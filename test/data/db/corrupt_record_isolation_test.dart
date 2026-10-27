import 'dart:io';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/db/hive_color_history_repository.dart';
import 'package:color_lab/data/db/hive_palette_repository.dart';
import 'package:color_lab/data/db/hive_room_design_repository.dart';
import 'package:color_lab/data/schema/corrupt_record.dart';
import 'package:color_lab/data/schema/repository_snapshot.dart';
import 'package:color_lab/features/history/domain/color_history_repository.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/palette/domain/saved_palette_repository.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  const malformed = <String, Object>{
    'version': 99,
    'retainedMarker': 'do-not-overwrite',
  };

  test('repository snapshots defensively own immutable list copies', () {
    final records = <int>[1];
    final corruptRecords = <CorruptRecord>[
      const CorruptRecord(
        collectionId: 'saved-colors',
        storageKey: 'bad',
        reason: 'decode-failed',
      ),
    ];
    final snapshot = RepositorySnapshot<int>(
      records: records,
      corruptRecords: corruptRecords,
    );

    records.clear();
    corruptRecords.clear();
    expect(snapshot.records, [1]);
    expect(snapshot.corruptRecords, hasLength(1));
    expect(() => snapshot.records.clear(), throwsUnsupportedError);
    expect(() => snapshot.corruptRecords.clear(), throwsUnsupportedError);
  });

  test(
    'saved colors isolate malformed records and keep healthy writes',
    () async {
      final fixture = await _BoxFixture.open('corrupt_color_isolation');
      final valid = SavedColor(
        id: '#010203',
        hex: '#010203',
        name: 'Ink',
        isFavorite: false,
        createdAt: DateTime.utc(2026, 10, 27, 8),
        source: ColorSource.lab,
      );
      const corruptKey = '#AABBCC';
      await fixture.box.put(valid.id, valid.toMap());
      await fixture.box.put(corruptKey, malformed);
      final repository = HiveColorHistoryRepository.fromBox(
        box: fixture.box,
        clock: () => DateTime.utc(2026, 10, 27, 9),
      );
      addTearDown(() => fixture.dispose());

      final snapshot = await repository.loadSnapshot();
      _expectIsolated(
        snapshot.records,
        snapshot.corruptRecords,
        valid,
        collectionId: 'saved-colors',
        corruptKey: corruptKey,
      );
      expect(fixture.box.get(corruptKey), malformed);

      await expectLater(
        repository.save(
          color: RgbColor(170, 187, 204),
          name: 'Conflicting',
          source: ColorSource.manual,
        ),
        throwsA(isA<HistoryStorageException>()),
      );

      final created = await repository.save(
        color: RgbColor(4, 5, 6),
        name: 'Slate',
        source: ColorSource.manual,
      );
      await repository.delete(valid.id);
      final updated = await repository.loadSnapshot();
      expect(updated.records, [created]);
      expect(updated.corruptRecords.single.storageKey, corruptKey);
      expect(await repository.load(), [created]);
      expect(fixture.box.get(corruptKey), malformed);
      expect(fixture.box.containsKey(valid.id), isFalse);
      expect(fixture.box.containsKey(created.id), isTrue);
      await repository.close();
      final durable = await fixture.reopen();
      expect(durable.get(corruptKey), malformed);
      expect(durable.containsKey(valid.id), isFalse);
      expect(durable.containsKey(created.id), isTrue);
      await durable.close();
    },
  );

  test(
    'saved palettes isolate malformed records and keep healthy writes',
    () async {
      final fixture = await _BoxFixture.open('corrupt_palette_isolation');
      final valid = SavedPalette(
        name: 'Ocean',
        base: RgbColor(1, 2, 3),
        mode: HarmonyMode.complementary,
        colors: [RgbColor(1, 2, 3), RgbColor(4, 5, 6)],
        createdAt: DateTime.utc(2026, 10, 27, 8),
      );
      const corruptKey = 'triadic-070809';
      await fixture.box.put(valid.id, valid.toMap());
      await fixture.box.put(corruptKey, malformed);
      final repository = HivePaletteRepository.fromBox(
        box: fixture.box,
        clock: () => DateTime.utc(2026, 10, 27, 9),
      );
      addTearDown(() => fixture.dispose());

      final snapshot = await repository.loadSnapshot();
      _expectIsolated(
        snapshot.records,
        snapshot.corruptRecords,
        valid,
        collectionId: 'saved-palettes',
        corruptKey: corruptKey,
      );

      await expectLater(
        repository.save(
          name: 'Conflicting',
          base: RgbColor(7, 8, 9),
          mode: HarmonyMode.triadic,
          colors: [RgbColor(7, 8, 9)],
        ),
        throwsA(isA<PaletteStorageException>()),
      );

      final created = await repository.save(
        name: 'Forest',
        base: RgbColor(10, 11, 12),
        mode: HarmonyMode.triadic,
        colors: [RgbColor(10, 11, 12)],
      );
      await repository.delete(valid.id);
      final updated = await repository.loadSnapshot();
      expect(updated.records, [created]);
      expect(updated.corruptRecords.single.storageKey, corruptKey);
      expect(fixture.box.get(corruptKey), malformed);
      expect(fixture.box.containsKey(valid.id), isFalse);
      expect(fixture.box.containsKey(created.id), isTrue);
      await repository.close();
      final durable = await fixture.reopen();
      expect(durable.get(corruptKey), malformed);
      expect(durable.containsKey(valid.id), isFalse);
      expect(durable.containsKey(created.id), isTrue);
      await durable.close();
    },
  );

  test(
    'room designs isolate malformed records and keep healthy writes',
    () async {
      final fixture = await _BoxFixture.open('corrupt_room_isolation');
      final valid = SavedRoomDesign(
        id: 'study-existing',
        name: 'Existing',
        templateId: 'study',
        colors: _colors,
        createdAt: DateTime.utc(2026, 10, 27, 8),
        updatedAt: DateTime.utc(2026, 10, 27, 8),
      );
      final creationTime = DateTime.utc(2026, 10, 27, 9);
      final corruptKey = 'study-${creationTime.microsecondsSinceEpoch}';
      await fixture.box.put(valid.id, valid.toMap());
      await fixture.box.put(corruptKey, malformed);
      final repository = HiveRoomDesignRepository.fromBox(
        box: fixture.box,
        clock: () => creationTime,
      );
      addTearDown(() => fixture.dispose());

      final snapshot = await repository.loadSnapshot();
      _expectIsolated(
        snapshot.records,
        snapshot.corruptRecords,
        valid,
        collectionId: 'illustrated-rooms',
        corruptKey: corruptKey,
      );

      final created = await repository.save(
        name: 'New study',
        templateId: 'study',
        colors: _colors,
      );
      expect(created.id, '$corruptKey-1');
      await repository.delete(valid.id);
      final updated = await repository.loadSnapshot();
      expect(updated.records, [created]);
      expect(updated.corruptRecords.single.storageKey, corruptKey);
      expect(fixture.box.get(corruptKey), malformed);
      expect(fixture.box.containsKey(valid.id), isFalse);
      expect(fixture.box.containsKey(created.id), isTrue);
      await repository.close();
      final durable = await fixture.reopen();
      expect(durable.get(corruptKey), malformed);
      expect(durable.containsKey(valid.id), isFalse);
      expect(durable.containsKey(created.id), isTrue);
      await durable.close();
    },
  );
}

final _colors = IllustratedRoomColors(
  wall: RgbColor(10, 20, 30),
  ceiling: RgbColor(40, 50, 60),
  floor: RgbColor(70, 80, 90),
  furniture: RgbColor(100, 110, 120),
);

void _expectIsolated<T>(
  List<T> records,
  List<CorruptRecord> corruptRecords,
  T valid, {
  required String collectionId,
  required Object corruptKey,
}) {
  expect(records, [valid]);
  expect(() => records.add(valid), throwsUnsupportedError);
  expect(corruptRecords, hasLength(1));
  final corrupt = corruptRecords.single;
  expect(corrupt.collectionId, collectionId);
  expect(corrupt.storageKey, corruptKey);
  expect(corrupt.reason, isNotEmpty);
  expect(() => corruptRecords.clear(), throwsUnsupportedError);
}

final class _BoxFixture {
  const _BoxFixture(this.directory, this.boxName, this.box);

  final Directory directory;
  final String boxName;
  final Box<dynamic> box;

  static Future<_BoxFixture> open(String boxName) async {
    final directory = await Directory.systemTemp.createTemp('$boxName-');
    final box = await Hive.openBox<dynamic>(
      boxName,
      path: directory.path,
      crashRecovery: false,
    );
    return _BoxFixture(directory, boxName, box);
  }

  Future<Box<dynamic>> reopen() => Hive.openBox<dynamic>(
    boxName,
    path: directory.path,
    crashRecovery: false,
  );

  Future<void> dispose() async {
    if (box.isOpen) await box.close();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
