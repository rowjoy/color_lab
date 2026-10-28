import 'dart:async';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/coloring/application/coloring_session_controller.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_coloring_project_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DrawingDefinition apple;
  setUpAll(() async {
    apple = await AssetDrawingCatalogLoader().loadById('fruit_red_apple');
  });

  // Dropping a queued snapshot or letting an old acknowledgement overwrite the
  // visible draft loses a rapid fill; inspect both intermediate and final state.
  test(
    'rapid fills stay visible while ordered acknowledgements drain',
    () async {
      final project = _project(apple);
      final gate = Completer<void>();
      final repository = InMemoryColoringProjectRepository([project])
        ..saveGate = gate;
      final acknowledged = <ColoringProject>[];
      final controller = ColoringSessionController(
        repository: repository,
        definition: apple,
        project: project,
        onAcknowledged: acknowledged.add,
      );
      addTearDown(controller.dispose);
      final sessions = <ColoringSession>[];
      controller.addListener(() => sessions.add(controller.session));

      final fills = [
        controller.fillRegion('apple-body', RgbColor.fromHex('#112233')),
        controller.fillRegion('apple-leaf', RgbColor.fromHex('#445566')),
        controller.fillRegion('apple-body', RgbColor.fromHex('#778899')),
      ];
      var flushed = false;
      final flush = controller.flush().then((_) => flushed = true);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.session.visible.assignments['apple-body']!.hex,
        '#778899',
      );
      expect(
        controller.session.visible.assignments['apple-leaf']!.hex,
        '#445566',
      );
      expect(controller.session.durable.assignments, isEmpty);
      expect(acknowledged, isEmpty);
      expect(flushed, isFalse);

      gate.complete();
      expect(await Future.wait(fills), [true, true, true]);
      await flush;
      expect(acknowledged.map((item) => item.assignments['apple-body']!.hex), [
        '#112233',
        '#112233',
        '#778899',
      ]);
      expect(acknowledged.map((item) => item.assignments.length), [1, 2, 2]);
      expect(
        sessions.any(
          (session) =>
              session.durable.assignments['apple-body']?.hex == '#112233' &&
              session.visible.assignments['apple-body']?.hex == '#778899' &&
              session.saveStatus == ProjectSaveStatus.saving,
        ),
        isTrue,
      );
      expect(controller.session.saveStatus, ProjectSaveStatus.saved);
      final reopened = (await repository.read(project.id))!;
      expect(reopened.assignments['apple-body']!.hex, '#778899');
      expect(reopened.assignments['apple-leaf']!.hex, '#445566');
      expect(reopened.undoStack, hasLength(3));
      expect(controller.session.durable.toMap(), reopened.toMap());
    },
  );

  test(
    'undo redo persists history and a new fill abandons the old redo branch',
    () async {
      final project = _project(apple);
      final repository = InMemoryColoringProjectRepository([project]);
      final controller = ColoringSessionController(
        repository: repository,
        definition: apple,
        project: project,
      );
      addTearDown(controller.dispose);
      await controller.fillRegion('apple-body', RgbColor.fromHex('#112233'));
      await controller.fillRegion('apple-leaf', RgbColor.fromHex('#445566'));
      await controller.undo();
      expect(controller.session.durable.assignments.keys, ['apple-body']);
      expect(controller.session.durable.redoStack, hasLength(1));
      await controller.redo();
      expect(
        controller.session.durable.assignments['apple-leaf']!.hex,
        '#445566',
      );
      await controller.undo();
      await controller.fillRegion('apple-stem', RgbColor.fromHex('#778899'));
      await controller.redo();
      await controller.flush();
      final reopened = (await repository.read(project.id))!;
      expect(reopened.assignments.map((id, color) => MapEntry(id, color.hex)), {
        'apple-body': '#112233',
        'apple-stem': '#778899',
      });
      expect(reopened.undoStack.map((edit) => edit.regionId), [
        'apple-body',
        'apple-stem',
      ]);
      expect(reopened.redoStack, isEmpty);
      expect(reopened.mode, ColoringMode.free);
      expect(reopened.guidedFilledRegionIds, isEmpty);
    },
  );

  test(
    'dispose during a write still drains flush without notifying disposed listeners',
    () async {
      final project = _project(apple);
      final gate = Completer<void>();
      final repository = InMemoryColoringProjectRepository([project])
        ..saveGate = gate;
      final acknowledged = <ColoringProject>[];
      final controller = ColoringSessionController(
        repository: repository,
        definition: apple,
        project: project,
        onAcknowledged: acknowledged.add,
      );
      var notifications = 0;
      controller.addListener(() => notifications++);
      final body = controller.fillRegion(
        'apple-body',
        RgbColor.fromHex('#112233'),
      );
      final leaf = controller.fillRegion(
        'apple-leaf',
        RgbColor.fromHex('#445566'),
      );
      var flushed = false;
      final flush = controller.flush().then((_) => flushed = true);
      await Future<void>.delayed(Duration.zero);
      expect(flushed, isFalse);
      final beforeDispose = notifications;
      controller.dispose();
      gate.complete();
      await Future.wait([body, leaf]);
      await flush;

      expect(notifications, beforeDispose);
      expect(acknowledged, hasLength(2));
      final reopened = (await repository.read(project.id))!;
      expect(reopened.assignments.map((id, color) => MapEntry(id, color.hex)), {
        'apple-body': '#112233',
        'apple-leaf': '#445566',
      });
      expect(repository.closed, isFalse);
    },
  );

  test(
    'Guided history restores progress and finish acknowledges only complete work',
    () async {
      final project = _project(apple, mode: ColoringMode.guided);
      final repository = InMemoryColoringProjectRepository([project]);
      final controller = ColoringSessionController(
        repository: repository,
        definition: apple,
        project: project,
      );
      addTearDown(controller.dispose);
      expect(await controller.finish(), isFalse);
      expect(controller.session.focusedRegionId, 'apple-body');
      for (final region in apple.artwork.regions) {
        await controller.fillRegion(
          region.id,
          apple.slotById(apple.regionRules[region.id]!.targetSlotId!).color,
        );
      }
      expect(controller.progress, 1);
      await controller.undo();
      expect(controller.filledRequiredCount, 3);
      expect(controller.session.durable.guidedFilledRegionIds, hasLength(3));
      expect(await controller.finish(), isFalse);
      await controller.redo();
      expect(controller.session.durable.guidedFilledRegionIds, hasLength(4));
      expect(await controller.finish(), isTrue);
      final reopened = (await repository.read(project.id))!;
      expect(reopened.completed, isTrue);
      expect(reopened.mode, ColoringMode.guided);
      expect(
        reopened.guidedFilledRegionIds,
        apple.artwork.regions.map((region) => region.id).toSet(),
      );
      await controller.undo();
      expect(controller.session.durable.completed, isFalse);
    },
  );

  for (final mismatch in ['drawing', 'revision']) {
    test('rejects a project with a different $mismatch', () {
      final project = ColoringProject.create(
        drawingId: mismatch == 'drawing' ? 'another_drawing' : apple.id,
        drawingRevision: mismatch == 'revision'
            ? apple.revision + 1
            : apple.revision,
        mode: ColoringMode.free,
      );
      expect(
        () => ColoringSessionController(
          repository: InMemoryColoringProjectRepository([project]),
          definition: apple,
          project: project,
        ),
        throwsArgumentError,
      );
    });
  }
}

ColoringProject _project(
  DrawingDefinition drawing, {
  ColoringMode mode = ColoringMode.free,
}) => ColoringProject.create(
  drawingId: drawing.id,
  drawingRevision: drawing.revision,
  mode: mode,
);
