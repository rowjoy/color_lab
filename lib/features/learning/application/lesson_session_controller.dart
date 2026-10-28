import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../../data/db/hive_learning_repository.dart';
import '../../../data/schema/corrupt_record.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../data/color_foundations_catalog.dart';
import '../domain/experiment_snapshot.dart';
import '../domain/learning_content.dart';
import '../domain/learning_library.dart';
import '../domain/learning_repository.dart';

typedef LearningClock = DateTime Function();
typedef LearningIdFactory = String Function(String prefix);

final learningClockProvider = Provider<LearningClock>((ref) => DateTime.now);

final learningIdProvider = Provider<LearningIdFactory>((ref) {
  var sequence = 0;
  return (prefix) =>
      '$prefix-${DateTime.now().toUtc().microsecondsSinceEpoch}-${sequence++}';
});

final learningRepositoryProvider = FutureProvider<LearningRepository>((
  ref,
) async {
  final storage = await ref.watch(appStorageDirectoryProvider.future);
  if (!ref.mounted) {
    throw StateError('Learning was disposed during initialization.');
  }
  final repository = await HiveLearningRepository.open(
    directory: resolveAppStorageDirectory(storage).path,
  );
  if (!ref.mounted) {
    await repository.close();
    throw StateError('Learning was disposed during initialization.');
  }
  ref.onDispose(() {
    unawaited(
      repository.close().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Learning storage could not be closed cleanly.');
      }),
    );
  });
  return repository;
}, retry: (retryCount, error) => null);

final class LearningSessionState {
  LearningSessionState({
    required this.durable,
    required this.visible,
    required Iterable<CorruptRecord> corruptRecords,
    required this.saving,
    required this.saveError,
  }) : corruptRecords = List.unmodifiable(corruptRecords);

  final LearningLibrary durable;
  final LearningLibrary visible;
  final List<CorruptRecord> corruptRecords;
  final bool saving;
  final Object? saveError;

  LearningSessionState copyWith({
    LearningLibrary? durable,
    LearningLibrary? visible,
    Iterable<CorruptRecord>? corruptRecords,
    bool? saving,
    Object? saveError,
    bool clearSaveError = false,
  }) => LearningSessionState(
    durable: durable ?? this.durable,
    visible: visible ?? this.visible,
    corruptRecords: corruptRecords ?? this.corruptRecords,
    saving: saving ?? this.saving,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
  );
}

final learningSessionProvider =
    AsyncNotifierProvider<LessonSessionController, LearningSessionState>(
      LessonSessionController.new,
      retry: (retryCount, error) => null,
    );

final learningLibraryProvider = Provider<LearningLibrary>((ref) {
  return ref.watch(learningSessionProvider).value?.visible ??
      LearningLibrary.empty();
});

final learningCorruptRecordsProvider = Provider<List<CorruptRecord>>((ref) {
  return ref.watch(learningSessionProvider).value?.corruptRecords ?? const [];
});

class LessonSessionController extends AsyncNotifier<LearningSessionState> {
  Future<void> _pending = Future<void>.value();
  int _generation = 0;

  @override
  Future<LearningSessionState> build() async {
    final generation = ++_generation;
    final repository = await ref.watch(learningRepositoryProvider.future);
    final loaded = await repository.load();
    if (!ref.mounted || generation != _generation) {
      throw StateError('Stale learning library load.');
    }
    return LearningSessionState(
      durable: loaded.library,
      visible: loaded.library,
      corruptRecords: loaded.corruptRecords,
      saving: false,
      saveError: null,
    );
  }

  Future<LearningChange<T>> _mutate<T>(
    LearningChange<T> Function(LearningLibrary visible) transition,
  ) {
    final completer = Completer<LearningChange<T>>();
    _pending = _pending.then((_) async {
      try {
        await future;
        if (!ref.mounted) {
          throw StateError('Learning session is no longer available.');
        }
        final before = state.requireValue;
        final intended = transition(before.visible);
        state = AsyncData(
          before.copyWith(
            visible: intended.state,
            saving: true,
            clearSaveError: true,
          ),
        );
        final repository = await ref.read(learningRepositoryProvider.future);
        final generation = _generation;
        try {
          final acknowledged = await repository.transact((_) => intended);
          if (!ref.mounted || generation != _generation) {
            throw StateError('Stale learning write.');
          }
          final loaded = await repository.load();
          if (!ref.mounted || generation != _generation) {
            throw StateError('Stale learning reload.');
          }
          state = AsyncData(
            LearningSessionState(
              durable: loaded.library,
              visible: loaded.library,
              corruptRecords: loaded.corruptRecords,
              saving: false,
              saveError: null,
            ),
          );
          completer.complete(acknowledged);
        } catch (error, stackTrace) {
          if (ref.mounted && generation == _generation) {
            state = AsyncData(
              before.copyWith(
                visible: intended.state,
                saving: false,
                saveError: error,
              ),
            );
          }
          completer.completeError(error, stackTrace);
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    });
    return completer.future;
  }

  DateTime _now() => ref.read(learningClockProvider)().toUtc();
  String _id(String prefix) => ref.read(learningIdProvider)(prefix);

  Future<LessonProgress> openLesson(String lessonId) async {
    await future;
    final lesson = ColorFoundationsCatalog.byId(lessonId);
    final visible = state.requireValue.visible;
    final existing = visible.progressByLesson[lessonId];
    if (existing != null && existing.lessonRevision == lesson.revision) {
      return existing;
    }
    return (await _mutate((current) {
      final previous = current.progressByLesson[lessonId];
      final archive = <PracticeAttempt>[...current.practiceHistory];
      if (previous != null) {
        for (final response in previous.answers.values) {
          for (var index = 0; index < response.attempts.length; index++) {
            final attempt = response.attempts[index];
            archive.add(
              PracticeAttempt(
                id: _id(
                  'practice-revision-$lessonId-${previous.lessonRevision}-${response.questionId}-$index',
                ),
                lessonId: lessonId,
                activityId: response.questionId,
                answerId: attempt.answerId,
                correct: attempt.correct,
                explanationKey: attempt.explanationKey,
                attemptedAt: attempt.attemptedAt,
              ),
            );
          }
        }
      }
      final progress = _freshProgress(lesson);
      return LearningChange(
        state: current.copyWith(
          progressByLesson: {...current.progressByLesson, lessonId: progress},
          practiceHistory: archive,
        ),
        value: progress,
      );
    })).value;
  }

  LessonProgress _freshProgress(LearningLesson lesson) => LessonProgress(
    lessonId: lesson.id,
    lessonRevision: lesson.revision,
    currentStepIndex: 0,
    completedStepIds: const {},
    answers: const {},
    completed: false,
    updatedAt: _now(),
  );

  Future<LessonProgress> setCurrentStep(String lessonId, String stepId) async =>
      (await _mutate((current) {
        final lesson = ColorFoundationsCatalog.byId(lessonId);
        final progress = _currentProgress(current, lesson);
        final target = lesson.steps.indexWhere((step) => step.id == stepId);
        if (target < 0) throw StateError('Unknown lesson step.');
        final highestCompleted = lesson.steps.lastIndexWhere(
          (step) => progress.completedStepIds.contains(step.id),
        );
        final furthest = progress.currentStepIndex > highestCompleted
            ? progress.currentStepIndex
            : highestCompleted;
        if (target > furthest + 1) {
          throw StateError('Complete the current stage before moving ahead.');
        }
        final completed = {...progress.completedStepIds};
        if (target > progress.currentStepIndex) {
          completed.add(lesson.steps[progress.currentStepIndex].id);
        }
        final updated = progress.copyWith(
          currentStepIndex: target,
          completedStepIds: completed,
          updatedAt: _now(),
        );
        return LearningChange(
          state: current.copyWith(
            progressByLesson: {...current.progressByLesson, lessonId: updated},
          ),
          value: updated,
        );
      })).value;

  Future<QuestionResponse> answerQuestion({
    required String lessonId,
    required String questionId,
    required String answerId,
  }) async => (await _mutate((current) {
    final lesson = ColorFoundationsCatalog.byId(lessonId);
    final progress = _currentProgress(current, lesson);
    final question = lesson.questionById(questionId);
    final answer = question.answerById(answerId);
    final attempt = QuestionAttempt(
      answerId: answer.id,
      correct: answer.correct,
      explanationKey: answer.explanationKey,
      attemptedAt: _now(),
    );
    final response = progress.answers[questionId] == null
        ? QuestionResponse(questionId: questionId, attempts: [attempt])
        : progress.answers[questionId]!.add(attempt);
    final answers = {...progress.answers, questionId: response};
    final updated = progress.copyWith(answers: answers, updatedAt: _now());
    final revisit = {...current.topicsToRevisit};
    if (!answer.correct) {
      revisit.add(lesson.topic);
    } else if (lesson.questions.every(
      (item) => answers[item.id]?.latest.correct == true,
    )) {
      revisit.remove(lesson.topic);
    }
    final history = [
      ...current.practiceHistory,
      PracticeAttempt(
        id: _id('practice-$lessonId-${current.practiceHistory.length + 1}'),
        lessonId: lessonId,
        activityId: questionId,
        answerId: answer.id,
        correct: answer.correct,
        explanationKey: answer.explanationKey,
        attemptedAt: attempt.attemptedAt,
      ),
    ];
    return LearningChange(
      state: current.copyWith(
        progressByLesson: {...current.progressByLesson, lessonId: updated},
        practiceHistory: history,
        topicsToRevisit: revisit,
      ),
      value: response,
    );
  })).value;

  Future<LessonProgress> completeLesson(String lessonId) async =>
      (await _mutate((current) {
        final lesson = ColorFoundationsCatalog.byId(lessonId);
        final progress = _currentProgress(current, lesson);
        if (progress.currentStepIndex != lesson.steps.length - 1 ||
            !lesson.questions.every(
              (question) => progress.answers.containsKey(question.id),
            )) {
          throw StateError(
            'Finish every stage and answer every question first.',
          );
        }
        final updated = progress.copyWith(
          completedStepIds: lesson.steps.map((step) => step.id),
          completed: true,
          updatedAt: _now(),
        );
        return LearningChange(
          state: current.copyWith(
            progressByLesson: {...current.progressByLesson, lessonId: updated},
          ),
          value: updated,
        );
      })).value;

  Future<void> resetLesson(String lessonId) async {
    await _mutate((current) {
      final lesson = ColorFoundationsCatalog.byId(lessonId);
      final progress = _freshProgress(lesson);
      return LearningChange<void>(
        state: current.copyWith(
          progressByLesson: {...current.progressByLesson, lessonId: progress},
          topicsToRevisit: {...current.topicsToRevisit}..remove(lesson.topic),
        ),
        value: null,
      );
    });
  }

  Future<ExperimentRecord> saveExperiment({
    required String title,
    required String? lessonId,
    required ExperimentSnapshot snapshot,
    required List<RgbColor> results,
    required String observation,
  }) async => (await _mutate((current) {
    if (snapshot is UnknownExperimentSnapshot) {
      throw StateError('A newer experiment cannot be saved by this version.');
    }
    if (lessonId != null) ColorFoundationsCatalog.byId(lessonId);
    final timestamp = _now();
    final record = ExperimentRecord(
      id: _id('experiment'),
      title: title,
      lessonId: lessonId,
      inputHexes: _snapshotInputs(snapshot),
      resultHexes: [
        for (final color in results)
          RgbColor(color.red, color.green, color.blue).hex,
      ],
      snapshot: snapshot,
      observation: observation,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    return LearningChange(
      state: current.copyWith(experiments: [record, ...current.experiments]),
      value: record,
    );
  })).value;

  Future<void> deleteExperiment(String experimentId) async {
    await _mutate((current) {
      if (!current.experiments.any((item) => item.id == experimentId)) {
        throw StateError('Experiment does not exist.');
      }
      return LearningChange<void>(
        state: current.copyWith(
          experiments: current.experiments.where(
            (item) => item.id != experimentId,
          ),
        ),
        value: null,
      );
    });
  }

  Future<void> retryVisible() async {
    await future;
    final visible = state.requireValue.visible;
    await _mutate((_) => LearningChange<void>(state: visible, value: null));
  }

  LessonProgress _currentProgress(
    LearningLibrary library,
    LearningLesson lesson,
  ) {
    final progress = library.progressByLesson[lesson.id];
    if (progress == null || progress.lessonRevision != lesson.revision) {
      throw StateError('Open the current lesson revision first.');
    }
    return progress;
  }
}

List<String> _snapshotInputs(ExperimentSnapshot snapshot) => switch (snapshot) {
  LabExperimentSnapshot() => [
    HslColor(snapshot.hue, snapshot.saturation, snapshot.lightness).toRgb().hex,
  ],
  MixerExperimentSnapshot() => [for (final stop in snapshot.stops) stop.hex],
  HarmonyExperimentSnapshot() => [snapshot.baseHex],
  FormulaExperimentSnapshot() => [snapshot.targetHex],
  MatchingExperimentSnapshot() => [snapshot.targetHex, snapshot.guessHex],
  UnknownExperimentSnapshot() => throw StateError(
    'Unknown experiment snapshots cannot be edited.',
  ),
};
