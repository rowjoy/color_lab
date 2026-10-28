import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_comparison.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_editor_persistence.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_draft_store.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../support/in_memory_room_design_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final template = IllustratedRoomCatalog.study;
  IllustratedRoomDraft saved() => IllustratedRoomDraft.grayscale(
    template,
  ).applyPalette('quiet-sage').markSaved(id: 'a', name: 'A');

  test(
    'A/B original and grayscale never enter edit history or dirty state',
    () {
      final original = saved();
      final edited = original
          .setRegionColor('wall-back', RgbColor.fromHex('#ABCDEF'))
          .pinBaseline();
      final variant = original
          .setRegionColor('desk', RgbColor.fromHex('#123456'))
          .assignments!;
      for (final view in [
        edited.showPinnedBaseline(),
        edited.setComparisonVariant(variant),
        edited.showTemporaryOriginal(),
        edited.showTemporaryGrayscale(),
      ]) {
        expect(view.assignments, edited.assignments);
        expect(identical(view.history, edited.history), isTrue);
        expect(view.isDirty, edited.isDirty);
        expect(view.savedAssignments, edited.savedAssignments);
        expect(view.pinnedBaseline, edited.pinnedBaseline);
        expect(view.clearComparison().displayAssignments, edited.assignments);
        expect(view.clearComparison(), edited);
      }
      expect(
        edited.showTemporaryOriginal().displayAssignments,
        original.assignments,
      );
      expect(edited.showTemporaryGrayscale().displayAssignments, isNull);
      expect(edited.setComparisonVariant(variant).displayAssignments, variant);
    },
  );

  test(
    'pin always copies editable colors and closing preserves later edits',
    () {
      final current = saved().showTemporaryGrayscale().pinBaseline();
      expect(current.pinnedBaseline, current.assignments);
      final edited = current.setRegionColor(
        'desk',
        RgbColor.fromHex('#010203'),
      );
      expect(edited.comparison.view, IllustratedRoomComparisonView.current);
      expect(edited.clearComparison().assignments, edited.assignments);
      expect(edited.history.canUndo, isTrue);
    },
  );

  test(
    'original is the saved snapshot, while an unsaved original is grayscale',
    () {
      expect(
        saved().showTemporaryOriginal().displayAssignments,
        saved().assignments,
      );
      final unsaved = IllustratedRoomDraft.grayscale(
        template,
      ).applyPalette('quiet-sage');
      expect(unsaved.showTemporaryOriginal().displayAssignments, isNull);
      expect(unsaved.showTemporaryOriginal().temporaryGrayscale, isFalse);
    },
  );

  test(
    'copied variant survives saved identity mutation without opening it',
    () {
      final draft = saved();
      final variant = draft
          .setRegionColor('desk', RgbColor.fromHex('#222222'))
          .assignments!;
      final compared = draft.setComparisonVariant(variant);
      expect(identical(compared.comparison.snapshot, variant), isFalse);
      expect(
        compared.renameSavedDesign(id: 'a', name: 'B').displayAssignments,
        variant,
      );
      expect(compared.asUnsavedAfterDelete().displayAssignments, variant);
      expect(compared.history, draft.history);
      expect(compared.savedDesignId, 'a');
    },
  );

  test('incompatible region membership cannot be compared', () {
    final other = IllustratedRoomDraft.grayscale(
      IllustratedRoomCatalog.living,
    ).applyCompleteLook(template.defaultPalette.colors).assignments!;
    expect(() => saved().setComparisonVariant(other), throwsArgumentError);
  });

  test(
    'switching room and closing editor clear temporary view but retain pin',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.applyPalette('quiet-sage');
      controller.pinBaseline();
      controller.showTemporaryGrayscale();
      controller.openTemplate(IllustratedRoomCatalog.living);
      final retained = container
          .read(illustratedRoomProvider)
          .draftFor('study')!;
      expect(retained.comparison.isActive, isFalse);
      expect(retained.pinnedBaseline, retained.assignments);
      controller.openTemplate(template);
      controller.showTemporaryOriginal();
      controller.closeEditor();
      expect(
        container
            .read(illustratedRoomProvider)
            .draftFor('study')!
            .comparison
            .isActive,
        isFalse,
      );
    },
  );

  test(
    'temporary views do not enqueue autosave but pinned colors do',
    () async {
      final repository = InMemoryRoomDesignRepository();
      final container = ProviderContainer(
        overrides: [
          roomDesignRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);
      container.read(illustratedRoomEditorPersistenceProvider);
      final store = await container.read(
        illustratedRoomDraftStoreProvider.future,
      );
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.applyPalette('quiet-sage');
      await Future<void>.delayed(Duration.zero);
      final before = store.acknowledgedFor('study');
      controller.showTemporaryGrayscale();
      controller.showTemporaryOriginal();
      controller.clearComparison();
      await Future<void>.delayed(Duration.zero);
      expect(identical(store.acknowledgedFor('study'), before), isTrue);
      controller.pinBaseline();
      await Future<void>.delayed(Duration.zero);
      expect(
        store.restoreAcknowledged(template)!.pinnedBaseline,
        container.read(illustratedRoomProvider).activeDraft!.assignments,
      );
    },
  );
  test(
    'opening a saved design in another template clears outgoing view but retains pin',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.applyPalette('quiet-sage');
      controller.pinBaseline();
      controller.showTemporaryGrayscale();
      final before = container.read(illustratedRoomProvider).activeDraft!;
      final other = IllustratedRoomCatalog.living;
      controller.openDesign(
        SavedRoomDesign(
          id: 'living-design',
          name: 'Living',
          templateId: other.id,
          colors: other.defaultPalette.colors,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      final retained = container
          .read(illustratedRoomProvider)
          .draftFor('study')!;
      expect(retained.comparison.isActive, isFalse);
      expect(retained.pinnedBaseline, before.pinnedBaseline);
      expect(identical(retained.history, before.history), isTrue);
      expect(retained.assignments, before.assignments);
    },
  );
}
