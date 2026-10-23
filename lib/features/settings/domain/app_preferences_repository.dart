import 'app_preferences.dart';

abstract interface class AppPreferencesRepository {
  Future<AppPreferences> load();
  Future<void> save(AppPreferences preferences);
  Future<void> close();
}

/// Safe storage failure with no underlying paths or implementation details.
final class PreferencesStorageException implements Exception {
  const PreferencesStorageException();
}
