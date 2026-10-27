import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/files/file_room_project_repository.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/data/room_project_codec.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_undo.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../../support/in_memory_room_project_repository.dart';

PreparedPhoto _photo({int width = 3, int height = 2}) => PreparedPhoto(
  width: width,
  height: height,
  rgbaBytes: Uint8List.fromList([
    for (var i = 0; i < width * height; i++) ...[i % 256, 23, 81, 255],
  ]),
  // Deliberately not PNG. Persistence must encode prepared pixels, never trust
  // a picker preview's container or its metadata.
  previewBytes: Uint8List.fromList([1, 2, 3, 4]),
  palette: const [],
);

RoomMaskDraft _draft({int revision = 0, int colorRevision = 0}) =>
    RoomMaskDraft(
      photoId: 'photo-fixture',
      photo: _photo(),
      aiMasks: MaskBitmap(
        width: 3,
        height: 2,
        labels: Uint8List.fromList([1, 1, 0, 3, 4, 2]),
      ),
      masks: MaskBitmap(
        width: 3,
        height: 2,
        labels: Uint8List.fromList([revision == 0 ? 1 : 0, 1, 0, 3, 4, 2]),
      ),
      history: MaskUndoHistory(),
      maskRevision: revision,
      colorRevision: colorRevision,
      changedFromAiCount: revision == 0 ? 0 : 1,
      colors: colorRevision == 0
          ? const RoomLayerColors()
          : RoomLayerColors(wall: RgbColor(12, 34, colorRevision)),
    );

class _Repository extends InMemoryRoomProjectRepository {
  RoomProjectReadResult? recovered;
  Completer<void>? readGate;
  int reads = 0;
  final submitted = <RoomProjectSnapshot>[];
  final expected = <int>[];
  int active = 0, maxActive = 0;

  @override
  Future<RoomProjectReadResult?> read(String id) async {
    final result = recovered ?? await super.read(id);
    reads++;
    await readGate?.future;
    return result;
  }

  @override
  Future<RoomProjectSnapshot> save(
    RoomProjectSnapshot snapshot, {
    required int expectedRevision,
  }) async {
    submitted.add(snapshot);
    expected.add(expectedRevision);
    active++;
    if (active > maxActive) maxActive = active;
    try {
      return await super.save(snapshot, expectedRevision: expectedRevision);
    } finally {
      active--;
    }
  }
}

class _Harness {
  _Harness(RoomProjectRepository repository, {bool fixedIds = true}) {
    var id = 0;
    container = ProviderContainer(
      overrides: [
        roomProjectRepositoryProvider.overrideWith((ref) async => repository),
        if (fixedIds)
          roomProjectIdFactoryProvider.overrideWithValue(() => 'id-${id++}'),
      ],
    );
    addTearDown(container.dispose);
  }
  late final ProviderContainer container;
  RoomProjectSessionController get controller =>
      container.read(roomProjectSessionProvider.notifier);
  RoomProjectSession get session => container.read(roomProjectSessionProvider)!;
}

Future<void> _until(bool Function() check) async {
  for (var i = 0; i < 300 && !check(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(
    check(),
    isTrue,
    reason: 'Session did not reach the expected boundary',
  );
}

class _FailPointer extends RoomProjectFileIo {
  bool fail = false;
  @override
  Future<void> renameFile(String source, String destination) async {
    if (fail && destination.endsWith('/current')) {
      throw const FileSystemException('private path');
    }
    await super.renameFile(source, destination);
  }
}

void main() {
  test(
    'a completed edit during Open wins even if its save finishes before decoding',
    () async {
      final repo = _Repository();
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      repo.readGate = Completer<void>();
      final opening = h.controller.openProject(h.session.projectId);
      await _until(() => repo.reads == 1);
      await h.controller.commitVisibleDraft(_draft(revision: 1));
      repo.readGate!.complete();
      expect(await opening, isNull);
      expect(h.session.visible.maskRevision, 1);
      expect(h.session.durable!.maskRevision, 1);
    },
  );

  test(
    'recovered snapshot uses acknowledged ancestry token for its next save',
    () async {
      final repo = _Repository();
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      final earlier = h.session.durable!;
      await h.controller.commitVisibleDraft(_draft(revision: 1));
      await h.controller.closeProject();
      repo.recovered = RoomProjectReadResult(
        snapshot: earlier,
        acknowledgedRevision: 2,
        warning: RoomProjectRecoveryWarning(
          reason: RoomProjectRecoveryReason.earlierRevision,
          acknowledgedRevision: 2,
          recoveredRevision: 1,
          rejectedRevisions: [2],
        ),
      );
      await h.controller.openProject(earlier.projectId);
      expect(h.session.recoveryWarning!.recoveredRevision, 1);
      expect(h.session.visible.maskRevision, 0);
      await h.controller.commitVisibleDraft(
        _draft(revision: 1, colorRevision: 1),
      );
      expect(repo.expected, [0, 1, 2]);
      expect(h.session.durable!.revision, 3);
    },
  );

  test(
    'late failed old-project save cannot replace the new session or its status',
    () async {
      final repo = _Repository();
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      final oldId = h.session.projectId;
      final gate = Completer<void>();
      var first = true;
      repo.beforeSave = () async {
        if (first) {
          first = false;
          await gate.future;
          throw const RoomProjectStorageException();
        }
      };
      final oldSave = h.controller.commitVisibleDraft(_draft(revision: 1));
      await _until(() => repo.submitted.length == 2);
      final nextSave = h.controller.createFromAnalysis(_draft());
      final nextId = h.session.projectId;
      expect(nextId, isNot(oldId));
      expect(h.session.durable, isNull);
      expect(h.session.saveStatus, RoomProjectSaveStatus.saving);
      gate.complete();
      await Future.wait([oldSave, nextSave]);
      expect(h.session.projectId, nextId);
      expect(h.session.saveStatus, RoomProjectSaveStatus.saved);
      expect(h.session.saveError, isNull);
      expect(h.session.durable!.revision, 1);
      expect((await repo.read(oldId))!.snapshot.maskRevision, 0);
      expect(repo.maxActive, 1);
    },
  );

  test(
    'close before owner initialization prevents any late initial save',
    () async {
      final repo = _Repository();
      final owner = Completer<RoomProjectRepository>();
      var requested = false;
      final container = ProviderContainer(
        overrides: [
          roomProjectRepositoryProvider.overrideWith((ref) {
            requested = true;
            return owner.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(roomProjectSessionProvider.notifier);
      final creating = controller.createFromAnalysis(_draft());
      await _until(() => requested);
      final closing = controller.closeProject();
      owner.complete(repo);
      await Future.wait([creating, closing]);
      expect(repo.submitted, isEmpty);
      expect(container.read(roomProjectSessionProvider), isNull);
    },
  );

  test(
    'opening a missing project retains the usable current saved session',
    () async {
      final h = _Harness(_Repository());
      await h.controller.createFromAnalysis(_draft());
      final saved = h.session;
      expect(await h.controller.openProject('missing-project'), isNull);
      expect(h.session, same(saved));
      await h.controller.commitVisibleDraft(_draft(revision: 1));
      expect(h.session.durable!.maskRevision, 1);
    },
  );

  test(
    'stale or duplicate draft commits cannot regress visible state or create saves',
    () async {
      final repo = _Repository();
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      await h.controller.commitVisibleDraft(
        _draft(revision: 2, colorRevision: 2),
      );
      await h.controller.commitVisibleDraft(
        _draft(revision: 1, colorRevision: 1),
      );
      await h.controller.commitVisibleDraft(
        _draft(revision: 2, colorRevision: 2),
      );
      expect(h.session.visible.maskRevision, 2);
      expect(h.session.durable!.colorRevision, 2);
      expect(repo.submitted.length, 2);
    },
  );

  test('open refuses to silently discard an unsaved visible draft', () async {
    final repo = _Repository();
    final h = _Harness(repo);
    await h.controller.createFromAnalysis(_draft());
    repo.saveError = const RoomProjectStorageException();
    await h.controller.commitVisibleDraft(_draft(revision: 1));
    final failed = h.session;
    await expectLater(
      h.controller.openProject(failed.projectId),
      throwsA(isA<RoomProjectUnsavedChanges>()),
    );
    expect(h.session, same(failed));
    repo.saveError = null;
    await h.controller.retrySave();
    expect(h.session.durable!.maskRevision, 1);
  });

  test(
    'Retry reacquires an owner that failed to initialize without replacing a live owner',
    () async {
      final repo = _Repository();
      var opens = 0;
      final container = ProviderContainer(
        overrides: [
          roomProjectRepositoryProvider.overrideWith((ref) async {
            if (++opens == 1) throw const RoomProjectStorageException();
            return repo;
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(roomProjectSessionProvider.notifier);
      await controller.createFromAnalysis(_draft());
      expect(
        container.read(roomProjectSessionProvider)!.saveStatus,
        RoomProjectSaveStatus.failed,
      );
      await controller.retrySave();
      expect(
        container.read(roomProjectSessionProvider)!.saveStatus,
        RoomProjectSaveStatus.saved,
      );
      expect(opens, 2);
      repo.saveError = const RoomProjectStorageException();
      await controller.commitVisibleDraft(_draft(revision: 1));
      repo.saveError = null;
      await controller.retrySave();
      expect(opens, 2);
      expect(
        container.read(roomProjectSessionProvider)!.durable!.maskRevision,
        1,
      );
    },
  );

  test(
    'analysis saves aligned masks, clean pixels, thumbnail and reopens identity',
    () async {
      final directory = await Directory.systemTemp.createTemp('room-session-');
      addTearDown(() => directory.delete(recursive: true));
      final repo = await FileRoomProjectRepository.open(
        directory: directory.path,
      );
      final h = _Harness(repo);
      final original = _draft();
      final saving = h.controller.createFromAnalysis(original);
      expect(h.session.visible, same(original));
      expect(h.session.durable, isNull);
      expect(h.session.saveStatus, RoomProjectSaveStatus.saving);
      await saving;
      final saved = h.session.durable!;
      expect(saved.revision, 1);
      expect(saved.projectId, 'id-0');
      expect(saved.photoId, 'photo-fixture');
      expect(saved.name, 'My room');
      expect(saved.variants.single.name, 'Original colors');
      expect(saved.aiMaskBytes, [1, 1, 0, 3, 4, 2]);
      expect(saved.maskBytes, saved.aiMaskBytes);
      expect(
        img.decodePng(saved.photoPng)!.getBytes(order: img.ChannelOrder.rgba),
        original.photo.rgbaBytes,
      );
      expect(img.decodePng(saved.thumbnailPng!), isNotNull);
      expect(() => const RoomProjectCodec().encode(saved), returnsNormally);
      await h.controller.closeProject();
      await repo.close();
      final reopened = await FileRoomProjectRepository.open(
        directory: directory.path,
      );
      final fresh = _Harness(reopened);
      final draft = await fresh.controller.openProject(saved.projectId);
      expect(draft!.photoId, saved.photoId);
      expect(draft.photo.rgbaBytes, original.photo.rgbaBytes);
      expect(draft.photo.previewBytes, saved.photoPng);
      expect(draft.aiMasks.labels, saved.aiMaskBytes);
      expect(draft.masks.labels, saved.maskBytes);
      expect(draft.maskRevision, saved.maskRevision);
      expect(draft.colorRevision, saved.colorRevision);
      expect(draft.history.canUndo, isFalse);
      expect(fresh.session.saveStatus, RoomProjectSaveStatus.saved);
      await fresh.controller.closeProject();
      await reopened.close();
    },
  );

  test(
    'manual fallback keeps photo, exact zero masks and bounded thumbnail',
    () async {
      final h = _Harness(_Repository());
      final photo = _photo(width: 1200, height: 4);
      await h.controller.createManualFallback(
        RoomPhotoCandidate(photoId: 'manual-photo', photo: photo),
      );
      final visible = h.session.visible;
      expect(visible.photo, same(photo));
      expect(visible.manualMode, isTrue);
      expect(visible.aiMasks.width, 1200);
      expect(visible.masks.height, 4);
      expect(visible.aiMasks.labels, List.filled(4800, 0));
      expect(visible.masks.labels, List.filled(4800, 0));
      final saved = h.session.durable!;
      final thumbnail = img.decodePng(saved.thumbnailPng!)!;
      expect(thumbnail.width, lessThanOrEqualTo(256));
      expect(thumbnail.height, greaterThan(0));
      expect(() => const RoomProjectCodec().encode(saved), returnsNormally);
      await h.controller.openProject(saved.projectId);
      expect(h.session.visible.manualMode, isTrue);
      expect(h.session.visible.photo.rgbaBytes, photo.rgbaBytes);
    },
  );

  test(
    'visible edits advance immediately while FIFO saves acknowledge only their snapshots',
    () async {
      final repo = _Repository();
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      final a = h.controller.commitVisibleDraft(_draft(revision: 1));
      await _until(() => repo.submitted.length == 2);
      final b = h.controller.commitVisibleDraft(
        _draft(revision: 2, colorRevision: 1),
      );
      final c = h.controller.commitVisibleDraft(
        _draft(revision: 3, colorRevision: 2),
      );
      expect(h.session.visible.maskRevision, 3);
      expect(h.session.durable!.maskRevision, 0);
      expect(h.session.pendingSaveCount, 3);
      expect(h.session.saveStatus, RoomProjectSaveStatus.saving);
      expect(repo.submitted.length, 2);
      final observations = <(int, int, RoomProjectSaveStatus)>[];
      final listener = h.container.listen(roomProjectSessionProvider, (
        _,
        next,
      ) {
        if (next != null) {
          observations.add((
            next.visible.maskRevision,
            next.durable?.maskRevision ?? -1,
            next.saveStatus,
          ));
        }
      });
      gate.complete();
      await Future.wait([a, b, c]);
      expect(repo.maxActive, 1);
      expect(repo.expected, [0, 1, 2, 3]);
      expect(repo.submitted.map((s) => s.maskRevision), [0, 1, 2, 3]);
      expect(
        observations
            .where((s) => s.$2 < 3)
            .every((s) => s.$1 == 3 && s.$3 != RoomProjectSaveStatus.saved),
        isTrue,
      );
      expect(h.session.durable!.maskRevision, 3);
      expect(h.session.durable!.colorRevision, 2);
      expect(h.session.saveStatus, RoomProjectSaveStatus.saved);
      listener.close();
    },
  );

  test(
    'failed middle save stops queued work; Retry saves current editable draft',
    () async {
      final repo = _Repository();
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      repo.saveError = StateError('/private/photo.png disk full');
      final a = h.controller.commitVisibleDraft(_draft(revision: 1));
      await _until(() => repo.submitted.length == 2);
      final b = h.controller.commitVisibleDraft(_draft(revision: 2));
      gate.complete();
      await Future.wait([a, b]);
      expect(repo.submitted.length, 2);
      expect(h.session.saveStatus, RoomProjectSaveStatus.failed);
      expect(h.session.saveError, RoomProjectSaveError.storage);
      expect(h.session.durable!.revision, 1);
      expect(h.session.visible.maskRevision, 2);
      await h.controller.commitVisibleDraft(
        _draft(revision: 3, colorRevision: 3),
      );
      expect(h.session.visible.maskRevision, 3);
      expect(repo.submitted.length, 2);
      repo.saveError = null;
      repo.beforeSave = null;
      await h.controller.retrySave();
      expect(repo.submitted.length, 3);
      expect(repo.expected, [0, 1, 1]);
      expect(h.session.durable!.maskRevision, 3);
      expect(h.session.durable!.colors.wall, RgbColor(12, 34, 3));
      expect(h.session.saveError, isNull);
      expect(h.session.saveStatus, RoomProjectSaveStatus.saved);
    },
  );

  test(
    'stale CAS remains a visible conflict and Retry never silently rebases',
    () async {
      final repo = _Repository();
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      final old = h.session.durable!;
      await repo.save(old.copyWith(name: 'Elsewhere'), expectedRevision: 1);
      await h.controller.commitVisibleDraft(_draft(revision: 1));
      expect(h.session.saveStatus, RoomProjectSaveStatus.conflict);
      expect(h.session.saveError, RoomProjectSaveError.conflict);
      expect(h.session.durable, same(old));
      await h.controller.retrySave();
      expect(h.session.saveStatus, RoomProjectSaveStatus.conflict);
      expect(repo.expected, [0, 1, 1, 1]);
      expect((await repo.read(old.projectId))!.snapshot.name, 'Elsewhere');
    },
  );

  test(
    'close drains accepted save, discards queued work and prevents post-delete recreation',
    () async {
      final repo = _Repository();
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      final id = h.session.projectId;
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      final a = h.controller.commitVisibleDraft(_draft(revision: 1));
      await _until(() => repo.submitted.length == 2);
      final b = h.controller.commitVisibleDraft(_draft(revision: 2));
      var closed = false;
      final closing = h.controller.closeProject().then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      expect(h.container.read(roomProjectSessionProvider), isNull);
      gate.complete();
      await Future.wait([a, b, closing]);
      await repo.delete(id);
      await h.controller.commitVisibleDraft(_draft(revision: 3));
      await h.controller.retrySave();
      expect(repo.submitted.length, 2);
      expect(await repo.read(id), isNull);
    },
  );

  test(
    'provider disposal settles active work without submitting queued intent',
    () async {
      final repo = _Repository();
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      final a = h.controller.commitVisibleDraft(_draft(revision: 1));
      await _until(() => repo.submitted.length == 2);
      final b = h.controller.commitVisibleDraft(_draft(revision: 2));
      h.container.invalidate(roomProjectSessionProvider);
      expect(h.container.read(roomProjectSessionProvider), isNull);
      gate.complete();
      await Future.wait([a, b]);
      expect(repo.submitted.length, 2);
      expect(h.container.read(roomProjectSessionProvider), isNull);
    },
  );

  test(
    'filesystem reopen after pointer failure returns last acknowledged colors and masks',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'room-session-failure-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final io = _FailPointer();
      final repo = await FileRoomProjectRepository.open(
        directory: directory.path,
        io: io,
      );
      final h = _Harness(repo);
      await h.controller.createFromAnalysis(_draft());
      await h.controller.commitVisibleDraft(
        _draft(revision: 1, colorRevision: 2),
      );
      final acknowledged = h.session.durable!;
      io.fail = true;
      await h.controller.commitVisibleDraft(
        _draft(revision: 2, colorRevision: 3),
      );
      expect(h.session.saveStatus, RoomProjectSaveStatus.failed);
      expect(h.session.visible.maskRevision, 2);
      await h.controller.closeProject();
      await repo.close();
      final next = await FileRoomProjectRepository.open(
        directory: directory.path,
      );
      final fresh = _Harness(next);
      final draft = await fresh.controller.openProject(acknowledged.projectId);
      expect(draft!.maskRevision, 1);
      expect(draft.colorRevision, 2);
      expect(draft.colors.wall, RgbColor(12, 34, 2));
      expect(draft.masks.labels, [0, 1, 0, 3, 4, 2]);
      expect(draft.history.canUndo, isFalse);
      await fresh.controller.closeProject();
      await next.close();
    },
  );

  test(
    'production IDs survive independent provider lifetimes without reuse',
    () async {
      final repo = _Repository();
      final first = _Harness(repo, fixedIds: false);
      await first.controller.createFromAnalysis(_draft());
      final a = first.session.projectId;
      await first.controller.closeProject();
      final second = _Harness(repo, fixedIds: false);
      await second.controller.createFromAnalysis(_draft());
      expect(second.session.projectId, isNot(a));
      expect(RoomProjectLimits.validId(second.session.projectId), isTrue);
      expect((await repo.listSnapshot()).records.length, 2);
    },
  );
}
