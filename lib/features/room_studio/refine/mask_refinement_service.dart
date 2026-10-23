import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mask_bitmap.dart';
import '../domain/mask_stroke.dart';
import '../domain/mask_undo.dart';
import 'mask_refinement.dart';

abstract interface class MaskRefinementService {
  Future<MaskEditResult> apply({
    required MaskBitmap current,
    required MaskBitmap ai,
    required MaskStroke stroke,
  });

  Future<MaskEditResult> undo({
    required MaskBitmap current,
    required MaskBitmap ai,
    required MaskUndoCommand command,
  });
}

/// Stateless compute adapter; owns neither native handles nor project state.
final class IsolateMaskRefinementService implements MaskRefinementService {
  @override
  Future<MaskEditResult> apply({
    required MaskBitmap current,
    required MaskBitmap ai,
    required MaskStroke stroke,
  }) => compute(_apply, (current: current, ai: ai, stroke: stroke));

  @override
  Future<MaskEditResult> undo({
    required MaskBitmap current,
    required MaskBitmap ai,
    required MaskUndoCommand command,
  }) => compute(_undo, (current: current, ai: ai, command: command));
}

MaskEditResult _apply(
  ({MaskBitmap current, MaskBitmap ai, MaskStroke stroke}) request,
) => applyMaskStroke(
  current: request.current,
  ai: request.ai,
  stroke: request.stroke,
);

MaskEditResult _undo(
  ({MaskBitmap current, MaskBitmap ai, MaskUndoCommand command}) request,
) => undoMaskStroke(
  current: request.current,
  ai: request.ai,
  command: request.command,
);

final maskRefinementServiceProvider = Provider<MaskRefinementService>(
  (ref) => IsolateMaskRefinementService(),
);
