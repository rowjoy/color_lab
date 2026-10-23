import 'dart:async';

import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/features/settings/domain/app_preferences_repository.dart';

/// Only replaces the disk boundary. Application/controller/router stay real.
class InMemoryAppPreferencesRepository implements AppPreferencesRepository {
  InMemoryAppPreferencesRepository({AppPreferences? initial})
    : value = initial ?? const AppPreferences(onboardingCompleted: true);

  AppPreferences value;
  bool failLoad = false, failSave = false;
  int saves = 0;
  Completer<void>? loadGate, saveGate;

  @override
  Future<AppPreferences> load() async {
    await loadGate?.future;
    if (failLoad) throw StateError('private preferences load failure');
    return value;
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    await saveGate?.future;
    if (failSave) throw StateError('private preferences write failure');
    value = preferences;
    saves++;
  }

  @override
  Future<void> close() async {}
}
