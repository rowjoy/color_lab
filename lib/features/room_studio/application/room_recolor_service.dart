import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../picker/domain/prepared_photo.dart';
import '../domain/mask_bitmap.dart';
import '../domain/room_layer_colors.dart';
import '../recolor/room_photo_recolorer.dart';
import '../recolor/room_recolor_frame.dart';

/// One immutable side captured with the other side from one visible session.
final class RoomRecolorInput {
  const RoomRecolorInput({
    required this.key,
    required this.photo,
    required this.masks,
    required this.colors,
  });
  final RoomRecolorKey key;
  final PreparedPhoto photo;
  final MaskBitmap masks;
  final RoomLayerColors colors;
}

abstract interface class RoomRecolorWorker {
  Future<void> get ready;
  Future<void> get exited;
  Future<RoomRecolorFrame> render(RoomRecolorInput input);

  /// Revokes work immediately; completes only after physical exit and cleanup.
  Future<void> terminate();
}

typedef RoomRecolorWorkerFactory = RoomRecolorWorker Function();
typedef RoomRecolorIsolateSpawner =
    Future<Isolate> Function(
      void Function(SendPort) entry,
      SendPort output,
      SendPort exit,
      SendPort errors,
    );

final roomRecolorWorkerFactoryProvider = Provider<RoomRecolorWorkerFactory>(
  (ref) => IsolateRoomRecolorWorker.new,
);

final class RoomRecolorWorkerStopped implements Exception {
  const RoomRecolorWorkerStopped();
}

final class RoomRecolorWorkerFailure implements Exception {
  const RoomRecolorWorkerFailure();
}

/// The handle exists before asynchronous spawn. Cancellation can therefore kill
/// an isolate that arrives after its owner has already revoked the operation.
final class IsolateRoomRecolorWorker implements RoomRecolorWorker {
  IsolateRoomRecolorWorker({
    void Function(SendPort) entryPoint = _recolorWorkerMain,
    RoomRecolorIsolateSpawner spawn = _spawn,
  }) {
    _messages.listen(_message);
    _errors.listen((_) => _fail());
    _exit.listen((_) => _didExit());
    _spawning = _start(entryPoint, spawn);
    // Ready may fail before a consumer has attached (e.g. synchronous close).
    unawaited(
      _ready.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }

  final _messages = ReceivePort();
  final _errors = ReceivePort();
  final _exit = ReceivePort();
  final _ready = Completer<void>();
  final _exited = Completer<void>();
  late final Future<void> _spawning;
  Isolate? _isolate;
  SendPort? _commands;
  Completer<RoomRecolorFrame>? _result;
  Future<void>? _termination;
  bool _stopping = false;

  static Future<Isolate> _spawn(
    void Function(SendPort) entry,
    SendPort output,
    SendPort exit,
    SendPort errors,
  ) => Isolate.spawn(
    entry,
    output,
    onExit: exit,
    onError: errors,
    errorsAreFatal: true,
    debugName: 'room-recolor',
  );

  Future<void> _start(
    void Function(SendPort) entry,
    RoomRecolorIsolateSpawner spawn,
  ) async {
    try {
      final isolate = await spawn(
        entry,
        _messages.sendPort,
        _exit.sendPort,
        _errors.sendPort,
      );
      if (_exited.isCompleted) {
        isolate.kill(priority: Isolate.immediate);
        return;
      }
      _isolate = isolate;
      if (_stopping) isolate.kill(priority: Isolate.immediate);
    } catch (_) {
      _fail();
      _didExit(); // Spawn failed: no process exists to acknowledge exit.
    }
  }

  void _message(Object? message) {
    if (message is SendPort) {
      if (_stopping) return;
      _commands = message;
      if (!_ready.isCompleted) _ready.complete();
    } else if (message is RoomRecolorFrame) {
      final result = _result;
      _result = null;
      if (_stopping || result == null) {
        message.dispose();
      } else {
        result.complete(message);
      }
    } else {
      _fail();
    }
  }

  void _fail() {
    if (!_ready.isCompleted) {
      _ready.completeError(const RoomRecolorWorkerFailure());
    }
    final result = _result;
    _result = null;
    result?.completeError(const RoomRecolorWorkerFailure());
  }

  void _didExit() {
    if (_exited.isCompleted) return;
    _stopping = true;
    _commands = null;
    _isolate = null;
    if (!_ready.isCompleted) {
      _ready.completeError(const RoomRecolorWorkerStopped());
    }
    final result = _result;
    _result = null;
    result?.completeError(const RoomRecolorWorkerStopped());
    _messages.close();
    _errors.close();
    _exit.close();
    _exited.complete();
  }

  @override
  Future<void> get ready => _ready.future;
  @override
  Future<void> get exited => _exited.future;
  @override
  Future<RoomRecolorFrame> render(RoomRecolorInput input) {
    if (_stopping || _commands == null || _result != null) {
      return Future.error(const RoomRecolorWorkerStopped());
    }
    final result = _result = Completer<RoomRecolorFrame>();
    _commands!.send(input);
    return result.future;
  }

  @override
  Future<void> terminate() {
    if (_termination case final existing?) return existing;
    _stopping = true;
    _commands = null;
    _isolate?.kill(priority: Isolate.immediate);
    return _termination = () async {
      await _spawning;
      _isolate?.kill(priority: Isolate.immediate);
      await exited;
    }();
  }
}

void _recolorWorkerMain(SendPort output) {
  final commands = ReceivePort();
  output.send(commands.sendPort);
  commands.listen((message) {
    if (message is! RoomRecolorInput) return;
    try {
      output.send(
        recolorRoomPhoto(
          key: message.key,
          photo: message.photo,
          masks: message.masks,
          colors: message.colors,
        ),
      );
    } catch (_) {
      // Do not transfer content, paths or underlying exception details.
      output.send(null);
    }
  });
}
