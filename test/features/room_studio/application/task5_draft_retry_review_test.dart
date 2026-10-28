import 'dart:io';
import 'dart:async';
import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/db/hive_room_design_repository.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_draft_store.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_editor_persistence.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/recoverable_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import '../../../support/task5_room_fault_box.dart';

void main() {
  // Mutation: initial-load Retry forgets the real failed-write barrier, or resets
  // the retained session and pending queue instead of preserving the latest edit.
  test(
    'Task5 review: initial draft load Retry clears a real repository barrier',
    () async {
      final directory = await Directory.systemTemp.createTemp('task5-load-');
      final box = Task5RoomFaultBox(
        await Hive.openBox<dynamic>('task5-load', path: directory.path),
      );
      final repository = HiveRoomDesignRepository.fromBox(box: box);
      final before = IllustratedRoomDraft.grayscale(
        IllustratedRoomCatalog.study,
      ).applyPalette('quiet-sage');
      await repository.saveDraft(
        RecoverableRoomDraft.fromDraft(
          before,
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      box.failNextFlush = true;
      await expectLater(
        repository.saveDraft(
          RecoverableRoomDraft.fromDraft(
            before.setRegionColor('desk', RgbColor.fromHex('#111111')),
            updatedAt: DateTime.utc(2026, 1, 2),
          ),
        ),
        throwsA(isA<RoomDesignStorageException>()),
      );
      final container = ProviderContainer(
        overrides: [
          roomDesignRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      try {
        container.read(illustratedRoomEditorPersistenceProvider);
        await expectLater(
          container.read(illustratedRoomDraftStoreProvider.future),
          throwsA(isA<RoomDesignStorageException>()),
        );
        final controller = container.read(illustratedRoomProvider.notifier);
        controller.setRegionColor('desk', RgbColor.fromHex('#123456'));
        controller.setRegionColor('desk', RgbColor.fromHex('#654321'));
        final latest = container.read(illustratedRoomProvider).activeDraft;
        await container.read(illustratedRoomDraftLoadRetryProvider)();
      final store = await container.read(illustratedRoomDraftStoreProvider.future);
      final saved = Completer<void>();
      void observe() {
        if (!saved.isCompleted &&
            store.statusFor('study') == IllustratedRoomDraftSaveStatus.saved &&
            store.acknowledgedFor('study')?.visible?.regionOverrides['desk'] == '#654321') {
          saved.complete();
        }
      }
      store.addListener(observe);
      observe();
      await saved.future;
      store.removeListener(observe);
        expect(
          container.read(illustratedRoomProvider).activeDraft,
          same(latest),
        );
        expect(
          (await repository.loadDraftSnapshot())
              .records
              .single
              .visible!
              .regionOverrides,
          {'desk': '#654321'},
        );
      } finally {
        container.dispose();
        await repository.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
