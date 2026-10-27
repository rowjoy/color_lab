import 'dart:io';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/db/hive_color_history_repository.dart';
import 'package:color_lab/features/history/domain/color_history_repository.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The real disk box handles reads and writes. Only the OS flush boundary fails.
class _FailingFlushBox implements Box<dynamic> {
  _FailingFlushBox(this.delegate);

  final Box<dynamic> delegate;
  bool failFlush = false;

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
  Future<void> flush() {
    if (failFlush) {
      throw const FileSystemException('Injected flush failure');
    }
    return delegate.flush();
  }

  @override
  Future<void> close() => delegate.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late _FailingFlushBox box;
  late HiveColorHistoryRepository repository;
  const boxName = 'history_durability';
  final storageError = throwsA(isA<HistoryStorageException>());

  Future<SavedColor> save({String name = 'Ink'}) => repository.save(
    color: RgbColor(1, 2, 3),
    name: name,
    source: ColorSource.lab,
  );

  Future<void> reopen() async {
    await repository.close();
    repository = await HiveColorHistoryRepository.open(
      directory: directory.path,
      boxName: boxName,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('history-durability-');
    final realBox = await Hive.openBox<dynamic>(
      boxName,
      path: directory.path,
      crashRecovery: false,
    );
    box = _FailingFlushBox(realBox);
    repository = HiveColorHistoryRepository.fromBox(
      box: box,
      clock: () => DateTime.utc(2026, 10, 21, 9),
    );
  });

  tearDown(() async {
    box.failFlush = false;
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'failed save flush blocks reads and duplicate saves until retry persists',
    () async {
      box.failFlush = true;
      await expectLater(save(), storageError);
      await expectLater(repository.load(), storageError);
      await expectLater(save(name: 'Duplicate'), storageError);
      // Even unrelated no-op branches must respect the pending durability barrier.
      await expectLater(repository.delete('#070809'), storageError);
      box.failFlush = false;
      final retried = await save(name: 'Duplicate');
      expect(retried.name, 'Ink');
      expect(retried.createdAt, DateTime.utc(2026, 10, 21, 9));
      await reopen();
      expect(await repository.load(), [retried]);
    },
  );

  test(
    'failed favorite flush blocks reads and unchanged favorite retries',
    () async {
      final saved = await save();
      box.failFlush = true;
      await expectLater(repository.setFavorite(saved.id, true), storageError);
      await expectLater(repository.load(), storageError);
      await expectLater(repository.setFavorite(saved.id, true), storageError);
      await expectLater(save(name: 'Duplicate'), storageError);
      box.failFlush = false;
      await repository.setFavorite(saved.id, true);
      await reopen();
      expect(await repository.load(), [saved.copyWith(isFavorite: true)]);
    },
  );

  test('failed delete flush blocks reads and missing-delete retries', () async {
    final saved = await save();
    box.failFlush = true;
    await expectLater(repository.delete(saved.id), storageError);
    await expectLater(repository.load(), storageError);
    await expectLater(repository.delete(saved.id), storageError);
    box.failFlush = false;
    await repository.delete(saved.id);
    await reopen();
    expect(await repository.load(), isEmpty);
  });

  test(
    'successful read retries a failed flush before exposing the committed record',
    () async {
      box.failFlush = true;
      await expectLater(save(), storageError);
      await expectLater(repository.loadSnapshot(), storageError);
      await expectLater(repository.load(), storageError);
      box.failFlush = false;
      expect((await repository.loadSnapshot()).records.single.name, 'Ink');
      await reopen();
      expect((await repository.load()).single.name, 'Ink');
    },
  );

  test(
    'queued close retries pending durability and a failed close remains retryable',
    () async {
      box.failFlush = true;
      final saving = save();
      final closing = repository.close();
      await Future.wait([
        expectLater(saving, storageError),
        expectLater(closing, storageError),
      ]);
      await expectLater(repository.load(), storageError);
      box.failFlush = false;
      await reopen();
      expect((await repository.load()).single.name, 'Ink');
    },
  );
}
