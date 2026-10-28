import 'dart:async';

import 'package:color_lab/app.dart';
import 'package:color_lab/features/lab/presentation/lab_screen.dart';
import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/learning/domain/learning_library.dart';
import 'package:color_lab/features/learning/presentation/experiment_notebook_screen.dart';
import 'package:color_lab/features/learning/presentation/learning_experiment_route_screen.dart';
import 'package:color_lab/features/learning/presentation/lesson_screen.dart';
import 'package:color_lab/features/lab/application/lab_controller.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_screen.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/in_memory_app_preferences_repository.dart';
import '../../support/in_memory_learning_repository.dart';

void main() {
  testWidgets('canonical Learn routes and legacy Lab redirect are safe', (
    tester,
  ) async {
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    harness.router.go('/lab');
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/learn/experiment/lab');
    expect(find.byType(LabScreen), findsOneWidget);

    harness.router.go('/learn/notebook');
    await tester.pumpAndSettle();
    expect(find.byType(ExperimentNotebookScreen), findsOneWidget);

    harness.router.go('/learn/lesson/not-a-lesson');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('route-unavailable')), findsOneWidget);

    harness.router.go('/learn/experiment/not-an-experiment');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('learning-experiment-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('lesson progress survives an Illustrated Room detour and Back', (
    tester,
  ) async {
    final harness = await _launch(tester);
    addTearDown(harness.dispose);
    harness.router.go('/learn/lesson/hue');
    await tester.pumpAndSettle();
    expect(find.byType(LessonScreen), findsOneWidget);
    final before = harness.container
        .read(learningSessionProvider)
        .requireValue
        .visible
        .progressByLesson['hue'];

    unawaited(harness.router.push<void>('/room/illustrated/study'));
    await tester.pumpAndSettle();
    expect(find.byType(IllustratedRoomScreen), findsOneWidget);
    harness.router.pop();
    await tester.pumpAndSettle();

    expect(find.byType(LessonScreen), findsOneWidget);
    expect(
      harness.container
          .read(learningSessionProvider)
          .requireValue
          .visible
          .progressByLesson['hue'],
      before,
    );
  });

  testWidgets('dismissed deep link cannot restore stale experiment state', (
    tester,
  ) async {
    final repositoryGate = Completer<InMemoryLearningRepository>();
    final container = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWith((ref) => repositoryGate.future),
      ],
    );
    addTearDown(container.dispose);
    final before = container.read(labProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LearningExperimentRouteScreen(experimentId: 'experiment-one'),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const SizedBox.shrink(),
      ),
    );
    final now = DateTime.utc(2026, 10, 28);
    repositoryGate.complete(
      InMemoryLearningRepository(
        initial: LearningLibrary.empty().copyWith(
          experiments: [
            ExperimentRecord(
              id: 'experiment-one',
              title: 'Stale Lab',
              lessonId: null,
              inputHexes: const ['#FF0000'],
              resultHexes: const ['#FF0000'],
              snapshot: const LabExperimentSnapshot(
                hue: 0,
                saturation: 1,
                lightness: .5,
              ),
              observation: '',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(labProvider), before);
  });
}

final class _Harness {
  const _Harness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  void dispose() => container.dispose();
}

Future<_Harness> _launch(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      appPreferencesRepositoryProvider.overrideWith(
        (ref) async => InMemoryAppPreferencesRepository(),
      ),
      learningRepositoryProvider.overrideWith(
        (ref) async => InMemoryLearningRepository(),
      ),
    ],
  );
  await container.read(appPreferencesProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ColorLabApp()),
  );
  await tester.pumpAndSettle();
  return _Harness(container, container.read(appRouterProvider));
}
