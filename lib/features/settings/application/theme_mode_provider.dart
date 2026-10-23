import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_preferences_providers.dart';

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() =>
      ref.watch(appPreferencesProvider).asData?.value.themeMode ??
      ThemeMode.system;

  Future<void> setMode(ThemeMode mode) =>
      ref.read(appPreferencesProvider.notifier).setThemeMode(mode);
}
