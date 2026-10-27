import 'dart:async';
import 'dart:typed_data';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/application/room_variant_controller.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_provider.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_service.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_undo.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/room_project_fixtures.dart';

PreparedPhoto _photo() => PreparedPhoto(
  width: 1,
  height: 1,
  rgbaBytes: Uint8List.fromList([80, 90, 100, 255]),
  previewBytes: Uint8List(0),
  palette: const [],
);

RoomMaskDraft _draft({int maskRevision = 0, int colorRevision = 0}) {
  final masks = MaskBitmap(
    width: 1,
    height: 1,
    labels: Uint8List.fromList([RoomLayer.wall.label]),
  );
  return RoomMaskDraft(
    photoId: 'photo',
    photo: _photo(),
    aiMasks: masks,
    masks: masks,
    history: MaskUndoHistory(),
    maskRevision: maskRevision,
    changedFromAiCount: 0,
    colors: RoomLayerColors(wall: RgbColor(160, 80, 40)),
    colorRevision: colorRevision,
  );
}

RoomRecolorFrame _frame(RoomRecolorKey key, [int marker = 1]) =>
    RoomRecolorFrame(
      key: key,
      width: 1,
      height: 1,
      rgbaBytes: Uint8List.fromList([marker, 2, 3, 255]),
      pngBytes: Uint8List.fromList([marker]),
    );

final class _DraftController extends RoomMaskController {
  _DraftController(this.initial);

  final RoomMaskDraft initial;

  @override
  RoomMaskState build() =>
      RoomMaskState(stage: RoomMaskStage.ready, draft: initial);

  void replace(RoomMaskDraft draft) => state = state.copyWith(draft: draft);
}

final class _Request {
  _Request({required this.key, required this.photo, required this.masks});

  final RoomRecolorKey key;
  final PreparedPhoto photo;
  final MaskBitmap masks;
  final result = Completer<RoomRecolorFrame>();
}

final class _Service implements RoomRecolorService {
  final requests = <_Request>[];

  @override
  Future<RoomRecolorFrame> render({
    required RoomRecolorKey key,
    required PreparedPhoto photo,
    required MaskBitmap masks,
    required RoomLayerColors colors,
  }) {
    final request = _Request(key: key, photo: photo, masks: masks);
    requests.add(request);
    return request.result.future;
  }
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

class _PreviewSession extends RoomProjectSessionController {
  @override
  RoomProjectSession build() {
    final draft = ref.watch(roomMaskProvider).draft!;
    return RoomProjectSession(
      projectId: 'project',
      name: 'Room',
      durable: null,
      visible: draft,
      saveStatus: RoomProjectSaveStatus.saved,
      saveError: null,
      pendingSaveCount: 0,
      acknowledgedRevision: 0,
      variantSet: RoomVariantSet(
        variants: [RoomColorVariant(id: 'a', name: 'A', colors: draft.colors)],
        activeVariantId: 'a',
      ),
    );
  }
}

void main() {
  test(
    'session Open renders one coherent project before the editor mirror catches up',
    () async {
      final service = _Service();
      final source = roomProjectFixture(revision: 1);
      final other = source.copyWith(
        projectId: 'other',
        maskBytes: Uint8List.fromList([4, 3, 2, 1]),
      );
      final repo = InMemoryRoomProjectRepository(initial: [source, other]);
      final c = ProviderContainer(
        overrides: [
          roomProjectRepositoryProvider.overrideWith((ref) async => repo),
          roomRecolorServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(c.dispose);
      await c.read(roomMaskProvider.notifier).openProject('project-1');
      final subscription = c.listen(roomRecolorPreviewProvider, (_, _) {});
      addTearDown(subscription.close);
      await _tick();
      // Session publication precedes installing the returned editor draft.
      await c.read(roomProjectSessionProvider.notifier).openProject('other');
      await _tick();
      expect(service.requests.last.key.projectId, 'other');
      expect(service.requests.last.masks.labels, [4, 3, 2, 1]);
      expect(c.read(roomMaskProvider).draft!.masks.labels, [1, 2, 3, 4]);
    },
  );
  test(
    'mismatched worker full key fails instead of publishing another variant',
    () async {
      final service = _Service();
      final repo = InMemoryRoomProjectRepository(
        initial: [roomProjectFixture(revision: 1)],
      );
      final c = ProviderContainer(
        overrides: [
          roomProjectRepositoryProvider.overrideWith((ref) async => repo),
          roomRecolorServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(c.dispose);
      await c.read(roomMaskProvider.notifier).openProject('project-1');
      final result = c.read(roomRecolorPreviewProvider.future);
      await _tick();
      service.requests.single.result.complete(
        _frame(c.read(roomComparisonKeyProvider)!),
      );
      await expectLater(result, throwsStateError);
      expect(c.read(roomRecolorPreviewProvider).hasError, isTrue);
    },
  );
  for (final failedSide in ['active', 'baseline']) {
    test(
      'active and baseline generations isolate late $failedSide error across variants',
      () async {
        final service = _Service();
        final repo = InMemoryRoomProjectRepository(
          initial: [roomProjectFixture(revision: 1)],
        );
        final c = ProviderContainer(
          overrides: [
            roomProjectRepositoryProvider.overrideWith((ref) async => repo),
            roomRecolorServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(c.dispose);
        await c.read(roomMaskProvider.notifier).openProject('project-1');
        final active = c.listen(roomRecolorPreviewProvider, (_, _) {});
        final baseline = c.listen(roomComparisonPreviewProvider, (_, _) {});
        addTearDown(active.close);
        addTearDown(baseline.close);
        await _tick();
        final old = List<_Request>.of(service.requests);
        expect(old.map((r) => r.key.variantId).toSet(), {
          'variant-a',
          'variant-b',
        });
        await c.read(roomVariantProvider.notifier).selectVariant('variant-b');
        await c
            .read(roomVariantProvider.notifier)
            .pinComparisonBaseline('variant-a');
        await _tick();
        for (var i = 0; i < old.length; i++) {
          if ((i == 0) == (failedSide == 'active')) {
            old[i].result.completeError(StateError('old side failed'));
          } else {
            old[i].result.complete(_frame(old[i].key));
          }
        }
        await _tick();
        expect(c.read(roomRecolorPreviewProvider).isLoading, isTrue);
        expect(c.read(roomRecolorPreviewProvider).hasError, isFalse);
        expect(c.read(roomComparisonPreviewProvider).isLoading, isTrue);
        expect(c.read(roomComparisonPreviewProvider).hasError, isFalse);
        final latestActive = service.requests.lastWhere(
          (r) => r.key == c.read(roomRecolorKeyProvider),
        );
        final latestBaseline = service.requests.lastWhere(
          (r) => r.key == c.read(roomComparisonKeyProvider),
        );
        latestActive.result.complete(_frame(latestActive.key, 22));
        await _tick();
        expect(
          c.read(roomRecolorPreviewProvider).requireValue!.rgbaBytes.first,
          22,
        );
        expect(c.read(roomComparisonPreviewProvider).isLoading, isTrue);
        latestBaseline.result.complete(_frame(latestBaseline.key, 33));
        await _tick();
        expect(
          c.read(roomComparisonPreviewProvider).requireValue!.rgbaBytes.first,
          33,
        );
        expect(
          c.read(roomRecolorPreviewProvider).requireValue!.key.variantId,
          'variant-b',
        );
      },
    );
  }
  test(
    'same-photo project change rejects late old project results on both sides',
    () async {
      final service = _Service();
      final source = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(
        initial: [
          source,
          source.copyWith(projectId: 'other'),
        ],
      );
      final c = ProviderContainer(
        overrides: [
          roomProjectRepositoryProvider.overrideWith((ref) async => repo),
          roomRecolorServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(c.dispose);
      await c.read(roomMaskProvider.notifier).openProject('project-1');
      final a = c.listen(roomRecolorPreviewProvider, (_, _) {});
      final b = c.listen(roomComparisonPreviewProvider, (_, _) {});
      addTearDown(a.close);
      addTearDown(b.close);
      await _tick();
      final old = List<_Request>.of(service.requests);
      await c.read(roomMaskProvider.notifier).openProject('other');
      await _tick();
      for (final r in old) {
        r.result.complete(_frame(r.key));
      }
      await _tick();
      expect(c.read(roomRecolorPreviewProvider).isLoading, isTrue);
      expect(c.read(roomComparisonPreviewProvider).isLoading, isTrue);
      for (final r in service.requests.where(
        (r) => r.key.projectId == 'other',
      )) {
        r.result.complete(_frame(r.key));
      }
      await _tick();
      expect(
        c.read(roomRecolorPreviewProvider).requireValue!.key.projectId,
        'other',
      );
      expect(
        c.read(roomComparisonPreviewProvider).requireValue!.key.projectId,
        'other',
      );
    },
  );
  test('real isolate service returns a detached matching frame', () async {
    final draft = _draft();
    final key = RoomRecolorKey(
      projectId: 'project',
      variantId: 'a',
      photoId: draft.photoId,
      maskRevision: draft.maskRevision,
      colorRevision: draft.colorRevision,
    );

    final frame = await const IsolateRoomRecolorService().render(
      key: key,
      photo: draft.photo,
      masks: draft.masks,
      colors: draft.colors,
    );

    expect(frame.key, key);
    expect(frame.width, 1);
    expect(frame.height, 1);
    expect(frame.pngBytes, isNotEmpty);
    expect(() => frame.rgbaBytes[0] = 0, throwsUnsupportedError);
  });

  test('provider publishes only the newest photo mask color key', () async {
    final service = _Service();
    final controller = _DraftController(_draft());
    final container = ProviderContainer(
      overrides: [
        roomMaskProvider.overrideWith(() => controller),
        roomProjectSessionProvider.overrideWith(_PreviewSession.new),
        roomRecolorServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      roomRecolorPreviewProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await _tick();
    expect(service.requests, hasLength(1));
    final first = service.requests.single;
    expect(first.key.maskRevision, 0);
    expect(first.key.colorRevision, 0);

    controller.replace(_draft(maskRevision: 1, colorRevision: 2));
    await _tick();
    expect(service.requests, hasLength(2));
    final latest = service.requests.last;
    first.result.complete(_frame(first.key, 10));
    await _tick();
    expect(container.read(roomRecolorPreviewProvider).isLoading, isTrue);

    latest.result.complete(_frame(latest.key, 20));
    await _tick();
    final published = container.read(roomRecolorPreviewProvider).requireValue!;
    expect(published.key, latest.key);
    expect(published.rgbaBytes[0], 20);
  });

  test('late old error is ignored and current render can finish', () async {
    final service = _Service();
    final controller = _DraftController(_draft());
    final container = ProviderContainer(
      overrides: [
        roomMaskProvider.overrideWith(() => controller),
        roomProjectSessionProvider.overrideWith(_PreviewSession.new),
        roomRecolorServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      roomRecolorPreviewProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await _tick();
    final old = service.requests.single;
    controller.replace(_draft(colorRevision: 1));
    await _tick();
    final latest = service.requests.last;

    old.result.completeError(StateError('old failure'));
    await _tick();
    expect(container.read(roomRecolorPreviewProvider).isLoading, isTrue);
    latest.result.complete(_frame(latest.key));
    await _tick();
    expect(
      container.read(roomRecolorPreviewProvider).requireValue!.key,
      latest.key,
    );
  });

  test('invalidating a failed preview retries the same key', () async {
    final service = _Service();
    final controller = _DraftController(_draft());
    final container = ProviderContainer(
      overrides: [
        roomMaskProvider.overrideWith(() => controller),
        roomProjectSessionProvider.overrideWith(_PreviewSession.new),
        roomRecolorServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final failed = container.read(roomRecolorPreviewProvider.future);
    await _tick();
    service.requests.single.result.completeError(StateError('render failed'));
    await expectLater(failed, throwsStateError);
    container.invalidate(roomRecolorPreviewProvider);
    final retried = container.read(roomRecolorPreviewProvider.future);
    await _tick();
    expect(service.requests, hasLength(2));
    service.requests.last.result.complete(_frame(service.requests.last.key));
    expect((await retried)!.key, service.requests.last.key);
  });
}
