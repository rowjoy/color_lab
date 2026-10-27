import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/data/files/file_room_project_repository.dart';
import 'package:color_lab/data/storage/local_data_manager.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';
import 'package:crypto/crypto.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/room_project_fixtures.dart';
import '../../support/frozen_room_project_fixtures.dart';
import '../../support/mask_edit_fixtures.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';

final class _FaultIo extends RoomProjectFileIo {
  bool failBeforePointer = false;
  bool failAfterPointer = false;
  bool failRevisionPublish = false;
  bool partialManifest = false;
  String? assetPublicationFailure;
  String? writeFailure;
  bool writeFailureInjected = false;
  String? failDelete;
  Completer<void>? pointerEntered;
  Completer<void>? releasePointer;

  @override
  Future<void> writeFlushed(String path, Uint8List bytes) async {
    if (partialManifest && path.endsWith('/manifest.json')) {
      await super.writeFlushed(
        path,
        Uint8List.fromList(bytes.take(7).toList()),
      );
      throw const FileSystemException('injected interrupted manifest');
    }
    final phase = writeFailure;
    final targeted =
        phase != null &&
        (phase.startsWith('asset-')
            ? path.contains('/.stage-') && path.endsWith('.mask')
            : path.contains('/.current-'));
    if (targeted) {
      final handle = await File(path).open(mode: FileMode.writeOnly);
      try {
        await handle.writeFrom(
          bytes,
          0,
          phase.endsWith('write') ? 1 : bytes.length,
        );
        if (phase.endsWith('flush')) await handle.flush();
        writeFailureInjected = true;
        throw FileSystemException('injected $phase acknowledgement failure');
      } finally {
        await handle.close();
      }
    }
    await super.writeFlushed(path, bytes);
  }

  @override
  Future<void> renameDirectory(String source, String destination) async {
    if (failRevisionPublish) {
      throw const FileSystemException('injected revision publish');
    }
    await super.renameDirectory(source, destination);
  }

  @override
  Future<void> renameFile(String source, String destination) async {
    if (destination.contains('/assets/') && assetPublicationFailure != null) {
      if (assetPublicationFailure == 'after') {
        await super.renameFile(source, destination);
      }
      throw const FileSystemException('injected asset publication');
    }
    if (destination.endsWith('/current')) {
      pointerEntered?.complete();
      await releasePointer?.future;
      if (failBeforePointer) {
        throw const FileSystemException('injected before pointer');
      }
      await super.renameFile(source, destination);
      if (failAfterPointer) {
        throw const FileSystemException('injected after pointer');
      }
      return;
    }
    await super.renameFile(source, destination);
  }

  @override
  Future<void> removeFile(String path) async {
    if (path == failDelete) throw const FileSystemException('injected delete');
    await super.removeFile(path);
  }
}

void main() {
  late Directory root;
  late _FaultIo io;
  late FileRoomProjectRepository repository;
  String projectPath([String id = 'project-1']) =>
      '${root.path}/room_projects/projects/$id';
  Future<FileRoomProjectRepository> open() =>
      FileRoomProjectRepository.open(directory: root.path, io: io);
  Future<void> reopen() async {
    await repository.close();
    repository = await open();
  }

  Future<RoomProjectSnapshot> saveFirst() =>
      repository.save(roomProjectFixture(), expectedRevision: 0);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('room-projects-');
    root = Directory(await root.resolveSymbolicLinks());
    io = _FaultIo();
    repository = await open();
  });
  tearDown(() async {
    await repository.close();
    await root.delete(recursive: true);
  });

  test(
    'frozen v1 disk reopen uses acknowledged ancestry and ignores newer orphan',
    () async {
      await repository.close();
      await copyFrozenRooms(root);
      repository = await open();
      final healthy = (await repository.read('v1-healthy'))!;
      expect(healthy.acknowledgedRevision, 3);
      expect(healthy.snapshot.maskBytes, [1, 2, 0, 4, 3, 1]);
      expect(healthy.snapshot.activeVariantId, 'b');
      expect(healthy.snapshot.comparisonBaselineVariantId, 'a');
      expect(
        (await repository.read('v1-manual'))!.snapshot.thumbnailPng,
        isNull,
      );
      final base = projectPath('v1-healthy');
      final pointer = await File('$base/current').readAsBytes();
      final newer = jsonDecode(
        await File('$base/revisions/3/manifest.json').readAsString(),
      );
      newer['revision'] = 4;
      newer['name'] = 'Unacknowledged orphan';
      await Directory('$base/revisions/4').create();
      await File(
        '$base/revisions/4/manifest.json',
      ).writeAsString(jsonEncode(newer));
      await File(
        '$base/revisions/3/manifest.json',
      ).writeAsString('corrupt-current');
      await reopen();
      final recovered = (await repository.read('v1-healthy'))!;
      expect(recovered.snapshot.revision, 2);
      expect(recovered.acknowledgedRevision, 3);
      expect(
        recovered.warning!.reason,
        RoomProjectRecoveryReason.earlierRevision,
      );
      expect(recovered.snapshot.name, 'Corner study');
      expect(await File('$base/current').readAsBytes(), pointer);
      expect(await Directory('$base/revisions/4').exists(), isFalse);
      expect((await repository.listSnapshot()).records, hasLength(2));
      await expectLater(
        repository.save(recovered.snapshot, expectedRevision: 2),
        throwsA(isA<RoomProjectConflict>()),
      );
      expect(
        (await repository.save(
          recovered.snapshot,
          expectedRevision: 3,
        )).revision,
        4,
      );
      await frozenRoomFiles(); // The immutable source fixture still matches every hash.
    },
  );

  test(
    'opening frozen v1 is read-only and next acknowledged save writes v2 reusing appearance assets',
    () async {
      await repository.close();
      await copyFrozenRooms(root);
      final frozen = await frozenRoomFiles();
      repository = await open();
      for (final id in ['v1-healthy', 'v1-manual']) {
        final before = (await repository.read(id))!;
        final base = projectPath(id);
        for (final entry in frozen.entries.where(
          (e) => e.key.startsWith('projects/$id/'),
        )) {
          expect(
            await File('${root.path}/room_projects/${entry.key}').readAsBytes(),
            entry.value,
          );
        }
        expect(before.snapshot.schemaVersion, 2);
        expect(before.snapshot.intent.bytes, [0, 0, 0, 0, 0, 0]);
        final priorAssets = {
          await for (final entity in Directory('$base/assets').list())
            entity.path: await File(entity.path).readAsBytes(),
        };
        final saved = await repository.save(
          before.snapshot,
          expectedRevision: before.acknowledgedRevision,
        );
        final manifest = jsonDecode(
          await File(
            '$base/revisions/${saved.revision}/manifest.json',
          ).readAsString(),
        );
        expect(manifest['schemaVersion'], 2);
        expect(manifest['assets']['intent']['length'], 6);
        expect(manifest['assets']['intent']['path'], endsWith('.intent.bin'));
        for (final entry in priorAssets.entries) {
          expect(await File(entry.key).readAsBytes(), entry.value);
        }
        expect(
          await Directory('$base/assets').list().length,
          priorAssets.length + 2,
        );
        expect(saved.revision, before.acknowledgedRevision + 1);
        expect(saved.projectId, before.snapshot.projectId);
        expect(saved.photoId, before.snapshot.photoId);
        expect(saved.createdAt, before.snapshot.createdAt);
        expect(saved.updatedAt, before.snapshot.updatedAt);
        expect(saved.photoPng, before.snapshot.photoPng);
        expect(saved.aiMaskBytes, before.snapshot.aiMaskBytes);
        expect(saved.maskBytes, before.snapshot.maskBytes);
        expect(saved.activeVariantId, before.snapshot.activeVariantId);
        expect(
          saved.comparisonBaselineVariantId,
          before.snapshot.comparisonBaselineVariantId,
        );
        expect(
          saved.variants.map(
            (v) => (
              v.id,
              v.name,
              v.colors.wall?.hex,
              v.colors.ceiling?.hex,
              v.colors.floor?.hex,
              v.colors.furniture?.hex,
            ),
          ),
          before.snapshot.variants.map(
            (v) => (
              v.id,
              v.name,
              v.colors.wall?.hex,
              v.colors.ceiling?.hex,
              v.colors.floor?.hex,
              v.colors.furniture?.hex,
            ),
          ),
        );
        await reopen();
        final reopened = (await repository.read(id))!.snapshot;
        expect(reopened.intent.bytes, [0, 0, 0, 0, 0, 0]);
        expect(reopened.maskBytes, before.snapshot.maskBytes);
      }
    },
  );

  test(
    'missing first v2 intent recovers frozen v1 and next save retains acknowledged CAS',
    () async {
      await repository.close();
      await copyFrozenRooms(root);
      repository = await open();
      final old = (await repository.read('v1-healthy'))!;
      await repository.save(old.snapshot, expectedRevision: 3);
      final base = projectPath('v1-healthy');
      final data = jsonDecode(
        await File('$base/revisions/4/manifest.json').readAsString(),
      );
      await File('$base/${data['assets']['intent']['path']}').delete();
      await reopen();
      final recovered = (await repository.read('v1-healthy'))!;
      expect(recovered.snapshot.revision, 3);
      expect(recovered.acknowledgedRevision, 4);
      expect(recovered.warning!.rejectedRevisions, [4]);
      expect(recovered.snapshot.intent.bytes, [0, 0, 0, 0, 0, 0]);
      await expectLater(
        repository.save(recovered.snapshot, expectedRevision: 3),
        throwsA(isA<RoomProjectConflict>()),
      );
      final saved = await repository.save(
        recovered.snapshot,
        expectedRevision: 4,
      );
      expect(saved.revision, 5);
      await reopen();
      expect((await repository.read('v1-healthy'))!.snapshot.revision, 5);
    },
  );

  for (final corruption in ['missing', 'hash', 'invalid-value']) {
    test(
      'corrupt v2 intent $corruption falls back through mixed acknowledged ancestry with CAS intact',
      () async {
        await repository.close();
        await copyFrozenRooms(root);
        repository = await open();
        final old = (await repository.read('v1-healthy'))!;
        final fourth = await repository.save(old.snapshot, expectedRevision: 3);
        final fifth = await repository.save(
          fourth.copyWith(
            name: 'Fifth',
            intent: MaskIntentBitmap.fromBytes(
              width: 3,
              height: 2,
              bytes: Uint8List.fromList([1, 2, 3, 4, 5, 0]),
            ),
          ),
          expectedRevision: 4,
        );
        final base = projectPath('v1-healthy');
        // A newer v2 orphan must never be promoted over acknowledged ancestry.
        io.failBeforePointer = true;
        await expectLater(
          repository.save(fifth.copyWith(name: 'Orphan'), expectedRevision: 5),
          throwsA(isA<RoomProjectStorageException>()),
        );
        io.failBeforePointer = false;
        final newest = File('$base/revisions/5/manifest.json');
        final data = jsonDecode(await newest.readAsString());
        expect(data['assets'].containsKey('intent'), isTrue);
        final intentPath = '$base/${data['assets']['intent']['path']}';
        if (corruption == 'missing') {
          await File(intentPath).delete();
        } else if (corruption == 'hash') {
          await File(intentPath).writeAsBytes([1, 0, 0, 0, 0, 0]);
        } else {
          final invalid = Uint8List.fromList([6, 0, 0, 0, 0, 0]);
          final hash = sha256.convert(invalid).toString();
          data['assets']['intent'] = {
            'path': 'assets/$hash.intent.bin',
            'length': 6,
            'sha256': hash,
          };
          await File('$base/assets/$hash.intent.bin').writeAsBytes(invalid);
          final encoded = utf8.encode(jsonEncode(data));
          await newest.writeAsBytes(encoded);
          final pointerFile = File('$base/current');
          final pointer = jsonDecode(await pointerFile.readAsString());
          pointer['ancestry'][0]['manifestSha256'] = sha256
              .convert(encoded)
              .toString();
          pointer.remove('checksum');
          pointer['checksum'] = sha256
              .convert(utf8.encode(jsonEncode(pointer)))
              .toString();
          await pointerFile.writeAsString(jsonEncode(pointer));
        }
        final pointerBefore = await File('$base/current').readAsBytes();
        await reopen();
        final recovered = (await repository.read('v1-healthy'))!;
        expect(recovered.snapshot.revision, 4);
        expect(recovered.acknowledgedRevision, 5);
        expect(recovered.warning!.rejectedRevisions, [5]);
        expect(recovered.snapshot.intent.bytes, [0, 0, 0, 0, 0, 0]);
        expect(recovered.snapshot.maskBytes, old.snapshot.maskBytes);
        expect(await File('$base/current').readAsBytes(), pointerBefore);
        expect(await Directory('$base/revisions/6').exists(), isFalse);
        expect(await File('$base/quarantine/revision-5.json').exists(), isTrue);
        final listed = await repository.listSnapshot();
        expect(
          listed.records.map((r) => r.projectId),
          containsAll(['v1-healthy', 'v1-manual']),
        );
        expect(listed.corruptRecords, isEmpty);
        await expectLater(
          repository.save(
            recovered.snapshot,
            expectedRevision: recovered.snapshot.revision,
          ),
          throwsA(isA<RoomProjectConflict>()),
        );
        final saved = await repository.save(
          recovered.snapshot,
          expectedRevision: 5,
        );
        expect(saved.revision, 6);
        expect(
          jsonDecode(
            await File('$base/revisions/6/manifest.json').readAsString(),
          )['schemaVersion'],
          2,
        );
        await reopen();
        expect((await repository.read('v1-healthy'))!.snapshot.revision, 6);
      },
    );
  }

  test(
    'cleanup collects only unreferenced intent assets and retains acknowledged intent',
    () async {
      await saveFirst();
      final base = projectPath();
      final manifest = jsonDecode(
        await File('$base/revisions/1/manifest.json').readAsString(),
      );
      expect(manifest['assets'].containsKey('intent'), isTrue);
      final keep = File('$base/${manifest['assets']['intent']['path']}');
      final orphan = Uint8List.fromList([5, 5, 5, 5]);
      final orphanFile = File(
        '$base/assets/${sha256.convert(orphan)}.intent.bin',
      );
      await orphanFile.writeAsBytes(orphan);
      await reopen();
      expect(await keep.readAsBytes(), [0, 0, 0, 0]);
      expect(await orphanFile.exists(), isFalse);
    },
  );

  test(
    'new acknowledged revisions own history assets and legacy v1 remains untouched',
    () async {
      await repository.close();
      await copyFrozenRooms(root);
      repository = await open();
      final before = (await repository.read('v1-healthy'))!;
      final dynamic snapshot = before.snapshot;
      expect(() => snapshot.history, returnsNormally);
      expect(snapshot.history.undoStack, isEmpty);
      final saved = await repository.save(before.snapshot, expectedRevision: 3);
      final manifest = jsonDecode(
        await File(
          '${projectPath('v1-healthy')}/revisions/${saved.revision}/manifest.json',
        ).readAsString(),
      );
      expect(manifest['assets'].containsKey('history'), isTrue);
      await reopen();
      final dynamic reopened = (await repository.read('v1-healthy'))!.snapshot;
      expect(reopened.history.redoStack, isEmpty);
      await frozenRoomFiles();
    },
  );

  test(
    'repository reopen preserves exact durable undo and redo stacks and collects unreferenced history',
    () async {
      final source = maskHistoryProjectFixture(revision: 0);
      final saved = await repository.save(source, expectedRevision: 0);
      await reopen();
      final reopened = (await repository.read('project-1'))!.snapshot;
      expect(reopened.history.byteLength, 16);
      final masks = MaskBitmap(width: 2, height: 2, labels: reopened.maskBytes);
      final undo = reopened.history.undo(masks: masks, intent: reopened.intent);
      expect(undo.result.masks.labels, [1, 2, 3, 4]);
      expect(undo.result.intent.bytes, [0, 0, 0, 0]);
      final second = await repository.save(
        reopened.copyWith(
          maskBytes: undo.result.masks.labels,
          intent: undo.result.intent,
          history: undo.history,
        ),
        expectedRevision: 1,
      );
      await reopen();
      final twice = (await repository.read('project-1'))!.snapshot;
      expect(twice.history.undoStack, isEmpty);
      expect(twice.history.redoStack, hasLength(2));
      final redo = twice.history.redo(
        masks: MaskBitmap(width: 2, height: 2, labels: twice.maskBytes),
        intent: twice.intent,
      );
      expect(redo.result.masks.labels, saved.maskBytes);
      expect(redo.result.intent.bytes, saved.intent.bytes);
      expect(second.createdAt, source.createdAt);
      expect(second.updatedAt, source.updatedAt);
      final fake = Uint8List.fromList([84, 65, 69, 72, 1]);
      final orphan = File(
        '${projectPath()}/assets/${sha256.convert(fake)}.history.bin',
      );
      await orphan.writeAsBytes(fake);
      await reopen();
      expect(await orphan.exists(), isFalse);
    },
  );

  for (final corruption in ['missing', 'trailing', 'oversized']) {
    test(
      'corrupt $corruption history quarantines only its revision and next save uses acknowledged CAS',
      () async {
        await saveFirst();
        final source = maskHistoryProjectFixture();
        await repository.save(source, expectedRevision: 1);
        io.failBeforePointer = true;
        await expectLater(
          repository.save(source.copyWith(name: 'Orphan'), expectedRevision: 2),
          throwsA(isA<RoomProjectStorageException>()),
        );
        io.failBeforePointer = false;
        final base = projectPath();
        final file = File('$base/revisions/2/manifest.json');
        final manifest =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final reference = manifest['assets']['history'];
        if (corruption == 'missing') {
          await File('$base/${reference['path']}').delete();
        } else {
          final old = await File('$base/${reference['path']}').readAsBytes();
          final bad = Uint8List.fromList(
            corruption == 'trailing' ? [...old, 0] : old,
          );
          if (corruption == 'oversized') {
            ByteData.sublistView(bad).setUint32(24, 16777224);
          }
          final hash = sha256.convert(bad).toString();
          final path = 'assets/$hash.history.bin';
          await File('$base/$path').writeAsBytes(bad);
          manifest['assets']['history'] = <String, dynamic>{
            'path': path,
            'length': bad.length,
            'sha256': hash,
          };
          final encoded = utf8.encode(jsonEncode(manifest));
          await file.writeAsBytes(encoded);
          final pointerFile = File('$base/current');
          final pointer = jsonDecode(await pointerFile.readAsString());
          pointer['ancestry'][0]['manifestSha256'] = sha256
              .convert(encoded)
              .toString();
          pointer.remove('checksum');
          pointer['checksum'] = sha256
              .convert(utf8.encode(jsonEncode(pointer)))
              .toString();
          await pointerFile.writeAsString(jsonEncode(pointer));
        }
        final before = await File('$base/current').readAsBytes();
        await reopen();
        final recovered = (await repository.read('project-1'))!;
        expect(recovered.snapshot.revision, 1);
        expect(recovered.acknowledgedRevision, 2);
        expect(recovered.warning!.rejectedRevisions, [2]);
        expect(recovered.snapshot.history.canUndo, isFalse);
        expect(recovered.snapshot.history.canRedo, isFalse);
        expect(await File('$base/current').readAsBytes(), before);
        expect(await Directory('$base/revisions/3').exists(), isFalse);
        expect(await File('$base/quarantine/revision-2.json').exists(), isTrue);
        expect((await repository.listSnapshot()).records, hasLength(1));
        await expectLater(
          repository.save(recovered.snapshot, expectedRevision: 1),
          throwsA(isA<RoomProjectConflict>()),
        );
        expect(
          (await repository.save(
            recovered.snapshot,
            expectedRevision: 2,
          )).revision,
          3,
        );
      },
    );
  }

  for (final phase in [
    'asset-write',
    'asset-flush',
    'asset-before',
    'asset-after',
    'pointer-write',
    'pointer-flush',
  ]) {
    test(
      '$phase failure preserves pointer/assets and fresh reopen retries',
      () async {
        final first = await saveFirst();
        final base = projectPath();
        final current = await File('$base/current').readAsBytes();
        final prior = <String, Uint8List>{
          await for (final entry in Directory('$base/assets').list())
            if (entry is File) entry.path: await entry.readAsBytes(),
        };
        final next = first.copyWith(
          maskBytes: Uint8List.fromList([0, 2, 3, 0]),
          maskRevision: 3,
        );
        io.writeFailure = phase.endsWith('write') || phase.endsWith('flush')
            ? phase
            : null;
        io.assetPublicationFailure = phase == 'asset-before'
            ? 'before'
            : phase == 'asset-after'
            ? 'after'
            : null;
        await expectLater(
          repository.save(next, expectedRevision: 1),
          throwsA(isA<RoomProjectStorageException>()),
        );
        io.writeFailure = null;
        if (phase.endsWith('write') || phase.endsWith('flush')) {
          expect(io.writeFailureInjected, isTrue);
        }
        expect(await File('$base/current').readAsBytes(), current);
        for (final entry in prior.entries) {
          expect(await File(entry.key).readAsBytes(), entry.value);
        }
        io.assetPublicationFailure = null;
        await reopen();
        expect(
          (await repository.read(first.projectId))!.snapshot.maskBytes,
          first.maskBytes,
        );
        final paths = (await Directory(
          base,
        ).list(recursive: true).toList()).map((e) => e.path);
        expect(
          paths.where(
            (p) =>
                p.contains('.stage-') ||
                p.contains('.current-') ||
                p.contains('/revisions/2'),
          ),
          isEmpty,
        );
        expect(await Directory('$base/assets').list().length, prior.length);
        expect((await repository.save(next, expectedRevision: 1)).revision, 2);
        await reopen();
        expect(
          (await repository.read(first.projectId))!.snapshot.maskBytes,
          next.maskBytes,
        );
      },
    );
  }

  test('first save commits revision 1 and reopens byte-identically', () async {
    final saved = await saveFirst();
    expect(saved.revision, 1);
    await reopen();
    final result = (await repository.read('project-1'))!;
    expect(result.acknowledgedRevision, 1);
    expect(result.warning, isNull);
    expect(result.snapshot.projectId, 'project-1');
    expect(result.snapshot.photoId, 'photo-1');
    expect(result.snapshot.photoPng, saved.photoPng);
    expect(result.snapshot.aiMaskBytes, saved.aiMaskBytes);
    expect(result.snapshot.maskBytes, saved.maskBytes);
    expect(result.snapshot.thumbnailPng, saved.thumbnailPng);
    expect(result.snapshot.maskRevision, 2);
    expect(result.snapshot.colorRevision, 3);
    expect(result.snapshot.comparisonBaselineVariantId, 'variant-b');
    final list = await repository.listSnapshot();
    expect(list.records.single.name, 'Living room');
    expect(list.records.single.revision, 1);
  });

  test(
    'an unrenderable photo cannot replace a healthy filesystem commit',
    () async {
      final first = await saveFirst();
      final current = File('${projectPath()}/current');
      final acknowledged = await current.readAsBytes();
      final invalid = roomProjectOnePixelFixture(
        photoPng: roomProjectPngWithMethods(compression: 1),
        revision: 1,
      );
      await expectLater(
        repository.save(invalid, expectedRevision: 1),
        throwsA(isA<RoomProjectStorageException>()),
      );
      expect(await current.readAsBytes(), acknowledged);
      await reopen();
      final result = (await repository.read('project-1'))!;
      expect(result.snapshot.revision, 1);
      expect(result.snapshot.photoPng, first.photoPng);
      expect(result.warning, isNull);
    },
  );

  for (final asset in ['photo', 'thumbnail']) {
    test(
      'reopen recovers an unsupported $asset PNG even with valid storage hashes',
      () async {
        final first = await repository.save(
          roomProjectOnePixelFixture(photoPng: roomProjectPngWithMethods()),
          expectedRevision: 0,
        );
        await repository.save(
          first.copyWith(name: 'Second'),
          expectedRevision: 1,
        );
        final malformed = roomProjectPngWithMethods(compression: 1);
        final assetHash = sha256.convert(malformed).toString();
        final assetPath = 'assets/$assetHash.png';
        await File(
          '${projectPath()}/$assetPath',
        ).writeAsBytes(malformed, flush: true);
        final manifestFile = File('${projectPath()}/revisions/2/manifest.json');
        final manifest =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, dynamic>;
        manifest['assets'][asset] = {
          'path': assetPath,
          'length': malformed.length,
          'sha256': assetHash,
        };
        final manifestBytes = utf8.encode(jsonEncode(manifest));
        await manifestFile.writeAsBytes(manifestBytes, flush: true);
        final pointerFile = File('${projectPath()}/current');
        final pointer =
            jsonDecode(await pointerFile.readAsString())
                as Map<String, dynamic>;
        pointer['ancestry'][0]['manifestSha256'] = sha256
            .convert(manifestBytes)
            .toString();
        pointer.remove('checksum');
        pointer['checksum'] = sha256
            .convert(utf8.encode(jsonEncode(pointer)))
            .toString();
        await pointerFile.writeAsString(jsonEncode(pointer), flush: true);

        await reopen();
        final result = (await repository.read('project-1'))!;
        expect(result.acknowledgedRevision, 2);
        if (asset == 'photo') {
          expect(result.snapshot.revision, 1);
          expect(result.snapshot.photoPng, first.photoPng);
          expect(
            result.warning!.reason,
            RoomProjectRecoveryReason.earlierRevision,
          );
        } else {
          expect(result.snapshot.revision, 2);
          expect(result.snapshot.thumbnailPng, isNull);
          expect(
            result.warning!.reason,
            RoomProjectRecoveryReason.thumbnailUnavailable,
          );
        }
        expect(
          (await repository.listSnapshot()).records.single.warning,
          isNotNull,
        );
        expect(
          await File('${projectPath()}/$assetPath').readAsBytes(),
          malformed,
        );
      },
    );
  }

  test(
    'first save and concurrent updates enforce typed compare-and-swap',
    () async {
      await expectLater(
        repository.save(roomProjectFixture(), expectedRevision: 1),
        throwsA(
          isA<RoomProjectConflict>().having(
            (e) => e.actualRevision,
            'actual',
            0,
          ),
        ),
      );
      final saved = await saveFirst();
      final first = repository.save(
        saved.copyWith(name: 'First'),
        expectedRevision: 1,
      );
      final stale = expectLater(
        repository.save(saved.copyWith(name: 'Stale'), expectedRevision: 1),
        throwsA(
          isA<RoomProjectConflict>().having(
            (e) => e.actualRevision,
            'actual',
            2,
          ),
        ),
      );
      expect((await first).revision, 2);
      await stale;
      expect((await repository.read('project-1'))!.snapshot.name, 'First');
    },
  );

  test('two open owners cannot race CAS against the same root', () async {
    final saved = await saveFirst();
    final second = await open();
    try {
      final first = repository.save(
        saved.copyWith(name: 'First'),
        expectedRevision: 1,
      );
      final conflict = expectLater(
        second.save(saved.copyWith(name: 'Second'), expectedRevision: 1),
        throwsA(isA<RoomProjectConflict>()),
      );
      await first;
      await conflict;
      expect((await second.read('project-1'))!.snapshot.name, 'First');
    } finally {
      await second.close();
    }
  });

  test(
    'metadata revisions reuse immutable photo/masks and preserve manifests',
    () async {
      final first = await saveFirst();
      final path = projectPath();
      final manifest = await File(
        '$path/revisions/1/manifest.json',
      ).readAsBytes();
      final originalAssets = await Directory('$path/assets').list().toList();
      await repository.save(
        first.copyWith(
          name: 'Renamed',
          activeVariantId: 'variant-b',
          comparisonBaselineVariantId: null,
        ),
        expectedRevision: 1,
      );
      await reopen();
      expect(
        await File('$path/revisions/1/manifest.json').readAsBytes(),
        manifest,
      );
      expect(
        await Directory('$path/assets').list().length,
        originalAssets.length,
      );
      final read = (await repository.read('project-1'))!.snapshot;
      expect(read.name, 'Renamed');
      expect(read.activeVariantId, 'variant-b');
      expect(read.comparisonBaselineVariantId, isNull);
      expect(read.photoPng, first.photoPng);
      expect(read.maskBytes, first.maskBytes);
    },
  );

  for (final failure in [
    'partialManifest',
    'revisionRename',
    'beforePointer',
  ]) {
    test(
      'interruption at $failure retains acknowledged state and cleans orphans',
      () async {
        final first = await saveFirst();
        io.partialManifest = failure == 'partialManifest';
        io.failRevisionPublish = failure == 'revisionRename';
        io.failBeforePointer = failure == 'beforePointer';
        await expectLater(
          repository.save(
            first.copyWith(name: 'Uncommitted'),
            expectedRevision: 1,
          ),
          throwsA(isA<RoomProjectStorageException>()),
        );
        io.partialManifest = false;
        io.failRevisionPublish = false;
        io.failBeforePointer = false;
        await reopen();
        expect(
          (await repository.read('project-1'))!.snapshot.name,
          'Living room',
        );
        final paths = (await Directory(
          projectPath(),
        ).list(recursive: true).toList()).map((e) => e.path);
        expect(
          paths.where(
            (p) =>
                p.contains('.stage-') ||
                p.contains('.current-') ||
                p.contains('/revisions/2'),
          ),
          isEmpty,
        );
        expect(
          (await repository.save(
            first.copyWith(name: 'Retried'),
            expectedRevision: 1,
          )).revision,
          2,
        );
      },
    );
  }

  test(
    'pointer replacement is the commit boundary even if the caller is interrupted',
    () async {
      final first = await saveFirst();
      io.failAfterPointer = true;
      await expectLater(
        repository.save(first.copyWith(name: 'Committed'), expectedRevision: 1),
        throwsA(isA<RoomProjectStorageException>()),
      );
      io.failAfterPointer = false;
      await reopen();
      final result = (await repository.read('project-1'))!;
      expect(result.snapshot.name, 'Committed');
      expect(result.snapshot.revision, 2);
      await expectLater(
        repository.save(first, expectedRevision: 1),
        throwsA(isA<RoomProjectConflict>()),
      );
    },
  );

  test(
    'an interrupted first save is never listed or recovered as committed',
    () async {
      io.failBeforePointer = true;
      await expectLater(
        saveFirst(),
        throwsA(isA<RoomProjectStorageException>()),
      );
      expect(await repository.read('project-1'), isNull);
      expect((await repository.listSnapshot()).records, isEmpty);
      io.failBeforePointer = false;
      await reopen();
      expect(await Directory('${projectPath()}/revisions/1').exists(), false);
      expect((await saveFirst()).revision, 1);
    },
  );

  test(
    'cleanup retains assets used only by an older acknowledged revision',
    () async {
      final first = await saveFirst();
      final second = await repository.save(
        first.copyWith(
          maskBytes: Uint8List.fromList([0, 0, 0, 0]),
          maskRevision: 3,
        ),
        expectedRevision: 1,
      );
      io.failBeforePointer = true;
      await expectLater(
        repository.save(
          second.copyWith(
            maskBytes: Uint8List.fromList([0, 1, 0, 1]),
            maskRevision: 4,
          ),
          expectedRevision: 2,
        ),
        throwsA(isA<RoomProjectStorageException>()),
      );
      io.failBeforePointer = false;
      await reopen();
      await File(
        '${projectPath()}/revisions/2/manifest.json',
      ).writeAsString('corrupt');
      final recovered = (await repository.read('project-1'))!;
      expect(recovered.snapshot.revision, 1);
      expect(recovered.snapshot.maskBytes, [1, 2, 3, 4]);
      expect(recovered.snapshot.photoPng, first.photoPng);
    },
  );

  test(
    'valid newer orphan is never a fallback for corrupt acknowledged data',
    () async {
      final first = await saveFirst();
      final second = await repository.save(
        first.copyWith(name: 'Second'),
        expectedRevision: 1,
      );
      io.failBeforePointer = true;
      await expectLater(
        repository.save(second.copyWith(name: 'Orphan'), expectedRevision: 2),
        throwsA(isA<RoomProjectStorageException>()),
      );
      io.failBeforePointer = false;
      await File(
        '${projectPath()}/revisions/2/manifest.json',
      ).writeAsString('corrupt-current');
      final result = (await repository.read('project-1'))!;
      expect(result.snapshot.revision, 1);
      expect(result.acknowledgedRevision, 2);
      expect(result.warning!.reason, RoomProjectRecoveryReason.earlierRevision);
      expect(result.warning!.rejectedRevisions, [2]);
      expect(
        (await repository.listSnapshot()).records.single.warning,
        isNotNull,
      );
      expect(
        await File('${projectPath()}/revisions/2/manifest.json').readAsString(),
        'corrupt-current',
      );
      expect(
        await Directory('${projectPath()}/quarantine').list().length,
        greaterThan(0),
      );
      await expectLater(
        repository.save(result.snapshot, expectedRevision: 1),
        throwsA(isA<RoomProjectConflict>()),
      );
      await reopen();
      expect((await repository.read('project-1'))!.snapshot.revision, 1);
      expect(await Directory('${projectPath()}/revisions/3').exists(), false);
      final recovered = await repository.save(
        result.snapshot.copyWith(name: 'Recovered'),
        expectedRevision: 2,
      );
      expect(recovered.revision, 3);
    },
  );

  test('a corrupt pointer cannot authorize directory-based recovery', () async {
    await saveFirst();
    final current = File('${projectPath()}/current');
    final original =
        jsonDecode(await current.readAsString()) as Map<String, dynamic>;
    original['checksum'] = '0' * 64;
    await current.writeAsString(jsonEncode(original));
    await expectLater(
      repository.read('project-1'),
      throwsA(isA<RoomProjectStorageException>()),
    );
    await reopen();
    final list = await repository.listSnapshot();
    expect(list.records, isEmpty);
    expect(list.corruptRecords, hasLength(1));
    expect(
      await File('${projectPath()}/revisions/1/manifest.json').exists(),
      true,
    );
  });

  test(
    'pointer schema must be an integer even if its normalized checksum matches',
    () async {
      await saveFirst();
      final file = File('${projectPath()}/current');
      final pointer =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      pointer['schemaVersion'] = 1.0;
      await file.writeAsString(jsonEncode(pointer));
      await expectLater(
        repository.read('project-1'),
        throwsA(isA<RoomProjectStorageException>()),
      );
    },
  );

  test(
    'one corrupt project does not hide healthy sorted library records',
    () async {
      await saveFirst();
      await repository.save(
        roomProjectFixture(projectId: 'project-2', name: 'Healthy'),
        expectedRevision: 0,
      );
      await repository.save(
        roomProjectFixture(projectId: 'project-0', name: 'Tie'),
        expectedRevision: 0,
      );
      await File(
        '${projectPath()}/revisions/1/manifest.json',
      ).writeAsString('{"schemaVersion":999}');
      final list = await repository.listSnapshot();
      expect(list.records.map((p) => p.projectId), ['project-0', 'project-2']);
      expect(list.corruptRecords.single.storageKey, 'project-1');
      expect(
        await File('${projectPath()}/revisions/1/manifest.json').readAsString(),
        '{"schemaVersion":999}',
      );
    },
  );

  test(
    'a corrupt thumbnail returns core data and a library fallback warning',
    () async {
      await saveFirst();
      final manifest = jsonDecode(
        await File('${projectPath()}/revisions/1/manifest.json').readAsString(),
      );
      await File(
        '${projectPath()}/${manifest['assets']['thumbnail']['path']}',
      ).writeAsBytes([0]);
      final result = (await repository.read('project-1'))!;
      expect(result.snapshot.revision, 1);
      expect(result.snapshot.maskBytes, [1, 2, 3, 4]);
      expect(result.snapshot.thumbnailPng, isNull);
      expect(
        result.warning!.reason,
        RoomProjectRecoveryReason.thumbnailUnavailable,
      );
      expect(
        (await repository.listSnapshot()).records.single.thumbnailPng,
        isNull,
      );
    },
  );

  test(
    'unsafe project IDs and symlinked assets cannot read or write exports',
    () async {
      await saveFirst();
      final outside = File('${root.path}/export.png');
      await outside.writeAsString('user export');
      for (final id in ['../x', '/tmp/x', r'x\y', '.', 'x/y']) {
        await expectLater(
          repository.read(id),
          throwsA(isA<RoomProjectStorageException>()),
        );
        await expectLater(
          repository.delete(id),
          throwsA(isA<RoomProjectStorageException>()),
        );
      }
      final manifest = jsonDecode(
        await File('${projectPath()}/revisions/1/manifest.json').readAsString(),
      );
      final photoPath =
          '${projectPath()}/${manifest['assets']['photo']['path']}';
      await File(photoPath).delete();
      await Link(photoPath).create(outside.path);
      await expectLater(
        repository.read('project-1'),
        throwsA(isA<RoomProjectStorageException>()),
      );
      await expectLater(
        repository.save(roomProjectFixture(), expectedRevision: 1),
        throwsA(isA<RoomProjectStorageException>()),
      );
      expect(await outside.readAsString(), 'user export');
    },
  );

  test(
    'symlinked project and repository directories fail without following',
    () async {
      final outside = await Directory('${root.path}/outside').create();
      final sentinel = await File('${outside.path}/keep').writeAsString('keep');
      await Link(projectPath('linked')).create(outside.path);
      await expectLater(
        repository.read('linked'),
        throwsA(isA<RoomProjectStorageException>()),
      );
      await expectLater(
        repository.delete('linked'),
        throwsA(isA<RoomProjectStorageException>()),
      );
      await repository.close();
      await Directory('${root.path}/room_projects').delete(recursive: true);
      await Link('${root.path}/room_projects').create(outside.path);
      await expectLater(open(), throwsA(isA<RoomProjectStorageException>()));
      expect(await sentinel.readAsString(), 'keep');
      await Link('${root.path}/room_projects').delete();
    },
  );

  test(
    'a redirected private parent cannot bypass owned-path symlink checks',
    () async {
      await saveFirst();
      final moved = Directory('${root.path}-moved');
      await root.rename(moved.path);
      await Link(root.path).create(moved.path);
      try {
        await expectLater(
          repository.read('project-1'),
          throwsA(isA<RoomProjectStorageException>()),
        );
        await expectLater(
          repository.save(roomProjectFixture(), expectedRevision: 1),
          throwsA(isA<RoomProjectStorageException>()),
        );
        await expectLater(
          repository.withMaintenance((lease) => lease.inventory()),
          throwsA(isA<RoomProjectStorageException>()),
        );
      } finally {
        await Link(root.path).delete();
        await moved.rename(root.path);
      }
      expect((await repository.read('project-1'))!.snapshot.revision, 1);
    },
  );

  test(
    'oversized manifest is rejected without hiding a healthy neighbor',
    () async {
      await saveFirst();
      await repository.save(
        roomProjectFixture(projectId: 'healthy'),
        expectedRevision: 0,
      );
      final handle = await File(
        '${projectPath()}/revisions/1/manifest.json',
      ).open(mode: FileMode.write);
      await handle.truncate(262145);
      await handle.close();
      expect(
        (await repository.listSnapshot()).records.single.projectId,
        'healthy',
      );
    },
  );

  test(
    'oversized assets and pointers are bounded before reading their bytes',
    () async {
      await saveFirst();
      final manifest = jsonDecode(
        await File('${projectPath()}/revisions/1/manifest.json').readAsString(),
      );
      final photo = await File(
        '${projectPath()}/${manifest['assets']['photo']['path']}',
      ).open(mode: FileMode.write);
      await photo.truncate(67108865);
      await photo.close();
      await expectLater(
        repository.read('project-1'),
        throwsA(isA<RoomProjectStorageException>()),
      );
      final pointer = await File(
        '${projectPath()}/current',
      ).open(mode: FileMode.write);
      await pointer.truncate(2097153);
      await pointer.close();
      await expectLater(
        repository.read('project-1'),
        throwsA(isA<RoomProjectStorageException>()),
      );
      expect(await Directory('${projectPath()}/revisions/1').exists(), true);
    },
  );

  test(
    'delete failure is retryable and deletion never touches other projects/exports',
    () async {
      await saveFirst();
      await repository.save(
        roomProjectFixture(projectId: 'other'),
        expectedRevision: 0,
      );
      final export = await File(
        '${root.path}/export.png',
      ).writeAsString('export');
      io.failDelete = '${projectPath()}/current';
      await expectLater(
        repository.delete('project-1'),
        throwsA(isA<RoomProjectStorageException>()),
      );
      io.failDelete = null;
      await repository.delete('project-1');
      expect(await repository.read('project-1'), isNull);
      expect(
        (await repository.listSnapshot()).records.single.projectId,
        'other',
      );
      expect(await export.readAsString(), 'export');
      await repository.delete('project-1');
    },
  );

  test('close drains accepted saves and rejects all later work', () async {
    io.pointerEntered = Completer<void>();
    io.releasePointer = Completer<void>();
    final saving = saveFirst();
    await io.pointerEntered!.future;
    var closed = false;
    final closing = repository.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, false);
    await expectLater(
      repository.listSnapshot(),
      throwsA(isA<RoomProjectStorageException>()),
    );
    await expectLater(
      repository.save(
        roomProjectFixture(projectId: 'late'),
        expectedRevision: 0,
      ),
      throwsA(isA<RoomProjectStorageException>()),
    );
    io.releasePointer!.complete();
    expect((await saving).revision, 1);
    await closing;
    io.pointerEntered = null;
    io.releasePointer = null;
    await reopen();
    expect(
      (await repository.listSnapshot()).records.single.projectId,
      'project-1',
    );
  });

  test(
    'delete waits for an accepted save before removing the project',
    () async {
      io.pointerEntered = Completer<void>();
      io.releasePointer = Completer<void>();
      final saving = saveFirst();
      await io.pointerEntered!.future;
      final deleting = repository.delete('project-1');
      io.releasePointer!.complete();
      await saving;
      await deleting;
      expect(await repository.read('project-1'), isNull);
      expect(await Directory(projectPath()).exists(), false);
    },
  );

  test('maintenance excludes saves and an escaped lease expires', () async {
    await saveFirst();
    final entered = Completer<void>();
    final release = Completer<void>();
    late LocalDataLease escaped;
    final maintenance = repository.withMaintenance((lease) async {
      escaped = lease;
      entered.complete();
      await release.future;
    });
    await entered.future;
    var saved = false;
    final saving = repository
        .save(roomProjectFixture(projectId: 'queued'), expectedRevision: 0)
        .then((_) => saved = true);
    await Future<void>.delayed(Duration.zero);
    expect(saved, false);
    release.complete();
    await maintenance;
    await saving;
    await expectLater(escaped.inventory(), throwsA(isA<LocalDataException>()));
  });

  test(
    'inventory includes artifacts and links, counts projects, and erases only owned data',
    () async {
      final first = await saveFirst();
      await repository.save(
        first.copyWith(name: 'Second'),
        expectedRevision: 1,
      );
      await Directory('${projectPath()}/revisions/.stage-stranded').create();
      await File(
        '${projectPath()}/revisions/.stage-stranded/partial',
      ).writeAsString('partial');
      await File(
        '${projectPath()}/quarantine-marker',
      ).writeAsString('evidence');
      final export = await File(
        '${root.path}/export.png',
      ).writeAsString('export');
      await Link('${projectPath()}/outside-link').create(export.path);
      final manager = ExactLocalDataManager(
        owners: {LocalDataCategory.roomProjects: () async => repository},
      );
      final preview = await manager.preview({LocalDataCategory.roomProjects});
      expect(preview.recordCount, 1);
      expect(preview.revisionCount, 2);
      expect(preview.estimatedBytes, greaterThan(100));
      final manifest = await repository.withMaintenance(
        (lease) => lease.inventory(),
      );
      expect(manifest.entries.keys, contains('projects/project-1/current'));
      expect(
        manifest.entries.keys,
        contains('projects/project-1/revisions/.stage-stranded/partial'),
      );
      expect(
        manifest.entries.keys,
        contains('projects/project-1/outside-link'),
      );
      await manager.delete({LocalDataCategory.roomProjects});
      expect((await repository.listSnapshot()).records, isEmpty);
      expect(await export.readAsString(), 'export');
      expect(
        (await repository.save(
          roomProjectFixture(),
          expectedRevision: 0,
        )).revision,
        1,
      );
    },
  );

  test(
    'artifact changes invalidate deletion and a partial erase needs a fresh preview',
    () async {
      await saveFirst();
      final manager = ExactLocalDataManager(
        owners: {LocalDataCategory.roomProjects: () async => repository},
      );
      const selected = {LocalDataCategory.roomProjects};
      await manager.preview(selected);
      await File('${projectPath()}/new-artifact').writeAsString('new');
      await expectLater(
        manager.delete(selected),
        throwsA(isA<LocalDataException>()),
      );
      expect((await repository.read('project-1'))!.snapshot.revision, 1);
      await manager.preview(selected);
      io.failDelete = '${projectPath()}/current';
      await expectLater(
        manager.delete(selected),
        throwsA(isA<LocalDataException>()),
      );
      io.failDelete = null;
      await expectLater(
        manager.delete(selected),
        throwsA(isA<LocalDataException>()),
      );
      await manager.preview(selected);
      await manager.delete(selected);
      expect((await repository.listSnapshot()).records, isEmpty);
    },
  );
}
