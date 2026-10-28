import 'package:color_lab/core/color/color_engine.dart' show HarmonyMode;
import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/coloring/application/coloring_project_providers.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/presentation/coloring_workspace_screen.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_color_history_repository.dart';
import '../../../support/in_memory_coloring_project_repository.dart';
import '../../../support/in_memory_saved_palette_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Free Color copies saved and custom values with region-first undo/redo',
    (tester) async {
      final apple = await AssetDrawingCatalogLoader().loadById(
        'fruit_red_apple',
      );
      final project = ColoringProject.create(
        drawingId: apple.id,
        drawingRevision: apple.revision,
        mode: ColoringMode.free,
      );
      final projects = InMemoryColoringProjectRepository([project]);
      final history = InMemoryColorHistoryRepository(
        colors: [
          SavedColor(
            id: '#123456',
            hex: '#123456',
            name: 'Study teal',
            isFavorite: false,
            createdAt: DateTime.utc(2026, 10, 28),
            source: ColorSource.lab,
          ),
        ],
      );
      final palettes = InMemorySavedPaletteRepository(
        palettes: [
          SavedPalette(
            name: 'Study palette',
            base: RgbColor.fromHex('#654321'),
            mode: HarmonyMode.analogous,
            colors: [RgbColor.fromHex('#654321'), RgbColor.fromHex('#ABCDEF')],
            createdAt: DateTime.utc(2026, 10, 28),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coloringProjectRepositoryProvider.overrideWith(
              (ref) async => projects,
            ),
            drawingCatalogProvider.overrideWith((ref) async => [apple]),
            colorHistoryRepositoryProvider.overrideWith((ref) async => history),
            savedPaletteRepositoryProvider.overrideWith(
              (ref) async => palettes,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ColoringWorkspaceScreen(projectId: project.id),
          ),
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await history.close();
        await palettes.close();
      });
      await tester.pumpAndSettle();

      final savedSwatch = find.byKey(
        const ValueKey('color-source-Study teal #123456-#123456'),
      );
      await tester.ensureVisible(savedSwatch);
      await tester.tap(savedSwatch);
      await tester.pump();
      expect(find.text('Choose a region first.'), findsOneWidget);
      expect((await projects.read(project.id))!.assignments, isEmpty);

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('coloring-region-apple-body')),
      );
      await _tapVisible(tester, savedSwatch);
      await tester.pumpAndSettle();
      expect(
        (await projects.read(project.id))!.assignments['apple-body']?.hex,
        '#123456',
      );

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('coloring-region-apple-leaf')),
      );
      final custom = find.byKey(const ValueKey('coloring-custom-hex'));
      await tester.ensureVisible(custom);
      await tester.enterText(custom, '#12');
      await tester.tap(find.byTooltip('Use custom color'));
      await tester.pump();
      expect(find.text('Enter a six-digit HEX color.'), findsOneWidget);

      await tester.enterText(custom, '#ABCDEF');
      await tester.tap(find.byTooltip('Use custom color'));
      await tester.pumpAndSettle();
      expect(
        (await projects.read(project.id))!.assignments['apple-leaf']?.hex,
        '#ABCDEF',
      );

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('coloring-region-apple-stem')),
      );
      await _tapVisible(
        tester,
        find.byKey(
          const ValueKey('color-source-Study palette #654321-#654321'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (await projects.read(project.id))!.assignments['apple-stem']?.hex,
        '#654321',
      );

      await _tapVisible(
        tester,
        find.byKey(const ValueKey('coloring-region-apple-highlight')),
      );
      await _tapVisible(
        tester,
        find.byKey(const ValueKey('color-source-Highlight cream-#F7D7C4')),
      );
      await tester.pumpAndSettle();
      expect(
        (await projects.read(project.id))!.assignments['apple-highlight']?.hex,
        '#F7D7C4',
      );

      await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Undo'));
      await tester.pumpAndSettle();
      expect(
        (await projects.read(project.id))!.assignments['apple-highlight'],
        isNull,
      );
      await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Redo'));
      await tester.pumpAndSettle();
      expect(
        (await projects.read(project.id))!.assignments['apple-highlight']?.hex,
        '#F7D7C4',
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}
