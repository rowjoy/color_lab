import 'dart:async';

import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/adapters/bubble_shooter_level_adapter.dart';
import 'package:color_lab/features/games/domain/bubble_shooter_game.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_level_catalog.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/presentation/bubble_shooter_painter.dart';
import 'package:color_lab/features/games/presentation/bubble_shooter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  testWidgets(
    'uses the descriptor level and tier and exposes Map and fresh Restart',
    (tester) async {
      final fixture = _fixture(level: 10);
      final repository = InMemoryGameProfilesRepository(
        initialState: fixture.state,
      );
      var mapOpens = 0;
      final harness = await _pumpScreen(
        tester,
        fixture,
        repository,
        onOpenMap: () => mapOpens++,
      );
      addTearDown(harness.dispose);

      final game = _paintedGame(tester);
      expect(game.level, 10);
      expect(game.colorCount, 2);
      expect(game.dropEvery, 73);
      expect(game.grid.expand((row) => row).whereType<int>(), hasLength(11));
      expect(find.text('10'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Choose difficulty'), findsNothing);

      await tester.tap(find.text('Map'));
      await tester.pump();
      expect(mapOpens, 1);

      final oldAttemptId = fixture.launch.attemptId;
      await tester.tap(find.byTooltip('Restart level'));
      await _pumpUntil(
        tester,
        () => _progress(repository).activeAttempt?.attemptId != oldAttemptId,
      );
      expect(_progress(repository).currentLevel, 10);
      expect(
        _progress(repository).activeAttempt?.attemptId,
        isNot(oldAttemptId),
      );
      expect(_paintedGame(tester).level, 10);
    },
  );

  testWidgets('loss does not advance and Try again starts a fresh attempt', (
    tester,
  ) async {
    final fixture = _fixture(level: 10, loses: true);
    final repository = InMemoryGameProfilesRepository(
      initialState: fixture.state,
    );
    final harness = await _pumpScreen(tester, fixture, repository);
    addTearDown(harness.dispose);
    final writesBefore = repository.writeAttempts;

    await _shoot(tester);
    await _pumpRealUntil(
      tester,
      () => find.text('Try again').evaluate().isNotEmpty,
    );

    expect(_progress(repository).currentLevel, 10);
    expect(repository.writeAttempts, writesBefore);
    expect(
      _progress(repository).activeAttempt?.attemptId,
      fixture.launch.attemptId,
    );

    await tester.tap(find.text('Try again'));
    await _pumpUntil(
      tester,
      () =>
          _progress(repository).activeAttempt?.attemptId !=
          fixture.launch.attemptId,
    );
    expect(_progress(repository).currentLevel, 10);
    expect(_progress(repository).activeAttempt?.attemptId, isNotNull);
  });

  testWidgets(
    'win waits for storage, normalizes raw score, and launches persisted next',
    (tester) async {
      const audioChannel = MethodChannel('com.colorlab/game_audio');
      final audioEffects = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audioChannel, (call) async {
            final arguments = call.arguments as Map<Object?, Object?>;
            audioEffects.add(arguments['effect']! as String);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(audioChannel, null),
      );
      final fixture = _fixture(level: 20);
      final repository = InMemoryGameProfilesRepository(
        initialState: fixture.state,
      );
      final harness = await _pumpScreen(tester, fixture, repository);
      addTearDown(harness.dispose);
      final coinsBefore = repository.durableState.activeProfile!.coins;
      final writesBefore = repository.writeAttempts;
      repository.writeGate = Completer<void>();

      await _shoot(tester);
      await _pumpRealUntil(
        tester,
        () => repository.writeAttempts == writesBefore + 1,
      );

      expect(_progress(repository).currentLevel, 20);
      expect(find.text('Next Level'), findsNothing);
      expect(find.textContaining('+50 coins'), findsNothing);
      expect(find.textContaining('Badge earned'), findsNothing);
      expect(fixture.adapter.lastOutcome?.rawScore, 210);
      expect(fixture.adapter.lastOutcome?.shotsFired, 1);
      expect(fixture.adapter.lastOutcome?.parShots, 4);
      expect(fixture.adapter.lastNormalizedScore, 100);

      repository.writeGate!.complete();
      repository.writeGate = null;
      await _pumpUntil(
        tester,
        () => find.text('Next Level').evaluate().isNotEmpty,
      );

      expect(_progress(repository).currentLevel, 21);
      expect(_progress(repository).bestScores[20], 100);
      expect(_progress(repository).latestReceipt?.normalizedScore, 100);
      expect(repository.durableState.activeProfile!.coins, coinsBefore + 50);
      expect(find.textContaining('+50 coins'), findsOneWidget);
      expect(find.textContaining('Badge earned'), findsOneWidget);
      expect(
        audioEffects,
        containsAll(<String>['shoot', 'pop', 'fall', 'win']),
      );

      final writesBeforeNext = repository.writeAttempts;
      repository.writeGate = Completer<void>();
      await tester.tap(find.text('Next Level'));
      await _pumpUntil(
        tester,
        () => repository.writeAttempts == writesBeforeNext + 1,
      );
      expect(_progress(repository).activeAttempt, isNull);
      expect(_paintedGame(tester).level, 20);

      repository.writeGate!.complete();
      repository.writeGate = null;
      await _pumpUntil(tester, () => _paintedLevel(tester) == 21);
      expect(_progress(repository).activeAttempt?.level, 21);
      expect(
        _progress(repository).activeAttempt?.attemptId,
        isNot(fixture.launch.attemptId),
      );
    },
  );

  testWidgets('duplicate receipt suppresses coin and badge celebration', (
    tester,
  ) async {
    final fixture = _fixture(level: 20, alreadyCompleted: true);
    final repository = InMemoryGameProfilesRepository(
      initialState: fixture.state,
    );
    final coinsBefore = repository.durableState.activeProfile!.coins;
    final harness = await _pumpScreen(tester, fixture, repository);
    addTearDown(harness.dispose);

    await _shoot(tester);
    await _pumpRealUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );

    expect(_progress(repository).currentLevel, 21);
    expect(repository.durableState.activeProfile!.coins, coinsBefore);
    expect(find.textContaining('+50 coins'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);
  });

  testWidgets('failed completion keeps Retry save available', (tester) async {
    final fixture = _fixture(level: 10);
    final repository = InMemoryGameProfilesRepository(
      initialState: fixture.state,
    )..failWrite = true;
    final harness = await _pumpScreen(tester, fixture, repository);
    addTearDown(harness.dispose);
    final writesBefore = repository.writeAttempts;

    await _shoot(tester);
    await _pumpRealUntil(
      tester,
      () => find.text('Retry save').evaluate().isNotEmpty,
    );

    expect(repository.writeAttempts, writesBefore + 1);
    expect(_progress(repository).currentLevel, 10);
    expect(
      _progress(repository).activeAttempt?.attemptId,
      fixture.launch.attemptId,
    );
    expect(find.text('Next Level'), findsNothing);

    repository.failWrite = false;
    await tester.tap(find.text('Retry save'));
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    expect(repository.writeAttempts, writesBefore + 2);
    expect(_progress(repository).currentLevel, 11);
    expect(
      _progress(repository).latestReceipt?.attemptId,
      fixture.launch.attemptId,
    );
  });

  testWidgets('locks Map during durable completion and protects win dialog', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final repository = InMemoryGameProfilesRepository(
      initialState: fixture.state,
    );
    var mapOpens = 0;
    final harness = await _pumpScreen(
      tester,
      fixture,
      repository,
      onOpenMap: () => mapOpens++,
    );
    addTearDown(harness.dispose);
    final gate = Completer<void>();
    repository.writeGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final writesBefore = repository.writeAttempts;

    await _shoot(tester);
    await _pumpRealUntil(
      tester,
      () => repository.writeAttempts == writesBefore + 1,
    );

    final mapButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Map'),
    );
    expect(mapButton.onPressed, isNull);
    await tester.tap(find.text('Map'), warnIfMissed: false);
    await tester.pump();
    expect(mapOpens, 0);

    gate.complete();
    repository.writeGate = null;
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Next Level'), findsOneWidget);
  });

  testWidgets('system Back cannot discard save retry or loss retry', (
    tester,
  ) async {
    final saveFixture = _fixture(level: 10);
    final saveRepository = InMemoryGameProfilesRepository(
      initialState: saveFixture.state,
    )..failWrite = true;
    final saveHarness = await _pumpScreen(tester, saveFixture, saveRepository);
    addTearDown(saveHarness.dispose);

    await _shoot(tester);
    await _pumpRealUntil(
      tester,
      () => find.text('Retry save').evaluate().isNotEmpty,
    );
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Retry save'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    saveHarness.dispose();

    final lossFixture = _fixture(level: 10, loses: true);
    final lossRepository = InMemoryGameProfilesRepository(
      initialState: lossFixture.state,
    );
    final lossHarness = await _pumpScreen(tester, lossFixture, lossRepository);
    addTearDown(lossHarness.dispose);

    await _shoot(tester);
    await _pumpRealUntil(
      tester,
      () => find.text('Try again').evaluate().isNotEmpty,
    );
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'profile switch makes an old completion a neutral stale session',
    (tester) async {
      final fixture = _fixture(level: 20);
      final repository = InMemoryGameProfilesRepository(
        initialState: fixture.state,
      );
      final harness = await _pumpScreen(tester, fixture, repository);
      addTearDown(harness.dispose);
      final oldProfileBefore = repository.durableState.profiles['profile-1']!;

      final guest = await harness.container
          .read(gameProfilesProvider.notifier)
          .createProfile(name: 'Guest');
      await tester.pump();
      expect(repository.durableState.activeProfileId, guest.id);

      await _shoot(tester);
      await _pumpRealUntil(
        tester,
        () => find.text('Session changed').evaluate().isNotEmpty,
      );

      final oldProfileAfter = repository.durableState.profiles['profile-1']!;
      expect(oldProfileAfter.coins, oldProfileBefore.coins);
      expect(oldProfileAfter.gamesWon, oldProfileBefore.gamesWon);
      expect(
        oldProfileAfter.gameProgress[GameId.bubbleShooter]!.currentLevel,
        20,
      );
      expect(repository.durableState.profiles[guest.id]!.coins, 0);
      expect(find.text('Retry save'), findsNothing);
      expect(find.text('Next Level'), findsNothing);
      expect(find.textContaining('+50 coins'), findsNothing);
      expect(find.textContaining('Badge earned'), findsNothing);
    },
  );

  testWidgets('launch replacement ignores an older in-flight completion UI', (
    tester,
  ) async {
    final fixture = _fixture(level: 10);
    final repository = InMemoryGameProfilesRepository(
      initialState: fixture.state,
    );
    final harness = await _pumpScreen(tester, fixture, repository);
    addTearDown(harness.dispose);
    final gate = Completer<void>();
    repository.writeGate = gate;
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final writesBefore = repository.writeAttempts;

    await _shoot(tester);
    await _pumpRealUntil(
      tester,
      () => repository.writeAttempts == writesBefore + 1,
    );

    final nextDescriptor = _progress(repository).descriptors[11]!;
    final replacement = GameLaunch(
      profileId: fixture.launch.profileId,
      gameId: GameId.bubbleShooter,
      descriptor: nextDescriptor,
      attemptId: 'profile-1:bubble_shooter:999',
      playKind: GamePlayKind.current,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(home: BubbleShooterScreen(launch: replacement)),
      ),
    );
    await tester.pump();
    expect(_paintedLevel(tester), 11);

    gate.complete();
    repository.writeGate = null;
    await _pumpUntil(tester, () => _progress(repository).currentLevel == 11);
    await tester.pump(const Duration(milliseconds: 500));

    expect(_paintedLevel(tester), 11);
    expect(find.text('Next Level'), findsNothing);
    expect(find.text('Session changed'), findsNothing);
    expect(find.textContaining('+25 coins'), findsNothing);
  });
}

final class _Fixture {
  const _Fixture(this.state, this.launch, this.adapter);

  final GameProfilesState state;
  final GameLaunch launch;
  final _BubbleAdapter adapter;
}

_Fixture _fixture({
  required int level,
  bool loses = false,
  bool alreadyCompleted = false,
}) {
  final adapter = _BubbleAdapter(loses: loses);
  final engine = GameProgressionEngine(
    catalog: GameLevelCatalog(registry: _Registry(adapter)),
  );
  var state = GameProfilesState(
    activeProfileId: null,
    profiles: const {},
    legacyMigrationComplete: true,
  );
  var minute = 0;
  DateTime now() =>
      DateTime.utc(2026, 10, 24, 8).add(Duration(minutes: minute++));

  state = engine
      .createProfile(
        state: state,
        profileId: 'profile-1',
        name: 'Player',
        now: now(),
      )
      .state;
  state = engine
      .prepareGame(
        state: state,
        profileId: 'profile-1',
        gameId: GameId.bubbleShooter,
      )
      .state;
  for (var completed = 1; completed < level; completed++) {
    final started = engine.beginCurrentAttempt(
      state: state,
      profileId: 'profile-1',
      gameId: GameId.bubbleShooter,
      startedAt: now(),
    );
    state = started.state;
    state = engine
        .completeLevel(
          state: state,
          launch: started.value,
          normalizedScore: 80,
          completedAt: now(),
        )
        .state;
  }
  final started = engine.beginCurrentAttempt(
    state: state,
    profileId: 'profile-1',
    gameId: GameId.bubbleShooter,
    startedAt: now(),
  );
  state = started.state;
  if (alreadyCompleted) {
    state = engine
        .completeLevel(
          state: state,
          launch: started.value,
          normalizedScore: 100,
          completedAt: now(),
        )
        .state;
  }
  return _Fixture(state, started.value, adapter);
}

final class _Harness {
  const _Harness(this.container);
  final ProviderContainer container;
  void dispose() => container.dispose();
}

Future<_Harness> _pumpScreen(
  WidgetTester tester,
  _Fixture fixture,
  InMemoryGameProfilesRepository repository, {
  VoidCallback? onOpenMap,
}) async {
  final container = ProviderContainer(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      gameAdapterRegistryProvider.overrideWithValue(_Registry(fixture.adapter)),
      gameProfilesClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 25, 9),
      ),
    ],
  );
  await container.read(gameProfilesProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: BubbleShooterScreen(launch: fixture.launch, onOpenMap: onOpenMap),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container);
}

PlayerGameProgress _progress(InMemoryGameProfilesRepository repository) =>
    repository.durableState.profiles['profile-1']!.gameProgress[GameId
        .bubbleShooter]!;

BubbleShooterGame _paintedGame(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is BubbleShooterPainter,
  );
  expect(finder, findsOneWidget);
  return (tester.widget<CustomPaint>(finder).painter! as BubbleShooterPainter)
      .game;
}

int? _paintedLevel(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is BubbleShooterPainter,
  );
  if (finder.evaluate().length != 1) return null;
  return (tester.widget<CustomPaint>(finder).painter! as BubbleShooterPainter)
      .game
      .level;
}

Future<void> _shoot(WidgetTester tester) async {
  final board = find.byKey(const ValueKey('bubble-shooter-board'));
  expect(board, findsOneWidget);
  await tester.tap(board);
  await tester.pump();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 120 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (!condition()) throw StateError('Timed out waiting for widget state');
}

Future<void> _pumpRealUntil(
  WidgetTester tester,
  bool Function() condition,
) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.runAsync<void>(() async {
      await Future<void>.delayed(const Duration(milliseconds: 15));
    });
    await tester.pump(const Duration(milliseconds: 15));
  }
  if (!condition()) throw StateError('Timed out waiting for game animation');
}

final class _Registry implements GameLevelAdapterRegistry {
  const _Registry(this.adapter);
  final _BubbleAdapter adapter;

  @override
  GameLevelAdapter adapterFor(GameId gameId) {
    if (gameId != GameId.bubbleShooter) throw StateError('Unexpected game');
    return adapter;
  }
}

final class _BubbleAdapter implements GameLevelAdapter {
  _BubbleAdapter({required this.loses});

  final bool loses;
  final BubbleShooterLevelAdapter _normalizer = BubbleShooterLevelAdapter();
  BubbleShooterOutcome? lastOutcome;
  int? lastNormalizedScore;

  @override
  GameId get gameId => GameId.bubbleShooter;
  @override
  int get currentGeneratorVersion => 1;
  @override
  bool supportsVersion(int version) => version == 1;
  @override
  BubbleShooterLevelLayout build(GameLevelDescriptor descriptor) => loses
      ? _losingLayout(descriptor.level)
      : _winningLayout(descriptor.level);
  @override
  int normalizeScore(GameLevelOutcome outcome) {
    if (outcome is! BubbleShooterOutcome) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    lastOutcome = outcome;
    return lastNormalizedScore = _normalizer.normalizeScore(outcome);
  }
}

BubbleShooterLevelLayout _winningLayout(int level) {
  final grid = List.generate(
    9,
    (_) => List<int?>.filled(BubbleShooterGame.columns, null),
  );
  grid[0][4] = 0;
  grid[0][5] = 0;
  grid[1][3] = 1;
  for (var column = 0; column < 4; column++) {
    grid[2][column] = 1;
    grid[3][column] = 1;
  }
  return BubbleShooterLevelLayout(
    level: level,
    colorCount: 2,
    occupiedRows: 4,
    dropEvery: 73,
    currentColor: 0,
    nextColor: 0,
    runtimeSeed: level,
    grid: grid,
    placementCertificate: const [
      BubbleShooterPlacement(row: 1, column: 4, color: 0),
    ],
    parShots: 4,
  );
}

BubbleShooterLevelLayout _losingLayout(int level) => BubbleShooterLevelLayout(
  level: level,
  colorCount: 2,
  occupiedRows: 9,
  dropEvery: 73,
  currentColor: 0,
  nextColor: 1,
  runtimeSeed: level,
  grid: List.generate(
    9,
    (row) => List<int?>.generate(
      BubbleShooterGame.columns,
      (column) => (row + column).isEven ? 0 : 1,
    ),
  ),
  placementCertificate: const [],
  parShots: 4,
);
