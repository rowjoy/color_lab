import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recolor/room_recolor_frame.dart';
import 'room_recolor_service.dart';

enum RoomRecolorStatus {
  rendered,
  superseded,
  projectCancelled,
  suspended,
  closed,
  timeout,
  processingError,
  invalidOutput,
}

final class RoomRecolorOutcome {
  const RoomRecolorOutcome(this.status, [this.frame]);
  final RoomRecolorStatus status;

  /// A rendered result transfers its initial ownership to the ticket consumer.
  final RoomRecolorFrame? frame;
}

final class RoomRecolorRequest {
  const RoomRecolorRequest({
    required this.lifetime,
    required this.active,
    this.baseline,
    this.activeNeeded = true,
    this.baselineNeeded = true,
  });
  final Object lifetime;
  final RoomRecolorInput active;
  final RoomRecolorInput? baseline;
  final bool activeNeeded;
  final bool baselineNeeded;
  String get projectId => active.key.projectId;
}

final class RoomRecolorTicket {
  final _active = Completer<RoomRecolorOutcome>();
  final _baseline = Completer<RoomRecolorOutcome>();
  Future<RoomRecolorOutcome> get active => _active.future;
  Future<RoomRecolorOutcome> get baseline => _baseline.future;
  void _settle(RoomRecolorStatus status) {
    if (!_active.isCompleted) _active.complete(RoomRecolorOutcome(status));
    if (!_baseline.isCompleted) _baseline.complete(RoomRecolorOutcome(status));
  }
}

abstract interface class RoomRecolorWatchdog {
  void cancel();
}

typedef RoomRecolorWatchdogFactory =
    RoomRecolorWatchdog Function(Duration duration, void Function() fire);

final class _TimerWatchdog implements RoomRecolorWatchdog {
  _TimerWatchdog(Duration duration, void Function() fire)
    : _timer = Timer(duration, fire);
  final Timer _timer;
  @override
  void cancel() => _timer.cancel();
}

final roomRecolorWatchdogFactoryProvider = Provider<RoomRecolorWatchdogFactory>(
  (ref) => _TimerWatchdog.new,
);
final roomRecolorSchedulerProvider = Provider<RoomRecolorScheduler>((ref) {
  final scheduler = RoomRecolorScheduler(
    workerFactory: ref.read(roomRecolorWorkerFactoryProvider),
    watchdogFactory: ref.read(roomRecolorWatchdogFactoryProvider),
  );
  ref.onDispose(() => unawaited(scheduler.close()));
  return scheduler;
});

final class _SetWork {
  _SetWork(RoomRecolorRequest input, this.ticket)
    : request = input,
      projectId = input.projectId;
  RoomRecolorRequest? request;
  final String projectId;
  final RoomRecolorTicket ticket;
  bool revoked = false;
  bool baselineCleared = false;
  void revoke(RoomRecolorStatus status) {
    revoked = true;
    request = null;
    ticket._settle(status);
  }
}

/// One executing preview set and one replaceable pending set. At most one side
/// physically computes. Superseded tickets settle now while physical work drains.
final class RoomRecolorScheduler {
  RoomRecolorScheduler({
    required RoomRecolorWorkerFactory workerFactory,
    required RoomRecolorWatchdogFactory watchdogFactory,
    this.timeout = const Duration(seconds: 30),
  }) : _workerFactory = workerFactory,
       _watchdogFactory = watchdogFactory;
  final RoomRecolorWorkerFactory _workerFactory;
  final RoomRecolorWatchdogFactory _watchdogFactory;
  final Duration timeout;
  final _cancellations = <void Function(String?)>{};
  _SetWork? _executing, _pending;
  RoomRecolorWorker? _worker;
  String? _workerProjectId, _retiringProjectId;
  Future<void> _retiring = Future.value();
  Completer<RoomRecolorOutcome>? _operation;
  RoomRecolorWatchdog? _watchdog;
  RoomRecolorInput? _startupInput;
  bool _closed = false, _suspended = false, _baselineFirst = false;
  Future<void>? _closing;

  void Function() listenCancellation(void Function(String?) listener) {
    _cancellations.add(listener);
    return () => _cancellations.remove(listener);
  }

  RoomRecolorTicket renderLatest(RoomRecolorRequest request) {
    final ticket = RoomRecolorTicket();
    if (_closed || _suspended) {
      ticket._settle(
        _closed ? RoomRecolorStatus.closed : RoomRecolorStatus.suspended,
      );
      return ticket;
    }
    _executing?.revoke(RoomRecolorStatus.superseded);
    _pending?.revoke(RoomRecolorStatus.superseded);
    _pending = _SetWork(request, ticket);
    _pump();
    return ticket;
  }

  /// Baseline demand can disappear without invalidating the selected side.
  void clearBaseline() {
    for (final set in [_executing, _pending]) {
      if (set == null) continue;
      set.baselineCleared = true;
      if (!set.ticket._baseline.isCompleted) {
        set.ticket._baseline.complete(
          const RoomRecolorOutcome(RoomRecolorStatus.superseded),
        );
      }
    }
  }

  void _pump() {
    if (_executing != null || _pending == null || _closed || _suspended) return;
    final work = _executing = _pending!;
    _pending = null;
    unawaited(
      _run(work).whenComplete(() {
        work.request = null;
        _executing = null;
        _pump();
      }),
    );
  }

  Future<void> _run(_SetWork work) async {
    // Do not start even a handshake until the previous worker confirmed exit.
    await _retiring;
    if (work.revoked) return;
    final both =
        work.request!.activeNeeded &&
        work.request!.baseline != null &&
        work.request!.baselineNeeded &&
        !work.baselineCleared;
    final baselineFirst = both && _baselineFirst;
    if (both) _baselineFirst = !_baselineFirst;
    for (final baseline in baselineFirst ? [true, false] : [false, true]) {
      await _retiring;
      if (work.revoked) return;
      final request = work.request!;
      final completer = baseline ? work.ticket._baseline : work.ticket._active;
      final input = baseline ? request.baseline : request.active;
      final needed = baseline
          ? request.baselineNeeded && !work.baselineCleared
          : request.activeNeeded;
      if (completer.isCompleted) continue;
      if (input == null || !needed) {
        completer.complete(
          const RoomRecolorOutcome(RoomRecolorStatus.superseded),
        );
        continue;
      }
      final outcome = await _render(input, work);
      if (work.revoked || completer.isCompleted) {
        outcome.frame?.dispose();
        continue;
      }
      completer.complete(outcome);
    }
  }

  Future<RoomRecolorOutcome> _render(
    RoomRecolorInput input,
    _SetWork work,
  ) async {
    if (work.revoked) {
      return const RoomRecolorOutcome(RoomRecolorStatus.superseded);
    }
    if (_closed || _suspended) {
      return RoomRecolorOutcome(
        _closed ? RoomRecolorStatus.closed : RoomRecolorStatus.suspended,
      );
    }
    final operation = _operation = Completer<RoomRecolorOutcome>();
    RoomRecolorWorker worker;
    _workerProjectId = input.key.projectId;
    try {
      worker = _worker ??= _workerFactory();
    } catch (_) {
      _operation = null;
      return const RoomRecolorOutcome(RoomRecolorStatus.processingError);
    }
    _watchdog = _watchdogFactory(timeout, () {
      if (!identical(_operation, operation) || operation.isCompleted) return;
      operation.complete(const RoomRecolorOutcome(RoomRecolorStatus.timeout));
      _retire();
    });
    final key = input.key;
    final width = input.photo.width, height = input.photo.height;
    _startupInput = input;
    void failed(Object _, StackTrace _) {
      if (!operation.isCompleted) {
        operation.complete(
          const RoomRecolorOutcome(RoomRecolorStatus.processingError),
        );
        _retire();
      }
    }

    // Startup holds input in an explicitly revocable slot. Result handlers keep
    // only identity/dimensions; cancelled late spawn cannot retain the photo.
    unawaited(
      worker.ready.then<void>((_) {
        if (operation.isCompleted) return;
        final retained = _startupInput;
        _startupInput = null;
        if (retained == null) return;
        Future<RoomRecolorFrame> result;
        try {
          result = worker.render(retained);
        } catch (error, stack) {
          failed(error, stack);
          return;
        }
        unawaited(
          result.then<void>((frame) {
            if (operation.isCompleted) {
              frame.dispose();
              return;
            }
            if (frame.isDisposed ||
                frame.key != key ||
                frame.width != width ||
                frame.height != height) {
              frame.dispose();
              operation.complete(
                const RoomRecolorOutcome(RoomRecolorStatus.invalidOutput),
              );
            } else {
              operation.complete(
                RoomRecolorOutcome(RoomRecolorStatus.rendered, frame),
              );
            }
          }, onError: failed),
        );
      }, onError: failed),
    );
    final outcome = await operation.future;
    if (identical(_operation, operation)) {
      _watchdog?.cancel();
      _watchdog = null;
      _operation = null;
    }
    return outcome;
  }

  Future<void> _retire() {
    _startupInput = null;
    _watchdog?.cancel();
    _watchdog = null;
    final worker = _worker;
    _worker = null;
    if (worker != null) {
      _retiringProjectId = _workerProjectId;
      _workerProjectId = null;
      final previous = _retiring;
      final exit = worker.terminate(); // Immediate kill before any await.
      _retiring = Future.wait<void>([
        previous,
        exit,
        worker.exited,
      ]).then((_) {});
    }
    return _retiring;
  }

  Future<void> _cancel(RoomRecolorStatus status, [String? projectId]) {
    bool matches(_SetWork work) =>
        projectId == null || work.projectId == projectId;
    final executing = _executing;
    final pending = _pending;
    if (pending != null && matches(pending)) {
      pending.revoke(status);
      _pending = null;
    }
    final cancelExecuting = executing != null && matches(executing);
    if (cancelExecuting) executing.revoke(status);
    for (final callback in _cancellations.toList()) {
      callback(projectId);
    }
    if (cancelExecuting || projectId == null || _workerProjectId == projectId) {
      final op = _operation;
      if (op != null && !op.isCompleted) {
        op.complete(RoomRecolorOutcome(status));
      }
      return _retire();
    }
    if (projectId == _retiringProjectId) return _retiring;
    return Future.value();
  }

  Future<void> cancelProject(String projectId) =>
      _cancel(RoomRecolorStatus.projectCancelled, projectId);
  Future<void> suspend() {
    _suspended = true;
    return _cancel(RoomRecolorStatus.suspended);
  }

  void resume() {
    if (!_closed) _suspended = false;
  }

  Future<void> close() {
    if (_closing case final existing?) return existing;
    _closed = true;
    _closing = _cancel(RoomRecolorStatus.closed);
    _cancellations.clear();
    return _closing!;
  }
}
