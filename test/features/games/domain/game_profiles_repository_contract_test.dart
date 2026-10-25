import 'dart:async';

import 'package:color_lab/features/games/domain/game_profiles_repository.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:color_lab/features/games/domain/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_game_profiles_repository.dart';

void main() {
  gameProfilesRepositoryContract(
    'in-memory game profiles repository',
    (initial) async => InMemoryGameProfilesRepository(initialState: initial),
  );

  group('in-memory durability boundaries', () {
    test(
      'overlapping transactions serialize and re-read durable state',
      () async {
        final repository = InMemoryGameProfilesRepository(
          initialState: _state(coins: 0),
        );
        repository.writeGate = Completer<void>();
        final seenCoins = <int>[];

        final first = repository.transact<int>((current) {
          final coins = current.activeProfile!.coins;
          seenCoins.add(coins);
          return _coinChange(current, coins + 1);
        });
        final second = repository.transact<int>((current) {
          final coins = current.activeProfile!.coins;
          seenCoins.add(coins);
          return _coinChange(current, coins + 1);
        });

        await _flushMicrotasks();
        expect(seenCoins, [0]);
        expect(repository.durableState.activeProfile!.coins, 0);

        repository.writeGate!.complete();
        final results = await Future.wait([first, second]);
        expect(seenCoins, [0, 1]);
        expect(results.map((result) => result.value), [1, 2]);
        expect(repository.durableState.activeProfile!.coins, 2);
        expect(repository.writeCount, 2);
      },
    );

    test(
      'transaction result is published only after its state is durable',
      () async {
        final repository = InMemoryGameProfilesRepository(
          initialState: _state(coins: 4),
        );
        repository.writeGate = Completer<void>();
        var completed = false;
        final future = repository
            .transact<int>((current) => _coinChange(current, 9))
            .whenComplete(() {
              completed = true;
            });

        await _flushMicrotasks();
        expect(repository.durableState.activeProfile!.coins, 4);
        expect(completed, isFalse);

        repository.writeGate!.complete();
        final result = await future;
        expect(completed, isTrue);
        expect(result.value, 9);
        expect(result.state, same(repository.durableState));
        expect(repository.durableState.activeProfile!.coins, 9);
      },
    );

    test(
      'injected write failure preserves state and a retry can commit',
      () async {
        final repository = InMemoryGameProfilesRepository(
          initialState: _state(coins: 2),
        )..failWrite = true;

        await expectLater(
          repository.transact<int>((current) => _coinChange(current, 8)),
          throwsA(isA<TestGameProfilesRepositoryException>()),
        );
        expect(repository.durableState.activeProfile!.coins, 2);
        expect(repository.writeAttempts, 1);
        expect(repository.writeCount, 0);

        repository.failWrite = false;
        final retried = await repository.transact<int>(
          (current) => _coinChange(current, 8),
        );
        expect(retried.value, 8);
        expect(repository.durableState.activeProfile!.coins, 8);
      },
    );

    test('a thrown transition never reaches the write boundary', () async {
      final repository = InMemoryGameProfilesRepository(
        initialState: _state(coins: 5),
      );

      await expectLater(
        repository.transact<void>((_) => throw StateError('transition')),
        throwsStateError,
      );

      expect(repository.transitionCount, 1);
      expect(repository.writeAttempts, 0);
      expect(repository.writeCount, 0);
      expect(repository.durableState.activeProfile!.coins, 5);
    });

    test(
      'close waits its turn, rejects new work, and can be retried',
      () async {
        final repository = InMemoryGameProfilesRepository(
          initialState: _state(coins: 0),
        );
        repository.closeGate = Completer<void>();
        final closing = repository.close();

        await expectLater(repository.loadState(), throwsStateError);
        await expectLater(
          repository.transact<int>((current) => _coinChange(current, 1)),
          throwsStateError,
        );
        expect(repository.isClosed, isFalse);

        repository.failClose = true;
        repository.closeGate!.complete();
        await expectLater(
          closing,
          throwsA(isA<TestGameProfilesRepositoryException>()),
        );
        expect(repository.isClosed, isFalse);

        repository.failClose = false;
        repository.closeGate = null;
        await repository.close();
        expect(repository.isClosed, isTrue);
        expect(repository.closeAttempts, 2);
      },
    );
  });
}

typedef GameProfilesRepositoryFactory =
    Future<GameProfilesRepository> Function(GameProfilesState initialState);

/// Shared behavioral contract for every durable game-profile repository.
void gameProfilesRepositoryContract(
  String description,
  GameProfilesRepositoryFactory createRepository,
) {
  group(description, () {
    test('loadState returns the current durable snapshot', () async {
      final initial = _state(coins: 3);
      final repository = await createRepository(initial);
      addTearDown(repository.close);

      final loaded = await repository.loadState();

      expect(loaded.toMap(), initial.toMap());
    });

    test('each transaction receives the latest committed state', () async {
      final repository = await createRepository(_state(coins: 0));
      addTearDown(repository.close);
      final seen = <int>[];

      await repository.transact<int>((current) {
        seen.add(current.activeProfile!.coins);
        return _coinChange(current, 1);
      });
      await repository.transact<int>((current) {
        seen.add(current.activeProfile!.coins);
        return _coinChange(current, 2);
      });

      expect(seen, [0, 1]);
      expect((await repository.loadState()).activeProfile!.coins, 2);
    });

    test('a thrown transition never writes', () async {
      final initial = _state(coins: 6);
      final repository = await createRepository(initial);
      addTearDown(repository.close);

      await expectLater(
        repository.transact<void>((_) => throw StateError('transition')),
        throwsStateError,
      );

      expect((await repository.loadState()).toMap(), initial.toMap());
    });

    test('work submitted after close is rejected', () async {
      final repository = await createRepository(_state(coins: 0));
      await repository.close();

      await expectLater(repository.loadState(), throwsStateError);
      await expectLater(
        repository.transact<int>((current) => _coinChange(current, 1)),
        throwsStateError,
      );
    });
  });
}

final DateTime _time = DateTime.utc(2026, 10, 24, 8);

GameProfilesState _state({required int coins}) {
  final profile = PlayerProfile(
    id: 'profile-1',
    name: 'Player',
    createdAt: _time,
    updatedAt: _time,
    coins: coins,
  );
  return GameProfilesState(
    activeProfileId: profile.id,
    profiles: {profile.id: profile},
    legacyMigrationComplete: true,
  );
}

ProgressionChange<int> _coinChange(GameProfilesState current, int coins) {
  final active = current.activeProfile!;
  final updated = active.copyWith(coins: coins);
  final profiles = Map<String, PlayerProfile>.of(current.profiles)
    ..[active.id] = updated;
  return ProgressionChange<int>(
    state: current.copyWith(profiles: profiles),
    value: coins,
  );
}

Future<void> _flushMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
