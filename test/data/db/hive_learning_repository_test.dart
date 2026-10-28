import 'dart:io';

import 'package:color_lab/data/db/hive_learning_repository.dart';
import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/learning/domain/learning_content.dart';
import 'package:color_lab/features/learning/domain/learning_library.dart';
import 'package:color_lab/features/learning/domain/learning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final class _FlushBoundaryBox implements Box<dynamic> {
  _FlushBoundaryBox(this.delegate);

  final Box<dynamic> delegate;
  bool failNextFlush = false;

  @override
  Iterable<dynamic> get keys => delegate.keys;
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) => delegate.put(key, value);
  @override
  Future<void> delete(dynamic key) => delegate.delete(key);
  @override
  Future<void> deleteAll(Iterable<dynamic> keys) => delegate.deleteAll(keys);
  @override
  Future<void> flush() async {
    if (failNextFlush) {
      failNextFlush = false;
      throw const FileSystemException('injected flush failure');
    }
    await delegate.flush();
  }

  @override
  Future<void> close() => delegate.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late _FlushBoundaryBox box;
  late HiveLearningRepository repository;
  final now = DateTime.utc(2026, 10, 28, 6);

  LessonProgress progress(String id, int step) => LessonProgress(
    lessonId: id,
    lessonRevision: 1,
    currentStepIndex: step,
    completedStepIds: step == 0 ? const {} : const {'step-predict'},
    answers: const {},
    completed: false,
    updatedAt: now.add(Duration(minutes: step)),
  );

  ExperimentRecord experiment(String id) => ExperimentRecord(
    id: id,
    title: 'Saved lab state',
    lessonId: 'hue',
    inputHexes: const ['#112233'],
    resultHexes: const ['#445566'],
    snapshot: const LabExperimentSnapshot(
      hue: 210,
      saturation: .5,
      lightness: .3,
    ),
    observation: 'Blue remains dominant.',
    createdAt: now,
    updatedAt: now,
  );

  LearningChange<T> change<T>(LearningLibrary state, T value) =>
      LearningChange(state: state, value: value);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('learning-repository-');
    box = _FlushBoundaryBox(
      await Hive.openBox<dynamic>(
        'learning',
        path: directory.path,
        crashRecovery: false,
      ),
    );
    repository = HiveLearningRepository.fromBox(box: box);
  });

  tearDown(() async {
    try {
      await repository.close();
    } on LearningStorageException {
      await box.delegate.close();
    }
    await directory.delete(recursive: true);
  });

  test('acknowledged independent records survive close and reopen', () async {
    await repository.transact((current) {
      final next = current.copyWith(
        progressByLesson: {'hue': progress('hue', 1)},
        topicsToRevisit: const {LearningTopic.hue},
        experiments: [experiment('experiment-one')],
      );
      return change(next, null);
    });
    await repository.close();
    repository = await HiveLearningRepository.open(
      directory: directory.path,
      boxName: 'learning',
    );

    final loaded = await repository.load();
    expect(loaded.corruptRecords, isEmpty);
    expect(loaded.library.progressByLesson['hue']!.currentStepIndex, 1);
    expect(loaded.library.topicsToRevisit, {LearningTopic.hue});
    expect(loaded.library.experiments.single, experiment('experiment-one'));
  });

  test(
    'concurrent transitions serialize against the acknowledged state',
    () async {
      final first = repository.transact((current) {
        expect(current.progressByLesson, isEmpty);
        return change(
          current.copyWith(progressByLesson: {'hue': progress('hue', 1)}),
          1,
        );
      });
      final second = repository.transact((current) {
        expect(current.progressByLesson.keys, {'hue'});
        return change(
          current.copyWith(
            progressByLesson: {
              ...current.progressByLesson,
              'saturation': progress('saturation', 0),
            },
          ),
          2,
        );
      });

      expect((await first).value, 1);
      expect((await second).value, 2);
      expect((await repository.load()).library.progressByLesson.keys, {
        'hue',
        'saturation',
      });
    },
  );

  test(
    'one corrupt row is reported without hiding or rewriting healthy rows',
    () async {
      await repository.transact(
        (current) => change(
          current.copyWith(
            progressByLesson: {'hue': progress('hue', 1)},
            experiments: [experiment('experiment-one')],
          ),
          null,
        ),
      );
      const corrupt = {'schemaVersion': 999, 'private': 'untouched'};
      await box.delegate.put('progress:broken', corrupt);
      await box.delegate.flush();

      final loaded = await repository.load();
      expect(loaded.library.progressByLesson.keys, {'hue'});
      expect(loaded.library.experiments.single.id, 'experiment-one');
      expect(loaded.corruptRecords, hasLength(1));
      expect(loaded.corruptRecords.single.storageKey, 'progress:broken');
      expect(box.delegate.get('progress:broken'), corrupt);
    },
  );

  test(
    'unknown typed snapshot versions remain healthy and byte-preserved',
    () async {
      final raw = Map<String, Object?>.from(experiment('future').toMap());
      raw['snapshot'] = {
        'schemaVersion': 4,
        'tool': 'lab',
        'coordinates': [0.7, 0.1, 240],
      };
      await box.delegate.put('experiment:future', raw);
      await box.delegate.flush();

      final loaded = await repository.load();
      expect(loaded.corruptRecords, isEmpty);
      expect(
        loaded.library.experiments.single.snapshot,
        isA<UnknownExperimentSnapshot>(),
      );
      expect(box.delegate.get('experiment:future'), raw);
    },
  );

  test(
    'flush failure restores the last acknowledged state before retry',
    () async {
      await repository.transact(
        (current) => change(
          current.copyWith(progressByLesson: {'hue': progress('hue', 1)}),
          null,
        ),
      );
      box.failNextFlush = true;
      await expectLater(
        repository.transact(
          (current) => change(
            current.copyWith(progressByLesson: {'hue': progress('hue', 2)}),
            null,
          ),
        ),
        throwsA(isA<LearningStorageException>()),
      );

      expect(
        (await repository.load())
            .library
            .progressByLesson['hue']!
            .currentStepIndex,
        1,
      );
      await repository.transact(
        (current) => change(
          current.copyWith(progressByLesson: {'hue': progress('hue', 2)}),
          null,
        ),
      );
      expect(
        (await repository.load())
            .library
            .progressByLesson['hue']!
            .currentStepIndex,
        2,
      );
    },
  );

  test('close is idempotent and rejects later work', () async {
    await repository.close();
    await repository.close();
    await expectLater(
      repository.load(),
      throwsA(isA<LearningStorageException>()),
    );
  });
}
