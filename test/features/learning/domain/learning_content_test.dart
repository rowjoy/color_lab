import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/learning/domain/learning_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<LearningStep> steps() => [
    for (final kind in LearningStepKind.values)
      LearningStep(
        id: 'step-${kind.name}',
        kind: kind,
        titleKey: '${kind.name}Title',
        instructionKey: '${kind.name}Instruction',
        nonVisualInstructionKey: '${kind.name}NonVisual',
        glossaryKeys: const ['glossaryHue'],
        experimentTool: kind == LearningStepKind.manipulate
            ? ExperimentTool.lab
            : null,
      ),
  ];

  ConceptQuestion question(String id) => ConceptQuestion(
    id: id,
    promptKey: '${id}Prompt',
    answers: [
      ConceptAnswer(
        id: '$id-a',
        labelKey: '${id}ALabel',
        explanationKey: '${id}AExplanation',
        correct: true,
      ),
      ConceptAnswer(
        id: '$id-b',
        labelKey: '${id}BLabel',
        explanationKey: '${id}BExplanation',
        correct: false,
      ),
    ],
  );

  test('lesson freezes the six-stage loop and immutable content', () {
    final sourceSteps = steps();
    final lesson = LearningLesson(
      id: 'color-coordinates',
      revision: 1,
      topic: LearningTopic.colorCoordinates,
      titleKey: 'lessonCoordinatesTitle',
      summaryKey: 'lessonCoordinatesSummary',
      steps: sourceSteps,
      questions: [question('q1'), question('q2')],
    );

    sourceSteps.clear();
    expect(lesson.steps.map((step) => step.kind), LearningStepKind.values);
    expect(() => lesson.steps.add(steps().first), throwsUnsupportedError);
    expect(
      () => lesson.questions.first.answers.clear(),
      throwsUnsupportedError,
    );
  });

  test('lesson rejects a missing, repeated, or out-of-order stage', () {
    final valid = steps();
    for (final invalid in <List<LearningStep>>[
      valid.take(5).toList(),
      [...valid.take(5), valid.first],
      [valid[1], valid[0], ...valid.skip(2)],
    ]) {
      expect(
        () => LearningLesson(
          id: 'lesson',
          revision: 1,
          topic: LearningTopic.hue,
          titleKey: 'title',
          summaryKey: 'summary',
          steps: invalid,
          questions: [question('q1'), question('q2')],
        ),
        throwsFormatException,
      );
    }
  });

  test('lesson enforces global IDs and two-or-three concept questions', () {
    for (final count in [0, 1, 4]) {
      expect(
        () => LearningLesson(
          id: 'lesson',
          revision: 1,
          topic: LearningTopic.hue,
          titleKey: 'title',
          summaryKey: 'summary',
          steps: steps(),
          questions: [
            for (var index = 0; index < count; index++) question('q$index'),
          ],
        ),
        throwsFormatException,
      );
    }

    expect(
      () => ConceptQuestion(
        id: 'q1',
        promptKey: 'prompt',
        answers: [question('q1').answers.first, question('q1').answers.first],
      ),
      throwsFormatException,
    );
    expect(
      () => LearningLesson(
        id: 'lesson',
        revision: 1,
        topic: LearningTopic.hue,
        titleKey: 'title',
        summaryKey: 'summary',
        steps: steps(),
        questions: [question('q1'), question('q1')],
      ),
      throwsFormatException,
    );
  });
}
