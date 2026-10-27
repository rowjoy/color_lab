import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/storage/local_data_manager.dart';
import '../../history/application/history_providers.dart';
import '../../palette/application/saved_palettes_providers.dart';
import '../../room_studio/application/room_designs_providers.dart';
import '../../room_studio/application/room_model_download_providers.dart';
import '../../room_studio/application/room_projects_providers.dart';
import '../../games/application/game_profiles_provider.dart';
import 'app_preferences_providers.dart';

final localDataManagerProvider = Provider<LocalDataManager>((ref) {
  Future<LocalDataOwner> owner(Future<Object> future) async {
    final value = await future;
    if (value is! LocalDataOwner) throw const LocalDataException();
    return value;
  }

  return ExactLocalDataManager(
    owners: {
      LocalDataCategory.preferences: () =>
          owner(ref.read(appPreferencesRepositoryProvider.future)),
      LocalDataCategory.savedColors: () =>
          owner(ref.read(colorHistoryRepositoryProvider.future)),
      LocalDataCategory.savedPalettes: () =>
          owner(ref.read(savedPaletteRepositoryProvider.future)),
      LocalDataCategory.illustratedRooms: () =>
          owner(ref.read(roomDesignRepositoryProvider.future)),
      LocalDataCategory.roomProjects: () =>
          owner(ref.read(roomProjectRepositoryProvider.future)),
      LocalDataCategory.gameProfiles: () =>
          owner(ref.read(gameProfilesRepositoryProvider.future)),
      LocalDataCategory.modelCache: () async =>
          ref.read(roomModelStoreProvider),
    },
  );
});

/// Refresh values only; active repositories retain ownership of their handles.
void refreshDeletedData(WidgetRef ref, Set<LocalDataCategory> categories) {
  for (final category in categories) {
    switch (category) {
      case LocalDataCategory.savedColors:
        ref.invalidate(colorHistoryProvider);
      case LocalDataCategory.savedPalettes:
        ref.invalidate(savedPalettesProvider);
      case LocalDataCategory.illustratedRooms:
        ref.invalidate(savedRoomDesignsProvider);
      case LocalDataCategory.roomProjects:
        ref.invalidate(roomProjectsProvider);
      case LocalDataCategory.gameProfiles:
        ref.invalidate(gameProfilesProvider);
      case LocalDataCategory.preferences:
        ref.invalidate(appPreferencesProvider);
      default:
        break;
    }
  }
}
