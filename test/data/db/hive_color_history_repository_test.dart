import 'dart:io';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/db/hive_color_history_repository.dart';
import 'package:color_lab/features/history/domain/color_history_repository.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late HiveColorHistoryRepository repository;
  var now = DateTime.utc(2026, 10, 21, 9);
  const boxName = 'history_test';

  Future<void> reopen() async {
    await repository.close();
    repository = await HiveColorHistoryRepository.open(
      directory: directory.path,
      boxName: boxName,
      clock: () => now,
    );
  }

  setUp(() async {
    now = DateTime.utc(2026, 10, 21, 9);
    directory = await Directory.systemTemp.createTemp('color-history-test-');
    repository = await HiveColorHistoryRepository.open(
      directory: directory.path,
      boxName: boxName,
      clock: () => now,
    );
  });

  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'saves all metadata to disk and returns immutable loaded snapshots',
    () async {
      final saved = await repository.save(
        color: RgbColor(170, 187, 204),
        name: 'Mist',
        source: ColorSource.gallery,
      );
      expect(saved.id, '#AABBCC');
      expect(saved.createdAt, DateTime.utc(2026, 10, 21, 9));
      await reopen();
      final loaded = await repository.load();
      expect(loaded, [saved]);
      expect(loaded.single.source, ColorSource.gallery);
      expect(() => loaded.clear(), throwsUnsupportedError);
    },
  );

  test('persists favorite changes through close and reopen', () async {
    await repository.save(
      color: RgbColor(1, 2, 3),
      name: 'Ink',
      source: ColorSource.manual,
    );
    final before = await repository.load();
    await repository.setFavorite('#010203', true);
    expect(before.single.isFavorite, isFalse);
    await reopen();
    expect((await repository.load()).single.isFavorite, isTrue);
    await repository.setFavorite('#010203', false);
    await reopen();
    expect((await repository.load()).single.isFavorite, isFalse);
  });

  test('deletes durably and missing deletes are idempotent', () async {
    await repository.save(
      color: RgbColor(1, 2, 3),
      name: 'Ink',
      source: ColorSource.manual,
    );
    await repository.delete('#010203');
    await repository.delete('#010203');
    await reopen();
    expect(await repository.load(), isEmpty);
  });

  test(
    'repeat saves preserve original source, name, favorite and date',
    () async {
      final first = await repository.save(
        color: RgbColor(1, 2, 3),
        name: 'First',
        source: ColorSource.lab,
      );
      await repository.setFavorite(first.id, true);
      now = DateTime.utc(2027);
      final duplicate = await repository.save(
        color: RgbColor(1, 2, 3),
        name: 'Later',
        source: ColorSource.room,
      );
      expect(duplicate, first.copyWith(isFavorite: true));
      await reopen();
      expect(await repository.load(), [duplicate]);
    },
  );

  test('sorts newest first and breaks equal times by normalized id', () async {
    await repository.save(
      color: RgbColor(255, 255, 255),
      name: 'White',
      source: ColorSource.manual,
    );
    await repository.save(
      color: RgbColor(0, 0, 0),
      name: 'Black',
      source: ColorSource.manual,
    );
    now = now.add(const Duration(seconds: 1));
    await repository.save(
      color: RgbColor(255, 0, 0),
      name: 'Red',
      source: ColorSource.manual,
    );
    await reopen();
    expect((await repository.load()).map((color) => color.id), [
      '#FF0000',
      '#000000',
      '#FFFFFF',
    ]);
  });

  test(
    'serializes concurrent save favorite duplicate delete and load',
    () async {
      final firstSave = repository.save(
        color: RgbColor(1, 2, 3),
        name: 'First',
        source: ColorSource.camera,
      );
      final favorite = repository.setFavorite('#010203', true);
      final duplicate = repository.save(
        color: RgbColor(1, 2, 3),
        name: 'Later',
        source: ColorSource.manual,
      );
      final secondSave = repository.save(
        color: RgbColor(4, 5, 6),
        name: 'Other',
        source: ColorSource.manual,
      );
      final deletion = repository.delete('#040506');
      final snapshot = repository.load();
      await Future.wait([firstSave, favorite, duplicate, secondSave, deletion]);
      expect((await duplicate).isFavorite, isTrue);
      expect((await duplicate).name, 'First');
      expect(await snapshot, [await duplicate]);
      await reopen();
      expect(await repository.load(), [await duplicate]);
    },
  );

  test(
    'missing favorites throw a typed error without poisoning later edits',
    () async {
      await expectLater(
        repository.setFavorite('#010203', true),
        throwsA(isA<HistoryStorageException>()),
      );
      await repository.save(
        color: RgbColor(1, 2, 3),
        name: 'Ink',
        source: ColorSource.manual,
      );
      expect((await repository.load()).single.isFavorite, isFalse);
    },
  );

  test(
    'malformed records are isolated while healthy edits remain durable',
    () async {
      final valid = await repository.save(
        color: RgbColor(1, 2, 3),
        name: 'Ink',
        source: ColorSource.manual,
      );
      await repository.close();
      final box = await Hive.openBox<dynamic>(boxName, path: directory.path);
      final malformed = {'version': 99, 'source': 'future'};
      await box.put('#BADBAD', malformed);
      await box.close();
      repository = await HiveColorHistoryRepository.open(
        directory: directory.path,
        boxName: boxName,
      );

      final snapshot = await repository.loadSnapshot();
      expect(snapshot.records, [valid]);
      expect(snapshot.corruptRecords.single.storageKey, '#BADBAD');
      await expectLater(
        repository.save(
          color: RgbColor(186, 219, 173),
          name: 'Conflicting',
          source: ColorSource.manual,
        ),
        throwsA(isA<HistoryStorageException>()),
      );
      final created = await repository.save(
        color: RgbColor(7, 8, 9),
        name: 'New',
        source: ColorSource.manual,
      );
      await repository.setFavorite(valid.id, true);
      await repository.delete(valid.id);
      await repository.delete('#BADBAD');
      expect((await repository.loadSnapshot()).records, [created]);
      await repository.close();
      final unchanged = await Hive.openBox<dynamic>(
        boxName,
        path: directory.path,
      );
      expect(unchanged.get('#BADBAD'), malformed);
      expect(unchanged.containsKey(valid.id), isFalse);
      expect(unchanged.containsKey(created.id), isTrue);
      await unchanged.close();
    },
  );

  test(
    'closing waits for queued writes and rejects subsequent operations',
    () async {
      final saving = repository.save(
        color: RgbColor(1, 2, 3),
        name: 'Ink',
        source: ColorSource.manual,
      );
      final closing = repository.close();
      await saving;
      await closing;
      await expectLater(
        repository.load(),
        throwsA(isA<HistoryStorageException>()),
      );
      await reopen();
      expect((await repository.load()).single.name, 'Ink');
    },
  );

  test(
    'opening a file as a directory reports a generic typed storage failure',
    () async {
      final file = File('${directory.path}/not-a-directory');
      await file.writeAsString('keep');
      await expectLater(
        HiveColorHistoryRepository.open(directory: file.path),
        throwsA(isA<HistoryStorageException>()),
      );
      expect(await file.readAsString(), 'keep');
    },
  );

  test(
    'corrupt Hive bytes fail open without automatic recovery or truncation',
    () async {
      await repository.close();
      final file = File('${directory.path}/$boxName.hive');
      const corruptBytes = [12, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8];
      await file.writeAsBytes(corruptBytes, flush: true);
      await expectLater(
        HiveColorHistoryRepository.open(
          directory: directory.path,
          boxName: boxName,
        ),
        throwsA(isA<HistoryStorageException>()),
      );
      expect(await file.readAsBytes(), corruptBytes);
    },
  );

  test(
    'equal box names in different directories keep independent libraries',
    () async {
      final otherDirectory = await Directory.systemTemp.createTemp(
        'color-history-other-',
      );
      final other = await HiveColorHistoryRepository.open(
        directory: otherDirectory.path,
        boxName: boxName,
      );
      try {
        await repository.save(
          color: RgbColor(1, 2, 3),
          name: 'Ink',
          source: ColorSource.manual,
        );
        await other.save(
          color: RgbColor(4, 5, 6),
          name: 'Ash',
          source: ColorSource.manual,
        );
        expect((await repository.load()).single.hex, '#010203');
        expect((await other.load()).single.hex, '#040506');
      } finally {
        await other.close();
        await otherDirectory.delete(recursive: true);
      }
    },
  );
}
