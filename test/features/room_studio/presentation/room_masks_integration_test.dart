import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/application/photo_acquisition_controller.dart';
import 'package:color_lab/features/picker/application/camera_session.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/application/theme_mode_provider.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_model_download_providers.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_provider.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_service.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_stroke.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_screen.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_viewport.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'package:color_lab/features/room_studio/segmentation/room_segmentation_service.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../../support/in_memory_acquisition_intent_store.dart';
import '../../../support/in_memory_app_preferences_repository.dart';
import '../../../support/in_memory_color_history_repository.dart';

class _Picker implements PhotoPickerService {
  PreparedPhoto? next = _photo(), recovered;
  Completer<void>? gate;
  PhotoPickFailure? failure;
  final sources = <PhotoSource>[];
  int recoveries = 0;
  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async {
    sources.add(source);
    final result = next;
    await gate?.future;
    if (failure != null) throw failure!;
    return result;
  }

  @override
  Future<PreparedPhoto?> recoverLost() async {
    recoveries++;
    return recovered;
  }

  @override
  Future<bool> openSettings() async => false;
}

PreparedPhoto _photo([int gray = 100]) {
  final image = img.Image(width: 10, height: 10, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(gray, gray, gray, 255));
  return PreparedPhoto(
    width: 10,
    height: 10,
    rgbaBytes: image.getBytes(order: img.ChannelOrder.rgba),
    previewBytes: Uint8List.fromList(img.encodePng(image)),
    palette: const [],
  );
}

class _Analysis {
  _Analysis(this.id);
  final String id;
  final result = Completer<RoomSegmentationResult>();
  void succeed([int label = 0]) => result.complete(
    RoomSegmentationResult(
      photoId: id,
      masks: MaskBitmap(
        width: 10,
        height: 10,
        labels: Uint8List(100)..fillRange(0, 100, label),
      ),
    ),
  );
  void fail() => result.completeError(StateError('private model error'));
}

class _Segmenter implements RoomSegmentationService {
  final requests = <_Analysis>[];
  @override
  Future<RoomSegmentationResult> analyze({
    required String photoId,
    required PreparedPhoto photo,
  }) {
    final request = _Analysis(photoId);
    requests.add(request);
    return request.result.future;
  }

  @override
  Future<void> close() async {}
}

class _RecolorRequest {
  _RecolorRequest(this.key, this.photo);

  final RoomRecolorKey key;
  final PreparedPhoto photo;
  final result = Completer<RoomRecolorFrame>();

  void succeed() => result.complete(
    RoomRecolorFrame(
      key: key,
      width: photo.width,
      height: photo.height,
      rgbaBytes: photo.rgbaBytes,
      pngBytes: photo.previewBytes,
    ),
  );

  void fail() => result.completeError(StateError('preview failed'));
}

class _Recolorer implements RoomRecolorService {
  final requests = <_RecolorRequest>[];

  @override
  Future<RoomRecolorFrame> render({
    required RoomRecolorKey key,
    required PreparedPhoto photo,
    required MaskBitmap masks,
    required RoomLayerColors colors,
  }) {
    final request = _RecolorRequest(key, photo);
    requests.add(request);
    return request.result.future;
  }
}

class _Exporter implements RoomImageExportService {
  Uint8List? bytes;
  String? photoId;
  Rect? origin;
  Object? failure;
  Completer<void>? gate;

  @override
  Future<void> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
  }) async {
    bytes = Uint8List.fromList(pngBytes);
    this.photoId = photoId;
    this.origin = origin;
    await gate?.future;
    final error = failure;
    if (error != null) throw error;
  }
}

class _Store extends InMemoryAcquisitionIntentStore {
  Completer<void>? clearGate;
  int clears = 0;
  @override
  Future<void> clear({bool discardUntrusted = false}) async {
    clears++;
    await clearGate?.future;
    await super.clear(discardUntrusted: discardUntrusted);
  }
}

Future<ProviderContainer> _launch(
  WidgetTester tester, {
  _Picker? picker,
  _Segmenter? segmenter,
  RoomRecolorService? recolorer,
  RoomImageExportService? exporter,
  InMemoryAcquisitionIntentStore? store,
  AppPreferences? preferences,
  RoomModelStore? modelStore,
}) async {
  final container = ProviderContainer(
    overrides: [
      acquisitionIntentStoreProvider.overrideWith(
        (ref) async => store ?? InMemoryAcquisitionIntentStore(),
      ),
      appPreferencesRepositoryProvider.overrideWith(
        (ref) async => InMemoryAppPreferencesRepository(initial: preferences),
      ),
      colorHistoryRepositoryProvider.overrideWith(
        (ref) async => InMemoryColorHistoryRepository(),
      ),
      colorNamerProvider.overrideWith(
        (ref) async =>
            ColorNamer([NamedColor('Sage', RgbColor.fromHex('#A7B5A0'))]),
      ),
      photoPickerServiceProvider.overrideWithValue(picker ?? _Picker()),
      roomSegmentationServiceProvider.overrideWithValue(
        segmenter ?? _Segmenter(),
      ),
      if (recolorer != null)
        roomRecolorServiceProvider.overrideWithValue(recolorer),
      if (exporter != null)
        roomImageExportServiceProvider.overrideWithValue(exporter),
      if (modelStore != null)
        roomModelStoreProvider.overrideWithValue(modelStore),
      cameraSessionFactoryProvider.overrideWithValue(
        () => throw StateError(
          'Room must use the explicit photo source, never live camera',
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ColorLabApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _key(String name) => find.byKey(ValueKey(name));

Future<void> _expectCandidate(WidgetTester tester, int gray) async {
  final candidate = _key('room-mask-candidate-photo');
  expect(candidate, findsOneWidget);
  final raw = find.descendant(of: candidate, matching: find.byType(RawImage));
  for (var i = 0; i < 200; i++) {
    if (raw.evaluate().isNotEmpty &&
        tester.widget<RawImage>(raw).image != null) {
      break;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  final image = tester.widget<RawImage>(raw).image;
  expect(image, isNotNull, reason: 'Candidate photo must finish decoding');
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  expect(bytes!.buffer.asUint8List().sublist(0, 4), [gray, gray, gray, 255]);
  expect(find.byType(RoomMaskViewport), findsNothing);
  expect(_key('room-mask-tool-add'), findsNothing);
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _frames(tester);
}

Future<void> _open(WidgetTester tester) async {
  final rooms = _key('nav-rooms');
  expect(rooms, findsOneWidget);
  await tester.tap(rooms);
  await _frames(tester);
  final masks = _key('open-room-masks');
  expect(masks, findsOneWidget);
  await tester.tap(masks);
  await _frames(tester);
}

Future<void> _ready(
  WidgetTester tester,
  _Segmenter segmenter, {
  int label = 0,
}) async {
  await _tap(tester, _key('room-mask-gallery'));
  segmenter.requests.last.succeed(label);
  await _frames(tester);
}

Future<void> _worker(WidgetTester tester, ProviderContainer container) async {
  for (var i = 0; i < 100 && container.read(roomMaskProvider).editBusy; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(container.read(roomMaskProvider).editBusy, isFalse);
  await _frames(tester);
}

Future<void> _preview(WidgetTester tester, ProviderContainer container) async {
  for (var i = 0; i < 100; i++) {
    final draft = container.read(roomMaskProvider).draft;
    final preview = container.read(roomRecolorPreviewProvider);
    final frame = preview.value;
    if (draft != null &&
        frame != null &&
        frame.key.photoId == draft.photoId &&
        frame.key.maskRevision == draft.maskRevision &&
        frame.key.colorRevision == draft.colorRevision) {
      await _frames(tester);
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  fail('Current recolor preview did not finish');
}

Future<void> _dot(
  WidgetTester tester,
  ProviderContainer container, {
  double x = .55,
}) async {
  final viewport = find.byType(RoomMaskViewport);
  await tester.ensureVisible(viewport);
  final rect = tester.getRect(viewport);
  final size = rect.width < rect.height ? rect.width : rect.height;
  await tester.tapAt(
    Offset(rect.center.dx + (x - .5) * size, rect.center.dy + .05 * size),
  );
  await tester.pump();
  await _worker(tester, container);
}

Future<void> _zoom(WidgetTester tester) async {
  await _tap(tester, _key('room-mask-tool-move'));
  final viewport = find.byType(RoomMaskViewport);
  await tester.ensureVisible(viewport);
  final center = tester.getCenter(viewport);
  final a = await tester.startGesture(center - const Offset(40, 0), pointer: 1);
  final b = await tester.startGesture(center + const Offset(40, 0), pointer: 2);
  await a.moveTo(center - const Offset(80, 0));
  await b.moveTo(center + const Offset(80, 0));
  await a.up();
  await b.up();
  await _frames(tester);
}

void main() {
  testWidgets('Cancel download aborts model setup and ignores late analysis', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'room-model-screen-test-',
    );
    final gate = Completer<Directory>();
    final modelStore = RoomModelStore(directory: () => gate.future);
    final pending = modelStore.load();
    final cancelled = expectLater(
      pending,
      throwsA(
        isA<RoomModelDownloadException>().having(
          (e) => e.cancelled,
          'cancelled',
          isTrue,
        ),
      ),
    );
    addTearDown(() async {
      if (!gate.isCompleted) gate.complete(directory);
      await modelStore.close();
      directory.deleteSync(recursive: true);
    });
    final segmenter = _Segmenter();
    final container = await _launch(
      tester,
      segmenter: segmenter,
      modelStore: modelStore,
    );
    await _open(tester);
    await _tap(tester, _key('room-mask-gallery'));
    expect(find.text('Checking saved AI models…'), findsOneWidget);
    await _tap(tester, find.text('Cancel download'));
    gate.complete(directory);
    await cancelled;
    expect(container.read(roomMaskProvider).stage, RoomMaskStage.empty);
    segmenter.requests.single.succeed(1);
    await _frames(tester);
    expect(container.read(roomMaskProvider).draft, isNull);
    expect(modelStore.progress.stage, RoomModelDownloadStage.cancelled);
  });

  testWidgets('refresh AI masks retains the photo, corrections, and colors', (
    tester,
  ) async {
    final segmenter = _Segmenter();
    final container = await _launch(tester, segmenter: segmenter);
    await _open(tester);
    await _ready(tester, segmenter);
    final controller = container.read(roomMaskProvider.notifier);
    await _tap(tester, _key('room-mask-tool-add'));
    await _dot(tester, container);
    controller.setLayerColor(RoomLayer.wall, RgbColor(12, 34, 56));
    await _frames(tester);
    final before = container.read(roomMaskProvider).draft!;
    expect(before.masks.labels[55], 1);
    await _tap(tester, _key('room-mask-refresh'));
    expect(container.read(roomMaskProvider).draft, same(before));
    expect(_key('room-mask-editor'), findsOneWidget);
    expect(tester.widget<Offstage>(_key('room-mask-editor')).offstage, isFalse);
    expect(find.text('Refreshing AI masks…'), findsWidgets);
    expect(
      tester.widget<SecondaryButton>(_key('room-mask-refresh')).onPressed,
      isNull,
    );
    expect(
      tester.widget<PrimaryButton>(_key('room-mask-fullscreen')).onPressed,
      isNull,
    );
    segmenter.requests.last.succeed(4);
    await _worker(tester, container);
    final after = container.read(roomMaskProvider).draft!;
    expect(after.photo, same(before.photo));
    expect(after.photoId, before.photoId);
    expect(after.masks.labels[0], 4);
    expect(after.masks.labels[55], 1);
    expect(after.colors, before.colors);
    expect(after.colorRevision, before.colorRevision);
    expect(
      find.text('AI masks refreshed. Your corrections and colors were kept.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('failed mask refresh keeps the editor usable and offers retry', (
    tester,
  ) async {
    final segmenter = _Segmenter();
    final container = await _launch(tester, segmenter: segmenter);
    await _open(tester);
    await _ready(tester, segmenter, label: 1);
    final before = container.read(roomMaskProvider).draft!;
    await _tap(tester, _key('room-mask-refresh'));
    segmenter.requests.last.fail();
    await _frames(tester);
    expect(container.read(roomMaskProvider).draft, same(before));
    expect(container.read(roomMaskProvider).canEdit, isTrue);
    expect(
      find.text(
        'Could not refresh AI masks. Your current masks and colors are safe. Try again.',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<SecondaryButton>(_key('room-mask-refresh')).onPressed,
      isNotNull,
    );
    await _tap(tester, _key('room-mask-refresh'));
    segmenter.requests.last.succeed(3);
    await _worker(tester, container);
    expect(container.read(roomMaskProvider).draft!.masks.labels[0], 3);
    expect(container.read(roomMaskProvider).failure, isNull);
  });

  testWidgets(
    'full-screen editor edits the shared masks and keeps edits on close',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _ready(tester, segmenter);
      final initial = container.read(roomMaskProvider).draft!;
      await _tap(tester, _key('room-mask-fullscreen'));
      expect(_key('room-mask-fullscreen-editor'), findsOneWidget);
      expect(_key('room-mask-fullscreen-viewport'), findsOneWidget);
      expect(container.read(roomMaskProvider).tool, RoomMaskTool.add);
      await _tap(tester, _key('room-mask-fullscreen-zoom-in'));
      final viewport = _key('room-mask-fullscreen-viewport');
      final rect = tester.getRect(viewport);
      expect(rect.height, greaterThan(300));
      // At 1.5×, this hits the center of source pixel (6, 5). Ignoring
      // the displayed zoom would hit a different pixel in this tiny photo.
      final side = rect.shortestSide;
      final dot = rect.center + Offset(side * .225, side * .075);
      await tester.tapAt(dot);
      await _worker(tester, container);
      final painted = container.read(roomMaskProvider).draft!;
      expect(painted.maskRevision, initial.maskRevision + 1);
      expect(painted.masks.count(RoomLayer.wall), 1);
      expect(painted.masks.labels[56], RoomLayer.wall.label);
      await _tap(tester, _key('room-mask-fullscreen-close'));
      expect(_key('room-mask-fullscreen-editor'), findsNothing);
      expect(container.read(roomMaskProvider).draft, same(painted));
      expect(find.byType(RoomMaskViewport), findsOneWidget);
      await _tap(tester, _key('room-mask-fullscreen'));
      await _tap(tester, _key('room-mask-fullscreen-zoom-in'));
      await _tap(tester, _key('room-mask-fullscreen-tool-erase'));
      await tester.tapAt(dot);
      await _worker(tester, container);
      expect(
        container.read(roomMaskProvider).draft!.masks.count(RoomLayer.wall),
        0,
      );
      await _tap(tester, _key('room-mask-fullscreen-undo'));
      await _worker(tester, container);
      expect(
        container.read(roomMaskProvider).draft!.masks.count(RoomLayer.wall),
        painted.masks.count(RoomLayer.wall),
      );
      await _tap(tester, _key('room-mask-fullscreen-close'));
    },
  );

  testWidgets(
    'closing full-screen cancels a buffered brush without phantom edits',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _ready(tester, segmenter);
      container.read(roomMaskProvider.notifier).setBrushFraction(.2);
      await _tap(tester, _key('room-mask-fullscreen'));
      final draft = container.read(roomMaskProvider).draft!;
      final gesture = await tester.startGesture(
        tester.getCenter(_key('room-mask-fullscreen-viewport')),
        pointer: 7,
      );
      await _tap(tester, _key('room-mask-fullscreen-close'));
      await gesture.up();
      await _frames(tester);
      expect(container.read(roomMaskProvider).draft, same(draft));
      expect(container.read(roomMaskProvider).editBusy, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'candidate photo is visible through initial and replacement analysis',
    (tester) async {
      final picker = _Picker();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        segmenter: segmenter,
      );
      await _open(tester);
      await _tap(tester, _key('room-mask-gallery'));
      await _expectCandidate(tester, 100);
      expect(container.read(roomMaskProvider).canEdit, isFalse);
      segmenter.requests.single.succeed(1);
      await _frames(tester);
      final old = container.read(roomMaskProvider).draft;
      final oldViewport = tester.element(find.byType(RoomMaskViewport));
      picker.next = _photo(50);
      await _tap(tester, _key('room-mask-gallery'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      await _expectCandidate(tester, 50);
      final retained = find.byType(RoomMaskViewport, skipOffstage: false);
      expect(tester.widget<RoomMaskViewport>(retained).photo, same(old!.photo));
      await _tap(tester, find.text('Cancel analysis'));
      expect(container.read(roomMaskProvider).draft, same(old));
      expect(find.byType(RoomMaskViewport), findsOneWidget);
      expect(tester.element(find.byType(RoomMaskViewport)), same(oldViewport));
      expect(_key('room-mask-candidate-photo'), findsNothing);
      await _tap(tester, _key('room-mask-gallery'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      await _expectCandidate(tester, 50);
      segmenter.requests.last.fail();
      await _frames(tester);
      await _tap(tester, find.text('Return to previous masks'));
      expect(container.read(roomMaskProvider).draft, same(old));
      expect(find.byType(RoomMaskViewport), findsOneWidget);
      expect(tester.element(find.byType(RoomMaskViewport)), same(oldViewport));
      segmenter.requests[1].succeed(3);
      await _frames(tester);
      expect(container.read(roomMaskProvider).draft, same(old));
    },
  );

  testWidgets('repeated Continue cannot invalidate a durable claim', (
    tester,
  ) async {
    final picker = _Picker()..recovered = _photo();
    final store = _Store();
    final segmenter = _Segmenter();
    final container = await _launch(
      tester,
      picker: picker,
      store: store,
      segmenter: segmenter,
    );
    await _open(tester);
    store.clearGate = Completer<void>();
    final clears = store.clears;
    final button = _key('room-mask-continue-import');
    await tester.ensureVisible(button);
    // Two actual taps before a rebuild must share one logical action.
    await tester.tap(button);
    await tester.tap(button);
    await _frames(tester);
    expect(
      tester
          .widget<SecondaryButton>(_key('room-mask-continue-import'))
          .onPressed,
      isNull,
    );
    store.clearGate!.complete();
    await _frames(tester);
    expect(store.clears, clears + 1);
    expect(segmenter.requests, hasLength(1));
    expect(container.read(roomMaskProvider).failure, isNull);
    segmenter.requests.single.succeed(1);
    await _frames(tester);
    expect(container.read(roomMaskProvider).canEdit, isTrue);
    expect(container.read(photoAcquisitionProvider).pendingReceipt, isNull);
  });

  testWidgets(
    'reopened editor stale Continue cannot lose a replacement accepted during durable clear',
    (tester) async {
      final picker = _Picker();
      final store = _Store();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        store: store,
        segmenter: segmenter,
      );
      await _open(tester);
      await _ready(tester, segmenter, label: 1);
      final old = container.read(roomMaskProvider).draft;
      final replacement = _photo(50);
      picker.next = replacement;
      store.clearGate = Completer<void>();
      await _tap(tester, _key('room-mask-gallery'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      final receipt = container.read(photoAcquisitionProvider).pendingReceipt!;
      await _tap(tester, find.byTooltip('Back'));
      await _tap(tester, _key('open-room-masks'));
      await _tap(tester, _key('room-mask-continue-import'));
      // A new route can have opened this confirmation while the old route's
      // retained controller still owns the receipt's durable clear.
      final staleConfirmation = _key('confirm-room-mask-replace');
      store.clearGate!.complete();
      await _frames(tester);
      final accepted = container.read(roomMaskProvider).candidate!;
      expect(accepted.photo, same(replacement));
      expect(container.read(photoAcquisitionProvider).pendingReceipt, isNull);
      expect(container.read(roomMaskProvider).draft, same(old));
      expect(segmenter.requests, hasLength(1));
      if (staleConfirmation.evaluate().isNotEmpty) {
        await _tap(tester, staleConfirmation);
      }
      expect(
        container.read(roomMaskProvider).candidate,
        same(accepted),
        reason:
            'A stale continuation must not clear the already accepted photo',
      );
      expect(container.read(roomMaskProvider).failure, isNull);
      expect(container.read(roomMaskProvider).draft, same(old));
      expect(container.read(photoAcquisitionProvider).pendingReceipt, isNull);
      await _expectCandidate(tester, 50);
      await _tap(tester, _key('room-mask-continue-analysis'));
      expect(container.read(roomMaskProvider).draft, same(old));
      expect(segmenter.requests, hasLength(2));
      expect(segmenter.requests.last.id, accepted.photoId);
      segmenter.requests.last.succeed(3);
      await _frames(tester);
      final committed = container.read(roomMaskProvider).draft!;
      expect(committed.photo, same(replacement));
      expect(committed.photoId, accepted.photoId);
      expect(committed.masks.count(RoomLayer.floor), 100);
      expect(committed.photoId, isNot(receipt.requestId));
      expect(container.read(roomMaskProvider).canEdit, isTrue);
    },
  );

  testWidgets(
    'cancel releases import guard and stale completion cannot release a newer claim',
    (tester) async {
      final store = _Store();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        store: store,
        segmenter: segmenter,
      );
      await _open(tester);
      await _tap(tester, _key('room-mask-gallery'));
      await _tap(tester, find.text('Cancel analysis'));
      store.clearGate = Completer<void>();
      await _tap(tester, _key('room-mask-gallery'));
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt,
        isNotNull,
      );
      segmenter.requests.first.succeed();
      await _frames(tester);
      expect(
        tester
            .widget<SecondaryButton>(_key('room-mask-continue-import'))
            .onPressed,
        isNull,
      );
      store.clearGate!.complete();
      await _frames(tester);
      expect(segmenter.requests, hasLength(2));
      segmenter.requests.last.succeed(3);
      await _frames(tester);
      expect(
        container.read(roomMaskProvider).draft!.masks.count(RoomLayer.floor),
        100,
      );
    },
  );

  testWidgets(
    'photo editor assigns independent colors and keeps them through mask undo',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _ready(tester, segmenter, label: RoomLayer.floor.label);

      await _tap(tester, _key('room-color-layer-wall'));
      await _tap(tester, _key('room-color-choose'));
      await tester.enterText(_key('mixer-hex-input'), '#A7B5A0');
      await _tap(tester, find.text('Use this color'));
      await _tap(tester, _key('room-color-layer-floor'));
      await _tap(tester, _key('room-color-choose'));
      await tester.enterText(_key('mixer-hex-input'), '#D9BC9E');
      await _tap(tester, find.text('Use this color'));
      await _preview(tester, container);

      var draft = container.read(roomMaskProvider).draft!;
      expect(draft.colors.wall!.hex, '#A7B5A0');
      expect(draft.colors.floor!.hex, '#D9BC9E');
      expect(draft.colorRevision, 2);
      expect(_key('room-recolor-after-image'), findsOneWidget);
      await _tap(tester, _key('room-recolor-before'));
      expect(_key('room-recolor-before-image'), findsOneWidget);
      await _tap(tester, _key('room-recolor-after'));

      await _tap(tester, _key('room-mask-layer-wall'));
      await _tap(tester, _key('room-mask-tool-add'));
      await _dot(tester, container);
      draft = container.read(roomMaskProvider).draft!;
      expect(draft.colors.wall!.hex, '#A7B5A0');
      expect(draft.colors.floor!.hex, '#D9BC9E');
      await _tap(tester, _key('room-mask-undo'));
      await _worker(tester, container);
      expect(container.read(roomMaskProvider).draft!.colorRevision, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'PNG share requires the current frame and retains the room after dismissal or error',
    (tester) async {
      final segmenter = _Segmenter();
      final recolorer = _Recolorer();
      final exporter = _Exporter();
      final container = await _launch(
        tester,
        segmenter: segmenter,
        recolorer: recolorer,
        exporter: exporter,
      );
      await _open(tester);
      await _ready(tester, segmenter, label: RoomLayer.wall.label);

      expect(recolorer.requests, hasLength(1));
      expect(
        tester.widget<PrimaryButton>(_key('room-recolor-share')).onPressed,
        isNull,
      );
      recolorer.requests.single.succeed();
      await _preview(tester, container);
      expect(
        tester.widget<PrimaryButton>(_key('room-recolor-share')).onPressed,
        isNotNull,
      );

      container
          .read(roomMaskProvider.notifier)
          .setLayerColor(RoomLayer.wall, RgbColor.fromHex('#A7B5A0'));
      await _frames(tester);
      expect(recolorer.requests, hasLength(2));
      expect(
        tester.widget<PrimaryButton>(_key('room-recolor-share')).onPressed,
        isNull,
        reason: 'the visible previous frame is stale for export',
      );
      final currentRequest = recolorer.requests.last;
      currentRequest.succeed();
      await _preview(tester, container);
      final draftBeforeShare = container.read(roomMaskProvider).draft!;

      await _tap(tester, _key('room-recolor-share'));
      expect(exporter.bytes, orderedEquals(currentRequest.photo.previewBytes));
      expect(exporter.photoId, draftBeforeShare.photoId);
      expect(exporter.origin!.width, greaterThan(0));
      expect(exporter.origin!.height, greaterThan(0));
      expect(container.read(roomMaskProvider).draft, same(draftBeforeShare));

      exporter.gate = Completer<void>();
      await _tap(tester, _key('room-recolor-share'));
      final busyButton = tester.widget<PrimaryButton>(
        _key('room-recolor-share'),
      );
      expect(busyButton.isLoading, isTrue);
      expect(busyButton.onPressed, isNull);
      exporter.gate!.complete();
      exporter.gate = null;
      await _frames(tester);

      exporter.failure = StateError('native share failure');
      await _tap(tester, _key('room-recolor-share'));
      expect(find.text('Could not share the PNG. Try again.'), findsOneWidget);
      expect(container.read(roomMaskProvider).draft, same(draftBeforeShare));
      expect(
        tester.widget<PrimaryButton>(_key('room-recolor-share')).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'reopened editor retains a preview only while its replacement renders',
    (tester) async {
      final segmenter = _Segmenter();
      final recolorer = _Recolorer();
      final container = await _launch(
        tester,
        segmenter: segmenter,
        recolorer: recolorer,
      );
      await _open(tester);
      await _ready(tester, segmenter, label: RoomLayer.wall.label);
      recolorer.requests.single.succeed();
      await _preview(tester, container);

      await _tap(tester, find.byTooltip('Back'));
      await _tap(tester, _key('open-room-masks'));
      expect(_key('room-recolor-after-image'), findsOneWidget);

      container
          .read(roomMaskProvider.notifier)
          .setLayerColor(RoomLayer.wall, RgbColor.fromHex('#B25030'));
      await _frames(tester);
      expect(recolorer.requests, hasLength(2));
      expect(_key('room-recolor-previous-image'), findsOneWidget);
      expect(find.text('Updating preview...'), findsOneWidget);

      recolorer.requests.last.fail();
      await _frames(tester);
      expect(
        find.text('Preview could not update. Your photo and masks are safe.'),
        findsOneWidget,
      );
      expect(find.text('Updating preview...'), findsNothing);
      expect(_key('room-recolor-before-image'), findsOneWidget);
    },
  );

  testWidgets(
    'erasing all detected pixels does not describe an empty AI result',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _tap(tester, _key('room-mask-gallery'));
      final request = segmenter.requests.single;
      request.result.complete(
        RoomSegmentationResult(
          photoId: request.id,
          masks: MaskBitmap(
            width: 10,
            height: 10,
            labels: Uint8List(100)..[55] = 1,
          ),
        ),
      );
      await _frames(tester);
      await _tap(tester, _key('room-mask-tool-erase'));
      await _dot(tester, container);
      expect(
        container.read(roomMaskProvider).draft!.masks.count(RoomLayer.wall),
        0,
      );
      expect(
        container.read(roomMaskProvider).draft!.aiMasks.count(RoomLayer.wall),
        1,
      );
      expect(
        find.textContaining('No supported surfaces were found'),
        findsNothing,
      );
    },
  );

  testWidgets('manual addition preserves the genuine empty AI explanation', (
    tester,
  ) async {
    final segmenter = _Segmenter();
    final container = await _launch(tester, segmenter: segmenter);
    await _open(tester);
    await _ready(tester, segmenter);
    await _tap(tester, _key('room-mask-tool-add'));
    await _dot(tester, container);
    expect(
      container.read(roomMaskProvider).draft!.masks.count(RoomLayer.wall),
      1,
    );
    expect(
      find.textContaining('No supported surfaces were found'),
      findsOneWidget,
    );
  });

  testWidgets('Room offers a focused visible photo-mask editor entry', (
    tester,
  ) async {
    await _launch(tester);
    final rooms = find.byKey(const ValueKey('nav-rooms'));
    expect(rooms, findsOneWidget);
    await tester.tap(rooms);
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('open-room-masks'));
    expect(entry, findsOneWidget);
    expect(entry.hitTestable(), findsOneWidget);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Room masks'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('room-mask-gallery')).hitTestable(),
      findsOneWidget,
    );
  });

  for (final source in PhotoSource.values) {
    testWidgets(
      '${source.name} import runs analysis before enabling manual masks',
      (tester) async {
        final picker = _Picker();
        final segmenter = _Segmenter();
        final container = await _launch(
          tester,
          picker: picker,
          segmenter: segmenter,
        );
        await _open(tester);
        await _tap(tester, _key('room-mask-${source.name}'));
        expect(picker.sources, [source]);
        expect(container.read(roomMaskProvider).stage, RoomMaskStage.analyzing);
        expect(
          find.text('Finding room surfaces on this device…'),
          findsOneWidget,
        );
        expect(find.byType(RoomMaskViewport), findsNothing);
        expect(container.read(roomMaskProvider).canEdit, isFalse);
        segmenter.requests.single.succeed(1);
        await _frames(tester);
        expect(find.byType(RoomMaskViewport), findsOneWidget);
        expect(container.read(roomMaskProvider).canEdit, isTrue);
        expect(find.text('Mask preview'), findsOneWidget);
        expect(find.textContaining('Not detected'), findsNWidgets(3));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'failure never becomes editable empty output; retry accepts genuine empty output',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _tap(tester, _key('room-mask-gallery'));
      segmenter.requests.last.fail();
      await _frames(tester);
      expect(
        find.text(
          'Room analysis could not finish. Try again or choose another photo.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('private model'), findsNothing);
      expect(find.byType(RoomMaskViewport), findsNothing);
      expect(container.read(roomMaskProvider).canEdit, isFalse);
      await _tap(tester, find.text('Retry analysis'));
      segmenter.requests.last.succeed();
      await _frames(tester);
      expect(
        find.text(
          'No supported surfaces were found. You can mark them manually.',
        ),
        findsOneWidget,
      );
      expect(container.read(roomMaskProvider).canEdit, isTrue);
    },
  );

  testWidgets(
    'viewport edits transfer ownership, erase only selection and undo restores exact pixels',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _ready(tester, segmenter, label: 3);
      final original = container
          .read(roomMaskProvider)
          .draft!
          .masks
          .labels
          .toList();
      await _tap(tester, _key('room-mask-tool-add'));
      await _dot(tester, container);
      final labels = List<int>.filled(100, 3)..[55] = 1;
      expect(container.read(roomMaskProvider).draft!.masks.labels, labels);
      await _tap(tester, _key('room-mask-layer-floor'));
      await _tap(tester, _key('room-mask-tool-erase'));
      await _dot(tester, container);
      expect(container.read(roomMaskProvider).draft!.masks.labels, labels);
      await _tap(tester, _key('room-mask-undo'));
      await _worker(tester, container);
      expect(container.read(roomMaskProvider).draft!.masks.labels, original);
      expect(container.read(roomMaskProvider).draft!.history.canUndo, isFalse);
    },
  );

  testWidgets(
    'Show original preserves pixels and disables strokes until overlay returns',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _ready(tester, segmenter);
      await _tap(tester, _key('room-mask-tool-add'));
      final draft = container.read(roomMaskProvider).draft;
      await _tap(tester, _key('room-mask-show-original'));
      expect(container.read(roomMaskProvider).tool, RoomMaskTool.move);
      expect(
        tester
            .widget<RoomMaskViewport>(find.byType(RoomMaskViewport))
            .showOverlay,
        isFalse,
      );
      await _dot(tester, container);
      expect(container.read(roomMaskProvider).draft, same(draft));
      await _tap(tester, _key('room-mask-show-original'));
      expect(container.read(roomMaskProvider).canEdit, isTrue);
    },
  );

  testWidgets(
    'restore cancel and system Back retain edits; accept clears edits and history',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _ready(tester, segmenter);
      await _tap(tester, _key('room-mask-tool-add'));
      await _dot(tester, container);
      final draft = container.read(roomMaskProvider).draft;
      await _tap(tester, _key('room-mask-restore'));
      await tester.binding.handlePopRoute();
      await _frames(tester);
      expect(container.read(roomMaskProvider).draft, same(draft));
      await _tap(tester, _key('room-mask-restore'));
      await _tap(tester, find.text('Cancel'));
      expect(container.read(roomMaskProvider).draft, same(draft));
      await _tap(tester, _key('room-mask-restore'));
      await _tap(tester, _key('confirm-room-mask-restore'));
      final restored = container.read(roomMaskProvider).draft!;
      expect(restored.masks.labels, List<int>.filled(100, 0));
      expect(restored.maskRevision, draft!.maskRevision + 1);
      expect(restored.history.canUndo, isFalse);
    },
  );

  testWidgets(
    'stale restore and replace confirmations cannot mutate newer draft revisions',
    (tester) async {
      final picker = _Picker();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        segmenter: segmenter,
      );
      await _open(tester);
      await _ready(tester, segmenter);
      final controller = container.read(roomMaskProvider.notifier);
      for (final action in ['restore', 'replace']) {
        await _tap(
          tester,
          action == 'restore'
              ? _key('room-mask-restore')
              : _key('room-mask-gallery'),
        );
        final old = container.read(roomMaskProvider).draft!;
        controller.restoreAiMasks(
          photoId: old.photoId,
          maskRevision: old.maskRevision,
        );
        final newer = container.read(roomMaskProvider).draft;
        await _tap(tester, _key('confirm-room-mask-$action'));
        expect(container.read(roomMaskProvider).draft, same(newer));
        expect(picker.sources.length, 1);
      }
    },
  );

  testWidgets(
    'replacement cancellation and failure retain old edits until explicit Return',
    (tester) async {
      final picker = _Picker();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        segmenter: segmenter,
      );
      await _open(tester);
      await _ready(tester, segmenter);
      await _tap(tester, _key('room-mask-tool-add'));
      await _dot(tester, container);
      final old = container.read(roomMaskProvider).draft!;
      await _tap(tester, _key('room-mask-camera'));
      await _tap(tester, find.text('Cancel'));
      expect(picker.sources.length, 1);
      picker.next = null;
      await _tap(tester, _key('room-mask-camera'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      expect(container.read(roomMaskProvider).draft, same(old));
      picker.next = _photo(50);
      await _tap(tester, _key('room-mask-gallery'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      segmenter.requests.last.fail();
      await _frames(tester);
      expect(container.read(roomMaskProvider).draft, same(old));
      expect(find.byType(RoomMaskViewport), findsNothing);
      await _tap(tester, find.text('Return to previous masks'));
      expect(container.read(roomMaskProvider).draft, same(old));
      expect(find.byType(RoomMaskViewport), findsOneWidget);
      await _tap(tester, _key('room-mask-gallery'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      segmenter.requests.last.succeed(2);
      await _frames(tester);
      final replacement = container.read(roomMaskProvider).draft!;
      expect(replacement.photoId, isNot(old.photoId));
      expect(replacement.maskRevision, 0);
      expect(replacement.history.canUndo, isFalse);
      expect(replacement.masks.labels, List<int>.filled(100, 2));
    },
  );

  testWidgets(
    'late picker output while another root route is active remains pending without route theft',
    (tester) async {
      final picker = _Picker()..gate = Completer<void>();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        segmenter: segmenter,
      );
      await _open(tester);
      await _tap(tester, _key('room-mask-gallery'));
      final router = container.read(appRouterProvider);
      router.push<void>('/welcome');
      await _frames(tester);
      picker.gate!.complete();
      await _frames(tester);
      expect(router.state.uri.path, '/welcome');
      expect(segmenter.requests, isEmpty);
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt,
        isNotNull,
      );
      router.pop();
      await _frames(tester);
      await _tap(tester, _key('room-mask-continue-import'));
      segmenter.requests.single.succeed();
      await _frames(tester);
      expect(container.read(photoAcquisitionProvider).pendingReceipt, isNull);
      expect(container.read(roomMaskProvider).canEdit, isTrue);
    },
  );

  testWidgets(
    'hidden during durable claim stages candidate for explicit Analyze this photo',
    (tester) async {
      final store = _Store();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        store: store,
        segmenter: segmenter,
      );
      await _open(tester);
      store.clearGate = Completer<void>();
      await _tap(tester, _key('room-mask-gallery'));
      final router = container.read(appRouterProvider);
      router.push<void>('/welcome');
      await _frames(tester);
      store.clearGate!.complete();
      await _frames(tester);
      expect(segmenter.requests, isEmpty);
      expect(container.read(roomMaskProvider).candidate, isNotNull);
      router.pop();
      await _frames(tester);
      await _expectCandidate(tester, 100);
      await _tap(tester, _key('room-mask-continue-analysis'));
      segmenter.requests.single.succeed();
      await _frames(tester);
      expect(container.read(roomMaskProvider).canEdit, isTrue);
    },
  );

  testWidgets(
    'unknown recovered receipt requires an explicit Room or Capture choice',
    (tester) async {
      final picker = _Picker()..recovered = _photo();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        segmenter: segmenter,
      );
      await _open(tester);
      expect(segmenter.requests, isEmpty);
      expect(find.text('Continue in Capture'), findsOneWidget);
      expect(_key('room-mask-continue-import'), findsOneWidget);
      await _tap(tester, find.text('Continue in Capture'));
      expect(container.read(appRouterProvider).state.uri.path, '/capture');
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt,
        isNotNull,
      );
      await _open(tester);
      await _tap(tester, _key('room-mask-continue-import'));
      segmenter.requests.single.succeed();
      await _frames(tester);
      expect(container.read(roomMaskProvider).canEdit, isTrue);
    },
  );

  testWidgets(
    'direct masks route is guarded by onboarding and Back retains the session draft',
    (tester) async {
      final picker = _Picker();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        segmenter: segmenter,
        preferences: const AppPreferences(),
      );
      final router = container.read(appRouterProvider);
      router.go('/room/masks');
      await _frames(tester);
      expect(router.state.uri.path, '/onboarding');
      expect(picker.recoveries, 0);
      expect(picker.sources, isEmpty);
      expect(segmenter.requests, isEmpty);
      await _tap(tester, find.text('Skip'));
      router.go('/room/masks');
      await _frames(tester);
      await _ready(tester, segmenter);
      final draft = container.read(roomMaskProvider).draft;
      await _tap(tester, find.byTooltip('Back'));
      expect(router.state.uri.path, '/rooms');
      final masks = _key('open-room-masks');
      expect(masks, findsOneWidget);
      await tester.tap(masks);
      await _frames(tester);
      expect(container.read(roomMaskProvider).draft, same(draft));
    },
  );

  testWidgets(
    'zoom survives revisions layer theme and failed replacement; only accepted restore or new photo resets it',
    (tester) async {
      final picker = _Picker();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        segmenter: segmenter,
      );
      await _open(tester);
      await _ready(tester, segmenter);
      tester.widget<Slider>(_key('room-mask-brush')).onChanged!(.1);
      await _frames(tester);
      await _zoom(tester);
      await _tap(tester, _key('room-mask-tool-add'));
      await _dot(tester, container, x: .25);
      expect(container.read(roomMaskProvider).draft!.masks.labels[53], 1);
      expect(container.read(roomMaskProvider).draft!.masks.labels[52], 0);
      await _tap(tester, _key('room-mask-gallery'));
      await tester.binding.handlePopRoute();
      await _frames(tester);
      await _tap(tester, _key('room-mask-layer-floor'));
      container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
      await _frames(tester);
      await _dot(tester, container, x: .75);
      expect(container.read(roomMaskProvider).draft!.masks.labels[56], 3);
      expect(container.read(roomMaskProvider).draft!.masks.labels[57], 0);
      await _tap(tester, _key('room-mask-gallery'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      segmenter.requests.last.fail();
      await _frames(tester);
      await _tap(tester, find.text('Return to previous masks'));
      await _tap(tester, _key('room-mask-layer-wall'));
      await _dot(tester, container, x: .75);
      expect(container.read(roomMaskProvider).draft!.masks.labels[56], 1);
      await _tap(tester, _key('room-mask-restore'));
      await _tap(tester, _key('confirm-room-mask-restore'));
      await _dot(tester, container, x: .25);
      expect(container.read(roomMaskProvider).draft!.masks.labels[52], 1);
      expect(container.read(roomMaskProvider).draft!.masks.labels[53], 0);
      await _zoom(tester);
      await _tap(tester, _key('room-mask-tool-add'));
      picker.next = _photo(50);
      await _tap(tester, _key('room-mask-camera'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      segmenter.requests.last.succeed();
      await _frames(tester);
      expect(container.read(roomMaskProvider).draft!.history.canUndo, isFalse);
      await _dot(tester, container, x: .25);
      expect(container.read(roomMaskProvider).draft!.masks.labels[52], 1);
      expect(container.read(roomMaskProvider).draft!.masks.labels[53], 0);
    },
  );

  testWidgets(
    'captured viewport callbacks cannot edit a newer revision or equal-sized replacement',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _ready(tester, segmenter);
      await _tap(tester, _key('room-mask-tool-add'));
      final oldCallback = tester
          .widget<RoomMaskViewport>(find.byType(RoomMaskViewport))
          .onStroke;
      final stroke = MaskStroke(
        layer: RoomLayer.wall,
        mode: MaskEditMode.add,
        segments: [
          [MaskPoint(.55, .55)],
        ],
        diameterFraction: .05,
      );
      await _tap(tester, _key('room-mask-restore'));
      await _tap(tester, _key('confirm-room-mask-restore'));
      final restored = container.read(roomMaskProvider).draft;
      oldCallback(stroke);
      await _worker(tester, container);
      expect(container.read(roomMaskProvider).draft, same(restored));
      await _tap(tester, _key('room-mask-gallery'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      segmenter.requests.last.succeed();
      await _frames(tester);
      final replacement = container.read(roomMaskProvider).draft;
      oldCallback(stroke);
      await _worker(tester, container);
      expect(container.read(roomMaskProvider).draft, same(replacement));
      expect(replacement!.masks.labels, List<int>.filled(100, 0));
    },
  );

  testWidgets(
    'cancel analysis retains the old draft and ignores late completion',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await _open(tester);
      await _ready(tester, segmenter, label: 1);
      final old = container.read(roomMaskProvider).draft;
      await _tap(tester, _key('room-mask-gallery'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      await _tap(tester, find.text('Cancel analysis'));
      expect(container.read(roomMaskProvider).draft, same(old));
      segmenter.requests.last.succeed(3);
      await _frames(tester);
      expect(container.read(roomMaskProvider).draft, same(old));
      expect(container.read(roomMaskProvider).canEdit, isTrue);
    },
  );

  testWidgets(
    'accepted root dialog result while another route owns the screen is ignored',
    (tester) async {
      final picker = _Picker();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        segmenter: segmenter,
      );
      await _open(tester);
      await _ready(tester, segmenter);
      final router = container.read(appRouterProvider);
      for (final action in ['restore', 'replace']) {
        final old = container.read(roomMaskProvider).draft;
        await _tap(
          tester,
          action == 'restore'
              ? _key('room-mask-restore')
              : _key('room-mask-gallery'),
        );
        final dialogContext = tester.element(_key('confirm-room-mask-$action'));
        final dialog = ModalRoute.of(dialogContext)!;
        final navigator = Navigator.of(dialogContext, rootNavigator: true);
        router.push<void>('/welcome');
        await _frames(tester);
        navigator.removeRoute(dialog, true);
        await _frames(tester);
        expect(router.state.uri.path, '/welcome');
        expect(container.read(roomMaskProvider).draft, same(old));
        expect(picker.sources.length, 1);
        router.pop();
        await _frames(tester);
      }
    },
  );

  testWidgets(
    'Use in Room sets the illustrated shade while masks Lab and saved history survive',
    (tester) async {
      final segmenter = _Segmenter();
      final container = await _launch(tester, segmenter: segmenter);
      await container.read(colorHistoryProvider.future);
      await container
          .read(colorHistoryProvider.notifier)
          .saveColor(
            RgbColor.fromHex('#B2A4D4'),
            name: 'Lilac',
            source: ColorSource.lab,
          );
      final history = container.read(colorHistoryProvider).requireValue;
      final learn = _key('nav-learn');
      expect(learn, findsOneWidget);
      await tester.tap(learn);
      await _frames(tester);
      final openLab = _key('learn-open-lab');
      expect(openLab, findsOneWidget);
      await tester.ensureVisible(openLab);
      await tester.tap(openLab);
      await _frames(tester);
      tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(123);
      await _frames(tester);
      final labHex = tester
          .widget<ColorSwatchTile>(find.byType(ColorSwatchTile))
          .hex;
      await _open(tester);
      await _ready(tester, segmenter);
      await _tap(tester, _key('room-mask-tool-add'));
      await _dot(tester, container);
      final draft = container.read(roomMaskProvider).draft;
      await _tap(tester, find.byTooltip('Back'));
      expect(learn, findsOneWidget);
      await tester.tap(learn);
      await _frames(tester);
      expect(find.text('Open color mixer'), findsOneWidget);
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        labHex,
      );
      await _tap(tester, find.byType(ColorSwatchTile));
      await _tap(tester, find.text('Use in Room'));
      expect(
        container.read(appRouterProvider).state.uri.path,
        '/room/illustrated/study',
      );
      expect(find.byType(IllustratedRoomScreen), findsOneWidget);
      expect(container.read(roomColorProvider).hex, labHex);
      final study = container.read(illustratedRoomProvider).draftFor('study')!;
      expect(study.colors!.wall.hex, labHex);
      expect(study.colors!.ceiling.hex, '#F8F4EB');
      expect(study.colors!.floor.hex, '#C6AC84');
      expect(study.colors!.furniture.hex, '#654A39');
      expect(container.read(roomMaskProvider).draft, same(draft));
      expect(container.read(colorHistoryProvider).requireValue, history);
      await _tap(tester, _key('room-editor-back'));
      expect(find.text('Keep this draft?'), findsOneWidget);
      await _tap(tester, find.text('Keep draft'));
      final rooms = _key('nav-rooms');
      expect(rooms, findsOneWidget);
      await tester.tap(rooms);
      await _frames(tester);
      final masks = _key('open-room-masks');
      expect(masks, findsOneWidget);
      await tester.tap(masks);
      await _frames(tester);
      expect(container.read(roomMaskProvider).draft, same(draft));
    },
  );

  testWidgets(
    'permission failure replacing a photo retains masks and safe recoverable copy',
    (tester) async {
      final picker = _Picker();
      final segmenter = _Segmenter();
      final container = await _launch(
        tester,
        picker: picker,
        segmenter: segmenter,
      );
      await _open(tester);
      await _ready(tester, segmenter);
      final draft = container.read(roomMaskProvider).draft;
      picker.failure = const PhotoPickFailure(
        PhotoPickFailureKind.permissionDenied,
      );
      await _tap(tester, _key('room-mask-camera'));
      await _tap(tester, _key('confirm-room-mask-replace'));
      expect(container.read(roomMaskProvider).draft, same(draft));
      expect(container.read(roomMaskProvider).canEdit, isFalse);
      expect(find.byType(RoomMaskViewport), findsNothing);
      await _tap(tester, find.text('Return to previous masks'));
      expect(container.read(roomMaskProvider).draft, same(draft));
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      '360dp doubled text ${theme.name} keeps new-photo entry and dialogs usable',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final semantics = tester.ensureSemantics();
        final segmenter = _Segmenter();
        await _launch(
          tester,
          segmenter: segmenter,
          preferences: AppPreferences(
            onboardingCompleted: true,
            themeMode: theme,
          ),
        );
        final rooms = _key('nav-rooms');
        expect(rooms, findsOneWidget);
        await tester.tap(rooms);
        await _frames(tester);
        final roomScreen = _key('screen-Rooms');
        expect(roomScreen, findsOneWidget);
        expect(
          _key('open-room-masks').hitTestable(),
          findsOneWidget,
          reason:
              'entry ${tester.getRect(_key('open-room-masks'))}, room ${tester.getRect(roomScreen)}',
        );
        await tester.tap(_key('open-room-masks'));
        await _frames(tester);
        expect(_key('room-mask-gallery').hitTestable(), findsOneWidget);
        expect(_key('room-mask-camera').hitTestable(), findsOneWidget);
        await _tap(tester, _key('room-mask-gallery'));
        await _expectCandidate(tester, 100);
        await tester.ensureVisible(_key('room-mask-candidate-photo'));
        expect(_key('room-mask-candidate-photo').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        segmenter.requests.single.succeed();
        await _frames(tester);
        for (final key in [
          'room-mask-layer-wall',
          'room-mask-tool-add',
          'room-mask-show-original',
          'room-mask-undo',
          'room-mask-restore',
        ]) {
          expect(tester.getSize(_key(key)).height, greaterThanOrEqualTo(48));
        }
        await _tap(tester, _key('room-mask-fullscreen'));
        expect(
          _key('room-mask-fullscreen-close').hitTestable(),
          findsOneWidget,
        );
        expect(
          tester.getSize(_key('room-mask-fullscreen-viewport')).height,
          greaterThan(300),
        );
        for (final tool in ['add', 'erase', 'move']) {
          await _tap(tester, _key('room-mask-fullscreen-tool-$tool'));
        }
        await _tap(tester, _key('room-mask-fullscreen-zoom-in'));
        await _tap(tester, _key('room-mask-fullscreen-fit'));
        expect(tester.takeException(), isNull);
        await _tap(tester, _key('room-mask-fullscreen-close'));
        for (final action in ['restore', 'replace']) {
          await _tap(
            tester,
            action == 'restore'
                ? _key('room-mask-restore')
                : _key('room-mask-gallery'),
          );
          final confirm = _key('confirm-room-mask-$action');
          expect(confirm.hitTestable(), findsOneWidget);
          expect(tester.getSize(confirm).height, greaterThanOrEqualTo(48));
          await _tap(tester, find.text('Cancel'));
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
