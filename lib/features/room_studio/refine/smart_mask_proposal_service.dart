import 'dart:ui' show Offset;

import '../../picker/domain/prepared_photo.dart';
import '../domain/mask_bitmap.dart';
import '../domain/mask_intent_bitmap.dart';
import '../domain/smart_mask_proposal.dart';
import '../segmentation/room_wall_depth_protection.dart' show RoomDepthFrame;

abstract interface class SmartMaskProposalService {
  Future<SmartMaskProposal?> propose({
    required SmartMaskProposalKey key,
    required Offset normalizedSeed,
    required PreparedPhoto photo,
    required MaskBitmap aiMasks,
    required MaskBitmap currentMasks,
    required MaskIntentBitmap intent,
    required RoomDepthFrame? depth,
  });
}

/// Deliberately does not validate, inspect or forward any user data.
final class DisabledSmartMaskProposalService
    implements SmartMaskProposalService {
  const DisabledSmartMaskProposalService();

  @override
  Future<SmartMaskProposal?> propose({
    required SmartMaskProposalKey key,
    required Offset normalizedSeed,
    required PreparedPhoto photo,
    required MaskBitmap aiMasks,
    required MaskBitmap currentMasks,
    required MaskIntentBitmap intent,
    required RoomDepthFrame? depth,
  }) async => null;
}
