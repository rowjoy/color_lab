import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/presentation/lesson_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_learning_repository.dart';

void main() {
  testWidgets(
    'lesson exposes all stages, nonvisual values, explanations, and retry',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = InMemoryLearningRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learningRepositoryProvider.overrideWith((ref) async => repository),
            learningClockProvider.overrideWithValue(
              () => DateTime.utc(2026, 10, 28),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LessonScreen(lessonId: 'hue'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final stage in const [
        'Predict',
        'Manipulate',
        'Observe',
        'Explain',
        'Apply',
        'Check',
      ]) {
        expect(find.text(stage), findsWidgets);
      }
      expect(find.textContaining('seeing a color difference'), findsOneWidget);

      for (var index = 0; index < 5; index++) {
        final next = find.byKey(const ValueKey('learning-next-step'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        if (index == 0) {
          expect(
            find.byKey(const ValueKey('learning-open-practice-tool')),
            findsOneWidget,
          );
          expect(find.text('Open lab experiment'), findsOneWidget);
        }
      }
      final wrong = find.text('It becomes maximum brightness');
      await tester.ensureVisible(wrong);
      await tester.tap(wrong);
      await tester.pumpAndSettle();
      expect(
        find.text('Not quite. Hue angle does not set brightness.'),
        findsOneWidget,
      );
      expect(find.text('Try again as often as you like.'), findsWidgets);

      final right = find.text('It wraps to 0° on the color circle');
      await tester.tap(right);
      await tester.pumpAndSettle();
      expect(
        find.text('Correct. Hue is circular, so 360° and 0° meet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'lesson reset requires confirmation and restarts only that lesson',
    (tester) async {
      final repository = InMemoryLearningRepository();
      final container = ProviderContainer(
        overrides: [
          learningRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LessonScreen(lessonId: 'hue'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final next = find.byKey(const ValueKey('learning-next-step'));
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(
        container
            .read(learningSessionProvider)
            .requireValue
            .visible
            .progressByLesson['hue']!
            .currentStepIndex,
        1,
      );

      final reset = find.byKey(const ValueKey('learning-reset-lesson'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(find.text('Reset this lesson?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(learningSessionProvider)
            .requireValue
            .visible
            .progressByLesson['hue']!
            .currentStepIndex,
        1,
      );

      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('learning-confirm-reset')));
      await tester.pumpAndSettle();
      expect(
        container
            .read(learningSessionProvider)
            .requireValue
            .visible
            .progressByLesson['hue']!
            .currentStepIndex,
        0,
      );
    },
  );
}
