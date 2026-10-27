import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/hive_app_preferences_repository.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../domain/app_preferences.dart';
import '../domain/app_preferences_repository.dart';

final preferencesStorageDirectoryProvider = appStorageDirectoryProvider;

final appPreferencesRepositoryProvider =
    FutureProvider<AppPreferencesRepository>((ref) async {
      final storage = await ref.watch(appStorageDirectoryProvider.future);
      if (!ref.mounted) {
        throw StateError('Preferences were disposed during initialization.');
      }
      final directory = resolveAppStorageDirectory(storage);
      final repository = await HiveAppPreferencesRepository.open(
        directory: directory.path,
      );
      if (!ref.mounted) {
        await repository.close();
        throw StateError('Preferences were disposed during initialization.');
      }
      ref.onDispose(() {
        unawaited(
          repository.close().catchError((Object error, StackTrace stack) {
            debugPrint('Preferences could not be closed cleanly.');
          }),
        );
      });
      return repository;
    }, retry: (retryCount, error) => null);

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
      retry: (retryCount, error) => null,
    );

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  Future<void> _pending = Future<void>.value();

  @override
  Future<AppPreferences> build() async {
    final repository = await ref.watch(appPreferencesRepositoryProvider.future);
    if (!ref.mounted) {
      throw StateError('Preferences are no longer available.');
    }
    return repository.load();
  }

  Future<void> _mutate(AppPreferences Function(AppPreferences) edit) {
    if (!ref.mounted) {
      return Future<void>.error(
        StateError('Preferences are no longer available.'),
      );
    }
    final result = Completer<void>();
    _pending = _pending.then((_) async {
      try {
        if (!ref.mounted) {
          throw StateError('Preferences are no longer available.');
        }
        // Wait for startup validation, then read storage again for every edit.
        await future;
        if (!ref.mounted) {
          throw StateError('Preferences are no longer available.');
        }
        final repository = await ref.read(
          appPreferencesRepositoryProvider.future,
        );
        final current = await repository.load();
        if (!ref.mounted) {
          throw StateError('Preferences are no longer available.');
        }
        final updated = edit(current);
        await repository.save(updated);
        if (!ref.mounted) {
          throw StateError('Preferences are no longer available.');
        }
        state = AsyncData(updated);
        result.complete();
      } catch (error, stack) {
        // A caller may show its own retry UI while the committed state remains.
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _mutate((current) => current.copyWith(themeMode: mode));

  Future<void> completeOnboarding() =>
      _mutate((current) => current.copyWith(onboardingCompleted: true));

  void retry() {
    if (!ref.mounted) return;
    if (ref.read(preferencesStorageDirectoryProvider).hasError) {
      ref.invalidate(preferencesStorageDirectoryProvider);
    }
    if (ref.read(appPreferencesRepositoryProvider).hasError) {
      ref.invalidate(appPreferencesRepositoryProvider);
    }
    ref.invalidateSelf();
  }
}
