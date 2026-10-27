import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/widgets/buttons.dart';
import 'package:color_lab/data/files/file_room_project_repository.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/application/camera_session.dart';
import 'package:color_lab/features/picker/application/photo_acquisition_controller.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/application/photo_processor.dart';
import 'package:color_lab/features/picker/domain/acquisition_intent_store.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/room_studio/application/room_export_metadata_verifier.dart';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_model_download_providers.dart';
import 'package:color_lab/features/room_studio/application/room_model_setup_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_provider.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_scheduler.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_service.dart';
import 'package:color_lab/features/room_studio/application/room_variant_controller.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_viewport.dart';
import 'package:color_lab/features/room_studio/presentation/room_project_actions.dart';
import 'package:color_lab/features/room_studio/recolor/room_photo_recolorer.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'package:color_lab/features/room_studio/segmentation/room_segmentation_service.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../support/controlled_room_recolor_worker.dart';
import '../../support/in_memory_acquisition_intent_store.dart';
import '../../support/in_memory_app_preferences_repository.dart';
import '../../support/in_memory_color_history_repository.dart';

Finder _key(String value) => find.byKey(ValueKey(value));

// Start disk/compute work in the real event loop, but keep pumping any earlier
// fake-async controller continuations while awaiting it. Never await a queued
// fake-async save inside runAsync: that would starve its queue continuation.
Future<T?> _io<T>(WidgetTester tester, Future<T> Function() action) async {
  T? result;
  Object? error;
  StackTrace? stack;
  var done = false;
  await tester.runAsync(() async {
    unawaited(
      action().then(
        (value) {
          result = value;
          done = true;
        },
        onError: (Object e, StackTrace s) {
          error = e;
          stack = s;
          done = true;
        },
      ),
    );
  });
  await _until(tester, () => done);
  if (error != null) Error.throwWithStackTrace(error!, stack!);
  return result;
}

Future<void> _until(WidgetTester tester, bool Function() predicate) async {
  for (var i = 0; i < 1200; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (predicate()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Bounded milestone predicate did not become true');
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _frames(tester);
}

class _NativePicker extends ImagePicker {
  XFile? file;
  int calls = 0;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls++;
    expect(source, ImageSource.gallery);
    expect(requestFullMetadata, isFalse);
    expect((maxWidth, maxHeight), (2048, 2048));
    return file;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async => LostDataResponse.empty();
}

class _AnalysisBoundary implements RoomSegmentationService {
  int calls = 0;
  bool fail = true;
  PreparedPhoto? prepared;
  @override
  Future<RoomSegmentationResult> analyze({
    required String photoId,
    required PreparedPhoto photo,
  }) async {
    calls++;
    prepared = photo;
    if (fail) {
      throw const RoomSegmentationException(
        RoomSegmentationFailureKind.modelUnavailable,
      );
    }
    return RoomSegmentationResult(
      photoId: photoId,
      masks: MaskBitmap(
        width: photo.width,
        height: photo.height,
        labels: Uint8List(photo.width * photo.height),
      ),
    );
  }

  @override
  Future<void> close() async {}
}

class _PointerBoundary extends RoomProjectFileIo {
  bool fail = false;
  int commits = 0;
  @override
  Future<void> renameFile(String source, String destination) async {
    if (destination.endsWith('/current')) {
      if (fail) throw const FileSystemException('injected pointer failure');
      commits++;
    }
    await super.renameFile(source, destination);
  }
}

class _ReceiptStore extends InMemoryAcquisitionIntentStore {
  bool failClear = false;
  @override
  Future<void> clear({bool discardUntrusted = false}) async {
    if (failClear) throw const AcquisitionStorageException();
    await super.clear(discardUntrusted: discardUntrusted);
  }
}

/// A fresh container/router and disk owner each time; setup is never overridden.
class _App {
  _App(
    this.root,
    this.repository,
    this.models,
    this.container,
    this.picker,
    this.analysis,
    this.preferences,
    this.receipts,
  );
  final Directory root;
  final FileRoomProjectRepository repository;
  final RoomModelStore models;
  final ProviderContainer container;
  final _NativePicker picker;
  final _AnalysisBoundary analysis;
  final InMemoryAppPreferencesRepository preferences;
  final _ReceiptStore receipts;
  int networkCalls = 0;
  bool disposed = false;
  RoomProjectSession get session => container.read(roomProjectSessionProvider)!;
  Future<void> saved(WidgetTester tester) => _until(tester, () {
    final current = container.read(roomProjectSessionProvider);
    if (current?.saveStatus == RoomProjectSaveStatus.failed) {
      fail('Save failed: ${current?.saveError}');
    }
    return current?.saveStatus == RoomProjectSaveStatus.saved;
  });
  Future<void> preview(WidgetTester tester) => _until(tester, () {
    final frame = container.read(roomRecolorPreviewProvider);
    final key = roomActiveRecolorKey(
      container.read(roomProjectSessionProvider),
    );
    return key != null && !frame.isLoading && frame.value?.key == key;
  });
  Future<void> dispose(WidgetTester tester) async {
    if (disposed) return;
    disposed = true;
    await tester.pumpWidget(const SizedBox());
    var drained = false;
    unawaited(
      container
          .read(roomMaskProvider.notifier)
          .closeProject()
          .then((_) => drained = true),
    );
    await _until(tester, () => drained);
    await container.read(roomRecolorSchedulerProvider).close();
    container.dispose();
    await _io(tester, () async {
      await repository.close();
      await models.close();
      await receipts.close();
    });
    await tester.pump();
  }
}

Future<_App> _mount(
  WidgetTester tester,
  Directory root, {
  bool cached = false,
  bool onboarding = true,
  _PointerBoundary? io,
  _NativePicker? picker,
  _AnalysisBoundary? analysis,
  RoomImageExportService? exporter,
  _ReceiptStore? receipts,
}) async {
  final native = picker ?? _NativePicker();
  final boundary = analysis ?? _AnalysisBoundary();
  final preferences = InMemoryAppPreferencesRepository(
    initial: AppPreferences(onboardingCompleted: onboarding),
  );
  final receiptStore = receipts ?? _ReceiptStore();
  late _App app;
  final artifacts = [
    for (final pair in [
      ('room_seg.tflite', 'hello'),
      ('room_depth.tflite', 'world'),
    ])
      RoomModelArtifact(
        name: pair.$1,
        url: 'https://invalid.example/${pair.$1}',
        bytes: 5,
        sha256: sha256.convert(utf8.encode(pair.$2)).toString(),
      ),
  ];
  final models = RoomModelStore(
    directory: () async => root,
    artifacts: cached ? artifacts : roomModelArtifacts,
    clientFactory: () {
      app.networkCalls++;
      throw StateError('Network forbidden');
    },
  );
  final repo = (await _io(tester, () async {
    if (cached) {
      for (var i = 0; i < artifacts.length; i++) {
        final artifact = artifacts[i];
        final file = File(
          '${root.path}/room_models/${artifact.sha256}/${artifact.name}',
        );
        if (!await file.exists()) {
          await file.parent.create(recursive: true);
          await file.writeAsString(i == 0 ? 'hello' : 'world', flush: true);
        }
      }
    }
    return FileRoomProjectRepository.open(
      directory: root.path,
      io: io ?? const RoomProjectFileIo(),
    );
  }))!;
  var ids = 0;
  final c = ProviderContainer(
    overrides: [
      roomProjectRepositoryProvider.overrideWith((ref) async => repo),
      roomProjectIdFactoryProvider.overrideWithValue(
        () => 'milestone-${++ids}',
      ),
      roomModelStoreProvider.overrideWithValue(models),
      acquisitionIntentStoreProvider.overrideWith((ref) async => receiptStore),
      appPreferencesRepositoryProvider.overrideWith((ref) async => preferences),
      colorHistoryRepositoryProvider.overrideWith(
        (ref) async => InMemoryColorHistoryRepository(),
      ),
      colorNamerProvider.overrideWith((ref) async => ColorNamer([])),
      photoPickerServiceProvider.overrideWithValue(
        PluginPhotoPickerService(
          processor: const IsolatePhotoProcessor(),
          picker: native,
          platform: TargetPlatform.android,
        ),
      ),
      roomSegmentationServiceProvider.overrideWithValue(boundary),
      roomRecolorWorkerFactoryProvider.overrideWithValue(
        () => CallbackRecolorWorker(
          (input) async => recolorRoomPhoto(
            key: input.key,
            photo: input.photo,
            masks: input.masks,
            colors: input.colors,
          ),
        ),
      ),
      if (exporter != null)
        roomImageExportServiceProvider.overrideWithValue(exporter),
      cameraSessionFactoryProvider.overrideWithValue(
        () => throw StateError('No live camera in Room'),
      ),
    ],
  );
  app = _App(
    root,
    repo,
    models,
    c,
    native,
    boundary,
    preferences,
    receiptStore,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: c, child: const ColorLabApp()),
  );
  await _until(
    tester,
    () => onboarding
        ? _key('nav-rooms').evaluate().isNotEmpty
        : find.text('Skip').evaluate().isNotEmpty,
  );
  await _frames(tester);
  return app;
}

Future<void> _cachedEditor(WidgetTester tester, _App app) async {
  await _tap(tester, _key('nav-rooms'));
  await _tap(tester, _key('open-room-masks'));
  await _until(
    tester,
    () =>
        app.container.read(roomModelSetupProvider).availability ==
        RoomModelAvailability.ready,
  );
  expect(app.container.read(roomModelSetupProvider).canEnter, isFalse);
  expect(app.picker.calls, 0);
  expect(app.analysis.calls, 0);
  await _tap(tester, _key('room-setup-continue'));
  await _until(tester, () => _key('room-mask-gallery').evaluate().isNotEmpty);
  expect(app.container.read(roomModelSetupProvider).canEnter, isTrue);
}

Future<File> _source(WidgetTester tester, Directory root) async {
  final image = img.Image(width: 12, height: 8, numChannels: 3);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 12; x++) {
      image.setPixelRgb(x, y, 20 + x * 15, 30 + y * 20, 40 + (x + y) * 8);
    }
  }
  image.exif.imageIfd.orientation = 3;
  image.textData = {'Comment': 'synthetic source metadata'};
  final source = File('${root.path}/source.jpg');
  await _io(
    tester,
    () => source.writeAsBytes(img.encodeJpg(image, quality: 100), flush: true),
  );
  return source;
}

Future<Map<String, String>> _hashes(Directory root) async => {
  await for (final item in root.list(recursive: true, followLinks: false))
    if (item is File)
      item.path.substring(root.path.length): sha256
          .convert(await item.readAsBytes())
          .toString(),
};
Future<void> _edit(WidgetTester tester, _App app, double x) async {
  final editor = app.container.read(roomMaskProvider.notifier);
  editor.setShowOverlay(true);
  editor.setTool(RoomMaskTool.add);
  editor.setBrushFraction(.05);
  await _frames(tester);
  final viewport = find.byType(RoomMaskViewport);
  await tester.ensureVisible(viewport);
  final rect = tester.getRect(viewport);
  // Source aspect ratio 12:8, centered contain transform.
  final scale = rect.width / 12 < rect.height / 8
      ? rect.width / 12
      : rect.height / 8;
  await tester.tapAt(rect.center + Offset((x - 6) * scale, .5 * scale));
  await _until(tester, () => !app.container.read(roomMaskProvider).editBusy);
}

void main() {
  testWidgets(
    'fresh empty offline install defers real-photo setup and keeps Illustrated Rooms reachable',
    (tester) async {
      final root = (await _io(
        tester,
        () => Directory.systemTemp.createTemp('milestone-empty-'),
      ))!;
      final app = await _mount(tester, root, onboarding: false);
      try {
        expect(
          (await _io(tester, () => app.repository.listSnapshot()))!.records,
          isEmpty,
        );
        await _tap(tester, find.text('Skip'));
        expect(app.preferences.value.onboardingCompleted, isTrue);
        await _tap(tester, _key('nav-rooms'));
        await _tap(tester, _key('open-illustrated-gallery'));
        expect(
          app.container.read(appRouterProvider).state.uri.path,
          '/room/illustrated',
        );
        expect(_key('screen-IllustratedRoomGallery'), findsOneWidget);
        await _tap(tester, _key('room-template-bedroom'));
        expect(
          app.container.read(appRouterProvider).state.uri.path,
          '/room/illustrated/bedroom',
        );
        app.container.read(appRouterProvider).pop();
        await _frames(tester);
        app.container.read(appRouterProvider).pop();
        await _frames(tester);
        await _tap(tester, _key('open-room-masks'));
        await _until(
          tester,
          () =>
              app.container.read(roomModelSetupProvider).availability ==
              RoomModelAvailability.notInstalled,
        );
        expect(find.textContaining('68,316,288 bytes'), findsOneWidget);
        expect(find.textContaining('65.2 MiB'), findsOneWidget);
        await _tap(tester, _key('room-setup-later'));
        expect(app.container.read(appRouterProvider).state.uri.path, '/rooms');
        await _tap(tester, _key('nav-learn'));
        await _tap(tester, _key('nav-home'));
        expect(app.networkCalls, 0);
        expect(app.picker.calls, 0);
        expect(app.analysis.calls, 0);
        expect(
          await _io(
            tester,
            () => Directory('${root.path}/room_models').exists(),
          ),
          isFalse,
        );
      } finally {
        await app.dispose(tester);
        await _io(tester, () => root.delete(recursive: true));
      }
    },
  );

  testWidgets(
    'acquisition storage retry clears only its error and a second action cannot retry project save',
    (tester) async {
      final root = (await _io(
        tester,
        () => Directory.systemTemp.createTemp('milestone-receipt-'),
      ))!;
      final io = _PointerBoundary();
      final source = await _source(tester, root);
      final receipts = _ReceiptStore();
      final app = await _mount(
        tester,
        root,
        cached: true,
        io: io,
        receipts: receipts,
        picker: _NativePicker()..file = XFile(source.path),
      );
      try {
        await _cachedEditor(tester, app);
        await _tap(tester, _key('room-mask-gallery'));
        await _until(
          tester,
          () => _key('room-mask-manual').evaluate().isNotEmpty,
        );
        await _tap(tester, _key('room-mask-manual'));
        await app.saved(tester);
        io.fail = true;
        app.container
            .read(roomMaskProvider.notifier)
            .setLayerColor(RoomLayer.wall, RgbColor.fromHex('#CC8844'));
        await _until(
          tester,
          () => app.session.saveStatus == RoomProjectSaveStatus.failed,
        );
        final previous = app.session.visible;
        final committed = io.commits;
        receipts.failClear = true;
        await _tap(tester, _key('room-mask-gallery'));
        await _tap(tester, _key('confirm-room-mask-replace'));
        await _until(
          tester,
          () =>
              app.container.read(photoAcquisitionProvider).phase ==
              AcquisitionPhase.storageError,
        );
        expect(
          app.container.read(roomMaskProvider).failure,
          RoomMaskFailureKind.storage,
        );
        final receipt = app.container
            .read(photoAcquisitionProvider)
            .pendingReceipt!;
        final staleAction = tester
            .widget<PrimaryButton>(_key('room-photo-recovery'))
            .onPressed!;
        receipts.failClear = false;
        io.fail = false;
        await _tap(tester, _key('room-photo-recovery'));
        await _until(
          tester,
          () =>
              app.container.read(photoAcquisitionProvider).phase ==
              AcquisitionPhase.ready,
        );
        expect(app.container.read(roomMaskProvider).failure, isNull);
        expect(_key('room-photo-recovery'), findsNothing);
        expect(
          app.container.read(photoAcquisitionProvider).pendingReceipt,
          same(receipt),
        );
        expect(app.container.read(roomMaskProvider).draft, same(previous));
        expect(app.session.visible, same(previous));
        expect(app.session.saveStatus, RoomProjectSaveStatus.failed);
        staleAction();
        await _frames(tester);
        expect(io.commits, committed);
        expect(app.session.saveStatus, RoomProjectSaveStatus.failed);
        expect(app.picker.calls, 2);
        expect(app.analysis.calls, 1);
      } finally {
        await app.dispose(tester);
        await _io(tester, () => root.delete(recursive: true));
      }
    },
  );

  testWidgets(
    'cached manual project owns edits variants reopen export and delete on real disk',
    (tester) async {
      final root = (await _io(
        tester,
        () => Directory.systemTemp.createTemp('milestone-project-'),
      ))!;
      final io = _PointerBoundary();
      final source = await _source(tester, root);
      final sourceBytes = (await _io(tester, source.readAsBytes))!;
      final picker = _NativePicker()..file = XFile(source.path);
      final temp = Directory('${root.path}/export-temp');
      final outside = Directory('${root.path}/external-exports');
      await _io(tester, () async {
        await temp.create();
        await outside.create();
      });
      final exporter = PlatformRoomImageExportService(
        gallery: GalRoomGalleryWriter(
          temporaryRoot: () async => temp,
          platform: TargetPlatform.android,
        ),
        temporaryRoot: () async => temp,
      );
      var app = await _mount(
        tester,
        root,
        cached: true,
        picker: picker,
        io: io,
        exporter: exporter,
      );
      try {
        await _cachedEditor(tester, app);
        final modelHashes = (await _io(
          tester,
          () => _hashes(Directory('${root.path}/room_models')),
        ))!;
        await _tap(tester, _key('room-mask-gallery'));
        await _until(
          tester,
          () =>
              app.container.read(roomMaskProvider).failure ==
              RoomMaskFailureKind.modelUnavailable,
        );
        final candidate = app.container.read(roomMaskProvider).candidate!;
        expect(candidate.photo, same(app.analysis.prepared));
        expect((candidate.photo.width, candidate.photo.height), (12, 8));
        final decodedSource = img.decodeJpg(sourceBytes)!;
        // JPEG decoder applies EXIF orientation 3 exactly once. Corners must swap.
        expect(candidate.photo.rgbaBytes[0], greaterThan(170));
        expect(candidate.photo.rgbaBytes[(96 - 1) * 4], lessThan(35));
        expect(
          candidate.photo.rgbaBytes,
          decodedSource.getBytes(order: img.ChannelOrder.rgba),
        );
        expect(
          img.decodePng(candidate.photo.previewBytes)!.textData,
          anyOf(isNull, isEmpty),
        );
        expect(await _io(tester, source.readAsBytes), sourceBytes);
        debugPrint(
          'Milestone source: ${sourceBytes.length} bytes; SHA-256 ${sha256.convert(sourceBytes)}; prepared ${candidate.photo.width}x${candidate.photo.height}; PNG ${candidate.photo.previewBytes.length} bytes; SHA-256 ${sha256.convert(candidate.photo.previewBytes)}',
        );
        await _tap(tester, _key('room-mask-manual'));
        await app.saved(tester);
        expect(app.session.visible.photo, same(candidate.photo));
        expect(app.session.visible.aiMasks.labels, Uint8List(96));
        expect(app.session.visible.masks.labels, Uint8List(96));
        final initial = app.session.durable!;
        final editor = app.container.read(roomMaskProvider.notifier);
        editor.setTool(RoomMaskTool.add);
        editor.setBrushFraction(.1);
        editor.setShowOverlay(false);
        editor.setShowOverlay(true);
        await _frames(tester);
        final viewport = find.byType(RoomMaskViewport);
        await tester.ensureVisible(viewport);
        final gesture = await tester.startGesture(tester.getCenter(viewport));
        await _frames(tester);
        expect(app.session.acknowledgedRevision, initial.revision);
        await gesture.cancel();
        await _frames(tester);
        expect(app.session.acknowledgedRevision, initial.revision);
        await _edit(tester, app, 4.5);
        await app.saved(tester);
        expect(
          app.session.visible.masks.labels.where((v) => v != 0),
          isNotEmpty,
        );
        var saved = app.session.durable!;
        expect(saved.revision, initial.revision + 1);
        expect(
          [
            for (var i = 0; i < 96; i++)
              if (saved.maskBytes[i] != 0) i,
          ],
          [52],
        );
        expect(saved.maskBytes, app.session.visible.masks.labels);
        expect(
          (await _io(
            tester,
            () => app.repository.read(saved.projectId),
          ))!.snapshot.maskBytes,
          saved.maskBytes,
        );
        final pointerFile = File(
          '${root.path}/room_projects/projects/${saved.projectId}/current',
        );
        final pointerBefore = (await _io(tester, pointerFile.readAsBytes))!;
        io.fail = true;
        await _edit(tester, app, 7.5);
        await _until(
          tester,
          () => app.session.saveStatus == RoomProjectSaveStatus.failed,
        );
        await _edit(tester, app, 9.5);
        final visibleFailed = app.session.visible;
        expect(await _io(tester, pointerFile.readAsBytes), pointerBefore);
        expect(
          (await _io(
            tester,
            () => app.repository.read(saved.projectId),
          ))!.snapshot.maskBytes,
          saved.maskBytes,
        );
        io.fail = false;
        final commitsBeforeRetry = io.commits;
        unawaited(
          app.container.read(roomProjectSessionProvider.notifier).retrySave(),
        );
        await app.saved(tester);
        expect(io.commits, commitsBeforeRetry + 1);
        expect(app.session.durable!.maskBytes, visibleFailed.masks.labels);
        expect(
          [
            for (var i = 0; i < 96; i++)
              if (visibleFailed.masks.labels[i] != 0) i,
          ],
          [52, 55, 57],
        );
        final beforeVariantsRevision = app.session.acknowledgedRevision;
        final assets = Directory(
          '${root.path}/room_projects/projects/${saved.projectId}/assets',
        );
        final assetsBefore = (await _io(tester, () => _hashes(assets)))!;
        final variants = app.container.read(roomVariantProvider.notifier);
        await _io(
          tester,
          () => variants.updateVariantColors(
            RoomLayerColors(wall: RgbColor.fromHex('#CC8844')),
          ),
        );
        final firstVariant = app.session.activeVariantId;
        await _io(tester, () => variants.createVariant('Cool'));
        final secondVariant = app.session.activeVariantId;
        await _io(
          tester,
          () => variants.updateVariantColors(
            RoomLayerColors(wall: RgbColor.fromHex('#2255AA')),
          ),
        );
        await _io(tester, () => variants.selectVariant(firstVariant));
        await _io(tester, () => variants.pinComparisonBaseline(secondVariant));
        await app.saved(tester);
        expect(await _io(tester, () => _hashes(assets)), assetsBefore);
        saved = app.session.durable!;
        expect(saved.revision, beforeVariantsRevision + 5);
        final expectedKey = RoomRecolorKey(
          projectId: saved.projectId,
          photoId: saved.photoId,
          maskRevision: saved.maskRevision,
          colorRevision: saved.colorRevision,
          variantId: saved.activeVariantId,
        );
        await app.preview(tester);
        expect(
          app.container.read(roomRecolorPreviewProvider).value!.key,
          expectedKey,
        );
        await _until(
          tester,
          () => _key('room-comparison-divider').evaluate().isNotEmpty,
        );
        final comparisonPointer = (await _io(tester, pointerFile.readAsBytes))!;
        await tester.ensureVisible(_key('room-comparison-divider'));
        await tester.drag(_key('room-comparison-divider'), const Offset(80, 0));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await _frames(tester);
        await _tap(tester, _key('room-recolor-before'));
        await _tap(tester, _key('room-recolor-after'));
        expect(await _io(tester, pointerFile.readAsBytes), comparisonPointer);
        expect(await _io(tester, () => _hashes(assets)), assetsBefore);
        // Background and covered retained route each reacquire current full-key work.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await _frames(tester);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await app.preview(tester);
        app.container.read(appRouterProvider).push('/rooms/projects');
        await _frames(tester);
        app.container.read(appRouterProvider).pop();
        await _frames(tester);
        await app.preview(tester);
        // Real library action/dialog recovery: Cancel, Retry save, reopen Rename.
        app.container.read(appRouterProvider).push('/rooms/projects');
        await _until(
          tester,
          () => _key(
            'room-project-menu-${saved.projectId}',
          ).evaluate().isNotEmpty,
        );
        await _tap(tester, _key('room-project-menu-${saved.projectId}'));
        await _tap(tester, _key('room-project-rename'));
        await tester.enterText(_key('room-project-name'), 'North corner');
        io.fail = true;
        await _tap(tester, _key('room-project-rename-confirm'));
        await _until(
          tester,
          () => app.session.saveStatus == RoomProjectSaveStatus.failed,
        );
        expect(app.session.name, saved.name);
        await _tap(tester, _key('room-project-rename-cancel'));
        io.fail = false;
        await _io(
          tester,
          () => app.container
              .read(roomProjectSessionProvider.notifier)
              .retrySave(),
        );
        await _until(
          tester,
          () =>
              app.container
                  .read(roomProjectsProvider)
                  .value
                  ?.records
                  .single
                  .acknowledgedRevision ==
              app.session.acknowledgedRevision,
        );
        await _tap(tester, _key('room-project-menu-${saved.projectId}'));
        await _tap(tester, _key('room-project-rename'));
        await tester.enterText(_key('room-project-name'), 'North corner');
        await _tap(tester, _key('room-project-rename-confirm'));
        await _until(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
        expect(app.session.name, 'North corner');
        final summary = (await _io(
          tester,
          () => app.repository.listSnapshot(),
        ))!.records.single;
        final duplicate = (await _io(
          tester,
          () => app.container
              .read(roomProjectActionsProvider.notifier)
              .duplicate(summary, name: 'Independent copy'),
        ))!;
        expect(duplicate.projectId, isNot(saved.projectId));
        expect(duplicate.photoId, isNot(saved.photoId));
        expect(duplicate.maskBytes, app.session.durable!.maskBytes);
        expect(duplicate.photoPng, saved.photoPng);
        expect(await _io(tester, () => _hashes(assets)), assetsBefore);
        saved = app.session.durable!;
        // Kill-style discard of a visible failed draft; only acknowledged data reopens.
        app.container.read(appRouterProvider).pop();
        await _frames(tester);
        io.fail = true;
        editor.setLayerColor(RoomLayer.wall, RgbColor.fromHex('#EE1199'));
        await _until(
          tester,
          () => app.session.saveStatus == RoomProjectSaveStatus.failed,
        );
        expect(app.session.visible.colors, isNot(saved.colors));
        await app.dispose(tester);
        io.fail = false;
        app = await _mount(
          tester,
          root,
          cached: true,
          io: io,
          exporter: exporter,
        );
        app.container
            .read(appRouterProvider)
            .go('/rooms/project/${saved.projectId}');
        await _until(
          tester,
          () =>
              app.container.read(roomProjectSessionProvider)?.projectId ==
              saved.projectId,
        );
        await app.preview(tester);
        final reopened = app.session;
        expect(reopened.visible.photoId, saved.photoId);
        expect(
          (reopened.visible.photo.width, reopened.visible.photo.height),
          (12, 8),
        );
        expect(reopened.visible.aiMasks.labels, saved.aiMaskBytes);
        expect(reopened.visible.masks.labels, saved.maskBytes);
        expect(reopened.visible.colors, saved.colors);
        expect(reopened.activeVariantId, saved.activeVariantId);
        expect(
          reopened.comparisonBaselineVariantId,
          saved.comparisonBaselineVariantId,
        );
        expect(
          roomActiveRecolorKey(reopened),
          RoomRecolorKey(
            projectId: saved.projectId,
            photoId: saved.photoId,
            maskRevision: saved.maskRevision,
            colorRevision: saved.colorRevision,
            variantId: saved.activeVariantId,
          ),
        );
        expect(reopened.visible.manualMode, isTrue);
        expect(
          find.text(
            'Manual mode: automatic masks are unavailable. Mark surfaces to preview colors, or retry analysis.',
          ),
          findsOneWidget,
        );
        expect(app.picker.calls, 0);
        expect(app.analysis.calls, 0);
        io.fail = true;
        app.container
            .read(roomMaskProvider.notifier)
            .setLayerColor(RoomLayer.wall, RgbColor.fromHex('#8844CC'));
        await _until(
          tester,
          () => app.session.saveStatus == RoomProjectSaveStatus.failed,
        );
        await app.preview(tester);
        expect(find.textContaining('unsaved'), findsWidgets);
        final exported = <Uint8List>[];
        var granted = false;
        // Locked share_plus represents dismissal with an empty result string.
        const shareResult = '';
        var interruptPermission = false;
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        Future<Object?> handoff(MethodCall call) async {
          final args = call.arguments as Map;
          if (call.method == 'requestAccess') {
            expect(args['toAlbum'], false);
            if (interruptPermission) {
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.paused,
              );
            }
            return granted;
          }
          final path = call.method == 'putImage'
              ? args['path'] as String
              : (args['paths'] as List).single as String;
          final bytes = await File(path).readAsBytes();
          final verified = const RoomExportMetadataVerifier().verify(bytes);
          expect((verified.width, verified.height), (12, 8));
          expect(
            File(path).uri.pathSegments.last,
            'tintatlas-room-${saved.photoId}.png',
          );
          final current = app.container.read(roomRecolorPreviewProvider).value!;
          expect(current.key, roomActiveRecolorKey(app.session));
          expect(bytes, current.pngBytes);
          final decoded = img.decodePng(bytes)!;
          expect(
            decoded.getBytes(order: img.ChannelOrder.rgba),
            current.rgbaBytes,
          );
          if (call.method == 'share') {
            expect(args['mimeTypes'], ['image/png']);
            expect(args['title'], contains('TintAtlas'));
            expect(args['subject'], args['title']);
            expect(args['originWidth'] as double, greaterThan(0));
            expect(args['originHeight'] as double, greaterThan(0));
          } else {
            expect(args['album'], isNull);
          }
          debugPrint(
            'Milestone ${call.method}: ${verified.width}x${verified.height}; ${bytes.length} bytes; SHA-256 ${sha256.convert(bytes)}',
          );
          exported.add(Uint8List.fromList(bytes));
          await File(
            '${outside.path}/export-${exported.length}.png',
          ).writeAsBytes(bytes, flush: true);
          return call.method == 'share' ? shareResult : null;
        }

        Object? terminalError;
        Future<Object?> checkedHandoff(MethodCall call) async {
          try {
            return await handoff(call);
          } catch (error) {
            terminalError = error;
            rethrow;
          }
        }

        messenger.setMockMethodCallHandler(
          const MethodChannel('gal'),
          checkedHandoff,
        );
        messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          checkedHandoff,
        );
        addTearDown(() {
          messenger.setMockMethodCallHandler(const MethodChannel('gal'), null);
          messenger.setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        });
        await _tap(tester, _key('room-recolor-save'));
        expect(exported, isEmpty);
        expect(app.session.saveStatus, RoomProjectSaveStatus.failed);
        granted = true;
        interruptPermission = true;
        await _tap(tester, _key('room-recolor-save'));
        expect(exported, isEmpty);
        interruptPermission = false;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await _frames(tester);
        await app.preview(tester);
        await _tap(tester, _key('room-recolor-save'));
        await _until(tester, () => exported.length == 1);
        await _until(
          tester,
          () =>
              tester
                  .widget<PrimaryButton>(_key('room-recolor-share'))
                  .onPressed !=
              null,
        );
        await _tap(tester, _key('room-recolor-share'));
        await _until(tester, () {
          if (terminalError != null) throw terminalError!;
          return exported.length == 2;
        });
        await _until(
          tester,
          () =>
              tester
                  .widget<PrimaryButton>(_key('room-recolor-share'))
                  .onPressed !=
              null,
        );
        expect(app.session.saveStatus, RoomProjectSaveStatus.failed);
        await _until(
          tester,
          () => _key('room-export-result').evaluate().isNotEmpty,
        );
        expect(find.text('Share sheet dismissed.'), findsOneWidget);
        expect(await _io(tester, () => temp.list().length), 0);
        final externalHashes = (await _io(tester, () => _hashes(outside)))!;
        final duplicateHashes = (await _io(
          tester,
          () => _hashes(
            Directory(
              '${root.path}/room_projects/projects/${duplicate.projectId}',
            ),
          ),
        ))!;
        app.container.read(appRouterProvider).go('/rooms/projects');
        await _until(
          tester,
          () => _key(
            'room-project-menu-${saved.projectId}',
          ).evaluate().isNotEmpty,
        );
        await _tap(tester, _key('room-project-menu-${saved.projectId}'));
        await _tap(tester, _key('room-project-delete'));
        await _tap(tester, _key('room-project-delete-cancel'));
        expect(
          await _io(tester, () => app.repository.read(saved.projectId)),
          isNotNull,
        );
        await _tap(tester, _key('room-project-menu-${saved.projectId}'));
        await _tap(tester, _key('room-project-delete'));
        await _tap(tester, _key('room-project-delete-confirm'));
        await _until(tester, () => find.byType(AlertDialog).evaluate().isEmpty);
        expect(
          await _io(tester, () => app.repository.read(saved.projectId)),
          isNull,
        );
        expect(await _io(tester, () => _hashes(outside)), externalHashes);
        expect(
          await _io(
            tester,
            () => _hashes(Directory('${root.path}/room_models')),
          ),
          modelHashes,
        );
        expect(
          await _io(
            tester,
            () => _hashes(
              Directory(
                '${root.path}/room_projects/projects/${duplicate.projectId}',
              ),
            ),
          ),
          duplicateHashes,
        );
        expect(await _io(tester, source.readAsBytes), sourceBytes);
        expect(app.networkCalls, 0);
        await app.dispose(tester);
        await _io(tester, () async {
          final finalOwner = await FileRoomProjectRepository.open(
            directory: root.path,
          );
          expect(await finalOwner.read(saved.projectId), isNull);
          expect(
            (await finalOwner.listSnapshot()).records.single.projectId,
            duplicate.projectId,
          );
          await finalOwner.close();
        });
      } finally {
        await app.dispose(tester);
        await _io(tester, () => root.delete(recursive: true));
      }
    },
  );
  testWidgets(
    'successful zero AI and manual fallback reopen with the same cause-neutral v1 notice',
    (tester) async {
      final root = (await _io(
        tester,
        () => Directory.systemTemp.createTemp('milestone-zero-ai-'),
      ))!;
      final source = await _source(tester, root);
      var app = await _mount(
        tester,
        root,
        cached: true,
        picker: _NativePicker()..file = XFile(source.path),
        analysis: _AnalysisBoundary()..fail = false,
      );
      try {
        await _cachedEditor(tester, app);
        await _tap(tester, _key('room-mask-gallery'));
        await app.saved(tester);
        expect(app.session.visible.manualMode, isFalse);
        expect(app.session.visible.aiMasks.labels, Uint8List(96));
        final snapshot = app.session.durable!;
        await app.dispose(tester);
        app = await _mount(tester, root);
        app.container
            .read(appRouterProvider)
            .go('/rooms/project/${snapshot.projectId}');
        await _until(
          tester,
          () =>
              app.container.read(roomProjectSessionProvider)?.projectId ==
              snapshot.projectId,
        );
        await app.preview(tester);
        expect(app.session.visible.manualMode, isTrue);
        expect(app.session.visible.aiMasks.labels, snapshot.aiMaskBytes);
        expect(app.session.visible.masks.labels, snapshot.maskBytes);
        expect(
          find.text(
            'Manual mode: automatic masks are unavailable. Mark surfaces to preview colors, or retry analysis.',
          ),
          findsOneWidget,
        );
        expect(app.analysis.calls, 0);
        expect(app.networkCalls, 0);
        expect(
          app.container.read(roomRecolorPreviewProvider).value!.key,
          RoomRecolorKey(
            projectId: snapshot.projectId,
            photoId: snapshot.photoId,
            maskRevision: snapshot.maskRevision,
            colorRevision: snapshot.colorRevision,
            variantId: snapshot.activeVariantId,
          ),
        );
      } finally {
        await app.dispose(tester);
        await _io(tester, () => root.delete(recursive: true));
      }
    },
  );
}
