import 'dart:async';

import 'package:color_lab/l10n/l10n.dart';
import 'package:color_lab/features/coloring/application/coloring_project_providers.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/presentation/coloring_workspace_screen.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_color_history_repository.dart';
import '../../../support/in_memory_coloring_project_repository.dart';
import '../../../support/in_memory_saved_palette_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DrawingDefinition apple;
  setUpAll(() async {
    apple = await AssetDrawingCatalogLoader().loadById('fruit_red_apple');
  });

  Future<InMemoryColoringProjectRepository> launch(
    WidgetTester tester,
    ColoringMode mode,
  ) async {
    final project = ColoringProject.create(
      drawingId: apple.id,
      drawingRevision: apple.revision,
      mode: mode,
    );
    final repository = InMemoryColoringProjectRepository([project]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coloringProjectRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          drawingCatalogProvider.overrideWith((ref) async => [apple]),
          colorHistoryRepositoryProvider.overrideWith(
            (ref) async => InMemoryColorHistoryRepository(),
          ),
          savedPaletteRepositoryProvider.overrideWith(
            (ref) async => InMemorySavedPaletteRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ColoringWorkspaceScreen(projectId: project.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('Guided mode can fill through list, labeled swatch, and Apply', (
    tester,
  ) async {
    final repository = await launch(tester, ColoringMode.guided);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    final region = find.byKey(const ValueKey('coloring-region-apple-body'));
    await tester.ensureVisible(region);
    await tester.tap(region);
    await tester.pump();

    final swatch = find.byKey(const ValueKey('color-source-#D94B45'));
    await tester.ensureVisible(swatch);
    expect(find.textContaining('1. Apple red #D94B45'), findsOneWidget);
    await tester.tap(swatch);
    await tester.pump();

    final apply = find.byKey(const ValueKey('coloring-apply-guided'));
    await tester.ensureVisible(apply);
    await tester.tap(apply);
    await tester.pumpAndSettle();

    final saved = (await repository.loadSnapshot()).records.single;
    expect(saved.assignments['apple-body']?.hex, '#D94B45');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact landscape keeps canvas and scrollable controls reachable',
    (tester) async {
      tester.view.physicalSize = const Size(568, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await launch(tester, ColoringMode.free);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });

      final customHex = find.byKey(const ValueKey('coloring-custom-hex'));
      await tester.ensureVisible(customHex);
      await tester.pump();
      expect(customHex, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late save after workspace disposal still publishes catalog state',
    (tester) async {
      final project = ColoringProject.create(
        drawingId: apple.id,
        drawingRevision: apple.revision,
        mode: ColoringMode.free,
      );
      final saveGate = Completer<void>();
      final repository = InMemoryColoringProjectRepository([project])
        ..saveGate = saveGate;
      final history = InMemoryColorHistoryRepository();
      final palettes = InMemorySavedPaletteRepository();
      final container = ProviderContainer(
        overrides: [
          coloringProjectRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          drawingCatalogProvider.overrideWith((ref) async => [apple]),
          colorHistoryRepositoryProvider.overrideWith((ref) async => history),
          savedPaletteRepositoryProvider.overrideWith((ref) async => palettes),
        ],
      );
      addTearDown(container.dispose);
      await container.read(coloringProjectsProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ColoringWorkspaceScreen(projectId: project.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final region = find.byKey(const ValueKey('coloring-region-apple-body'));
      await tester.ensureVisible(region);
      await tester.tap(region);
      await tester.pump();
      final swatch = find.byKey(
        const ValueKey('color-source-Apple red-#D94B45'),
      );
      await tester.ensureVisible(swatch);
      await tester.tap(swatch);
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      saveGate.complete();
      final saved = await repository.read(project.id);
      await tester.pump();

      expect(saved?.assignments['apple-body']?.hex, '#D94B45');
      final published = container
          .read(coloringProjectsProvider)
          .requireValue
          .single;
      expect(published.assignments['apple-body']?.hex, '#D94B45');
      expect(tester.takeException(), isNull);
    },
  );
}
