import 'dart:async';

import 'package:color_lab/features/coloring/application/coloring_project_providers.dart';
import 'package:color_lab/features/coloring/presentation/coloring_catalog_screen.dart';
import 'package:color_lab/features/coloring/presentation/coloring_completion_screen.dart';
import 'package:color_lab/features/coloring/presentation/coloring_workspace_screen.dart';
import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/domain/learning_palette_copy.dart';
import 'package:color_lab/features/learning/presentation/experiment_notebook_screen.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coloring_flow_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'canonical catalog, project and completion routes retain identity',
    (tester) async {
      final flow = await ColoringFlowHarness.launch(
        tester,
        location: '/coloring',
      );
      expect(find.byType(ColoringCatalogScreen), findsOneWidget);
      expect(flow.router.state.uri.path, '/coloring');

      unawaited(flow.router.push<void>('/coloring/project/${flow.project.id}'));
      await pumpColoringUntil(tester, find.byType(ColoringWorkspaceScreen));
      expect(
        tester
            .widget<ColoringWorkspaceScreen>(
              find.byType(ColoringWorkspaceScreen),
            )
            .projectId,
        flow.project.id,
      );
      flow.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ColoringCatalogScreen), findsOneWidget);
      expect(flow.router.state.uri.path, '/coloring');

      flow.router.go('/coloring/complete/${flow.project.id}');
      await pumpColoringUntil(tester, find.byType(ColoringCompletionScreen));
      expect(
        tester
            .widget<ColoringCompletionScreen>(
              find.byType(ColoringCompletionScreen),
            )
            .projectId,
        flow.project.id,
      );
      expect((await flow.persisted(tester))!.toMap(), flow.project.toMap());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Learning payload survives catalog, workspace, Finish and Return', (
    tester,
  ) async {
    final source = [...bridgeColors];
    const returnLocation = '/learn/notebook?origin=coloring&lesson=warm-cool';
    final payload = LearningPaletteCopy(
      colors: source,
      returnLocation: returnLocation,
    );
    source.clear();
    final flow = await ColoringFlowHarness.launch(
      tester,
      location: '/coloring',
      paletteCopy: payload,
    );
    expect(payload.colors, bridgeColors);
    expect(
      tester
          .widget<ColoringCatalogScreen>(find.byType(ColoringCatalogScreen))
          .paletteCopy
          ?.returnLocation,
      returnLocation,
    );

    // Resume through the catalog's real callback with a retained value payload.
    final resumable = flow.project.copyWith(completed: false);
    await tester.runAsync(() async {
      await flow.repository.save(resumable);
      flow.container.read(coloringProjectsProvider.notifier).refresh();
      await flow.container.read(coloringProjectsProvider.future);
    });
    await tester.pumpAndSettle();
    final l10n = tester.element(find.byType(ColoringCatalogScreen)).l10n;
    final resume = find.widgetWithText(
      ListTile,
      l10n.coloringDrawingTitle(flow.drawing.title),
    );
    await tester.ensureVisible(resume);
    await tester.tap(resume);
    await pumpColoringUntil(tester, find.byType(ColoringWorkspaceScreen));
    final workspace = tester.widget<ColoringWorkspaceScreen>(
      find.byType(ColoringWorkspaceScreen),
    );
    expect(workspace.paletteCopy?.colors, bridgeColors);
    expect(workspace.paletteCopy?.returnLocation, returnLocation);

    await tapColoringKey(tester, 'coloring-finish');
    await pumpColoringUntil(tester, find.byType(ColoringCompletionScreen));
    final finished = (await flow.persisted(tester))!.toMap();
    expect(finished['completed'], isTrue);
    expect(finished['assignments'], flow.project.toMap()['assignments']);
    expect(
      tester
          .widget<ColoringCompletionScreen>(
            find.byType(ColoringCompletionScreen),
          )
          .paletteCopy
          ?.returnLocation,
      returnLocation,
    );

    // Initialize the real repository outside Flutter's fake clock before the
    // destination screen subscribes to it.
    await tester.runAsync(
      () => flow.container
          .read(learningSessionProvider.future)
          .timeout(const Duration(seconds: 5)),
    );
    final returnAction = find.byKey(
      const ValueKey('coloring-return-to-source'),
    );
    await tester.ensureVisible(returnAction);
    await tester.tap(returnAction);
    await tester.pump();
    await pumpColoringUntil(tester, find.byType(ExperimentNotebookScreen));
    expect(flow.router.state.uri.toString(), returnLocation);
    expect((await flow.persisted(tester))!.toMap(), finished);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'room handoff waits for explicit assignment and Cancel keeps both records',
    (tester) async {
      final flow = await ColoringFlowHarness.launch(tester);
      final beforeProject = (await flow.persisted(tester))!.toMap();
      final beforeRoom = flow.container.read(illustratedRoomProvider);
      await tapColoringKey(tester, 'coloring-use-in-room');

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        flow.router.state.uri.path,
        '/coloring/complete/${flow.project.id}',
      );
      expect(flow.container.read(illustratedRoomProvider), same(beforeRoom));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('coloring-room-assign-confirm')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ColoringCompletionScreen), findsOneWidget);
      expect(flow.container.read(illustratedRoomProvider), same(beforeRoom));
      expect((await flow.persisted(tester))!.toMap(), beforeProject);
      expect(tester.takeException(), isNull);
    },
  );
}
