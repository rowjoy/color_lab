import 'dart:convert';
import 'dart:io';

import 'package:color_lab/features/learning/data/color_foundations_catalog.dart';
import 'package:color_lab/features/learning/domain/learning_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, Object?> english;

  setUpAll(() {
    english = Map<String, Object?>.from(
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map,
    );
  });

  test('catalog exposes the exact six Color Foundations topics in order', () {
    final lessons = ColorFoundationsCatalog.lessons;
    expect(lessons.map((lesson) => lesson.id), [
      'color-coordinates',
      'hue',
      'saturation',
      'lightness-value',
      'digital-mixing',
      'palette-relationships',
    ]);
    expect(lessons.map((lesson) => lesson.topic), LearningTopic.values);
    expect(lessons.every((lesson) => lesson.revision == 1), true);
    expect(ColorFoundationsCatalog.byId('digital-mixing'), same(lessons[4]));
    expect(
      () => ColorFoundationsCatalog.byId('advanced-track'),
      throwsFormatException,
    );
  });

  test('all authored IDs are globally unique and loops are complete', () {
    final allIds = <String>[];
    for (final lesson in ColorFoundationsCatalog.lessons) {
      allIds.add(lesson.id);
      allIds.addAll(lesson.steps.map((step) => step.id));
      allIds.addAll(lesson.questions.map((question) => question.id));
      allIds.addAll(
        lesson.questions.expand(
          (question) => question.answers.map((answer) => answer.id),
        ),
      );
      expect(lesson.steps.map((step) => step.kind), LearningStepKind.values);
      expect(lesson.questions.length, inInclusiveRange(2, 3));
      expect(
        lesson.steps.every((step) => step.nonVisualInstructionKey.isNotEmpty),
        true,
      );
      expect(
        lesson.questions
            .expand((question) => question.answers)
            .every((answer) => answer.explanationKey.isNotEmpty),
        true,
      );
    }
    expect(allIds.toSet(), hasLength(allIds.length));
  });

  test('every content key has English copy and required ARB metadata', () {
    final keys = <String>{};
    for (final lesson in ColorFoundationsCatalog.lessons) {
      keys.addAll([lesson.titleKey, lesson.summaryKey]);
      for (final step in lesson.steps) {
        keys.addAll([
          step.titleKey,
          step.instructionKey,
          step.nonVisualInstructionKey,
          ...step.glossaryKeys,
        ]);
      }
      for (final question in lesson.questions) {
        keys.add(question.promptKey);
        for (final answer in question.answers) {
          keys.addAll([answer.labelKey, answer.explanationKey]);
        }
      }
    }
    for (final key in keys) {
      expect(english[key], isA<String>(), reason: 'Missing $key');
      final metadata = english['@$key'];
      expect(metadata, isA<Map>(), reason: 'Missing @$key');
      expect(
        (metadata! as Map)['description'],
        isNotEmpty,
        reason: 'Missing description for $key',
      );
    }
  });

  test(
    'scientific boundaries are explicit and curriculum needs no vision plate',
    () {
      final copy = english.values.whereType<String>().join(' ').toLowerCase();
      expect(copy, contains('not pigment mixing'));
      expect(copy, contains('not a paint recipe'));
      expect(copy, contains('not a universal beauty rule'));
      expect(copy, contains('delta-e points'));
      for (final lesson in ColorFoundationsCatalog.lessons) {
        expect(
          [
            lesson.id,
            lesson.titleKey,
            lesson.summaryKey,
            ...lesson.steps.expand(
              (step) => [
                step.id,
                step.instructionKey,
                step.nonVisualInstructionKey,
              ],
            ),
          ].join(' ').toLowerCase(),
          isNot(contains('vision')),
        );
      }
    },
  );
}
