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

  // Mutations caught: look/surface split into commands, override loss, dirty undo.
  test(
    'complete look and one region edit each form one exact undoable command',
    () {
      final container = containerFor(InMemoryRoomDesignRepository());
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.applyCompleteLook(
        IllustratedRoomCatalog.study.palette('airy-slate').colors,
      );
      final look = activeOf(container).assignments!;
      expect(activeOf(container).history.undoCommands.length, 1);
      controller.setRegionColor('wall-side', RgbColor.fromHex('#123456'));
      final edited = activeOf(container).assignments!;
      expect(activeOf(container).history.undoCommands.length, 2);
      expect(edited.regionOverrides, {
        'wall-side': RgbColor.fromHex('#123456'),
      });
      controller.undo();
      expect(activeOf(container).assignments, look);
      controller.undo();
      expect(activeOf(container).mode, IllustratedRoomVisualMode.grayscale);
      expect(activeOf(container).isDirty, isFalse);
      controller.redo();
      controller.redo();
      expect(activeOf(container).assignments!.groupColors, edited.groupColors);
      expect(
        activeOf(container).assignments!.regionOverrides,
        edited.regionOverrides,
      );
      controller.applyCompleteLook(
        IllustratedRoomCatalog.study.palette('soft-linen').colors,
      );
      expect(activeOf(container).assignments!.regionOverrides, isEmpty);
      controller.undo();
      expect(activeOf(container).assignments, edited);
    },
  );

  // Mutations caught: reset used for temporary grayscale, pinned snapshots alias edits.
  test(
    'comparison and B&W leave assignments dirty state and history intact',
    () {
      final container = containerFor(InMemoryRoomDesignRepository());
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.openDesign(savedDesign());
      final saved = activeOf(container);
      controller.pinBaseline();
      expect(activeOf(container).pinnedBaseline, saved.assignments);
      expect(activeOf(container).isDirty, isFalse);
      controller.showTemporaryGrayscale();
      final temporary = activeOf(container);
      expect(temporary.displayAssignments, isNull);
      expect(temporary.assignments, saved.assignments);
      expect(temporary.history, same(saved.history));
      expect(temporary.mode, IllustratedRoomVisualMode.colored);
      expect(temporary.isDirty, isFalse);
      controller.clearComparison();
      expect(activeOf(container).displayAssignments, saved.assignments);
      controller.setRegionColor('desk', RgbColor.fromHex('#123456'));
      final edited = activeOf(container);
      controller.showTemporaryGrayscale();
      controller.clearComparison();
      expect(activeOf(container).assignments, edited.assignments);
      expect(activeOf(container).history, same(edited.history));
      expect(activeOf(container).isDirty, isTrue);
      expect(activeOf(container).pinnedBaseline, saved.assignments);
    },
  );

  test(
    'opening migrated legacy-v2 design expands visible and pinned values',
    () {
      final container = containerFor(InMemoryRoomDesignRepository());
      final controller = container.read(illustratedRoomProvider.notifier);
      RoomDesignSnapshot snapshot(String legacyId, String color) =>
          RoomDesignSnapshot(
            groupColors: {
              'walls': '#101010',
              'ceiling': '#202020',
              'floor': '#303030',
              'furniture': '#404040',
            },
            regionOverrides: {legacyId: color},
          );
      controller.openDesign(
        SavedRoomDesign(
          id: 'living-legacy',
          name: 'Legacy living',
          templateId: 'living',
          snapshot: snapshot('legacy-furniture', '#A0A003'),
          activeBaseline: snapshot('legacy-wall', '#AA0001'),
          createdAt: now,
          updatedAt: now,
        ),
      );
      final draft = activeOf(container);
      for (final id in draft.membership.membersOf('furniture')) {
        expect(draft.assignments!.colorFor(id).hex, '#A0A003');
      }
      for (final id in draft.membership.membersOf('walls')) {
        expect(draft.pinnedBaseline!.colorFor(id).hex, '#AA0001');
      }
      expect(draft.savedAssignments, draft.assignments);
      expect(draft.isDirty, isFalse);
    },
  );

  // Mutations caught: cross-room history leakage, destructive restore, consuming no-ops.
  test(
    'pin restore and histories survive room switching and restore is undoable',
    () {
      final container = containerFor(InMemoryRoomDesignRepository());
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.setRegionColor('wall-back', RgbColor.fromHex('#123456'));
      controller.pinBaseline();
      final pinned = activeOf(container).pinnedBaseline!;
      controller.setGroupColor('furniture', RgbColor.fromHex('#654321'));
      final edited = activeOf(container).assignments!;
      controller.openTemplate(IllustratedRoomCatalog.living);
      controller.applyPalette('airy-slate');
      expect(stateOf(container).activeHistory!.undoCommands.length, 1);
      controller.openTemplate(IllustratedRoomCatalog.study);
      expect(activeOf(container).pinnedBaseline, pinned);
      expect(stateOf(container).historyFor('study')!.undoCommands.length, 2);
      controller.restoreSnapshot(pinned);
      expect(activeOf(container).assignments, pinned);
      expect(activeOf(container).history.undoCommands.length, 3);
      controller.restoreSnapshot(pinned.copyWith());
      expect(activeOf(container).history.undoCommands.length, 3);
      controller.undo();
      expect(activeOf(container).assignments, edited);
      controller.setRegionColor('desk', RgbColor.fromHex('#111111'));
      expect(activeOf(container).history.canRedo, isFalse);
      controller.restoreSnapshot(null);
      expect(activeOf(container).mode, IllustratedRoomVisualMode.grayscale);
      controller.undo();
      expect(activeOf(container).mode, IllustratedRoomVisualMode.colored);
    },
  );

  test('invalid region group and foreign snapshot edits fail atomically', () {
    final container = containerFor(InMemoryRoomDesignRepository());
    final controller = container.read(illustratedRoomProvider.notifier);
    final before = stateOf(container);
    expect(
      () => controller.setRegionColor('missing', RgbColor(1, 2, 3)),
      throwsArgumentError,
    );
    expect(
      () => controller.setGroupColor('missing', RgbColor(1, 2, 3)),
      throwsArgumentError,
    );
    expect(stateOf(container), same(before));
    controller.openTemplate(IllustratedRoomCatalog.living);
    controller.applyPalette('airy-slate');
    final foreign = activeOf(container).assignments!;
    controller.openTemplate(IllustratedRoomCatalog.study);
    expect(() => controller.restoreSnapshot(foreign), throwsArgumentError);
    expect(activeOf(container).assignments, isNull);
    controller.closeEditor();
    expect(
      () => controller.setRegionColor('desk', RgbColor(1, 2, 3)),
      throwsStateError,
    );
  });

  // Mutations caught: save/delete/rename adapters lose region overrides or baselines.
  test(
    'draft save rename discard and delete preserve exact region snapshots',
    () {
      final initial = IllustratedRoomDraft.grayscale(
        IllustratedRoomCatalog.study,
      ).setRegionColor('desk', RgbColor.fromHex('#123456'));
      final saved = initial.markSaved(id: 'study-x', name: 'Desk plan');
      expect(saved.assignments, initial.assignments);
      expect(saved.isDirty, isFalse);
      final renamed = saved.renameSavedDesign(id: 'study-x', name: 'New name');
      final dirty = renamed.setRegionColor(
        'wall-side',
        RgbColor.fromHex('#654321'),
      );
      expect(dirty.discardChanges().assignments, initial.assignments);
      expect(dirty.discardChanges().savedName, 'New name');
      final deleted = dirty.asUnsavedAfterDelete();
      expect(deleted.assignments, dirty.assignments);
      expect(deleted.savedDesignId, isNull);
      expect(deleted.isDirty, isTrue);
      expect(deleted.discardChanges().assignments, isNull);
    },
  );

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
      controller.applyPalette('airy-slate');
      controller.openTemplate(IllustratedRoomCatalog.living);
      final before = stateOf(container);
      final design = savedDesign(
        id: 'bedroom-1',
        templateId: 'bedroom',
        colors: IllustratedRoomCatalog.bedroom.palette('soft-linen').colors,
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
        colors: IllustratedRoomCatalog.bedroom.palette('quiet-sage').colors,
      );
      controller.openDesign(replacement);
      expect(activeOf(container).savedDesignId, 'bedroom-2');
    },
  );

  test(
    'Study handoff guards a dirty background target and seeds Quiet Sage',
    () {
      final container = containerFor(InMemoryRoomDesignRepository());
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.applyPalette('soft-linen');
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
      expect(draft.colors!.ceiling.hex, '#B7C2A3');
      expect(draft.colors!.floor.hex, '#78866B');
      expect(draft.colors!.furniture.hex, '#4E5B4A');
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
      controller.applyPalette('soft-linen');
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
      controller.applyPalette('quiet-sage');
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
      controller.applyPalette('airy-slate');
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

  // Catches captured-draft replacement when equal content hides newer history/comparison.
  test(
    'gated equal-content save retains newer pin temporary comparison and edit undo history',
    () async {
      final repository = InMemoryRoomDesignRepository(clock: () => now);
      final container = containerFor(repository);
      await container.read(savedRoomDesignsProvider.future);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.setRegionColor('desk', RgbColor.fromHex('#123456'));
      final captured = activeOf(container);
      repository.writeGate = Completer<void>();
      final saving = controller.saveDesign('Exact snapshot');
      await Future<void>.delayed(Duration.zero);
      controller.setRegionColor('chair', RgbColor.fromHex('#654321'));
      controller.pinBaseline();
      controller.undo();
      controller.showTemporaryGrayscale();
      final newer = activeOf(container);
      expect(newer.assignments, captured.assignments);
      repository.writeGate!.complete();
      final saved = await saving;
      final current = activeOf(container);
      expect(current.history, same(newer.history));
      expect(current.pinnedBaseline, newer.pinnedBaseline);
      expect(current.temporaryGrayscale, isTrue);
      expect(current.savedDesignId, saved.id);
      expect(current.isDirty, isFalse);
      expect(saved.snapshot.regionOverrides, {'desk': '#123456'});
      expect(saved.activeBaseline, isNull);
      controller.openDesign(saved);
      expect(activeOf(container).assignments, captured.assignments);
    },
  );

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
