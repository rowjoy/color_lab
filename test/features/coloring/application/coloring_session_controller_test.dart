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

  test(
    'Guided wrong color is a no-op and exact target is acknowledged',
    () async {
      final project = ColoringProject.create(
        drawingId: apple.id,
        drawingRevision: apple.revision,
        mode: ColoringMode.guided,
      );
      final repository = InMemoryColoringProjectRepository([project]);
      final controller = ColoringSessionController(
        repository: repository,
        definition: apple,
        project: project,
      );
      expect(
        await controller.fillRegion('apple-body', RgbColor.fromHex('#4F8A4C')),
        isFalse,
      );
      expect(controller.session.visible.assignments, isEmpty);
      expect(
        await controller.fillRegion('apple-body', RgbColor.fromHex('#D94B45')),
        isTrue,
      );
      expect(
        controller.session.durable.assignments['apple-body']?.hex,
        '#D94B45',
      );
      controller.dispose();
    },
  );

  test('failed save keeps visible draft and retry acknowledges it', () async {
    final project = ColoringProject.create(
      drawingId: apple.id,
      drawingRevision: apple.revision,
      mode: ColoringMode.free,
    );
    final repository = InMemoryColoringProjectRepository([project])
      ..failNextSave = true;
    final controller = ColoringSessionController(
      repository: repository,
      definition: apple,
      project: project,
    );
    await expectLater(
      controller.fillRegion('apple-body', RgbColor.fromHex('#123456')),
      throwsA(anything),
    );
    expect(
      controller.session.visible.assignments['apple-body']?.hex,
      '#123456',
    );
    expect(controller.session.durable.assignments, isEmpty);
    expect(controller.session.saveStatus, ProjectSaveStatus.failed);
    await controller.retrySave();
    expect(
      controller.session.durable.assignments['apple-body']?.hex,
      '#123456',
    );
    expect(controller.session.saveStatus, ProjectSaveStatus.saved);
    controller.dispose();
  });

  test('acknowledged saves publish the exact durable project', () async {
    final project = ColoringProject.create(
      drawingId: apple.id,
      drawingRevision: apple.revision,
      mode: ColoringMode.free,
    );
    final repository = InMemoryColoringProjectRepository([project]);
    ColoringProject? published;
    final controller = ColoringSessionController(
      repository: repository,
      definition: apple,
      project: project,
      onAcknowledged: (value) => published = value,
    );

    await controller.fillRegion('apple-body', RgbColor.fromHex('#123456'));

    expect(published?.assignments['apple-body']?.hex, '#123456');
    expect((await repository.read(project.id))!.toMap(), published!.toMap());
    controller.dispose();
  });

  test('finish rejects a later edit even when both saves succeed', () async {
    final project = ColoringProject.create(
      drawingId: apple.id,
      drawingRevision: apple.revision,
      mode: ColoringMode.free,
    ).fill('apple-body', RgbColor.fromHex('#D94B45'));
    final repository = InMemoryColoringProjectRepository([project]);
    final controller = ColoringSessionController(
      repository: repository,
      definition: apple,
      project: project,
    );
    final gate = Completer<void>();
    repository.saveGate = gate;

    final finishing = controller.finish();
    await Future<void>.delayed(Duration.zero);
    final laterEdit = controller.fillRegion(
      'apple-leaf',
      RgbColor.fromHex('#112233'),
    );
    gate.complete();

    expect(await finishing, isFalse);
    await laterEdit;
    expect(controller.session.visible.completed, isFalse);
    expect(
      controller.session.durable.assignments['apple-leaf']?.hex,
      '#112233',
    );
    controller.dispose();
  });
}
