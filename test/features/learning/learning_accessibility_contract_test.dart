import 'dart:convert';
import 'dart:io';

import 'package:color_lab/features/color_test/application/vision_controller.dart';
import 'package:color_lab/features/color_test/domain/vision_plate.dart';
import 'package:color_lab/features/color_test/presentation/vision_screen.dart';
import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/data/color_foundations_catalog.dart';
import 'package:color_lab/features/learning/domain/learning_content.dart';
import 'package:color_lab/features/learning/domain/learning_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_learning_repository.dart';

void main() {
  List<VisionPlate> plates() => [
    for (var index = 0; index < 6; index++)
      VisionPlate(number: index + 1, seed: 100 + index),
  ];

  test('vision activity cannot mutate completed learning progress', () async {
    final progress = LessonProgress(
      lessonId: 'hue',
      lessonRevision: 1,
      currentStepIndex: 5,
      completedStepIds: const {
        'hue-predict',
        'hue-manipulate',
        'hue-observe',
        'hue-explain',
        'hue-apply',
        'hue-check',
      },
      answers: const {},
      completed: true,
      updatedAt: DateTime.utc(2026, 10, 28),
    );
    final repository = InMemoryLearningRepository(
      initial: LearningLibrary.empty().copyWith(
        progressByLesson: {'hue': progress},
      ),
    );
    final container = ProviderContainer(
      overrides: [
        learningRepositoryProvider.overrideWith((ref) async => repository),
        visionPlateGeneratorProvider.overrideWithValue(plates),
      ],
    );
    addTearDown(container.dispose);
    await container.read(learningSessionProvider.future);
    final before = container.read(learningLibraryProvider).progressByLesson;
    final vision = container.read(visionSessionProvider.notifier)..start();
    for (var index = 0; index < 6; index++) {
      final plate = container.read(visionSessionProvider).currentPlate;
      expect(vision.respond(plateId: plate.id, answer: plate.number), isTrue);
    }
    vision.restart();

    expect(container.read(learningLibraryProvider).progressByLesson, before);
    expect(
      container
          .read(learningLibraryProvider)
          .progressByLesson['hue']!
          .completed,
      isTrue,
    );
  });

  test('all six lesson loops publish complete non-color alternatives', () {
    final english = Map<String, Object?>.from(
      jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map,
    );
    final lessons = ColorFoundationsCatalog.lessons;
    expect(lessons, hasLength(6));
    final manipulateKeys = <String>{};
    for (final lesson in lessons) {
      expect(lesson.steps.map((step) => step.kind), LearningStepKind.values);
      for (final step in lesson.steps) {
        expect(
          english[step.nonVisualInstructionKey],
          isA<String>().having((value) => value.trim(), 'copy', isNotEmpty),
          reason: step.id,
        );
        if (step.kind == LearningStepKind.manipulate) {
          manipulateKeys.add(step.nonVisualInstructionKey);
          expect(step.experimentTool, isNotNull, reason: step.id);
        }
      }
    }
    expect(manipulateKeys, hasLength(6));
  });

  testWidgets('vision result stays optional and exposes no capability score', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [visionPlateGeneratorProvider.overrideWithValue(plates)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: VisionScreen()),
      ),
    );
    final vision = container.read(visionSessionProvider.notifier)..start();
    for (var index = 0; index < 6; index++) {
      final plate = container.read(visionSessionProvider).currentPlate;
      vision.respond(plateId: plate.id, answer: null);
    }
    await tester.pump();

    expect(
      find.text(
        'This optional activity does not affect lessons or completion and does not evaluate accessibility.',
      ),
      findsOneWidget,
    );
    expect(find.text('Review your 6 recorded responses'), findsOneWidget);
    expect(find.textContaining('pattern matches'), findsNothing);
    expect(find.textContaining('capability'), findsNothing);
    expect(find.textContaining('curriculum credit'), findsNothing);
    expect(find.textContaining('mastery'), findsNothing);
  });
}
