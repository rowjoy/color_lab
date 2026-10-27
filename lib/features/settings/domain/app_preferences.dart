import 'package:flutter/material.dart';

import 'app_preferences_repository.dart';

enum MotionPreference { system, reduce }

final class AppPreferences {
  const AppPreferences({
    this.themeMode = ThemeMode.system,
    this.onboardingCompleted = false,
    this.motion = MotionPreference.system,
    this.highContrast = false,
    this.alwaysShowColorLabels = false,
  });

  final ThemeMode themeMode;
  final bool onboardingCompleted;
  final MotionPreference motion;
  final bool highContrast;
  final bool alwaysShowColorLabels;

  AppPreferences copyWith({
    ThemeMode? themeMode,
    bool? onboardingCompleted,
    MotionPreference? motion,
    bool? highContrast,
    bool? alwaysShowColorLabels,
  }) => AppPreferences(
    themeMode: themeMode ?? this.themeMode,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    motion: motion ?? this.motion,
    highContrast: highContrast ?? this.highContrast,
    alwaysShowColorLabels: alwaysShowColorLabels ?? this.alwaysShowColorLabels,
  );

  Map<String, dynamic> toMap() => {
    'schemaVersion': 2,
    'themeMode': themeMode.name,
    'onboardingCompleted': onboardingCompleted,
    'motion': motion.name,
    'highContrast': highContrast,
    'alwaysShowColorLabels': alwaysShowColorLabels,
  };

  factory AppPreferences.fromMap(Map<dynamic, dynamic> map) {
    if (map['schemaVersion'] is! int ||
        ![1, 2].contains(map['schemaVersion'])) {
      throw const PreferencesStorageException();
    }
    return AppPreferences(
      motion: map['schemaVersion'] == 2 && map['motion'] == 'reduce'
          ? MotionPreference.reduce
          : MotionPreference.system,
      highContrast: map['schemaVersion'] == 2 && map['highContrast'] == true,
      alwaysShowColorLabels:
          map['schemaVersion'] == 2 && map['alwaysShowColorLabels'] == true,
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
      other.onboardingCompleted == onboardingCompleted &&
      other.motion == motion &&
      other.highContrast == highContrast &&
      other.alwaysShowColorLabels == alwaysShowColorLabels;

  @override
  int get hashCode => Object.hash(
    themeMode,
    onboardingCompleted,
    motion,
    highContrast,
    alwaysShowColorLabels,
  );
}
