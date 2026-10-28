import 'dart:io';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/db/hive_coloring_project_repository.dart';
import 'package:color_lab/data/storage/local_data_manager.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

final class _FlushBoundaryBox implements Box<dynamic> {
  _FlushBoundaryBox(this.delegate);

  final Box<dynamic> delegate;
  final Set<int> failingFlushCalls = {};
  int flushCalls = 0;

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
    flushCalls++;
    if (failingFlushCalls.remove(flushCalls)) {
      throw const FileSystemException('injected flush failure');
    }
    await delegate.flush();
  }

  @override
  Future<void> close() => delegate.close();
  @override
  bool get isOpen => delegate.isOpen;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late Box<dynamic> box;
  late _FlushBoundaryBox guardedBox;
  late HiveColoringProjectRepository repository;

  ColoringProject project(String id, ColoringMode mode) => ColoringProject(
    id: id,
    drawingId: 'fruit_red_apple',
    drawingRevision: 1,
    mode: mode,
    assignments: const {},
    guidedFilledRegionIds: const {},
    undoStack: const [],
    redoStack: const [],
    completed: false,
    createdAt: DateTime.utc(2026, 10, 28),
    updatedAt: DateTime.utc(2026, 10, 28),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('coloring-repository-');
    box = await Hive.openBox<dynamic>(
      'coloring',
      path: directory.path,
      crashRecovery: false,
    );
    guardedBox = _FlushBoundaryBox(box);
    repository = HiveColoringProjectRepository.fromBox(box: guardedBox);
  });

  tearDown(() async {
    try {
      await repository.close();
    } on Object {
      if (box.isOpen) await box.close();
    }
    await directory.delete(recursive: true);
  });

  test('acknowledged independent Guided and Free projects reopen', () async {
    final guided = project(
      'apple-guided-1',
      ColoringMode.guided,
    ).fill('apple-body', RgbColor.fromHex('#D94B45'), guided: true);
    final free = project(
      'apple-free-1',
      ColoringMode.free,
    ).fill('apple-body', RgbColor.fromHex('#123456'));
    await repository.save(guided);
    await repository.save(free);
    await repository.close();
    repository = await HiveColoringProjectRepository.open(
      directory: directory.path,
      boxName: 'coloring',
    );

    final records = (await repository.loadSnapshot()).records;
    expect(records.map((item) => item.id).toSet(), {
      'apple-guided-1',
      'apple-free-1',
    });
    expect(
      records
          .firstWhere((item) => item.mode == ColoringMode.guided)
          .assignments['apple-body']
          ?.hex,
      '#D94B45',
    );
    expect(
      records
          .firstWhere((item) => item.mode == ColoringMode.free)
          .assignments['apple-body']
          ?.hex,
      '#123456',
    );
  });

  test('one corrupt row is isolated beside a healthy project', () async {
    final healthy = project('healthy-free-1', ColoringMode.free);
    await repository.save(healthy);
    await box.put('broken-free-1', {'version': 99, 'private': 'untouched'});
    await box.flush();

    final snapshot = await repository.loadSnapshot();
    expect(snapshot.records.single.id, healthy.id);
    expect(snapshot.corruptRecords.single.storageKey, 'broken-free-1');
    expect(box.get('broken-free-1'), {'version': 99, 'private': 'untouched'});
  });

  test(
    'local-data preview counts projects and erases all generations',
    () async {
      final guided = project('apple-guided-1', ColoringMode.guided);
      await repository.save(guided);
      await repository.save(
        guided.fill('apple-body', RgbColor.fromHex('#D94B45'), guided: true),
      );
      await repository.save(project('apple-free-1', ColoringMode.free));
      final manager = ExactLocalDataManager(
        owners: {LocalDataCategory.coloringProjects: () async => repository},
      );
      const selected = {LocalDataCategory.coloringProjects};

      final manifest = await repository.withMaintenance(
        (lease) => lease.inventory(),
      );
      expect(manifest.entries, hasLength(5));
      expect(manifest.recordCount, 2);
      final preview = await manager.preview(selected);
      expect(preview.recordCount, 2);
      expect(preview.estimatedBytes, greaterThan(0));

      await manager.delete(selected);
      expect(box.keys, isEmpty);
      final snapshot = await repository.loadSnapshot();
      expect(snapshot.records, isEmpty);
      expect(snapshot.corruptRecords, isEmpty);
      expect((await manager.preview(selected)).recordCount, 0);
    },
  );

  test(
    'local-data inventory accounts for corrupt and orphan projects',
    () async {
      await repository.save(project('healthy', ColoringMode.free));
      final broken = project('broken', ColoringMode.free);
      await repository.save(broken);
      await repository.save(broken);
      await box.putAll({
        '@slot:a:broken': {'version': 999},
        '@slot:b:broken': {'version': 999},
        '@commit:malformed': {'version': 999},
        '@slot:a:malformed': {'version': 999},
        '@slot:b:malformed': {'version': 999},
        '@slot:a:orphan': {'version': 999},
        '@slot:b:orphan': {'version': 999},
        'legacy': {'version': 999},
        42: 'unknown owned row',
        '@unknown': 'unknown internal row',
      });
      await box.flush();
      final manager = ExactLocalDataManager(
        owners: {LocalDataCategory.coloringProjects: () async => repository},
      );
      const selected = {LocalDataCategory.coloringProjects};

      final manifest = await repository.withMaintenance(
        (lease) => lease.inventory(),
      );
      expect(manifest.entries, hasLength(13));
      expect(manifest.recordCount, 7);
      expect((await manager.preview(selected)).recordCount, 7);
      await manager.delete(selected);
      expect(box.keys, isEmpty);
    },
  );

  test('slot-only changes invalidate local-data deletion preview', () async {
    final saved = project('apple-free-1', ColoringMode.free);
    await repository.save(saved);
    await repository.save(saved);
    final manager = ExactLocalDataManager(
      owners: {LocalDataCategory.coloringProjects: () async => repository},
    );
    const selected = {LocalDataCategory.coloringProjects};
    await manager.preview(selected);
    await box.put('@slot:a:apple-free-1', {'version': 999});
    await box.flush();

    await expectLater(
      manager.delete(selected),
      throwsA(isA<LocalDataException>()),
    );
    expect(box.keys, hasLength(3));
    expect((await repository.loadSnapshot()).records.single.id, saved.id);
  });

  test('last-valid backup recovers a damaged current row', () async {
    final initial = project('recover-free-1', ColoringMode.free);
    await repository.save(initial);
    final updated = initial.fill('apple-body', RgbColor.fromHex('#ABCDEF'));
    await repository.save(updated);
    await box.put('@slot:b:recover-free-1', {'version': 999});
    await box.flush();

    final recovered = await repository.read('recover-free-1');
    expect(recovered, isNotNull);
    expect(recovered!.assignments, isEmpty);
  });

  test(
    'failed promotion and rollback keep the acknowledged generation authoritative',
    () async {
      final initial = project('atomic-free-1', ColoringMode.free);
      await repository.save(initial);
      final updated = initial.fill('apple-body', RgbColor.fromHex('#123456'));
      final firstUpdateFlush = guardedBox.flushCalls + 1;
      guardedBox.failingFlushCalls.addAll({
        firstUpdateFlush + 1,
        firstUpdateFlush + 2,
      });

      await expectLater(repository.save(updated), throwsA(isA<Exception>()));
      expect((await repository.read(initial.id))!.assignments, isEmpty);
      await repository.close();
      repository = await HiveColoringProjectRepository.open(
        directory: directory.path,
        boxName: 'coloring',
      );
      expect((await repository.read(initial.id))!.assignments, isEmpty);
    },
  );
}
