import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/features/settings/domain/app_preferences_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty preferences use safe first launch defaults', () {
    const preferences = AppPreferences();
    expect(preferences.themeMode, ThemeMode.system);
    expect(preferences.onboardingCompleted, false);
    expect(preferences.toMap(), {
      'schemaVersion': 2,
      'themeMode': 'system',
      'onboardingCompleted': false,
      'motion': 'system',
      'highContrast': false,
      'alwaysShowColorLabels': false,
    });
  });

  test('version one round trips both fields and copy preserves others', () {
    const preferences = AppPreferences(themeMode: ThemeMode.dark);
    final completed = preferences.copyWith(onboardingCompleted: true);
    expect(completed.themeMode, ThemeMode.dark);
    expect(completed.onboardingCompleted, true);
    expect(
      completed,
      AppPreferences.fromMap({
        'schemaVersion': 1,
        'themeMode': 'dark',
        'onboardingCompleted': true,
      }),
    );
    expect(
      completed.hashCode,
      AppPreferences.fromMap(completed.toMap()).hashCode,
    );
    expect(preferences.onboardingCompleted, false);
    expect(
      completed.copyWith(themeMode: ThemeMode.light).toMap()['themeMode'],
      'light',
    );
  });

  test(
    'unknown themes and malformed completion independently default safely',
    () {
      for (final theme in ['sepia', 5, null]) {
        final preferences = AppPreferences.fromMap({
          'schemaVersion': 1,
          'themeMode': theme,
          'onboardingCompleted': true,
        });
        expect(preferences.themeMode, ThemeMode.system);
        expect(preferences.onboardingCompleted, true);
      }
      expect(
        AppPreferences.fromMap({
          'schemaVersion': 1,
          'themeMode': 'dark',
          'onboardingCompleted': 'true',
        }),
        const AppPreferences(themeMode: ThemeMode.dark),
      );
    },
  );

  test('missing and unsupported schema versions report safe storage error', () {
    for (final version in [null, 0, 3, '1']) {
      expect(
        () => AppPreferences.fromMap({'schemaVersion': version}),
        throwsA(isA<PreferencesStorageException>()),
      );
    }
  });

  test(
    'v1 defaults and v2 accessibility fields survive copy and round trip',
    () {
      final old = AppPreferences.fromMap({'schemaVersion': 1});
      expect(old.motion, MotionPreference.system);
      expect(old.highContrast, false);
      expect(old.alwaysShowColorLabels, false);
      final updated = old.copyWith(
        motion: MotionPreference.reduce,
        highContrast: true,
        alwaysShowColorLabels: true,
      );
      expect(AppPreferences.fromMap(updated.toMap()), updated);
      expect(
        updated.copyWith(themeMode: ThemeMode.dark).motion,
        MotionPreference.reduce,
      );
    },
  );
}
