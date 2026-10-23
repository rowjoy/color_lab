import 'dart:async';
import 'dart:io';

import 'package:color_lab/data/db/hive_app_preferences_repository.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/features/settings/domain/app_preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

// Reads, writes and files remain real; inject only durability/async boundaries.
class _BoundaryBox implements Box<dynamic> {
  _BoundaryBox(this.delegate);
  final Box<dynamic> delegate;
  bool failFlush = false;
  bool failClose = false;
  Completer<void>? writeGate;
  @override
  bool containsKey(dynamic key) => delegate.containsKey(key);
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) async {
    await writeGate?.future;
    await delegate.put(key, value);
  }

  @override
  Future<void> flush() async {
    if (failFlush) throw const FileSystemException('injected flush');
    await delegate.flush();
  }

  @override
  Future<void> close() async {
    if (failClose) throw const FileSystemException('injected close');
    await delegate.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late Directory directory;
  final storageError = throwsA(isA<PreferencesStorageException>());
  const dark = AppPreferences(
    themeMode: ThemeMode.dark,
    onboardingCompleted: true,
  );
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('preferences-test-');
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'empty file defaults and dark completed state survives actual reopen',
    () async {
      var repository = await HiveAppPreferencesRepository.open(
        directory: directory.path,
      );
      expect(await repository.load(), const AppPreferences());
      await repository.save(dark);
      await repository.close();
      repository = await HiveAppPreferencesRepository.open(
        directory: directory.path,
      );
      expect(await repository.load(), dark);
      await repository.close();
    },
  );

  test(
    'equal box names in different directories never share cached data',
    () async {
      final other = await Directory.systemTemp.createTemp(
        'preferences-independent-',
      );
      final first = await HiveAppPreferencesRepository.open(
        directory: directory.path,
      );
      final second = await HiveAppPreferencesRepository.open(
        directory: other.path,
      );
      try {
        await first.save(dark);
        expect(await second.load(), const AppPreferences());
        await second.save(const AppPreferences(themeMode: ThemeMode.light));
        expect(await first.load(), dark);
      } finally {
        await first.close();
        await second.close();
        await other.delete(recursive: true);
      }
    },
  );

  test(
    'malformed records are preserved and cannot be silently overwritten',
    () async {
      for (final record in [
        null,
        'not a map',
        {'schemaVersion': 99, 'themeMode': 'dark'},
      ]) {
        final box = await HiveImpl().openBox<dynamic>(
          'corrupt',
          path: directory.path,
        );
        await box.put('preferences', record);
        final repository = HiveAppPreferencesRepository.fromBox(box: box);
        await expectLater(repository.load(), storageError);
        await expectLater(repository.save(dark), storageError);
        expect(box.get('preferences'), record);
        await repository.close();
      }
    },
  );

  Future<(_BoundaryBox, HiveAppPreferencesRepository)>
  boundaryRepository() async {
    final box = _BoundaryBox(
      await HiveImpl().openBox<dynamic>(
        'app_preferences_v1',
        path: directory.path,
      ),
    );
    return (box, HiveAppPreferencesRepository.fromBox(box: box));
  }

  test(
    'failed flush blocks load and unchanged save until retry reaches disk',
    () async {
      final (box, repository) = await boundaryRepository();
      box.failFlush = true;
      await expectLater(repository.save(dark), storageError);
      await expectLater(repository.load(), storageError);
      await expectLater(repository.save(dark), storageError);
      box.failFlush = false;
      expect(await repository.load(), dark);
      await repository.close();
      final reopened = await HiveAppPreferencesRepository.open(
        directory: directory.path,
      );
      expect(await reopened.load(), dark);
      await reopened.close();
    },
  );

  test(
    'load and close wait behind pending writes and reject edits after close',
    () async {
      final (box, repository) = await boundaryRepository();
      box.writeGate = Completer<void>();
      final save = repository.save(dark);
      var loaded = false;
      final load = repository.load().then((value) {
        loaded = true;
        return value;
      });
      final close = repository.close();
      await expectLater(repository.save(const AppPreferences()), storageError);
      await Future<void>.delayed(Duration.zero);
      expect(loaded, false);
      box.writeGate!.complete();
      await save;
      expect(await load, dark);
      await close;
      final reopened = await HiveAppPreferencesRepository.open(
        directory: directory.path,
      );
      expect(await reopened.load(), dark);
      await reopened.close();
    },
  );

  test(
    'failed pending flush and failed box close both permit close retry',
    () async {
      final (box, repository) = await boundaryRepository();
      box.failFlush = true;
      await expectLater(repository.save(dark), storageError);
      await expectLater(repository.close(), storageError);
      box.failFlush = false;
      box.failClose = true;
      await expectLater(repository.close(), storageError);
      box.failClose = false;
      await repository.close();
      final reopened = await HiveAppPreferencesRepository.open(
        directory: directory.path,
      );
      expect(await reopened.load(), dark);
      await reopened.close();
    },
  );

  test(
    'opening a directory occupying the Hive file reports a safe error',
    () async {
      await Directory('${directory.path}/app_preferences_v1.hive').create();
      await expectLater(
        HiveAppPreferencesRepository.open(directory: directory.path),
        storageError,
      );
      expect(
        await Directory('${directory.path}/app_preferences_v1.hive').exists(),
        true,
      );
    },
  );
}
