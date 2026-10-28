import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/smart_mask_proposal.dart';
import '../refine/smart_mask_proposal_service.dart';
import '../segmentation/room_wall_depth_protection.dart' show RoomDepthFrame;
import 'room_mask_controller.dart';
import 'room_project_session_controller.dart';

final smartMaskAvailabilityProvider = Provider<SmartMaskAvailability>(
  (ref) => SmartMaskAvailability.disabledByEvidence,
);

/// The only production binding. Tests may substitute a fake service; no
/// candidate implementation or enablement switch is provided by this plan.
final smartMaskProposalServiceProvider = Provider<SmartMaskProposalService>(
  (ref) => const DisabledSmartMaskProposalService(),
);

final smartMaskProposalProvider =
    NotifierProvider<SmartMaskProposalController, SmartMaskProposal?>(
      SmartMaskProposalController.new,
    );

class SmartMaskProposalController extends Notifier<SmartMaskProposal?> {
  bool _alive = false;
  Object? _pending;
  int _generation = 0;
  Object? _previewLifetime;

  @override
  SmartMaskProposal? build() {
    _alive = true;
    ref.listen(roomMaskProvider, (previous, next) {
      if (!identical(previous?.draft, next.draft) ||
          previous?.selectedLayer != next.selectedLayer ||
          !next.canEdit) {
        cancelProposal();
      }
    });
    ref.listen(roomProjectSessionProvider, (previous, next) {
      if (previous?.projectId != next?.projectId ||
          !identical(previous?.lifetime, next?.lifetime)) {
        cancelProposal();
      }
    });
    ref.onDispose(() {
      _alive = false;
      _generation++;
      _previewLifetime = null;
    });
    return null;
  }

  bool get _live => _alive && ref.mounted;

  bool _matches(SmartMaskProposalKey key) {
    if (!_live) return false;
    final editor = ref.read(roomMaskProvider);
    final session = ref.read(roomProjectSessionProvider);
    return editor.canEdit &&
        session != null &&
        session.projectId == key.projectId &&
        session.visible.photoId == key.photoId &&
        session.visible.maskRevision == key.maskRevision &&
        editor.draft?.photoId == key.photoId &&
        editor.draft?.maskRevision == key.maskRevision &&
        editor.selectedLayer == key.layer;
  }

  Future<bool> requestProposal({
    required SmartMaskProposalKey key,
    required Offset normalizedSeed,
    RoomDepthFrame? depth,
  }) async {
    if (!_live || _pending != null) return false;
    final service = ref.read(smartMaskProposalServiceProvider);
    // Return before reading editor/photo/mask/depth data in production.
    if (service is DisabledSmartMaskProposalService) return false;
    if (!normalizedSeed.dx.isFinite ||
        !normalizedSeed.dy.isFinite ||
        normalizedSeed.dx < 0 ||
        normalizedSeed.dx > 1 ||
        normalizedSeed.dy < 0 ||
        normalizedSeed.dy > 1 ||
        !_matches(key)) {
      return false;
    }
    cancelProposal();
    final generation = _generation;
    final token = Object();
    _pending = token;
    final draft = ref.read(roomMaskProvider).draft!;
    final lifetime = ref.read(roomProjectSessionProvider)!.lifetime;
    bool current() =>
        _live &&
        generation == _generation &&
        _matches(key) &&
        identical(ref.read(roomMaskProvider).draft, draft) &&
        identical(ref.read(roomProjectSessionProvider)?.lifetime, lifetime);
    try {
      final proposal = await service.propose(
        key: key,
        normalizedSeed: normalizedSeed,
        photo: draft.photo,
        aiMasks: draft.aiMasks,
        currentMasks: draft.masks,
        intent: draft.intent,
        depth: depth,
      );
      if (!current() ||
          proposal == null ||
          proposal.key != key ||
          proposal.command.width != draft.photo.width ||
          proposal.command.height != draft.photo.height) {
        return false;
      }
      final exact = proposal.command.applyForward(
        masks: draft.masks,
        intent: draft.intent,
      );
      if (!listEquals(exact.masks.labels, proposal.previewMasks.labels)) {
        return false;
      }
      _previewLifetime = lifetime;
      state = proposal;
      return true;
    } catch (_) {
      return false;
    } finally {
      if (identical(_pending, token)) _pending = null;
    }
  }

  Future<bool> applyProposal(SmartMaskProposalKey key) async {
    if (!_live || _pending != null) return false;
    final preview = state;
    final lifetime = _previewLifetime;
    if (preview == null ||
        preview.key != key ||
        !_matches(key) ||
        !identical(ref.read(roomProjectSessionProvider)?.lifetime, lifetime)) {
      return false;
    }
    // Consume synchronously before invoking the existing command/save path.
    cancelProposal();
    return ref
        .read(roomMaskProvider.notifier)
        .applyExactCommand(
          projectId: key.projectId,
          photoId: key.photoId,
          maskRevision: key.maskRevision,
          layer: key.layer,
          sessionLifetime: lifetime!,
          command: preview.command,
        );
  }

  void cancelProposal() {
    _generation++;
    _previewLifetime = null;
    if (_live) state = null;
    // A cancelled service still owns its physical in-flight slot until done.
  }
}
