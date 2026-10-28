import 'package:flutter/foundation.dart';

import 'mask_bitmap.dart';
import 'mask_edit_command.dart';
import 'room_layer.dart';

/// No enabled production state exists before the external evidence gate.
enum SmartMaskAvailability { disabledByEvidence }

enum SmartMaskAction { add, remove, cleanup }

@immutable
final class SmartMaskProposalKey {
  SmartMaskProposalKey({
    required this.projectId,
    required this.photoId,
    required this.maskRevision,
    required this.layer,
    required this.action,
  }) {
    if (projectId.isEmpty || photoId.isEmpty || maskRevision < 0) {
      throw ArgumentError(
        'A project, photo and nonnegative revision are required.',
      );
    }
  }

  final String projectId;
  final String photoId;
  final int maskRevision;
  final RoomLayer layer;
  final SmartMaskAction action;

  @override
  bool operator ==(Object other) =>
      other is SmartMaskProposalKey &&
      projectId == other.projectId &&
      photoId == other.photoId &&
      maskRevision == other.maskRevision &&
      layer == other.layer &&
      action == other.action;

  @override
  int get hashCode =>
      Object.hash(projectId, photoId, maskRevision, layer, action);
}

/// Ephemeral preview only; never serialized into a project or history.
@immutable
final class SmartMaskProposal {
  SmartMaskProposal({
    required this.key,
    required this.command,
    required this.previewMasks,
  }) {
    if (command.width != previewMasks.width ||
        command.height != previewMasks.height) {
      throw ArgumentError('Preview and exact command dimensions must align.');
    }
  }

  final SmartMaskProposalKey key;
  final MaskEditCommand command;
  final MaskBitmap previewMasks;
}
