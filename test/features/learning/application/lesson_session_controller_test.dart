import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/data/color_foundations_catalog.dart';
import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/learning/domain/learning_library.dart';
import 'package:color_lab/features/learning/domain/learning_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_learning_repository.dart';

void main() {
  final now = DateTime.utc(2026, 10, 28, 8);

  ProviderContainer containerFor(InMemoryLearningRepository repository) =>
      ProviderContainer(
        overrides: [
          learningRepositoryProvider.overrideWith((ref) async => repository),
          learningClockProvider.overrideWithValue(() => now),
          learningIdProvider.overrideWithValue((prefix) => '$prefix-fixed'),
        ],
      );

  test(
    'legal sequence advances, back navigation retains completed work',
    () async {
      final repository = InMemoryLearningRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      await container.read(learningSessionProvider.future);
      final controller = container.read(learningSessionProvider.notifier);
      final lesson = ColorFoundationsCatalog.byId('hue');

      expect((await controller.openLesson('hue')).currentStepIndex, 0);
      await expectLater(
        controller.setCurrentStep('hue', lesson.steps[2].id),
        throwsA(isA<StateError>()),
      );
      final forward = await controller.setCurrentStep(
        'hue',
        lesson.steps[1].id,
      );
      expect(forward.currentStepIndex, 1);
      expect(forward.completedStepIds, {lesson.steps.first.id});

      final back = await controller.setCurrentStep(
        'hue',
        lesson.steps.first.id,
      );
      expect(back.currentStepIndex, 0);
      expect(back.completedStepIds, {lesson.steps.first.id});
    },
  );

  test(
    'answer history supports free retry and wrong answers do not block completion',
    () async {
      final repository = InMemoryLearningRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      await container.read(learningSessionProvider.future);
      final controller = container.read(learningSessionProvider.notifier);
      final lesson = ColorFoundationsCatalog.byId('hue');
      await controller.openLesson(lesson.id);
      for (final step in lesson.steps.skip(1)) {
        await controller.setCurrentStep(lesson.id, step.id);
      }

      final firstQuestion = lesson.questions.first;
      final wrong = firstQuestion.answers.singleWhere(
        (answer) => !answer.correct,
      );
      final right = firstQuestion.answers.singleWhere(
        (answer) => answer.correct,
      );
      expect(
        (await controller.answerQuestion(
          lessonId: lesson.id,
          questionId: firstQuestion.id,
          answerId: wrong.id,
        )).latest.correct,
        false,
      );
      final retried = await controller.answerQuestion(
        lessonId: lesson.id,
        questionId: firstQuestion.id,
        answerId: right.id,
      );
      expect(retried.attempts.map((attempt) => attempt.correct), [false, true]);

      final second = lesson.questions.last;
      final secondWrong = second.answers.singleWhere(
        (answer) => !answer.correct,
      );
      await controller.answerQuestion(
        lessonId: lesson.id,
        questionId: second.id,
        answerId: secondWrong.id,
      );
      final beforeCompletion = container
          .read(learningSessionProvider)
          .requireValue
          .visible
          .progressByLesson[lesson.id]!;
      expect(beforeCompletion.currentStepIndex, lesson.steps.length - 1);
      expect(beforeCompletion.answers.keys, {
        lesson.questions.first.id,
        lesson.questions.last.id,
      });
      final complete = await controller.completeLesson(lesson.id);
      expect(complete.completed, true);
      expect(complete.answers[second.id]!.latest.correct, false);
      expect(
        container
            .read(learningSessionProvider)
            .requireValue
            .visible
            .practiceHistory,
        hasLength(3),
      );
    },
  );

  test(
    'content revision archives prior answers and starts revised lesson explicitly',
    () async {
      final oldAttempt = QuestionAttempt(
        answerId: 'hue-q1-b',
        correct: false,
        explanationKey: 'learningHueQ1BExplanation',
        attemptedAt: now.subtract(const Duration(days: 1)),
      );
      final old = LessonProgress(
        lessonId: 'hue',
        lessonRevision: 2,
        currentStepIndex: 4,
        completedStepIds: const {'hue-predict'},
        answers: {
          'hue-q1': QuestionResponse(
            questionId: 'hue-q1',
            attempts: [oldAttempt],
          ),
        },
        completed: false,
        updatedAt: now.subtract(const Duration(days: 1)),
      );
      final repository = InMemoryLearningRepository(
        initial: LearningLibrary.empty().copyWith(
          progressByLesson: {'hue': old},
        ),
      );
      final container = containerFor(repository);
      addTearDown(container.dispose);
      await container.read(learningSessionProvider.future);

      final revised = await container
          .read(learningSessionProvider.notifier)
          .openLesson('hue');
      final state = container
          .read(learningSessionProvider)
          .requireValue
          .visible;
      expect(revised.lessonRevision, 1);
      expect(revised.currentStepIndex, 0);
      expect(revised.answers, isEmpty);
      expect(state.practiceHistory.single.answerId, oldAttempt.answerId);
      expect(state.practiceHistory.single.correct, false);
    },
  );

  test(
    'failed write keeps visible work, durable state, and supports retry',
    () async {
      final repository = InMemoryLearningRepository();
      final container = containerFor(repository);
      addTearDown(container.dispose);
      await container.read(learningSessionProvider.future);
      final controller = container.read(learningSessionProvider.notifier);
      final lesson = ColorFoundationsCatalog.byId('hue');
      await controller.openLesson('hue');
      repository.failNextTransaction = true;

      await expectLater(
        controller.setCurrentStep('hue', lesson.steps[1].id),
        throwsA(isA<LearningStorageException>()),
      );
      final failed = container.read(learningSessionProvider).requireValue;
      expect(failed.durable.progressByLesson['hue']!.currentStepIndex, 0);
      expect(failed.visible.progressByLesson['hue']!.currentStepIndex, 1);
      expect(failed.saving, false);
      expect(failed.saveError, isNotNull);

      await controller.retryVisible();
      final recovered = container.read(learningSessionProvider).requireValue;
      expect(recovered.durable, recovered.visible);
      expect(recovered.durable.progressByLesson['hue']!.currentStepIndex, 1);
      expect(recovered.saveError, isNull);
    },
  );

  test('notebook saves copied HEX values and deletes by stable ID', () async {
    final repository = InMemoryLearningRepository();
    final container = containerFor(repository);
    addTearDown(container.dispose);
    await container.read(learningSessionProvider.future);
    final controller = container.read(learningSessionProvider.notifier);

    final record = await controller.saveExperiment(
      title: 'Formula note',
      lessonId: 'color-coordinates',
      snapshot: const FormulaExperimentSnapshot(targetHex: '#112233'),
      results: [RgbColor.fromHex('#AABBCC')],
      observation: 'A copied result.',
    );
    expect(record.id, 'experiment-fixed');
    expect(record.inputHexes, ['#112233']);
    expect(record.resultHexes, ['#AABBCC']);
    expect(
      container
          .read(learningSessionProvider)
          .requireValue
          .durable
          .experiments
          .single,
      record,
    );
    await controller.deleteExperiment(record.id);
    expect(
      container.read(learningSessionProvider).requireValue.visible.experiments,
      isEmpty,
    );
  });
}
