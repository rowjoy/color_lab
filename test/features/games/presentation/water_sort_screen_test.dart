import 'dart:async';

import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/adapters/water_sort_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/domain/water_sort_game.dart';
import 'package:color_lab/features/games/presentation/water_sort_painter.dart';
import 'package:color_lab/features/games/presentation/water_sort_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  testWidgets('uses the persisted descriptor layout, level, tier, and Map', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    var mapOpens = 0;
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      onOpenMap: () => mapOpens++,
    );
    addTearDown(harness.dispose);

    expect(_paintedTubes(tester), _quickLayout(10).tubes);
    expect(find.text('Level 10'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Choose difficulty'), findsNothing);

    await tester.tap(find.text('Map'));
    await tester.pump();
    expect(mapOpens, 1);
  });

  testWidgets('Restart durably replaces the attempt on the same level', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(tester, fixture: fixture);
    addTearDown(harness.dispose);
    final gate = Completer<void>();
    harness.repository.writeGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });

    await tester.tap(find.text('Restart'));
    await _pumpUntil(tester, () => harness.repository.writeAttempts == 1);

    var progress = _progress(harness.repository);
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt?.attemptId, fixture.launch.attemptId);

    gate.complete();
    harness.repository.writeGate = null;
    await _pumpUntil(
      tester,
      () =>
          _progress(harness.repository).activeAttempt?.attemptId !=
          fixture.launch.attemptId,
    );
    progress = _progress(harness.repository);
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt?.level, 10);
    expect(_paintedTubes(tester), _quickLayout(10).tubes);
  });

  testWidgets(
    'win waits for durability and persists adapter-normalized score',
    (tester) async {
      final fixture = _fixture(level: 20);
      var mapOpens = 0;
      final harness = await _pumpScreen(
        tester,
        fixture: fixture,
        onOpenMap: () => mapOpens++,
      );
      addTearDown(harness.dispose);
      final gate = Completer<void>();
      harness.repository.writeGate = gate;
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });

      await _solveBoard(tester, _quickLayout(20));
      await _pumpUntil(tester, () => harness.repository.writeAttempts == 1);

      expect(_progress(harness.repository).currentLevel, 20);
      expect(find.text('Next Level'), findsNothing);
      expect(find.textContaining('+50 coins'), findsNothing);
      expect(find.textContaining('Badge earned'), findsNothing);
      expect(harness.adapter.lastOutcome?.actualMoves, 4);
      expect(harness.adapter.lastOutcome?.parMoves, 4);
      expect(harness.adapter.lastNormalizedScore, 100);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Map'))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<GestureDetector>(
              find.byKey(const ValueKey('water-sort-board')),
            )
            .onTapUp,
        isNull,
      );
      expect(_buttonInk(tester, 'Undo').onTap, isNull);
      expect(_buttonInk(tester, 'Restart').onTap, isNull);
      await tester.tap(find.text('Map'), warnIfMissed: false);
      await tester.pump();
      expect(mapOpens, 0);

      gate.complete();
      harness.repository.writeGate = null;
      await _pumpUntil(
        tester,
        () => find.text('Next Level').evaluate().isNotEmpty,
      );

      final profile = harness.repository.durableState.activeProfile!;
      final progress = profile.gameProgress[GameId.waterSort]!;
      expect(progress.currentLevel, 21);
      expect(progress.bestScores[20], 100);
      expect(profile.coins, 50);
      expect(profile.badgeIds, contains('waterSort:20'));
      expect(find.textContaining('+50 coins'), findsOneWidget);
      expect(find.textContaining('Badge earned'), findsOneWidget);
    },
  );

  testWidgets(
    'duplicate win hides rewards and Next Level uses persisted launch',
    (tester) async {
      final fixture = _fixture(level: 20);
      final harness = _createHarness(fixture: fixture);
      addTearDown(harness.dispose);
      await harness.container.read(gameProfilesProvider.future);
      await harness.container
          .read(gameProfilesProvider.notifier)
          .completeLevel(
            fixture.launch,
            const WaterSortOutcome(actualMoves: 4, parMoves: 4),
          );
      final coinsBefore = harness.repository.durableState.activeProfile!.coins;
      await harness.pump(tester);

      await _solveBoard(tester, _quickLayout(20));
      await _pumpUntil(
        tester,
        () => find.text('Next Level').evaluate().isNotEmpty,
      );

      expect(find.textContaining('+50 coins'), findsNothing);
      expect(find.textContaining('Badge earned'), findsNothing);
      expect(find.textContaining('Progress already saved'), findsOneWidget);

      await tester.tap(find.text('Next Level'));
      await _pumpUntil(
        tester,
        () => find.text('Level 21').evaluate().isNotEmpty,
      );
      final progress = _progress(harness.repository);
      expect(progress.currentLevel, 21);
      expect(progress.activeAttempt?.level, 21);
      expect(progress.activeAttempt?.attemptId, 'profile-1:waterSort:21');
      expect(harness.repository.durableState.activeProfile!.coins, coinsBefore);
    },
  );

  testWidgets('launch replacement cancels an old pour and installs new board', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(tester, fixture: fixture);
    addTearDown(harness.dispose);

    await _tapMove(
      tester,
      tubeCount: 5,
      move: const WaterSortMove(source: 0, target: 3),
      settleMotion: false,
    );
    expect(_waterPainter(tester).motion, isNotNull);

    final replacement = GameLaunch(
      profileId: fixture.launch.profileId,
      gameId: GameId.waterSort,
      descriptor: _descriptor(11),
      attemptId: 'profile-1:waterSort:replacement',
      playKind: GamePlayKind.current,
    );
    await harness.pumpWithLaunch(tester, replacement);

    expect(find.text('Level 11'), findsOneWidget);
    expect(_waterPainter(tester).motion, isNull);
    expect(_paintedTubes(tester), _quickLayout(11).tubes);
  });

  testWidgets('launch replacement ignores an older completion callback', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(tester, fixture: fixture);
    addTearDown(harness.dispose);
    final gate = Completer<void>();
    harness.repository.writeGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });

    await _solveBoard(tester, _quickLayout(10));
    await _pumpUntil(tester, () => harness.repository.writeAttempts == 1);
    final replacement = GameLaunch(
      profileId: fixture.launch.profileId,
      gameId: GameId.waterSort,
      descriptor: _descriptor(11),
      attemptId: 'profile-1:waterSort:replacement',
      playKind: GamePlayKind.current,
    );
    await harness.pumpWithLaunch(tester, replacement);
    expect(find.text('Level 11'), findsOneWidget);

    gate.complete();
    harness.repository.writeGate = null;
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Level 11'), findsOneWidget);
    expect(find.text('Next Level'), findsNothing);
    expect(find.text('Retry save'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);
  });

  testWidgets('failed completion retains a protected Retry save action', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(tester, fixture: fixture);
    addTearDown(harness.dispose);
    harness.repository.failWrite = true;

    await _solveBoard(tester, _quickLayout(10));
    await _pumpUntil(
      tester,
      () => find.text('Retry save').evaluate().isNotEmpty,
    );

    expect(_progress(harness.repository).currentLevel, 10);
    expect(find.textContaining('+25 coins'), findsNothing);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Retry save'), findsOneWidget);

    harness.repository.failWrite = false;
    await tester.tap(find.text('Retry save'));
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    expect(_progress(harness.repository).currentLevel, 11);
    expect(find.textContaining('+25 coins'), findsOneWidget);
  });

  testWidgets('failed next-level write retains a protected retry path', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(tester, fixture: fixture);
    addTearDown(harness.dispose);

    await _solveBoard(tester, _quickLayout(10));
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    harness.repository.failWrite = true;
    await tester.tap(find.text('Next Level'));
    await _pumpUntil(
      tester,
      () => find.text('Retry Next Level').evaluate().isNotEmpty,
    );

    expect(_progress(harness.repository).currentLevel, 11);
    expect(_progress(harness.repository).activeAttempt, isNull);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Retry Next Level'), findsOneWidget);

    harness.repository.failWrite = false;
    await tester.tap(find.text('Retry Next Level'));
    await _pumpUntil(tester, () => find.text('Level 11').evaluate().isNotEmpty);
    expect(_progress(harness.repository).activeAttempt?.level, 11);
  });

  testWidgets('profile switch after a win exits the completed session safely', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    var mapOpens = 0;
    final harness = await _pumpScreen(
      tester,
      fixture: fixture,
      onOpenMap: () => mapOpens++,
    );
    addTearDown(harness.dispose);

    await _solveBoard(tester, _quickLayout(10));
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    final guest = await harness.container
        .read(gameProfilesProvider.notifier)
        .createProfile(name: 'Guest');
    await tester.pump();

    await tester.tap(find.text('Next Level'));
    await _pumpUntil(
      tester,
      () =>
          find.text('This attempt is no longer active.').evaluate().isNotEmpty,
    );

    expect(harness.repository.durableState.activeProfileId, guest.id);
    expect(harness.repository.durableState.profiles[guest.id]!.coins, 0);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Map'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Map'));
    await tester.pump();
    expect(mapOpens, 1);
  });

  testWidgets('stale completion is rejected without storage retry or rewards', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(tester, fixture: fixture);
    addTearDown(harness.dispose);
    final replacement = await harness.container
        .read(gameProfilesProvider.notifier)
        .beginCurrentAttempt(
          profileId: fixture.launch.profileId,
          gameId: GameId.waterSort,
        );

    await _solveBoard(tester, _quickLayout(10));
    await _pumpUntil(
      tester,
      () =>
          find.text('This attempt is no longer active.').evaluate().isNotEmpty,
    );

    final profile = harness.repository.durableState.activeProfile!;
    final progress = profile.gameProgress[GameId.waterSort]!;
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt?.attemptId, replacement.attemptId);
    expect(profile.coins, 0);
    expect(find.text('Retry save'), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);
  });

  testWidgets('replay Restart stays replay and replay win never advances', (
    tester,
  ) async {
    final fixture = _fixture(level: 10, replayLevel: 3);
    final harness = await _pumpScreen(tester, fixture: fixture);
    addTearDown(harness.dispose);
    final profileBefore = harness.repository.durableState.activeProfile!;
    final coinsBefore = profileBefore.coins;
    final badgeIdsBefore = {...profileBefore.badgeIds};
    final milestonesBefore = {
      ...profileBefore.gameProgress[GameId.waterSort]!.badgeMilestones,
    };
    final oldAttemptId = fixture.launch.attemptId;

    await tester.tap(find.text('Restart'));
    await _pumpUntil(
      tester,
      () =>
          _progress(harness.repository).activeAttempt?.attemptId !=
          oldAttemptId,
    );
    var progress = _progress(harness.repository);
    expect(progress.activeAttempt?.playKind, GamePlayKind.replay);
    expect(progress.activeAttempt?.level, 3);
    expect(progress.currentLevel, 10);
    expect(find.text('Level 3'), findsOneWidget);

    await _solveBoard(tester, _quickLayout(3));
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );

    progress = _progress(harness.repository);
    expect(progress.currentLevel, 10);
    expect(progress.latestReceipt?.firstClear, isFalse);
    expect(progress.latestReceipt?.coinsAwarded, 0);
    final profileAfterReplay = harness.repository.durableState.activeProfile!;
    expect(profileAfterReplay.coins, coinsBefore);
    expect(profileAfterReplay.badgeIds, badgeIdsBefore);
    expect(progress.badgeMilestones, milestonesBefore);
    expect(find.textContaining('coins'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);

    await tester.tap(find.text('Next Level'));
    await _pumpUntil(tester, () => find.text('Level 10').evaluate().isNotEmpty);
    progress = _progress(harness.repository);
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt?.playKind, GamePlayKind.current);
    expect(progress.activeAttempt?.level, 10);
  });

  testWidgets('pour animation keeps amount-aware native audio timing', (
    tester,
  ) async {
    const channel = MethodChannel('com.colorlab/game_audio');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final fixture = _fixture(level: 10);
    final harness = await _pumpScreen(tester, fixture: fixture);
    addTearDown(harness.dispose);

    await _tapMove(
      tester,
      tubeCount: 5,
      move: const WaterSortMove(source: 0, target: 3),
      settleMotion: false,
    );
    final motion = _waterPainter(tester).motion!;
    expect(motion.amount, 2);
    expect(motion.pourMillis, 970);
    expect(motion.totalMillis, 1730);

    await tester.pump(const Duration(milliseconds: 379));
    expect(
      calls.where(
        (call) =>
            call.arguments is Map &&
            (call.arguments as Map<Object?, Object?>)['effect'] == 'waterPour',
      ),
      isEmpty,
    );
    await tester.pump(const Duration(milliseconds: 2));
    final pourCalls = calls.where(
      (call) =>
          call.arguments is Map &&
          (call.arguments as Map<Object?, Object?>)['effect'] == 'waterPour',
    );
    expect(pourCalls, hasLength(1));
    expect(pourCalls.single.arguments, {
      'effect': 'waterPour',
      'amount': 2,
      'durationMs': 970,
    });
  });
}

final class _Harness {
  const _Harness({
    required this.container,
    required this.repository,
    required this.adapter,
    required this.fixture,
    required this.onOpenMap,
  });

  final ProviderContainer container;
  final InMemoryGameProfilesRepository repository;
  final _ControlledWaterAdapter adapter;
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
          home: WaterSortScreen(launch: launch, onOpenMap: onOpenMap),
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
  VoidCallback? onOpenMap,
}) async {
  final harness = _createHarness(fixture: fixture, onOpenMap: onOpenMap);
  await harness.container.read(gameProfilesProvider.future);
  await harness.pump(tester);
  return harness;
}

_Harness _createHarness({required _Fixture fixture, VoidCallback? onOpenMap}) {
  final repository = InMemoryGameProfilesRepository(
    initialState: fixture.state,
  );
  final adapter = _ControlledWaterAdapter();
  var tick = 0;
  final container = ProviderContainer(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      gameAdapterRegistryProvider.overrideWithValue(_WaterRegistry(adapter)),
      gameProfilesClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 24, 11).add(Duration(seconds: tick++)),
      ),
    ],
  );
  final harness = _Harness(
    container: container,
    repository: repository,
    adapter: adapter,
    fixture: fixture,
    onOpenMap: onOpenMap,
  );
  return harness;
}

List<List<WaterSegment>> _paintedTubes(WidgetTester tester) {
  return _waterPainter(tester).tubes;
}

WaterSortPainter _waterPainter(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is WaterSortPainter,
    ),
  );
  return paint.painter! as WaterSortPainter;
}

InkWell _buttonInk(WidgetTester tester, String label) => tester.widget<InkWell>(
  find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
);

PlayerGameProgress _progress(InMemoryGameProfilesRepository repository) =>
    repository.durableState.profiles['profile-1']!.gameProgress[GameId
        .waterSort]!;

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var index = 0; index < 100 && !condition(); index++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

Future<void> _solveBoard(
  WidgetTester tester,
  WaterSortLevelLayout layout,
) async {
  for (final move in layout.inverseSolution) {
    await _tapMove(tester, tubeCount: layout.tubes.length, move: move);
  }
}

Future<void> _tapMove(
  WidgetTester tester, {
  required int tubeCount,
  required WaterSortMove move,
  bool settleMotion = true,
}) async {
  final board = find.byKey(const ValueKey('water-sort-board'));
  final size = tester.getSize(board);
  final origin = tester.getTopLeft(board);
  final geometry = WaterSortGeometry.layout(size, tubeCount);
  await tester.tapAt(origin + geometry.positions[move.source]);
  await tester.pump();
  await tester.tapAt(origin + geometry.positions[move.target]);
  await tester.pump();
  if (settleMotion) await tester.pump(const Duration(milliseconds: 1731));
}

final class _Fixture {
  const _Fixture({required this.state, required this.launch});

  final GameProfilesState state;
  final GameLaunch launch;
}

_Fixture _fixture({required int level, int? replayLevel}) {
  final generatedThrough = level >= 20 ? 45 : 30;
  final descriptors = <int, GameLevelDescriptor>{
    for (var index = 1; index <= generatedThrough; index++)
      index: _descriptor(index),
  };
  final playLevel = replayLevel ?? level;
  final attemptSequence = replayLevel == null ? level : level + 1;
  final attemptId = 'profile-1:waterSort:$attemptSequence';
  final activeAttempt = ActiveGameAttempt(
    attemptId: attemptId,
    sequence: attemptSequence,
    level: playLevel,
    playKind: replayLevel == null ? GamePlayKind.current : GamePlayKind.replay,
    descriptorFingerprint: descriptors[playLevel]!.fingerprint,
    startedAt: DateTime.utc(2026, 10, 24, 10),
  );
  final progress = PlayerGameProgress(
    gameId: GameId.waterSort,
    currentLevel: level,
    generatedThrough: generatedThrough,
    descriptors: descriptors,
    fingerprints: descriptors.values
        .map((descriptor) => descriptor.fingerprint)
        .toSet(),
    clearedLevels: {for (var index = 1; index < level; index++) index},
    bestScores: {for (var index = 1; index < level; index++) index: 80},
    attempts: attemptSequence,
    wins: level - 1,
    attemptSequence: attemptSequence,
    activeAttempt: activeAttempt,
    highestCompletedLevel: level - 1,
  );
  final profile = PlayerProfile(
    id: 'profile-1',
    name: 'Player',
    createdAt: DateTime.utc(2026, 10, 24, 9),
    updatedAt: DateTime.utc(2026, 10, 24, 10),
    gamesPlayed: attemptSequence,
    gamesWon: level - 1,
    bestScore: level == 1 ? 0 : 80,
    gameProgress: {GameId.waterSort: progress},
  );
  return _Fixture(
    state: GameProfilesState(
      activeProfileId: profile.id,
      profiles: {profile.id: profile},
      legacyMigrationComplete: true,
    ),
    launch: GameLaunch(
      profileId: profile.id,
      gameId: GameId.waterSort,
      descriptor: descriptors[playLevel]!,
      attemptId: attemptId,
      playKind: replayLevel == null
          ? GamePlayKind.current
          : GamePlayKind.replay,
    ),
  );
}

GameLevelDescriptor _descriptor(int level) => GameLevelDescriptor(
  gameId: GameId.waterSort,
  level: level,
  seed: 0xabc000 + level,
  generatorVersion: 1,
  retrySalt: 0,
  fingerprint: level.toRadixString(16).padLeft(64, '0'),
  tier: GameTier.forLevel(level),
  levelPressure: levelPressureFor(level),
);

WaterSortLevelLayout _quickLayout(int level) => WaterSortLevelLayout(
  level: level,
  colorCount: 3,
  scrambleDepth: 4,
  tubes: const [
    [WaterSegment(0, 2), WaterSegment(1, 2)],
    [WaterSegment(1, 2), WaterSegment(0, 2)],
    [WaterSegment(2, 4)],
    [],
    [],
  ],
  inverseSolution: const [
    WaterSortMove(source: 0, target: 3),
    WaterSortMove(source: 1, target: 4),
    WaterSortMove(source: 0, target: 4),
    WaterSortMove(source: 1, target: 3),
  ],
  parMoves: 4,
  candidateAttempts: 1,
);

final class _WaterRegistry implements GameLevelAdapterRegistry {
  const _WaterRegistry(this.adapter);

  final GameLevelAdapter adapter;

  @override
  GameLevelAdapter adapterFor(GameId gameId) {
    if (gameId != GameId.waterSort) {
      throw StateError('Unexpected adapter request for $gameId');
    }
    return adapter;
  }
}

final class _ControlledWaterAdapter implements GameLevelAdapter {
  final WaterSortLevelAdapter _scoreAdapter = WaterSortLevelAdapter();
  WaterSortOutcome? lastOutcome;
  int? lastNormalizedScore;

  @override
  GameId get gameId => GameId.waterSort;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  WaterSortLevelLayout build(GameLevelDescriptor descriptor) =>
      _quickLayout(descriptor.level);

  @override
  int normalizeScore(GameLevelOutcome outcome) {
    lastOutcome = outcome as WaterSortOutcome;
    lastNormalizedScore = _scoreAdapter.normalizeScore(outcome);
    return lastNormalizedScore!;
  }
}
