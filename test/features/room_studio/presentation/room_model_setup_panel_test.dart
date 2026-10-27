import 'package:color_lab/features/room_studio/application/room_model_download_providers.dart';
import 'package:color_lab/features/room_studio/application/room_model_setup_controller.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/room_studio/presentation/room_model_setup_panel.dart';
import 'package:color_lab/features/room_studio/presentation/room_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Setup extends RoomModelSetupController {
  _Setup({this.cached = false});
  final bool cached;
  bool get cancelled => state.availability == RoomModelAvailability.cancelled;
  static const progress = RoomModelDownloadProgress(
    stage: RoomModelDownloadStage.idle,
    receivedBytes: 0,
    totalBytes: 68316288,
  );
  @override
  RoomModelSetupState build() => const RoomModelSetupState(progress: progress);
  void show(RoomModelAvailability availability, {bool enter = false}) {
    state = RoomModelSetupState(
      availability: availability,
      progress: progress,
      canEnter: enter,
    );
  }

  @override
  Future<void> check() async => show(
    cached ? RoomModelAvailability.ready : RoomModelAvailability.notInstalled,
  );
  @override
  Future<void> download() async => show(RoomModelAvailability.downloading);
  @override
  Future<void> retry() => download();
  @override
  void cancel() => show(RoomModelAvailability.cancelled);
  @override
  Future<bool> continueWithCachedModels() async {
    show(RoomModelAvailability.ready, enter: true);
    return true;
  }
}

int _editorMounts = 0;

class _Editor extends StatefulWidget {
  const _Editor();
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  @override
  void initState() {
    super.initState();
    _editorMounts++;
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('Photo editor'));
}

void main() {
  Future<GoRouter> launch(
    WidgetTester tester, {
    String initial = '/rooms',
    _Setup? setup,
  }) async {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/rooms', builder: (_, _) => const RoomScreen()),
        GoRoute(
          path: '/room/masks',
          builder: (_, _) => const RoomModelSetupGate(child: _Editor()),
        ),
        GoRoute(
          path: '/room/illustrated',
          builder: (_, _) => const Scaffold(body: Text('Illustrated gallery')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (setup != null) roomModelSetupProvider.overrideWith(() => setup),
          roomModelStoreProvider.overrideWith(
            (ref) => throw StateError('Illustrated must not access models'),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('Illustrated Rooms bypass every model provider', (tester) async {
    await launch(tester);
    await tap(tester, 'open-illustrated-gallery');
    expect(find.text('Illustrated gallery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Use my photo offers exact size and Later without downloading', (
    tester,
  ) async {
    final router = await launch(tester, setup: _Setup());
    expect(find.text('Use my photo'), findsOneWidget);
    await tap(tester, 'open-room-masks');
    expect(find.textContaining('68,316,288 bytes'), findsOneWidget);
    expect(find.textContaining('65.2 MiB'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    await tap(tester, 'room-setup-later');
    expect(router.state.uri.path, '/rooms');
    expect(find.text('Use my photo'), findsOneWidget);
  });

  testWidgets(
    'direct route downloads, cancels, retries, verifies and awaits Continue',
    (tester) async {
      final setup = _Setup();
      final router = await launch(tester, initial: '/room/masks', setup: setup);
      expect(find.text('Download'), findsOneWidget);
      await tap(tester, 'room-setup-download');
      expect(find.text('Cancel'), findsOneWidget);
      await tap(tester, 'room-setup-cancel');
      expect(find.textContaining('paused'), findsOneWidget);
      await tap(tester, 'room-setup-retry');
      setup.show(RoomModelAvailability.verifying);
      await tester.pump();
      expect(find.text('Verifying AI models…'), findsOneWidget);
      setup.show(RoomModelAvailability.ready);
      await tester.pumpAndSettle();
      expect(find.text('Photo editor'), findsNothing);
      await tap(tester, 'room-setup-continue');
      expect(find.text('Photo editor'), findsOneWidget);
      expect(router.state.uri.path, '/room/masks');
    },
  );

  testWidgets('cached models offer offline Continue without Download', (
    tester,
  ) async {
    await launch(tester, initial: '/room/masks', setup: _Setup(cached: true));
    expect(find.text('Download'), findsNothing);
    expect(find.textContaining('offline'), findsWidgets);
    await tap(tester, 'room-setup-continue');
    expect(find.text('Photo editor'), findsOneWidget);
  });

  testWidgets(
    'reentry rechecks before mounting the editor after prior permission',
    (tester) async {
      _editorMounts = 0;
      final router = await launch(
        tester,
        initial: '/room/masks',
        setup: _Setup(cached: true),
      );
      await tap(tester, 'room-setup-continue');
      expect(_editorMounts, 1);
      router.go('/rooms');
      await tester.pumpAndSettle();
      await tap(tester, 'open-room-masks');
      expect(find.text('Photo editor'), findsNothing);
      expect(
        _editorMounts,
        1,
        reason: 'Photo acquisition must not mount before a fresh Continue',
      );
      await tap(tester, 'room-setup-continue');
      expect(_editorMounts, 2);
    },
  );

  testWidgets(
    'failure and full storage retain Retry, Back and Illustrated recovery',
    (tester) async {
      final setup = _Setup();
      await launch(tester, initial: '/room/masks', setup: setup);
      for (final failure in [
        RoomModelAvailability.failed,
        RoomModelAvailability.storageFull,
      ]) {
        setup.show(failure);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('room-setup-retry')), findsOneWidget);
        expect(find.byTooltip('Back'), findsOneWidget);
        expect(find.textContaining('/private'), findsNothing);
      }
      expect(find.textContaining('space'), findsWidgets);
      await tap(tester, 'room-setup-illustrated');
      expect(find.text('Illustrated gallery'), findsOneWidget);
    },
  );

  testWidgets('Back during download cancels before returning to Rooms', (
    tester,
  ) async {
    final setup = _Setup();
    final router = await launch(tester, initial: '/room/masks', setup: setup);
    await tap(tester, 'room-setup-download');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/rooms');
    expect(setup.cancelled, isTrue);
    // Reentry shows the setup choice; no editor permission was granted.
    await tap(tester, 'open-room-masks');
    expect(find.text('Photo editor'), findsNothing);
  });

  testWidgets('360dp at 200 percent text keeps setup actions usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester, initial: '/room/masks', setup: _Setup());
    await tap(tester, 'room-setup-download');
    await tap(tester, 'room-setup-cancel');
    await tap(tester, 'room-setup-retry');
    expect(tester.takeException(), isNull);
  });
}
