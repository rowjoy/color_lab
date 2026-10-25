import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'game_id.dart';

final class StableRandom implements Random {
  StableRandom(int seed) {
    if (seed < 0 || seed > _mask) {
      throw ArgumentError.value(seed, 'seed', 'Must be an unsigned 32-bit int');
    }
    _state = seed == 0 ? _zeroSeed : seed;
  }

  StableRandom._fromState(this._state);

  static const int _mask = 0xffffffff;
  static const int _zeroSeed = 0x6d2b79f5;
  static const double _uint32Range = 4294967296;

  late int _state;

  StableRandom copy() => StableRandom._fromState(_state);

  int nextUint32() {
    var value = _state;
    value = (value ^ ((value << 13) & _mask)) & _mask;
    value = (value ^ (value >> 17)) & _mask;
    value = (value ^ ((value << 5) & _mask)) & _mask;
    _state = value;
    return value;
  }

  @override
  int nextInt(int upperBound) {
    if (upperBound < 1) {
      throw ArgumentError.value(upperBound, 'upperBound', 'Must be positive');
    }
    return nextUint32() % upperBound;
  }

  @override
  double nextDouble() => nextUint32() / _uint32Range;

  @override
  bool nextBool() => nextUint32().isOdd;
}

List<T> stableShuffle<T>(Iterable<T> values, StableRandom random) {
  final result = List<T>.of(values);
  for (var index = result.length - 1; index > 0; index--) {
    final swapIndex = random.nextInt(index + 1);
    final value = result[index];
    result[index] = result[swapIndex];
    result[swapIndex] = value;
  }
  return result;
}

int deriveLevelSeed({
  required String profileId,
  required GameId gameId,
  required int level,
  required int retrySalt,
  int generatorVersion = 1,
}) {
  if (profileId.isEmpty || profileId.trim() != profileId) {
    throw ArgumentError.value(
      profileId,
      'profileId',
      'Must be non-empty without surrounding whitespace',
    );
  }
  if (level < 1) {
    throw ArgumentError.value(level, 'level', 'Must be positive');
  }
  if (retrySalt < 0) {
    throw ArgumentError.value(retrySalt, 'retrySalt', 'Must not be negative');
  }
  if (generatorVersion < 1) {
    throw ArgumentError.value(
      generatorVersion,
      'generatorVersion',
      'Must be positive',
    );
  }

  final bytes = sha256
      .convert(
        utf8.encode(
          'v$generatorVersion|$profileId|${gameId.storageId}|$level|$retrySalt',
        ),
      )
      .bytes;
  return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
}
