import 'package:color_lab/features/coloring/application/coloring_project_providers.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/presentation/coloring_workspace_screen.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/l10n/l10n.dart';
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

  for (final size in const [
    Size(320, 568),
    Size(844, 390),
    Size(600, 960),
    Size(1280, 800),
  ]) {
    testWidgets(
      'workspace keeps controls reachable at ${size.width}x${size.height}, 200% text, RTL',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final project = ColoringProject.create(
          drawingId: apple.id,
          drawingRevision: apple.revision,
          mode: ColoringMode.free,
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
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: child!,
                ),
              ),
              home: ColoringWorkspaceScreen(projectId: project.id),
            ),
          ),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
        await tester.pumpAndSettle();

        final customHex = find.byKey(const ValueKey('coloring-custom-hex'));
        await tester.ensureVisible(customHex);
        await tester.pump();
        final finish = find.byKey(const ValueKey('coloring-finish'));
        await tester.ensureVisible(finish);
        await tester.pump();

        expect(customHex, findsOneWidget);
        expect(finish, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
