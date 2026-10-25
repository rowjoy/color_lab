import 'dart:async';

import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/adapters/fruit_pop_level_adapter.dart';
import 'package:color_lab/features/games/domain/fruit_pop_game.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/presentation/fruit_pop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  testWidgets('builds the descriptor board and shows persisted metadata', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    var mapOpens = 0;
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _oneMoveLayout(descriptor.level, target: 3000),
      onOpenMap: () => mapOpens++,
    );
    addTearDown(harness.dispose);

    expect(find.text('Level 10'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.byKey(const ValueKey('fruit-pop-board')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('fruit-cell-0-0')),
        matching: find.text('🍎'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('fruit-cell-0-1')),
        matching: find.text('🥕'),
      ),
      findsOneWidget,
    );
    expect(find.text('Choose difficulty'), findsNothing);

    await tester.tap(find.text('Map'));
    await tester.pump();
    expect(mapOpens, 1);
  });

  testWidgets('Restart durably begins a fresh attempt on the same level', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _oneMoveLayout(descriptor.level, target: 3000),
    );
    addTearDown(harness.dispose);
    harness.repository.writeGate = Completer<void>();

    await tester.tap(find.byTooltip('Restart level'));
    await tester.pump();
    await _pumpUntil(tester, () => harness.repository.writeAttempts == 1);

    expect(
      harness
          .repository
          .durableState
          .activeProfile!
          .gameProgress[GameId.fruitPop]!
          .activeAttempt!
          .attemptId,
      fixture.launch.attemptId,
    );

    harness.repository.writeGate!.complete();
    await tester.pumpAndSettle();
    final restarted = harness
        .repository
        .durableState
        .activeProfile!
        .gameProgress[GameId.fruitPop]!;
    expect(restarted.currentLevel, 10);
    expect(restarted.activeAttempt!.attemptId, 'profile-1:fruitPop:11');
    expect(restarted.activeAttempt!.attemptId, isNot(fixture.launch.attemptId));
  });

  testWidgets('vertical swipe moves a fruit from top to bottom', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _oneMoveLayout(descriptor.level, target: 3000),
    );
    addTearDown(harness.dispose);

    await _swipeMove(tester, const _Move(0, 1, 1, 1));
    await tester.pumpAndSettle();

    expect(find.text('No moves left'), findsOneWidget);
  });

  testWidgets('vertical swipe moves a fruit from bottom to top', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _oneMoveLayout(descriptor.level, target: 3000),
    );
    addTearDown(harness.dispose);

    await _swipeMove(tester, const _Move(1, 1, 0, 1));
    await tester.pumpAndSettle();

    expect(find.text('No moves left'), findsOneWidget);
  });

  testWidgets(
    'profile switch keeps launch Best and blocks Restart without a write',
    (tester) async {
      final base = _fixture(level: 10);
      final owner = base.state.profiles[base.launch.profileId]!;
      final progress = owner.gameProgress[GameId.fruitPop]!;
      final replayAttempt = ActiveGameAttempt(
        attemptId: 'profile-1:fruitPop:replay-9',
        sequence: progress.attemptSequence,
        level: 9,
        playKind: GamePlayKind.replay,
        descriptorFingerprint: progress.descriptors[9]!.fingerprint,
        startedAt: DateTime.utc(2026, 10, 24, 9),
      );
      final fixture = _Fixture(
        state: GameProfilesState(
          activeProfileId: owner.id,
          profiles: {
            owner.id: owner.copyWith(
              bestScore: 91,
              gameProgress: {
                GameId.fruitPop: progress.copyWith(
                  bestScores: {...progress.bestScores, 9: 91},
                  activeAttempt: replayAttempt,
                ),
              },
            ),
          },
          legacyMigrationComplete: true,
        ),
        launch: GameLaunch(
          profileId: owner.id,
          gameId: GameId.fruitPop,
          descriptor: progress.descriptors[9]!,
          attemptId: replayAttempt.attemptId,
          playKind: GamePlayKind.replay,
        ),
      );
      final harness = await _pumpScreen(
        tester,
        fixture: fixture,
        layoutFor: (descriptor) =>
            _oneMoveLayout(descriptor.level, target: 3000),
      );
      addTearDown(harness.dispose);

      await harness.container
          .read(gameProfilesProvider.notifier)
          .createProfile(name: 'Guest');
      await tester.pump();
      expect(find.textContaining('Best: 91'), findsOneWidget);
      final writesBeforeRestart = harness.repository.writeCount;
      final ownerBefore = harness.repository.durableState.profiles[owner.id]!;

      await tester.tap(find.byTooltip('Restart level'));
      await tester.pump();

      expect(find.text('This player is no longer active.'), findsOneWidget);
      expect(harness.repository.writeCount, writesBeforeRestart);
      expect(harness.repository.durableState.profiles[owner.id], ownerBefore);
    },
  );

  testWidgets('a loss stays current and Try again allocates a new attempt', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _oneMoveLayout(descriptor.level, target: 3000),
    );
    addTearDown(harness.dispose);
    await _mute(tester);

    await _tapMove(tester, const _Move(0, 1, 1, 1));
    await tester.pumpAndSettle();

    expect(find.text('No moves left'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('No moves left'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
    var progress = harness
        .repository
        .durableState
        .activeProfile!
        .gameProgress[GameId.fruitPop]!;
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt!.attemptId, fixture.launch.attemptId);
    expect(progress.latestReceipt, isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();
    progress = harness
        .repository
        .durableState
        .activeProfile!
        .gameProgress[GameId.fruitPop]!;
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt!.attemptId, 'profile-1:fruitPop:11');
    expect(progress.activeAttempt!.attemptId, isNot(fixture.launch.attemptId));
  });

  testWidgets('win copy waits for durability and stores normalized score', (
    tester,
  ) async {
    final fixture = _fixture(level: 20);
    final winningLayout = _rawScoreLayout(20);
    final probe = FruitPopGame.fromLayout(winningLayout);
    expect(probe.swap(0, 0, 0, 1), isTrue);
    expect(probe.score, greaterThan(100));

    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _rawScoreLayout(descriptor.level),
    );
    addTearDown(harness.dispose);
    await _mute(tester);
    harness.repository.writeGate = Completer<void>();

    await _swipeMove(tester, const _Move(0, 0, 0, 1));
    await _pumpUntil(tester, () => harness.repository.writeAttempts == 1);

    expect(
      harness
          .repository
          .durableState
          .activeProfile!
          .gameProgress[GameId.fruitPop]!
          .currentLevel,
      20,
    );
    expect(find.textContaining('+50 coins'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);

    harness.repository.writeGate!.complete();
    await tester.pumpAndSettle();
    final profile = harness.repository.durableState.activeProfile!;
    final progress = profile.gameProgress[GameId.fruitPop]!;
    expect(progress.currentLevel, 21);
    expect(progress.bestScores[20], 100);
    expect(profile.coins, 50);
    expect(profile.badgeIds, contains('fruitPop:20'));
    expect(find.textContaining('+50 coins'), findsOneWidget);
    expect(find.textContaining('Badge earned'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Next Level'), findsOneWidget);
  });

  testWidgets('Map is disabled while a winning completion is being saved', (
    tester,
  ) async {
    final fixture = _fixture(level: 20);
    var mapOpens = 0;
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _rawScoreLayout(descriptor.level),
      onOpenMap: () => mapOpens++,
    );
    addTearDown(harness.dispose);
    await _mute(tester);
    harness.repository.writeGate = Completer<void>();

    await _swipeMove(tester, const _Move(0, 0, 0, 1));
    await _pumpUntil(tester, () => harness.repository.writeAttempts == 1);

    final mapButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Map'),
    );
    expect(mapButton.onPressed, isNull);
    await tester.tap(find.text('Map'), warnIfMissed: false);
    await tester.pump();
    expect(mapOpens, 0);

    harness.repository.writeGate!.complete();
    harness.repository.writeGate = null;
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Next Level'), findsOneWidget);
  });

  testWidgets(
    'duplicate result hides rewards and Next Level uses persisted launch',
    (tester) async {
      final fixture = _fixture(level: 20);
      final harness = await _createHarness(
        fixture: fixture,
        layoutFor: (descriptor) => _rawScoreLayout(descriptor.level),
      );
      addTearDown(harness.dispose);
      await harness.container.read(gameProfilesProvider.future);
      await harness.container
          .read(gameProfilesProvider.notifier)
          .completeLevel(
            fixture.launch,
            const FruitPopOutcome(rawScore: 1555, movesUsed: 1, parMoves: 1),
          );
      await harness.pump(tester);
      await _mute(tester);

      await _swipeMove(tester, const _Move(0, 0, 0, 1));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Next Level'), findsOneWidget);
      expect(find.textContaining('+50 coins'), findsNothing);
      expect(find.textContaining('Badge earned'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Next Level'));
      await tester.pumpAndSettle();
      final progress = harness
          .repository
          .durableState
          .activeProfile!
          .gameProgress[GameId.fruitPop]!;
      expect(progress.currentLevel, 21);
      expect(progress.activeAttempt!.attemptId, 'profile-1:fruitPop:21');
      expect(progress.activeAttempt!.level, 21);
      expect(find.text('Level 21'), findsOneWidget);
    },
  );

  testWidgets('profile switch blocks Next Level without replacing the launch', (
    tester,
  ) async {
    final fixture = _fixture(level: 20);
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _rawScoreLayout(descriptor.level),
    );
    addTearDown(harness.dispose);
    await _mute(tester);

    await _swipeMove(tester, const _Move(0, 0, 0, 1));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Next Level'), findsOneWidget);

    final ownerId = fixture.launch.profileId;
    await harness.container
        .read(gameProfilesProvider.notifier)
        .createProfile(name: 'Guest');
    final ownerBefore = harness.repository.durableState.profiles[ownerId]!;
    final writesBeforeNext = harness.repository.writeCount;
    await tester.tap(find.widgetWithText(FilledButton, 'Next Level'));
    await tester.pumpAndSettle();

    expect(find.text('This player is no longer active.'), findsOneWidget);
    expect(find.text('Level 21'), findsNothing);
    expect(harness.repository.writeCount, writesBeforeNext);
    expect(harness.repository.durableState.profiles[ownerId], ownerBefore);
  });

  testWidgets('a failed completion keeps Retry save available', (tester) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _rawScoreLayout(descriptor.level),
    );
    addTearDown(harness.dispose);
    await _mute(tester);
    harness.repository.failWrite = true;

    await _swipeMove(tester, const _Move(0, 0, 0, 1));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Retry save'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Retry save'), findsOneWidget);
    expect(
      harness
          .repository
          .durableState
          .activeProfile!
          .gameProgress[GameId.fruitPop]!
          .currentLevel,
      10,
    );
    expect(find.textContaining('+25 coins'), findsNothing);

    harness.repository.failWrite = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry save'));
    await tester.pumpAndSettle();
    expect(
      harness
          .repository
          .durableState
          .activeProfile!
          .gameProgress[GameId.fruitPop]!
          .currentLevel,
      11,
    );
    expect(find.textContaining('+25 coins'), findsOneWidget);
  });

  testWidgets('a stale attempt is rejected without retry or rewards', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _rawScoreLayout(descriptor.level),
    );
    addTearDown(harness.dispose);
    await _mute(tester);

    final replacement = await harness.container
        .read(gameProfilesProvider.notifier)
        .beginCurrentAttempt(
          profileId: fixture.launch.profileId,
          gameId: GameId.fruitPop,
        );
    expect(replacement.attemptId, isNot(fixture.launch.attemptId));

    await _swipeMove(tester, const _Move(0, 0, 0, 1));
    await tester.pumpAndSettle();

    expect(find.text('This attempt is no longer active.'), findsOneWidget);
    expect(find.text('Retry save'), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(find.textContaining('+25 coins'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);
    final profile = harness.repository.durableState.activeProfile!;
    final progress = profile.gameProgress[GameId.fruitPop]!;
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt?.attemptId, replacement.attemptId);
    expect(profile.coins, 0);
  });

  testWidgets('launch replacement ignores an older completion callback', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      layoutFor: (descriptor) => _rawScoreLayout(descriptor.level),
    );
    addTearDown(harness.dispose);
    await _mute(tester);
    harness.repository.writeGate = Completer<void>();

    await _swipeMove(tester, const _Move(0, 0, 0, 1));
    await _pumpUntil(tester, () => harness.repository.writeAttempts == 1);

    final replacement = GameLaunch(
      profileId: fixture.launch.profileId,
      gameId: GameId.fruitPop,
      descriptor: _descriptor(11),
      attemptId: 'profile-1:fruitPop:replacement',
      playKind: GamePlayKind.current,
    );
    await harness.pumpWithLaunch(tester, replacement);
    expect(find.text('Level 11'), findsOneWidget);

    harness.repository.writeGate!.complete();
    harness.repository.writeGate = null;
    await tester.pumpAndSettle();

    expect(find.text('Level 11'), findsOneWidget);
    expect(find.text('Next Level'), findsNothing);
    expect(find.text('Retry save'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);
  });
}

final class _Harness {
  const _Harness({
    required this.container,
    required this.repository,
    required this.fixture,
    required this.onOpenMap,
  });

  final ProviderContainer container;
  final InMemoryGameProfilesRepository repository;
  final _Fixture fixture;
  final VoidCallback? onOpenMap;

  Future<void> pump(WidgetTester tester) async {
    await pumpWithLaunch(tester, fixture.launch);
  }

  Future<void> pumpWithLaunch(WidgetTester tester, GameLaunch launch) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: FruitPopScreen(launch: launch, onOpenMap: onOpenMap),
        ),
      ),
    );
    await tester.pump();
  }

  void dispose() => container.dispose();
}

Future<_Harness> _pumpScreen(
  WidgetTester tester, {
  required _Fixture fixture,
  required FruitPopLevelLayout Function(GameLevelDescriptor) layoutFor,
  VoidCallback? onOpenMap,
}) async {
  final harness = await _createHarness(
    fixture: fixture,
    layoutFor: layoutFor,
    onOpenMap: onOpenMap,
  );
  await harness.container.read(gameProfilesProvider.future);
  await harness.pump(tester);
  return harness;
}

Future<_Harness> _createHarness({
  required _Fixture fixture,
  required FruitPopLevelLayout Function(GameLevelDescriptor) layoutFor,
  VoidCallback? onOpenMap,
}) async {
  final repository = InMemoryGameProfilesRepository(
    initialState: fixture.state,
  );
  var tick = 0;
  final container = ProviderContainer(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      gameAdapterRegistryProvider.overrideWithValue(
        _FruitRegistry(_ControlledFruitAdapter(layoutFor)),
      ),
      gameProfilesClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 24, 10).add(Duration(seconds: tick++)),
      ),
    ],
  );
  return _Harness(
    container: container,
    repository: repository,
    fixture: fixture,
    onOpenMap: onOpenMap,
  );
}

Future<void> _mute(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Mute sounds'));
  await tester.pump();
}

Future<void> _tapMove(WidgetTester tester, _Move move) async {
  await tester.tap(find.byKey(ValueKey('fruit-cell-${move.row}-${move.col}')));
  await tester.pump();
  await tester.tap(
    find.byKey(ValueKey('fruit-cell-${move.otherRow}-${move.otherCol}')),
  );
  await tester.pump();
}

Future<void> _swipeMove(WidgetTester tester, _Move move) async {
  final from = find.byKey(ValueKey('fruit-cell-${move.row}-${move.col}'));
  final to = find.byKey(
    ValueKey('fruit-cell-${move.otherRow}-${move.otherCol}'),
  );
  await tester.drag(from, tester.getCenter(to) - tester.getCenter(from));
  await tester.pump();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var index = 0; index < 100 && !condition(); index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

final class _Move {
  const _Move(this.row, this.col, this.otherRow, this.otherCol);

  final int row;
  final int col;
  final int otherRow;
  final int otherCol;
}

final class _Fixture {
  const _Fixture({required this.state, required this.launch});

  final GameProfilesState state;
  final GameLaunch launch;
}

_Fixture _fixture({required int level}) {
  final generatedThrough = level >= 20 ? 45 : 30;
  final descriptors = <int, GameLevelDescriptor>{
    for (var index = 1; index <= generatedThrough; index++)
      index: _descriptor(index),
  };
  final attemptId = 'profile-1:fruitPop:$level';
  final activeAttempt = ActiveGameAttempt(
    attemptId: attemptId,
    sequence: level,
    level: level,
    playKind: GamePlayKind.current,
    descriptorFingerprint: descriptors[level]!.fingerprint,
    startedAt: DateTime.utc(2026, 10, 24, 9),
  );
  final progress = PlayerGameProgress(
    gameId: GameId.fruitPop,
    currentLevel: level,
    generatedThrough: generatedThrough,
    descriptors: descriptors,
    fingerprints: descriptors.values
        .map((descriptor) => descriptor.fingerprint)
        .toSet(),
    clearedLevels: {for (var index = 1; index < level; index++) index},
    bestScores: {for (var index = 1; index < level; index++) index: 80},
    attempts: level,
    wins: level - 1,
    attemptSequence: level,
    activeAttempt: activeAttempt,
    highestCompletedLevel: level - 1,
  );
  final profile = PlayerProfile(
    id: 'profile-1',
    name: 'Player',
    createdAt: DateTime.utc(2026, 10, 24, 8),
    updatedAt: DateTime.utc(2026, 10, 24, 9),
    gamesPlayed: level,
    gamesWon: level - 1,
    bestScore: level == 1 ? 0 : 80,
    gameProgress: {GameId.fruitPop: progress},
  );
  return _Fixture(
    state: GameProfilesState(
      activeProfileId: profile.id,
      profiles: {profile.id: profile},
      legacyMigrationComplete: true,
    ),
    launch: GameLaunch(
      profileId: profile.id,
      gameId: GameId.fruitPop,
      descriptor: descriptors[level]!,
      attemptId: attemptId,
      playKind: GamePlayKind.current,
    ),
  );
}

GameLevelDescriptor _descriptor(int level) => GameLevelDescriptor(
  gameId: GameId.fruitPop,
  level: level,
  seed: 0xabc000 + level,
  generatorVersion: 1,
  retrySalt: 0,
  fingerprint: level.toRadixString(16).padLeft(64, '0'),
  tier: GameTier.forLevel(level),
  levelPressure: levelPressureFor(level),
);

FruitPopLevelLayout _oneMoveLayout(int level, {required int target}) {
  final board = List.generate(
    FruitPopGame.size,
    (row) => List<int?>.generate(
      FruitPopGame.size,
      (column) => (row * 2 + column) % 5,
    ),
  );
  board[0][0] = 0;
  board[0][1] = 1;
  board[0][2] = 0;
  board[1][1] = 0;
  return _layout(level: level, target: target, board: board);
}

FruitPopLevelLayout _rawScoreLayout(int level) => _layout(
  level: level,
  target: 1000,
  board: List.generate(
    FruitPopGame.size,
    (_) => List<int?>.filled(FruitPopGame.size, 0),
  ),
);

FruitPopLevelLayout _layout({
  required int level,
  required int target,
  required List<List<int?>> board,
}) => FruitPopLevelLayout(
  level: level,
  typeCount: 5,
  target: target,
  baseMoveBudget: 1,
  moveBudget: 1,
  parMoves: 1,
  refillSeed: 7,
  board: board,
  blockers: const {},
  simulationWins: 8,
  simulationCount: 16,
  candidateAttempts: 1,
);

final class _FruitRegistry implements GameLevelAdapterRegistry {
  const _FruitRegistry(this.adapter);

  final GameLevelAdapter adapter;

  @override
  GameLevelAdapter adapterFor(GameId gameId) {
    if (gameId != GameId.fruitPop) {
      throw StateError('Unexpected adapter request for $gameId');
    }
    return adapter;
  }
}

final class _ControlledFruitAdapter implements GameLevelAdapter {
  _ControlledFruitAdapter(this._layoutFor);

  final FruitPopLevelLayout Function(GameLevelDescriptor) _layoutFor;
  final FruitPopLevelAdapter _scoreAdapter = FruitPopLevelAdapter();

  @override
  GameId get gameId => GameId.fruitPop;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  FruitPopLevelLayout build(GameLevelDescriptor descriptor) =>
      _layoutFor(descriptor);

  @override
  int normalizeScore(GameLevelOutcome outcome) =>
      _scoreAdapter.normalizeScore(outcome);
}
