import 'dart:io';
import 'package:color_lab/data/db/hive_room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/recoverable_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import '../../support/task5_room_fault_box.dart';

void main() {
  for (final deletion in [false, true]) {
    for (final failure in [false, true]) {
      // Mutation: identity edits update only the saved row, materialize future
      // snapshots, discard dirty/pinned values, or acknowledge a partial flush.
      test(
        'Task5 review: ${deletion ? 'delete' : 'rename'} reconciles raw future drafts atomically, failure=$failure',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'task5-identity-',
          );
          final box = Task5RoomFaultBox(
            await Hive.openBox<dynamic>('task5', path: directory.path),
          );
          final repository = HiveRoomDesignRepository.fromBox(
            box: box,
            clock: () => DateTime.utc(2026, 10, 28),
          );
          final savedSnapshot = RoomDesignSnapshot(
            groupColors: const {
              'walls': '#123456',
              'ceiling': '#ABCDEF',
              'floor': '#010203',
              'furniture': '#FFEEDD',
            },
          );
          final saved = await repository.saveNew(
            name: 'Original',
            templateId: 'study',
            snapshot: savedSnapshot,
          );
          final dirtySnapshot = RoomDesignSnapshot(
            groupColors: savedSnapshot.groupColors,
            regionOverrides: const {'unknown-future-region': '#654321'},
          );
          final record = RecoverableRoomDraft(
            templateId: 'study',
            templateRevision: 2,
            visible: dirtySnapshot,
            activeBaseline: dirtySnapshot,
            savedSnapshot: savedSnapshot,
            savedDesignId: saved.id,
            savedName: 'Original',
            updatedAt: DateTime.utc(2026, 10, 27),
          );
          await repository.saveDraft(record);
          final before = record.toMap();
          box.failNextFlush = failure;
          try {
            final action = deletion
                ? repository.delete(saved.id)
                : repository.rename(saved.id, 'Renamed');
            if (failure) {
              await expectLater(
                action,
                throwsA(isA<RoomDesignStorageException>()),
              );
              await repository.retry();
            } else {
              await action;
            }
            await repository.close();
            final fresh = await Hive.openBox<dynamic>(
              'task5',
              path: directory.path,
              crashRecovery: false,
            );
            try {
              final expected = failure
                  ? before
                  : deletion
                  ? {
                      ...before,
                      'savedDesignId': null,
                      'savedName': null,
                      'savedSnapshot': null,
                    }
                  : {...before, 'savedName': 'Renamed'};
              expect(fresh.get('@draft:study'), expected);
              expect(
                fresh.get(saved.id),
                failure
                    ? saved.toMap()
                    : deletion
                    ? null
                    : {...saved.toMap(), 'name': 'Renamed'},
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
  }
}
