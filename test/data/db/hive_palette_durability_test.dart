import 'dart:io';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/db/hive_palette_repository.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/palette/domain/saved_palette_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Retains real disk/cache writes; only the operating system flush may fail.
class _FlushBoundaryBox implements Box<dynamic> {
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
  late _FlushBoundaryBox box;
  late HivePaletteRepository repository;
  const boxName = 'palette_durability';
  final base = RgbColor(1, 2, 3);
  final error = throwsA(isA<PaletteStorageException>());
  Future<SavedPalette> save({String name = 'Ink'}) => repository.save(
    name: name,
    base: base,
    mode: HarmonyMode.complementary,
    colors: [base, RgbColor(4, 5, 6)],
  );
  Future<void> reopen() async {
    await repository.close();
    repository = await HivePaletteRepository.open(
      directory: directory.path,
      boxName: boxName,
    );
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('palette-durability-');
    box = _FlushBoundaryBox(
      await Hive.openBox<dynamic>(
        boxName,
        path: directory.path,
        crashRecovery: false,
      ),
    );
    repository = HivePaletteRepository.fromBox(
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
    'failed save flush blocks reads duplicate and missing delete until durable retry',
    () async {
      box.failFlush = true;
      await expectLater(save(), error);
      await expectLater(repository.load(), error);
      await expectLater(save(name: 'Later'), error);
      await expectLater(repository.delete('missing'), error);
      box.failFlush = false;
      final duplicate = await save(name: 'Later');
      expect(duplicate.name, 'Ink');
      expect(duplicate.createdAt, DateTime.utc(2026, 10, 21, 9));
      await reopen();
      expect(await repository.load(), [duplicate]);
    },
  );
  test(
    'failed delete flush blocks reads and no-op retries until durable',
    () async {
      final first = await save();
      box.failFlush = true;
      await expectLater(repository.delete(first.id), error);
      await expectLater(repository.load(), error);
      await expectLater(repository.delete(first.id), error);
      box.failFlush = false;
      await repository.delete(first.id);
      await reopen();
      expect(await repository.load(), isEmpty);
    },
  );
  test(
    'read recovery flushes pending cache before publishing persisted snapshot',
    () async {
      box.failFlush = true;
      await expectLater(save(), error);
      box.failFlush = false;
      expect((await repository.load()).single.name, 'Ink');
      await reopen();
      expect((await repository.load()).single.colors.map((c) => c.hex), [
        '#010203',
        '#040506',
      ]);
    },
  );
  test(
    'queued failed close remains retryable and persists queued write',
    () async {
      box.failFlush = true;
      final saving = save();
      final closing = repository.close();
      await Future.wait([
        expectLater(saving, error),
        expectLater(closing, error),
      ]);
      expect(box.delegate.isOpen, isTrue);
      await expectLater(repository.load(), error);
      box.failFlush = false;
      await reopen();
      expect((await repository.load()).single.name, 'Ink');
    },
  );
}
