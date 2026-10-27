import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/data/files/file_room_project_repository.dart';
import 'package:color_lab/data/storage/local_data_manager.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/room_project_fixtures.dart';

final class _FaultIo extends RoomProjectFileIo {
  bool failBeforePointer = false;
  bool failAfterPointer = false;
  bool failRevisionPublish = false;
  bool partialManifest = false;
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
