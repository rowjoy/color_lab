import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_badge.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/presentation/badges_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  testWidgets('maps persisted badges onto every 20/40/60 gallery tile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final owner = _profile(
      id: 'profile-owner',
      name: 'Owner',
      completedByGame: const {
        GameId.bubbleShooter: 0,
        GameId.fruitPop: 20,
        GameId.waterSort: 40,
        GameId.rainbowRings: 60,
        GameId.colorMatch: 40,
      },
    );
    final repository = InMemoryGameProfilesRepository(
      initialState: _state(owner),
    );
    final harness = await _pumpBadges(tester, repository: repository);
    addTearDown(harness.dispose);

    try {
      await tester.pumpAndSettle();

      expect(find.text('Badges'), findsOneWidget);
      const earnedMilestones = {
        GameId.bubbleShooter: <int>{},
        GameId.fruitPop: {20},
        GameId.waterSort: {20, 40},
        GameId.rainbowRings: {20, 40, 60},
        GameId.colorMatch: {20, 40},
      };

      for (final gameId in GameId.values) {
        final gameLabel = _gameLabels[gameId]!;
        expect(find.text(gameLabel), findsOneWidget);
        for (final milestone in const [20, 40, 60]) {
          final tile = find.byKey(
            ValueKey('badge-${gameId.storageId}-$milestone'),
          );
          final earned = earnedMilestones[gameId]!.contains(milestone);
          final stateLabel = earned ? 'earned' : 'locked';

          expect(tile, findsOneWidget);
          expect(
            find.bySemanticsLabel(
              '$gameLabel Level $milestone badge, $stateLabel',
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: tile,
              matching: find.text(
                earned ? _earnedDateText[milestone]! : 'Locked',
              ),
            ),
            findsOneWidget,
          );
        }
      }
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('explains that a local player is required for badges', (
    tester,
  ) async {
    final repository = InMemoryGameProfilesRepository(
      initialState: _emptyState(),
    );
    final harness = await _pumpBadges(tester, repository: repository);
    addTearDown(harness.dispose);

    await tester.pumpAndSettle();

    expect(find.text('Badges'), findsOneWidget);
    expect(find.text('Create a player to earn badges.'), findsOneWidget);
    for (final gameId in GameId.values) {
      for (final milestone in const [20, 40, 60]) {
        expect(
          find.byKey(ValueKey('badge-${gameId.storageId}-$milestone')),
          findsNothing,
        );
      }
    }
  });

  testWidgets('reacts when the durable active profile changes', (tester) async {
    tester.view.physicalSize = const Size(900, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final owner = _profile(
      id: 'profile-owner',
      name: 'Owner',
      completedByGame: const {GameId.waterSort: 20},
    );
    final guest = _profile(id: 'profile-guest', name: 'Guest');
    final repository = InMemoryGameProfilesRepository(
      initialState: GameProfilesState(
        activeProfileId: owner.id,
        profiles: {owner.id: owner, guest.id: guest},
        legacyMigrationComplete: true,
      ),
    );
    final harness = await _pumpBadges(tester, repository: repository);
    addTearDown(harness.dispose);

    try {
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Water Sort Level 20 badge, earned'),
        findsOneWidget,
      );
      expect(find.text('Earned Oct 20, 2026'), findsOneWidget);

      await harness.container
          .read(gameProfilesProvider.notifier)
          .setActiveProfile(profileId: guest.id);
      await tester.pumpAndSettle();

      expect(repository.durableState.activeProfileId, guest.id);
      expect(
        find.bySemanticsLabel('Water Sort Level 20 badge, earned'),
        findsNothing,
      );
      for (final gameId in GameId.values) {
        final gameLabel = _gameLabels[gameId]!;
        for (final milestone in const [20, 40, 60]) {
          expect(
            find.bySemanticsLabel('$gameLabel Level $milestone badge, locked'),
            findsOneWidget,
          );
        }
      }
      expect(find.text('Earned Oct 20, 2026'), findsNothing);
      expect(find.text('Locked'), findsNWidgets(15));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('badge-waterSort-20')),
          matching: find.text('Locked'),
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'fits 360dp at 2x text with badge semantics in ${themeMode.name}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        final player = _profile(id: 'profile-player', name: 'Player');
        final repository = InMemoryGameProfilesRepository(
          initialState: _state(player),
        );
        final harness = await _pumpBadges(
          tester,
          repository: repository,
          themeMode: themeMode,
          textScaler: const TextScaler.linear(2),
        );
        addTearDown(harness.dispose);

        try {
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.bySemanticsLabel('Bubble Shooter Level 20 badge, locked'),
            findsOneWidget,
          );

          await tester.fling(
            find.byType(Scrollable).first,
            const Offset(0, -5000),
            4000,
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.bySemanticsLabel('Color Match Level 60 badge, locked'),
            findsOneWidget,
          );
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

const _gameLabels = {
  GameId.bubbleShooter: 'Bubble Shooter',
  GameId.fruitPop: 'Fruit & Veggie Pop',
  GameId.waterSort: 'Water Sort',
  GameId.rainbowRings: 'Rainbow Rings',
  GameId.colorMatch: 'Color Match',
};

const _earnedDateText = {
  20: 'Earned Oct 20, 2026',
  40: 'Earned Oct 21, 2026',
  60: 'Earned Oct 22, 2026',
};

final class _BadgesHarness {
  const _BadgesHarness(this.container);

  final ProviderContainer container;

  void dispose() => container.dispose();
}

Future<_BadgesHarness> _pumpBadges(
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const BadgesScreen(),
      ),
    ),
  );
  await tester.pump();
  return _BadgesHarness(container);
}

GameProfilesState _emptyState() => GameProfilesState(
  activeProfileId: null,
  profiles: const {},
  legacyMigrationComplete: true,
);

GameProfilesState _state(PlayerProfile profile) => GameProfilesState(
  activeProfileId: profile.id,
  profiles: {profile.id: profile},
  legacyMigrationComplete: true,
);

PlayerProfile _profile({
  required String id,
  required String name,
  Map<GameId, int> completedByGame = const {},
}) {
  final progress = <GameId, PlayerGameProgress>{
    for (final entry in completedByGame.entries)
      entry.key: _progress(entry.key, entry.value),
  };
  final badges = <String, GameBadge>{};
  for (final entry in progress.entries) {
    for (final milestone in entry.value.badgeMilestones) {
      final badge = GameBadge(
        gameId: entry.key,
        milestone: milestone,
        earnedAt: DateTime.utc(2026, 10, 19 + milestone ~/ 20, 8),
      );
      badges[badge.id] = badge;
    }
  }
  final completedCount = completedByGame.values.fold<int>(
    0,
    (total, completed) => total + completed,
  );

  return PlayerProfile(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026, 10, 1, 8),
    updatedAt: DateTime.utc(2026, 10, 24, 10),
    gamesPlayed: completedCount,
    gamesWon: completedCount,
    bestScore: completedCount == 0 ? 0 : 90,
    gameProgress: progress,
    badges: badges,
  );
}

PlayerGameProgress _progress(GameId gameId, int completed) {
  final generatedThrough = completed < 15 ? 15 : ((completed + 14) ~/ 15) * 15;
  final descriptors = <int, GameLevelDescriptor>{
    for (var level = 1; level <= generatedThrough; level++)
      level: _descriptor(gameId, level),
  };
  return PlayerGameProgress(
    gameId: gameId,
    currentLevel: completed + 1,
    generatedThrough: generatedThrough,
    descriptors: descriptors,
    fingerprints: descriptors.values
        .map((descriptor) => descriptor.fingerprint)
        .toSet(),
    clearedLevels: {for (var level = 1; level <= completed; level++) level},
    bestScores: {for (var level = 1; level <= completed; level++) level: 90},
    attempts: completed,
    wins: completed,
    attemptSequence: completed,
    highestCompletedLevel: completed,
    badgeMilestones: {
      for (var milestone = 20; milestone <= completed; milestone += 20)
        milestone,
    },
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
