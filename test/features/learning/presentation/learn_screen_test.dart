import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/domain/learning_library.dart';
import 'package:color_lab/features/learning/presentation/learn_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_learning_repository.dart';

void main() {
  Future<void> pumpLearn(
    WidgetTester tester, {
    Size size = const Size(800, 1000),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final progress = LessonProgress(
      lessonId: 'hue',
      lessonRevision: 1,
      currentStepIndex: 2,
      completedStepIds: const {'hue-predict', 'hue-manipulate'},
      answers: const {},
      completed: false,
      updatedAt: DateTime.utc(2026, 10, 28),
    );
    final repository = InMemoryLearningRepository(
      initial: LearningLibrary.empty().copyWith(
        progressByLesson: {'hue': progress},
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const LearnScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Learn shows exact sections, six lessons, and durable resume state',
    (tester) async {
      await pumpLearn(tester);

      expect(find.text('Learn'), findsWidgets);
      expect(find.text('Experiment'), findsOneWidget);
      expect(find.text('My Work'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('learning-lesson-color-coordinates')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('learning-lesson-hue')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('learning-lesson-saturation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('learning-lesson-lightness-value')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('learning-lesson-digital-mixing')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('learning-lesson-palette-relationships')),
        findsOneWidget,
      );
      expect(find.text('Resume · Observe'), findsOneWidget);
      expect(find.textContaining('camera'), findsNothing);
      expect(find.textContaining('download'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Learn stays scrollable at compact landscape and 200% text', (
    tester,
  ) async {
    await pumpLearn(tester, size: const Size(568, 320), textScale: 2);
    expect(find.byType(Scrollable), findsWidgets);
    expect(find.byKey(const ValueKey('learning-lesson-hue')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
