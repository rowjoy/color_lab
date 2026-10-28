import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/data/files/file_room_project_repository.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/domain/mask_edit_command.dart';
import 'package:color_lab/features/room_studio/domain/mask_edit_history.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_acquisition_intent_store.dart';
import '../../support/mask_edit_fixtures.dart';
import '../../support/room_project_fixtures.dart';

class _InterruptedIo extends RoomProjectFileIo {
  bool fail = false;
  @override
  Future<void> renameFile(String source, String destination) async {
    if (fail && destination.endsWith('/current')) throw const FileSystemException('interrupted');
    await super.renameFile(source, destination);
  }
}

void main() {
  test('manual recovery ignores an interrupted visible edit and corrupt newest history', () async {
    final root = await Directory.systemTemp.createTemp('manual-mask-recovery-'); final io = _InterruptedIo();
    var repository = await FileRoomProjectRepository.open(directory: root.path, io: io);
    addTearDown(() async { await repository.close(); await root.delete(recursive: true); });
    final first = await repository.save(maskHistoryProjectFixture(revision: 0), expectedRevision: 0);
    await repository.save(roomProjectFixture(projectId: 'healthy'), expectedRevision: 0);
    final edit = historyEdit(2, before: 3, after: 1, afterIntent: 2);
    final result = edit.applyForward(masks: MaskBitmap(width: 2, height: 2, labels: first.maskBytes), intent: first.intent);
    final visible = first.copyWith(maskBytes: result.masks.labels, intent: result.intent, history: first.history.push(edit));
    io.fail = true;
    await expectLater(repository.save(visible, expectedRevision: 1), throwsA(isA<RoomProjectStorageException>()));
    await repository.close(); io.fail = false;
    repository = await FileRoomProjectRepository.open(directory: root.path, io: io);
    expect((await repository.read(first.projectId))!.snapshot.intent.bytes, [5, 0, 0, 0]);
    final second = await repository.save(visible, expectedRevision: 1);
    final base = '${root.path}/room_projects/projects/${first.projectId}';
    final manifest = jsonDecode(await File('$base/revisions/${second.revision}/manifest.json').readAsString());
    await File('$base/${manifest['assets']['history']['path']}').delete();
    await repository.close(); repository = await FileRoomProjectRepository.open(directory: root.path, io: io);
    final recovered = (await repository.read(first.projectId))!;
    expect(recovered.snapshot.revision, 1); expect(recovered.acknowledgedRevision, 2);
    expect(recovered.snapshot.intent.bytes, [5, 0, 0, 0]);
    expect(recovered.snapshot.history.undoStack, hasLength(1)); expect(recovered.snapshot.history.redoStack, hasLength(1));
    expect((await repository.listSnapshot()).records, hasLength(2));
    expect((await repository.save(recovered.snapshot, expectedRevision: 2)).revision, 3);
  });

  test('manual recovery retains intent after history eviction fresh controller and model refresh', () async {
    final root = await Directory.systemTemp.createTemp('manual-mask-evicted-');
    final repository = await FileRoomProjectRepository.open(directory: root.path);
    final source = roomProjectFixture();
    var masks = MaskBitmap(width: 2, height: 2, labels: source.maskBytes);
    var intent = source.intent; var history = MaskEditHistory.empty(width: 2, height: 2);
    for (var i = 0; i < 21; i++) {
      final after = i.isEven ? 1 : 2;
      final edit = MaskEditCommand(width: 2, height: 2, indices: Uint32List.fromList([0]),
        beforeLabels: Uint8List.fromList([masks.labels[0]]), afterLabels: Uint8List.fromList([after]),
        beforeIntent: Uint8List.fromList([intent.intentAt(0)]), afterIntent: Uint8List.fromList([after + 1]));
      final next = edit.applyForward(masks: masks, intent: intent); masks = next.masks; intent = next.intent; history = history.push(edit);
    }
    final saved = await repository.save(source.copyWith(maskBytes: masks.labels, intent: intent, history: history), expectedRevision: 0);
    final container = ProviderContainer(overrides: [
      roomProjectRepositoryProvider.overrideWith((ref) async => repository),
      acquisitionIntentStoreProvider.overrideWith((ref) async => InMemoryAcquisitionIntentStore()),
    ]);
    addTearDown(() async { await container.read(roomProjectSessionProvider.notifier).closeProject(); container.dispose(); await repository.close(); await root.delete(recursive: true); });
    final controller = container.read(roomMaskProvider.notifier);
    expect(await controller.openProject(saved.projectId), isTrue);
    expect(await controller.refreshAiMasks(MaskBitmap(width: 2, height: 2, labels: Uint8List.fromList([4, 4, 4, 4]))), isTrue);
    for (var i = 0; i < 300 && container.read(roomProjectSessionProvider)!.saveStatus != RoomProjectSaveStatus.saved; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(container.read(roomProjectSessionProvider)!.saveStatus, RoomProjectSaveStatus.saved);
    final draft = container.read(roomMaskProvider).draft!;
    expect(draft.intent.intentAt(0), 2); expect(draft.masks.labels[0], 1);
    expect(draft.masks.labels.sublist(1), [4, 4, 4]); expect(draft.history.undoStack, hasLength(20));
    final reopened = (await repository.read(saved.projectId))!.snapshot;
    expect(reopened.intent.bytes, draft.intent.bytes); expect(reopened.history.byteLength, 160);
  });
}
