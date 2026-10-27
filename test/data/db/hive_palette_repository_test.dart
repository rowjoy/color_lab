import 'dart:io';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/db/hive_palette_repository.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/palette/domain/saved_palette_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory directory;
  late HivePaletteRepository repository;
  var now = DateTime.utc(2026, 10, 21, 9);
  const boxName = 'palettes_test';
  final base = RgbColor(170, 187, 204);
  final error = throwsA(isA<PaletteStorageException>());
  Future<SavedPalette> save({
    String name = 'Mist',
    RgbColor? anchor,
    HarmonyMode mode = HarmonyMode.complementary,
    Iterable<RgbColor>? colors,
  }) => repository.save(
    name: name,
    base: anchor ?? base,
    mode: mode,
    colors: colors ?? [anchor ?? base, RgbColor(1, 2, 3)],
  );
  Future<void> reopen() async {
    await repository.close();
    repository = await HivePaletteRepository.open(
      directory: directory.path,
      boxName: boxName,
      clock: () => now,
    );
  }

  setUp(() async {
    now = DateTime.utc(2026, 10, 21, 9);
    directory = await Directory.systemTemp.createTemp('palette-repository-');
    repository = await HivePaletteRepository.open(
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
    'reopens the complete arbitrary stored snapshot and immutable library',
    () async {
      final colors = [base, RgbColor(1, 2, 3), RgbColor(4, 5, 6)];
      final saved = await save(colors: colors);
      colors.clear();
      await reopen();
      final loaded = await repository.load();
      expect(loaded, [saved]);
      expect(loaded.single.toMap(), {
        'version': 1,
        'id': 'complementary-AABBCC',
        'name': 'Mist',
        'base': '#AABBCC',
        'mode': 'complementary',
        'colors': ['#AABBCC', '#010203', '#040506'],
        'createdAt': '2026-10-21T09:00:00.000Z',
      });
      expect(() => loaded.clear(), throwsUnsupportedError);
      expect(() => loaded.single.colors.clear(), throwsUnsupportedError);
    },
  );

  test(
    'duplicate base mode preserves name date and original colors exactly',
    () async {
      final first = await save();
      now = DateTime.utc(2027);
      final duplicate = await save(name: 'Other', colors: [base]);
      expect(duplicate, first);
      final triadic = await save(mode: HarmonyMode.triadic, colors: [base]);
      await reopen();
      expect(await repository.load(), [triadic, first]);
    },
  );

  test('sorts dates descending with ids ascending for equal dates', () async {
    await save(anchor: RgbColor(255, 255, 255));
    await save(anchor: RgbColor(0, 0, 0));
    now = now.add(const Duration(seconds: 1));
    await save(mode: HarmonyMode.triadic);
    await reopen();
    expect((await repository.load()).map((p) => p.id), [
      'triadic-AABBCC',
      'complementary-000000',
      'complementary-FFFFFF',
    ]);
  });

  test('serializes concurrent saves duplicate delete read and close', () async {
    final first = save();
    final duplicate = save(name: 'Later', colors: [base]);
    final other = save(mode: HarmonyMode.triadic);
    final deletion = repository.delete('triadic-AABBCC');
    final snapshot = repository.load();
    final closing = repository.close();
    await Future.wait([first, duplicate, other, deletion, closing]);
    expect(await snapshot, [await first]);
    expect(await duplicate, await first);
    await expectLater(repository.load(), error);
    await reopen();
    expect(await repository.load(), [await first]);
    await repository.delete('complementary-AABBCC');
    await repository.delete('complementary-AABBCC');
    await reopen();
    expect(await repository.load(), isEmpty);
  });

  test('equal box names in separate directories remain independent', () async {
    final otherDirectory = await Directory.systemTemp.createTemp(
      'palette-other-',
    );
    final other = await HivePaletteRepository.open(
      directory: otherDirectory.path,
      boxName: boxName,
    );
    try {
      final first = await save();
      final second = await other.save(
        name: 'Other',
        base: base,
        mode: HarmonyMode.triadic,
        colors: [base],
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
      'id': 'complementary-AABBCC',
      'name': 'Mist',
      'base': '#AABBCC',
      'mode': 'complementary',
      'colors': ['#AABBCC'],
      'createdAt': '2026-10-21T09:00:00.000Z',
    },
  ]) {
    test(
      'invalid schema or mismatched key is isolated during edits: $malformed',
      () async {
        final valid = await save();
        await repository.close();
        final box = await Hive.openBox<dynamic>(boxName, path: directory.path);
        await box.put('wrong-key', malformed);
        await box.close();
        repository = await HivePaletteRepository.open(
          directory: directory.path,
          boxName: boxName,
        );
        final snapshot = await repository.loadSnapshot();
        expect(snapshot.records, [valid]);
        expect(snapshot.corruptRecords.single.storageKey, 'wrong-key');
        expect(await save(name: 'Duplicate'), valid);
        final created = await save(mode: HarmonyMode.triadic);
        await repository.delete(valid.id);
        await repository.delete('wrong-key');
        expect((await repository.loadSnapshot()).records, [created]);
        await repository.close();
        final unchanged = await Hive.openBox<dynamic>(
          boxName,
          path: directory.path,
        );
        expect(unchanged.get('wrong-key'), malformed);
        expect(unchanged.length, 2);
        expect(unchanged.containsKey(created.id), isTrue);
        await unchanged.close();
      },
    );
  }

  test(
    'corrupt file fails open without truncation or unhandled open future',
    () async {
      await repository.close();
      final file = File('${directory.path}/$boxName.hive');
      const bytes = [12, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8];
      await file.writeAsBytes(bytes, flush: true);
      await expectLater(
        HivePaletteRepository.open(directory: directory.path, boxName: boxName),
        error,
      );
      expect(await file.readAsBytes(), bytes);
    },
  );

  test(
    'unreadable directory produces only a safe generic storage exception',
    () async {
      final file = File('${directory.path}/private-data');
      await file.writeAsString('private record');
      await expectLater(
        HivePaletteRepository.open(directory: file.path),
        error,
      );
      expect(
        const PaletteStorageException().toString(),
        isNot(contains(directory.path)),
      );
      expect(await file.readAsString(), 'private record');
    },
  );
}
