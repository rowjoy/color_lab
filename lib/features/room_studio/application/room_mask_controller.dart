import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_models.dart';
import '../../picker/application/photo_acquisition_controller.dart';
import '../../picker/domain/photo_acquisition.dart';
import '../domain/mask_bitmap.dart';
import '../domain/mask_stroke.dart';
import '../domain/mask_undo.dart';
import '../domain/room_layer.dart';
import '../domain/room_mask_state.dart';
import '../refine/mask_refinement.dart';
import '../refine/mask_refinement_service.dart';
import '../segmentation/room_segmentation_service.dart';

var _photoSequence = 0;

final roomPhotoIdFactoryProvider = Provider<String Function()>(
  (ref) =>
      () => 'room-photo-${_photoSequence++}',
);

/// Session lifetime ownership, independent of screen subscriptions or colors.
final roomMaskProvider = NotifierProvider<RoomMaskController, RoomMaskState>(
  RoomMaskController.new,
);

class RoomMaskController extends Notifier<RoomMaskState> {
  bool _alive = false;
  int _operation = 0;
  int? _claimOperation;
  int _editSelection = 0;
  bool _refining = false;

  @override
  RoomMaskState build() {
    _alive = true;
    ref.onDispose(() {
      _alive = false;
      _operation++;
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
    final operation = ++_operation;
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
        case AcquisitionFailed(:final kind):
          _fail(_acquisitionFailure(kind));
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
      final photo = await ref
          .read(photoAcquisitionProvider.notifier)
          .claim(
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
      if (photo == null) {
        final failure = ref.read(photoAcquisitionProvider).failure;
        _fail(
          failure == null
              ? RoomMaskFailureKind.acquisitionUnavailable
              : _acquisitionFailure(failure),
        );
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
          history: MaskUndoHistory(),
          maskRevision: 0,
          changedFromAiCount: 0,
        ),
      );
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
        state.stage == RoomMaskStage.error &&
        state.candidate != null) {
      await analyzeCandidate();
    }
  }

  /// Re-runs the current photo without replacing its colors or manual edits.
  Future<bool> reanalyzeCurrentPhoto() async {
    if (!_live ||
        _refining ||
        state.editBusy ||
        state.stage != RoomMaskStage.ready ||
        state.candidate != null ||
        state.draft == null) {
      return false;
    }
    final draft = state.draft!;
    final revision = draft.maskRevision;
    final operation = ++_operation;
    state = state.copyWith(
      stage: RoomMaskStage.analyzing,
      editBusy: true,
      failure: null,
    );
    bool currentDraft() =>
        _current(operation) &&
        identical(state.draft, draft) &&
        state.draft!.maskRevision == revision;
    try {
      // The service caches by PreparedPhoto identity. Explicit refresh must
      // initialize a new worker rather than reuse that photo's earlier result.
      ref.invalidate(roomSegmentationServiceProvider);
      final result = await ref
          .read(roomSegmentationServiceProvider)
          .analyze(photoId: draft.photoId, photo: draft.photo);
      if (!currentDraft()) return false;
      if (result.photoId != draft.photoId ||
          result.masks.width != draft.photo.width ||
          result.masks.height != draft.photo.height) {
        throw const RoomSegmentationException(
          RoomSegmentationFailureKind.invalidOutput,
        );
      }
      final merged = await compute(_mergeRefreshedMasks, (
        oldAi: draft.aiMasks,
        current: draft.masks,
        nextAi: result.masks,
        history: draft.history,
      ));
      if (!currentDraft()) return false;
      state = state.copyWith(
        stage: RoomMaskStage.ready,
        failure: null,
        editBusy: false,
        draft: RoomMaskDraft(
          photoId: draft.photoId,
          photo: draft.photo,
          aiMasks: result.masks,
          masks: merged.masks,
          history: merged.history,
          maskRevision: revision + 1,
          changedFromAiCount: merged.changedFromAiCount,
          colors: draft.colors,
          colorRevision: draft.colorRevision,
        ),
      );
      return true;
    } catch (error) {
      if (!currentDraft()) return false;
      state = state.copyWith(
        stage: RoomMaskStage.ready,
        editBusy: false,
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
      return false;
    }
  }

  void cancelCandidate() {
    if (!_live) return;
    _operation++;
    _returnToDraft();
  }

  void _returnToDraft() {
    state = state.copyWith(
      stage: state.draft == null ? RoomMaskStage.empty : RoomMaskStage.ready,
      candidate: null,
      failure: null,
      editBusy: state.draft != null && _refining,
    );
  }

  void _fail(RoomMaskFailureKind failure) {
    state = state.copyWith(
      stage: RoomMaskStage.error,
      failure: failure,
      editBusy: false,
    );
  }

  void setLayer(RoomLayer layer) {
    if (!_live || state.selectedLayer == layer) return;
    _editSelection++;
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
        history: draft.history,
        maskRevision: draft.maskRevision,
        changedFromAiCount: draft.changedFromAiCount,
        colors: colors,
        colorRevision: draft.colorRevision + 1,
      ),
    );
    return true;
  }

  void setTool(RoomMaskTool tool) {
    if (!_live) return;
    final next = state.showOverlay ? tool : RoomMaskTool.move;
    if (state.tool == next) return;
    _editSelection++;
    state = state.copyWith(tool: next);
  }

  void setBrushFraction(double fraction) {
    if (!_live || !fraction.isFinite) return;
    final next = fraction.clamp(.01, .20);
    if (state.brushFraction == next) return;
    _editSelection++;
    state = state.copyWith(brushFraction: next);
  }

  void setShowOverlay(bool visible) {
    if (!_live || state.showOverlay == visible) return;
    _editSelection++;
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
    final draft = state.draft!;
    return _refine(
      draft,
      undo: false,
      work: () => ref
          .read(maskRefinementServiceProvider)
          .apply(current: draft.masks, ai: draft.aiMasks, stroke: stroke),
    );
  }

  Future<bool> undo({
    required String photoId,
    required int maskRevision,
  }) async {
    if (!_canMutate(photoId, maskRevision) || !state.draft!.history.canUndo) {
      return false;
    }
    final draft = state.draft!;
    return _refine(
      draft,
      undo: true,
      work: () => ref
          .read(maskRefinementServiceProvider)
          .undo(
            current: draft.masks,
            ai: draft.aiMasks,
            command: draft.history.last!,
          ),
    );
  }

  Future<bool> _refine(
    RoomMaskDraft draft, {
    required bool undo,
    required Future<MaskEditResult> Function() work,
  }) async {
    final operation = _operation;
    final selection = _editSelection;
    _refining = true;
    state = state.copyWith(editBusy: true, failure: null);
    bool currentDraft() => _current(operation) && identical(state.draft, draft);
    try {
      final result = await work();
      if (!currentDraft() || selection != _editSelection) return false;
      if (!undo && result.undo == null) return false;
      final next = RoomMaskDraft(
        photoId: draft.photoId,
        photo: draft.photo,
        aiMasks: draft.aiMasks,
        masks: result.masks,
        history: undo
            ? draft.history.withoutLast()
            : draft.history.push(result.undo!),
        maskRevision: draft.maskRevision + 1,
        changedFromAiCount: result.changedFromAiCount,
        colors: draft.colors,
        colorRevision: draft.colorRevision,
      );
      state = state.copyWith(draft: next, editBusy: false);
      return true;
    } catch (_) {
      if (currentDraft() && selection == _editSelection) {
        _fail(RoomMaskFailureKind.processing);
      }
      return false;
    } finally {
      // No other refinement can start until this physical gate is released.
      // A replacement/cancelled ready draft also waits on this same gate;
      // release it without publishing any of the old worker's result.
      _refining = false;
      if (_live &&
          state.editBusy &&
          (currentDraft() || state.stage == RoomMaskStage.ready)) {
        state = state.copyWith(editBusy: false);
      }
    }
  }

  /// UI obtains confirmation before invoking this captured revision action.
  bool restoreAiMasks({required String photoId, required int maskRevision}) {
    if (!_canMutate(photoId, maskRevision)) return false;
    final draft = state.draft!;
    state = state.copyWith(
      draft: RoomMaskDraft(
        photoId: draft.photoId,
        photo: draft.photo,
        aiMasks: draft.aiMasks,
        masks: draft.aiMasks,
        history: MaskUndoHistory(),
        maskRevision: draft.maskRevision + 1,
        changedFromAiCount: 0,
        colors: draft.colors,
        colorRevision: draft.colorRevision,
      ),
    );
    return true;
  }

  static RoomMaskFailureKind _acquisitionFailure(AcquisitionFailureKind kind) =>
      switch (kind) {
        AcquisitionFailureKind.permissionDenied =>
          RoomMaskFailureKind.permissionDenied,
        AcquisitionFailureKind.unavailable =>
          RoomMaskFailureKind.acquisitionUnavailable,
        AcquisitionFailureKind.invalidImage => RoomMaskFailureKind.invalidImage,
        AcquisitionFailureKind.tooLarge => RoomMaskFailureKind.tooLarge,
        AcquisitionFailureKind.storage => RoomMaskFailureKind.storage,
        AcquisitionFailureKind.processing ||
        AcquisitionFailureKind.recovery => RoomMaskFailureKind.processing,
      };
}

typedef _RefreshInput = ({
  MaskBitmap oldAi,
  MaskBitmap current,
  MaskBitmap nextAi,
  MaskUndoHistory history,
});

typedef _RefreshResult = ({
  MaskBitmap masks,
  MaskUndoHistory history,
  int changedFromAiCount,
});

/// Apply the same baseline substitution to the current mask and saved undo
/// values, so undo returns to the refreshed AI rather than obsolete labels.
_RefreshResult _mergeRefreshedMasks(_RefreshInput input) {
  int rebase(int index, int label) =>
      label == input.oldAi.labels[index] ? input.nextAi.labels[index] : label;
  final labels = Uint8List(input.current.pixelCount);
  var changedFromAiCount = 0;
  for (var i = 0; i < labels.length; i++) {
    labels[i] = rebase(i, input.current.labels[i]);
    if (labels[i] != input.nextAi.labels[i]) changedFromAiCount++;
  }
  var history = MaskUndoHistory();
  for (final command in input.history.commands) {
    final previousLabels = Uint8List(command.previousLabels.length);
    for (var i = 0; i < previousLabels.length; i++) {
      previousLabels[i] = rebase(command.indices[i], command.previousLabels[i]);
    }
    history = history.push(
      MaskUndoCommand(
        width: command.width,
        height: command.height,
        indices: command.indices,
        previousLabels: previousLabels,
      ),
    );
  }
  return (
    masks: MaskBitmap(
      width: input.current.width,
      height: input.current.height,
      labels: labels,
    ),
    history: history,
    changedFromAiCount: changedFromAiCount,
  );
}
