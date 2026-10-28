import 'dart:async';
import 'dart:io';
import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/db/hive_room_design_repository.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_draft_store.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/recoverable_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import '../../../support/in_memory_room_design_repository.dart';
import '../../../support/task5_room_fault_box.dart';

final _initial = RoomDesignSnapshot(
  groupColors: const {
    'walls': '#123456',
    'ceiling': '#ABCDEF',
    'floor': '#010203',
    'furniture': '#FFEEDD',
  },
);
final _updated = RoomDesignSnapshot(
  groupColors: const {
    'walls': '#222222',
    'ceiling': '#333333',
    'floor': '#444444',
    'furniture': '#555555',
  },
  regionOverrides: const {'desk': '#654321'},
);

RecoverableRoomDraft _futureRecord(String id) => RecoverableRoomDraft(
  templateId: 'study',
  templateRevision: 2,
  visible: RoomDesignSnapshot(
    groupColors: _initial.groupColors,
    regionOverrides: const {'future-region': '#102030'},
  ),
  activeBaseline: _updated,
  savedSnapshot: _initial,
  savedDesignId: id,
  savedName: 'A',
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  for (final failure in [false, true]) {
    // Mutation: Update after Rename changes only the saved row, rebuilds raw
    // future snapshots, or acknowledges one row before the shared flush succeeds.
    test(
      'Task5 round2: real Hive update reconciles raw identity atomically failure=$failure',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'task5-update-',
        );
        final box = Task5RoomFaultBox(
          await Hive.openBox<dynamic>('update-review', path: directory.path),
        );
        final repository = HiveRoomDesignRepository.fromBox(
          box: box,
          clock: () => DateTime.utc(2026, 10, 28),
        );
        try {
          final original = await repository.saveNew(
            name: 'A',
            templateId: 'study',
            snapshot: _initial,
          );
          final record = _futureRecord(original.id);
          await repository.saveDraft(record);
          final renamed = await repository.rename(original.id, 'B');
          box.failNextFlush = failure;
          final update = repository.update(
            original.id,
            name: 'C',
            snapshot: _updated,
            activeBaseline: _updated,
          );
          if (failure) {
            await expectLater(
              update,
              throwsA(isA<RoomDesignStorageException>()),
            );
            await repository.retry();
          } else {
            await update;
          }
          await repository.close();
          final fresh = await Hive.openBox<dynamic>(
            'update-review',
            path: directory.path,
            crashRecovery: false,
          );
          try {
            expect(fresh.get('@draft:study'), {
              ...record.toMap(),
              'savedName': failure ? 'B' : 'C',
            });
            expect(
              fresh.get(original.id),
              failure
                  ? renamed.toMap()
                  : {
                      ...renamed.toMap(),
                      'name': 'C',
                      ..._updated.toMap(),
                      'activeBaseline': _updated.toMap(),
                    },
            );
          } finally {
            await fresh.close();
          }
        } finally {
          await repository.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  // Mutation: UI fake omits the real repository's metadata reconciliation and
  // masks or fabricates future revision/unknown-override preservation behavior.
  test(
    'Task5 round2: in-memory update preserves raw snapshots and uses latest name',
    () async {
      final repository = InMemoryRoomDesignRepository();
      try {
        final saved = await repository.saveNew(
          name: 'A',
          templateId: 'study',
          snapshot: _initial,
        );
        final record = _futureRecord(saved.id);
        await repository.saveDraft(record);
        await repository.rename(saved.id, 'B');
        await repository.update(
          saved.id,
          name: 'C',
          snapshot: _updated,
          activeBaseline: _updated,
        );
        expect((await repository.loadDraftSnapshot()).records.single.toMap(), {
          ...record.toMap(),
          'savedName': 'C',
        });
        expect((await repository.load()).single.name, 'C');
      } finally {
        await repository.close();
      }
    },
  );

  // Mutation: Update fails to refresh the store's identity transform, allowing
  // a gated/replayed A or B capture to reinstate an old name after successful C.
  // Real Hive supplies the asynchronous mutation and flush boundaries.
  test(
    'Task5 round2: gated retains overlapping rename and update keep latest identity C',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'task5-gated-update-',
      );
      final box = Task5RoomFaultBox(
        await Hive.openBox<dynamic>('gated-update', path: directory.path),
      );
      final repository = HiveRoomDesignRepository.fromBox(box: box);
      final store = IllustratedRoomDraftStore(repository);
      final container = ProviderContainer(
        overrides: [
          roomDesignRepositoryProvider.overrideWith((ref) async => repository),
          illustratedRoomDraftStoreProvider.overrideWith((ref) async => store),
        ],
      );
      try {
        final original = await repository.saveNew(
          name: 'A',
          templateId: 'study',
          snapshot: _initial,
        );
        await store.load();
        await container.read(illustratedRoomDraftStoreProvider.future);
        await container.read(savedRoomDesignsProvider.future);
        final controller = container.read(illustratedRoomProvider.notifier);
        controller.openDesign(original);
        controller.setRegionColor('desk', RgbColor.fromHex('#111111'));
        final firstGate = Completer<void>();
        final firstStarted = Completer<void>();
        box.nextFlushGate = firstGate.future;
        box.nextFlushStarted = firstStarted;
        final retainingA = store.retain(
          container.read(illustratedRoomProvider).activeDraft!,
        );
        await firstStarted.future;
        final renaming = controller.renameDesign(original.id, 'B');
        firstGate.complete();
        await retainingA;
        await renaming;
        expect(store.acknowledgedFor('study')!.savedName, 'B');

        controller.setRegionColor('desk', RgbColor.fromHex('#654321'));
        controller.pinBaseline();
        final capturedB = container.read(illustratedRoomProvider).activeDraft!;
        final secondGate = Completer<void>();
        final secondStarted = Completer<void>();
        box.nextFlushGate = secondGate.future;
        box.nextFlushStarted = secondStarted;
        final retainingB = store.retain(capturedB);
        await secondStarted.future;
        final updating = controller.saveDesign('C');
        secondGate.complete();
        await retainingB;
        await updating;
        // Replaying a captured write must still use the latest permanent name C.
        await store.retain(capturedB);
        final session = container.read(illustratedRoomProvider).activeDraft!;
        expect(session.savedName, 'C');
        expect(session.savedDesignId, original.id);
        expect(
          session.assignments!.regionOverrides.map(
            (k, v) => MapEntry(k, v.hex),
          ),
          {'desk': '#654321'},
        );
        final library = (await repository.load()).single;
        expect(library.name, 'C');
        expect(library.snapshot.regionOverrides, {'desk': '#654321'});
        expect(store.acknowledgedFor('study')!.savedName, 'C');
        expect(store.acknowledgedFor('study')!.visible!.regionOverrides, {
          'desk': '#654321',
        });
        final durable = (await repository.loadDraftSnapshot()).records.single;
        expect(durable.savedName, 'C');
        expect(durable.activeBaseline!.regionOverrides, {'desk': '#654321'});
        await repository.close();
        final fresh = await HiveRoomDesignRepository.open(
          directory: directory.path,
          boxName: 'gated-update',
        );
        try {
          final restored = (await fresh.loadDraftSnapshot()).records.single
              .restore(IllustratedRoomCatalog.study);
          expect(restored.savedName, 'C');
          expect(restored.savedDesignId, original.id);
          expect(
            restored.assignments!.regionOverrides.map(
              (k, v) => MapEntry(k, v.hex),
            ),
            {'desk': '#654321'},
          );
          expect(restored.pinnedBaseline, session.pinnedBaseline);
          expect((await fresh.load()).single.name, 'C');
        } finally {
          await fresh.close();
        }
      } finally {
        container.dispose();
        store.dispose();
        await repository.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
