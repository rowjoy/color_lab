import 'dart:io';

import 'package:color_lab/data/db/hive_game_profiles_repository.dart';
import 'package:color_lab/features/games/domain/game_id.dart';
import 'package:color_lab/features/games/domain/game_level_adapter.dart';
import 'package:color_lab/features/games/domain/game_level_catalog.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/domain/game_progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';
// Hive 2 has no public independent-registry factory.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

void main() {
  late Directory directory;
  final storageError = throwsA(isA<GameProfilesStorageException>());

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'game-profiles-migration-',
    );
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('absent legacy data starts and reopens as migration complete', () async {
    var repository = await HiveGameProfilesRepository.open(
      directory: directory.path,
    );
    var state = await repository.loadState();
    expect(state.profiles, isEmpty);
    expect(state.activeProfileId, isNull);
    expect(state.pendingLegacySnapshot, isNull);
    expect(state.legacyMigrationComplete, isTrue);
    await repository.close();

    repository = await HiveGameProfilesRepository.open(
      directory: directory.path,
    );
    state = await repository.loadState();
    expect(state.profiles, isEmpty);
    expect(state.pendingLegacySnapshot, isNull);
    expect(state.legacyMigrationComplete, isTrue);
    await repository.close();
  });

  test(
    'valid legacy data remains pending across restart before import',
    () async {
      await _writeBoxValue(
        directory.path,
        'game_progress_v1',
        'progress',
        _legacyMap,
      );

      var repository = await HiveGameProfilesRepository.open(
        directory: directory.path,
      );
      var state = await repository.loadState();
      _expectPendingLegacy(state);
      await repository.close();

      repository = await HiveGameProfilesRepository.open(
        directory: directory.path,
      );
      state = await repository.loadState();
      _expectPendingLegacy(state);
      await repository.close();

      final legacy = await _readBoxEntry(
        directory.path,
        'game_progress_v1',
        'progress',
      );
      expect(legacy.containsKey, isTrue);
      expect(legacy.value, _legacyMap);
    },
  );

  test(
    'first profile imports legacy once, restart uses v2, and legacy stays',
    () async {
      await _writeBoxValue(
        directory.path,
        'game_progress_v1',
        'progress',
        _legacyMap,
      );
      final engine = GameProgressionEngine(
        catalog: GameLevelCatalog(registry: _UnusedRegistry()),
      );
      var repository = await HiveGameProfilesRepository.open(
        directory: directory.path,
      );

      final first = await repository.transact(
        (current) => engine.createProfile(
          state: current,
          profileId: 'profile-1',
          name: 'Me',
          now: _createdAt,
        ),
      );
      expect(first.value.coins, 135);
      expect(first.value.gamesPlayed, 12);
      expect(first.value.gamesWon, 7);
      expect(first.value.bestScore, 92);
      expect(
        first.value.gameProgress,
        isEmpty,
        reason: 'legacy bestScore is profile-wide, not assigned to a game',
      );
      expect(first.state.pendingLegacySnapshot, isNull);
      expect(first.state.legacyMigrationComplete, isTrue);
      await repository.close();

      final legacyAfterImport = await _readBoxEntry(
        directory.path,
        'game_progress_v1',
        'progress',
      );
      expect(legacyAfterImport.containsKey, isTrue);
      expect(legacyAfterImport.value, _legacyMap);

      repository = await HiveGameProfilesRepository.open(
        directory: directory.path,
      );
      final reopened = await repository.loadState();
      expect(reopened.profiles.keys, ['profile-1']);
      expect(reopened.activeProfile!.coins, 135);
      expect(reopened.activeProfile!.bestScore, 92);
      expect(reopened.activeProfile!.gameProgress, isEmpty);
      expect(reopened.pendingLegacySnapshot, isNull);
      expect(reopened.legacyMigrationComplete, isTrue);

      final second = await repository.transact(
        (current) => engine.createProfile(
          state: current,
          profileId: 'profile-2',
          name: 'Guest',
          now: _createdAt.add(const Duration(minutes: 1)),
        ),
      );
      expect(second.value.coins, 0);
      expect(second.value.gamesPlayed, 0);
      expect(second.value.gamesWon, 0);
      expect(second.value.bestScore, 0);
      expect(second.state.profiles['profile-1']!.coins, 135);
      expect(second.state.profiles.keys, ['profile-1', 'profile-2']);
      await repository.close();

      final legacyAfterSecond = await _readBoxEntry(
        directory.path,
        'game_progress_v1',
        'progress',
      );
      expect(legacyAfterSecond.containsKey, isTrue);
      expect(legacyAfterSecond.value, _legacyMap);
    },
  );

  test(
    'malformed legacy data fails load and transact without overwrite',
    () async {
      final records = <Object?>[
        null,
        'not a map',
        {..._legacyMap, 'schemaVersion': 99},
        {..._legacyMap, 'extra': true},
        {..._legacyMap, 'gamesWon': 8},
      ];

      for (var index = 0; index < records.length; index++) {
        final caseDirectory = Directory('${directory.path}/legacy-$index');
        await caseDirectory.create();
        final legacyBoxName = 'legacy_$index';
        final stateBoxName = 'state_$index';
        final record = records[index];
        await _writeBoxValue(
          caseDirectory.path,
          legacyBoxName,
          'progress',
          record,
        );
        final repository = await HiveGameProfilesRepository.open(
          directory: caseDirectory.path,
          boxName: stateBoxName,
          legacyBoxName: legacyBoxName,
        );

        await expectLater(
          repository.loadState(),
          storageError,
          reason: '$record',
        );
        var transitionCalled = false;
        await expectLater(
          repository.transact<void>((current) {
            transitionCalled = true;
            return ProgressionChange<void>(state: current, value: null);
          }),
          storageError,
          reason: '$record',
        );
        expect(transitionCalled, isFalse, reason: '$record');
        await repository.close();

        final unchanged = await _readBoxEntry(
          caseDirectory.path,
          legacyBoxName,
          'progress',
        );
        expect(unchanged.containsKey, isTrue, reason: '$record');
        expect(unchanged.value, record, reason: '$record');
        final stateEntry = await _readBoxEntry(
          caseDirectory.path,
          stateBoxName,
          'state',
        );
        expect(stateEntry.containsKey, isFalse, reason: '$record');
      }
    },
  );

  test(
    'malformed v2 never falls back to valid legacy or overwrites bytes',
    () async {
      final validEmpty = GameProfilesState(
        activeProfileId: null,
        profiles: const {},
        legacyMigrationComplete: true,
      ).toMap();
      final records = <Object?>[
        null,
        'not a map',
        {...validEmpty, 'schemaVersion': 3},
        {...validEmpty, 'extra': true},
      ];

      for (var index = 0; index < records.length; index++) {
        final caseDirectory = Directory('${directory.path}/v2-$index');
        await caseDirectory.create();
        final legacyBoxName = 'legacy_$index';
        final stateBoxName = 'state_$index';
        final record = records[index];
        await _writeBoxValue(
          caseDirectory.path,
          legacyBoxName,
          'progress',
          _legacyMap,
        );
        await _writeBoxValue(caseDirectory.path, stateBoxName, 'state', record);
        final repository = await HiveGameProfilesRepository.open(
          directory: caseDirectory.path,
          boxName: stateBoxName,
          legacyBoxName: legacyBoxName,
        );

        await expectLater(
          repository.loadState(),
          storageError,
          reason: '$record',
        );
        var transitionCalled = false;
        await expectLater(
          repository.transact<void>((current) {
            transitionCalled = true;
            return ProgressionChange<void>(state: current, value: null);
          }),
          storageError,
          reason: '$record',
        );
        expect(transitionCalled, isFalse, reason: '$record');
        await repository.close();

        final unchanged = await _readBoxEntry(
          caseDirectory.path,
          stateBoxName,
          'state',
        );
        expect(unchanged.containsKey, isTrue, reason: '$record');
        expect(unchanged.value, record, reason: '$record');
        final legacy = await _readBoxEntry(
          caseDirectory.path,
          legacyBoxName,
          'progress',
        );
        expect(legacy.value, _legacyMap, reason: '$record');
      }
    },
  );

  test('valid v2 takes precedence without parsing malformed legacy', () async {
    final state = GameProfilesState(
      activeProfileId: null,
      profiles: const {},
      legacyMigrationComplete: true,
    );
    await _writeBoxValue(
      directory.path,
      'game_profiles_v2',
      'state',
      state.toMap(),
    );
    await _writeBoxValue(
      directory.path,
      'game_progress_v1',
      'progress',
      'malformed legacy',
    );

    final repository = await HiveGameProfilesRepository.open(
      directory: directory.path,
    );
    expect((await repository.loadState()).toMap(), state.toMap());
    await repository.close();

    final legacy = await _readBoxEntry(
      directory.path,
      'game_progress_v1',
      'progress',
    );
    expect(legacy.containsKey, isTrue);
    expect(legacy.value, 'malformed legacy');
  });
}

const Map<String, Object?> _legacyMap = {
  'schemaVersion': 1,
  'coins': 135,
  'gamesPlayed': 12,
  'gamesWon': 7,
  'bestScore': 92,
  'lastDifficulty': 'hard',
  'easyWins': 2,
  'mediumWins': 3,
  'hardWins': 2,
};

final DateTime _createdAt = DateTime.utc(2026, 10, 24, 8);

void _expectPendingLegacy(GameProfilesState state) {
  expect(state.profiles, isEmpty);
  expect(state.activeProfileId, isNull);
  expect(state.legacyMigrationComplete, isFalse);
  expect(state.pendingLegacySnapshot, isNotNull);
  expect(state.pendingLegacySnapshot!.coins, 135);
  expect(state.pendingLegacySnapshot!.gamesPlayed, 12);
  expect(state.pendingLegacySnapshot!.gamesWon, 7);
  expect(state.pendingLegacySnapshot!.bestScore, 92);
}

Future<void> _writeBoxValue(
  String directory,
  String boxName,
  String key,
  Object? value,
) async {
  final box = await HiveImpl().openBox<dynamic>(
    boxName,
    path: directory,
    crashRecovery: false,
  );
  await box.put(key, value);
  await box.flush();
  await box.close();
}

Future<({bool containsKey, Object? value})> _readBoxEntry(
  String directory,
  String boxName,
  String key,
) async {
  final box = await HiveImpl().openBox<dynamic>(
    boxName,
    path: directory,
    crashRecovery: false,
  );
  final entry = (containsKey: box.containsKey(key), value: box.get(key));
  await box.close();
  return entry;
}

final class _UnusedRegistry implements GameLevelAdapterRegistry {
  @override
  GameLevelAdapter adapterFor(GameId gameId) =>
      throw StateError('No game levels are generated during migration');
}
