import 'dart:async';
import 'dart:io';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/db/hive_room_design_repository.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_draft_store.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/recoverable_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

// Only the flush boundary is injected; put/get/delete/close use actual Hive files.
class _Boundary implements Box<dynamic> {
  _Boundary(this.box);
  final Box<dynamic> box;
  bool fail = false;
  Completer<void>? gate;
  @override
  Iterable<dynamic> get keys => box.keys;
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      box.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) => box.put(key, value);
  @override
  Future<void> delete(dynamic key) => box.delete(key);
  @override
  Future<void> flush() async {
    if (gate case final g?) await g.future;
    if (fail) throw const FileSystemException('flush');
    await box.flush();
  }

  @override
  Future<void> close() => box.close();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory dir;
  late HiveRoomDesignRepository repo;
  late _Boundary boundary;
  late IllustratedRoomDraftStore store;
  final template = IllustratedRoomCatalog.study;
  final error = throwsA(isA<RoomDesignStorageException>());
  IllustratedRoomDraft draft() => IllustratedRoomDraft.grayscale(template)
      .setRegionColor('desk', RgbColor.fromHex('#123456'))
      .pinBaseline()
      .markSaved(id: 'study-saved', name: 'Saved desk')
      .setRegionColor('wall-side', RgbColor.fromHex('#654321'));
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('recoverable-rooms-');
    boundary = _Boundary(await Hive.openBox<dynamic>('drafts', path: dir.path));
    repo = HiveRoomDesignRepository.fromBox(box: boundary);
    store = IllustratedRoomDraftStore(repo);
    await store.load();
  });
  tearDown(() async {
    store.dispose();
    await repo.close();
    await dir.delete(recursive: true);
  });

  // Catches memory-only drafts, lost saved identity/baseline, cross-template replacement.
  test(
    'one draft per template survives close reopen with exact visible and pinned snapshots',
    () async {
      final first = draft();
      await store.retain(first);
      final latest = first.setRegionColor('chair', RgbColor.fromHex('#ABCDEF'));
      await store.retain(latest);
      await store.retain(
        IllustratedRoomDraft.grayscale(IllustratedRoomCatalog.living),
      );
      expect(store.statusFor('study'), IllustratedRoomDraftSaveStatus.saved);
      expect(await repo.load(), isEmpty);
      store.dispose();
      await repo.close();
      repo = await HiveRoomDesignRepository.open(
        directory: dir.path,
        boxName: 'drafts',
      );
      store = IllustratedRoomDraftStore(repo);
      await store.load();
      final resumed = store.draftFor(template)!;
      expect(resumed.assignments, latest.assignments);
      expect(resumed.pinnedBaseline, first.pinnedBaseline);
      expect(resumed.savedDesignId, 'study-saved');
      expect(resumed.savedName, 'Saved desk');
      expect(resumed.isDirty, isTrue);
      expect(
        resumed.discardChanges().assignments,
        first.discardChanges().assignments,
      );
      expect(
        store.draftFor(IllustratedRoomCatalog.living)!.assignments,
        isNull,
      );
      expect((await repo.loadDraftSnapshot()).records, hasLength(2));
    },
  );

  // Catches early success, implicit retry/cache promotion, failed visible draft loss.
  test(
    'failed barrier retains visible draft and previous durable revision until Retry',
    () async {
      final first = draft();
      await store.retain(first);
      final failed = first.setRegionColor('chair', RgbColor.fromHex('#ABCDEF'));
      boundary.fail = true;
      await expectLater(store.retain(failed), error);
      expect(store.statusFor('study'), IllustratedRoomDraftSaveStatus.failed);
      expect(store.draftFor(template), same(failed));
      expect(store.acknowledgedFor('study')!.visible!.regionOverrides, {
        'desk': '#123456',
        'wall-side': '#654321',
      });
      boundary.fail = false;
      await expectLater(repo.loadDraftSnapshot(), error);
      await store.retry('study');
      expect(store.statusFor('study'), IllustratedRoomDraftSaveStatus.saved);
      await repo.close();
      repo = await HiveRoomDesignRepository.open(
        directory: dir.path,
        boxName: 'drafts',
      );
      expect(
        (await repo.loadDraftSnapshot())
            .records
            .single
            .visible!
            .regionOverrides,
        {'desk': '#123456', 'wall-side': '#654321', 'chair': '#ABCDEF'},
      );
    },
  );

  // Catches close implicitly committing a failed draft instead of the last acknowledgement.
  test('closing after failed draft reopens last durable draft', () async {
    final first = draft();
    await store.retain(first);
    boundary.fail = true;
    await expectLater(store.retain(first.resetToGrayscale()), error);
    boundary.fail = false;
    await repo.close();
    repo = await HiveRoomDesignRepository.open(
      directory: dir.path,
      boxName: 'drafts',
    );
    final resumed = (await repo.loadDraftSnapshot()).records.single.restore(
      template,
    );
    expect(resumed.assignments, first.assignments);
  });

  // Catches stale completion publishing saved over a newer queued draft, disposed notifications.
  test(
    'queued saves publish only latest completion and disposal suppresses notifications',
    () async {
      boundary.gate = Completer<void>();
      final first = store.retain(draft());
      await Future<void>.delayed(Duration.zero);
      final newest = draft().resetToGrayscale();
      final second = store.retain(newest);
      expect(store.statusFor('study'), IllustratedRoomDraftSaveStatus.saving);
      expect(store.draftFor(template), same(newest));
      boundary.gate!.complete();
      await first;
      await second;
      expect(store.statusFor('study'), IllustratedRoomDraftSaveStatus.saved);
      expect(store.acknowledgedFor('study')!.visible, isNull);
      var notifications = 0;
      store.addListener(() => notifications++);
      boundary.gate = Completer<void>();
      final pending = store.retain(draft());
      await Future<void>.delayed(Duration.zero);
      final beforeDispose = notifications;
      store.dispose();
      boundary.gate!.complete();
      await pending;
      expect(notifications, beforeDispose);
    },
  );

  // Catches library/draft corruption mixing and implicit overwriting of quarantined bytes.
  test(
    'corrupt draft and unknown template are retained separately from healthy library',
    () async {
      final record = RecoverableRoomDraft.fromDraft(
        draft(),
        updatedAt: DateTime.utc(2026, 10, 28),
      );
      final unknown = {...record.toMap(), 'templateId': 'future-room'};
      await boundary.box.put('@draft:future-room', unknown);
      const corrupt = {'version': 99};
      await boundary.box.put('@draft:living', corrupt);
      await boundary.box.flush();
      await store.load();
      expect(store.corruptRecords.single.storageKey, '@draft:living');
      expect((await repo.loadSnapshot()).corruptRecords, isEmpty);
      await expectLater(
        store.retain(
          IllustratedRoomDraft.grayscale(IllustratedRoomCatalog.living),
        ),
        error,
      );
      expect(boundary.box.get('@draft:living'), corrupt);
      expect(
        (await repo.loadDraftSnapshot()).records.single.templateId,
        'future-room',
      );
      final invalid = {
        ...record.toMap(),
        'visible': {
          'groupColors': record.visible!.groupColors,
          'regionOverrides': {'unknown-region': '#123456'},
        },
      };
      final decoded = RecoverableRoomDraft.fromMap(invalid);
      expect(() => decoded.restore(template), throwsArgumentError);
      for (final patch in <Map<String, Object?>>[
        {'version': 3},
        {'extra': true},
        {'templateRevision': 0},
        {'savedDesignId': null},
        {'updatedAt': 'not-utc'},
        {
          'visible': {
            'groupColors': record.visible!.groupColors,
            'regionOverrides': {'desk': '#abcdef'},
          },
        },
      ]) {
        expect(
          () => RecoverableRoomDraft.fromMap({...record.toMap(), ...patch}),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'mixed legacy draft is isolated while a healthy template still restores',
    () async {
      final healthy = RecoverableRoomDraft.fromDraft(
        draft(),
        updatedAt: DateTime.utc(2026, 10, 28),
      );
      final livingDraft = IllustratedRoomDraft.grayscale(
        IllustratedRoomCatalog.living,
      ).setRegionColor('console', RgbColor.fromHex('#334455'));
      final living = RecoverableRoomDraft.fromDraft(
        livingDraft,
        updatedAt: DateTime.utc(2026, 10, 28),
      );
      final mixed = <String, Object?>{
        ...living.toMap(),
        'visible': <String, Object>{
          ...living.visible!.toMap(),
          'regionOverrides': <String, String>{
            'legacy-wall': '#112233',
            'console': '#334455',
          },
        },
      };
      await boundary.box.put('@draft:study', healthy.toMap());
      await boundary.box.put('@draft:living', mixed);
      await boundary.box.flush();

      await store.load();

      expect(store.draftFor(template)!.assignments, draft().assignments);
      expect(store.draftFor(IllustratedRoomCatalog.living), isNull);
      expect(store.recoveryUnavailableFor('living'), isTrue);
      expect(store.recoveryUnavailableFor('study'), isFalse);
      expect(boundary.box.get('@draft:living'), mixed);
    },
  );
}
