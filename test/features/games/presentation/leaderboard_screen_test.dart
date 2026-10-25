import 'dart:ui' show Tristate;

import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/presentation/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  testWidgets(
    'overall and all five game filters show the exact derived ranking',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final repository = InMemoryGameProfilesRepository(
          initialState: _rankingState(activeProfileId: 'alpha'),
        );
        final harness = await _pumpLeaderboard(tester, repository: repository);
        addTearDown(harness.dispose);
        await tester.pumpAndSettle();

        expect(find.text('Leaderboard'), findsOneWidget);
        for (final ranking in _rankings) {
          final filter = find.byKey(
            ValueKey('leaderboard-filter-${ranking.filterId}'),
          );
          expect(filter, findsOneWidget);
          expect(
            find.descendant(of: filter, matching: find.text(ranking.label)),
            findsOneWidget,
          );
        }

        for (final ranking in _rankings) {
          await _selectFilter(tester, ranking);
          _expectRanking(tester, ranking);
        }
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('profiles with no progress remain ranked at zero', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final saver = _profile(id: 'saver', name: 'Saver', coins: 9);
      final newPlayer = _profile(
        id: 'new-player',
        name: 'New Player',
        coins: 0,
      );
      final repository = InMemoryGameProfilesRepository(
        initialState: GameProfilesState(
          activeProfileId: newPlayer.id,
          profiles: {newPlayer.id: newPlayer, saver.id: saver},
          legacyMigrationComplete: true,
        ),
      );
      final harness = await _pumpLeaderboard(tester, repository: repository);
      addTearDown(harness.dispose);
      await tester.pumpAndSettle();

      _expectRanking(
        tester,
        const _RankingExpectation(
          filterId: 'overall',
          label: 'Overall',
          semanticLabel: 'Show Overall leaderboard',
          profileIds: ['saver', 'new-player'],
          names: ['Saver', 'New Player'],
          completedLevels: [0, 0],
          coins: [9, 0],
        ),
      );

      const waterSort = _RankingExpectation(
        filterId: 'waterSort',
        label: 'Water Sort',
        semanticLabel: 'Show Water Sort leaderboard',
        profileIds: ['saver', 'new-player'],
        names: ['Saver', 'New Player'],
        completedLevels: [0, 0],
        coins: [9, 0],
      );
      await _selectFilter(tester, waterSort);
      _expectRanking(tester, waterSort);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('an empty state stays available across leaderboard filters', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = InMemoryGameProfilesRepository(
        initialState: _emptyState(),
      );
      final harness = await _pumpLeaderboard(tester, repository: repository);
      addTearDown(harness.dispose);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('leaderboard-empty')), findsOneWidget);
      expect(find.text('No players yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('leaderboard-list')), findsNothing);

      await _selectFilter(
        tester,
        const _RankingExpectation(
          filterId: 'rainbowRings',
          label: 'Rainbow Rings',
          semanticLabel: 'Show Rainbow Rings leaderboard',
          profileIds: [],
          names: [],
          completedLevels: [],
          coins: [],
        ),
      );
      expect(find.byKey(const ValueKey('leaderboard-empty')), findsOneWidget);
      expect(find.text('No players yet'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('active-player highlight reacts to a durable profile switch', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final repository = InMemoryGameProfilesRepository(
        initialState: _rankingState(activeProfileId: 'alpha'),
      );
      final harness = await _pumpLeaderboard(tester, repository: repository);
      addTearDown(harness.dispose);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('leaderboard-active-alpha')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Rank 1, Alpha, 15 levels completed, 50 coins, active player',
        ),
        findsOneWidget,
      );

      await harness.container
          .read(gameProfilesProvider.notifier)
          .setActiveProfile(profileId: 'beta');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('leaderboard-active-alpha')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('leaderboard-active-beta')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Rank 5, Beta, 15 levels completed, 10 coins, active player',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Rank 1, Alpha, 15 levels completed, 50 coins, active player',
        ),
        findsNothing,
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    '360dp dark layout supports 2x text, scrolling, and useful semantics',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        final repository = InMemoryGameProfilesRepository(
          initialState: _rankingState(activeProfileId: 'alpha'),
        );
        final harness = await _pumpLeaderboard(
          tester,
          repository: repository,
          themeMode: ThemeMode.dark,
          textScaler: const TextScaler.linear(2),
        );
        addTearDown(harness.dispose);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('Leaderboard filters'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Show Overall leaderboard'),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Show Overall leaderboard'))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        expect(
          find.bySemanticsLabel(
            'Rank 1, Alpha, 15 levels completed, 50 coins, active player',
          ),
          findsOneWidget,
        );

        const colorMatch = _RankingExpectation(
          filterId: 'colorMatch',
          label: 'Color Match',
          semanticLabel: 'Show Color Match leaderboard',
          profileIds: ['echo', 'alpha', 'beta', 'coral', 'delta'],
          names: ['Echo', 'Alpha', 'Beta', 'Coral', 'Delta'],
          completedLevels: [5, 4, 3, 2, 1],
          coins: [20, 50, 10, 30, 50],
        );
        await _selectFilter(tester, colorMatch);
        expect(tester.takeException(), isNull);
        expect(
          find.bySemanticsLabel(
            'Rank 2, Alpha, 4 levels completed, 50 coins, active player',
          ),
          findsOneWidget,
        );

        await tester.drag(
          find.byKey(const ValueKey('leaderboard-list')),
          const Offset(0, -500),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );
}

const List<_RankingExpectation> _rankings = [
  _RankingExpectation(
    filterId: 'overall',
    label: 'Overall',
    semanticLabel: 'Show Overall leaderboard',
    profileIds: ['alpha', 'delta', 'coral', 'echo', 'beta'],
    names: ['Alpha', 'Delta', 'Coral', 'Echo', 'Beta'],
    completedLevels: [15, 15, 15, 15, 15],
    coins: [50, 50, 30, 20, 10],
  ),
  _RankingExpectation(
    filterId: 'bubbleShooter',
    label: 'Bubble Shooter',
    semanticLabel: 'Show Bubble Shooter leaderboard',
    profileIds: ['alpha', 'beta', 'coral', 'delta', 'echo'],
    names: ['Alpha', 'Beta', 'Coral', 'Delta', 'Echo'],
    completedLevels: [5, 4, 3, 2, 1],
    coins: [50, 10, 30, 50, 20],
  ),
  _RankingExpectation(
    filterId: 'fruitPop',
    label: 'Fruit & Veggie Pop',
    semanticLabel: 'Show Fruit & Veggie Pop leaderboard',
    profileIds: ['beta', 'coral', 'delta', 'echo', 'alpha'],
    names: ['Beta', 'Coral', 'Delta', 'Echo', 'Alpha'],
    completedLevels: [5, 4, 3, 2, 1],
    coins: [10, 30, 50, 20, 50],
  ),
  _RankingExpectation(
    filterId: 'waterSort',
    label: 'Water Sort',
    semanticLabel: 'Show Water Sort leaderboard',
    profileIds: ['coral', 'delta', 'echo', 'alpha', 'beta'],
    names: ['Coral', 'Delta', 'Echo', 'Alpha', 'Beta'],
    completedLevels: [5, 4, 3, 2, 1],
    coins: [30, 50, 20, 50, 10],
  ),
  _RankingExpectation(
    filterId: 'rainbowRings',
    label: 'Rainbow Rings',
    semanticLabel: 'Show Rainbow Rings leaderboard',
    profileIds: ['delta', 'echo', 'alpha', 'beta', 'coral'],
    names: ['Delta', 'Echo', 'Alpha', 'Beta', 'Coral'],
    completedLevels: [5, 4, 3, 2, 1],
    coins: [50, 20, 50, 10, 30],
  ),
  _RankingExpectation(
    filterId: 'colorMatch',
    label: 'Color Match',
    semanticLabel: 'Show Color Match leaderboard',
    profileIds: ['echo', 'alpha', 'beta', 'coral', 'delta'],
    names: ['Echo', 'Alpha', 'Beta', 'Coral', 'Delta'],
    completedLevels: [5, 4, 3, 2, 1],
    coins: [20, 50, 10, 30, 50],
  ),
];

final class _RankingExpectation {
  const _RankingExpectation({
    required this.filterId,
    required this.label,
    required this.semanticLabel,
    required this.profileIds,
    required this.names,
    required this.completedLevels,
    required this.coins,
  });

  final String filterId;
  final String label;
  final String semanticLabel;
  final List<String> profileIds;
  final List<String> names;
  final List<int> completedLevels;
  final List<int> coins;
}

Future<void> _selectFilter(
  WidgetTester tester,
  _RankingExpectation ranking,
) async {
  final filter = find.byKey(ValueKey('leaderboard-filter-${ranking.filterId}'));
  await tester.ensureVisible(filter);
  await tester.pumpAndSettle();
  await tester.tap(filter);
  await tester.pumpAndSettle();

  expect(
    tester
        .getSemantics(find.bySemanticsLabel(ranking.semanticLabel))
        .getSemanticsData()
        .flagsCollection
        .isSelected,
    Tristate.isTrue,
  );
}

void _expectRanking(WidgetTester tester, _RankingExpectation ranking) {
  expect(ranking.profileIds, hasLength(ranking.completedLevels.length));
  expect(ranking.profileIds, hasLength(ranking.coins.length));
  expect(ranking.profileIds, hasLength(ranking.names.length));

  Finder? previousRow;
  for (var index = 0; index < ranking.profileIds.length; index++) {
    final profileId = ranking.profileIds[index];
    final row = find.byKey(ValueKey('leaderboard-row-$profileId'));
    expect(row, findsOneWidget);
    expect(_text(tester, 'leaderboard-rank-$profileId'), '#${index + 1}');
    expect(
      _text(tester, 'leaderboard-completed-$profileId'),
      '${ranking.completedLevels[index]} completed',
    );
    expect(
      _text(tester, 'leaderboard-coins-$profileId'),
      '${ranking.coins[index]} coins',
    );
    expect(
      find.descendant(of: row, matching: find.text(ranking.names[index])),
      findsOneWidget,
    );
    if (previousRow != null) {
      expect(
        tester.getTopLeft(previousRow).dy,
        lessThan(tester.getTopLeft(row).dy),
      );
    }
    previousRow = row;
  }
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

final class _LeaderboardHarness {
  const _LeaderboardHarness(this.container);

  final ProviderContainer container;

  void dispose() => container.dispose();
}

Future<_LeaderboardHarness> _pumpLeaderboard(
  WidgetTester tester, {
  required InMemoryGameProfilesRepository repository,
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final container = ProviderContainer(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const LeaderboardScreen(),
      ),
    ),
  );
  await tester.pump();
  return _LeaderboardHarness(container);
}

GameProfilesState _emptyState() => GameProfilesState(
  activeProfileId: null,
  profiles: const {},
  legacyMigrationComplete: true,
);

GameProfilesState _rankingState({required String activeProfileId}) {
  final profiles = [
    _profile(
      id: 'echo',
      name: 'Echo',
      coins: 20,
      completedByGame: const {
        GameId.bubbleShooter: 1,
        GameId.fruitPop: 2,
        GameId.waterSort: 3,
        GameId.rainbowRings: 4,
        GameId.colorMatch: 5,
      },
    ),
    _profile(
      id: 'beta',
      name: 'Beta',
      coins: 10,
      completedByGame: const {
        GameId.bubbleShooter: 4,
        GameId.fruitPop: 5,
        GameId.waterSort: 1,
        GameId.rainbowRings: 2,
        GameId.colorMatch: 3,
      },
    ),
    _profile(
      id: 'delta',
      name: 'Delta',
      coins: 50,
      completedByGame: const {
        GameId.bubbleShooter: 2,
        GameId.fruitPop: 3,
        GameId.waterSort: 4,
        GameId.rainbowRings: 5,
        GameId.colorMatch: 1,
      },
    ),
    _profile(
      id: 'alpha',
      name: 'Alpha',
      coins: 50,
      completedByGame: const {
        GameId.bubbleShooter: 5,
        GameId.fruitPop: 1,
        GameId.waterSort: 2,
        GameId.rainbowRings: 3,
        GameId.colorMatch: 4,
      },
    ),
    _profile(
      id: 'coral',
      name: 'Coral',
      coins: 30,
      completedByGame: const {
        GameId.bubbleShooter: 3,
        GameId.fruitPop: 4,
        GameId.waterSort: 5,
        GameId.rainbowRings: 1,
        GameId.colorMatch: 2,
      },
    ),
  ];
  return GameProfilesState(
    activeProfileId: activeProfileId,
    profiles: {for (final profile in profiles) profile.id: profile},
    legacyMigrationComplete: true,
  );
}

PlayerProfile _profile({
  required String id,
  required String name,
  required int coins,
  Map<GameId, int> completedByGame = const {},
}) {
  final progress = <GameId, PlayerGameProgress>{
    for (final entry in completedByGame.entries)
      entry.key: _progress(entry.key, entry.value),
  };
  final completed = completedByGame.values.fold<int>(
    0,
    (total, value) => total + value,
  );
  return PlayerProfile(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026, 10, 24, 8),
    updatedAt: DateTime.utc(2026, 10, 24, 9),
    coins: coins,
    gamesPlayed: completed,
    gamesWon: completed,
    bestScore: completed == 0 ? 0 : 80,
    gameProgress: progress,
  );
}

PlayerGameProgress _progress(GameId gameId, int completed) {
  final descriptors = <int, GameLevelDescriptor>{
    for (var level = 1; level <= completed; level++)
      level: _descriptor(gameId, level),
  };
  return PlayerGameProgress(
    gameId: gameId,
    currentLevel: completed + 1,
    generatedThrough: completed,
    descriptors: descriptors,
    fingerprints: descriptors.values
        .map((descriptor) => descriptor.fingerprint)
        .toSet(),
    clearedLevels: {for (var level = 1; level <= completed; level++) level},
    bestScores: {for (var level = 1; level <= completed; level++) level: 80},
    attempts: completed,
    wins: completed,
    attemptSequence: completed,
    highestCompletedLevel: completed,
  );
}

GameLevelDescriptor _descriptor(GameId gameId, int level) {
  final identity = (GameId.values.indexOf(gameId) + 1) * 1000 + level;
  return GameLevelDescriptor(
    gameId: gameId,
    level: level,
    seed: identity,
    generatorVersion: 1,
    retrySalt: 0,
    fingerprint: identity.toRadixString(16).padLeft(64, '0'),
    tier: GameTier.forLevel(level),
    levelPressure: levelPressureFor(level),
  );
}
