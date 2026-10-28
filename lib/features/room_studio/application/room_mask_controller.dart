import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_models.dart';
import '../../picker/application/photo_acquisition_controller.dart';
import '../../picker/domain/photo_acquisition.dart';
import '../domain/mask_bitmap.dart';
import '../domain/mask_stroke.dart';
import '../domain/mask_edit_command.dart';
import '../domain/mask_edit_history.dart';
import '../domain/mask_intent_bitmap.dart';
import '../domain/room_layer.dart';
import '../domain/room_mask_state.dart';
import '../refine/mask_refinement.dart';
import '../refine/mask_refinement_service.dart';
import '../segmentation/room_segmentation_service.dart';
import 'room_project_session_controller.dart';
import 'room_projects_providers.dart';

final roomPhotoIdFactoryProvider = Provider<String Function()>(
  (ref) => ref.read(roomProjectIdFactoryProvider),
);

/// Session lifetime ownership, independent of screen subscriptions or colors.
final roomMaskProvider = NotifierProvider<RoomMaskController, RoomMaskState>(
  RoomMaskController.new,
);

final class _PhotoStorageError {
  const _PhotoStorageError({
    required this.failure,
    required this.state,
    required this.operation,
    required this.sessionLifetime,
    required this.sessionDraft,
    required this.receipt,
  });
  final AcquisitionStorageFailure failure;
  final RoomMaskState state;
  final int operation;
  final Object? sessionLifetime;
  final RoomMaskDraft? sessionDraft;
  final AcquisitionReceipt? receipt;
}

class RoomMaskController extends Notifier<RoomMaskState> {
  bool _alive = false;
  int _operation = 0;
  int? _claimOperation;
  int _editSelection = 0;
  bool _refining = false;
  _PendingStroke? _pendingStroke;
  RoomProjectSessionController? _projectSession;
  _PhotoStorageError? _photoStorageError;

  RoomProjectSessionController get _session {
    final session = ref.read(roomProjectSessionProvider.notifier);
    _projectSession = session;
    return session;
  }

  @override
  RoomMaskState build() {
    _alive = true;
    ref.listen(
      photoAcquisitionProvider,
      (_, next) => _reconcilePhotoStorage(next),
    );
    ref.listen(roomProjectSessionProvider, (previous, next) {
      if (!identical(previous?.lifetime, next?.lifetime)) cancelStroke();
      final error = _photoStorageError;
      if (error != null &&
          (!identical(error.sessionLifetime, next?.lifetime) ||
              !identical(error.sessionDraft, next?.visible))) {
        _photoStorageError = null;
      }
    });
    ref.onDispose(() {
      cancelStroke();
      _alive = false;
      _photoStorageError = null;
      cancelStroke();
      _operation++;
      unawaited(
        _projectSession?.closeProject(deferNotification: true) ??
            Future.value(),
      );
    });
    // Dependencies are read only for explicit actions, never watched here.
    return const RoomMaskState.initial();
  }

  bool get _live => _alive && ref.mounted;
  bool _current(int operation) => _live && operation == _operation;

  bool _active(bool Function() isActive) {
    try {
      return isActive();
    } catch (_) {
      return false;
    }
  }

  int _startImport() {
    cancelStroke();
    final operation = ++_operation;
    _photoStorageError = null;
    state = state.copyWith(
      stage: RoomMaskStage.acquiring,
      candidate: null,
      failure: null,
      editBusy: false,
    );
    return operation;
  }

  Future<void> importPhoto(
    PhotoSource source, {
    required bool Function() isActive,
  }) async {
    if (!_live || !_active(isActive)) return;
    final operation = _startImport();
    try {
      final outcome = await ref
          .read(photoAcquisitionProvider.notifier)
          .request(
            source: source,
            destination: AcquisitionDestination.room,
            isActive: () => _current(operation) && _active(isActive),
          );
      if (!_current(operation)) return;
      switch (outcome) {
        case Acquired(:final receipt):
          await _claim(receipt.requestId, operation, isActive);
        case AcquisitionFailed(:final kind, :final storageFailure):
          _failAcquisition(kind, storageFailure);
        case AcquisitionCancelled():
          _returnToDraft();
        case AcquisitionBusy():
          _fail(RoomMaskFailureKind.acquisitionUnavailable);
      }
    } catch (_) {
      if (_current(operation)) {
        _fail(RoomMaskFailureKind.acquisitionUnavailable);
      }
    }
  }

  /// A photo recovery action can retry only its exact failed mutation. Shared
  /// retry completion is reconciled independently of the initiating route.
  Future<void> retryAcquisitionStorage({
    required RoomMaskState failedState,
  }) async {
    final error = _photoStorageError;
    if (error == null ||
        !identical(failedState, error.state) ||
        !_ownsPhotoStorageError(error)) {
      return;
    }
    await ref
        .read(photoAcquisitionProvider.notifier)
        .retryStorage(expectedFailure: error.failure);
  }

  bool _ownsPhotoStorageError(_PhotoStorageError error) =>
      _current(error.operation) &&
      identical(state, error.state) &&
      identical(
        error.sessionLifetime,
        ref.read(roomProjectSessionProvider)?.lifetime,
      ) &&
      identical(
        error.sessionDraft,
        ref.read(roomProjectSessionProvider)?.visible,
      );

  void _reconcilePhotoStorage(AcquisitionState acquisition) {
    final error = _photoStorageError;
    if (error == null) return;
    if (!_ownsPhotoStorageError(error)) {
      _photoStorageError = null;
      return;
    }
    if (acquisition.phase == AcquisitionPhase.ready &&
        identical(acquisition.resolvedStorageFailure, error.failure) &&
        identical(acquisition.pendingReceipt, error.receipt)) {
      _photoStorageError = null;
      state = state.copyWith(
        stage: state.draft == null ? RoomMaskStage.empty : RoomMaskStage.ready,
        failure: null,
      );
    } else if (!identical(acquisition.storageFailure, error.failure)) {
      // Replaced provider/request/event identities can never resolve this error.
      _photoStorageError = null;
    }
  }

  void _failAcquisition(
    AcquisitionFailureKind kind,
    AcquisitionStorageFailure? failure,
  ) {
    _fail(acquisitionFailure(kind));
    if (kind != AcquisitionFailureKind.storage ||
        failure?.requestId == null ||
        failure?.destination != AcquisitionDestination.room) {
      return;
    }
    final session = ref.read(roomProjectSessionProvider);
    final acquisition = ref.read(photoAcquisitionProvider);
    _photoStorageError = _PhotoStorageError(
      failure: failure!,
      state: state,
      operation: _operation,
      sessionLifetime: session?.lifetime,
      sessionDraft: session?.visible,
      receipt: acquisition.pendingReceipt,
    );
    _reconcilePhotoStorage(acquisition);
  }

  Future<void> continueImport(
    String requestId, {
    required bool Function() isActive,
  }) async {
    if (!_live || !_active(isActive)) return;
    final acquisition = ref.read(photoAcquisitionProvider);
    final receipt = acquisition.pendingReceipt;
    // A reopened screen can confirm Continue while an earlier screen's claim
    // is clearing storage, or after that claim has already accepted the photo.
    // Reject both cases before _startImport can discard its owned candidate.
    if ((_claimOperation != null && _current(_claimOperation!)) ||
        acquisition.phase != AcquisitionPhase.ready ||
        receipt == null ||
        receipt.requestId != requestId ||
        (receipt.destination != null &&
            receipt.destination != AcquisitionDestination.room)) {
      return;
    }
    final operation = _startImport();
    await _claim(requestId, operation, isActive);
  }

  Future<void> _claim(
    String requestId,
    int operation,
    bool Function() isActive,
  ) async {
    if (!_current(operation)) return;
    if (!_active(isActive)) {
      _returnToDraft();
      return;
    }
    _claimOperation = operation;
    try {
      final outcome = await ref
          .read(photoAcquisitionProvider.notifier)
          .claimReceipt(
            requestId: requestId,
            destination: AcquisitionDestination.room,
            accept: (photo) {
              // Acceptance is synchronous while acquisition owns the receipt gate.
              // Hidden but still retained owners stage pixels; disposed/superseded
              // owners leave the original receipt available for explicit Continue.
              if (!_current(operation)) return false;
              final photoId = ref.read(roomPhotoIdFactoryProvider)();
              state = state.copyWith(
                candidate: RoomPhotoCandidate(photoId: photoId, photo: photo),
              );
              return _current(operation);
            },
          );
      if (!_current(operation)) return;
      if (outcome is! Acquired) {
        if (outcome case AcquisitionFailed(
          :final kind,
          :final storageFailure,
        )) {
          _failAcquisition(kind, storageFailure);
        } else {
          _fail(RoomMaskFailureKind.acquisitionUnavailable);
        }
        return;
      }
      // Screen visibility can change during the durable receipt clear.
      if (_active(isActive)) await analyzeCandidate();
    } catch (_) {
      if (_current(operation)) {
        _fail(RoomMaskFailureKind.acquisitionUnavailable);
      }
    } finally {
      // Logical cancellation/supersession can admit a newer owner before this
      // physical future settles; its cleanup must not release the newer claim.
      if (_claimOperation == operation) _claimOperation = null;
    }
  }

  Future<void> analyzeCandidate() async {
    if (!_live ||
        state.candidate == null ||
        (state.stage != RoomMaskStage.acquiring &&
            state.stage != RoomMaskStage.error)) {
      return;
    }
    final candidate = state.candidate!;
    cancelStroke();
    final operation = ++_operation;
    state = state.copyWith(
      stage: RoomMaskStage.analyzing,
      failure: null,
      editBusy: false,
    );
    try {
      final result = await ref
          .read(roomSegmentationServiceProvider)
          .analyze(photoId: candidate.photoId, photo: candidate.photo);
      if (!_current(operation)) return;
      if (result.photoId != candidate.photoId ||
          result.masks.width != candidate.photo.width ||
          result.masks.height != candidate.photo.height) {
        _fail(RoomMaskFailureKind.invalidOutput);
        return;
      }
      state = state.copyWith(
        stage: RoomMaskStage.ready,
        candidate: null,
        failure: null,
        editBusy: _refining,
        draft: RoomMaskDraft(
          photoId: candidate.photoId,
          photo: candidate.photo,
          aiMasks: result.masks,
          masks: result.masks,
          history: MaskEditHistory.empty(
            width: candidate.photo.width,
            height: candidate.photo.height,
          ),
          maskRevision: 0,
          changedFromAiCount: 0,
        ),
      );
      unawaited(_session.createFromAnalysis(state.draft!));
    } catch (error) {
      if (!_current(operation)) return;
      _fail(
        error is RoomSegmentationException
            ? switch (error.kind) {
                RoomSegmentationFailureKind.modelUnavailable =>
                  RoomMaskFailureKind.modelUnavailable,
                RoomSegmentationFailureKind.incompatibleModel =>
                  RoomMaskFailureKind.incompatibleModel,
                RoomSegmentationFailureKind.invalidOutput =>
                  RoomMaskFailureKind.invalidOutput,
                RoomSegmentationFailureKind.processing =>
                  RoomMaskFailureKind.processing,
              }
            : RoomMaskFailureKind.processing,
      );
    }
  }

  Future<void> retryAnalysis() async {
    if (_live &&
        state.stage == RoomMaskStage.ready &&
        state.draft?.manualMode == true) {
      await reanalyzeCurrentPhoto();
      return;
    }
    if (_live &&
        state.stage == RoomMaskStage.error &&
        state.candidate != null) {
      await analyzeCandidate();
    }
  }

  /// Explicit recovery after a valid photo's analysis failed (or was deferred).
  bool createManualFallback() {
    if (!_live ||
        state.candidate == null ||
        (state.stage != RoomMaskStage.error &&
            state.stage != RoomMaskStage.acquiring)) {
      return false;
    }
    cancelStroke();
    _operation++;
    final session = _session;
    unawaited(session.createManualFallback(state.candidate!));
    final draft = ref.read(roomProjectSessionProvider)!.visible;
    state = state.copyWith(
      stage: RoomMaskStage.ready,
      candidate: null,
      failure: null,
      draft: draft,
      editBusy: _refining,
    );
    return true;
  }

  /// Continue retains transient tools, history and the current unsaved draft.
  /// It is separate from Open, which deliberately reads a stored version.
  bool continueProject(String projectId) {
    if (!_live) return false;
    final session = ref.read(roomProjectSessionProvider);
    if (session == null || session.projectId != projectId) return false;
    if (state.draft?.photoId == session.visible.photoId) return true;
    if (state.candidate != null || state.editBusy || _refining) return false;
    cancelStroke();
    _operation++;
    state = state.copyWith(
      stage: RoomMaskStage.ready,
      candidate: null,
      failure: null,
      draft: session.visible,
    );
    return true;
  }

  Future<bool> openProject(
    String projectId, {
    bool Function()? isCurrent,
    bool preserveCurrentOnFailure = false,
  }) async {
    if (!_live ||
        _refining ||
        state.editBusy ||
        state.stage == RoomMaskStage.acquiring ||
        state.stage == RoomMaskStage.analyzing) {
      return false;
    }
    final captured = state.draft;
    cancelStroke();
    final operation = ++_operation;
    bool current() =>
        _current(operation) &&
        identical(state.draft, captured) &&
        (isCurrent?.call() ?? true);
    try {
      final draft = await _session.openProject(projectId, isCurrent: current);
      if (!current() || draft == null) return false;
      state = state.copyWith(
        stage: RoomMaskStage.ready,
        candidate: null,
        failure: null,
        draft: draft,
        editBusy: _refining,
      );
      return true;
    } catch (_) {
      if (current() && !preserveCurrentOnFailure) {
        _fail(RoomMaskFailureKind.storage);
      }
      return false;
    }
  }

  Future<void> closeProject() {
    if (!_live) return Future.value();
    cancelStroke();
    _operation++;
    _photoStorageError = null;
    state = const RoomMaskState.initial();
    return _session.closeProject();
  }

  void _commitDraft() {
    unawaited(_session.commitVisibleDraft(state.draft!));
  }

  bool _canRefresh() =>
      _live &&
      !_refining &&
      !state.editBusy &&
      state.stage == RoomMaskStage.ready &&
      state.candidate == null &&
      state.draft != null;

  /// Re-analysis captures selection and session ownership before its async work.
  Future<bool> reanalyzeCurrentPhoto() async {
    if (!_canRefresh()) return false;
    cancelStroke();
    final draft = state.draft!;
    final selection = _editSelection;
    final operation = ++_operation;
    state = state.copyWith(
      stage: RoomMaskStage.analyzing,
      editBusy: true,
      failure: null,
    );
    bool current() =>
        _current(operation) &&
        selection == _editSelection &&
        identical(state.draft, draft);
    try {
      ref.invalidate(roomSegmentationServiceProvider);
      final result = await ref
          .read(roomSegmentationServiceProvider)
          .analyze(photoId: draft.photoId, photo: draft.photo);
      if (!current()) return false;
      if (result.photoId != draft.photoId ||
          result.masks.width != draft.photo.width ||
          result.masks.height != draft.photo.height) {
        throw const RoomSegmentationException(
          RoomSegmentationFailureKind.invalidOutput,
        );
      }
      return await _publishRefresh(draft, result.masks, operation, selection);
    } catch (error) {
      if (current()) {
        state = state.copyWith(
          failure: error is RoomSegmentationException
              ? switch (error.kind) {
                  RoomSegmentationFailureKind.modelUnavailable =>
                    RoomMaskFailureKind.modelUnavailable,
                  RoomSegmentationFailureKind.incompatibleModel =>
                    RoomMaskFailureKind.incompatibleModel,
                  RoomSegmentationFailureKind.invalidOutput =>
                    RoomMaskFailureKind.invalidOutput,
                  RoomSegmentationFailureKind.processing =>
                    RoomMaskFailureKind.processing,
                }
              : RoomMaskFailureKind.processing,
        );
      }
      return false;
    } finally {
      if (_current(operation) && identical(state.draft, draft)) {
        state = state.copyWith(stage: RoomMaskStage.ready, editBusy: false);
      }
    }
  }

  Future<bool> refreshAiMasks(
    MaskBitmap refreshedAi, {
    String? photoId,
    int? maskRevision,
  }) async {
    if (!_canRefresh()) return false;
    final draft = state.draft!;
    if ((photoId != null && photoId != draft.photoId) ||
        (maskRevision != null && maskRevision != draft.maskRevision) ||
        refreshedAi.width != draft.photo.width ||
        refreshedAi.height != draft.photo.height) {
      return false;
    }
    cancelStroke();
    final selection = _editSelection;
    final operation = ++_operation;
    state = state.copyWith(
      stage: RoomMaskStage.analyzing,
      editBusy: true,
      failure: null,
    );
    try {
      return await _publishRefresh(draft, refreshedAi, operation, selection);
    } catch (_) {
      if (_current(operation) &&
          selection == _editSelection &&
          identical(state.draft, draft)) {
        state = state.copyWith(failure: RoomMaskFailureKind.processing);
      }
      return false;
    } finally {
      if (_current(operation) && identical(state.draft, draft)) {
        state = state.copyWith(stage: RoomMaskStage.ready, editBusy: false);
      }
    }
  }

  Future<bool> _publishRefresh(
    RoomMaskDraft draft,
    MaskBitmap refreshedAi,
    int operation,
    int selection,
  ) async {
    final result = await compute(_mergeRefreshedMasks, (
      nextAi: refreshedAi,
      intent: draft.intent,
      history: draft.history,
    ));
    if (!_current(operation) ||
        selection != _editSelection ||
        !identical(state.draft, draft)) {
      return false;
    }
    final next = draft.copyWith(
      aiMasks: refreshedAi,
      masks: result.masks,
      history: result.history,
      maskRevision: draft.maskRevision + 1,
      changedFromAiCount: result.changedFromAiCount,
      manualMode: false,
    );
    state = state.copyWith(
      stage: RoomMaskStage.ready,
      editBusy: false,
      failure: null,
      draft: next,
    );
    _commitDraft();
    return true;
  }

  /// Stop inference while retaining prepared pixels for Analyze/Edit manually.
  void cancelAnalysis() {
    if (!_live || state.stage != RoomMaskStage.analyzing) return;
    cancelStroke();
    _operation++;
    if (state.candidate == null) {
      _returnToDraft();
      return;
    }
    state = state.copyWith(
      stage: RoomMaskStage.acquiring,
      failure: null,
      editBusy: false,
    );
  }

  /// Explicitly discard an import candidate and restore the previous draft.
  void cancelCandidate() {
    if (!_live) return;
    cancelStroke();
    _operation++;
    _returnToDraft();
  }

  void _returnToDraft() {
    _photoStorageError = null;
    state = state.copyWith(
      stage: state.draft == null ? RoomMaskStage.empty : RoomMaskStage.ready,
      candidate: null,
      failure: null,
      editBusy: state.draft != null && _refining,
    );
  }

  void _fail(RoomMaskFailureKind failure) {
    _photoStorageError = null;
    state = state.copyWith(
      stage: RoomMaskStage.error,
      failure: failure,
      editBusy: false,
    );
  }

  void setLayer(RoomLayer layer) {
    if (!_live || state.selectedLayer == layer) return;
    cancelStroke();
    state = state.copyWith(selectedLayer: layer);
  }

  bool setLayerColor(RoomLayer layer, RgbColor? color) {
    if (!_live ||
        state.stage != RoomMaskStage.ready ||
        state.editBusy ||
        state.draft == null) {
      return false;
    }
    final draft = state.draft!;
    final colors = draft.colors.withColor(layer, color);
    if (identical(colors, draft.colors)) return false;
    state = state.copyWith(
      draft: RoomMaskDraft(
        photoId: draft.photoId,
        photo: draft.photo,
        aiMasks: draft.aiMasks,
        masks: draft.masks,
        intent: draft.intent,
        history: draft.history,
        maskRevision: draft.maskRevision,
        changedFromAiCount: draft.changedFromAiCount,
        colors: colors,
        colorRevision: draft.colorRevision + 1,
        manualMode: draft.manualMode,
      ),
    );
    _commitDraft();
    return true;
  }

  /// The session already captured this variant command. Mirror its draft into
  /// the editor without generating another save or changing mask/history state.
  void adoptVariantDraft(RoomMaskDraft draft) {
    if (!_live ||
        state.editBusy ||
        state.stage != RoomMaskStage.ready ||
        state.draft?.photoId != draft.photoId ||
        state.draft?.maskRevision != draft.maskRevision) {
      return;
    }
    state = state.copyWith(draft: draft);
  }

  void setTool(RoomMaskTool tool) {
    if (!_live) return;
    final next = state.showOverlay ? tool : RoomMaskTool.move;
    if (state.tool == next) return;
    cancelStroke();
    state = state.copyWith(tool: next);
  }

  void setBrushFraction(double fraction) {
    if (!_live || !fraction.isFinite) return;
    final next = fraction.clamp(.005, .20);
    if (state.brushFraction == next) return;
    cancelStroke();
    state = state.copyWith(brushFraction: next);
  }

  void setShowOverlay(bool visible) {
    if (!_live || state.showOverlay == visible) return;
    cancelStroke();
    state = state.copyWith(
      showOverlay: visible,
      tool: visible ? state.tool : RoomMaskTool.move,
    );
  }

  bool _canMutate(String photoId, int maskRevision) =>
      _live &&
      !_refining &&
      state.canEdit &&
      state.draft!.photoId == photoId &&
      state.draft!.maskRevision == maskRevision;

  bool beginStroke(Offset sourcePoint) {
    if (_pendingStroke != null || _refining) {
      cancelStroke();
      return false;
    }
    if (!_live ||
        !_canMutate(
          state.draft?.photoId ?? '',
          state.draft?.maskRevision ?? -1,
        ) ||
        state.tool == RoomMaskTool.move) {
      return false;
    }
    final draft = state.draft!;
    final point = _sourcePoint(sourcePoint, draft);
    if (point == null) return false;
    _pendingStroke = _PendingStroke(
      draft,
      _operation,
      _editSelection,
      ref.read(roomProjectSessionProvider)?.lifetime,
      state.selectedLayer,
      state.tool,
      state.brushFraction,
      point,
    );
    return true;
  }

  MaskPoint? _sourcePoint(Offset point, RoomMaskDraft draft) =>
      !point.dx.isFinite ||
          !point.dy.isFinite ||
          point.dx < 0 ||
          point.dy < 0 ||
          point.dx >= draft.photo.width ||
          point.dy >= draft.photo.height
      ? null
      : MaskPoint(point.dx / draft.photo.width, point.dy / draft.photo.height);

  bool _ownsStroke(_PendingStroke stroke) =>
      _current(stroke.operation) &&
      stroke.selection == _editSelection &&
      identical(state.draft, stroke.draft) &&
      identical(
        ref.read(roomProjectSessionProvider)?.lifetime,
        stroke.lifetime,
      );

  bool extendStroke(Offset sourcePoint) {
    final pending = _pendingStroke;
    if (pending == null || !_ownsStroke(pending)) {
      cancelStroke();
      return false;
    }
    final point = _sourcePoint(sourcePoint, pending.draft);
    if (point == null) {
      pending.breakSegment = true;
      return false;
    }
    if (pending.breakSegment) {
      pending.segments.add([point]);
      pending.breakSegment = false;
    } else {
      pending.segments.last.add(point);
    }
    return true;
  }

  Future<bool> commitStroke() async {
    final pending = _pendingStroke;
    _pendingStroke = null;
    if (pending == null || !_ownsStroke(pending)) return false;
    return applyStroke(
      photoId: pending.draft.photoId,
      maskRevision: pending.draft.maskRevision,
      stroke: MaskStroke(
        layer: pending.layer,
        mode: pending.tool == RoomMaskTool.add
            ? MaskEditMode.add
            : MaskEditMode.erase,
        diameterFraction: pending.brush,
        segments: pending.segments,
      ),
    );
  }

  void cancelStroke() {
    _pendingStroke = null;
    _editSelection++;
  }

  Future<bool> applyStroke({
    required String photoId,
    required int maskRevision,
    required MaskStroke stroke,
  }) async {
    if (!_canMutate(photoId, maskRevision) ||
        stroke.layer != state.selectedLayer ||
        state.tool !=
            (stroke.mode == MaskEditMode.add
                ? RoomMaskTool.add
                : RoomMaskTool.erase)) {
      return false;
    }
    if (_pendingStroke != null) {
      cancelStroke();
      return false;
    }
    final draft = state.draft!;
    final operation = _operation;
    final selection = _editSelection;
    final lifetime = ref.read(roomProjectSessionProvider)?.lifetime;
    _refining = true;
    state = state.copyWith(editBusy: true, failure: null);
    bool current() =>
        _current(operation) &&
        selection == _editSelection &&
        identical(state.draft, draft) &&
        identical(ref.read(roomProjectSessionProvider)?.lifetime, lifetime);
    try {
      final result = await ref
          .read(maskRefinementServiceProvider)
          .apply(
            current: draft.masks,
            ai: draft.aiMasks,
            intent: draft.intent,
            stroke: stroke,
          );
      if (!current() || result.command == null) return false;
      final exact = result.command!.applyForward(
        masks: draft.masks,
        intent: draft.intent,
      );
      if (!listEquals(exact.masks.labels, result.masks.labels) ||
          !listEquals(exact.intent.bytes, result.intent.bytes)) {
        throw StateError('Incoherent refinement result.');
      }
      _publishExactCommand(
        draft,
        result.command!,
        MaskEditResult(masks: result.masks, intent: result.intent),
        changedFromAiCount: result.changedFromAiCount,
      );
      return true;
    } catch (_) {
      if (current()) _fail(RoomMaskFailureKind.processing);
      return false;
    } finally {
      _refining = false;
      if (_live &&
          state.editBusy &&
          (identical(state.draft, draft) ||
              state.stage == RoomMaskStage.ready)) {
        state = state.copyWith(editBusy: false);
      }
    }
  }

  /// Commit one already-previewed command through the same history/autosave
  /// path as a manual stroke. A reopened equal-key project is still stale.
  bool applyExactCommand({
    required String projectId,
    required String photoId,
    required int maskRevision,
    required RoomLayer layer,
    required Object sessionLifetime,
    required MaskEditCommand command,
  }) {
    if (!_canMutate(photoId, maskRevision) ||
        state.selectedLayer != layer ||
        _pendingStroke != null) {
      return false;
    }
    final session = ref.read(roomProjectSessionProvider);
    if (session?.projectId != projectId ||
        !identical(session?.lifetime, sessionLifetime) ||
        session?.visible.photoId != photoId ||
        session?.visible.maskRevision != maskRevision) {
      return false;
    }
    final draft = state.draft!;
    try {
      final exact = command.applyForward(
        masks: draft.masks,
        intent: draft.intent,
      );
      _publishExactCommand(
        draft,
        command,
        exact,
        changedFromAiCount: countMaskDifferences(exact.masks, draft.aiMasks),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _publishExactCommand(
    RoomMaskDraft draft,
    MaskEditCommand command,
    MaskEditResult exact, {
    required int changedFromAiCount,
  }) {
    final next = draft.copyWith(
      masks: exact.masks,
      intent: exact.intent,
      history: draft.history.push(command),
      maskRevision: draft.maskRevision + 1,
      changedFromAiCount: changedFromAiCount,
    );
    state = state.copyWith(draft: next, editBusy: false);
    _commitDraft();
  }

  Future<bool> undo({required String photoId, required int maskRevision}) =>
      _historyAction(photoId, maskRevision, false);
  Future<bool> redo({required String photoId, required int maskRevision}) =>
      _historyAction(photoId, maskRevision, true);

  Future<bool> _historyAction(String photoId, int revision, bool redo) async {
    if (!_canMutate(photoId, revision)) return false;
    cancelStroke();
    final draft = state.draft!;
    if (redo ? !draft.history.canRedo : !draft.history.canUndo) return false;
    try {
      final transition = redo
          ? draft.history.redo(masks: draft.masks, intent: draft.intent)
          : draft.history.undo(masks: draft.masks, intent: draft.intent);
      state = state.copyWith(
        draft: draft.copyWith(
          masks: transition.result.masks,
          intent: transition.result.intent,
          history: transition.history,
          maskRevision: draft.maskRevision + 1,
          changedFromAiCount: countMaskDifferences(
            transition.result.masks,
            draft.aiMasks,
          ),
        ),
        failure: null,
      );
      _commitDraft();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// UI obtains confirmation before invoking this captured revision action.
  bool restoreAiMasks({required String photoId, required int maskRevision}) {
    if (!_canMutate(photoId, maskRevision)) return false;
    cancelStroke();
    final draft = state.draft!;
    state = state.copyWith(
      draft: RoomMaskDraft(
        photoId: draft.photoId,
        photo: draft.photo,
        aiMasks: draft.aiMasks,
        masks: draft.aiMasks,
        intent: MaskIntentBitmap.untouched(
          width: draft.photo.width,
          height: draft.photo.height,
        ),
        history: MaskEditHistory.empty(
          width: draft.photo.width,
          height: draft.photo.height,
        ),
        maskRevision: draft.maskRevision + 1,
        changedFromAiCount: 0,
        colors: draft.colors,
        colorRevision: draft.colorRevision,
        manualMode: draft.manualMode,
      ),
    );
    _commitDraft();
    return true;
  }

  static RoomMaskFailureKind acquisitionFailure(AcquisitionFailureKind kind) =>
      switch (kind) {
        AcquisitionFailureKind.permissionDenied =>
          RoomMaskFailureKind.permissionDenied,
        AcquisitionFailureKind.unavailable =>
          RoomMaskFailureKind.acquisitionUnavailable,
        AcquisitionFailureKind.cameraUnavailable =>
          RoomMaskFailureKind.cameraUnavailable,
        AcquisitionFailureKind.unsupported => RoomMaskFailureKind.unsupported,
        AcquisitionFailureKind.invalidImage => RoomMaskFailureKind.invalidImage,
        AcquisitionFailureKind.tooLarge => RoomMaskFailureKind.tooLarge,
        AcquisitionFailureKind.storage => RoomMaskFailureKind.storage,
        AcquisitionFailureKind.processing ||
        AcquisitionFailureKind.recovery => RoomMaskFailureKind.preparation,
      };
}

typedef _RefreshInput = ({
  MaskBitmap nextAi,
  MaskIntentBitmap intent,
  MaskEditHistory history,
});
typedef _RefreshResult = ({
  MaskBitmap masks,
  MaskEditHistory history,
  int changedFromAiCount,
});

_RefreshResult _mergeRefreshedMasks(_RefreshInput input) {
  final masks = mergeAiWithIntent(
    refreshedAi: input.nextAi,
    intent: input.intent,
  );
  MaskEditCommand rebase(MaskEditCommand command) {
    Uint8List side(Uint8List intents) => Uint8List.fromList([
      for (var i = 0; i < command.indices.length; i++)
        intents[i] == 0
            ? input.nextAi.labels[command.indices[i]]
            : intents[i] - 1,
    ]);
    return MaskEditCommand(
      width: command.width,
      height: command.height,
      indices: command.indices,
      beforeLabels: side(command.beforeIntent),
      afterLabels: side(command.afterIntent),
      beforeIntent: command.beforeIntent,
      afterIntent: command.afterIntent,
    );
  }

  final history = MaskEditHistory.fromStacks(
    width: masks.width,
    height: masks.height,
    undoStack: input.history.undoStack.map(rebase).toList(),
    redoStack: input.history.redoStack.map(rebase).toList(),
  );
  history.validateAgainst(masks: masks, intent: input.intent);
  return (
    masks: masks,
    history: history,
    changedFromAiCount: countMaskDifferences(masks, input.nextAi),
  );
}

final class _PendingStroke {
  _PendingStroke(
    this.draft,
    this.operation,
    this.selection,
    this.lifetime,
    this.layer,
    this.tool,
    this.brush,
    MaskPoint first,
  ) : segments = [
        [first],
      ];
  final RoomMaskDraft draft;
  final int operation;
  final int selection;
  final Object? lifetime;
  final RoomLayer layer;
  final RoomMaskTool tool;
  final double brush;
  final List<List<MaskPoint>> segments;
  bool breakSegment = false;
}
