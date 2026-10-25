import 'package:color_lab/features/games/domain/deterministic_random.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('xorshift32 sequence is frozen for seed one', () {
    final random = StableRandom(1);

    expect(List<int>.generate(5, (_) => random.nextUint32()), [
      270369,
      67634689,
      2647435461,
      307599695,
      2398689233,
    ]);
  });

  test('stable shuffle owns its literal Fisher-Yates order', () {
    final source = [0, 1, 2, 3, 4, 5];

    expect(stableShuffle(source, StableRandom(1)), [0, 5, 2, 1, 4, 3]);
    expect(source, [0, 1, 2, 3, 4, 5]);
  });

  test('level seed uses the frozen SHA-256 wire string', () {
    expect(
      deriveLevelSeed(
        profileId: 'profile-a',
        gameId: GameId.waterSort,
        level: 1,
        retrySalt: 0,
      ),
      3628656079,
    );
  });

  test('bounded values reject invalid ranges and remain deterministic', () {
    final first = StableRandom(99);
    final second = StableRandom(99);

    expect(
      List<int>.generate(20, (_) => first.nextInt(7)),
      List<int>.generate(20, (_) => second.nextInt(7)),
    );
    expect(() => first.nextInt(0), throwsArgumentError);
    expect(first.nextDouble(), inInclusiveRange(0.0, 1.0));
  });

  test('seed derivation rejects malformed identity and counters', () {
    expect(
      () => deriveLevelSeed(
        profileId: '',
        gameId: GameId.waterSort,
        level: 1,
        retrySalt: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => deriveLevelSeed(
        profileId: ' profile-a ',
        gameId: GameId.waterSort,
        level: 1,
        retrySalt: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => deriveLevelSeed(
        profileId: 'profile-a',
        gameId: GameId.waterSort,
        level: 0,
        retrySalt: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => deriveLevelSeed(
        profileId: 'profile-a',
        gameId: GameId.waterSort,
        level: 1,
        retrySalt: -1,
      ),
      throwsArgumentError,
    );
  });
}
