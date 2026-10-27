import 'dart:async';
import 'dart:typed_data';

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/application/camera_session.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/application/photo_acquisition_controller.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/acquisition_intent_store.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../support/in_memory_color_history_repository.dart';
import '../../support/in_memory_app_preferences_repository.dart';
import '../../support/in_memory_acquisition_intent_store.dart';
import 'camera_screen_test.dart' show FakeCameraSession;

PreparedPhoto samplePhoto() => PreparedPhoto(
  width: 1,
  height: 1,
  rgbaBytes: Uint8List.fromList([255, 0, 0, 255]),
  previewBytes: Uint8List.fromList(
    img.encodePng(
      img.Image(width: 1, height: 1)..setPixelRgba(0, 0, 255, 0, 0, 255),
    ),
  ),
  palette: [],
);

class DelayedIntentStore extends InMemoryAcquisitionIntentStore {
  DelayedIntentStore({super.initial});
  Completer<void>? clearing, saving;
  bool failClear = false, failLoad = false;
  int clears = 0;
  @override
  Future<void> save(AcquisitionIntent intent) async {
    await saving?.future;
    await super.save(intent);
  }

  @override
  Future<AcquisitionIntentRecord> load() async {
    if (failLoad) throw const AcquisitionStorageException();
    return super.load();
  }

  @override
  Future<void> clear({bool discardUntrusted = false}) async {
    clears++;
    await clearing?.future;
    if (failClear) throw const AcquisitionStorageException();
    await super.clear(discardUntrusted: discardUntrusted);
  }
}

class EntryPhotoService implements PhotoPickerService {
  PreparedPhoto? photo;
  PhotoPickFailure? failure;
  Completer<PreparedPhoto?>? recovery;
  Completer<PreparedPhoto?>? picking;
  int picks = 0, settings = 0, recoveries = 0;
  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async {
    picks++;
    if (failure != null) throw failure!;
    return picking == null ? photo : picking!.future;
  }

  @override
  Future<PreparedPhoto?> recoverLost() async {
    recoveries++;
    return await recovery?.future;
  }

  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }
}

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester,
    EntryPhotoService service, {
    InMemoryAcquisitionIntentStore? store,
    CameraSession Function()? cameras,
    ThemeMode theme = ThemeMode.system,
  }) async {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => store ?? InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(
            initial: AppPreferences(
              onboardingCompleted: true,
              themeMode: theme,
            ),
          ),
        ),
        if (cameras != null)
          cameraSessionFactoryProvider.overrideWithValue(cameras),
        photoPickerServiceProvider.overrideWithValue(service),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => InMemoryColorHistoryRepository(),
        ),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([NamedColor('Red', RgbColor(255, 0, 0))]),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/capture');
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'welcome replay suspends a covered camera and resumes fresh samples only after return',
    (tester) async {
      final cameras = <FakeCameraSession>[];
      final container = await launch(
        tester,
        EntryPhotoService(),
        cameras: () {
          final session = FakeCameraSession();
          cameras.add(session);
          return session;
        },
      );
      final router = container.read(appRouterProvider);
      router.push('/camera');
      await tester.pumpAndSettle();
      expect(cameras.length, 1);
      router.push('/welcome');
      await tester.pumpAndSettle();
      expect(cameras.first.disposals, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(cameras.length, 1);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(cameras.length, 2);
      expect(cameras.last.starts, 1);
      expect(find.text('#FF0000'), findsNothing);
    },
  );

  testWidgets(
    'Capture and camera racing share one picker and leave hidden Capture result pending',
    (tester) async {
      final service = EntryPhotoService()
        ..picking = Completer<PreparedPhoto?>();
      final container = await launch(
        tester,
        service,
        cameras: FakeCameraSession.new,
      );
      await tester.ensureVisible(find.text('Pick a photo'));
      await tester.tap(find.text('Pick a photo'));
      await tester.pump();
      container.read(appRouterProvider).push('/camera');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Choose photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.picks, 1);
      service.picking!.complete(samplePhoto());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(container.read(appRouterProvider).state.uri.path, '/camera');
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt?.photo,
        isNotNull,
      );
    },
  );

  for (final duringClaim in [false, true]) {
    testWidgets(
      'disposed camera during ${duringClaim ? 'claim' : 'picker'} retains receipt without navigation or reopening',
      (tester) async {
        final service = EntryPhotoService()
          ..picking = Completer<PreparedPhoto?>();
        final store = DelayedIntentStore();
        final cameras = <FakeCameraSession>[];
        final container = await launch(
          tester,
          service,
          store: store,
          cameras: () {
            final camera = FakeCameraSession();
            cameras.add(camera);
            return camera;
          },
        );
        final router = container.read(appRouterProvider);
        router.push('/camera');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose photo'));
        await tester.pump();
        expect(cameras.single.disposals, 1);
        if (duringClaim) {
          store.clearing = Completer<void>();
          service.picking!.complete(samplePhoto());
          await tester.pump();
          expect(store.clears, 1);
        }
        router.go('/palette');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        if (duringClaim) {
          store.clearing!.complete();
        } else {
          service.picking!.complete(samplePhoto());
        }
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/palette');
        expect(
          container.read(photoAcquisitionProvider).pendingReceipt?.photo,
          isNotNull,
        );
        expect(cameras.length, 1);
        router.go('/capture');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Continue selected photo'));
        await tester.tap(find.text('Continue selected photo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(router.state.uri.path, '/photo');
        expect(container.read(photoAcquisitionProvider).pendingReceipt, isNull);
      },
    );
  }

  testWidgets('Room recovery never navigates Capture or consumes its receipt', (
    tester,
  ) async {
    final recovery = Completer<PreparedPhoto?>();
    final store = InMemoryAcquisitionIntentStore(
      initial: const AcquisitionIntentRecord.valid(
        AcquisitionIntent(
          requestId: 'room-recovery',
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.room,
        ),
      ),
    );
    final container = await launch(
      tester,
      EntryPhotoService()..recovery = recovery,
      store: store,
    );
    recovery.complete(
      PreparedPhoto(
        width: 1,
        height: 1,
        rgbaBytes: Uint8List.fromList([255, 0, 0, 255]),
        previewBytes: Uint8List.fromList(
          img.encodePng(img.Image(width: 1, height: 1)),
        ),
        palette: [],
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(appRouterProvider).state.uri.path, '/capture');
    expect(
      container.read(photoAcquisitionProvider).pendingReceipt?.destination,
      AcquisitionDestination.room,
    );
    expect((await store.load()).intent?.requestId, 'room-recovery');
    expect(find.text('Continue recovered photo'), findsNothing);
  });

  testWidgets(
    'picker waits behind recovery instead of opening a second native operation',
    (tester) async {
      final recovery = Completer<PreparedPhoto?>();
      final service = EntryPhotoService()..recovery = recovery;
      await launch(tester, service);
      await tester.ensureVisible(find.text('Pick a photo'));
      await tester.tap(find.text('Pick a photo'));
      await tester.pump();
      expect(service.picks, 0);
      recovery.complete(null);
      await tester.pumpAndSettle();
      expect(service.recoveries, 1);
    },
  );

  testWidgets('picker cancellation leaves Capture usable', (tester) async {
    final service = EntryPhotoService();
    await launch(tester, service);
    await tester.ensureVisible(find.text('Pick a photo'));
    await tester.tap(find.text('Pick a photo'));
    await tester.pumpAndSettle();
    expect(service.picks, 1);
    expect(find.text('See the world'), findsOneWidget);
    expect(find.text('Explore a color'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Capture hidden during durable claim keeps selected photo for explicit continuation',
    (tester) async {
      final store = DelayedIntentStore()..clearing = Completer<void>();
      final service = EntryPhotoService()..photo = samplePhoto();
      final container = await launch(tester, service, store: store);
      await tester.ensureVisible(find.text('Pick a photo'));
      await tester.tap(find.text('Pick a photo'));
      await tester.pump();
      expect(store.clears, 1);
      final router = container.read(appRouterProvider);
      router.push('/welcome');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      store.clearing!.complete();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/welcome');
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt?.photo,
        same(service.photo),
      );
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/capture');
      await tester.ensureVisible(find.text('Continue selected photo'));
      await tester.tap(find.text('Continue selected photo'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/photo');
    },
  );

  testWidgets(
    'welcome shown during intent save prevents native gallery launch',
    (tester) async {
      final store = DelayedIntentStore()..saving = Completer<void>();
      final service = EntryPhotoService();
      final container = await launch(tester, service, store: store);
      await tester.ensureVisible(find.text('Pick a photo'));
      await tester.tap(find.text('Pick a photo'));
      await tester.pump();
      container.read(appRouterProvider).push('/welcome');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      store.saving!.complete();
      await tester.pumpAndSettle();
      expect(service.picks, 0);
      expect((await store.load()).kind, IntentRecordKind.absent);
      expect(container.read(appRouterProvider).state.uri.path, '/welcome');
    },
  );

  testWidgets(
    'background Capture cannot deliver a late selected photo until explicit continuation',
    (tester) async {
      final service = EntryPhotoService()
        ..picking = Completer<PreparedPhoto?>();
      final container = await launch(tester, service);
      await tester.ensureVisible(find.text('Pick a photo'));
      await tester.tap(find.text('Pick a photo'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      service.picking!.complete(samplePhoto());
      await tester.pump();
      expect(container.read(appRouterProvider).state.uri.path, '/capture');
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt?.photo,
        isNotNull,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(container.read(appRouterProvider).state.uri.path, '/capture');
      await tester.ensureVisible(find.text('Continue selected photo'));
      await tester.tap(find.text('Continue selected photo'));
      await tester.pumpAndSettle();
      expect(container.read(appRouterProvider).state.uri.path, '/photo');
    },
  );

  testWidgets(
    'untrusted unfinished request requires confirmation and failed clear remains retryable',
    (tester) async {
      final store = DelayedIntentStore(
        initial: const AcquisitionIntentRecord.untrusted(),
      )..failClear = true;
      final service = EntryPhotoService();
      await launch(tester, service, store: store);
      await tester.ensureVisible(find.text('Dismiss unfinished request'));
      await tester.tap(find.text('Dismiss unfinished request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep request'));
      await tester.pumpAndSettle();
      expect(store.clears, 0);
      expect((await store.load()).kind, IntentRecordKind.untrusted);
      await tester.tap(find.text('Dismiss unfinished request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss request'));
      await tester.pumpAndSettle();
      expect((await store.load()).kind, IntentRecordKind.untrusted);
      expect(service.picks, 0);
      expect(find.text('Retry photo request'), findsOneWidget);
      store.failClear = false;
      await tester.ensureVisible(find.text('Retry photo request'));
      await tester.tap(find.text('Retry photo request'));
      await tester.pumpAndSettle();
      expect((await store.load()).kind, IntentRecordKind.untrusted);
      await tester.ensureVisible(find.text('Dismiss unfinished request'));
      await tester.tap(find.text('Dismiss unfinished request'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dismiss request'));
      await tester.pumpAndSettle();
      expect((await store.load()).kind, IntentRecordKind.absent);
      await tester.ensureVisible(find.text('Pick a photo'));
      await tester.tap(find.text('Pick a photo'));
      await tester.pumpAndSettle();
      expect(service.picks, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'storage recovery failure is visible and retries without navigation',
    (tester) async {
      final store = DelayedIntentStore()..failLoad = true;
      final service = EntryPhotoService();
      final container = await launch(tester, service, store: store);
      expect(service.recoveries, 0);
      expect(find.text('Retry photo request'), findsOneWidget);
      expect(tester.takeException(), isNull);
      store.failLoad = false;
      await tester.ensureVisible(find.text('Retry photo request'));
      await tester.tap(find.text('Retry photo request'));
      await tester.pumpAndSettle();
      expect(service.recoveries, 1);
      expect(container.read(appRouterProvider).state.uri.path, '/capture');
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'unknown photo destination actions work at 360dp and 2x text in ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final service = EntryPhotoService()
          ..recovery = (Completer<PreparedPhoto?>()..complete(samplePhoto()));
        final container = await launch(
          tester,
          service,
          theme: dark ? ThemeMode.dark : ThemeMode.light,
        );
        expect(find.text('Continue recovered photo'), findsOneWidget);
        expect(find.text('Continue in Room'), findsOneWidget);
        expect(
          tester
              .getSize(find.widgetWithText(SecondaryButton, 'Continue in Room'))
              .height,
          greaterThanOrEqualTo(48),
        );
        expect(
          tester
              .getSize(
                find.widgetWithText(
                  SecondaryButton,
                  'Continue recovered photo',
                ),
              )
              .height,
          greaterThanOrEqualTo(48),
        );
        final receipt = container.read(photoAcquisitionProvider).pendingReceipt;
        await tester.ensureVisible(find.text('Continue in Room'));
        await tester.tap(find.text('Continue in Room'));
        await tester.pumpAndSettle();
        expect(container.read(appRouterProvider).state.uri.path, '/rooms');
        expect(
          container.read(photoAcquisitionProvider).pendingReceipt,
          same(receipt),
        );
        container.read(appRouterProvider).go('/capture');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Continue recovered photo'));
        await tester.tap(find.text('Continue recovered photo'));
        await tester.pumpAndSettle();
        expect(container.read(appRouterProvider).state.uri.path, '/photo');
        expect(container.read(photoAcquisitionProvider).pendingReceipt, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'full-app gallery suspends camera through photo route and returns with fresh samples',
    (tester) async {
      final service = EntryPhotoService()
        ..picking = Completer<PreparedPhoto?>();
      final cameras = <FakeCameraSession>[];
      final container = await launch(
        tester,
        service,
        cameras: () {
          final camera = FakeCameraSession();
          cameras.add(camera);
          return camera;
        },
      );
      final router = container.read(appRouterProvider);
      router.push('/camera');
      await tester.pumpAndSettle();
      cameras.first.emit!(RgbColor(0, 255, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose photo'));
      await tester.pump();
      expect(cameras.single.disposals, 1);
      cameras.first.emit!(RgbColor(0, 0, 255));
      await tester.pump();
      expect(find.text('#0000FF'), findsNothing);
      service.picking!.complete(samplePhoto());
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/photo');
      expect(find.byKey(const ValueKey('photo-selected-hex')), findsOneWidget);
      expect(cameras.length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(cameras.length, 1);
      router.pop();
      await tester.pumpAndSettle();
      expect(cameras.length, 2);
      expect(find.text('#00FF00'), findsNothing);
      expect(find.text('#0000FF'), findsNothing);
      cameras.last.emit!(RgbColor(12, 34, 56));
      await tester.pumpAndSettle();
      expect(find.text('#0C2238'), findsOneWidget);
    },
  );

  testWidgets('permission and invalid image errors are recoverable', (
    tester,
  ) async {
    final service = EntryPhotoService()
      ..failure = const PhotoPickFailure(PhotoPickFailureKind.permissionDenied);
    await launch(tester, service);
    await tester.ensureVisible(find.text('Pick a photo'));
    await tester.tap(find.text('Pick a photo'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Open photo settings'));
    await tester.tap(find.text('Open photo settings'));
    await tester.pumpAndSettle();
    expect(service.settings, 1);
    service.failure = const PhotoPickFailure(PhotoPickFailureKind.invalidImage);
    await tester.ensureVisible(find.text('Pick a photo'));
    await tester.tap(find.text('Pick a photo'));
    await tester.pumpAndSettle();
    expect(
      find.text('This photo could not be read. Try a JPEG or PNG image.'),
      findsOneWidget,
    );
  });

  testWidgets('invalid photo route offers a safe return', (tester) async {
    final container = await launch(tester, EntryPhotoService());
    container.read(appRouterProvider).go('/photo');
    await tester.pumpAndSettle();
    expect(
      find.text('Choose a photo to start exploring its colors.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Return to Capture'));
    await tester.pumpAndSettle();
    expect(find.text('See the world'), findsOneWidget);
  });

  testWidgets(
    'lost photo arriving after another action waits for explicit continuation',
    (tester) async {
      final recovery = Completer<PreparedPhoto?>();
      final service = EntryPhotoService()..recovery = recovery;
      await launch(tester, service);
      await tester.ensureVisible(find.text('Explore a color'));
      await tester.tap(find.text('Explore a color'));
      await tester.pumpAndSettle();
      final image = img.Image(width: 1, height: 1)
        ..setPixelRgba(0, 0, 255, 0, 0, 255);
      recovery.complete(
        PreparedPhoto(
          width: 1,
          height: 1,
          rgbaBytes: Uint8List.fromList([255, 0, 0, 255]),
          previewBytes: Uint8List.fromList(img.encodePng(image)),
          palette: [],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start with a shade'), findsOneWidget);
      Navigator.of(tester.element(find.text('Start with a shade'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Continue recovered photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late recovery cannot interrupt a different indexed tab', (
    tester,
  ) async {
    final recovery = Completer<PreparedPhoto?>();
    final container = await launch(
      tester,
      EntryPhotoService()..recovery = recovery,
    );
    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await tester.pumpAndSettle();
    final image = img.Image(width: 1, height: 1)
      ..setPixelRgba(0, 0, 255, 0, 0, 255);
    recovery.complete(
      PreparedPhoto(
        width: 1,
        height: 1,
        rgbaBytes: Uint8List.fromList([255, 0, 0, 255]),
        previewBytes: Uint8List.fromList(img.encodePng(image)),
        palette: [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-Learn')), findsOneWidget);
    expect(find.text('Photo study'), findsNothing);
    container.read(appRouterProvider).go('/capture');
    await tester.pumpAndSettle();
    expect(find.text('Continue recovered photo'), findsOneWidget);
  });
}
