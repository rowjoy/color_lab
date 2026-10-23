import 'dart:async';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/application/camera_session.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/picker/presentation/camera_picker_screen.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../support/in_memory_color_history_repository.dart';
import '../../support/in_memory_acquisition_intent_store.dart';

class FakeCameraSession implements CameraSession {
  CameraFailure? failure;
  Completer<void>? initializing;
  Completer<void>? disposing;
  Completer<void>? stopping;
  ValueChanged<RgbColor>? emit;
  int starts = 0, stops = 0, disposals = 0, settings = 0;
  double? x, y;
  @override
  Future<void> initialize() async {
    await initializing?.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> start({
    required ValueChanged<RgbColor> onColor,
    required ValueChanged<CameraFailure> onError,
  }) async {
    starts++;
    emit = onColor;
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopping?.future;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await disposing?.future;
  }

  @override
  Future<bool> openSettings() async {
    settings++;
    return true;
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.black);
  @override
  double get previewAspectRatio => .75;
  @override
  void updateSamplePoint({
    required double x,
    required double y,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    this.x = x;
    this.y = y;
  }
}

class FakePhotoPicker implements PhotoPickerService {
  int picks = 0, recoveries = 0;
  Completer<PreparedPhoto?>? picking;
  Completer<PreparedPhoto?>? recovery;
  PhotoSource? lastSource;
  PreparedPhoto? result;
  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async {
    picks++;
    lastSource = source;
    return picking == null ? result : picking!.future;
  }

  @override
  Future<PreparedPhoto?> recoverLost() async {
    recoveries++;
    return recovery?.future;
  }

  @override
  Future<bool> openSettings() async => true;
}

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester,
    CameraSession Function() factory, {
    PhotoPickerService? picker,
    double textScale = 1,
  }) async {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        cameraSessionFactoryProvider.overrideWithValue(factory),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([NamedColor('Red', RgbColor(255, 0, 0))]),
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => InMemoryColorHistoryRepository(),
        ),
        if (picker != null)
          photoPickerServiceProvider.overrideWithValue(picker),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const CameraPickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('permanent denial offers settings and retry without leaking', (
    tester,
  ) async {
    final camera = FakeCameraSession()
      ..failure = const CameraFailure(
        CameraFailureKind.permissionPermanentlyDenied,
      );
    await launch(tester, () => camera);
    expect(find.text('Camera access is off'), findsOneWidget);
    expect(camera.disposals, 1);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(camera.settings, 1);
  });

  for (final deniedBeforeResume in [false, true]) {
    testWidgets(
      'permission denial ${deniedBeforeResume ? 'before' : 'after'} resume never creates an automatic second request',
      (tester) async {
        final pending = FakeCameraSession()
          ..initializing = Completer<void>()
          ..failure = const CameraFailure(CameraFailureKind.permissionDenied);
        final replacement = FakeCameraSession();
        var creations = 0;
        final container = ProviderContainer(
          overrides: [
            cameraSessionFactoryProvider.overrideWithValue(
              () => creations++ == 0 ? pending : replacement,
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const CameraPickerScreen(),
            ),
          ),
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        expect(pending.disposals, 1);
        if (deniedBeforeResume) {
          pending.initializing!.complete();
          await tester.pumpAndSettle();
        }
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(creations, 1);
        if (!deniedBeforeResume) pending.initializing!.complete();
        await tester.pumpAndSettle();
        expect(creations, 1);
        expect(find.text('Allow camera access'), findsOneWidget);
        expect(pending.starts, 0);
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();
        expect(creations, 2);
        expect(replacement.starts, 1);
      },
    );
  }

  testWidgets(
    'a grant arriving after real background cannot start the disposed camera',
    (tester) async {
      final pending = FakeCameraSession()..initializing = Completer<void>();
      final replacement = FakeCameraSession();
      var creations = 0;
      final container = ProviderContainer(
        overrides: [
          cameraSessionFactoryProvider.overrideWithValue(
            () => creations++ == 0 ? pending : replacement,
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const CameraPickerScreen(),
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      pending.initializing!.complete();
      await tester.pumpAndSettle();
      expect(pending.disposals, 1);
      expect(pending.starts, 0);
      expect(creations, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(creations, 2);
      expect(replacement.starts, 1);
    },
  );

  testWidgets(
    'unavailable camera retries and saves real sampled camera source',
    (tester) async {
      final first = FakeCameraSession()
        ..failure = const CameraFailure(CameraFailureKind.unavailable);
      final second = FakeCameraSession();
      var creations = 0;
      final container = await launch(
        tester,
        () => creations++ == 0 ? first : second,
      );
      expect(find.text('No camera found'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      second.emit!(RgbColor(255, 0, 0));
      await tester.pumpAndSettle();
      expect(find.text('#FF0000'), findsOneWidget);
      await tester.ensureVisible(find.text('Save color'));
      await tester.tap(find.text('Save color'));
      await tester.pumpAndSettle();
      expect(
        container.read(colorHistoryProvider).requireValue.single.source.name,
        'camera',
      );
      final preview = find.byKey(const ValueKey('camera-preview'));
      final rect = tester.getRect(preview);
      await tester.tapAt(
        rect.topLeft + Offset(rect.width * .2, rect.height * .2),
      );
      await tester.pump();
      expect(second.x, closeTo(.2, .01));
      expect(second.y, closeTo(.2, .01));
    },
  );

  testWidgets('background releases and resume creates a fresh session', (
    tester,
  ) async {
    final cameras = <FakeCameraSession>[];
    await launch(tester, () {
      final camera = FakeCameraSession();
      cameras.add(camera);
      return camera;
    });
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(cameras.first.disposals, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(cameras.length, 2);
    expect(cameras.last.starts, 1);
  });

  testWidgets('late initialization cannot start after route disposal', (
    tester,
  ) async {
    final camera = FakeCameraSession()..initializing = Completer<void>();
    final container = ProviderContainer(
      overrides: [cameraSessionFactoryProvider.overrideWithValue(() => camera)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CameraPickerScreen()),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    camera.initializing!.complete();
    await tester.pumpAndSettle();
    expect(camera.starts, 0);
    expect(camera.disposals, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera controls fit at 360px with doubled text', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final camera = FakeCameraSession();
    await launch(tester, () => camera, textScale: 2);
    camera.emit!(RgbColor(255, 0, 0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose photo'));
    await tester.pumpAndSettle();
    expect(find.text('#FF0000'), findsOneWidget);
    final chromeClip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byType(GlassBar),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(chromeClip.borderRadius, BorderRadius.circular(AppRadii.large));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reticle is filled with the actual sampled color', (
    tester,
  ) async {
    final camera = FakeCameraSession();
    await launch(tester, () => camera);
    camera.emit!(RgbColor(255, 0, 0));
    await tester.pump();
    final reticle = tester.widget<Container>(
      find.byKey(const ValueKey('camera-reticle')),
    );
    expect(
      (reticle.decoration! as BoxDecoration).color,
      const Color(0xFFFF0000),
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Hero && widget.tag == 'camera-selected-color',
      ),
      findsOneWidget,
    );
  });

  testWidgets('portrait route restores orientation on removal', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await launch(tester, () => FakeCameraSession());
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    final orientations = calls
        .where((call) => call.method == 'SystemChrome.setPreferredOrientations')
        .map((call) => call.arguments);
    expect(orientations, [
      ['DeviceOrientation.portraitUp'],
      [],
    ]);
  });

  testWidgets(
    'resume waits for old device disposal and rejects its late color',
    (tester) async {
      final first = FakeCameraSession()..disposing = Completer<void>();
      final second = FakeCameraSession();
      var creations = 0;
      await launch(tester, () => creations++ == 0 ? first : second);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      first.emit!(RgbColor(255, 0, 0));
      await tester.pump();
      expect(creations, 1);
      expect(find.text('#FF0000'), findsNothing);
      first.disposing!.complete();
      await tester.pumpAndSettle();
      expect(creations, 2);
      expect(second.starts, 1);
    },
  );

  testWidgets(
    'Choose photo acquires directly and resumes live camera after cancellation',
    (tester) async {
      final picker = FakePhotoPicker()..picking = Completer<PreparedPhoto?>();
      final cameras = <FakeCameraSession>[];
      await launch(tester, () {
        final session = FakeCameraSession();
        cameras.add(session);
        return session;
      }, picker: picker);
      await tester.ensureVisible(find.text('Choose photo'));
      await tester.tap(find.text('Choose photo'));
      await tester.pump();
      expect(picker.picks, 1);
      expect(cameras.first.disposals, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(cameras.length, 1);
      picker.picking!.complete(null);
      await tester.pumpAndSettle();
      expect(cameras.length, 2);
      expect(cameras.last.starts, 1);
    },
  );

  testWidgets(
    'direct camera gallery request waits for shared recovery before launching gallery',
    (tester) async {
      final picker = FakePhotoPicker()..recovery = Completer<PreparedPhoto?>();
      final cameras = <FakeCameraSession>[];
      await launch(tester, () {
        final session = FakeCameraSession();
        cameras.add(session);
        return session;
      }, picker: picker);
      expect(picker.recoveries, 0);
      await tester.tap(find.text('Choose photo'));
      await tester.pump();
      expect(picker.recoveries, 1);
      expect(picker.picks, 0);
      expect(cameras.single.disposals, 1);
      picker.recovery!.complete(null);
      await tester.pumpAndSettle();
      expect(picker.picks, 1);
      expect(picker.lastSource, PhotoSource.gallery);
      expect(cameras.length, 2);
    },
  );

  testWidgets(
    'background during pending detail stop cannot open a stale sheet',
    (tester) async {
      final first = FakeCameraSession()..stopping = Completer<void>();
      final second = FakeCameraSession();
      var creations = 0;
      await launch(tester, () => creations++ == 0 ? first : second);
      first.emit!(RgbColor(255, 0, 0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Color details'));
      await tester.tap(find.text('Color details'));
      await tester.pump();
      expect(first.stops, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      first.stopping!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(ColorDetails), findsNothing);
      expect(second.starts, 1);
      expect(first.disposals, 1);
    },
  );

  testWidgets(
    'selected photo reaches its route and camera resumes only after return',
    (tester) async {
      final photo = PreparedPhoto(
        width: 1,
        height: 1,
        rgbaBytes: Uint8List.fromList([1, 2, 3, 255]),
        previewBytes: Uint8List(0),
        palette: [],
      );
      final picker = FakePhotoPicker()..result = photo;
      final cameras = <FakeCameraSession>[];
      PreparedPhoto? received;
      final router = GoRouter(
        initialLocation: '/camera',
        routes: [
          GoRoute(
            path: '/camera',
            builder: (_, _) => const CameraPickerScreen(),
          ),
          GoRoute(
            path: '/photo',
            builder: (context, state) {
              received = state.extra! as PreparedPhoto;
              return Scaffold(
                body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Return to camera'),
                ),
              );
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            acquisitionIntentStoreProvider.overrideWith(
              (ref) async => InMemoryAcquisitionIntentStore(),
            ),
            cameraSessionFactoryProvider.overrideWithValue(() {
              final camera = FakeCameraSession();
              cameras.add(camera);
              return camera;
            }),
            photoPickerServiceProvider.overrideWithValue(picker),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Choose photo'));
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      expect(received, same(photo));
      expect(cameras.length, 1);
      expect(cameras.first.disposals, 1);
      await tester.tap(find.text('Return to camera'));
      await tester.pumpAndSettle();
      expect(cameras.length, 2);
      expect(cameras.last.starts, 1);
    },
  );
}
