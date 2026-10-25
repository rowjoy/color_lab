import 'dart:async';

import 'package:color_lab/features/games/application/game_adapter_registry.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/adapters/rainbow_rings_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_level_catalog.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:color_lab/features/games/domain/rainbow_rings_game.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_animation.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_painter.dart';
import 'package:color_lab/features/games/presentation/rainbow_rings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  testWidgets('uses the descriptor layout and restarts the persisted level', (
    tester,
  ) async {
    final fixture = _fixture(currentLevel: 10);
    var mapOpens = 0;
    final harness = await _pumpScreen(
      tester,
      fixture,
      onOpenMap: () => mapOpens++,
      reducedMotion: false,
    );
    addTearDown(harness.dispose);

    expect(fixture.adapter.lastLayout?.level, 10);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Choose difficulty'), findsNothing);

    await tester.tap(find.text('Map'));
    await tester.pump();
    expect(mapOpens, 1);

    final initialLayout = fixture.adapter.lastLayout!;
    await _finishIntro(tester, initialLayout);
    final oldAttempt = fixture.launch.attemptId;
    final buildsBeforeRestart = fixture.adapter.buildCount;
    await tester.tap(find.byTooltip('Restart level'));
    await _pumpUntil(
      tester,
      () =>
          _progress(harness.repository).activeAttempt?.attemptId !=
              oldAttempt &&
          fixture.adapter.buildCount == buildsBeforeRestart + 1,
    );

    final progress = _progress(harness.repository);
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt?.level, 10);
    expect(progress.activeAttempt?.playKind, GamePlayKind.current);
    expect(progress.activeAttempt?.attemptId, isNot(oldAttempt));
    expect(fixture.adapter.lastLayout?.level, 10);
    expect(fixture.adapter.buildCount, buildsBeforeRestart + 1);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('rainbow-rings-restart')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<GestureDetector>(
            find.byKey(const ValueKey('rainbow-rings-board')),
          )
          .onTapUp,
      isNull,
    );
    await _finishIntro(tester, fixture.adapter.lastLayout!);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('rainbow-rings-restart')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<GestureDetector>(
            find.byKey(const ValueKey('rainbow-rings-board')),
          )
          .onTapUp,
      isNotNull,
    );
  });

  testWidgets(
    'win waits for durability, normalizes moves, and starts persisted next',
    (tester) async {
      final fixture = _fixture(currentLevel: 20, normalizedScore: 73);
      final harness = await _pumpScreen(tester, fixture, reducedMotion: false);
      addTearDown(harness.dispose);
      await _mute(tester);
      final coinsBefore = harness.repository.durableState.activeProfile!.coins;
      final writesBefore = harness.repository.writeAttempts;
      harness.repository.writeGate = Completer<void>();

      await _solve(tester, fixture.adapter.lastLayout!);
      await _pumpUntil(
        tester,
        () => harness.repository.writeAttempts == writesBefore + 1,
      );

      expect(_progress(harness.repository).currentLevel, 20);
      expect(find.text('Next Level'), findsNothing);
      expect(find.textContaining('+50 coins'), findsNothing);
      expect(fixture.adapter.lastOutcome?.actualMoves, greaterThan(0));
      expect(
        fixture.adapter.lastOutcome?.actualMoves,
        fixture.adapter.lastLayout?.inverseSolution.length,
      );
      expect(
        fixture.adapter.lastOutcome?.parMoves,
        fixture.adapter.lastLayout?.parMoves,
      );

      harness.repository.writeGate!.complete();
      harness.repository.writeGate = null;
      await _pumpUntil(
        tester,
        () => find.text('Next Level').evaluate().isNotEmpty,
      );
      await _pumpUntil(tester, () => _winModalReady(tester));

      final completed = _progress(harness.repository);
      expect(completed.currentLevel, 21);
      expect(completed.bestScores[20], 73);
      expect(completed.latestReceipt?.normalizedScore, 73);
      expect(
        harness.repository.durableState.activeProfile!.coins,
        coinsBefore + 50,
      );
      expect(find.textContaining('+50 coins'), findsOneWidget);
      expect(find.textContaining('Badge earned'), findsOneWidget);

      final writesBeforeNext = harness.repository.writeAttempts;
      harness.repository.writeGate = Completer<void>();
      await tester.tap(find.text('Next Level'));
      await _pumpUntil(
        tester,
        () => harness.repository.writeAttempts == writesBeforeNext + 1,
      );
      expect(_progress(harness.repository).activeAttempt, isNull);
      expect(fixture.adapter.lastLayout?.level, 20);

      harness.repository.writeGate!.complete();
      harness.repository.writeGate = null;
      await _pumpUntil(
        tester,
        () => _progress(harness.repository).activeAttempt?.level == 21,
      );
      expect(
        _progress(harness.repository).activeAttempt?.playKind,
        GamePlayKind.current,
      );
      expect(fixture.adapter.lastLayout?.level, 21);
      expect(find.text('21'), findsOneWidget);
      final nextFrame = _frame(tester);
      expect(nextFrame.inputLocked, isTrue);
      expect(nextFrame.confetti, isEmpty);
      expect(nextFrame.sparkles, isEmpty);
      expect(nextFrame.toast, isNull);
      expect(nextFrame.completedPegs, isEmpty);
      expect(
        nextFrame.ringTransforms.values.any(
          (transform) => transform.kind == RainbowRingsRingEffectKind.intro,
        ),
        isTrue,
      );
    },
  );

  testWidgets('duplicate completion suppresses reward celebration', (
    tester,
  ) async {
    final fixture = _fixture(
      currentLevel: 20,
      normalizedScore: 73,
      alreadyCompleted: true,
      newerAttemptAfterCompletion: true,
    );
    final harness = await _pumpScreen(tester, fixture);
    addTearDown(harness.dispose);
    await _mute(tester);
    final coinsBefore = harness.repository.durableState.activeProfile!.coins;
    final writesBefore = harness.repository.writeAttempts;
    final transitionsBefore = harness.repository.transitionCount;
    final newerAttemptId = _progress(
      harness.repository,
    ).activeAttempt!.attemptId;

    await _solve(tester, fixture.adapter.lastLayout!);
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );

    expect(_progress(harness.repository).currentLevel, 21);
    expect(harness.repository.durableState.activeProfile!.coins, coinsBefore);
    expect(harness.repository.writeAttempts, writesBefore);
    expect(harness.repository.transitionCount, transitionsBefore);
    expect(
      _progress(harness.repository).activeAttempt?.attemptId,
      newerAttemptId,
    );
    expect(find.textContaining('+50 coins'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);
    expect(find.text('Level already saved'), findsOneWidget);
    expect(find.textContaining('already saved'), findsOneWidget);
    expect(find.byKey(const ValueKey('rainbow-rings-confetti')), findsNothing);

    final attemptsBeforeNext = _progress(harness.repository).attempts;
    await tester.tap(find.text('Next Level'));
    await _pumpUntil(
      tester,
      () =>
          find.text('This attempt is no longer active.').evaluate().isNotEmpty,
    );

    expect(
      _progress(harness.repository).activeAttempt?.attemptId,
      newerAttemptId,
    );
    expect(_progress(harness.repository).attempts, attemptsBeforeNext);
    expect(harness.repository.writeAttempts, writesBefore);
    expect(harness.repository.transitionCount, transitionsBefore);
    expect(find.text('Next Level'), findsNothing);
  });

  testWidgets('inactive profile rejects even a matching duplicate receipt', (
    tester,
  ) async {
    final fixture = _fixture(currentLevel: 20, alreadyCompleted: true);
    final harness = await _pumpScreen(tester, fixture);
    addTearDown(harness.dispose);
    await _mute(tester);
    await harness.container
        .read(gameProfilesProvider.notifier)
        .createProfile(name: 'Guest');
    await tester.pump();
    final transitionsBefore = harness.repository.transitionCount;

    await _solve(tester, fixture.adapter.lastLayout!);
    await _pumpUntil(
      tester,
      () =>
          find.text('This attempt is no longer active.').evaluate().isNotEmpty,
    );

    expect(harness.repository.transitionCount, transitionsBefore);
    expect(find.text('Level already saved'), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(harness.repository.durableState.activeProfile!.name, 'Guest');
  });

  testWidgets('failed completion keeps a protected Retry save action', (
    tester,
  ) async {
    final fixture = _fixture(currentLevel: 10);
    final harness = await _pumpScreen(tester, fixture);
    addTearDown(harness.dispose);
    await _mute(tester);
    harness.repository.failWrite = true;

    await _solve(tester, fixture.adapter.lastLayout!);
    await _pumpUntil(
      tester,
      () => find.text('Retry save').evaluate().isNotEmpty,
    );

    expect(_progress(harness.repository).currentLevel, 10);
    expect(find.text('Next Level'), findsNothing);
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
  });

  testWidgets(
    'a durable completion survives an optional refill write failure',
    (tester) async {
      final fixture = _fixture(currentLevel: 10, generatedThroughOverride: 19);
      fixture.adapter.failFirstCatalogBuild = true;
      final harness = await _pumpScreen(tester, fixture);
      addTearDown(harness.dispose);
      await _mute(tester);
      fixture.adapter.onCatalogBuildAfterFirst = () {
        harness.repository.failWrite = true;
      };
      final writesBefore = harness.repository.writeAttempts;
      final writeCountBefore = harness.repository.writeCount;

      await _solve(tester, fixture.adapter.lastLayout!);
      await _pumpUntil(
        tester,
        () => find.text('Next Level').evaluate().isNotEmpty,
      );

      final progress = _progress(harness.repository);
      expect(progress.currentLevel, 11);
      expect(progress.latestReceipt?.attemptId, fixture.launch.attemptId);
      expect(progress.pendingRefillThrough, 34);
      expect(harness.repository.writeAttempts, writesBefore + 2);
      expect(harness.repository.writeCount, writeCountBefore + 1);
      expect(find.text('Retry save'), findsNothing);
      expect(find.text('Next Level'), findsOneWidget);
    },
  );

  testWidgets(
    'celebration observes the durable receipt before optional refill settles',
    (tester) async {
      final fixture = _fixture(currentLevel: 10, generatedThroughOverride: 19);
      fixture.adapter.failFirstCatalogBuild = true;
      final harness = await _pumpScreen(tester, fixture, reducedMotion: false);
      addTearDown(harness.dispose);
      await _mute(tester);
      final refillGate = Completer<void>();
      fixture.adapter.onCatalogBuildAfterFirst = () {
        harness.repository.writeGate = refillGate;
      };

      await _solve(tester, fixture.adapter.lastLayout!);
      await _pumpUntil(
        tester,
        () => _progress(harness.repository).latestReceipt != null,
      );

      expect(_progress(harness.repository).currentLevel, 11);
      expect(_progress(harness.repository).pendingRefillThrough, 34);
      expect(_frame(tester).completedPegs, contains(1));
      expect(_frame(tester).confetti, hasLength(80));
      expect(find.text('Retry save'), findsNothing);
      expect(
        find.byKey(const ValueKey('rainbow-rings-win-modal')),
        findsNothing,
      );

      await tester.pump(const Duration(milliseconds: 799));
      expect(
        find.byKey(const ValueKey('rainbow-rings-win-modal')),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('rainbow-rings-win-modal')),
        findsOneWidget,
      );

      refillGate.complete();
      harness.repository.writeGate = null;
      await _pumpUntil(
        tester,
        () => _progress(harness.repository).pendingRefillThrough == null,
      );
    },
  );

  testWidgets('replay restart and win never advance or reward current level', (
    tester,
  ) async {
    final fixture = _fixture(currentLevel: 10, replayLevel: 3);
    final harness = await _pumpScreen(tester, fixture);
    addTearDown(harness.dispose);
    await _mute(tester);
    final coinsBefore = harness.repository.durableState.activeProfile!.coins;
    final badgeIdsBefore = harness
        .repository
        .durableState
        .activeProfile!
        .badges
        .keys
        .toSet();
    final milestonesBefore = _progress(
      harness.repository,
    ).badgeMilestones.toSet();
    final oldAttempt = fixture.launch.attemptId;
    final buildsBeforeRestart = fixture.adapter.buildCount;

    await tester.tap(find.byTooltip('Restart level'));
    await _pumpUntil(
      tester,
      () =>
          _progress(harness.repository).activeAttempt?.attemptId !=
              oldAttempt &&
          fixture.adapter.buildCount == buildsBeforeRestart + 1,
    );
    await tester.pump();
    var progress = _progress(harness.repository);
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt?.level, 3);
    expect(progress.activeAttempt?.playKind, GamePlayKind.replay);
    expect(fixture.adapter.buildCount, buildsBeforeRestart + 1);
    expect(fixture.adapter.lastLayout?.level, 3);
    expect(find.text('3'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('rainbow-rings-restart')),
          )
          .onPressed,
      isNotNull,
    );

    await _solve(tester, fixture.adapter.lastLayout!);
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );

    progress = _progress(harness.repository);
    expect(progress.currentLevel, 10);
    expect(progress.latestReceipt?.firstClear, isFalse);
    expect(progress.latestReceipt?.coinsAwarded, 0);
    expect(harness.repository.durableState.activeProfile!.coins, coinsBefore);
    expect(progress.badgeMilestones, milestonesBefore);
    expect(
      harness.repository.durableState.activeProfile!.badges.keys.toSet(),
      badgeIdsBefore,
    );
    expect(find.textContaining('coins'), findsNothing);
    expect(find.textContaining('Badge earned'), findsNothing);

    await tester.tap(find.text('Next Level'));
    await _pumpUntil(
      tester,
      () => _progress(harness.repository).activeAttempt?.level == 10,
    );
    progress = _progress(harness.repository);
    expect(progress.currentLevel, 10);
    expect(progress.activeAttempt?.playKind, GamePlayKind.current);
    expect(fixture.adapter.lastLayout?.level, 10);
  });

  testWidgets('a stale attempt never becomes a storage retry or reward', (
    tester,
  ) async {
    final fixture = _fixture(currentLevel: 10);
    final harness = await _pumpScreen(tester, fixture);
    addTearDown(harness.dispose);
    await _mute(tester);
    final replacement = await harness.container
        .read(gameProfilesProvider.notifier)
        .beginCurrentAttempt(
          profileId: fixture.launch.profileId,
          gameId: GameId.rainbowRings,
        );

    await _solve(tester, fixture.adapter.lastLayout!);
    await _pumpUntil(
      tester,
      () =>
          find.text('This attempt is no longer active.').evaluate().isNotEmpty,
    );

    expect(find.text('This attempt is no longer active.'), findsOneWidget);
    expect(find.text('Retry save'), findsNothing);
    expect(find.text('Next Level'), findsNothing);
    expect(_progress(harness.repository).currentLevel, 10);
    expect(
      _progress(harness.repository).activeAttempt?.attemptId,
      replacement.attemptId,
    );
    expect(harness.repository.durableState.activeProfile!.coins, 0);
  });

  testWidgets('profile switch after a win cannot start the old profile next', (
    tester,
  ) async {
    final fixture = _fixture(currentLevel: 10);
    final harness = await _pumpScreen(tester, fixture);
    addTearDown(harness.dispose);
    await _mute(tester);

    await _solve(tester, fixture.adapter.lastLayout!);
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    final attemptsAfterWin = _progress(harness.repository).attempts;
    final guest = await harness.container
        .read(gameProfilesProvider.notifier)
        .createProfile(name: 'Guest');
    await tester.pump();
    expect(harness.repository.durableState.activeProfileId, guest.id);

    await tester.tap(find.text('Next Level'));
    await _pumpUntil(
      tester,
      () =>
          find.text('This attempt is no longer active.').evaluate().isNotEmpty,
    );
    await tester.pump(const Duration(milliseconds: 300));

    final oldProgress = _progress(harness.repository);
    expect(oldProgress.currentLevel, 11);
    expect(oldProgress.attempts, attemptsAfterWin);
    expect(oldProgress.activeAttempt, isNull);
    expect(find.text('This attempt is no longer active.'), findsOneWidget);
    expect(find.text('Next Level'), findsNothing);
  });

  testWidgets('failed Next Level keeps a protected persistent retry', (
    tester,
  ) async {
    final fixture = _fixture(currentLevel: 10);
    final harness = await _pumpScreen(tester, fixture);
    addTearDown(harness.dispose);
    await _mute(tester);

    await _solve(tester, fixture.adapter.lastLayout!);
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
    expect(_progress(harness.repository).activeAttempt, isNull);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    expect(find.text('Retry Next Level'), findsOneWidget);

    harness.repository.failWrite = false;
    await tester.tap(find.text('Retry Next Level'));
    await _pumpUntil(
      tester,
      () => _progress(harness.repository).activeAttempt?.level == 11,
    );
    expect(fixture.adapter.lastLayout?.level, 11);
  });

  testWidgets(
    'Next retry adopts the exact attempt when storage throws after commit',
    (tester) async {
      final fixture = _fixture(currentLevel: 10);
      final harness = await _pumpScreen(tester, fixture);
      addTearDown(harness.dispose);
      await _mute(tester);

      await _solve(tester, fixture.adapter.lastLayout!);
      await _pumpUntil(
        tester,
        () => find.text('Next Level').evaluate().isNotEmpty,
      );
      final completed = _progress(harness.repository);
      final expectedSequence = completed.attemptSequence + 1;
      final expectedAttemptId = 'profile-1:rainbowRings:$expectedSequence';
      final attemptsBeforeNext = completed.attempts;
      harness.repository.failAfterWriteAttempt =
          harness.repository.writeAttempts + 2;

      await tester.tap(find.text('Next Level'));
      await _pumpUntil(
        tester,
        () => find.text('Retry Next Level').evaluate().isNotEmpty,
      );

      final durablyStarted = _progress(harness.repository);
      expect(durablyStarted.activeAttempt?.attemptId, expectedAttemptId);
      expect(durablyStarted.activeAttempt?.sequence, expectedSequence);
      expect(durablyStarted.activeAttempt?.level, 11);
      expect(durablyStarted.attempts, attemptsBeforeNext + 1);
      final attemptsAfterCommit = durablyStarted.attempts;
      final gamesPlayedAfterCommit =
          harness.repository.durableState.activeProfile!.gamesPlayed;
      final writesAfterCommit = harness.repository.writeAttempts;
      final transitionsAfterCommit = harness.repository.transitionCount;

      await tester.tap(find.text('Retry Next Level'));
      await _pumpUntil(tester, () => fixture.adapter.lastLayout?.level == 11);

      final adopted = _progress(harness.repository);
      expect(adopted.activeAttempt?.attemptId, expectedAttemptId);
      expect(adopted.activeAttempt?.sequence, expectedSequence);
      expect(adopted.attempts, attemptsAfterCommit);
      expect(
        harness.repository.durableState.activeProfile!.gamesPlayed,
        gamesPlayedAfterCommit,
      );
      expect(harness.repository.writeAttempts, writesAfterCommit + 1);
      expect(harness.repository.transitionCount, transitionsAfterCommit + 1);
      expect(find.text('Retry Next Level'), findsNothing);
      expect(find.text('11'), findsOneWidget);
      expect(_frame(tester).inputLocked, isFalse);
    },
  );

  testWidgets('Next atomically adopts a concurrently started current attempt', (
    tester,
  ) async {
    final fixture = _fixture(currentLevel: 10, generatedThroughOverride: 19);
    fixture.adapter.failFirstCatalogBuild = true;
    final harness = await _pumpScreen(tester, fixture);
    addTearDown(harness.dispose);
    await _mute(tester);
    fixture.adapter.onCatalogBuildAfterFirst = () {
      harness.repository.failWrite = true;
    };

    await _solve(tester, fixture.adapter.lastLayout!);
    await _pumpUntil(
      tester,
      () => find.text('Next Level').evaluate().isNotEmpty,
    );
    final before = _progress(harness.repository);
    final expectedSequence = before.attemptSequence + 1;
    final expectedAttemptId = 'profile-1:rainbowRings:$expectedSequence';
    Future<GameLaunch>? competingLaunch;
    harness.repository.failWrite = false;
    fixture.adapter.catalogBuildAttempts = 1;
    fixture.adapter.onCatalogBuildAfterFirst = () {
      competingLaunch = harness.container
          .read(gameProfilesProvider.notifier)
          .beginCurrentAttempt(
            profileId: fixture.launch.profileId,
            gameId: GameId.rainbowRings,
          );
    };

    await tester.tap(find.text('Next Level'));
    await _pumpUntil(tester, () => fixture.adapter.lastLayout?.level == 11);

    expect(competingLaunch, isNotNull);
    final competing = await competingLaunch!;
    final adopted = _progress(harness.repository);
    expect(competing.attemptId, expectedAttemptId);
    expect(adopted.activeAttempt?.attemptId, expectedAttemptId);
    expect(adopted.activeAttempt?.sequence, expectedSequence);
    expect(adopted.attempts, before.attempts + 1);
    expect(adopted.attemptSequence, expectedSequence);
    expect(find.text('Retry Next Level'), findsNothing);
  });
}

final class _Fixture {
  const _Fixture({
    required this.state,
    required this.launch,
    required this.adapter,
  });

  final GameProfilesState state;
  final GameLaunch launch;
  final _ControlledRainbowAdapter adapter;
}

_Fixture _fixture({
  required int currentLevel,
  int? replayLevel,
  int normalizedScore = 73,
  bool alreadyCompleted = false,
  bool newerAttemptAfterCompletion = false,
  int? generatedThroughOverride,
}) {
  final generatedThrough =
      generatedThroughOverride ?? (currentLevel >= 20 ? 45 : 30);
  final descriptors = <int, GameLevelDescriptor>{
    for (var level = 1; level <= generatedThrough; level++)
      level: _descriptor(level),
  };
  final launchLevel = replayLevel ?? currentLevel;
  final playKind = replayLevel == null
      ? GamePlayKind.current
      : GamePlayKind.replay;
  final sequence = currentLevel + (replayLevel == null ? 0 : 1);
  final attempt = ActiveGameAttempt(
    attemptId: 'profile-1:rainbowRings:$sequence',
    sequence: sequence,
    level: launchLevel,
    playKind: playKind,
    descriptorFingerprint: descriptors[launchLevel]!.fingerprint,
    startedAt: DateTime.utc(2026, 10, 24, 9),
  );
  final progress = PlayerGameProgress(
    gameId: GameId.rainbowRings,
    currentLevel: currentLevel,
    generatedThrough: generatedThrough,
    descriptors: descriptors,
    fingerprints: descriptors.values
        .map((descriptor) => descriptor.fingerprint)
        .toSet(),
    clearedLevels: {for (var level = 1; level < currentLevel; level++) level},
    bestScores: {for (var level = 1; level < currentLevel; level++) level: 80},
    attempts: sequence,
    wins: currentLevel - 1,
    attemptSequence: sequence,
    activeAttempt: attempt,
    highestCompletedLevel: currentLevel - 1,
  );
  final profile = PlayerProfile(
    id: 'profile-1',
    name: 'Player',
    createdAt: DateTime.utc(2026, 10, 24, 8),
    updatedAt: DateTime.utc(2026, 10, 24, 9),
    gamesPlayed: sequence,
    gamesWon: currentLevel - 1,
    bestScore: currentLevel == 1 ? 0 : 80,
    gameProgress: {GameId.rainbowRings: progress},
  );
  var state = GameProfilesState(
    activeProfileId: profile.id,
    profiles: {profile.id: profile},
    legacyMigrationComplete: true,
  );
  final launch = GameLaunch(
    profileId: profile.id,
    gameId: GameId.rainbowRings,
    descriptor: descriptors[launchLevel]!,
    attemptId: attempt.attemptId,
    playKind: playKind,
  );
  final adapter = _ControlledRainbowAdapter(normalizedScore);
  if (alreadyCompleted) {
    final engine = GameProgressionEngine(
      catalog: GameLevelCatalog(registry: _Registry(adapter)),
    );
    state = engine
        .completeLevel(
          state: state,
          launch: launch,
          normalizedScore: normalizedScore,
          completedAt: DateTime.utc(2026, 10, 24, 10),
        )
        .state;
    if (newerAttemptAfterCompletion) {
      state = engine
          .beginCurrentAttempt(
            state: state,
            profileId: profile.id,
            gameId: GameId.rainbowRings,
            startedAt: DateTime.utc(2026, 10, 24, 10, 1),
          )
          .state;
    }
  }
  return _Fixture(state: state, launch: launch, adapter: adapter);
}

GameLevelDescriptor _descriptor(int level) => GameLevelDescriptor(
  gameId: GameId.rainbowRings,
  level: level,
  seed: 0xdef000 + level,
  generatorVersion: 1,
  retrySalt: 0,
  fingerprint: level.toRadixString(16).padLeft(64, '0'),
  tier: GameTier.forLevel(level),
  levelPressure: levelPressureFor(level),
);

final class _Harness {
  const _Harness({required this.container, required this.repository});

  final ProviderContainer container;
  final InMemoryGameProfilesRepository repository;

  void dispose() => container.dispose();
}

Future<_Harness> _pumpScreen(
  WidgetTester tester,
  _Fixture fixture, {
  VoidCallback? onOpenMap,
  bool reducedMotion = true,
}) async {
  final repository = InMemoryGameProfilesRepository(
    initialState: fixture.state,
  );
  var tick = 0;
  final container = ProviderContainer(
    overrides: [
      gameProfilesRepositoryProvider.overrideWith((ref) async => repository),
      gameAdapterRegistryProvider.overrideWithValue(_Registry(fixture.adapter)),
      gameProfilesClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 10, 24, 11).add(Duration(seconds: tick++)),
      ),
    ],
  );
  await container.read(gameProfilesProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(disableAnimations: reducedMotion),
          child: RainbowRingsScreen(
            launch: fixture.launch,
            onOpenMap: onOpenMap,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Harness(container: container, repository: repository);
}

PlayerGameProgress _progress(InMemoryGameProfilesRepository repository) =>
    repository.durableState.profiles['profile-1']!.gameProgress[GameId
        .rainbowRings]!;

Future<void> _mute(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Mute game sounds'));
  await tester.pump();
}

Future<void> _solve(WidgetTester tester, RainbowRingsLevelLayout layout) async {
  await _finishIntro(tester, layout);
  final board = find.byKey(const ValueKey('rainbow-rings-board'));
  expect(board, findsOneWidget);
  final rect = tester.getRect(board);
  final pegWidth = rect.width / layout.stacks.length;
  for (final move in layout.inverseSolution) {
    await tester.tapAt(
      Offset(rect.left + pegWidth * (move.sourcePeg + .5), rect.center.dy),
    );
    await tester.pump();
    await tester.tapAt(
      Offset(rect.left + pegWidth * (move.destinationPeg + .5), rect.center.dy),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }
}

Future<void> _finishIntro(
  WidgetTester tester,
  RainbowRingsLevelLayout layout,
) => tester.pump(
  const Duration(milliseconds: 700) +
      const Duration(milliseconds: 55) * (layout.ringColors.length - 1),
);

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue);
}

bool _winModalReady(WidgetTester tester) {
  final interaction = find.byKey(
    const ValueKey('rainbow-rings-win-modal-interaction'),
  );
  if (interaction.evaluate().isEmpty) return false;
  return !tester.widget<IgnorePointer>(interaction).ignoring;
}

RainbowRingsFrame _frame(WidgetTester tester) {
  final paint = find.descendant(
    of: find.byKey(const ValueKey('rainbow-rings-repaint-boundary')),
    matching: find.byType(CustomPaint),
  );
  final painter = tester.widget<CustomPaint>(paint).painter!;
  expect(painter, isA<RainbowRingsPainter>());
  final rainbow = painter as RainbowRingsPainter;
  return rainbow.timeline.sample(rainbow.clock.value);
}

final class _Registry implements GameLevelAdapterRegistry {
  const _Registry(this.adapter);

  final _ControlledRainbowAdapter adapter;

  @override
  GameLevelAdapter adapterFor(GameId gameId) {
    if (gameId != GameId.rainbowRings) {
      throw StateError('Unexpected adapter request for $gameId');
    }
    return adapter;
  }
}

final class _ControlledRainbowAdapter implements GameLevelAdapter {
  _ControlledRainbowAdapter(this.normalizedScore);

  final int normalizedScore;
  final RainbowRingsLevelAdapter _delegate = RainbowRingsLevelAdapter();
  int buildCount = 0;
  int catalogBuildAttempts = 0;
  bool failFirstCatalogBuild = false;
  VoidCallback? onCatalogBuildAfterFirst;
  RainbowRingsLevelLayout? lastLayout;
  RainbowRingsMoveOutcome? lastOutcome;

  @override
  GameId get gameId => GameId.rainbowRings;

  @override
  int get currentGeneratorVersion => 1;

  @override
  bool supportsVersion(int version) => version == 1;

  @override
  RainbowRingsLevelLayout build(GameLevelDescriptor descriptor) {
    buildCount++;
    if (descriptor.fingerprint == '0' * 64) {
      catalogBuildAttempts++;
      if (failFirstCatalogBuild && catalogBuildAttempts == 1) {
        throw StateError('forced first catalog generation failure');
      }
      if (catalogBuildAttempts == 2) {
        final callback = onCatalogBuildAfterFirst;
        onCatalogBuildAfterFirst = null;
        callback?.call();
      }
    }
    return lastLayout = _delegate.build(descriptor);
  }

  @override
  int normalizeScore(GameLevelOutcome outcome) {
    if (outcome is! RainbowRingsMoveOutcome) {
      throw ArgumentError.value(outcome, 'outcome');
    }
    lastOutcome = outcome;
    return normalizedScore;
  }
}
