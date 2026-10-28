import 'dart:convert';
import 'dart:io';

import 'package:color_lab/data/db/hive_room_design_repository.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../../support/in_memory_room_design_repository.dart';

// Only operation boundaries can fail. All mutation/cache/file effects use Hive.
final class _FaultBox implements Box<dynamic> {
  _FaultBox(this.delegate);
  final Box<dynamic> delegate;
  void Function(String operation, dynamic key, dynamic value)? before;
  void Function(String operation, dynamic key, dynamic value)? after;
  @override
  Iterable<dynamic> get keys => delegate.keys;
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) async {
    before?.call('put', key, value);
    await delegate.put(key, value);
    after?.call('put', key, value);
  }

  @override
  Future<void> delete(dynamic key) async {
    before?.call('delete', key, null);
    await delegate.delete(key);
    after?.call('delete', key, null);
  }

  @override
  Future<void> flush() async {
    before?.call('flush', null, null);
    await delegate.flush();
    after?.call('flush', null, null);
  }

  @override
  Future<void> close() async {
    before?.call('close', null, null);
    await delegate.close();
    after?.call('close', null, null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  late _FaultBox box;
  late HiveRoomDesignRepository repository;
  final error = throwsA(isA<RoomDesignStorageException>());
  final now = DateTime.utc(2026, 10, 28);
  const corrupt = {'version': 99, 'evidence': 'untouched'};
  final snapshot = RoomDesignSnapshot(
    groupColors: {
      'walls': '#123456',
      'ceiling': '#ABCDEF',
      'floor': '#010203',
      'furniture': '#FFEEDD',
    },
    regionOverrides: {'desk': '#654321'},
  );
  final changed = RoomDesignSnapshot(
    groupColors: {
      'walls': '#222222',
      'ceiling': '#333333',
      'floor': '#444444',
      'furniture': '#555555',
    },
  );
  Never fail() => throw const FileSystemException('injected operation failure');
  Future<SavedRoomDesign> seed() => repository.saveNew(
    name: 'Original',
    templateId: 'study',
    templateRevision: 3,
    snapshot: snapshot,
    activeBaseline: snapshot,
  );
  Future<void> assertRaw(Map<Object, Object?> expected) async {
    await repository.close();
    final fresh = await Hive.openBox<dynamic>(
      'review',
      path: directory.path,
      crashRecovery: false,
    );
    try {
      expect({for (final key in fresh.keys) key: fresh.get(key)}, expected);
    } finally {
      await fresh.close();
    }
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('room-review-');
    box = _FaultBox(
      await Hive.openBox<dynamic>(
        'review',
        path: directory.path,
        crashRecovery: false,
      ),
    );
    await box.delegate.put('corrupt', corrupt);
    await box.delegate.flush();
    repository = HiveRoomDesignRepository.fromBox(box: box, clock: () => now);
  });
  tearDown(() async {
    box.before = null;
    box.after = null;
    // A terminal-close test intentionally leaves a failed owner handle.
    try {
      await repository.close();
    } on RoomDesignStorageException {
      await box.delegate.close();
    }
    await directory.delete(recursive: true);
  });

  // Catches the compatibility adapter rebuilding v2 with empty overrides/null pin.
  test(
    'review repository compatibility update preserves unseen v2 state on reopen',
    () async {
      final first = await seed();
      final unchanged = await repository.save(
        existingId: first.id,
        name: 'Unchanged',
        templateId: 'study',
        colors: first.colors,
      );
      expect(unchanged.snapshot.regionOverrides, {'desk': '#654321'});
      expect(unchanged.activeBaseline, snapshot);
      final updated = await repository.save(
        existingId: first.id,
        name: 'Changed groups',
        templateId: 'ignored-template',
        colors: changed.colors,
      );
      expect(updated.snapshot.groupColors, changed.groupColors);
      expect(updated.snapshot.regionOverrides, {'desk': '#654321'});
      expect(updated.activeBaseline, snapshot);
      expect(updated.templateRevision, 3);
      expect(updated.templateId, 'study');
      expect(updated.createdAt, first.createdAt);
      await assertRaw({'corrupt': corrupt, first.id: updated.toMap()});
    },
  );

  // Catches provider compatibility writes losing snapshots despite authoritative APIs.
  test(
    'review provider compatibility save preserves v2 data through real Hive reopen',
    () async {
      final first = await seed();
      final container = ProviderContainer(
        overrides: [
          roomDesignRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(savedRoomDesignsProvider.future);
      final updated = await container
          .read(savedRoomDesignsProvider.notifier)
          .saveDesign(
            existingId: first.id,
            name: 'Provider update',
            templateId: 'study',
            colors: changed.colors,
          );
      expect(
        container
            .read(savedRoomDesignsProvider)
            .requireValue
            .single
            .snapshot
            .regionOverrides,
        {'desk': '#654321'},
      );
      expect(updated.activeBaseline, snapshot);
      expect(updated.snapshot.groupColors, changed.groupColors);
      await assertRaw({'corrupt': corrupt, first.id: updated.toMap()});
    },
  );

  // Catches fake/production contract drift masking future provider regressions.
  test(
    'review in-memory compatibility boundary retains overrides and baseline',
    () async {
      final first = await seed();
      final memory = InMemoryRoomDesignRepository(
        designs: [first],
        clock: () => now,
      );
      final container = ProviderContainer(
        overrides: [
          roomDesignRepositoryProvider.overrideWith((ref) async => memory),
        ],
      );
      addTearDown(container.dispose);
      await container.read(savedRoomDesignsProvider.future);
      final updated = await container
          .read(savedRoomDesignsProvider.notifier)
          .saveDesign(
            existingId: first.id,
            name: 'Memory update',
            templateId: 'study',
            colors: changed.colors,
          );
      expect(updated.snapshot.regionOverrides, {'desk': '#654321'});
      expect(updated.activeBaseline, snapshot);
      expect(updated.snapshot.groupColors, changed.groupColors);
      expect(updated.templateRevision, 3);
    },
  );

  // Catches clearing _closing after Hive has closed itself before throwing.
  test(
    'review terminal box close cannot acknowledge Retry and requires fresh owner',
    () async {
      final first = await seed();
      box.after = (operation, key, value) {
        if (operation == 'close') fail();
      };
      await expectLater(repository.close(), error);
      expect(box.delegate.isOpen, isFalse);
      await expectLater(repository.retry(), error);
      await expectLater(repository.load(), error);
      await expectLater(repository.rename(first.id, 'Must fail'), error);
      box.after = null;
      repository = await HiveRoomDesignRepository.open(
        directory: directory.path,
        boxName: 'review',
        clock: () => now,
      );
      expect((await repository.loadSnapshot()).records, [first]);
      final renamed = await repository.rename(first.id, 'Fresh owner works');
      await assertRaw({'corrupt': corrupt, first.id: renamed.toMap()});
    },
  );

  // Catches mutation failure bypassing the barrier even before cache changes.
  test(
    'review failed put before mutation blocks later success until explicit recovery',
    () async {
      final first = await seed();
      var failPut = true;
      box.before = (operation, key, value) {
        if (operation == 'put' && failPut) {
          failPut = false;
          fail();
        }
      };
      await expectLater(
        repository.update(
          first.id,
          name: 'Failed',
          snapshot: changed,
          activeBaseline: null,
        ),
        error,
      );
      await expectLater(repository.load(), error);
      await expectLater(repository.delete(first.id), error);
      await repository.retry();
      expect(await repository.load(), [first]);
      await assertRaw({'corrupt': corrupt, first.id: first.toMap()});
    },
  );

  // Catches failed delete promotion and rollback-put loss; close must not bypass it.
  test(
    'review failed delete with failed rollback put remains blocked until all bytes restored',
    () async {
      final first = await seed();
      var rollback = false;
      var blockRollback = true;
      box.after = (operation, key, value) {
        if (operation == 'delete' && !rollback) {
          rollback = true;
          fail();
        }
      };
      box.before = (operation, key, value) {
        if (operation == 'put' && rollback && blockRollback) fail();
      };
      await expectLater(repository.delete(first.id), error);
      await expectLater(repository.retry(), error);
      await expectLater(repository.close(), error);
      expect(box.delegate.isOpen, isTrue);
      await expectLater(repository.load(), error);
      blockRollback = false;
      await repository.retry();
      expect(await repository.load(), [first]);
      await assertRaw({'corrupt': corrupt, first.id: first.toMap()});
    },
  );

  // Catches rollback-delete failure retaining a failed new ID as acknowledged.
  test(
    'review failed new put and rollback delete never promote unacknowledged row',
    () async {
      var rollback = false;
      var blockRollback = true;
      box.after = (operation, key, value) {
        if (operation == 'put' && !rollback) {
          rollback = true;
          fail();
        }
      };
      box.before = (operation, key, value) {
        if (operation == 'delete' && rollback && blockRollback) fail();
      };
      await expectLater(seed(), error);
      await expectLater(repository.retry(), error);
      await expectLater(repository.close(), error);
      await expectLater(repository.load(), error);
      blockRollback = false;
      await repository.retry();
      expect(await repository.load(), isEmpty);
      await assertRaw({'corrupt': corrupt});
    },
  );

  // Catches clearing a rollback barrier when its own flush still fails.
  test(
    'review pending rollback flush rejects Retry and close until durable',
    () async {
      final first = await seed();
      var blockFlush = true;
      box.before = (operation, key, value) {
        if (operation == 'flush' && blockFlush) fail();
      };
      await expectLater(
        repository.update(
          first.id,
          name: 'Failed',
          snapshot: changed,
          activeBaseline: null,
        ),
        error,
      );
      await expectLater(repository.retry(), error);
      await expectLater(repository.close(), error);
      expect(box.delegate.isOpen, isTrue);
      await expectLater(repository.rename(first.id, 'Blocked'), error);
      blockFlush = false;
      await repository.retry();
      expect(await repository.load(), [first]);
      await assertRaw({'corrupt': corrupt, first.id: first.toMap()});
    },
  );

  // Catches partial migration publication, incomplete multi-key rollback or evidence loss.
  test(
    'review partial six-row migration and rollback put failure restore every original',
    () async {
      final rows =
          (jsonDecode(
                    await File(
                      'test/fixtures/illustrated_rooms/v1.json',
                    ).readAsString(),
                  )
                  as List)
              .cast<Map>();
      for (final row in rows) {
        await box.delegate.put(row['id'], row);
      }
      await box.delegate.flush();
      var rollback = false;
      var blockRollback = true;
      box.after = (operation, key, value) {
        if (operation == 'put' &&
            key == 'dining-legacy' &&
            value is Map &&
            value['version'] == 2 &&
            !rollback) {
          rollback = true;
          fail();
        }
      };
      box.before = (operation, key, value) {
        if (operation == 'put' &&
            rollback &&
            blockRollback &&
            key == 'bedroom-legacy' &&
            value is Map &&
            value['version'] == 1) {
          fail();
        }
      };
      await expectLater(repository.loadSnapshot(), error);
      // First rollback row was restored; later rows still require the retained transaction.
      expect((box.delegate.get('bathroom-legacy') as Map)['version'], 1);
      expect((box.delegate.get('dining-legacy') as Map)['version'], 2);
      expect(box.delegate.get('corrupt'), corrupt);
      await expectLater(repository.retry(), error);
      await expectLater(repository.close(), error);
      await expectLater(
        repository.saveNew(
          name: 'Blocked',
          templateId: 'study',
          snapshot: snapshot,
        ),
        error,
      );
      blockRollback = false;
      await repository.retry();
      await assertRaw({
        'corrupt': corrupt,
        for (final row in rows) row['id'] as Object: row,
      });
      repository = await HiveRoomDesignRepository.open(
        directory: directory.path,
        boxName: 'review',
      );
      expect((await repository.loadSnapshot()).records, hasLength(6));
      await repository.close();
      final fresh = await Hive.openBox<dynamic>(
        'review',
        path: directory.path,
        crashRecovery: false,
      );
      try {
        for (final row in rows) {
          expect((fresh.get(row['id']) as Map)['version'], 2);
        }
        expect(fresh.get('corrupt'), corrupt);
      } finally {
        await fresh.close();
      }
    },
  );
}
