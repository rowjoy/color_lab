import '../domain/experiment_snapshot.dart';
import '../domain/learning_content.dart';

abstract final class ColorFoundationsCatalog {
  static final List<LearningLesson> lessons = List.unmodifiable([
    _lesson(
      id: 'color-coordinates',
      key: 'Coordinates',
      topic: LearningTopic.colorCoordinates,
      tool: ExperimentTool.lab,
      glossary: const [
        'learningGlossaryHsl',
        'learningGlossaryRgb',
        'learningGlossaryHex',
        'learningGlossaryLab',
        'learningGlossaryCmyk',
        'learningGlossaryDeltaE',
      ],
      correctFirst: true,
      correctSecond: false,
    ),
    _lesson(
      id: 'hue',
      key: 'Hue',
      topic: LearningTopic.hue,
      tool: ExperimentTool.lab,
      glossary: const ['learningGlossaryHsl', 'learningGlossaryHue'],
      correctFirst: true,
      correctSecond: false,
    ),
    _lesson(
      id: 'saturation',
      key: 'Saturation',
      topic: LearningTopic.saturation,
      tool: ExperimentTool.lab,
      glossary: const ['learningGlossaryHsl', 'learningGlossarySaturation'],
      correctFirst: false,
      correctSecond: true,
    ),
    _lesson(
      id: 'lightness-value',
      key: 'LightnessValue',
      topic: LearningTopic.lightnessValue,
      tool: ExperimentTool.lab,
      glossary: const [
        'learningGlossaryHsl',
        'learningGlossaryHsv',
        'learningGlossaryLightnessValue',
      ],
      correctFirst: true,
      correctSecond: false,
    ),
    _lesson(
      id: 'digital-mixing',
      key: 'DigitalMixing',
      topic: LearningTopic.digitalMixing,
      tool: ExperimentTool.mixer,
      glossary: const [
        'learningGlossaryRgb',
        'learningGlossaryLab',
        'learningGlossaryDigitalInterpolation',
      ],
      correctFirst: false,
      correctSecond: true,
    ),
    _lesson(
      id: 'palette-relationships',
      key: 'PaletteRelationships',
      topic: LearningTopic.paletteRelationships,
      tool: ExperimentTool.harmonies,
      glossary: const ['learningGlossaryHarmony', 'learningGlossaryHsl'],
      correctFirst: true,
      correctSecond: false,
    ),
  ]);

  static LearningLesson byId(String lessonId) {
    for (final lesson in lessons) {
      if (lesson.id == lessonId) return lesson;
    }
    throw FormatException('Unknown Color Foundations lesson: $lessonId');
  }
}

LearningLesson _lesson({
  required String id,
  required String key,
  required LearningTopic topic,
  required ExperimentTool tool,
  required List<String> glossary,
  required bool correctFirst,
  required bool correctSecond,
}) => LearningLesson(
  id: id,
  revision: 1,
  topic: topic,
  titleKey: 'learningLesson${key}Title',
  summaryKey: 'learningLesson${key}Summary',
  steps: [
    for (final kind in LearningStepKind.values)
      LearningStep(
        id: '$id-${kind.name}',
        kind: kind,
        titleKey: 'learningStep${_upper(kind.name)}Title',
        instructionKey: 'learning${key}${_upper(kind.name)}Instruction',
        nonVisualInstructionKey: kind == LearningStepKind.manipulate
            ? 'learning${key}ManipulateNonVisual'
            : 'learningNonVisualInstruction',
        glossaryKeys: glossary,
        experimentTool: kind == LearningStepKind.manipulate ? tool : null,
      ),
  ],
  questions: [
    _question(lessonId: id, key: key, number: 1, correctA: correctFirst),
    _question(lessonId: id, key: key, number: 2, correctA: correctSecond),
  ],
);

ConceptQuestion _question({
  required String lessonId,
  required String key,
  required int number,
  required bool correctA,
}) {
  final prefix = 'learning${key}Q$number';
  final id = '$lessonId-q$number';
  return ConceptQuestion(
    id: id,
    promptKey: '${prefix}Prompt',
    answers: [
      ConceptAnswer(
        id: '$id-a',
        labelKey: '${prefix}ALabel',
        explanationKey: '${prefix}AExplanation',
        correct: correctA,
      ),
      ConceptAnswer(
        id: '$id-b',
        labelKey: '${prefix}BLabel',
        explanationKey: '${prefix}BExplanation',
        correct: !correctA,
      ),
    ],
  );
}

String _upper(String value) => '${value[0].toUpperCase()}${value.substring(1)}';
