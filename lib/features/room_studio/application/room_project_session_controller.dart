import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../picker/domain/prepared_photo.dart';
import '../data/room_project_codec.dart';
import '../domain/mask_bitmap.dart';
import '../domain/mask_undo.dart';
import '../domain/room_mask_state.dart';
import '../domain/room_project.dart';
import '../domain/room_project_repository.dart';
import 'room_projects_providers.dart';

enum RoomProjectSaveStatus { saving, saved, failed, conflict }

/// Deliberately contains no filesystem paths or underlying exception text.
enum RoomProjectSaveError { storage, conflict, unavailable, invalidData, limit }

/// The caller must keep the draft or explicitly close it before opening another
/// saved version. In particular, conflict recovery never discards edits silently.
final class RoomProjectUnsavedChanges implements Exception {
  const RoomProjectUnsavedChanges();
}

@immutable
final class RoomProjectSession {
  const RoomProjectSession({
    required this.projectId,
    required this.name,
    required this.durable,
    required this.visible,
    required this.saveStatus,
    required this.saveError,
    required this.pendingSaveCount,
    this.recoveryWarning,
  });

  final String projectId;
  final String name;
  final RoomProjectSnapshot? durable;
  final RoomMaskDraft visible;
  final RoomProjectSaveStatus saveStatus;
  final RoomProjectSaveError? saveError;
  final int pendingSaveCount;
  final RoomProjectRecoveryWarning? recoveryWarning;

  bool get hasUnsavedChanges => saveStatus != RoomProjectSaveStatus.saved;
}

final roomProjectSessionProvider =
    NotifierProvider<RoomProjectSessionController, RoomProjectSession?>(
      RoomProjectSessionController.new,
    );

/// Completed mutations become FIFO save intents. Visible state never waits for
/// disk. A failure drops pending intents, retains the latest visible draft and
/// stops autosave until Retry. Retry uses the last acknowledged CAS token; a
/// conflict cannot silently adopt another writer's revision.
class RoomProjectSessionController extends Notifier<RoomProjectSession?> {
  _ProjectWork? _work;
  bool _alive = true;
  int _lifecycle = 0;
  Future<void> _draining = Future.value();

  @override
  RoomProjectSession? build() {
    ref.onDispose(() {
      _alive = false;
      unawaited(closeProject());
    });
    return null;
  }

  bool _current(_ProjectWork work) =>
      _alive && ref.mounted && !work.closed && identical(_work, work);

  Future<void> createFromAnalysis(RoomMaskDraft draft) {
    if (!_alive) return Future.value();
    final barrier = closeProject();
    final names = ref.read(roomProjectLocalizationsProvider);
    final id = ref.read(roomProjectIdFactoryProvider);
    final work = _ProjectWork(
      projectId: id(),
      name: names.roomProjectDefaultName,
      variantId: id(),
      variantName: names.roomProjectDefaultVariant,
      visible: draft,
      barrier: barrier,
    );
    _work = work;
    return _enqueue(work, draft);
  }

  Future<void> createManualFallback(RoomPhotoCandidate candidate) {
    final empty = MaskBitmap(
      width: candidate.photo.width,
      height: candidate.photo.height,
      labels: Uint8List(candidate.photo.width * candidate.photo.height),
    );
    return createFromAnalysis(
      RoomMaskDraft(
        photoId: candidate.photoId,
        photo: candidate.photo,
        aiMasks: empty,
        masks: empty,
        history: MaskUndoHistory(),
        maskRevision: 0,
        changedFromAiCount: 0,
        manualMode: true,
      ),
    );
  }

  /// Called once per completed mutation, never for pointer samples or controls.
  Future<void> commitVisibleDraft(RoomMaskDraft draft) {
    final work = _work;
    if (work == null ||
        !_current(work) ||
        draft.photoId != work.visible.photoId ||
        draft.photo.width != work.visible.photo.width ||
        draft.photo.height != work.visible.photo.height ||
        draft.maskRevision < work.visible.maskRevision ||
        draft.colorRevision < work.visible.colorRevision ||
        (draft.maskRevision == work.visible.maskRevision &&
            draft.colorRevision == work.visible.colorRevision) ||
        identical(draft, work.visible)) {
      return Future.value();
    }
    _lifecycle++;
    work.visible = draft;
    if (work.error != null) {
      _publish(work);
      return Future.value();
    }
    return _enqueue(work, draft);
  }

  Future<void> retrySave() {
    final work = _work;
    if (work == null ||
        !_current(work) ||
        work.error == null ||
        work.active != null) {
      return Future.value();
    }
    if (ref.read(roomProjectRepositoryProvider).hasError) {
      // No owner was established. Retry initialization without replacing a live
      // owner's serialized queue or maintenance lease.
      ref.invalidate(roomProjectRepositoryProvider);
    }
    work.error = null;
    return _enqueue(work, work.visible);
  }

  Future<void> _enqueue(_ProjectWork work, RoomMaskDraft draft) {
    final intent = _SaveIntent(draft);
    work.pending.add(intent);
    work.status = RoomProjectSaveStatus.saving;
    _publish(work);
    _pump(work);
    return intent.done.future;
  }

  void _pump(_ProjectWork work) {
    if (!_current(work) ||
        work.active != null ||
        work.error != null ||
        work.pending.isEmpty) {
      return;
    }
    final intent = work.pending.removeFirst();
    work.activeIntent = intent;
    work.active = _save(work, intent).whenComplete(() {
      work.active = null;
      _pump(work);
    });
  }

  Future<void> _save(_ProjectWork work, _SaveIntent intent) async {
    try {
      await work.barrier;
      if (!_current(work)) return;
      var base = work.durable;
      if (base == null) {
        final assets =
            work.assets ??
            await compute<PreparedPhoto, _PreparedAssets>(
              _prepareAssets,
              intent.draft.photo,
            );
        work.assets = assets;
        if (!_current(work)) return;
        base = RoomProjectSnapshot(
          projectId: work.projectId,
          photoId: intent.draft.photoId,
          name: work.name,
          revision: 0,
          width: intent.draft.photo.width,
          height: intent.draft.photo.height,
          photoPng: assets.photo,
          thumbnailPng: assets.thumbnail,
          aiMaskBytes: intent.draft.aiMasks.labels,
          maskBytes: intent.draft.masks.labels,
          maskRevision: intent.draft.maskRevision,
          colorRevision: intent.draft.colorRevision,
          variants: [
            RoomColorVariant(
              id: work.variantId,
              name: work.variantName,
              colors: intent.draft.colors,
            ),
          ],
          activeVariantId: work.variantId,
          createdAt: work.createdAt,
          updatedAt: work.createdAt,
        );
      }
      final now = DateTime.now().toUtc();
      final snapshot = base.copyWith(
        aiMaskBytes: intent.draft.aiMasks.labels,
        maskBytes: intent.draft.masks.labels,
        maskRevision: intent.draft.maskRevision,
        colorRevision: intent.draft.colorRevision,
        variants: [
          for (final variant in base.variants)
            variant.id == base.activeVariantId
                ? variant.copyWith(colors: intent.draft.colors)
                : variant,
        ],
        updatedAt: now.isBefore(base.updatedAt) ? base.updatedAt : now,
      );
      final repository = await ref.read(roomProjectRepositoryProvider.future);
      // close() may have happened during encoding or owner initialization.
      // Only a save already accepted by the repository is allowed to drain.
      if (!_current(work)) return;
      final saved = await repository.save(
        snapshot,
        expectedRevision: work.acknowledgedRevision,
      );
      work.durable = saved;
      work.acknowledgedRevision = saved.revision;
      if (_current(work)) ref.invalidate(roomProjectsProvider);
    } catch (error) {
      work.error = switch (error) {
        RoomProjectConflict() => RoomProjectSaveError.conflict,
        RoomProjectStorageException(:final failure) => switch (failure) {
          RoomProjectStorageFailure.closed => RoomProjectSaveError.unavailable,
          RoomProjectStorageFailure.corrupt ||
          RoomProjectStorageFailure.invalidId =>
            RoomProjectSaveError.invalidData,
          RoomProjectStorageFailure.limit => RoomProjectSaveError.limit,
          RoomProjectStorageFailure.io => RoomProjectSaveError.storage,
        },
        ArgumentError() ||
        FormatException() => RoomProjectSaveError.invalidData,
        _ => RoomProjectSaveError.storage,
      };
      _discardPending(work);
    } finally {
      work.activeIntent = null;
      work.status = work.error == RoomProjectSaveError.conflict
          ? RoomProjectSaveStatus.conflict
          : work.error != null
          ? RoomProjectSaveStatus.failed
          : work.pending.isNotEmpty
          ? RoomProjectSaveStatus.saving
          : RoomProjectSaveStatus.saved;
      _publish(work);
      intent.done.complete();
    }
  }

  /// Returns a fully reconstructed editor draft. Callers install it only if
  /// their route/operation still owns the request. Missing projects return null;
  /// storage/decode failures use the repository's safe typed exception.
  Future<RoomMaskDraft?> openProject(
    String projectId, {
    bool Function()? isCurrent,
  }) async {
    if (!_alive) return null;
    if (state?.hasUnsavedChanges ?? false) {
      throw const RoomProjectUnsavedChanges();
    }
    final lifecycle = ++_lifecycle;
    bool current() {
      if (!_alive || !ref.mounted || lifecycle != _lifecycle) return false;
      try {
        return isCurrent?.call() ?? true;
      } catch (_) {
        return false;
      }
    }

    await _draining;
    if (!current()) return null;
    try {
      final repository = await ref.read(roomProjectRepositoryProvider.future);
      if (!current()) return null;
      final result = await repository.read(projectId);
      if (!current() || result == null) return null;
      final draft = await compute(_reopenDraft, result.snapshot);
      if (!current()) return null;
      // Keep the old session usable if lookup/decoding fails. A command issued
      // while reading also wins over this open; it must be resolved explicitly.
      if (state?.hasUnsavedChanges ?? false) {
        throw const RoomProjectUnsavedChanges();
      }
      // Drain before changing ownership, then publish without an intervening
      // await. New editor commands or acquisition operations win at this gate.
      await (_work?.active ?? _draining);
      if (!current()) return null;
      final closing = closeProject();
      final snapshot = result.snapshot;
      final variant = snapshot.variants.firstWhere(
        (v) => v.id == snapshot.activeVariantId,
      );
      final work =
          _ProjectWork(
              projectId: snapshot.projectId,
              name: snapshot.name,
              variantId: variant.id,
              variantName: variant.name,
              visible: draft,
              barrier: closing,
            )
            ..durable = snapshot
            ..acknowledgedRevision = result.acknowledgedRevision
            ..warning = result.warning
            ..status = RoomProjectSaveStatus.saved;
      _work = work;
      _publish(work);
      return draft;
    } on RoomProjectUnsavedChanges {
      rethrow;
    } on RoomProjectStorageException {
      rethrow;
    } catch (_) {
      throw const RoomProjectStorageException(
        RoomProjectStorageFailure.corrupt,
      );
    }
  }

  /// Invalidates queued/not-yet-accepted writes synchronously, then waits for
  /// accepted storage work. Maintenance/delete must await this barrier.
  Future<void> closeProject({bool deferNotification = false}) {
    _lifecycle++;
    final work = _work;
    _work = null;
    if (work != null) {
      work.closed = true;
      _discardPending(work);
      _draining = Future.wait<void>([
        _draining,
        if (work.active != null) work.active!,
      ]).then((_) {});
    }
    final lifecycle = _lifecycle;
    void notifyClosed() {
      if (_alive && ref.mounted && lifecycle == _lifecycle && _work == null) {
        state = null;
      }
    }

    // Riverpod prohibits publishing to another provider during onDispose.
    // Invalidate work now; only the notification waits until that callback ends.
    if (deferNotification) {
      scheduleMicrotask(notifyClosed);
    } else {
      notifyClosed();
    }
    return _draining;
  }

  void _discardPending(_ProjectWork work) {
    while (work.pending.isNotEmpty) {
      work.pending.removeFirst().done.complete();
    }
  }

  void _publish(_ProjectWork work) {
    if (!_current(work)) return;
    state = RoomProjectSession(
      projectId: work.projectId,
      name: work.name,
      durable: work.durable,
      visible: work.visible,
      saveStatus: work.status,
      saveError: work.error,
      pendingSaveCount:
          work.pending.length + (work.activeIntent == null ? 0 : 1),
      recoveryWarning: work.warning,
    );
  }
}

final class _ProjectWork {
  _ProjectWork({
    required this.projectId,
    required this.name,
    required this.variantId,
    required this.variantName,
    required this.visible,
    required this.barrier,
  });
  final String projectId, name, variantId, variantName;
  final DateTime createdAt = DateTime.now().toUtc();
  final Future<void> barrier;
  final pending = Queue<_SaveIntent>();
  RoomMaskDraft visible;
  RoomProjectSnapshot? durable;
  _PreparedAssets? assets;
  int acknowledgedRevision = 0;
  RoomProjectRecoveryWarning? warning;
  RoomProjectSaveStatus status = RoomProjectSaveStatus.saving;
  RoomProjectSaveError? error;
  Future<void>? active;
  _SaveIntent? activeIntent;
  bool closed = false;
}

final class _SaveIntent {
  _SaveIntent(this.draft);
  final RoomMaskDraft draft;
  final done = Completer<void>();
}

typedef _PreparedAssets = ({Uint8List photo, Uint8List thumbnail});

_PreparedAssets _prepareAssets(PreparedPhoto photo) {
  if (photo.width > RoomProjectLimits.maxDimension ||
      photo.height > RoomProjectLimits.maxDimension ||
      photo.width * photo.height > RoomProjectLimits.maxPixels) {
    throw const FormatException('Invalid working dimensions');
  }
  // Start with pixels only: no source preview, EXIF, profile or text metadata.
  final image = img.Image.fromBytes(
    width: photo.width,
    height: photo.height,
    bytes: photo.rgbaBytes.buffer,
    bytesOffset: photo.rgbaBytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  final scale = math.min(1.0, 256 / math.max(photo.width, photo.height));
  final thumbnail = img.copyResize(
    image,
    width: math.max(1, (photo.width * scale).round()),
    height: math.max(1, (photo.height * scale).round()),
  );
  return (
    photo: Uint8List.fromList(img.encodePng(image)),
    thumbnail: Uint8List.fromList(img.encodePng(thumbnail)),
  );
}

RoomMaskDraft _reopenDraft(RoomProjectSnapshot snapshot) {
  // Validate strict headers, CRCs, dimensions and format before decoding even
  // when an alternate repository implementation supplies this snapshot.
  const RoomProjectCodec().encode(snapshot);
  final image = img.decodePng(snapshot.photoPng)!;
  var changed = 0;
  var hasAi = false;
  for (var i = 0; i < snapshot.maskBytes.length; i++) {
    if (snapshot.maskBytes[i] != snapshot.aiMaskBytes[i]) changed++;
    if (snapshot.aiMaskBytes[i] != 0) hasAi = true;
  }
  return RoomMaskDraft(
    photoId: snapshot.photoId,
    photo: PreparedPhoto(
      width: snapshot.width,
      height: snapshot.height,
      rgbaBytes: image.getBytes(order: img.ChannelOrder.rgba),
      previewBytes: snapshot.photoPng,
      palette: const [],
    ),
    aiMasks: MaskBitmap(
      width: snapshot.width,
      height: snapshot.height,
      labels: snapshot.aiMaskBytes,
    ),
    masks: MaskBitmap(
      width: snapshot.width,
      height: snapshot.height,
      labels: snapshot.maskBytes,
    ),
    history: MaskUndoHistory(),
    maskRevision: snapshot.maskRevision,
    colorRevision: snapshot.colorRevision,
    changedFromAiCount: changed,
    colors: snapshot.colors,
    manualMode: !hasAi,
  );
}
