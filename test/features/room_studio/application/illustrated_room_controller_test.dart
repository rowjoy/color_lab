import 'dart:async';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_session.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_design_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 25, 4);

  ProviderContainer containerFor(InMemoryRoomDesignRepository repository) {
    final container = ProviderContainer(
      overrides: [
        roomDesignRepositoryProvider.overrideWith((ref) async => repository),
        roomDesignClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  SavedRoomDesign savedDesign({
    String id = 'study-1',
    String name = 'Saved study',
    String templateId = 'study',
    IllustratedRoomColors? colors,
  }) {
    final template = IllustratedRoomCatalog.maybeById(templateId);
    return SavedRoomDesign(
      id: id,
      name: name,
      templateId: templateId,
      colors: colors ?? template!.defaultPalette.colors,
      createdAt: now,
      updatedAt: now,
    );
  }

  IllustratedRoomSession stateOf(ProviderContainer container) =>
      container.read(illustratedRoomProvider);

  IllustratedRoomDraft activeOf(ProviderContainer container) =>
      stateOf(container).activeDraft!;

  test(
    'retains six independent drafts and supports active close and discard',
    () {
      final container = containerFor(InMemoryRoomDesignRepository());
      final controller = container.read(illustratedRoomProvider.notifier);

      expect(activeOf(container).template.id, 'study');
      expect(activeOf(container).mode, IllustratedRoomVisualMode.grayscale);
      for (final room in IllustratedRoomCatalog.all) {
        controller.openTemplate(room);
        controller.applyPalette(room.defaultPaletteId);
      }

      expect(stateOf(container).draftsByTemplateId.keys.toSet(), {
        'living',
        'bedroom',
        'study',
        'dining',
        'kitchen',
        'bathroom',
      });
      expect(stateOf(container).activeTemplateId, 'bathroom');
      controller.discardActiveChanges();
      expect(activeOf(container).mode, IllustratedRoomVisualMode.grayscale);
      expect(activeOf(container).isDirty, isFalse);
      expect(
        stateOf(container).draftFor('living')?.sourcePaletteId,
        IllustratedRoomCatalog.living.defaultPaletteId,
      );

      controller.closeEditor();
      expect(stateOf(container).activeTemplateId, isNull);
      expect(stateOf(container).activeDraft, isNull);
      expect(stateOf(container).draftsByTemplateId.length, 6);
    },
  );

  test(
    'dirty saved-design target rejects replacement without any mutation',
    () {
      final container = containerFor(InMemoryRoomDesignRepository());
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.openTemplate(IllustratedRoomCatalog.bedroom);
      controller.applyPalette('cool-airy');
      controller.openTemplate(IllustratedRoomCatalog.living);
      final before = stateOf(container);
      final design = savedDesign(
        id: 'bedroom-1',
        templateId: 'bedroom',
        colors: IllustratedRoomCatalog.bedroom.palette('warm-natural').colors,
      );

      expect(
        () => controller.openDesign(design),
        throwsA(
          isA<IllustratedRoomDraftConflict>().having(
            (error) => error.templateId,
            'templateId',
            'bedroom',
          ),
        ),
      );
      expect(stateOf(container), same(before));

      controller.openDesign(design, replaceDirty: true);
      expect(stateOf(container).activeTemplateId, 'bedroom');
      expect(activeOf(container).savedDesignId, 'bedroom-1');
      expect(activeOf(container).isDirty, isFalse);

      final replacement = savedDesign(
        id: 'bedroom-2',
        name: 'Second bedroom',
        templateId: 'bedroom',
        colors: IllustratedRoomCatalog.bedroom.palette('soft-botanical').colors,
      );
      controller.openDesign(replacement);
      expect(activeOf(container).savedDesignId, 'bedroom-2');
    },
  );

  test(
    'Study handoff guards a dirty background target and seeds Soft Botanical',
    () {
      final container = containerFor(InMemoryRoomDesignRepository());
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.applyPalette('warm-natural');
      controller.openTemplate(IllustratedRoomCatalog.living);
      final before = stateOf(container);

      expect(
        () => controller.applyWallHandoff(RgbColor.fromHex('#123456')),
        throwsA(isA<IllustratedRoomDraftConflict>()),
      );
      expect(stateOf(container), same(before));

      controller.applyWallHandoff(
        RgbColor.fromHex('#123456'),
        replaceDirty: true,
      );
      final draft = activeOf(container);
      expect(draft.template.id, 'study');
      expect(draft.colors!.wall.hex, '#123456');
      expect(draft.colors!.ceiling.hex, '#F8F4EB');
      expect(draft.colors!.floor.hex, '#C6AC84');
      expect(draft.colors!.furniture.hex, '#654A39');
      expect(draft.savedDesignId, isNull);
      expect(draft.isDirty, isTrue);
    },
  );

  test(
    'background save marks only its captured target clean and keeps activation',
    () async {
      final repository = InMemoryRoomDesignRepository(clock: () => now);
      final container = containerFor(repository);
      await container.read(savedRoomDesignsProvider.future);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.openTemplate(IllustratedRoomCatalog.living);
      controller.applyPalette('warm-natural');
      controller.openTemplate(IllustratedRoomCatalog.study);

      final saved = await controller.saveDesign(
        'Living plan',
        templateId: 'living',
      );

      expect(saved.templateId, 'living');
      expect(stateOf(container).activeTemplateId, 'study');
      final living = stateOf(container).draftFor('living')!;
      expect(living.savedDesignId, saved.id);
      expect(living.savedName, 'Living plan');
      expect(living.isDirty, isFalse);
    },
  );

  test(
    'gated target save persists snapshot while a newer target edit stays dirty',
    () async {
      final repository = InMemoryRoomDesignRepository(clock: () => now);
      final container = containerFor(repository);
      await container.read(savedRoomDesignsProvider.future);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.openTemplate(IllustratedRoomCatalog.living);
      controller.applyPalette('soft-botanical');
      final captured = activeOf(container);
      repository.writeGate = Completer<void>();

      final saving = controller.saveDesign(
        'Captured living',
        templateId: 'living',
      );
      await Future<void>.delayed(Duration.zero);
      controller.setSurfaceColor(
        IllustratedRoomSurface.furniture,
        RgbColor.fromHex('#010203'),
      );
      repository.writeGate!.complete();
      final saved = await saving;

      expect(saved.colors, captured.colors);
      final current = stateOf(container).draftFor('living')!;
      expect(current.colors!.furniture.hex, '#010203');
      expect(current.savedDesignId, isNull);
      expect(current.isDirty, isTrue);
      expect((await repository.load()).single, saved);
    },
  );

  test(
    'rename success reconciles matching foreground and background baselines',
    () async {
      final stored = savedDesign(id: 'shared', name: 'Old study');
      final repository = InMemoryRoomDesignRepository(
        designs: [stored],
        clock: () => now.add(const Duration(minutes: 1)),
      );
      final container = containerFor(repository);
      await container.read(savedRoomDesignsProvider.future);
      final controller = container.read(illustratedRoomProvider.notifier);

      controller.openDesign(
        savedDesign(id: 'shared', name: 'Old living', templateId: 'living'),
      );
      controller.setSurfaceColor(
        IllustratedRoomSurface.wall,
        RgbColor.fromHex('#010203'),
      );
      controller.openDesign(stored);

      final renamed = await controller.renameDesign(
        'shared',
        'Shared new name',
      );

      expect(renamed.name, 'Shared new name');
      final session = stateOf(container);
      expect(session.draftFor('living')?.savedName, 'Shared new name');
      expect(session.draftFor('living')?.isDirty, isTrue);
      expect(session.draftFor('study')?.savedName, 'Shared new name');
      expect(session.draftFor('study')?.isDirty, isFalse);
      expect(
        session.draftFor('living')!.discardChanges().savedName,
        'Shared new name',
      );
    },
  );

  test(
    'delete success clears every matching identity with fresh baselines',
    () async {
      final stored = savedDesign(id: 'shared', name: 'Shared design');
      final repository = InMemoryRoomDesignRepository(designs: [stored]);
      final container = containerFor(repository);
      await container.read(savedRoomDesignsProvider.future);
      final controller = container.read(illustratedRoomProvider.notifier);

      controller.openDesign(
        savedDesign(id: 'shared', name: 'Shared design', templateId: 'living'),
      );
      controller.openDesign(stored);
      controller.resetToGrayscale();

      await controller.deleteDesign('shared');

      final living = stateOf(container).draftFor('living')!;
      expect(living.mode, IllustratedRoomVisualMode.colored);
      expect(living.savedDesignId, isNull);
      expect(living.isDirty, isTrue);
      expect(living.canSave, isTrue);
      final study = stateOf(container).draftFor('study')!;
      expect(study.mode, IllustratedRoomVisualMode.grayscale);
      expect(study.savedDesignId, isNull);
      expect(study.isDirty, isFalse);
      expect(await repository.load(), isEmpty);
    },
  );

  test(
    'repository write failures leave every retained draft unchanged',
    () async {
      final stored = savedDesign(id: 'shared', name: 'Stored');
      final repository = InMemoryRoomDesignRepository(designs: [stored]);
      final container = containerFor(repository);
      await container.read(savedRoomDesignsProvider.future);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.openDesign(stored);
      controller.openTemplate(IllustratedRoomCatalog.living);
      controller.applyPalette('cool-airy');
      final before = stateOf(container);
      repository.failWrites = true;

      await expectLater(
        controller.renameDesign('shared', 'Will fail'),
        throwsA(isA<RoomDesignStorageException>()),
      );
      expect(stateOf(container), same(before));
      await expectLater(
        controller.deleteDesign('shared'),
        throwsA(isA<RoomDesignStorageException>()),
      );
      expect(stateOf(container), same(before));
    },
  );

  test('unavailable saved template fails without mutation', () {
    final container = containerFor(InMemoryRoomDesignRepository());
    final controller = container.read(illustratedRoomProvider.notifier);
    final before = stateOf(container);

    expect(
      () => controller.openDesign(
        savedDesign(
          templateId: 'future-library',
          colors: IllustratedRoomCatalog.study.defaultPalette.colors,
        ),
      ),
      throwsArgumentError,
    );
    expect(stateOf(container), same(before));
  });

  test('default design name uses template title and local calendar date', () {
    expect(
      defaultRoomDesignName(
        IllustratedRoomCatalog.study,
        DateTime(2026, 1, 2, 23, 59),
      ),
      'Study room - 2026-01-02',
    );
  });
}
