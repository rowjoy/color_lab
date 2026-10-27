import 'dart:async';
import 'dart:io';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/files/file_room_project_repository.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';
import 'package:color_lab/features/room_studio/presentation/room_project_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/room_project_fixtures.dart';

void main() {
  test(
    'duplicate retries a creation-time CAS collision without adopting it',
    () async {
      final source = roomProjectFixture(revision: 1);
      final repo = _CreationCollisionRepository(source);
      final h = _Harness(repo);
      final copy = await h.actions.duplicate(_summary(source), name: 'Copy');
      expect(copy.projectId, 'new-3');
      expect(copy.photoId, 'new-4');
      expect(copy.revision, 1);
      expect((await repo.read('new-1'))!.snapshot.name, 'Concurrent creation');
      expect((await repo.read(source.projectId))!.snapshot, same(source));
    },
  );

  test('corrupt project Open leaves a healthy active editor usable', () async {
    final source = roomProjectFixture(revision: 1);
    final h = _Harness(_OneCorruptRepository(source));
    await h.actions.open(source.projectId);
    final before = h.container.read(roomMaskProvider);
    await expectLater(
      h.actions.open('bad'),
      _failure(RoomProjectActionFailure.unavailable),
    );
    expect(h.container.read(roomMaskProvider), same(before));
    expect(await h.actions.open(source.projectId), isTrue);
    expect(h.container.read(roomMaskProvider).canEdit, isTrue);
  });

  test(
    'duplicate never uses external changes hidden behind an active session',
    () async {
      final source = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(initial: [source]);
      final h = _Harness(repo);
      await h.actions.open(source.projectId);
      final updated = await repo.save(
        source.copyWith(name: 'External'),
        expectedRevision: 1,
      );
      await expectLater(
        h.actions.duplicate(_summary(updated), name: 'Copy'),
        _failure(RoomProjectActionFailure.conflict),
      );
      expect(h.session!.durable!.revision, 1);
      expect((await repo.listSnapshot()).records, hasLength(1));
    },
  );

  test(
    'rename keeps all identity, pixels, masks, variants and baseline',
    () async {
      final source = roomProjectFixture(revision: 1);
      final h = _Harness(InMemoryRoomProjectRepository(initial: [source]));
      final renamed = await h.actions.rename(_summary(source), '  Lounge  ');
      expect(renamed.name, 'Lounge');
      expect(renamed.revision, 2);
      expect(renamed.updatedAt, DateTime.utc(2026, 10, 28));
      expect(renamed.createdAt, source.createdAt);
      expect(renamed.projectId, source.projectId);
      expect(renamed.photoId, source.photoId);
      _sameAssetsAndVariants(renamed, source);
    },
  );

  test('stale summary rename conflicts and never silently rebases', () async {
    final source = roomProjectFixture(revision: 1);
    final repo = InMemoryRoomProjectRepository(initial: [source]);
    final h = _Harness(repo);
    await repo.save(
      source.copyWith(name: 'Another writer'),
      expectedRevision: 1,
    );
    await expectLater(
      h.actions.rename(_summary(source), 'Mine'),
      _failure(RoomProjectActionFailure.conflict),
    );
    expect(
      (await repo.read(source.projectId))!.snapshot.name,
      'Another writer',
    );
    expect((await repo.read(source.projectId))!.acknowledgedRevision, 2);
  });

  test('failed rename keeps source and exposes a safe failure', () async {
    final source = roomProjectFixture(revision: 1);
    final repo = InMemoryRoomProjectRepository(initial: [source])
      ..saveError = FileSystemException('private/path');
    final h = _Harness(repo);
    await expectLater(
      h.actions.rename(_summary(source), 'Mine'),
      _failure(RoomProjectActionFailure.storage),
    );
    expect((await repo.read(source.projectId))!.snapshot.name, source.name);
    expect(h.container.read(roomProjectActionsProvider), isFalse);
  });

  test(
    'active rename advances session token without losing visible history',
    () async {
      final source = roomProjectFixture(revision: 1);
      final h = _Harness(InMemoryRoomProjectRepository(initial: [source]));
      await h.actions.open(source.projectId);
      final visible = h.session!.visible;
      await h.actions.rename(_summary(source), 'Lounge');
      expect(h.session!.name, 'Lounge');
      expect(h.session!.durable!.revision, 2);
      expect(h.session!.visible, same(visible));
      h.editor.setLayerColor(RoomLayer.wall, RgbColor(5, 6, 7));
      await h.saved();
      expect(h.session!.durable!.revision, 3);
      expect(h.session!.durable!.name, 'Lounge');
    },
  );

  test(
    'active rename failure retains acknowledged state and recovery warning',
    () async {
      final source = roomProjectFixture(revision: 1);
      final repo = _RecoveredRepository(source);
      final h = _Harness(repo);
      await h.actions.open(source.projectId);
      final before = h.session!;
      repo.saveError = const RoomProjectConflict(
        expectedRevision: 3,
        actualRevision: 4,
      );
      await expectLater(
        h.actions.rename(
          _summary(source, acknowledged: 3, warning: repo.warning),
          'New',
        ),
        _failure(RoomProjectActionFailure.conflict),
      );
      expect(h.session!.name, before.name);
      expect(h.session!.durable, same(before.durable));
      expect(h.session!.visible, same(before.visible));
      expect(h.session!.recoveryWarning, same(before.recoveryWarning));
    },
  );

  test(
    'recovered rename uses acknowledged token and clears warning on repair',
    () async {
      final source = roomProjectFixture(revision: 1);
      final repo = _RecoveredRepository(source);
      final h = _Harness(repo);
      await h.actions.open(source.projectId);
      final saved = await h.actions.rename(
        _summary(source, acknowledged: 3, warning: repo.warning),
        'Repaired',
      );
      expect(repo.expected, 3);
      expect(saved.revision, 4);
      expect(h.session!.recoveryWarning, isNull);
      expect(h.session!.name, 'Repaired');
    },
  );

  test('rename and duplicate refuse any unsaved or saving session', () async {
    final source = roomProjectFixture(revision: 1);
    final other = source.copyWith(projectId: 'other', photoId: 'other-photo');
    final repo = InMemoryRoomProjectRepository(initial: [source, other]);
    final h = _Harness(repo);
    await h.actions.open(source.projectId);
    final gate = Completer<void>();
    repo.beforeSave = () => gate.future;
    h.editor.setLayerColor(RoomLayer.wall, RgbColor(3, 4, 5));
    for (final project in [source, other]) {
      await expectLater(
        h.actions.rename(_summary(project), 'New'),
        _failure(RoomProjectActionFailure.unsaved),
      );
      await expectLater(
        h.actions.duplicate(_summary(project), name: 'Copy'),
        _failure(RoomProjectActionFailure.unsaved),
      );
    }
    repo.saveError = const RoomProjectStorageException();
    gate.complete();
    await h.settled();
    await expectLater(
      h.actions.duplicate(_summary(source), name: 'Copy'),
      _failure(RoomProjectActionFailure.unsaved),
    );
    expect(h.session!.visible.colors.wall, RgbColor(3, 4, 5));
  });

  test(
    'Continue current unsaved project preserves exact visible draft',
    () async {
      final source = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(initial: [source]);
      final h = _Harness(repo);
      await h.actions.open(source.projectId);
      repo.saveError = const RoomProjectStorageException();
      h.editor.setLayerColor(RoomLayer.wall, RgbColor(3, 4, 5));
      await h.settled();
      final visible = h.session!.visible;
      expect(await h.actions.open(source.projectId), isTrue);
      expect(h.session!.visible, same(visible));
      expect(h.container.read(roomMaskProvider).draft, same(visible));
      expect(h.session!.saveStatus, RoomProjectSaveStatus.failed);
    },
  );

  test(
    'Open another project refuses unsaved changes without harming editor',
    () async {
      final source = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(
        initial: [
          source,
          source.copyWith(projectId: 'other'),
        ],
      );
      final h = _Harness(repo);
      await h.actions.open(source.projectId);
      repo.saveError = const RoomProjectStorageException();
      h.editor.setLayerColor(RoomLayer.wall, RgbColor(3, 4, 5));
      await h.settled();
      final before = h.container.read(roomMaskProvider);
      await expectLater(
        h.actions.open('other'),
        _failure(RoomProjectActionFailure.unsaved),
      );
      expect(h.container.read(roomMaskProvider), same(before));
      expect(h.session!.projectId, source.projectId);
    },
  );

  test(
    'duplicate owns new project and photo, revision one, and copied metadata',
    () async {
      final source = roomProjectFixture(revision: 7);
      final repo = InMemoryRoomProjectRepository(initial: [source]);
      final h = _Harness(repo);
      final duplicate = await h.actions.duplicate(
        _summary(source),
        name: 'Living room (copy)',
      );
      expect(duplicate.projectId, 'new-1');
      expect(duplicate.photoId, 'new-2');
      expect(duplicate.revision, 1);
      expect(duplicate.createdAt, DateTime.utc(2026, 10, 28));
      expect(duplicate.updatedAt, duplicate.createdAt);
      expect(duplicate.name, 'Living room (copy)');
      _sameAssetsAndVariants(duplicate, source);
      expect((await repo.read(source.projectId))!.snapshot, same(source));
    },
  );

  test(
    'duplicate bounds collisions and never overwrites existing records',
    () async {
      final source = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(
        initial: [
          source,
          source.copyWith(projectId: 'occupied'),
        ],
      );
      var calls = 0;
      final h = _Harness(
        repo,
        id: () => (++calls).isEven ? 'photo-new' : 'occupied',
      );
      await expectLater(
        h.actions.duplicate(_summary(source), name: 'Copy'),
        _failure(RoomProjectActionFailure.limit),
      );
      expect(calls, lessThanOrEqualTo(20));
      expect((await repo.listSnapshot()).records, hasLength(2));
      expect((await repo.read('occupied'))!.snapshot.revision, 1);
    },
  );

  test(
    'duplicate handles vanished, corrupt source and failed destination safely',
    () async {
      final source = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(initial: [source]);
      final h = _Harness(repo);
      repo.saveError = const RoomProjectStorageException();
      await expectLater(
        h.actions.duplicate(_summary(source), name: 'Copy'),
        _failure(RoomProjectActionFailure.storage),
      );
      expect((await repo.listSnapshot()).records, hasLength(1));
      await repo.delete(source.projectId);
      await expectLater(
        h.actions.duplicate(_summary(source), name: 'Copy'),
        _failure(RoomProjectActionFailure.unavailable),
      );
      final corrupt = _Harness(_CorruptRepository());
      await expectLater(
        corrupt.actions.duplicate(_summary(source), name: 'Copy'),
        _failure(RoomProjectActionFailure.unavailable),
      );
    },
  );

  test(
    'duplicate file assets have independent ownership and external export survives delete',
    () async {
      final directory = await Directory.systemTemp.createTemp('room-library-');
      addTearDown(() => directory.delete(recursive: true));
      final repo = await FileRoomProjectRepository.open(
        directory: directory.path,
      );
      addTearDown(repo.close);
      final source = await repo.save(roomProjectFixture(), expectedRevision: 0);
      final export = File('${directory.path}/shared-image.png');
      await export.writeAsBytes(source.photoPng);
      final h = _Harness(repo);
      final copy = await h.actions.duplicate(_summary(source), name: 'Copy');
      final sourceAssets = Directory(
        '${directory.path}/room_projects/projects/${source.projectId}/assets',
      );
      final copyAssets = Directory(
        '${directory.path}/room_projects/projects/${copy.projectId}/assets',
      );
      expect(await sourceAssets.exists(), isTrue);
      expect(await copyAssets.exists(), isTrue);
      final sourceFiles = await sourceAssets
          .list()
          .where((entity) => entity is File)
          .toList();
      for (final file in sourceFiles) {
        final name = file.path.split('/').last;
        expect(
          await FileSystemEntity.identical(
            file.path,
            '${copyAssets.path}/$name',
          ),
          isFalse,
        );
      }
      expect(
        await copyAssets.list().where((entity) => entity is Link).isEmpty,
        isTrue,
      );
      await h.actions.delete(source.projectId, confirmed: true);
      await repo.close();
      final fresh = await FileRoomProjectRepository.open(
        directory: directory.path,
      );
      addTearDown(fresh.close);
      expect(await fresh.read(source.projectId), isNull);
      _sameAssetsAndVariants(
        (await fresh.read(copy.projectId))!.snapshot,
        source,
      );
      final reopened = _Harness(fresh);
      expect(await reopened.actions.open(copy.projectId), isTrue);
      expect(reopened.session!.visible.masks.labels, [1, 2, 3, 4]);
      expect(
        reopened.session!.durable!.comparisonBaselineVariantId,
        'variant-b',
      );
      expect(await export.readAsBytes(), source.photoPng);
    },
  );

  test(
    'cancel deletion is a no-op, deleting another keeps session, active drains',
    () async {
      final source = roomProjectFixture(revision: 1);
      final other = source.copyWith(projectId: 'other');
      final repo = InMemoryRoomProjectRepository(initial: [source, other]);
      final h = _Harness(repo);
      await h.actions.open(source.projectId);
      final before = h.session;
      await h.actions.delete(source.projectId, confirmed: false);
      expect(h.session, same(before));
      expect((await repo.listSnapshot()).records, hasLength(2));
      await h.actions.delete(other.projectId, confirmed: true);
      expect(h.session, same(before));
      final accepted = Completer<void>();
      final gate = Completer<void>();
      repo.beforeSave = () {
        accepted.complete();
        return gate.future;
      };
      h.editor.setLayerColor(RoomLayer.wall, RgbColor(1, 2, 3));
      await accepted.future;
      var deleted = false;
      final deleting = h.actions
          .delete(source.projectId, confirmed: true)
          .then((_) => deleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(deleted, isFalse);
      expect(h.session, isNull);
      expect(h.container.read(roomMaskProvider).draft, isNull);
      gate.complete();
      await deleting;
      await Future<void>.delayed(Duration.zero);
      expect(await repo.read(source.projectId), isNull);
      expect((await repo.listSnapshot()).records, isEmpty);
    },
  );

  test(
    'busy action rejects double submission with one committed rename',
    () async {
      final source = roomProjectFixture(revision: 1);
      final accepted = Completer<void>();
      final gate = Completer<void>();
      final repo = InMemoryRoomProjectRepository(initial: [source])
        ..beforeSave = () {
          accepted.complete();
          return gate.future;
        };
      final h = _Harness(repo);
      final first = h.actions.rename(_summary(source), 'New');
      await accepted.future;
      expect(h.container.read(roomProjectActionsProvider), isTrue);
      await expectLater(
        h.actions.rename(_summary(source), 'Again'),
        _failure(RoomProjectActionFailure.busy),
      );
      gate.complete();
      await first;
      expect((await repo.read(source.projectId))!.snapshot.revision, 2);
    },
  );
}

Matcher _failure(RoomProjectActionFailure failure) => throwsA(
  isA<RoomProjectActionException>().having(
    (error) => error.failure,
    'safe failure',
    failure,
  ),
);

RoomProjectSummary _summary(
  RoomProjectSnapshot snapshot, {
  int? acknowledged,
  RoomProjectRecoveryWarning? warning,
}) => RoomProjectSummary.fromReadResult(
  RoomProjectReadResult(
    snapshot: snapshot,
    acknowledgedRevision: acknowledged ?? snapshot.revision,
    warning: warning,
  ),
);

void _sameAssetsAndVariants(
  RoomProjectSnapshot actual,
  RoomProjectSnapshot source,
) {
  expect(actual.width, source.width);
  expect(actual.height, source.height);
  expect(actual.photoPng, source.photoPng);
  expect(actual.thumbnailPng, source.thumbnailPng);
  expect(actual.aiMaskBytes, source.aiMaskBytes);
  expect(actual.maskBytes, source.maskBytes);
  expect(actual.maskRevision, source.maskRevision);
  expect(actual.colorRevision, source.colorRevision);
  expect(actual.activeVariantId, source.activeVariantId);
  expect(
    actual.comparisonBaselineVariantId,
    source.comparisonBaselineVariantId,
  );
  expect(
    actual.variants.map((v) => (v.id, v.name, v.colors)),
    source.variants.map((v) => (v.id, v.name, v.colors)),
  );
}

class _Harness {
  _Harness(RoomProjectRepository repository, {String Function()? id}) {
    var counter = 0;
    container = ProviderContainer(
      overrides: [
        roomProjectRepositoryProvider.overrideWith((ref) async => repository),
        roomProjectIdFactoryProvider.overrideWithValue(
          id ?? () => 'new-${++counter}',
        ),
        roomProjectActionClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 28),
        ),
      ],
    );
    addTearDown(container.dispose);
  }
  late final ProviderContainer container;
  RoomProjectActions get actions =>
      container.read(roomProjectActionsProvider.notifier);
  RoomMaskController get editor => container.read(roomMaskProvider.notifier);
  RoomProjectSession? get session => container.read(roomProjectSessionProvider);
  Future<void> settled() async {
    for (
      var i = 0;
      i < 200 && session?.saveStatus == RoomProjectSaveStatus.saving;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(session?.saveStatus, isNot(RoomProjectSaveStatus.saving));
  }

  Future<void> saved() async {
    await settled();
    expect(session!.saveStatus, RoomProjectSaveStatus.saved);
  }
}

class _RecoveredRepository extends InMemoryRoomProjectRepository {
  _RecoveredRepository(this.source) : super(initial: [source]);
  final RoomProjectSnapshot source;
  int? expected;
  final warning = RoomProjectRecoveryWarning(
    reason: RoomProjectRecoveryReason.earlierRevision,
    acknowledgedRevision: 3,
    recoveredRevision: 1,
    rejectedRevisions: [3, 2],
  );
  @override
  Future<RoomProjectReadResult?> read(String id) async => RoomProjectReadResult(
    snapshot: source,
    acknowledgedRevision: 3,
    warning: warning,
  );
  @override
  Future<RoomProjectSnapshot> save(
    RoomProjectSnapshot snapshot, {
    required int expectedRevision,
  }) async {
    expected = expectedRevision;
    if (saveError != null) throw saveError!;
    if (expectedRevision != 3) {
      throw RoomProjectConflict(
        expectedRevision: expectedRevision,
        actualRevision: 3,
      );
    }
    return snapshot.copyWith(revision: 4);
  }
}

class _CorruptRepository extends InMemoryRoomProjectRepository {
  @override
  Future<RoomProjectReadResult?> read(String id) async =>
      throw const RoomProjectStorageException(
        RoomProjectStorageFailure.corrupt,
      );
}

class _OneCorruptRepository extends InMemoryRoomProjectRepository {
  _OneCorruptRepository(RoomProjectSnapshot source) : super(initial: [source]);
  @override
  Future<RoomProjectReadResult?> read(String id) {
    if (id == 'bad') {
      return Future.error(
        const RoomProjectStorageException(RoomProjectStorageFailure.corrupt),
      );
    }
    return super.read(id);
  }
}

class _CreationCollisionRepository extends InMemoryRoomProjectRepository {
  _CreationCollisionRepository(RoomProjectSnapshot source)
    : super(initial: [source]);
  bool _collided = false;
  @override
  Future<RoomProjectSnapshot> save(
    RoomProjectSnapshot snapshot, {
    required int expectedRevision,
  }) async {
    if (!_collided) {
      _collided = true;
      await super.save(
        snapshot.copyWith(name: 'Concurrent creation'),
        expectedRevision: 0,
      );
    }
    return super.save(snapshot, expectedRevision: expectedRevision);
  }
}
