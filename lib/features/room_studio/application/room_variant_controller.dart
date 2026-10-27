import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/room_layer_colors.dart';
import '../domain/room_mask_state.dart';
import '../domain/room_project.dart';
import 'room_mask_controller.dart';
import 'room_project_session_controller.dart';
import 'room_projects_providers.dart';

final roomVariantProvider =
    NotifierProvider<RoomVariantController, RoomVariantSet?>(
      RoomVariantController.new,
    );

/// Commands delegate all persistence and failure ownership to the session.
class RoomVariantController extends Notifier<RoomVariantSet?> {
  @override
  RoomVariantSet? build() =>
      ref.watch(roomProjectSessionProvider.select((s) => s?.variantSet));

  RoomVariantSet _current() {
    final session = ref.read(roomProjectSessionProvider);
    final editor = ref.read(roomMaskProvider);
    if (session == null ||
        editor.editBusy ||
        (editor.draft != null &&
            (editor.stage != RoomMaskStage.ready ||
                editor.draft!.photoId != session.visible.photoId))) {
      throw const RoomVariantException(RoomVariantFailure.unavailable);
    }
    return session.variantSet;
  }

  Future<void> _apply(RoomVariantSet next) {
    final done = ref
        .read(roomProjectSessionProvider.notifier)
        .commitVariants(next);
    ref
        .read(roomMaskProvider.notifier)
        .adoptVariantDraft(ref.read(roomProjectSessionProvider)!.visible);
    return done;
  }

  Future<void> createVariant(String name) async {
    final current = _current();
    final factory = ref.read(roomProjectIdFactoryProvider);
    for (var attempt = 0; attempt < 5; attempt++) {
      final id = factory();
      if (RoomProjectLimits.validId(id) &&
          !current.variants.any((v) => v.id == id)) {
        return _apply(current.create(id, name));
      }
    }
    throw const RoomVariantException(RoomVariantFailure.invalidId);
  }

  Future<void> renameVariant(String id, String name) async =>
      _apply(_current().rename(id, name));
  Future<void> selectVariant(String id) async => _apply(_current().select(id));
  Future<void> updateVariantColors(RoomLayerColors colors) async {
    final current = _current();
    if (current.active.colors == colors) return;
    return _apply(current.updateColors(colors));
  }

  Future<void> deleteVariant(String id) async => _apply(_current().delete(id));
  Future<void> pinComparisonBaseline(String id) async =>
      _apply(_current().pin(id));
  Future<void> clearComparison() async => _apply(_current().clearComparison());
}
