import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/color/color_engine.dart' show HarmonyMode;
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_color_history_repository.dart';
import '../../support/in_memory_coloring_project_repository.dart';
import '../../support/in_memory_saved_palette_repository.dart';

void main() {
  test(
    'project keeps copied color values after source records are deleted',
    () async {
      final savedColor = SavedColor(
        id: '#123456',
        hex: '#123456',
        name: 'Study teal',
        isFavorite: false,
        createdAt: DateTime.utc(2026, 10, 28),
        source: ColorSource.lab,
      );
      final savedPalette = SavedPalette(
        name: 'Study palette',
        base: RgbColor.fromHex('#654321'),
        mode: HarmonyMode.analogous,
        colors: [RgbColor.fromHex('#654321'), RgbColor.fromHex('#ABCDEF')],
        createdAt: DateTime.utc(2026, 10, 28),
      );
      final colors = InMemoryColorHistoryRepository(colors: [savedColor]);
      final palettes = InMemorySavedPaletteRepository(palettes: [savedPalette]);
      final projectStore = InMemoryColoringProjectRepository();
      addTearDown(() async {
        await colors.close();
        await palettes.close();
        await projectStore.close();
      });

      final project =
          ColoringProject.create(
                drawingId: 'fruit_red_apple',
                drawingRevision: 1,
                mode: ColoringMode.free,
              )
              .fill('apple-body', RgbColor.fromHex(savedColor.hex))
              .fill('apple-leaf', savedPalette.colors[1]);
      await projectStore.save(project);

      await colors.delete(savedColor.id);
      await palettes.delete(savedPalette.id);

      final reopened = await projectStore.read(project.id);
      expect(reopened?.assignments['apple-body']?.hex, '#123456');
      expect(reopened?.assignments['apple-leaf']?.hex, '#ABCDEF');
      expect(reopened?.toMap().toString(), isNot(contains(savedPalette.id)));
      expect(reopened?.toMap().toString(), isNot(contains(savedColor.name)));
    },
  );
}
