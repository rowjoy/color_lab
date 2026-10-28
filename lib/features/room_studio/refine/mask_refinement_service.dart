import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mask_bitmap.dart';
import '../domain/mask_intent_bitmap.dart';
import '../domain/mask_stroke.dart';
import 'mask_refinement.dart';

abstract interface class MaskRefinementService {
  Future<MaskRefinementResult> apply({
    required MaskBitmap current,
    required MaskBitmap ai,
    required MaskIntentBitmap intent,
    required MaskStroke stroke,
  });
}

/// Stateless worker adapter; complete ownership and intent arrive together.
final class IsolateMaskRefinementService implements MaskRefinementService {
  @override
  Future<MaskRefinementResult> apply({
    required MaskBitmap current,
    required MaskBitmap ai,
    required MaskIntentBitmap intent,
    required MaskStroke stroke,
  }) => compute(_apply, (
    current: current,
    ai: ai,
    intent: intent,
    stroke: stroke,
  ));
}

MaskRefinementResult _apply(
  ({
    MaskBitmap current,
    MaskBitmap ai,
    MaskIntentBitmap intent,
    MaskStroke stroke,
  })
  request,
) => applyMaskStroke(
  current: request.current,
  ai: request.ai,
  intent: request.intent,
  stroke: request.stroke,
);

final maskRefinementServiceProvider = Provider<MaskRefinementService>(
  (ref) => IsolateMaskRefinementService(),
);
