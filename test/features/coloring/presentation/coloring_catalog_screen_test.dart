import 'package:color_lab/l10n/l10n.dart';
import 'package:color_lab/features/coloring/application/coloring_project_providers.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/presentation/coloring_catalog_screen.dart';
import 'package:color_lab/features/coloring/presentation/coloring_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/in_memory_coloring_project_repository.dart';

void main() {
  late DrawingDefinition apple;
  setUpAll(() async {
    apple = await AssetDrawingCatalogLoader().loadById('fruit_red_apple');
  });

  Future<GoRouter> launch(
    WidgetTester tester,
    InMemoryColoringProjectRepository repository,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/coloring',
      routes: [
        GoRoute(
          path: '/coloring',
          builder: (context, state) => const ColoringCatalogScreen(),
        ),
        GoRoute(
          path: '/coloring/project/:projectId',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Project workspace')),
            body: Text(state.pathParameters['projectId']!),
          ),
        ),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drawingCatalogProvider.overrideWith((ref) async => [apple]),
          coloringProjectRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  ColoringProject project(
    ColoringMode mode,
    int day, {
    bool completed = false,
  }) => ColoringProject.create(
    drawingId: apple.id,
    drawingRevision: apple.revision,
    mode: mode,
    clock: () => DateTime.utc(2026, 10, day),
  ).copyWith(completed: completed);

  testWidgets(
    'mode filter selects matching Continue projects before the four item limit',
    (tester) async {
      final repository = InMemoryColoringProjectRepository([
        project(ColoringMode.guided, 1),
        project(ColoringMode.guided, 2),
        project(ColoringMode.free, 3),
        project(ColoringMode.free, 4),
        project(ColoringMode.free, 5),
        project(ColoringMode.free, 6),
        project(ColoringMode.guided, 7, completed: true),
      ]);
      final router = await launch(tester, repository);
      expect(find.byType(ListTile), findsNWidgets(4));

      final guided = find.widgetWithText(FilterChip, 'Guided Color');
      expect(guided, findsOneWidget);
      await tester.tap(guided);
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.text('free · 0 regions'), findsNothing);
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      expect(
        find.text('fruit_red_apple-guided-1790899200000000'),
        findsOneWidget,
      );
      router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Free Color'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(4));
      expect(find.text('guided · 0 regions'), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'All modes'));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNWidgets(4));
      expect((await repository.loadSnapshot()).records, hasLength(7));
    },
  );

  testWidgets(
    'selected mode starts a separate project and retains category and difficulty after Back',
    (tester) async {
      final existing = project(ColoringMode.guided, 1);
      final repository = InMemoryColoringProjectRepository([existing]);
      final router = await launch(tester, repository);
      await tester.tap(find.widgetWithText(FilterChip, 'Fruit'));
      await tester.tap(find.widgetWithText(FilterChip, 'Easy'));
      final free = find.widgetWithText(FilterChip, 'Free Color');
      expect(free, findsOneWidget);
      await tester.tap(free);
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Animals'));
      await tester.pumpAndSettle();
      expect(find.byType(ColoringCanvas), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Fruit'));
      await tester.tap(find.widgetWithText(FilterChip, 'Hard'));
      await tester.pumpAndSettle();
      expect(find.byType(ColoringCanvas), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Easy'));
      await tester.pumpAndSettle();
      expect(find.byType(ColoringCanvas), findsOneWidget);
      await tester.tap(find.text('Red Apple'));
      await tester.pumpAndSettle();
      expect(find.text('Project workspace'), findsOneWidget);
      final records = (await repository.loadSnapshot()).records;
      expect(records, hasLength(2));
      expect(records.first.mode, ColoringMode.free);
      expect(records.first.id, isNot(existing.id));
      expect(records.last.toMap(), existing.toMap());
      router.pop();
      await tester.pumpAndSettle();
      for (final label in ['Fruit', 'Easy', 'Free Color']) {
        expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, label))
              .selected,
          isTrue,
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All modes retains mode choice and cancellation creates no project',
    (tester) async {
      final repository = InMemoryColoringProjectRepository();
      await launch(tester, repository);
      await tester.tap(find.text('Red Apple'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('coloring-mode-guided')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('coloring-mode-free')), findsOneWidget);
      await tester.tapAt(const Offset(10, 100));
      await tester.pumpAndSettle();
      expect((await repository.loadSnapshot()).records, isEmpty);
      await tester.tap(find.widgetWithText(FilterChip, 'Guided Color'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Red Apple'));
      await tester.pumpAndSettle();
      expect(find.text('Project workspace'), findsOneWidget);
      expect(
        (await repository.loadSnapshot()).records.single.mode,
        ColoringMode.guided,
      );
    },
  );

  testWidgets(
    'mode chips remain reachable with selected semantics in compact landscape',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await launch(tester, InMemoryColoringProjectRepository());
      tester.view.physicalSize = const Size(568, 320);
      await tester.pumpAndSettle();
      final free = find.widgetWithText(FilterChip, 'Free Color');
      await tester.scrollUntilVisible(free, 150);
      await tester.pumpAndSettle();
      await tester.tap(free);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(free),
        matchesSemantics(
          label: 'Free Color',
          isButton: true,
          hasFocusAction: true,
          hasSelectedState: true,
          isSelected: true,
          isEnabled: true,
          hasEnabledState: true,
          isFocusable: true,
          hasTapAction: true,
        ),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('catalog cards do not overflow at 320px and 200% text', (
    tester,
  ) async {
    await launch(tester, InMemoryColoringProjectRepository());
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Red Apple'), 200);
    expect(find.text('Red Apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
