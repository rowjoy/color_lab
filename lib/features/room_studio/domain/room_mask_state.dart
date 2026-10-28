import 'package:flutter/foundation.dart';

import '../../picker/domain/prepared_photo.dart';
import 'mask_bitmap.dart';
import 'mask_edit_history.dart';
import 'mask_intent_bitmap.dart';
import 'room_layer.dart';
import 'room_layer_colors.dart';

enum RoomMaskStage { empty, acquiring, analyzing, ready, error }

enum RoomMaskTool { move, add, erase }

enum RoomMaskFailureKind {
  permissionDenied,
  acquisitionUnavailable,
  cameraUnavailable,
  unsupported,
  preparation,
  invalidImage,
  tooLarge,
  storage,
  modelUnavailable,
  incompatibleModel,
  invalidOutput,
  processing,
}

@immutable
final class RoomPhotoCandidate {
  const RoomPhotoCandidate({required this.photoId, required this.photo});

  final String photoId;
  final PreparedPhoto photo;
}

/// Immutable working snapshots. Dirty metadata comes from the pixel worker,
/// independently of the bounded undo history; rebuilds never compare bytes.
@immutable
final class RoomMaskDraft {
  RoomMaskDraft({
    required this.photoId,
    required this.photo,
    required this.aiMasks,
    required this.masks,
    required this.history,
    MaskIntentBitmap? intent,
    required this.maskRevision,
    required this.changedFromAiCount,
    this.colors = const RoomLayerColors(),
    this.colorRevision = 0,
    this.manualMode = false,
  }) : intent =
           intent ??
           MaskIntentBitmap.untouched(
             width: masks.width,
             height: masks.height,
           ) {
    if (aiMasks.width != photo.width ||
        aiMasks.height != photo.height ||
        masks.width != photo.width ||
        masks.height != photo.height ||
        this.intent.width != photo.width ||
        this.intent.height != photo.height ||
        maskRevision < 0 ||
        colorRevision < 0 ||
        changedFromAiCount < 0 ||
        changedFromAiCount > masks.pixelCount) {
      throw ArgumentError(
        'Aligned masks and valid revision/dirty count required',
      );
    }
    history.validateAgainst(masks: masks, intent: this.intent);
  }

  final String photoId;
  final PreparedPhoto photo;
  final MaskBitmap aiMasks;
  final MaskBitmap masks;
  final MaskEditHistory history;
  final MaskIntentBitmap intent;

  final int maskRevision;
  final int changedFromAiCount;
  final RoomLayerColors colors;
  final int colorRevision;

  /// Transient/inferable presentation state; never added to schema v1.
  final bool manualMode;

  bool get hasEdits => changedFromAiCount > 0 || intent.hasExplicitIntent;

  RoomMaskDraft copyWith({
    PreparedPhoto? photo,
    MaskBitmap? aiMasks,
    MaskBitmap? masks,
    MaskIntentBitmap? intent,
    MaskEditHistory? history,
    int? maskRevision,
    int? changedFromAiCount,
    RoomLayerColors? colors,
    int? colorRevision,
    bool? manualMode,
  }) => RoomMaskDraft(
    photoId: photoId,
    photo: photo ?? this.photo,
    aiMasks: aiMasks ?? this.aiMasks,
    masks: masks ?? this.masks,
    intent: intent ?? this.intent,
    history: history ?? this.history,
    maskRevision: maskRevision ?? this.maskRevision,
    changedFromAiCount: changedFromAiCount ?? this.changedFromAiCount,
    colors: colors ?? this.colors,
    colorRevision: colorRevision ?? this.colorRevision,
    manualMode: manualMode ?? this.manualMode,
  );

  RoomMaskDraft withColors(RoomLayerColors next) => next == colors
      ? this
      : RoomMaskDraft(
          photoId: photoId,
          photo: photo,
          aiMasks: aiMasks,
          masks: masks,
          history: history,
          intent: intent,
          maskRevision: maskRevision,
          changedFromAiCount: changedFromAiCount,
          colors: next,
          colorRevision: colorRevision + 1,
          manualMode: manualMode,
        );
}

@immutable
final class RoomMaskState {
  const RoomMaskState({
    required this.stage,
    this.draft,
    this.candidate,
    this.failure,
    this.selectedLayer = RoomLayer.wall,
    this.tool = RoomMaskTool.move,
    this.brushFraction = .05,
    this.showOverlay = true,
    this.editBusy = false,
  });

  const RoomMaskState.initial() : this(stage: RoomMaskStage.empty);

  final RoomMaskStage stage;
  final RoomMaskDraft? draft;
  final RoomPhotoCandidate? candidate;
  final RoomMaskFailureKind? failure;
  final RoomLayer selectedLayer;
  final RoomMaskTool tool;
  final double brushFraction;
  final bool showOverlay;
  final bool editBusy;

  bool get canEdit =>
      stage == RoomMaskStage.ready && !editBusy && showOverlay && draft != null;

  static const _unchanged = Object();

  RoomMaskState copyWith({
    RoomMaskStage? stage,
    Object? draft = _unchanged,
    Object? candidate = _unchanged,
    Object? failure = _unchanged,
    RoomLayer? selectedLayer,
    RoomMaskTool? tool,
    double? brushFraction,
    bool? showOverlay,
    bool? editBusy,
  }) => RoomMaskState(
    stage: stage ?? this.stage,
    draft: identical(draft, _unchanged) ? this.draft : draft as RoomMaskDraft?,
    candidate: identical(candidate, _unchanged)
        ? this.candidate
        : candidate as RoomPhotoCandidate?,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as RoomMaskFailureKind?,
    selectedLayer: selectedLayer ?? this.selectedLayer,
    tool: tool ?? this.tool,
    brushFraction: brushFraction ?? this.brushFraction,
    showOverlay: showOverlay ?? this.showOverlay,
    editBusy: editBusy ?? this.editBusy,
  );
}
