import 'dart:io';
import 'package:color_lab/features/settings/domain/app_preferences.dart';

import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/application/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fresh provider containers restore completed onboarding and appearance from actual disk',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'color-lab-preferences-restart-',
      );
      final first = ProviderContainer(
        overrides: [
          preferencesStorageDirectoryProvider.overrideWith(
            (ref) async => directory,
          ),
        ],
      );
      var firstDisposed = false;
      try {
        expect(
          (await first.read(appPreferencesProvider.future)).onboardingCompleted,
          isFalse,
        );
        await first.read(appPreferencesProvider.notifier).completeOnboarding();
        await first.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
        await first
            .read(appPreferencesProvider.notifier)
            .setMotion(MotionPreference.reduce);
        await first.read(appPreferencesProvider.notifier).setHighContrast(true);
        await first
            .read(appPreferencesProvider.notifier)
            .setAlwaysShowColorLabels(true);
        final firstRepository = await first.read(
          appPreferencesRepositoryProvider.future,
        );
        await firstRepository.close();
        first.dispose();
        firstDisposed = true;
        final restarted = ProviderContainer(
          overrides: [
            preferencesStorageDirectoryProvider.overrideWith(
              (ref) async => directory,
            ),
          ],
        );
        try {
          final restored = await restarted.read(appPreferencesProvider.future);
          expect(restored.onboardingCompleted, isTrue);
          expect(restored.motion, MotionPreference.reduce);
          expect(restored.highContrast, true);
          expect(restored.alwaysShowColorLabels, true);
          expect(restarted.read(themeModeProvider), ThemeMode.dark);
          await restarted
              .read(themeModeProvider.notifier)
              .setMode(ThemeMode.system);
          final restartedRepository = await restarted.read(
            appPreferencesRepositoryProvider.future,
          );
          await restartedRepository.close();
        } finally {
          restarted.dispose();
        }
        final again = ProviderContainer(
          overrides: [
            preferencesStorageDirectoryProvider.overrideWith(
              (ref) async => directory,
            ),
          ],
        );
        try {
          expect(
            (await again.read(
              appPreferencesProvider.future,
            )).onboardingCompleted,
            isTrue,
          );
          expect(again.read(themeModeProvider), ThemeMode.system);
          await (await again.read(
            appPreferencesRepositoryProvider.future,
          )).close();
        } finally {
          again.dispose();
        }
      } finally {
        if (!firstDisposed) first.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
