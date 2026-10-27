import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/adapters/bubble_shooter_level_adapter.dart';
import 'package:color_lab/features/games/domain/adapters/water_sort_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:color_lab/features/games/presentation/game_level_map_screen.dart';
import 'package:color_lab/features/games/presentation/games_screen.dart';
import 'package:color_lab/features/games/presentation/leaderboard_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  testWidgets(
    'two named players keep independent endless progress across restart, replay, ranking, and stale launches',
    (tester) async {
      final harness = _IntegrationHarness(
        initialState: _emptyState(),
        profileIds: const ['profile-ada', 'profile-ben'],
      );
      addTearDown(harness.dispose);

      var container = harness.startContainer();
      await container.read(gameProfilesProvider.future);
      var controller = container.read(gameProfilesProvider.notifier);

      final ada = await controller.createProfile(name: 'Ada');
      final adaCatalog = await controller.prepareGame(
        profileId: ada.id,
        gameId: GameId.waterSort,
      );
      expect(adaCatalog.generatedThrough, 15);
      expect(adaCatalog.descriptors.keys, orderedEquals(_levelsThrough(15)));

      final adaLevelOne = await controller.beginCurrentAttempt(
        profileId: ada.id,
        gameId: GameId.waterSort,
      );
      var durableAda = harness
          .repository
          .durableState
          .profiles[ada.id]!
          .gameProgress[GameId.waterSort]!;
      expect(durableAda.activeAttempt?.attemptId, adaLevelOne.attemptId);
      expect(durableAda.attempts, 1);
      expect(harness.repository.durableState.profiles[ada.id]!.gamesPlayed, 1);

      await controller.completeLevel(
        adaLevelOne,
        const WaterSortOutcome(actualMoves: 5, parMoves: 4),
      );
      final adaLevelTwo = await controller.beginCurrentAttempt(
        profileId: ada.id,
        gameId: GameId.waterSort,
      );
      expect(adaLevelTwo.descriptor.level, 2);
      durableAda = harness
          .repository
          .durableState
          .profiles[ada.id]!
          .gameProgress[GameId.waterSort]!;
      expect(durableAda.currentLevel, 2);
      expect(durableAda.activeAttempt?.attemptId, adaLevelTwo.attemptId);
      expect(durableAda.attempts, 2);

      harness.stopContainer(container);
      container = harness.startContainer();
      final resumedAfterFirstRestart = await container.read(
        gameProfilesProvider.future,
      );
      controller = container.read(gameProfilesProvider.notifier);
      final resumedAda = resumedAfterFirstRestart.profiles[ada.id]!;
      expect(resumedAda.gameProgress[GameId.waterSort]!.currentLevel, 2);
      expect(
        resumedAda.gameProgress[GameId.waterSort]!.activeAttempt?.attemptId,
        adaLevelTwo.attemptId,
      );
      expect(resumedAda.gamesPlayed, 2);

      await controller.completeLevel(
        adaLevelTwo,
        const WaterSortOutcome(actualMoves: 10, parMoves: 9),
      );
      final ben = await controller.createProfile(name: 'Ben');
      final benCatalog = await controller.prepareGame(
        profileId: ben.id,
        gameId: GameId.waterSort,
      );
      final persistedAdaCatalog = harness
          .repository
          .durableState
          .profiles[ada.id]!
          .gameProgress[GameId.waterSort]!;
      expect(persistedAdaCatalog.currentLevel, 3);
      expect(benCatalog.currentLevel, 1);
      expect(benCatalog.generatedThrough, 15);
      expect(
        persistedAdaCatalog.descriptors[1]!.seed,
        isNot(benCatalog.descriptors[1]!.seed),
        reason: 'profile identity must participate in deterministic catalogs',
      );
      expect(
        persistedAdaCatalog.descriptors[1],
        isNot(benCatalog.descriptors[1]),
      );

      final benLevelOne = await controller.beginCurrentAttempt(
        profileId: ben.id,
        gameId: GameId.waterSort,
      );
      await controller.completeLevel(
        benLevelOne,
        const WaterSortOutcome(actualMoves: 10, parMoves: 7),
      );

      expect(
        container
            .read(overallLeaderboardProvider)
            .map((entry) => (entry.profileId, entry.completedLevels)),
        [(ada.id, 2), (ben.id, 1)],
      );
      expect(
        container
            .read(gameLeaderboardProvider(GameId.waterSort))
            .map((entry) => (entry.profileId, entry.completedLevels)),
        [(ada.id, 2), (ben.id, 1)],
      );

      await controller.prepareGame(
        profileId: ben.id,
        gameId: GameId.bubbleShooter,
      );
      for (var level = 1; level <= 2; level++) {
        final launch = await controller.beginCurrentAttempt(
          profileId: ben.id,
          gameId: GameId.bubbleShooter,
        );
        await controller.completeLevel(
          launch,
          const BubbleShooterOutcome(
            rawScore: 1000,
            shotsFired: 1,
            parShots: 1,
          ),
        );
      }
      expect(
        container
            .read(overallLeaderboardProvider)
            .map((entry) => (entry.profileId, entry.completedLevels)),
        [(ben.id, 3), (ada.id, 2)],
      );
      expect(
        container
            .read(gameLeaderboardProvider(GameId.waterSort))
            .map((entry) => (entry.profileId, entry.completedLevels)),
        [(ada.id, 2), (ben.id, 1)],
      );
      await controller.setActiveProfile(profileId: ada.id);

      final beforeReplay = harness.repository.durableState.profiles[ada.id]!;
      final beforeReplayProgress = beforeReplay.gameProgress[GameId.waterSort]!;
      final replay = await controller.beginReplayAttempt(
        profileId: ada.id,
        gameId: GameId.waterSort,
        level: 1,
      );
      final replayReceipt = await controller.completeLevel(
        replay,
        const WaterSortOutcome(actualMoves: 100, parMoves: 99),
      );
      final afterReplay = harness.repository.durableState.profiles[ada.id]!;
      final afterReplayProgress = afterReplay.gameProgress[GameId.waterSort]!;
      expect(replayReceipt.firstClear, isFalse);
      expect(replayReceipt.coinsAwarded, 0);
      expect(replayReceipt.currentLevelAfter, 3);
      expect(afterReplay.coins, beforeReplay.coins);
      expect(
        afterReplayProgress.currentLevel,
        beforeReplayProgress.currentLevel,
      );
      expect(
        afterReplayProgress.highestCompletedLevel,
        beforeReplayProgress.highestCompletedLevel,
      );
      expect(
        afterReplayProgress.badgeMilestones,
        beforeReplayProgress.badgeMilestones,
      );
      expect(afterReplayProgress.bestScores[1], 99);
      expect(afterReplay.gamesPlayed, beforeReplay.gamesPlayed + 1);
      expect(afterReplay.gamesWon, beforeReplay.gamesWon + 1);

      final openAdaLaunch = await controller.beginCurrentAttempt(
        profileId: ada.id,
        gameId: GameId.waterSort,
      );
      await controller.setActiveProfile(profileId: ben.id);
      final beforeStaleCompletion = harness.repository.durableState.toMap();
      await expectLater(
        controller.completeLevel(
          openAdaLaunch,
          const WaterSortOutcome(actualMoves: 1, parMoves: 1),
        ),
        throwsA(
          isA<GameProgressionException>().having(
            (error) => error.code,
            'code',
            GameProgressionError.staleAttempt,
          ),
        ),
      );
      expect(
        harness.repository.durableState.toMap(),
        beforeStaleCompletion,
        reason: 'a stale callback must not partially mutate either profile',
      );

      harness.stopContainer(container);
      container = harness.startContainer();
      final resumed = await container.read(gameProfilesProvider.future);
      controller = container.read(gameProfilesProvider.notifier);
      expect(resumed.activeProfileId, ben.id);
      expect(
        resumed.profiles[ada.id]!.gameProgress[GameId.waterSort]!.currentLevel,
        3,
      );
      expect(
        resumed.profiles[ben.id]!.gameProgress[GameId.waterSort]!.currentLevel,
        2,
      );
      expect(
        resumed.profiles[ada.id]!.gameProgress[GameId.waterSort]!.attempts,
        4,
      );
      expect(resumed.profiles[ada.id]!.gamesPlayed, 4);

      final overall = container.read(overallLeaderboardProvider);
      final waterSort = container.read(
        gameLeaderboardProvider(GameId.waterSort),
      );
      expect(overall.map((entry) => entry.profileId), [ben.id, ada.id]);
      expect(overall.map((entry) => entry.completedLevels), [3, 2]);
      expect(overall.map((entry) => entry.isActive), [isTrue, isFalse]);
      expect(waterSort.map((entry) => entry.profileId), [ada.id, ben.id]);
      expect(waterSort.map((entry) => entry.completedLevels), [2, 1]);

      await tester.pumpWidget(
        _testApp(container: container, home: const LeaderboardScreen()),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('leaderboard-active-profile-ben')),
        findsOneWidget,
      );
      expect(_text(tester, 'leaderboard-rank-profile-ada'), '#2');
      expect(_text(tester, 'leaderboard-completed-profile-ada'), '2 completed');

      final waterFilter = find.byKey(
        const ValueKey('leaderboard-filter-waterSort'),
      );
      await tester.ensureVisible(waterFilter);
      await tester.pump();
      await tester.tap(waterFilter);
      await tester.pump();
      expect(_text(tester, 'leaderboard-rank-profile-ada'), '#1');
      expect(_text(tester, 'leaderboard-rank-profile-ben'), '#2');
      expect(_text(tester, 'leaderboard-completed-profile-ben'), '1 completed');

      await controller.setActiveProfile(profileId: ada.id);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('leaderboard-active-profile-ada')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('leaderboard-active-profile-ben')),
        findsNothing,
      );

      final persistedReplayDescriptor = harness
          .repository
          .durableState
          .profiles[ada.id]!
          .gameProgress[GameId.waterSort]!
          .descriptors[1]!;
      final mapLaunches = <GameLaunch>[];
      await tester.pumpWidget(
        _testApp(
          container: container,
          home: GameLevelMapScreen(
            gameId: GameId.waterSort,
            onLaunchGame: mapLaunches.add,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('replay-level-1')));
      await tester.pumpAndSettle();
      expect(mapLaunches, hasLength(1));
      expect(mapLaunches.single.profileId, ada.id);
      expect(mapLaunches.single.gameId, GameId.waterSort);
      expect(mapLaunches.single.descriptor.level, 1);
      expect(mapLaunches.single.descriptor, persistedReplayDescriptor);
      expect(
        mapLaunches.single.descriptor.fingerprint,
        persistedReplayDescriptor.fingerprint,
      );
      expect(mapLaunches.single.playKind, GamePlayKind.replay);
      expect(
        harness
            .repository
            .durableState
            .profiles[ada.id]!
            .gameProgress[GameId.waterSort]!
            .activeAttempt
            ?.attemptId,
        mapLaunches.single.attemptId,
      );
    },
  );

  testWidgets(
    'legacy aggregates appear in the first named player while every game starts at level one',
    (tester) async {
      final harness = _IntegrationHarness(
        initialState: GameProfilesState(
          activeProfileId: null,
          profiles: const {},
          pendingLegacySnapshot: LegacyGameProgressSnapshot(
            coins: 135,
            gamesPlayed: 12,
            gamesWon: 7,
            bestScore: 92,
          ),
          legacyMigrationComplete: false,
        ),
        profileIds: const ['profile-me', 'profile-guest'],
      );
      addTearDown(harness.dispose);
      final container = harness.startContainer();

      await tester.pumpWidget(
        _testApp(container: container, home: const GamesScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('create-player')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('create-player')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('player-profile-name')),
        'Me',
      );
      await tester.tap(find.byKey(const ValueKey('save-player-profile')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Active player Me'), findsOneWidget);
      expect(_text(tester, 'games-stat-coins'), '135');
      expect(_text(tester, 'games-stat-wins'), '7');
      expect(_text(tester, 'games-stat-best'), '92');
      expect(
        find.text('12 games played · Progress stays on this device.'),
        findsOneWidget,
      );
      for (final gameId in GameId.values) {
        expect(_text(tester, 'game-level-${gameId.storageId}'), 'Level 1');
      }

      var durable = harness.repository.durableState;
      final imported = durable.profiles['profile-me']!;
      expect(durable.legacyMigrationComplete, isTrue);
      expect(durable.pendingLegacySnapshot, isNull);
      expect(imported.gameProgress, isEmpty);
      expect(imported.coins, 135);
      expect(imported.gamesPlayed, 12);
      expect(imported.gamesWon, 7);
      expect(imported.bestScore, 92);

      final guest = await container
          .read(gameProfilesProvider.notifier)
          .createProfile(name: 'Guest');
      durable = harness.repository.durableState;
      expect(guest.id, 'profile-guest');
      expect(guest.coins, 0);
      expect(guest.gamesPlayed, 0);
      expect(guest.gamesWon, 0);
      expect(guest.bestScore, 0);
      expect(durable.profiles['profile-me']!.coins, 135);
      expect(durable.profiles['profile-me']!.gamesPlayed, 12);
    },
  );
}

Widget _testApp({required ProviderContainer container, required Widget home}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: home,
      ),
    );

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

List<int> _levelsThrough(int end) => [
  for (var level = 1; level <= end; level++) level,
];

GameProfilesState _emptyState() => GameProfilesState(
  activeProfileId: null,
  profiles: const {},
  legacyMigrationComplete: true,
);

final class _IntegrationHarness {
  _IntegrationHarness({
    required GameProfilesState initialState,
    required List<String> profileIds,
  }) : repository = InMemoryGameProfilesRepository(initialState: initialState),
       _profileIds = List<String>.of(profileIds);

  final InMemoryGameProfilesRepository repository;
  final List<String> _profileIds;
  final Set<ProviderContainer> _containers = <ProviderContainer>{};
  int _profileIdIndex = 0;
  int _clockTick = 0;

  ProviderContainer startContainer() {
    final container = ProviderContainer(
      overrides: [
        gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
        gameProfileIdFactoryProvider.overrideWithValue(_nextProfileId),
        gameProfilesClockProvider.overrideWithValue(_now),
      ],
    );
    _containers.add(container);
    return container;
  }

  void stopContainer(ProviderContainer container) {
    if (_containers.remove(container)) container.dispose();
  }

  void dispose() {
    for (final container in _containers.toList(growable: false).reversed) {
      container.dispose();
    }
    _containers.clear();
  }

  String _nextProfileId() {
    if (_profileIdIndex >= _profileIds.length) {
      throw StateError('No deterministic profile ID remains');
    }
    return _profileIds[_profileIdIndex++];
  }

  DateTime _now() =>
      DateTime.utc(2026, 10, 24, 8).add(Duration(seconds: _clockTick++));
}
