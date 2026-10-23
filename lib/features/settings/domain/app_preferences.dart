import 'package:flutter/material.dart';

import 'app_preferences_repository.dart';

final class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.onboardingCompleted = false,
  });

  final ThemeMode themeMode;
  final bool onboardingCompleted;

  AppPreferences copyWith({ThemeMode? themeMode, bool? onboardingCompleted}) =>
      AppPreferences(
        themeMode: themeMode ?? this.themeMode,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );

  Map<String, dynamic> toMap() => {
    'schemaVersion': 1,
    'themeMode': themeMode.name,
    'onboardingCompleted': onboardingCompleted,
  };

  factory AppPreferences.fromMap(Map<dynamic, dynamic> map) {
    if (map['schemaVersion'] is! int || map['schemaVersion'] != 1) {
      throw const PreferencesStorageException();
    }
    return AppPreferences(
      themeMode: switch (map['themeMode']) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      },
      onboardingCompleted: map['onboardingCompleted'] is bool
          ? map['onboardingCompleted'] as bool
          : false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppPreferences &&
      other.themeMode == themeMode &&
      other.onboardingCompleted == onboardingCompleted;

  @override
  int get hashCode => Object.hash(themeMode, onboardingCompleted);
}
