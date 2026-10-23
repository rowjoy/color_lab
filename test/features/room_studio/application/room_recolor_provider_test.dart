import 'dart:async';
import 'dart:typed_data';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
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

void main() {
  test('real isolate service returns a detached matching frame', () async {
    final draft = _draft();
    final key = RoomRecolorKey(
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
