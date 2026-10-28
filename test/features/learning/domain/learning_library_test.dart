import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/learning/domain/learning_content.dart';
import 'package:color_lab/features/learning/domain/learning_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final updatedAt = DateTime.utc(2026, 10, 28, 4, 5, 6, 7, 8);

  QuestionResponse response() => QuestionResponse(
    questionId: 'q1',
    attempts: [
      QuestionAttempt(
        answerId: 'wrong',
        correct: false,
        explanationKey: 'wrongExplanation',
        attemptedAt: updatedAt,
      ),
      QuestionAttempt(
        answerId: 'right',
        correct: true,
        explanationKey: 'rightExplanation',
        attemptedAt: updatedAt.add(const Duration(seconds: 1)),
      ),
    ],
  );

  LessonProgress progress() => LessonProgress(
    lessonId: 'color-coordinates',
    lessonRevision: 1,
    currentStepIndex: 2,
    completedStepIds: const {'step-predict', 'step-manipulate'},
    answers: {'q1': response()},
    completed: false,
    updatedAt: updatedAt,
  );

  ExperimentRecord record() => ExperimentRecord(
    id: 'experiment-1',
    title: 'Warm violet',
    lessonId: 'color-coordinates',
    inputHexes: const ['#112233'],
    resultHexes: const ['#AABBCC'],
    snapshot: const FormulaExperimentSnapshot(targetHex: '#112233'),
    observation: 'The target contains more blue than red.',
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );

  test(
    'progress uses exact schema keys and UTC round trips answer history',
    () {
      final value = progress();
      final map = value.toMap();
      expect(map.keys.toSet(), {
        'schemaVersion',
        'lessonId',
        'lessonRevision',
        'currentStepIndex',
        'completedStepIds',
        'answers',
        'completed',
        'updatedAt',
      });
      expect(map['updatedAt'], '2026-10-28T04:05:06.007008Z');
      final decoded = LessonProgress.fromMap(map);
      expect(decoded, value);
      expect(decoded.answers['q1']!.attempts.length, 2);
      expect(decoded.answers['q1']!.latest.correct, true);
      expect(decoded.updatedAt.isUtc, true);
    },
  );

  test(
    'library round trips exact v1 schema and preserves immutable values',
    () {
      final library = LearningLibrary(
        schemaVersion: 1,
        progressByLesson: {'color-coordinates': progress()},
        practiceHistory: [
          PracticeAttempt(
            id: 'practice-1',
            lessonId: 'color-coordinates',
            activityId: 'check-1',
            answerId: 'right',
            correct: true,
            explanationKey: 'rightExplanation',
            attemptedAt: updatedAt,
          ),
        ],
        topicsToRevisit: const {LearningTopic.digitalMixing},
        experiments: [record()],
      );
      final map = library.toMap();
      expect(map.keys.toSet(), {
        'schemaVersion',
        'progressByLesson',
        'practiceHistory',
        'topicsToRevisit',
        'experiments',
      });
      expect(LearningLibrary.fromMap(map), library);
      expect(() => library.experiments.clear(), throwsUnsupportedError);
      expect(() => library.progressByLesson.clear(), throwsUnsupportedError);
    },
  );

  test(
    'strict decoding rejects duplicate IDs, invalid keys, and local dates',
    () {
      final duplicatePractice = {
        'schemaVersion': 1,
        'progressByLesson': <String, Object?>{},
        'practiceHistory': [
          {
            'schemaVersion': 1,
            'id': 'same',
            'lessonId': 'lesson',
            'activityId': 'activity',
            'answerId': 'answer',
            'correct': true,
            'explanationKey': 'explanation',
            'attemptedAt': '2026-10-28T04:05:06.000Z',
          },
          {
            'schemaVersion': 1,
            'id': 'same',
            'lessonId': 'lesson',
            'activityId': 'activity',
            'answerId': 'answer',
            'correct': false,
            'explanationKey': 'explanation',
            'attemptedAt': '2026-10-28T04:05:07.000Z',
          },
        ],
        'topicsToRevisit': <String>[],
        'experiments': <Object?>[],
      };
      expect(
        () => LearningLibrary.fromMap(duplicatePractice),
        throwsFormatException,
      );

      final invalidProgress = Map<String, Object?>.from(progress().toMap());
      invalidProgress['extra'] = true;
      expect(
        () => LessonProgress.fromMap(invalidProgress),
        throwsFormatException,
      );
      invalidProgress.remove('extra');
      invalidProgress['updatedAt'] = '2026-10-28T10:05:06+06:00';
      expect(
        () => LessonProgress.fromMap(invalidProgress),
        throwsFormatException,
      );

      final duplicateSteps = Map<String, Object?>.from(progress().toMap());
      duplicateSteps['completedStepIds'] = ['step-predict', 'step-predict'];
      expect(
        () => LessonProgress.fromMap(duplicateSteps),
        throwsFormatException,
      );
    },
  );

  test('unsupported library versions are rejected without coercion', () {
    expect(
      () => LearningLibrary.fromMap({
        'schemaVersion': 2,
        'progressByLesson': <String, Object?>{},
        'practiceHistory': <Object?>[],
        'topicsToRevisit': <String>[],
        'experiments': <Object?>[],
      }),
      throwsFormatException,
    );
  });

  test('equal map-backed learning values have equal hash codes', () {
    final firstProgress = progress();
    final secondProgress = LessonProgress.fromMap(firstProgress.toMap());
    expect(secondProgress, firstProgress);
    expect(secondProgress.hashCode, firstProgress.hashCode);

    final first = LearningLibrary.empty().copyWith(
      progressByLesson: {'color-coordinates': firstProgress},
    );
    final second = LearningLibrary.fromMap(first.toMap());
    expect(second, first);
    expect(second.hashCode, first.hashCode);
  });
}
