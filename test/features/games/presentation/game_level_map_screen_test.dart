import 'dart:async';

import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_badge.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/presentation/game_level_map_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  testWidgets('an empty profile state is safe and starts no level', (
    tester,
  ) async {
    final repository = InMemoryGameProfilesRepository(initialState: _state());
    final harness = await _pumpMap(tester, repository: repository);
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('level-map-no-profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-node-1')), findsNothing);
    expect(find.byKey(const ValueKey('play-current-level')), findsNothing);
    expect(repository.writeAttempts, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first visit prepares and exposes exactly levels 1 through 15', (
    tester,
  ) async {
    final profile = _profile();
    final repository = InMemoryGameProfilesRepository(
      initialState: _state(profile: profile),
    );
    final harness = await _pumpMap(tester, repository: repository);
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    final progress = repository
        .durableState
        .profiles[profile.id]!
        .gameProgress[GameId.waterSort]!;
    expect(progress.generatedThrough, 15);
    expect(progress.descriptors.keys, orderedEquals(_levelsThrough(15)));
    expect(find.byKey(const ValueKey('level-node-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-current-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-current-level')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-locked-2')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('level-node-2')),
        matching: find.byIcon(Icons.lock_rounded),
      ),
      findsOneWidget,
    );

    await _reveal(tester, const ValueKey('level-node-15'));
    expect(find.byKey(const ValueKey('level-node-15')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-node-16')), findsNothing);
    expect(find.text('Choose difficulty'), findsNothing);
    expect(find.byKey(const ValueKey('games-level-grid')), findsNothing);
  });

  testWidgets(
    'completed, current, and generated future nodes expose their actions',
    (tester) async {
      final profile = _profile(
        progress: _progress(
          completed: 3,
          generatedThrough: 15,
          scores: const {1: 91, 2: 84, 3: 96},
        ),
      );
      final repository = InMemoryGameProfilesRepository(
        initialState: _state(profile: profile),
      );
      final harness = await _pumpMap(tester, repository: repository);
      addTearDown(harness.dispose);
      await tester.pumpAndSettle();

      final completed = find.byKey(const ValueKey('level-node-1'));
      expect(find.byKey(const ValueKey('level-completed-1')), findsOneWidget);
      expect(
        find.descendant(
          of: completed,
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: completed, matching: find.text('Best 91')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('replay-level-1')), findsOneWidget);

      expect(find.byKey(const ValueKey('level-current-4')), findsOneWidget);
      expect(find.byKey(const ValueKey('play-current-level')), findsOneWidget);
      expect(find.text('Play Level 4'), findsOneWidget);

      expect(find.byKey(const ValueKey('level-locked-5')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('level-node-5')),
          matching: find.byIcon(Icons.lock_rounded),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('replay-level-5')), findsNothing);
    },
  );

  testWidgets('replay and current Play callbacks wait for durable writes', (
    tester,
  ) async {
    final profile = _profile(
      progress: _progress(
        completed: 3,
        generatedThrough: 15,
        scores: const {1: 91, 2: 84, 3: 96},
      ),
    );
    final repository = InMemoryGameProfilesRepository(
      initialState: _state(profile: profile),
    );
    final launches = <GameLaunch>[];
    final harness = await _pumpMap(
      tester,
      repository: repository,
      onLaunchGame: launches.add,
    );
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    var writesBefore = repository.writeAttempts;
    repository.writeGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('replay-level-1')));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => repository.writeAttempts == writesBefore + 1,
    );
    expect(launches, isEmpty);

    repository.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(launches, hasLength(1));
    expect(launches.first.gameId, GameId.waterSort);
    expect(launches.first.descriptor.level, 1);
    expect(launches.first.playKind, GamePlayKind.replay);
    expect(
      repository
          .durableState
          .profiles[profile.id]!
          .gameProgress[GameId.waterSort]!
          .activeAttempt
          ?.attemptId,
      launches.first.attemptId,
    );

    writesBefore = repository.writeAttempts;
    repository.writeGate = Completer<void>();
    await tester.tap(find.byKey(const ValueKey('play-current-level')));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => repository.writeAttempts == writesBefore + 1,
    );
    expect(launches, hasLength(1));

    repository.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(launches, hasLength(2));
    expect(launches.last.descriptor.level, 4);
    expect(launches.last.playKind, GamePlayKind.current);
    expect(
      repository
          .durableState
          .profiles[profile.id]!
          .gameProgress[GameId.waterSort]!
          .activeAttempt
          ?.attemptId,
      launches.last.attemptId,
    );
  });

  testWidgets('a failed Play write shows recovery copy and never launches', (
    tester,
  ) async {
    final profile = _profile(
      progress: _progress(
        completed: 3,
        generatedThrough: 15,
        scores: const {1: 91, 2: 84, 3: 96},
      ),
    );
    final repository = InMemoryGameProfilesRepository(
      initialState: _state(profile: profile),
    );
    final launches = <GameLaunch>[];
    final harness = await _pumpMap(
      tester,
      repository: repository,
      onLaunchGame: launches.add,
    );
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    repository.failWrite = true;
    await tester.tap(find.byKey(const ValueKey('play-current-level')));
    await tester.pumpAndSettle();

    expect(launches, isEmpty);
    expect(
      find.text('Water Sort level could not be started. Try again.'),
      findsOneWidget,
    );
    expect(
      repository
          .durableState
          .profiles[profile.id]!
          .gameProgress[GameId.waterSort]!
          .attemptSequence,
      3,
    );
  });

  testWidgets('refilled map exposes level 30 and earned level-20 milestone', (
    tester,
  ) async {
    final profile = _profile(
      progress: _progress(completed: 20, generatedThrough: 30),
    );
    final repository = InMemoryGameProfilesRepository(
      initialState: _state(profile: profile),
    );
    final harness = await _pumpMap(tester, repository: repository);
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    await _reveal(tester, const ValueKey('level-node-30'));
    expect(find.byKey(const ValueKey('level-node-30')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-node-31')), findsNothing);

    await _reveal(tester, const ValueKey('level-node-20'));
    expect(find.byKey(const ValueKey('level-milestone-20')), findsOneWidget);
    expect(find.byKey(const ValueKey('level-completed-20')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('level-node-20')),
        matching: find.byIcon(Icons.workspace_premium_rounded),
      ),
      findsOneWidget,
    );
    expect(find.text('Badge earned'), findsOneWidget);
    expect(find.text('Choose difficulty'), findsNothing);
  });

  testWidgets('dark 360dp map supports 2x text and meaningful semantics', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final profile = _profile(
      progress: _progress(
        completed: 3,
        generatedThrough: 15,
        scores: const {1: 91, 2: 84, 3: 96},
      ),
    );
    final repository = InMemoryGameProfilesRepository(
      initialState: _state(profile: profile),
    );
    final harness = await _pumpMap(
      tester,
      repository: repository,
      themeMode: ThemeMode.dark,
      textScaler: const TextScaler.linear(2),
    );
    addTearDown(harness.dispose);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        RegExp(r'Level 1.*completed.*best score 91', caseSensitive: false),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Level 4.*current', caseSensitive: false)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Level 5.*locked', caseSensitive: false)),
      findsOneWidget,
    );
    expect(find.byTooltip('Replay level 1'), findsOneWidget);
    expect(find.byTooltip('Play current level 4'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1400));
    await tester.pump();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

final class _MapHarness {
  const _MapHarness(this.container);

  final ProviderContainer container;

  void dispose() => container.dispose();
}

Future<_MapHarness> _pumpMap(
  WidgetTester tester, {
  required InMemoryGameProfilesRepository repository,
  ValueChanged<GameLaunch>? onLaunchGame,
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
        home: GameLevelMapScreen(
          gameId: GameId.waterSort,
          onLaunchGame: onLaunchGame,
        ),
      ),
    ),
  );
  await tester.pump();
  return _MapHarness(container);
}

GameProfilesState _state({PlayerProfile? profile}) => GameProfilesState(
  activeProfileId: profile?.id,
  profiles: profile == null ? const {} : {profile.id: profile},
  legacyMigrationComplete: true,
);

PlayerProfile _profile({PlayerGameProgress? progress}) {
  final badgeMilestones = progress?.badgeMilestones ?? const <int>{};
  final badges = <String, GameBadge>{
    for (final milestone in badgeMilestones)
      '${GameId.waterSort.storageId}:$milestone': GameBadge(
        gameId: GameId.waterSort,
        milestone: milestone,
        earnedAt: DateTime.utc(2026, 10, 24, 9),
      ),
  };
  return PlayerProfile(
    id: 'profile-1',
    name: 'Player',
    createdAt: DateTime.utc(2026, 10, 24, 8),
    updatedAt: DateTime.utc(2026, 10, 24, 9),
    gamesPlayed: progress?.attempts ?? 0,
    gamesWon: progress?.wins ?? 0,
    bestScore: progress == null || progress.bestScores.isEmpty
        ? 0
        : progress.bestScores.values.reduce((a, b) => a > b ? a : b),
    gameProgress: progress == null ? const {} : {GameId.waterSort: progress},
    badges: badges,
  );
}

PlayerGameProgress _progress({
  required int completed,
  required int generatedThrough,
  Map<int, int>? scores,
}) {
  final descriptors = <int, GameLevelDescriptor>{
    for (var level = 1; level <= generatedThrough; level++)
      level: _descriptor(level),
  };
  final bestScores =
      scores ?? {for (var level = 1; level <= completed; level++) level: 80};
  return PlayerGameProgress(
    gameId: GameId.waterSort,
    currentLevel: completed + 1,
    generatedThrough: generatedThrough,
    descriptors: descriptors,
    fingerprints: descriptors.values
        .map((descriptor) => descriptor.fingerprint)
        .toSet(),
    clearedLevels: {for (var level = 1; level <= completed; level++) level},
    bestScores: bestScores,
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

GameLevelDescriptor _descriptor(int level) => GameLevelDescriptor(
  gameId: GameId.waterSort,
  level: level,
  seed: 3000 + level,
  generatorVersion: 1,
  retrySalt: 0,
  fingerprint: (3000 + level).toRadixString(16).padLeft(64, '0'),
  tier: GameTier.forLevel(level),
  levelPressure: levelPressureFor(level),
);

List<int> _levelsThrough(int last) => [
  for (var level = 1; level <= last; level++) level,
];

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
      throw UnsupportedError('No completion in level-map tests');
}

final class _TestLayout implements GameLevelLayout {
  const _TestLayout(this.canonicalSignature);

  @override
  final String canonicalSignature;
}

Future<void> _reveal(WidgetTester tester, ValueKey<String> key) async {
  final target = find.byKey(key);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pump();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await tester.pump();
  }
  if (!condition()) throw StateError('Timed out waiting for test boundary');
}
