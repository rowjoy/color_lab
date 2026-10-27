import 'dart:async';
import 'dart:io';

import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/application/theme_mode_provider.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/features/settings/domain/app_preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryRepository implements AppPreferencesRepository {
  AppPreferences stored = const AppPreferences();
  Completer<void>? writeGate;
  Completer<void>? loadGate;
  bool failSave = false;
  bool failLoad = false;
  int writes = 0;
  @override
  Future<AppPreferences> load() async {
    await loadGate?.future;
    if (failLoad) throw const PreferencesStorageException();
    return stored;
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    await writeGate?.future;
    if (failSave) throw const PreferencesStorageException();
    writes++;
    stored = preferences;
  }

  @override
  Future<void> close() async {}
}

void main() {
  ProviderContainer containerFor(_MemoryRepository repository) {
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'accessibility writes merge and failed save retains committed values',
    () async {
      final repository = _MemoryRepository();
      final container = containerFor(repository);
      await container.read(appPreferencesProvider.future);
      final controller = container.read(appPreferencesProvider.notifier);
      await Future.wait([
        controller.setMotion(MotionPreference.reduce),
        controller.setHighContrast(true),
        controller.setAlwaysShowColorLabels(true),
      ]);
      final saved = container.read(appPreferencesProvider).requireValue;
      expect(saved.motion, MotionPreference.reduce);
      expect(saved.highContrast, true);
      expect(saved.alwaysShowColorLabels, true);
      repository.failSave = true;
      await expectLater(
        controller.setHighContrast(false),
        throwsA(isA<PreferencesStorageException>()),
      );
      expect(container.read(appPreferencesProvider).requireValue, saved);
    },
  );

  test(
    'theme defaults while loading and follows durable preferences',
    () async {
      final repository = _MemoryRepository()
        ..stored = const AppPreferences(themeMode: ThemeMode.dark)
        ..loadGate = Completer<void>();
      final container = containerFor(repository);
      expect(container.read(themeModeProvider), ThemeMode.system);
      repository.loadGate!.complete();
      await container.read(appPreferencesProvider.future);
      expect(container.read(themeModeProvider), ThemeMode.dark);
    },
  );

  test(
    'queued edits merge durable snapshot and publish only after save',
    () async {
      final repository = _MemoryRepository();
      final container = containerFor(repository);
      await container.read(appPreferencesProvider.future);
      repository.writeGate = Completer<void>();
      final theme = container
          .read(themeModeProvider.notifier)
          .setMode(ThemeMode.dark);
      final onboarding = container
          .read(appPreferencesProvider.notifier)
          .completeOnboarding();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(
        container.read(appPreferencesProvider).requireValue.onboardingCompleted,
        false,
      );
      repository.writeGate!.complete();
      await Future.wait([theme, onboarding]);
      expect(
        container.read(appPreferencesProvider).requireValue,
        const AppPreferences(
          themeMode: ThemeMode.dark,
          onboardingCompleted: true,
        ),
      );
      expect(
        repository.stored,
        const AppPreferences(
          themeMode: ThemeMode.dark,
          onboardingCompleted: true,
        ),
      );
    },
  );

  test(
    'edits read current durable record instead of stale published fields',
    () async {
      final repository = _MemoryRepository();
      final container = containerFor(repository);
      await container.read(appPreferencesProvider.future);
      repository.stored = const AppPreferences(onboardingCompleted: true);
      await container
          .read(appPreferencesProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(
        repository.stored,
        const AppPreferences(
          themeMode: ThemeMode.dark,
          onboardingCompleted: true,
        ),
      );
    },
  );

  test(
    'failed save retains last committed mode and next edit recovers',
    () async {
      final repository = _MemoryRepository();
      final container = containerFor(repository);
      await container.read(appPreferencesProvider.future);
      repository.failSave = true;
      await expectLater(
        container.read(themeModeProvider.notifier).setMode(ThemeMode.dark),
        throwsA(isA<PreferencesStorageException>()),
      );
      expect(container.read(themeModeProvider), ThemeMode.system);
      repository.failSave = false;
      await container
          .read(appPreferencesProvider.notifier)
          .completeOnboarding();
      expect(
        container.read(appPreferencesProvider).requireValue,
        const AppPreferences(onboardingCompleted: true),
      );
    },
  );

  test('unreadable initial state blocks writes until explicit retry', () async {
    final repository = _MemoryRepository()..failLoad = true;
    final container = containerFor(repository);
    await expectLater(
      container.read(appPreferencesProvider.future),
      throwsA(isA<PreferencesStorageException>()),
    );
    await expectLater(
      container.read(appPreferencesProvider.notifier).completeOnboarding(),
      throwsA(isA<PreferencesStorageException>()),
    );
    expect(repository.writes, 0);
    repository.failLoad = false;
    container.read(appPreferencesProvider.notifier).retry();
    expect(
      await container.read(appPreferencesProvider.future),
      const AppPreferences(),
    );
  });

  test(
    'retry recreates failed factory but reuses repository after load error',
    () async {
      final repository = _MemoryRepository();
      var opens = 0;
      final container = ProviderContainer(
        overrides: [
          appPreferencesRepositoryProvider.overrideWith((ref) async {
            if (++opens == 1) throw const PreferencesStorageException();
            return repository;
          }),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(appPreferencesProvider.future),
        throwsA(isA<PreferencesStorageException>()),
      );
      container.read(appPreferencesProvider.notifier).retry();
      await container.read(appPreferencesProvider.future);
      repository.failLoad = true;
      container.invalidate(appPreferencesProvider);
      await expectLater(
        container.read(appPreferencesProvider.future),
        throwsA(isA<PreferencesStorageException>()),
      );
      repository.failLoad = false;
      container.read(appPreferencesProvider.notifier).retry();
      await container.read(appPreferencesProvider.future);
      expect(opens, 2);
    },
  );

  test(
    'directory failure retry loads disk storage without erasing preferences',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'preferences-provider-',
      );
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          preferencesStorageDirectoryProvider.overrideWith((ref) async {
            if (++attempts == 1) throw const PreferencesStorageException();
            return directory;
          }),
        ],
      );
      AppPreferencesRepository? opened;
      addTearDown(() async {
        container.dispose();
        await opened?.close();
        await directory.delete(recursive: true);
      });
      await expectLater(
        container.read(appPreferencesProvider.future),
        throwsA(isA<PreferencesStorageException>()),
      );
      container.read(appPreferencesProvider.notifier).retry();
      expect(
        await container.read(appPreferencesProvider.future),
        const AppPreferences(),
      );
      opened = await container.read(appPreferencesRepositoryProvider.future);
      expect(attempts, 2);
    },
  );

  test(
    'disposal during directory initialization creates no box files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'preferences-late-init-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final gate = Completer<Directory>();
      final container = ProviderContainer(
        overrides: [
          preferencesStorageDirectoryProvider.overrideWith(
            (ref) => gate.future,
          ),
        ],
      );
      final rejected = expectLater(
        container.read(appPreferencesRepositoryProvider.future),
        throwsA(isA<StateError>()),
      );
      container.dispose();
      gate.complete(directory);
      await rejected;
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test('disposed controller rejects queued and late edits', () async {
    final repository = _MemoryRepository()..loadGate = Completer<void>();
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
      ],
    );
    final controller = container.read(appPreferencesProvider.notifier);
    final queued = expectLater(
      controller.completeOnboarding(),
      throwsStateError,
    );
    container.dispose();
    repository.loadGate!.complete();
    await queued;
    await expectLater(
      controller.setThemeMode(ThemeMode.dark),
      throwsStateError,
    );
    expect(repository.writes, 0);
  });
}
