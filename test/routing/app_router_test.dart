import 'package:color_lab/app.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/presentation/invalid_game_launch_screen.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/home/presentation/home_screen.dart';
import 'package:color_lab/features/lab/presentation/lab_screen.dart';
import 'package:color_lab/features/learning/presentation/learn_screen.dart';
import 'package:color_lab/features/my_work/presentation/my_work_screen.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/presentation/palette_screen.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/presentation/capture_screen.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_gallery_screen.dart';
import 'package:color_lab/features/room_studio/presentation/room_screen.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/shell/presentation/app_shell.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/in_memory_acquisition_intent_store.dart';
import '../support/in_memory_app_preferences_repository.dart';
import '../support/in_memory_color_history_repository.dart';
import '../support/in_memory_game_profiles_repository.dart';
import '../support/in_memory_room_design_repository.dart';
import '../support/in_memory_saved_palette_repository.dart';

void main() {
  testWidgets('completed onboarding lands on Home with exactly four roots', (
    tester,
  ) async {
    _configureView(tester, const Size(599, 800));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    expect(harness.router.state.uri.path, '/home');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(AppDestination.values, [
      AppDestination.home,
      AppDestination.rooms,
      AppDestination.learn,
      AppDestination.games,
    ]);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(4),
    );
    for (final id in ['home', 'rooms', 'learn', 'games']) {
      expect(find.byKey(ValueKey('nav-$id')), findsOneWidget, reason: id);
    }
    for (final removed in ['my-work', 'capture', 'palette', 'lab']) {
      expect(find.byKey(ValueKey('nav-$removed')), findsNothing);
    }

    tester.view.physicalSize = const Size(840, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).destinations,
      hasLength(4),
    );
  });

  testWidgets('Learn branch stack and draft survive switches and live resize', (
    tester,
  ) async {
    _configureView(tester, const Size(599, 800));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await _pumpUntil(tester, find.byType(LearnScreen));
    final openLab = find.byKey(const ValueKey('learn-open-lab'));
    await tester.ensureVisible(openLab);
    await tester.tap(openLab);
    await _pumpUntil(tester, find.byType(LabScreen));
    final slider = tester.widgetList<Slider>(find.byType(Slider)).first;
    slider.onChanged!(123);
    await tester.pump();
    expect(
      tester.widgetList<Slider>(find.byType(Slider)).first.value,
      closeTo(123, .01),
    );

    await tester.tap(find.byKey(const ValueKey('nav-rooms')));
    await _pumpUntil(tester, find.byType(RoomScreen));
    tester.view.physicalSize = const Size(840, 800);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await _pumpUntil(tester, find.byType(LabScreen));
    expect(harness.router.state.uri.path, '/lab');
    expect(
      tester.widgetList<Slider>(find.byType(Slider)).first.value,
      closeTo(123, .01),
    );

    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await _pumpUntil(tester, find.byType(LearnScreen));
    expect(harness.router.state.uri.path, '/learn');
  });

  testWidgets('My Work is not a fifth tab and system Back returns Home', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    final openMyWork = find.byKey(const ValueKey('home-card-my-work'));
    await tester.ensureVisible(openMyWork);
    await tester.tap(openMyWork);
    await _pumpUntil(tester, find.byType(MyWorkScreen));
    expect(harness.router.state.uri.path, '/my-work');
    expect(find.byKey(const ValueKey('nav-my-work')), findsNothing);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await _pumpUntil(tester, find.byType(HomeScreen));
    expect(harness.router.state.uri.path, '/home');
  });

  testWidgets('legacy tool paths and the Room redirect remain valid', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    for (final entry in <String, Finder>{
      '/capture': find.byType(CaptureScreen),
      '/palette': find.byType(PaletteScreen),
      '/lab': find.byType(LabScreen),
      '/room': find.byType(RoomScreen),
      '/room/illustrated': find.byType(IllustratedRoomGalleryScreen),
    }.entries) {
      harness.router.go(entry.key);
      await _pumpUntil(tester, entry.value);
      await tester.pumpAndSettle();
      expect(entry.value, findsOneWidget, reason: entry.key);
      expect(tester.takeException(), isNull, reason: entry.key);
    }
    harness.router.go('/room');
    await _pumpUntil(tester, find.byType(RoomScreen));
    expect(harness.router.state.uri.path, '/rooms');
  });

  testWidgets('invalid and unknown deep links recover safely to Home', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    harness.router.go('/water-sort');
    await _pumpUntil(tester, find.byType(InvalidGameLaunchScreen));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invalid-game-launch')), findsOneWidget);

    harness.router.go('/not-a-real-route');
    await _pumpUntil(tester, find.byKey(const ValueKey('route-unavailable')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Color Lab'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('route-recovery-home')));
    await _pumpUntil(tester, find.byType(HomeScreen));
    expect(harness.router.state.uri.path, '/home');
  });

  testWidgets('router and branches declare stable restoration identities', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).restorationScopeId,
      'tintatlas-app',
    );
    expect(
      harness.router.routerDelegate.builder.restorationScopeId,
      'tintatlas-router',
    );
    final shell = harness.router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;
    expect(shell.restorationScopeId, 'tintatlas-shell');
    expect(shell.branches.map((branch) => branch.restorationScopeId), [
      'home-branch',
      'rooms-branch',
      'learn-branch',
      'games-branch',
    ]);
    expect(
      shell.branches.map((branch) => branch.navigatorKey).toSet(),
      hasLength(4),
    );
  });
}

final class _RouterHarness {
  const _RouterHarness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  void dispose() => container.dispose();
}

Future<_RouterHarness> _launch(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      acquisitionIntentStoreProvider.overrideWith(
        (ref) async => InMemoryAcquisitionIntentStore(),
      ),
      appPreferencesRepositoryProvider.overrideWith(
        (ref) async => InMemoryAppPreferencesRepository(),
      ),
      colorHistoryRepositoryProvider.overrideWith(
        (ref) async => InMemoryColorHistoryRepository(),
      ),
      savedPaletteRepositoryProvider.overrideWith(
        (ref) async => InMemorySavedPaletteRepository(),
      ),
      roomDesignRepositoryProvider.overrideWith(
        (ref) async => InMemoryRoomDesignRepository(),
      ),
      gameProfilesRepositoryProvider.overrideWith(
        (ref) async => InMemoryGameProfilesRepository(
          initialState: GameProfilesState(
            activeProfileId: null,
            profiles: const {},
            legacyMigrationComplete: true,
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ColorLabApp()),
  );
  final router = container.read(appRouterProvider);
  await _pumpUntil(tester, find.byType(HomeScreen));
  return _RouterHarness(container, router);
}

void _configureView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var frame = 0; frame < 40; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}
