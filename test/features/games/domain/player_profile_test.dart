import 'package:color_lab/features/games/domain/game_badge.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_launch.dart';
import 'package:color_lab/features/games/domain/game_level.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 10, 24, 8);
  final updatedAt = DateTime.utc(2026, 10, 24, 9);

  test('profile names use trimmed visible graphemes and normalized keys', () {
    final profile = PlayerProfile(
      id: 'profile-1',
      name: '  A👩🏽‍🎨  ',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );

    expect(profile.name, 'A👩🏽‍🎨');
    expect(profile.normalizedName, 'a👩🏽‍🎨');
    expect(PlayerProfile.normalizedNameFor('  ME  '), 'me');
    for (final invalid in [
      ' ',
      'A',
      '👩🏽‍🎨',
      'a' * 21,
      'Good\nName',
      '\nGood Name\n',
      'Bad\u007fName',
    ]) {
      expect(
        () => PlayerProfile(
          id: 'profile-1',
          name: invalid,
          createdAt: createdAt,
          updatedAt: updatedAt,
        ),
        throwsArgumentError,
        reason: invalid,
      );
    }
    expect(
      PlayerProfile(
        id: 'profile-2',
        name: 'a' * 20,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ).name,
      'a' * 20,
    );
    expect(
      PlayerProfile(
        id: 'profile-3',
        name: '👩🏽‍🎨' * 3,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ).name.characters.length,
      3,
    );
  });

  test('attempt, launch, receipt, and badge freeze strict value contracts', () {
    final descriptor = level(GameId.waterSort, 20);
    final attempt = ActiveGameAttempt(
      attemptId: 'attempt-7',
      sequence: 7,
      level: 20,
      playKind: GamePlayKind.current,
      descriptorFingerprint: descriptor.fingerprint,
      startedAt: createdAt,
    );
    final launch = GameLaunch(
      profileId: 'profile-1',
      gameId: GameId.waterSort,
      descriptor: descriptor,
      attemptId: attempt.attemptId,
      playKind: attempt.playKind,
    );
    final badge = GameBadge(
      gameId: GameId.waterSort,
      milestone: 20,
      earnedAt: updatedAt,
    );
    final receipt = LevelCompletionReceipt(
      attemptId: attempt.attemptId,
      attemptSequence: attempt.sequence,
      level: 20,
      descriptorFingerprint: descriptor.fingerprint,
      normalizedScore: 91,
      firstClear: true,
      coinsAwarded: 50,
      badgeId: badge.id,
      currentLevelAfter: 21,
      completedAt: updatedAt,
    );

    expect(ActiveGameAttempt.fromMap(attempt.toMap()).toMap(), attempt.toMap());
    expect(launch.descriptor, descriptor);
    expect(launch.playKind, GamePlayKind.current);
    expect(GameBadge.fromMap(badge.toMap()).toMap(), badge.toMap());
    expect(badge.id, 'waterSort:20');
    expect(badge.accessibleLabel, 'Water Sort Level 20 badge');
    expect(
      LevelCompletionReceipt.fromMap(receipt.toMap()).toMap(),
      receipt.toMap(),
    );
    expect(receipt.alreadyApplied, isFalse);
    expect(receipt.asAlreadyApplied().alreadyApplied, isTrue);
    expect(receipt.asAlreadyApplied().toMap(), receipt.toMap());
    expect(
      () => GameBadge(
        gameId: GameId.waterSort,
        milestone: 21,
        earnedAt: updatedAt,
      ),
      throwsArgumentError,
    );
  });

  test(
    'nested progress and profile maps round trip as immutable snapshots',
    () {
      final levels = levelMap(GameId.bubbleShooter, 3);
      final active = ActiveGameAttempt(
        attemptId: 'attempt-2',
        sequence: 2,
        level: 2,
        playKind: GamePlayKind.current,
        descriptorFingerprint: levels[2]!.fingerprint,
        startedAt: updatedAt,
      );
      final receipt = LevelCompletionReceipt(
        attemptId: 'attempt-1',
        attemptSequence: 1,
        level: 1,
        descriptorFingerprint: levels[1]!.fingerprint,
        normalizedScore: 87,
        firstClear: true,
        coinsAwarded: 10,
        currentLevelAfter: 2,
        completedAt: createdAt,
      );
      final sourceLevels = Map<int, GameLevelDescriptor>.of(levels);
      final progress = PlayerGameProgress(
        gameId: GameId.bubbleShooter,
        currentLevel: 2,
        generatedThrough: 3,
        descriptors: sourceLevels,
        fingerprints: levels.values.map((value) => value.fingerprint).toSet(),
        clearedLevels: const {1},
        bestScores: const {1: 87},
        attempts: 2,
        wins: 1,
        attemptSequence: 2,
        activeAttempt: active,
        latestReceipt: receipt,
        highestCompletedLevel: 1,
        pendingRefillThrough: 30,
      );
      sourceLevels.clear();
      final profile = PlayerProfile(
        id: 'profile-1',
        name: 'Player One',
        createdAt: createdAt,
        updatedAt: updatedAt,
        coins: 10,
        gamesPlayed: 2,
        gamesWon: 1,
        bestScore: 87,
        gameProgress: {GameId.bubbleShooter: progress},
      );

      final decodedProgress = PlayerGameProgress.fromMap(progress.toMap());
      final decodedProfile = PlayerProfile.fromMap(profile.toMap());
      expect(decodedProgress.toMap(), progress.toMap());
      expect(decodedProfile.toMap(), profile.toMap());
      expect(progress.descriptors, hasLength(3));
      expect(() => progress.descriptors.clear(), throwsUnsupportedError);
      expect(() => progress.clearedLevels.add(2), throwsUnsupportedError);
      expect(() => progress.bestScores[1] = 2, throwsUnsupportedError);
      expect(() => profile.gameProgress.clear(), throwsUnsupportedError);
      expect(() => profile.badges.clear(), throwsUnsupportedError);
      expect(
        () => (progress.toMap()['descriptors'] as List).clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('progress rejects duplicate, mismatched, and out-of-range state', () {
    final levels = levelMap(GameId.fruitPop, 2);
    PlayerGameProgress build({
      Map<int, GameLevelDescriptor>? descriptors,
      Set<String>? fingerprints,
      Set<int> cleared = const {1},
      Map<int, int> scores = const {1: 80},
      int currentLevel = 2,
      int highest = 1,
    }) => PlayerGameProgress(
      gameId: GameId.fruitPop,
      currentLevel: currentLevel,
      generatedThrough: 2,
      descriptors: descriptors ?? levels,
      fingerprints:
          fingerprints ??
          levels.values.map((value) => value.fingerprint).toSet(),
      clearedLevels: cleared,
      bestScores: scores,
      attempts: 1,
      wins: 1,
      attemptSequence: 1,
      highestCompletedLevel: highest,
    );

    expect(build().currentLevel, 2);
    final duplicate = {
      1: levels[1]!,
      2: GameLevelDescriptor(
        gameId: GameId.fruitPop,
        level: 2,
        seed: 2,
        generatorVersion: 1,
        retrySalt: 0,
        fingerprint: levels[1]!.fingerprint,
        tier: GameTier.easy,
        levelPressure: levelPressureFor(2),
      ),
    };
    expect(
      () =>
          build(descriptors: duplicate, fingerprints: {levels[1]!.fingerprint}),
      throwsArgumentError,
    );
    expect(
      () => build(descriptors: {1: levels[2]!, 2: levels[1]!}),
      throwsArgumentError,
    );
    expect(() => build(scores: const {1: 101}), throwsArgumentError);
    expect(
      () => build(cleared: const {}, scores: const {}, highest: 0),
      throwsArgumentError,
    );

    final encoded = build().toMap();
    final descriptorList = List<Object?>.of(encoded['descriptors']! as List);
    expect(
      () => PlayerGameProgress.fromMap({
        ...encoded,
        'descriptors': [...descriptorList, descriptorList.first],
      }),
      throwsFormatException,
    );
    expect(
      () => PlayerGameProgress.fromMap({...encoded, 'gameId': 'futureGame'}),
      throwsFormatException,
    );
  });
}

GameLevelDescriptor level(GameId gameId, int number) => GameLevelDescriptor(
  gameId: gameId,
  level: number,
  seed: number,
  generatorVersion: 1,
  retrySalt: 0,
  fingerprint: number.toRadixString(16).padLeft(64, '0'),
  tier: GameTier.forLevel(number),
  levelPressure: levelPressureFor(number),
);

Map<int, GameLevelDescriptor> levelMap(GameId gameId, int through) => {
  for (var number = 1; number <= through; number++)
    number: level(gameId, number),
};
