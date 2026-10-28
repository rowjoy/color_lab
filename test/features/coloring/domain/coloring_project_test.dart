import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Guided and Free identities stay separate and edits round trip', () {
    DateTime clock() => DateTime.utc(2026, 10, 28);
    final guided = ColoringProject.create(
      drawingId: 'fruit_red_apple',
      drawingRevision: 1,
      mode: ColoringMode.guided,
      clock: clock,
    );
    final free = ColoringProject.create(
      drawingId: 'fruit_red_apple',
      drawingRevision: 1,
      mode: ColoringMode.free,
      clock: clock,
    );
    expect(guided.id, isNot(free.id));
    final filled = guided.fill(
      'apple-body',
      RgbColor.fromHex('#D94B45'),
      guided: true,
      now: DateTime.utc(2026, 10, 28, 0, 1),
    );
    expect(ColoringProject.fromMap(filled.toMap()).toMap(), filled.toMap());
    expect(filled.undo().assignments, isEmpty);
    expect(filled.undo().redo().assignments['apple-body']?.hex, '#D94B45');
  });

  test('history is bounded to the newest 50 committed edits', () {
    var project = ColoringProject.create(
      drawingId: 'fixture',
      drawingRevision: 1,
      mode: ColoringMode.free,
    );
    for (var index = 0; index < 60; index++) {
      project = project.fill('region-$index', RgbColor(index, 0, 0));
    }
    expect(project.undoStack, hasLength(50));
    expect(project.undoStack.first.regionId, 'region-10');
  });
}
