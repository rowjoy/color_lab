import 'dart:async';
import 'dart:io';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/files/file_room_project_repository.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/application/room_variant_controller.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/room_project_fixtures.dart';

class _Repository extends InMemoryRoomProjectRepository {
  _Repository() : super(initial: [roomProjectFixture(revision: 1)]);
  final writes = <RoomProjectSnapshot>[];
  final tokens = <int>[];
  @override
  Future<RoomProjectSnapshot> save(
    RoomProjectSnapshot snapshot, {
    required int expectedRevision,
  }) {
    writes.add(snapshot);
    tokens.add(expectedRevision);
    return super.save(snapshot, expectedRevision: expectedRevision);
  }
}

Future<ProviderContainer> open(
  RoomProjectRepository repo, {
  String Function()? ids,
}) async {
  var n = 0;
  final c = ProviderContainer(
    overrides: [
      roomProjectRepositoryProvider.overrideWith((ref) async => repo),
      roomProjectIdFactoryProvider.overrideWithValue(ids ?? () => 'new-${n++}'),
    ],
  );
  addTearDown(c.dispose);
  expect(
    await c.read(roomMaskProvider.notifier).openProject('project-1'),
    isTrue,
  );
  return c;
}

RoomProjectSession session(ProviderContainer c) =>
    c.read(roomProjectSessionProvider)!;
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'variant metadata queued during active project rename retains renamed project and CAS',
    () async {
      final repo = _Repository();
      final c = await open(repo);
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      final rename = c
          .read(roomProjectSessionProvider.notifier)
          .renameProject(
            'project-1',
            'Renamed room',
            expectedRevision: 1,
            updatedAt: DateTime.utc(2026, 10, 28),
          );
      final variant = c
          .read(roomVariantProvider.notifier)
          .createVariant('Evening');
      gate.complete();
      await rename;
      await variant;
      expect(repo.tokens, [1, 2]);
      expect(session(c).durable!.name, 'Renamed room');
      expect(session(c).durable!.variants.last.name, 'Evening');
      expect(session(c).activeVariantId, 'new-0');
    },
  );
  test(
    'ID factory retries collisions then selects the first safe unused ID',
    () async {
      final repo = _Repository();
      var call = 0;
      final c = await open(
        repo,
        ids: () => ['variant-a', '../bad', 'safe-new'][call++],
      );
      await c.read(roomVariantProvider.notifier).createVariant('Evening');
      expect(call, 3);
      expect(session(c).activeVariantId, 'safe-new');
      expect(repo.writes, hasLength(1));
    },
  );
  test(
    'every variant command captures exactly one FIFO metadata save',
    () async {
      final repo = _Repository();
      final c = await open(repo);
      final controller = c.read(roomVariantProvider.notifier);
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      final created = controller.createVariant('  Evening  ');
      final id = session(c).activeVariantId;
      final renamed = controller.renameVariant(id, 'Night');
      final pinned = controller.pinComparisonBaseline('variant-a');
      final selected = controller.selectVariant('variant-b');
      final cleared = controller.clearComparison();
      final deleted = controller.deleteVariant(id);
      expect(session(c).variants.map((v) => v.id), ['variant-a', 'variant-b']);
      expect(session(c).activeVariantId, 'variant-b');
      expect(session(c).durable!.activeVariantId, 'variant-a');
      await tick();
      expect(repo.writes, hasLength(1));
      gate.complete();
      await Future.wait([created, renamed, pinned, selected, cleared, deleted]);
      expect(repo.tokens, [1, 2, 3, 4, 5, 6]);
      expect(repo.writes[0].variants.last.name, 'Evening');
      expect(repo.writes[1].variants.last.name, 'Night');
      expect(repo.writes[2].comparisonBaselineVariantId, 'variant-a');
      expect(repo.writes[3].activeVariantId, 'variant-b');
      expect(repo.writes[4].comparisonBaselineVariantId, isNull);
      expect(session(c).durable!.revision, 7);
      expect(session(c).saveStatus, RoomProjectSaveStatus.saved);
      for (final write in repo.writes) {
        expect(write.photoPng, roomProjectFixture().photoPng);
        expect(write.aiMaskBytes, [1, 1, 0, 4]);
        expect(write.maskBytes, [1, 2, 3, 4]);
      }
    },
  );
  test(
    'older acknowledgement cannot overwrite latest visible metadata',
    () async {
      final repo = _Repository();
      final c = await open(repo);
      final gates = [Completer<void>(), Completer<void>()];
      var i = 0;
      repo.beforeSave = () => gates[i++].future;
      final controller = c.read(roomVariantProvider.notifier);
      final first = controller.selectVariant('variant-b');
      final second = controller.renameVariant('variant-b', 'Latest');
      await tick();
      gates.first.complete();
      await first;
      expect(session(c).variants.last.name, 'Latest');
      expect(session(c).durable!.variants.last.name, 'B');
      expect(session(c).saveStatus, RoomProjectSaveStatus.saving);
      gates.last.complete();
      await second;
    },
  );
  for (final conflict in [false, true]) {
    test(
      'failure retains latest variants; explicit Retry ${conflict ? 'does not rebase conflict' : 'saves latest'}',
      () async {
        final repo = _Repository();
        final c = await open(repo);
        if (conflict) {
          await repo.save(roomProjectFixture(revision: 1), expectedRevision: 1);
          repo.writes.clear();
          repo.tokens.clear();
        } else {
          repo.saveError = const RoomProjectStorageException();
        }
        final controller = c.read(roomVariantProvider.notifier);
        await controller.createVariant('Night');
        await controller.renameVariant(session(c).activeVariantId, 'Latest');
        await controller.pinComparisonBaseline('variant-a');
        expect(repo.writes, hasLength(1));
        expect(session(c).variants.last.name, 'Latest');
        expect(session(c).durable!.revision, 1);
        repo.saveError = null;
        await c.read(roomProjectSessionProvider.notifier).retrySave();
        expect(repo.tokens, [1, 1]);
        expect(
          session(c).saveStatus,
          conflict
              ? RoomProjectSaveStatus.conflict
              : RoomProjectSaveStatus.saved,
        );
        expect(session(c).variants.last.name, 'Latest');
        if (!conflict) {
          expect(session(c).durable!.comparisonBaselineVariantId, 'variant-a');
        }
      },
    );
  }
  test(
    'normal color edit changes only active variant with one revision; mask edit preserves all metadata',
    () async {
      final repo = _Repository();
      final c = await open(repo);
      final variants = c.read(roomVariantProvider.notifier);
      await variants.selectVariant('variant-b');
      final mask = c.read(roomMaskProvider.notifier);
      expect(mask.setLayerColor(RoomLayer.wall, RgbColor(12, 34, 56)), isTrue);
      await tick();
      await tick();
      expect(repo.writes, hasLength(2));
      expect(
        session(c).durable!.variants.first.colors.wall,
        RgbColor.fromHex('#ABCDEF'),
      );
      expect(
        session(c).durable!.variants.last.colors.wall,
        RgbColor(12, 34, 56),
      );
      expect(session(c).durable!.colorRevision, 5);
      final draft = c.read(roomMaskProvider).draft!;
      expect(
        mask.restoreAiMasks(
          photoId: draft.photoId,
          maskRevision: draft.maskRevision,
        ),
        isTrue,
      );
      await tick();
      await tick();
      expect(repo.writes, hasLength(3));
      expect(session(c).durable!.activeVariantId, 'variant-b');
      expect(session(c).durable!.comparisonBaselineVariantId, 'variant-b');
      expect(
        session(c).durable!.variants.last.colors.wall,
        RgbColor(12, 34, 56),
      );
      await variants.updateVariantColors(const RoomLayerColors());
      expect(repo.writes, hasLength(4));
      expect(c.read(roomMaskProvider).draft!.colors, const RoomLayerColors());
    },
  );
  test(
    'bounded ID collision handling and invalid commands cause no save',
    () async {
      final repo = _Repository();
      var calls = 0;
      final c = await open(
        repo,
        ids: () {
          calls++;
          return 'variant-a';
        },
      );
      final v = c.read(roomVariantProvider.notifier);
      await expectLater(
        v.createVariant('New'),
        throwsA(isA<RoomVariantException>()),
      );
      expect(calls, 5);
      await expectLater(
        v.selectVariant('missing'),
        throwsA(isA<RoomVariantException>()),
      );
      expect(repo.writes, isEmpty);
    },
  );
  test(
    'close discards queued variants and drains accepted save before deletion',
    () async {
      final repo = _Repository();
      final c = await open(repo);
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      final v = c.read(roomVariantProvider.notifier);
      final first = v.selectVariant('variant-b');
      await tick();
      final second = v.renameVariant('variant-b', 'Pending');
      var closed = false;
      final closing = c
          .read(roomMaskProvider.notifier)
          .closeProject()
          .then((_) => closed = true);
      await second;
      expect(closed, isFalse);
      expect(c.read(roomProjectSessionProvider), isNull);
      gate.complete();
      await first;
      await closing;
      await repo.delete('project-1');
      expect(await repo.read('project-1'), isNull);
      expect(repo.writes, hasLength(1));
    },
  );
  test(
    'real filesystem reopen in fresh container restores colors selection baseline without new assets',
    () async {
      final dir = await Directory.systemTemp.createTemp('room-variants-');
      addTearDown(() => dir.delete(recursive: true));
      var repo = await FileRoomProjectRepository.open(directory: dir.path);
      await repo.save(roomProjectFixture(), expectedRevision: 0);
      Future<List<String>> assets() async =>
          (await dir
                .list(recursive: true)
                .where((e) => e is File && e.path.contains('/assets/'))
                .map((e) => e.path)
                .toList())
            ..sort();
      final before = await assets();
      final c = await open(repo);
      final v = c.read(roomVariantProvider.notifier);
      await v.createVariant('Night');
      final id = session(c).activeVariantId;
      await v.updateVariantColors(RoomLayerColors(wall: RgbColor(2, 4, 6)));
      await v.pinComparisonBaseline('variant-a');
      await c.read(roomMaskProvider.notifier).closeProject();
      await repo.close();
      expect(await assets(), before);
      repo = await FileRoomProjectRepository.open(directory: dir.path);
      final reopened = await open(repo);
      expect(session(reopened).activeVariantId, id);
      expect(session(reopened).comparisonBaselineVariantId, 'variant-a');
      expect(session(reopened).variants, hasLength(3));
      expect(
        reopened.read(roomMaskProvider).draft!.colors.wall,
        RgbColor(2, 4, 6),
      );
      await reopened.read(roomMaskProvider.notifier).closeProject();
      await repo.close();
    },
  );
}
