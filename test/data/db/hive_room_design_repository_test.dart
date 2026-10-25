import 'dart:io';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/db/hive_room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final class _FlushBoundaryBox implements Box<dynamic> {
  _FlushBoundaryBox(this.delegate);

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
  Future<void> flush() async {
    if (failFlush) throw const FileSystemException('injected failure');
    await delegate.flush();
  }

  @override
  Future<void> close() => delegate.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late HiveRoomDesignRepository repository;
  var now = DateTime.utc(2026, 10, 25, 4);
  const boxName = 'room_designs_test';
  final error = throwsA(isA<RoomDesignStorageException>());
  final focusSage = IllustratedRoomColors(
    wall: RgbColor.fromHex('#A7B5A0'),
    ceiling: RgbColor.fromHex('#F7F2E8'),
    floor: RgbColor.fromHex('#C9A77B'),
    furniture: RgbColor.fromHex('#5B4636'),
  );
  final coolFocus = IllustratedRoomColors(
    wall: RgbColor.fromHex('#A9BBC8'),
    ceiling: RgbColor.fromHex('#F3F6F7'),
    floor: RgbColor.fromHex('#B99370'),
    furniture: RgbColor.fromHex('#34495E'),
  );

  Future<SavedRoomDesign> save({
    String? existingId,
    String name = 'My focused study',
    String templateId = 'study',
    IllustratedRoomColors? colors,
  }) => repository.save(
    existingId: existingId,
    name: name,
    templateId: templateId,
    colors: colors ?? focusSage,
  );

  Future<void> reopen() async {
    await repository.close();
    repository = await HiveRoomDesignRepository.open(
      directory: directory.path,
      boxName: boxName,
      clock: () => now,
    );
  }

  setUp(() async {
    now = DateTime.utc(2026, 10, 25, 4);
    directory = await Directory.systemTemp.createTemp('room-designs-');
    repository = await HiveRoomDesignRepository.open(
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
    'creates flushes reopens and returns an immutable exact snapshot',
    () async {
      final saved = await save();
      final expectedId = 'study-${now.microsecondsSinceEpoch}';

      expect(saved.id, expectedId);
      expect(saved.createdAt, now);
      expect(saved.updatedAt, now);
      await reopen();
      final loaded = await repository.load();
      expect(loaded, [saved]);
      expect(loaded.single.toMap(), {
        'version': 1,
        'id': expectedId,
        'name': 'My focused study',
        'templateId': 'study',
        'wall': '#A7B5A0',
        'ceiling': '#F7F2E8',
        'floor': '#C9A77B',
        'furniture': '#5B4636',
        'createdAt': '2026-10-25T04:00:00.000Z',
        'updatedAt': '2026-10-25T04:00:00.000Z',
      });
      expect(() => loaded.clear(), throwsUnsupportedError);
    },
  );

  test(
    'updates the requested identity and retains its creation date',
    () async {
      final first = await save();
      now = now.add(const Duration(hours: 2));

      final updated = await save(
        existingId: first.id,
        name: 'Cool focus',
        colors: coolFocus,
      );

      expect(updated.id, first.id);
      expect(updated.createdAt, first.createdAt);
      expect(updated.updatedAt, now);
      expect(updated.name, 'Cool focus');
      expect(updated.colors, coolFocus);
      await reopen();
      expect(await repository.load(), [updated]);
    },
  );

  test(
    'uses deterministic collision suffixes for creates at the same instant',
    () async {
      final first = await save(name: 'First');
      final second = await save(name: 'Second');
      final third = await save(name: 'Third');
      final base = 'study-${now.microsecondsSinceEpoch}';

      expect([first.id, second.id, third.id], [base, '$base-1', '$base-2']);
      await reopen();
      expect((await repository.load()).map((design) => design.id), [
        base,
        '$base-1',
        '$base-2',
      ]);
    },
  );

  test('sorts updated dates descending then IDs ascending for ties', () async {
    final first = await save(name: 'First');
    final second = await save(name: 'Second');
    now = now.add(const Duration(seconds: 1));
    final latest = await save(name: 'Latest', templateId: 'future-room');

    expect((await repository.load()).map((design) => design.id), [
      latest.id,
      first.id,
      second.id,
    ]);
  });

  test('delete is idempotent and durable across reopen', () async {
    final first = await save();
    await repository.delete(first.id);
    await repository.delete(first.id);
    await reopen();
    expect(await repository.load(), isEmpty);
  });

  test('failed flush blocks publication until a durable retry', () async {
    await repository.close();
    final boundary = _FlushBoundaryBox(
      await Hive.openBox<dynamic>(
        boxName,
        path: directory.path,
        crashRecovery: false,
      ),
    );
    repository = HiveRoomDesignRepository.fromBox(
      box: boundary,
      clock: () => now,
    );

    boundary.failFlush = true;
    await expectLater(save(), error);
    await expectLater(repository.load(), error);
    await expectLater(repository.delete('missing'), error);

    boundary.failFlush = false;
    final recovered = await repository.load();
    expect(recovered.single.name, 'My focused study');
    await reopen();
    expect(await repository.load(), recovered);
  });

  test('preserves a valid design for an unavailable future template', () async {
    final saved = await save(templateId: 'future-library');

    await reopen();
    final loaded = (await repository.load()).single;
    expect(loaded, saved);
    expect(loaded.templateId, 'future-library');
  });

  test(
    'missing update target fails safely and never creates a record',
    () async {
      await expectLater(save(existingId: 'missing-id'), error);
      expect(await repository.load(), isEmpty);
      await reopen();
      expect(await repository.load(), isEmpty);
    },
  );

  test('serializes concurrent create update delete load and close', () async {
    final first = save(name: 'First');
    final snapshot = repository.load();
    final closing = repository.close();
    final created = await first;
    await Future.wait([snapshot, closing]);

    expect(await snapshot, [created]);
    await expectLater(repository.load(), error);
    await reopen();
    final updated = save(existingId: created.id, name: 'Updated');
    final deletion = repository.delete(created.id);
    await Future.wait([updated, deletion]);
    expect(await repository.load(), isEmpty);
  });

  test('equal box names in separate directories remain independent', () async {
    final otherDirectory = await Directory.systemTemp.createTemp(
      'room-designs-other-',
    );
    final other = await HiveRoomDesignRepository.open(
      directory: otherDirectory.path,
      boxName: boxName,
      clock: () => now,
    );
    try {
      final first = await save(name: 'First');
      final second = await other.save(
        name: 'Second',
        templateId: 'study',
        colors: coolFocus,
      );
      expect(await repository.load(), [first]);
      expect(await other.load(), [second]);
    } finally {
      await other.close();
      await otherDirectory.delete(recursive: true);
    }
  });

  for (final malformed in <Object>[
    {'version': 99},
    'not a record',
    {
      'version': 1,
      'id': 'different-key',
      'name': 'Stored study',
      'templateId': 'study',
      'wall': '#A7B5A0',
      'ceiling': '#F7F2E8',
      'floor': '#C9A77B',
      'furniture': '#5B4636',
      'createdAt': '2026-10-25T04:00:00.000Z',
      'updatedAt': '2026-10-25T04:00:00.000Z',
    },
  ]) {
    test(
      'malformed or mismatched records block edits without changing bytes: $malformed',
      () async {
        final valid = await save();
        await repository.close();
        final box = await Hive.openBox<dynamic>(boxName, path: directory.path);
        await box.put('wrong-key', malformed);
        await box.close();
        final file = File('${directory.path}/$boxName.hive');
        final before = await file.readAsBytes();

        repository = await HiveRoomDesignRepository.open(
          directory: directory.path,
          boxName: boxName,
          clock: () => now,
        );
        await expectLater(repository.load(), error);
        await expectLater(save(name: 'Blocked'), error);
        await expectLater(repository.delete(valid.id), error);
        await repository.close();

        expect(await file.readAsBytes(), before);
        final unchanged = await Hive.openBox<dynamic>(
          boxName,
          path: directory.path,
        );
        expect(unchanged.get('wrong-key'), malformed);
        expect(unchanged.length, 2);
        await unchanged.close();
      },
    );
  }

  test('corrupt bytes fail open without truncating the file', () async {
    await repository.close();
    final file = File('${directory.path}/$boxName.hive');
    const bytes = [12, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8];
    await file.writeAsBytes(bytes, flush: true);

    await expectLater(
      HiveRoomDesignRepository.open(
        directory: directory.path,
        boxName: boxName,
      ),
      error,
    );
    expect(await file.readAsBytes(), bytes);
  });

  test('unreadable directory exposes only a generic safe exception', () async {
    final file = File('${directory.path}/private-data');
    await file.writeAsString('private room record');

    await expectLater(
      HiveRoomDesignRepository.open(directory: file.path),
      error,
    );
    expect(
      const RoomDesignStorageException().toString(),
      isNot(contains(directory.path)),
    );
    expect(await file.readAsString(), 'private room record');
  });
}
