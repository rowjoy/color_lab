import 'experiment_snapshot.dart';

enum LearningTopic {
  colorCoordinates,
  hue,
  saturation,
  lightnessValue,
  digitalMixing,
  paletteRelationships,
}

enum LearningStepKind { predict, manipulate, observe, explain, apply, check }

final class LearningStep {
  LearningStep({
    required this.id,
    required this.kind,
    required this.titleKey,
    required this.instructionKey,
    required this.nonVisualInstructionKey,
    Iterable<String> glossaryKeys = const [],
    this.experimentTool,
  }) : glossaryKeys = List.unmodifiable(glossaryKeys) {
    _contentId(id, 'step id');
    _copyKey(titleKey, 'step title');
    _copyKey(instructionKey, 'step instruction');
    _copyKey(nonVisualInstructionKey, 'nonvisual instruction');
    _unique(this.glossaryKeys, 'glossary keys');
    for (final key in this.glossaryKeys) {
      _copyKey(key, 'glossary key');
    }
  }

  final String id;
  final LearningStepKind kind;
  final String titleKey;
  final String instructionKey;
  final String nonVisualInstructionKey;
  final List<String> glossaryKeys;
  final ExperimentTool? experimentTool;
}

final class ConceptAnswer {
  ConceptAnswer({
    required this.id,
    required this.labelKey,
    required this.explanationKey,
    required this.correct,
  }) {
    _contentId(id, 'answer id');
    _copyKey(labelKey, 'answer label');
    _copyKey(explanationKey, 'answer explanation');
  }

  final String id;
  final String labelKey;
  final String explanationKey;
  final bool correct;
}

final class ConceptQuestion {
  ConceptQuestion({
    required this.id,
    required this.promptKey,
    required Iterable<ConceptAnswer> answers,
  }) : answers = List.unmodifiable(answers) {
    _contentId(id, 'question id');
    _copyKey(promptKey, 'question prompt');
    if (this.answers.length < 2 ||
        !this.answers.any((answer) => answer.correct) ||
        !this.answers.any((answer) => !answer.correct)) {
      throw const FormatException(
        'A concept question needs correct and incorrect choices.',
      );
    }
    _unique(this.answers.map((answer) => answer.id), 'answer ids');
  }

  final String id;
  final String promptKey;
  final List<ConceptAnswer> answers;

  ConceptAnswer answerById(String answerId) {
    for (final answer in answers) {
      if (answer.id == answerId) return answer;
    }
    throw FormatException('Unknown answer: $answerId');
  }
}

final class LearningLesson {
  LearningLesson({
    required this.id,
    required this.revision,
    required this.topic,
    required this.titleKey,
    required this.summaryKey,
    required Iterable<LearningStep> steps,
    required Iterable<ConceptQuestion> questions,
  }) : steps = List.unmodifiable(steps),
       questions = List.unmodifiable(questions) {
    _contentId(id, 'lesson id');
    if (revision < 1) {
      throw const FormatException('Lesson revision must be positive.');
    }
    _copyKey(titleKey, 'lesson title');
    _copyKey(summaryKey, 'lesson summary');
    if (this.steps.length != LearningStepKind.values.length) {
      throw const FormatException(
        'A lesson needs the complete six-stage loop.',
      );
    }
    for (var index = 0; index < this.steps.length; index++) {
      if (this.steps[index].kind != LearningStepKind.values[index]) {
        throw const FormatException(
          'Lesson stages must use the required order.',
        );
      }
    }
    _unique(this.steps.map((step) => step.id), 'step ids');
    if (this.questions.length < 2 || this.questions.length > 3) {
      throw const FormatException('A lesson needs two or three questions.');
    }
    _unique(this.questions.map((question) => question.id), 'question ids');
    final globalIds = <String>[
      ...this.steps.map((step) => step.id),
      ...this.questions.map((question) => question.id),
      ...this.questions.expand(
        (question) => question.answers.map((answer) => answer.id),
      ),
    ];
    _unique(globalIds, 'lesson content ids');
  }

  final String id;
  final int revision;
  final LearningTopic topic;
  final String titleKey;
  final String summaryKey;
  final List<LearningStep> steps;
  final List<ConceptQuestion> questions;

  LearningStep stepById(String stepId) {
    for (final step in steps) {
      if (step.id == stepId) return step;
    }
    throw FormatException('Unknown lesson step: $stepId');
  }

  ConceptQuestion questionById(String questionId) {
    for (final question in questions) {
      if (question.id == questionId) return question;
    }
    throw FormatException('Unknown concept question: $questionId');
  }
}

void _contentId(String value, String field) {
  if (!RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$').hasMatch(value)) {
    throw FormatException('Invalid $field.');
  }
}

void _copyKey(String value, String field) {
  if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(value)) {
    throw FormatException('Invalid $field localization key.');
  }
}

void _unique(Iterable<String> values, String field) {
  final snapshot = values.toList(growable: false);
  if (snapshot.toSet().length != snapshot.length) {
    throw FormatException('Duplicate $field.');
  }
}
