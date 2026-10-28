import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/data/files/file_room_project_repository.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_edit_history.dart';
import 'package:color_lab/features/room_studio/domain/mask_stroke.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_acquisition_intent_store.dart';

class _Io extends RoomProjectFileIo {
  bool failPointer = false;
  final revisions = <int>[];
  @override
  Future<void> renameFile(String source, String destination) async {
    if (destination.endsWith('/current')) {
      if (failPointer) {
        throw const FileSystemException('injected pointer failure');
      }
      final pointer = jsonDecode(await File(source).readAsString());
      await super.renameFile(source, destination);
      revisions.add(pointer['ancestry'][0]['revision'] as int);
    } else {
      await super.renameFile(source, destination);
    }
  }
}

MaskBitmap _ai(int label) => MaskBitmap(
  width: 10,
  height: 10,
  labels: Uint8List(100)..fillRange(0, 100, label),
);
ProviderContainer _container(FileRoomProjectRepository repository) =>
    ProviderContainer(
      overrides: [
        roomProjectRepositoryProvider.overrideWith((ref) async => repository),
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
      ],
    );

Future<void> _status(
  ProviderContainer container,
  RoomProjectSaveStatus status,
) async {
  for (var i = 0; i < 500; i++) {
    if (container.read(roomProjectSessionProvider)?.saveStatus == status) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Save did not reach $status');
}

Future<bool> _paint(ProviderContainer container, RoomLayer layer, int index) {
  final controller = container.read(roomMaskProvider.notifier);
  controller.setLayer(layer);
  controller.setTool(RoomMaskTool.add);
  final draft = container.read(roomMaskProvider).draft!;
  return controller.applyStroke(
    photoId: draft.photoId,
    maskRevision: draft.maskRevision,
    stroke: MaskStroke(
      layer: layer,
      mode: MaskEditMode.add,
      segments: [
        [MaskPoint(((index % 10) + .5) / 10, ((index ~/ 10) + .5) / 10)],
      ],
    ),
  );
}

void main() {
  test(
    'real disk preserves exact intent both stacks retry and last acknowledgment across fresh controllers',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'manual-mask-durable-',
      );
      final io = _Io();
      var repository = await FileRoomProjectRepository.open(
        directory: root.path,
        io: io,
      );
      var container = _container(repository);
      addTearDown(() async {
        await container
            .read(roomProjectSessionProvider.notifier)
            .closeProject();
        container.dispose();
        await repository.close();
        await root.delete(recursive: true);
      });
      await container
          .read(roomProjectSessionProvider.notifier)
          .createFromAnalysis(
            RoomMaskDraft(
              photoId: 'photo',
              photo: PreparedPhoto(
                width: 10,
                height: 10,
                rgbaBytes: Uint8List(400),
                previewBytes: Uint8List(0),
                palette: const [],
              ),
              aiMasks: _ai(1),
              masks: _ai(1),
              history: MaskEditHistory.empty(width: 10, height: 10),
              maskRevision: 0,
              changedFromAiCount: 0,
            ),
          );
      var controller = container.read(roomMaskProvider.notifier);
      final project = container.read(roomProjectSessionProvider)!.projectId;
      expect(controller.continueProject(project), isTrue);
      expect(await _paint(container, RoomLayer.wall, 55), isTrue);
      expect(container.read(roomMaskProvider).draft!.intent.intentAt(55), 2);
      expect(container.read(roomMaskProvider).draft!.changedFromAiCount, 0);
      expect(await _paint(container, RoomLayer.floor, 11), isTrue);
      var draft = container.read(roomMaskProvider).draft!;
      expect(
        await controller.undo(
          photoId: draft.photoId,
          maskRevision: draft.maskRevision,
        ),
        isTrue,
      );
      await _status(container, RoomProjectSaveStatus.saved);
      expect(io.revisions, [1, 2, 3, 4]);
      expect(await controller.refreshAiMasks(_ai(4)), isTrue);
      await _status(container, RoomProjectSaveStatus.saved);
      draft = container.read(roomMaskProvider).draft!;
      expect(draft.history.undoStack, hasLength(1));
      expect(draft.history.redoStack, hasLength(1));
      expect(draft.masks.labels[55], 1);
      expect(draft.masks.labels[11], 4);
      final masks = Uint8List.fromList(draft.masks.labels);
      final intent = Uint8List.fromList(draft.intent.bytes);
      await controller.closeProject();
      container.dispose();
      await repository.close();
      repository = await FileRoomProjectRepository.open(
        directory: root.path,
        io: io,
      );
      container = _container(repository);
      controller = container.read(roomMaskProvider.notifier);
      expect(await controller.openProject(project), isTrue);
      draft = container.read(roomMaskProvider).draft!;
      expect(draft.masks.labels, masks);
      expect(draft.intent.bytes, intent);
      expect(draft.history.undoStack.single.beforeLabels, [4]);
      expect(draft.history.undoStack.single.afterLabels, [1]);
      expect(draft.history.undoStack.single.beforeIntent, [0]);
      expect(draft.history.undoStack.single.afterIntent, [2]);
      expect(draft.history.redoStack.single.beforeLabels, [4]);
      expect(draft.history.redoStack.single.afterIntent, [4]);
      expect(io.revisions, [1, 2, 3, 4, 5]);
      expect(
        await controller.redo(
          photoId: draft.photoId,
          maskRevision: draft.maskRevision,
        ),
        isTrue,
      );
      await _status(container, RoomProjectSaveStatus.saved);
      draft = container.read(roomMaskProvider).draft!;
      expect(draft.masks.labels[11], 3);
      expect(draft.intent.intentAt(11), 4);
      expect(
        await controller.undo(
          photoId: draft.photoId,
          maskRevision: draft.maskRevision,
        ),
        isTrue,
      );
      await _status(container, RoomProjectSaveStatus.saved);
      expect(await _paint(container, RoomLayer.furniture, 88), isTrue);
      await _status(container, RoomProjectSaveStatus.saved);
      expect(
        container.read(roomMaskProvider).draft!.history.redoStack,
        isEmpty,
      );
      final durable = container.read(roomProjectSessionProvider)!.durable!;
      io.failPointer = true;
      expect(await _paint(container, RoomLayer.wall, 22), isTrue);
      await _status(container, RoomProjectSaveStatus.failed);
      expect(
        container.read(roomProjectSessionProvider)!.durable,
        same(durable),
      );
      expect(
        container.read(roomProjectSessionProvider)!.visible.intent.intentAt(22),
        2,
      );
      expect((await repository.read(project))!.snapshot.intent.intentAt(22), 0);
      io.failPointer = false;
      await container.read(roomProjectSessionProvider.notifier).retrySave();
      await _status(container, RoomProjectSaveStatus.saved);
      expect((await repository.read(project))!.snapshot.intent.intentAt(22), 2);
      final lastAck = (await repository.read(project))!.snapshot;
      io.failPointer = true;
      expect(await _paint(container, RoomLayer.ceiling, 33), isTrue);
      await _status(container, RoomProjectSaveStatus.failed);
      await controller.closeProject();
      container.dispose();
      await repository.close();
      io.failPointer = false;
      repository = await FileRoomProjectRepository.open(
        directory: root.path,
        io: io,
      );
      container = _container(repository);
      controller = container.read(roomMaskProvider.notifier);
      expect(await controller.openProject(project), isTrue);
      draft = container.read(roomMaskProvider).draft!;
      expect(draft.masks.labels, lastAck.maskBytes);
      expect(draft.intent.bytes, lastAck.intent.bytes);
      expect(draft.intent.intentAt(33), 0);
      expect(draft.history.undoStack.length, lastAck.history.undoStack.length);
      expect(io.revisions, List.generate(9, (i) => i + 1));
    },
  );
}
