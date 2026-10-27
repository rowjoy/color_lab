import 'dart:async';

import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/presentation/games_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  testWidgets('shows loading, recoverable load error, and retry', (
    tester,
  ) async {
    final repository = InMemoryGameProfilesRepository(
      initialState: _emptyState(),
    )..loadGate = Completer<void>();
    final harness = await _pumpHub(tester, repository: repository);
    addTearDown(harness.dispose);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.failLoad = true;
    repository.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Game profiles could not be opened on this device.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    repository.failLoad = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Create Player'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('requires a named player before showing any game cards', (
    tester,
  ) async {
    final repository = InMemoryGameProfilesRepository(
      initialState: _emptyState(),
    );
    final harness = await _pumpHub(tester, repository: repository);
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    expect(find.text('Create your player'), findsOneWidget);
    expect(find.text('Create Player'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-player')), findsOneWidget);
    for (final gameId in GameId.values) {
      expect(
        find.byKey(ValueKey('game-card-${gameId.storageId}')),
        findsNothing,
      );
    }
    expect(find.byKey(const ValueKey('games-level-grid')), findsNothing);
    expect(find.text('Choose difficulty'), findsNothing);
  });

  testWidgets('active profile controls all aggregate and per-game stats', (
    tester,
  ) async {
    final owner = _profile(
      id: 'profile-owner',
      name: 'Owner',
      coins: 321,
      gamesPlayed: 100,
      gamesWon: 60,
      bestScore: 98,
      completedByGame: {
        GameId.bubbleShooter: 2,
        GameId.fruitPop: 0,
        GameId.waterSort: 5,
        GameId.rainbowRings: 9,
        GameId.colorMatch: 19,
      },
    );
    final guest = _profile(
      id: 'profile-guest',
      name: 'Guest',
      coins: 7,
      gamesPlayed: 2,
      gamesWon: 1,
      bestScore: 44,
      completedByGame: {GameId.waterSort: 1},
    );
    final repository = InMemoryGameProfilesRepository(
      initialState: GameProfilesState(
        activeProfileId: owner.id,
        profiles: {owner.id: owner, guest.id: guest},
        legacyMigrationComplete: true,
      ),
    );
    final harness = await _pumpHub(tester, repository: repository);
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('games-profile-chip')), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);
    expect(_text(tester, 'games-stat-coins'), '321');
    expect(_text(tester, 'games-stat-wins'), '60');
    expect(_text(tester, 'games-stat-best'), '98');
    expect(_text(tester, 'game-level-bubbleShooter'), 'Level 3');
    expect(_text(tester, 'game-tier-waterSort'), 'Easy');
    expect(_text(tester, 'game-completed-rainbowRings'), '9 completed');
    expect(_text(tester, 'game-level-colorMatch'), 'Level 20');
    expect(_text(tester, 'game-tier-colorMatch'), 'Hard');
    expect(_text(tester, 'game-next-badge-colorMatch'), 'Next badge: Level 20');

    await tester.tap(find.byKey(const ValueKey('games-profile-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guest').last);
    await tester.pumpAndSettle();

    expect(repository.durableState.activeProfileId, guest.id);
    expect(_text(tester, 'games-stat-coins'), '7');
    expect(_text(tester, 'games-stat-wins'), '1');
    expect(_text(tester, 'games-stat-best'), '44');
    expect(_text(tester, 'game-level-waterSort'), 'Level 2');
    expect(_text(tester, 'game-level-bubbleShooter'), 'Level 1');
  });

  testWidgets('Play waits for its durable launch and errors never navigate', (
    tester,
  ) async {
    final profile = _profile(
      id: 'profile-1',
      name: 'Player',
      coins: 50,
      gamesPlayed: 5,
      gamesWon: 5,
      bestScore: 90,
      completedByGame: {for (final gameId in GameId.values) gameId: 1},
    );
    final repository = InMemoryGameProfilesRepository(
      initialState: GameProfilesState(
        activeProfileId: profile.id,
        profiles: {profile.id: profile},
        legacyMigrationComplete: true,
      ),
    );
    final launches = <GameLaunch>[];
    final maps = <GameId>[];
    final harness = await _pumpHub(
      tester,
      repository: repository,
      onLaunchGame: launches.add,
      onOpenMap: maps.add,
    );
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    repository.writeGate = Completer<void>();
    await _tapPlay(tester, 'waterSort');
    await tester.pump();
    await _pumpUntil(tester, () => repository.writeAttempts == 1);
    expect(launches, isEmpty);
    expect(find.text('Choose difficulty'), findsNothing);
    expect(find.byKey(const ValueKey('games-level-grid')), findsNothing);

    repository.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(launches, hasLength(1));
    expect(launches.single.gameId, GameId.waterSort);
    expect(launches.single.attemptId, 'profile-1:waterSort:2');

    await tester.tap(find.byKey(const ValueKey('map-waterSort')));
    await tester.pump();
    expect(maps, [GameId.waterSort]);

    repository.writeGate = null;
    repository.failWrite = true;
    await _tapPlay(tester, 'fruitPop');
    await tester.pumpAndSettle();
    expect(launches, hasLength(1));
    expect(
      find.text('Fruit & Veggie Pop could not be started. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a pending launch locks every game card', (tester) async {
    final profile = _profile(
      id: 'profile-1',
      name: 'Player',
      coins: 0,
      gamesPlayed: 0,
      gamesWon: 0,
      bestScore: 0,
      completedByGame: {for (final gameId in GameId.values) gameId: 1},
    );
    final repository = InMemoryGameProfilesRepository(
      initialState: GameProfilesState(
        activeProfileId: profile.id,
        profiles: {profile.id: profile},
        legacyMigrationComplete: true,
      ),
    )..writeGate = Completer<void>();
    final launches = <GameLaunch>[];
    final harness = await _pumpHub(
      tester,
      repository: repository,
      onLaunchGame: launches.add,
    );
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    await _tapPlay(tester, 'waterSort');
    await tester.pump();
    await _pumpUntil(tester, () => repository.writeAttempts == 1);
    await _tapPlay(tester, 'fruitPop');
    await tester.pump();
    expect(repository.writeAttempts, 1);

    repository.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(launches.map((launch) => launch.gameId), [GameId.waterSort]);
  });

  testWidgets(
    'profile switch during held resume never launches the previous player',
    (tester) async {
      final ownerBase = _profile(
        id: 'profile-owner',
        name: 'Owner',
        coins: 0,
        gamesPlayed: 1,
        gamesWon: 0,
        bestScore: 0,
        completedByGame: {GameId.waterSort: 0},
      );
      final ownerProgress = ownerBase.gameProgress[GameId.waterSort]!;
      final descriptor = ownerProgress.descriptors[1]!;
      final owner = ownerBase.copyWith(
        gameProgress: {
          GameId.waterSort: ownerProgress.copyWith(
            attempts: 1,
            attemptSequence: 1,
            activeAttempt: ActiveGameAttempt(
              attemptId: 'profile-owner:waterSort:1',
              sequence: 1,
              level: 1,
              playKind: GamePlayKind.current,
              descriptorFingerprint: descriptor.fingerprint,
              startedAt: DateTime.utc(2026, 10, 24, 9),
            ),
          ),
        },
      );
      final guest = _profile(
        id: 'profile-guest',
        name: 'Guest',
        coins: 0,
        gamesPlayed: 0,
        gamesWon: 0,
        bestScore: 0,
        completedByGame: const {},
      );
      final repository = InMemoryGameProfilesRepository(
        initialState: GameProfilesState(
          activeProfileId: owner.id,
          profiles: {owner.id: owner, guest.id: guest},
          legacyMigrationComplete: true,
        ),
      );
      final launches = <GameLaunch>[];
      final harness = await _pumpHub(
        tester,
        repository: repository,
        onLaunchGame: launches.add,
      );
      addTearDown(harness.dispose);
      await tester.pumpAndSettle();

      repository.writeGate = Completer<void>();
      await _tapPlay(tester, 'waterSort');
      await tester.pump();
      await _pumpUntil(tester, () => repository.writeAttempts == 1);
      expect(
        tester
            .widget<ActionChip>(
              find.byKey(const ValueKey('games-profile-chip')),
            )
            .onPressed,
        isNull,
      );

      final switchFuture = harness.container
          .read(gameProfilesProvider.notifier)
          .setActiveProfile(profileId: guest.id);
      repository.writeGate!.complete();
      await switchFuture;
      await tester.pumpAndSettle();

      expect(repository.durableState.activeProfileId, guest.id);
      expect(launches, isEmpty);
      final persistedOwner = repository.durableState.profiles[owner.id]!;
      expect(persistedOwner.gamesPlayed, 1);
      expect(
        persistedOwner.gameProgress[GameId.waterSort]!.activeAttempt?.attemptId,
        'profile-owner:waterSort:1',
      );
    },
  );

  testWidgets(
    'profile switch during held new attempt never writes for the old player',
    (tester) async {
      final owner = _profile(
        id: 'profile-owner',
        name: 'Owner',
        coins: 0,
        gamesPlayed: 0,
        gamesWon: 0,
        bestScore: 0,
        completedByGame: {GameId.waterSort: 0},
      );
      final guest = _profile(
        id: 'profile-guest',
        name: 'Guest',
        coins: 0,
        gamesPlayed: 0,
        gamesWon: 0,
        bestScore: 0,
        completedByGame: const {},
      );
      final repository = InMemoryGameProfilesRepository(
        initialState: GameProfilesState(
          activeProfileId: owner.id,
          profiles: {owner.id: owner, guest.id: guest},
          legacyMigrationComplete: true,
        ),
      );
      final launches = <GameLaunch>[];
      final harness = await _pumpHub(
        tester,
        repository: repository,
        onLaunchGame: launches.add,
      );
      addTearDown(harness.dispose);
      await tester.pumpAndSettle();

      repository.writeGate = Completer<void>();
      await _tapPlay(tester, 'waterSort');
      await tester.pump();
      await _pumpUntil(tester, () => repository.writeAttempts == 1);
      expect(
        tester
            .widget<ActionChip>(
              find.byKey(const ValueKey('games-profile-chip')),
            )
            .onPressed,
        isNull,
      );

      final switchFuture = harness.container
          .read(gameProfilesProvider.notifier)
          .setActiveProfile(profileId: guest.id);
      repository.writeGate!.complete();
      await switchFuture;
      await tester.pumpAndSettle();

      expect(repository.durableState.activeProfileId, guest.id);
      expect(launches, isEmpty);
      final persistedOwner = repository.durableState.profiles[owner.id]!;
      expect(persistedOwner.gamesPlayed, 0);
      expect(persistedOwner.gameProgress[GameId.waterSort]!.attempts, 0);
      expect(
        persistedOwner.gameProgress[GameId.waterSort]!.activeAttempt,
        isNull,
      );
    },
  );

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'five-game hub fits 360dp at 2x text with semantics in ${themeMode.name}',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        final profile = _profile(
          id: 'profile-1',
          name: 'Player',
          coins: 50,
          gamesPlayed: 5,
          gamesWon: 5,
          bestScore: 90,
          completedByGame: {for (final gameId in GameId.values) gameId: 2},
        );
        final repository = InMemoryGameProfilesRepository(
          initialState: GameProfilesState(
            activeProfileId: profile.id,
            profiles: {profile.id: profile},
            legacyMigrationComplete: true,
          ),
        );
        final harness = await _pumpHub(
          tester,
          repository: repository,
          themeMode: themeMode,
          textScaler: const TextScaler.linear(2),
        );
        addTearDown(harness.dispose);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.bySemanticsLabel('Active player Player'), findsOneWidget);
        expect(find.byTooltip('Play Bubble Shooter'), findsOneWidget);
        expect(find.byTooltip('Open Bubble Shooter level map'), findsOneWidget);
        expect(find.byKey(const ValueKey('games-badges')), findsOneWidget);
        expect(find.byKey(const ValueKey('games-leaderboard')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('game-card-colorMatch')),
          findsOneWidget,
        );

        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -1800),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}

final class _HubHarness {
  const _HubHarness(this.container);
  final ProviderContainer container;
  void dispose() => container.dispose();
}

Future<_HubHarness> _pumpHub(
  WidgetTester tester, {
  required InMemoryGameProfilesRepository repository,
  ValueChanged<GameLaunch>? onLaunchGame,
  ValueChanged<GameId>? onOpenMap,
  VoidCallback? onOpenBadges,
  VoidCallback? onOpenLeaderboard,
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final container = ProviderContainer(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      gameAdapterRegistryProvider.overrideWithValue(_TestRegistry()),
      gameProfilesClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 24, 10),
      ),
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
        home: GamesScreen(
          onLaunchGame: onLaunchGame,
          onOpenMap: onOpenMap,
          onOpenBadges: onOpenBadges,
          onOpenLeaderboard: onOpenLeaderboard,
        ),
      ),
    ),
  );
  await tester.pump();
  return _HubHarness(container);
}

String _text(WidgetTester tester, String key) {
  final keyed = find.byKey(ValueKey(key));
  final widget = tester.widget(keyed);
  if (widget is Text) return widget.data!;
  return tester
      .widget<Text>(find.descendant(of: keyed, matching: find.byType(Text)))
      .data!;
}

GameProfilesState _emptyState() => GameProfilesState(
  activeProfileId: null,
  profiles: const {},
  legacyMigrationComplete: true,
);

PlayerProfile _profile({
  required String id,
  required String name,
  required int coins,
  required int gamesPlayed,
  required int gamesWon,
  required int bestScore,
  required Map<GameId, int> completedByGame,
}) {
  final progress = <GameId, PlayerGameProgress>{
    for (final entry in completedByGame.entries)
      entry.key: _progress(entry.key, entry.value),
  };
  return PlayerProfile(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026, 10, 24, 8),
    updatedAt: DateTime.utc(2026, 10, 24, 9),
    coins: coins,
    gamesPlayed: gamesPlayed,
    gamesWon: gamesWon,
    bestScore: bestScore,
    gameProgress: progress,
  );
}

PlayerGameProgress _progress(GameId gameId, int completed) {
  final generatedThrough = completed < 15 ? 15 : 30;
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

final class _TestRegistry implements GameLevelAdapterRegistry {
  _TestRegistry()
    : _adapters = {
        for (final gameId in GameId.values) gameId: _TestAdapter(gameId),
      };
  final Map<GameId, _TestAdapter> _adapters;
  @override
  GameLevelAdapter adapterFor(GameId gameId) => _adapters[gameId]!;
}

final class _TestAdapter implements GameLevelAdapter {
  const _TestAdapter(this.gameId);
  @override
  final GameId gameId;
  @override
  int get currentGeneratorVersion => 1;
  @override
  bool supportsVersion(int version) => version == 1;
  @override
  GameLevelLayout build(GameLevelDescriptor descriptor) =>
      _TestLayout('${gameId.storageId}:${descriptor.level}:${descriptor.seed}');
  @override
  int normalizeScore(GameLevelOutcome outcome) =>
      throw UnsupportedError('No completion in Games hub tests');
}

final class _TestLayout implements GameLevelLayout {
  const _TestLayout(this.canonicalSignature);
  @override
  final String canonicalSignature;
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.pump();
  }
  if (!condition()) throw StateError('Timed out waiting for test boundary');
}

Future<void> _tapPlay(WidgetTester tester, String gameId) async {
  final play = find.byKey(ValueKey('play-$gameId'));
  await tester.ensureVisible(play);
  await tester.pump();
  await tester.tap(play);
}
