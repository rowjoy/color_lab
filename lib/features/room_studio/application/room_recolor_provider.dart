import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recolor/room_recolor_frame.dart';
import 'room_project_session_controller.dart';
import 'room_recolor_scheduler.dart';
import 'room_recolor_service.dart';

RoomRecolorKey _key(RoomProjectSession session, String variantId) =>
    RoomRecolorKey(
      projectId: session.projectId,
      photoId: session.visible.photoId,
      maskRevision: session.visible.maskRevision,
      colorRevision: session.visible.colorRevision,
      variantId: variantId,
    );
RoomRecolorKey? roomActiveRecolorKey(RoomProjectSession? session) =>
    session == null ? null : _key(session, session.activeVariantId);
RoomRecolorKey? roomBaselineRecolorKey(RoomProjectSession? session) {
  final baseline = session?.comparisonBaselineVariantId;
  return session == null ||
          baseline == null ||
          baseline == session.activeVariantId
      ? null
      : _key(session, baseline);
}

final roomRecolorKeyProvider = Provider<RoomRecolorKey?>(
  (ref) => roomActiveRecolorKey(ref.watch(roomProjectSessionProvider)),
);
final roomComparisonKeyProvider = Provider<RoomRecolorKey?>(
  (ref) => roomBaselineRecolorKey(ref.watch(roomProjectSessionProvider)),
);

final class RoomRecolorPreviews {
  const RoomRecolorPreviews({
    this.active = const AsyncData(null),
    this.baseline = const AsyncData(null),
    this.display,
  });
  final AsyncValue<RoomRecolorFrame?> active, baseline;
  final RoomRecolorFrame? display;
}

final roomRecolorCoordinatorProvider =
    NotifierProvider<RoomRecolorCoordinator, RoomRecolorPreviews>(
      RoomRecolorCoordinator.new,
    );
final roomRecolorPreviewProvider =
    NotifierProvider<
      _PreviewProjection<AsyncValue<RoomRecolorFrame?>>,
      AsyncValue<RoomRecolorFrame?>
    >(() => _PreviewProjection((s) => s.active));
final roomComparisonPreviewProvider =
    NotifierProvider<
      _PreviewProjection<AsyncValue<RoomRecolorFrame?>>,
      AsyncValue<RoomRecolorFrame?>
    >(() => _PreviewProjection((s) => s.baseline));
final roomRecolorDisplayProvider =
    NotifierProvider<_PreviewProjection<RoomRecolorFrame?>, RoomRecolorFrame?>(
      () => _PreviewProjection((s) => s.display),
    );

/// Project values synchronously instead of invalidating a provider generation.
/// Owner detachment must clear both lanes without queuing rebuild work after
/// their last view has unmounted.
class _PreviewProjection<T> extends Notifier<T> {
  _PreviewProjection(this.select);
  final T Function(RoomRecolorPreviews) select;
  @override
  T build() {
    ref.listen(roomRecolorCoordinatorProvider.select(select), (_, value) {
      state = value;
    });
    return select(ref.read(roomRecolorCoordinatorProvider));
  }
}

final class RoomRecolorFailure implements Exception {
  const RoomRecolorFailure(this.status);
  final RoomRecolorStatus status;
}

final class _Lane {
  RoomRecolorKey? key;
  RoomRecolorFrame? frame;
  int generation = 0;
  AsyncValue<RoomRecolorFrame?> value = const AsyncData(null);
  void clear() {
    generation++;
    frame?.dispose();
    frame = null;
    key = null;
    value = const AsyncData(null);
  }

  bool readyFor(RoomRecolorKey? next) =>
      next != null &&
      frame?.key == next &&
      !value.isLoading &&
      !value.hasError &&
      !frame!.isDisposed;
}

/// Sole accepted-frame owner and set submitter. The public providers only select
/// a lane; subscribing to baseline can never replace an active side request.
class RoomRecolorCoordinator extends Notifier<RoomRecolorPreviews>
    with WidgetsBindingObserver {
  late RoomRecolorScheduler _scheduler;
  RoomProjectSession? _session;
  final _active = _Lane(), _baseline = _Lane();
  Object? _owner;
  bool Function()? _visibleNow;
  bool _visible = false, _resumed = true, _alive = false;
  bool _publicationScheduled = false;
  Object? _submittedLifetime;

  @override
  RoomRecolorPreviews build() {
    _alive = true;
    _scheduler = ref.read(roomRecolorSchedulerProvider);
    _session = ref.read(roomProjectSessionProvider);
    final binding = WidgetsBinding.instance;
    _resumed =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    final remove = _scheduler.listenCancellation((project) {
      if (project == null || project == _session?.projectId) {
        _clear();
      }
    });
    ref.listen(roomProjectSessionProvider, (_, session) => _update(session));
    ref.onDispose(() {
      _alive = false;
      binding.removeObserver(this);
      remove();
      _clear();
      unawaited(_scheduler.suspend());
    });
    return const RoomRecolorPreviews();
  }

  bool get _eligible {
    if (!_alive || !_resumed || !_visible || _owner == null) return false;
    try {
      return _visibleNow?.call() ?? true;
    } catch (_) {
      return false;
    }
  }

  bool owns(Object owner) => identical(_owner, owner) && _alive;
  Object attachOwner({bool Function()? isVisible}) {
    final owner = Object();
    if (_owner != null) unawaited(_scheduler.suspend());
    _owner = owner;
    _visible = true;
    _visibleNow = isVisible;
    _restart();
    return owner;
  }

  void setOwnerVisible(Object owner, bool visible) {
    if (!owns(owner) || _visible == visible) return;
    _visible = visible;
    if (visible) {
      _restart();
    } else {
      unawaited(_scheduler.suspend());
    }
  }

  void detachOwner(Object owner) {
    if (!owns(owner)) return;
    _owner = null;
    _visibleNow = null;
    _visible = false;
    unawaited(_scheduler.suspend());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      lifecycleChanged(state);
  void lifecycleChanged(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    if (_resumed) {
      _restart();
    } else {
      unawaited(_scheduler.suspend());
    }
  }

  void _restart() {
    if (!_eligible) return;
    _scheduler.resume();
    _submit();
  }

  void _update(RoomProjectSession? session) {
    final old = _session;
    if (old != null &&
        (session == null ||
            !identical(old.lifetime, session.lifetime) ||
            old.projectId != session.projectId)) {
      unawaited(_scheduler.cancelProject(old.projectId));
    }
    _session = session;
    if (session == null) {
      _clear();
      return;
    }
    if (!_eligible) return;
    final activeKey = roomActiveRecolorKey(session);
    final baselineKey = roomBaselineRecolorKey(session);
    if (identical(_submittedLifetime, session.lifetime) &&
        activeKey == _active.key) {
      if (baselineKey == _baseline.key) return;
      if (baselineKey == null) {
        _scheduler.clearBaseline();
        _baseline.clear();
        _publish();
        return;
      }
    }
    _submit();
  }

  void retry({bool discardActive = false}) {
    if (!_eligible) return;
    // Export verification can reject a frame whose key/dimensions were valid.
    // Release only that selected lane so its explicit recovery renders again.
    if (discardActive) _active.clear();
    _submit();
  }

  void _submit() {
    final session = _session;
    if (!_eligible || session == null) return;
    final draft = session.visible; // Pixels, masks, colors and both keys agree.
    final activeKey = roomActiveRecolorKey(session)!;
    final baselineKey = roomBaselineRecolorKey(session);
    _submittedLifetime = session.lifetime;
    final needActive = !_active.readyFor(activeKey);
    final needBaseline =
        baselineKey != null && !_baseline.readyFor(baselineKey);
    _prepare(_active, activeKey, needActive);
    _prepare(_baseline, baselineKey, needBaseline);
    _publish();
    if (!needActive && !needBaseline) return;
    final request = RoomRecolorRequest(
      lifetime: session.lifetime,
      active: RoomRecolorInput(
        key: activeKey,
        photo: draft.photo,
        masks: draft.masks,
        colors: draft.colors,
      ),
      baseline: baselineKey == null
          ? null
          : RoomRecolorInput(
              key: baselineKey,
              photo: draft.photo,
              masks: draft.masks,
              colors: session.variantSet.baseline!.colors,
            ),
      activeNeeded: needActive,
      baselineNeeded: needBaseline,
    );
    final ticket = _scheduler.renderLatest(request);
    final owner = _owner;
    void accept(
      _Lane lane,
      RoomRecolorKey key,
      int generation,
      RoomRecolorOutcome result,
    ) {
      final current = _session;
      final currentKey = identical(lane, _active)
          ? roomActiveRecolorKey(current)
          : roomBaselineRecolorKey(current);
      final frame = result.frame;
      if (!_eligible ||
          !identical(owner, _owner) ||
          current == null ||
          !identical(current.lifetime, session.lifetime) ||
          lane.generation != generation ||
          currentKey != key ||
          lane.key != key ||
          (frame != null &&
              (frame.key != key ||
                  frame.width != draft.photo.width ||
                  frame.height != draft.photo.height))) {
        frame?.dispose();
        return;
      }
      switch (result.status) {
        case RoomRecolorStatus.rendered:
          lane.frame?.dispose();
          lane.frame = frame;
          lane.value = AsyncData(frame);
        case RoomRecolorStatus.timeout:
        case RoomRecolorStatus.processingError:
        case RoomRecolorStatus.invalidOutput:
          lane.value = AsyncError(
            RoomRecolorFailure(result.status),
            StackTrace.empty,
          );
        default:
          return;
      }
      _publish();
    }

    if (needActive) {
      final generation = _active.generation;
      unawaited(
        ticket.active.then(
          (result) => accept(_active, activeKey, generation, result),
        ),
      );
    }
    if (needBaseline) {
      final generation = _baseline.generation;
      unawaited(
        ticket.baseline.then(
          (result) => accept(_baseline, baselineKey, generation, result),
        ),
      );
    }
  }

  void _prepare(_Lane lane, RoomRecolorKey? key, bool needed) {
    if (key == null) {
      lane.clear();
      return;
    }
    if (lane.frame != null && !lane.frame!.key.sameView(key)) {
      lane.frame!.dispose();
      lane.frame = null;
    }
    lane.key = key;
    if (needed) {
      lane.generation++;
      lane.value = const AsyncLoading();
    }
  }

  void _clear() {
    _submittedLifetime = null;
    _active.clear();
    _baseline.clear();
    _publish();
  }

  void _publish() {
    if (!_alive || _publicationScheduled) return;
    _publicationScheduled = true;
    // Owner visibility may change during widget dependency updates or disposal.
    // Revoke resources synchronously; notify Riverpod after that callback ends.
    scheduleMicrotask(() {
      _publicationScheduled = false;
      if (_alive && ref.mounted) {
        state = RoomRecolorPreviews(
          active: _active.value,
          baseline: _baseline.value,
          display: _active.frame,
        );
      }
    });
  }
}
