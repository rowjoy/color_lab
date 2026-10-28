import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_surface_status.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_acquisition_intent_store.dart';
import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/mask_edit_fixtures.dart';

void main() {
  test('manual review surface and original recolored overlay switches preserve exact draft and saves', () async {
    final source = maskHistoryProjectFixture();
    final repository = InMemoryRoomProjectRepository(initial: [source]);
    var saves = 0; repository.beforeSave = () async { saves++; };
    final container = ProviderContainer(overrides: [
      roomProjectRepositoryProvider.overrideWith((ref) async => repository),
      acquisitionIntentStoreProvider.overrideWith((ref) async => InMemoryAcquisitionIntentStore()),
    ]);
    addTearDown(() async {
      await container.read(roomProjectSessionProvider.notifier).closeProject();
      container.dispose(); await repository.close();
    });
    final controller = container.read(roomMaskProvider.notifier);
    expect(await controller.openProject(source.projectId), isTrue);
    final before = container.read(roomMaskProvider).draft!;
    for (final layer in RoomLayer.values) {
      controller.setLayer(layer);
      for (final view in RoomMaskReviewView.values) {
        controller.setShowOverlay(view == RoomMaskReviewView.overlay);
        final next = container.read(roomMaskProvider).draft!;
        expect(next, same(before));
        expect(next.masks.labels, source.maskBytes);
        expect(next.intent.bytes, source.intent.bytes);
        expect(next.history.undoStack, hasLength(1));
        expect(next.history.redoStack, hasLength(1));
      }
    }
    expect(saves, 0);
    expect((await repository.read(source.projectId))!.snapshot.revision, 1);
  });
}
