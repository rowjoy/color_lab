import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/config/app_identity.dart';
import 'package:color_lab/features/color_test/presentation/matching_screen.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_difficulty.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/presentation/badges_screen.dart';
import 'package:color_lab/features/games/presentation/bubble_shooter_screen.dart';
import 'package:color_lab/features/games/presentation/fruit_pop_screen.dart';
import 'package:color_lab/features/games/presentation/game_level_map_screen.dart';
import 'package:color_lab/features/games/presentation/games_screen.dart';
import 'package:color_lab/features/games/presentation/leaderboard_screen.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_screen.dart';
import 'package:color_lab/features/games/presentation/water_sort_screen.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/settings/application/theme_mode_provider.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_color_history_repository.dart';
import 'support/in_memory_app_preferences_repository.dart';
import 'support/in_memory_acquisition_intent_store.dart';
import 'support/in_memory_game_profiles_repository.dart';

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    InMemoryGameProfilesRepository? gameProfilesRepository,
  }) async {
    final repository = InMemoryColorHistoryRepository();
    final profilesRepository =
        gameProfilesRepository ??
        InMemoryGameProfilesRepository(initialState: _emptyProfilesState());
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(),
        ),
        colorHistoryRepositoryProvider.overrideWith((ref) async => repository),
        gameProfilesRepositoryProvider.overrideWith(
          (ref) async => profilesRepository,
        ),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([
            NamedColor('Red', RgbColor(255, 0, 0)),
            NamedColor('Lilac Haze', RgbColor.fromHex('#B2A4D4')),
          ]),
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
    return container;
  }

  Future<void> openRoute(
    WidgetTester tester,
    ProviderContainer container,
    String path, {
    Object? extra,
  }) async {
    container.read(appRouterProvider).go(path, extra: extra);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
  }

  Future<void> finishRouteTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
  }

  testWidgets('starts in Home and opens each destination', (tester) async {
    await launch(tester);
    expect(find.text(AppIdentity.displayName), findsOneWidget);
    expect(
      tester.widget<Title>(find.byType(Title)).title,
      AppIdentity.displayName,
    );
    expect(find.text('Color Lab'), findsNothing);
    expect(find.byKey(const ValueKey('screen-Home')), findsOneWidget);
    for (final destination in ['rooms', 'learn', 'games', 'home']) {
      await tester.tap(find.byKey(ValueKey('nav-$destination')));
      await finishRouteTransition(tester);
      final screenName = switch (destination) {
        'rooms' => 'Rooms',
        'learn' => 'Learn',
        'games' => 'Games',
        _ => 'Home',
      };
      expect(find.byKey(ValueKey('screen-$screenName')), findsOneWidget);
    }
  });

  testWidgets('manual color entry validates and opens actual color values', (
    tester,
  ) async {
    final container = await launch(tester);
    await openRoute(tester, container, '/capture');
    await tester.ensureVisible(find.text('Explore a color'));
    await tester.tap(find.text('Explore a color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hex-input')), 'oops');
    await tester.tap(find.text('View color'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a 3 or 6 digit HEX color.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('hex-input')), '#FF0000');
    await tester.tap(find.text('View color'));
    await tester.pumpAndSettle();
    expect(find.text('#FF0000'), findsWidgets);
    expect(find.text('255, 0, 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme state changes the application theme', (tester) async {
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
    container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    final context = tester.element(find.byKey(const ValueKey('screen-Home')));
    expect(Theme.of(context).brightness, Brightness.dark);
    container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('a manually saved shade appears in the Palette library', (
    tester,
  ) async {
    final container = await launch(tester);
    await openRoute(tester, container, '/capture');
    await tester.ensureVisible(find.text('Explore a color'));
    await tester.tap(find.text('Explore a color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hex-input')), '#FF0000');
    await tester.tap(find.text('View color'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save color'));
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    expect(find.text('Saved to library'), findsOneWidget);
    final saved = container.read(colorHistoryProvider).requireValue.single;
    expect(saved.hex, '#FF0000');
    expect(saved.source.name, 'manual');
    await tester.ensureVisible(find.byTooltip('Close color details'));
    await tester.tap(find.byTooltip('Close color details'));
    await tester.pumpAndSettle();
    await openRoute(tester, container, '/palette');
    expect(find.byKey(const ValueKey('saved-#FF0000')), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
  });

  testWidgets(
    'appearance menu changes theme and lab study survives tab switches',
    (tester) async {
      final container = await launch(tester);
      await tester.tap(find.byTooltip('Appearance settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      final pageContext = tester.element(
        find.byKey(const ValueKey('screen-Home')),
      );
      expect(Theme.of(pageContext).brightness, Brightness.dark);
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      await openRoute(tester, container, '/lab');
      final slider = find.byType(Slider).first;
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(50, 0));
      await tester.pumpAndSettle();
      final study = tester.widget<ColorSwatchTile>(
        find.byType(ColorSwatchTile),
      );
      expect(study.hex, isNot('#B2A4D4'));
      await tester.tap(find.byKey(const ValueKey('nav-rooms')));
      await finishRouteTransition(tester);
      await tester.tap(find.byKey(const ValueKey('nav-learn')));
      await finishRouteTransition(tester);
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        study.hex,
      );
    },
  );

  testWidgets('all destinations fit a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester);
    for (final destination in ['rooms', 'learn', 'games', 'home']) {
      await tester.tap(find.byKey(ValueKey('nav-$destination')));
      await finishRouteTransition(tester);
      expect(tester.takeException(), isNull, reason: destination);
    }
  });

  testWidgets('color entry opens immediately when reduced motion is enabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = await launch(tester);
    await openRoute(tester, container, '/capture');
    await tester.ensureVisible(find.text('Explore a color'));
    await tester.tap(find.text('Explore a color'));
    await tester.pump();
    await tester.pump();
    expect(find.text('View color').hitTestable(), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump();
    expect(find.text('View color'), findsNothing);
  });

  testWidgets(
    'Lab preserves the chosen hue while saturation passes through gray',
    (tester) async {
      final container = await launch(tester);
      await openRoute(tester, container, '/lab');
      var sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      final originalHue = sliders[0].value;
      sliders[1].onChanged!(0);
      await tester.pumpAndSettle();
      sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders[0].value, originalHue);
      sliders[0].onChanged!(120);
      await tester.pumpAndSettle();
      sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders[0].value, 120);
      sliders[1].onChanged!(.5);
      await tester.pumpAndSettle();
      expect(tester.widgetList<Slider>(find.byType(Slider)).first.value, 120);
    },
  );

  group('typed game routes', () {
    testWidgets('all five play routes require and retain their typed launch', (
      tester,
    ) async {
      final container = await launch(tester);

      for (final gameId in GameId.values) {
        final gameLaunch = _gameLaunch(gameId);
        await openRoute(
          tester,
          container,
          _playPath(gameId),
          extra: gameLaunch,
        );

        final routedLaunch = switch (gameId) {
          GameId.bubbleShooter =>
            tester
                .widget<BubbleShooterScreen>(find.byType(BubbleShooterScreen))
                .launch,
          GameId.fruitPop =>
            tester.widget<FruitPopScreen>(find.byType(FruitPopScreen)).launch,
          GameId.waterSort =>
            tester.widget<WaterSortScreen>(find.byType(WaterSortScreen)).launch,
          GameId.rainbowRings =>
            tester
                .widget<RainbowRingsScreen>(find.byType(RainbowRingsScreen))
                .launch,
          GameId.colorMatch =>
            tester.widget<MatchingScreen>(find.byType(MatchingScreen)).launch,
        };
        expect(routedLaunch, same(gameLaunch), reason: gameId.storageId);
        expect(tester.takeException(), isNull, reason: gameId.storageId);
      }

      final hardLaunch = _gameLaunch(
        GameId.waterSort,
        level: 30,
        attemptId: 'hard-water-sort',
      );
      await openRoute(tester, container, '/water-sort', extra: hardLaunch);
      final routedHardLaunch = tester
          .widget<WaterSortScreen>(find.byType(WaterSortScreen))
          .launch;
      expect(routedHardLaunch, same(hardLaunch));
      expect(routedHardLaunch.descriptor.tier, GameTier.hard);
    });

    testWidgets(
      'missing, wrong-type, and mismatched play data opens a safe screen',
      (tester) async {
        final repository = InMemoryGameProfilesRepository(
          initialState: _emptyProfilesState(),
        );
        final container = await launch(
          tester,
          gameProfilesRepository: repository,
        );

        for (final gameId in GameId.values) {
          if (gameId != GameId.colorMatch) {
            await openRoute(tester, container, _playPath(gameId));
            expect(
              find.byKey(const ValueKey('invalid-game-launch')),
              findsOneWidget,
              reason: '${gameId.storageId} missing launch',
            );
          }

          await openRoute(
            tester,
            container,
            _playPath(gameId),
            extra: GameDifficulty.easy,
          );
          expect(
            find.byKey(const ValueKey('invalid-game-launch')),
            findsOneWidget,
            reason: '${gameId.storageId} wrong launch type',
          );

          final otherGame =
              GameId.values[(GameId.values.indexOf(gameId) + 1) %
                  GameId.values.length];
          await openRoute(
            tester,
            container,
            _playPath(gameId),
            extra: _gameLaunch(otherGame),
          );
          expect(
            find.byKey(const ValueKey('invalid-game-launch')),
            findsOneWidget,
            reason: '${gameId.storageId} mismatched launch',
          );
          expect(tester.takeException(), isNull, reason: gameId.storageId);
        }

        await openRoute(tester, container, '/bubble-shooter');
        expect(find.byType(BubbleShooterScreen), findsNothing);
        expect(find.text('Easy'), findsNothing);
        expect(repository.transitionCount, 0);
        expect(repository.writeAttempts, 0);
      },
    );

    testWidgets('/matching without extra remains isolated Lab practice', (
      tester,
    ) async {
      final repository = InMemoryGameProfilesRepository(
        initialState: _emptyProfilesState(),
      );
      final container = await launch(
        tester,
        gameProfilesRepository: repository,
      );

      await openRoute(tester, container, '/matching');

      final screen = tester.widget<MatchingScreen>(find.byType(MatchingScreen));
      expect(screen.launch, isNull);
      expect(screen.onOpenMap, isNull);
      expect(find.byKey(const ValueKey('screen-Matching')), findsOneWidget);
      expect(repository.transitionCount, 0);
      expect(repository.writeAttempts, 0);
    });

    testWidgets('map, badges, and leaderboard routes parse stable game IDs', (
      tester,
    ) async {
      final container = await launch(tester);

      for (final gameId in GameId.values) {
        await openRoute(tester, container, '/games/${gameId.storageId}/map');
        expect(
          tester
              .widget<GameLevelMapScreen>(find.byType(GameLevelMapScreen))
              .gameId,
          gameId,
        );
      }

      await openRoute(tester, container, '/games/not-a-game/map');
      expect(find.byType(GameLevelMapScreen), findsNothing);
      expect(find.byKey(const ValueKey('invalid-game-launch')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await openRoute(tester, container, '/games/BubbleShooter/map');
      expect(find.byType(GameLevelMapScreen), findsNothing);
      expect(find.byKey(const ValueKey('invalid-game-launch')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await openRoute(tester, container, '/games/badges');
      expect(find.byType(BadgesScreen), findsOneWidget);

      await openRoute(tester, container, '/games/leaderboard');
      expect(find.byType(LeaderboardScreen), findsOneWidget);
    });

    testWidgets('Games hub callbacks open every destination and Back returns', (
      tester,
    ) async {
      final container = await launch(tester);
      final router = container.read(appRouterProvider);
      await openRoute(tester, container, '/games');

      for (final gameId in GameId.values) {
        tester.widget<GamesScreen>(find.byType(GamesScreen)).onOpenMap!(gameId);
        await finishRouteTransition(tester);
        expect(
          tester
              .widget<GameLevelMapScreen>(find.byType(GameLevelMapScreen))
              .gameId,
          gameId,
        );
        router.pop();
        await finishRouteTransition(tester);
        expect(find.byType(GamesScreen), findsOneWidget);
      }

      tester.widget<GamesScreen>(find.byType(GamesScreen)).onOpenBadges!();
      await finishRouteTransition(tester);
      expect(find.byType(BadgesScreen), findsOneWidget);
      router.pop();
      await finishRouteTransition(tester);

      tester.widget<GamesScreen>(find.byType(GamesScreen)).onOpenLeaderboard!();
      await finishRouteTransition(tester);
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      router.pop();
      await finishRouteTransition(tester);

      for (final gameId in GameId.values) {
        final gameLaunch = _gameLaunch(gameId);
        tester.widget<GamesScreen>(find.byType(GamesScreen)).onLaunchGame!(
          gameLaunch,
        );
        await finishRouteTransition(tester);
        expect(_findGameScreen(gameId), findsOneWidget);
        router.pop();
        await finishRouteTransition(tester);
        expect(find.byType(GamesScreen), findsOneWidget);
      }
    });

    testWidgets('game Map callbacks and map replay preserve Back history', (
      tester,
    ) async {
      final container = await launch(tester);
      final router = container.read(appRouterProvider);

      for (final gameId in GameId.values) {
        final gameLaunch = _gameLaunch(gameId);
        await openRoute(
          tester,
          container,
          _playPath(gameId),
          extra: gameLaunch,
        );

        final openMap = switch (gameId) {
          GameId.bubbleShooter =>
            tester
                .widget<BubbleShooterScreen>(find.byType(BubbleShooterScreen))
                .onOpenMap,
          GameId.fruitPop =>
            tester
                .widget<FruitPopScreen>(find.byType(FruitPopScreen))
                .onOpenMap,
          GameId.waterSort =>
            tester
                .widget<WaterSortScreen>(find.byType(WaterSortScreen))
                .onOpenMap,
          GameId.rainbowRings =>
            tester
                .widget<RainbowRingsScreen>(find.byType(RainbowRingsScreen))
                .onOpenMap,
          GameId.colorMatch =>
            tester
                .widget<MatchingScreen>(find.byType(MatchingScreen))
                .onOpenMap,
        };
        expect(openMap, isNotNull, reason: gameId.storageId);
        openMap!();
        await finishRouteTransition(tester);
        expect(
          tester
              .widget<GameLevelMapScreen>(find.byType(GameLevelMapScreen))
              .gameId,
          gameId,
        );

        final replay = _gameLaunch(
          gameId,
          attemptId: 'replay-${gameId.storageId}',
          playKind: GamePlayKind.replay,
        );
        tester
            .widget<GameLevelMapScreen>(find.byType(GameLevelMapScreen))
            .onLaunchGame!(replay);
        await finishRouteTransition(tester);
        expect(_findGameScreen(gameId), findsOneWidget);

        router.pop();
        await finishRouteTransition(tester);
        expect(find.byType(GameLevelMapScreen), findsOneWidget);
        router.pop();
        await finishRouteTransition(tester);
        expect(_findGameScreen(gameId), findsOneWidget);
      }
    });

    testWidgets('invalid launch recovery returns safely to Games', (
      tester,
    ) async {
      final container = await launch(tester);
      await openRoute(
        tester,
        container,
        '/water-sort',
        extra: const <String, Object?>{'difficulty': 'easy'},
      );

      await tester.tap(find.byKey(const ValueKey('invalid-game-launch-back')));
      await finishRouteTransition(tester);

      expect(find.byType(GamesScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

GameProfilesState _emptyProfilesState() => GameProfilesState(
  activeProfileId: null,
  profiles: const {},
  legacyMigrationComplete: true,
);

String _playPath(GameId gameId) => switch (gameId) {
  GameId.bubbleShooter => '/bubble-shooter',
  GameId.fruitPop => '/fruit-pop',
  GameId.waterSort => '/water-sort',
  GameId.rainbowRings => '/rainbow-rings',
  GameId.colorMatch => '/matching',
};

GameLaunch _gameLaunch(
  GameId gameId, {
  String? attemptId,
  GamePlayKind playKind = GamePlayKind.current,
  int level = 1,
}) {
  final identity = (GameId.values.indexOf(gameId) + 1) * 1000 + level;
  return GameLaunch(
    profileId: 'profile-router-test',
    gameId: gameId,
    descriptor: GameLevelDescriptor(
      gameId: gameId,
      level: level,
      seed: identity,
      generatorVersion: 1,
      retrySalt: 0,
      fingerprint: identity.toRadixString(16).padLeft(64, '0'),
      tier: GameTier.forLevel(level),
      levelPressure: levelPressureFor(level),
    ),
    attemptId: attemptId ?? 'attempt-${gameId.storageId}',
    playKind: playKind,
  );
}

Finder _findGameScreen(GameId gameId) => switch (gameId) {
  GameId.bubbleShooter => find.byType(BubbleShooterScreen),
  GameId.fruitPop => find.byType(FruitPopScreen),
  GameId.waterSort => find.byType(WaterSortScreen),
  GameId.rainbowRings => find.byType(RainbowRingsScreen),
  GameId.colorMatch => find.byType(MatchingScreen),
};
