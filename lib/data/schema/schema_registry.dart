enum LocalDataScope { sharedLibrary, gameProfile, cache, userExport }

enum StorageBackend { hiveBox, fileTree, appPrivateCache }

enum LocalDataCategory {
  preferences,
  savedColors,
  savedPalettes,
  illustratedRooms,
  roomProjects,
  coloringProjects,
  learningProgress,
  gameProfiles,
  modelCache,
}

final class SchemaDescriptor {
  const SchemaDescriptor({
    required this.id,
    required this.storageName,
    required this.backend,
    required this.currentVersion,
    required this.scope,
  }) : assert(id != ''),
       assert(storageName != ''),
       assert(currentVersion > 0);

  final String id;
  final String storageName;
  final StorageBackend backend;
  final int currentVersion;
  final LocalDataScope scope;
}

abstract final class SchemaRegistry {
  static const appPreferences = SchemaDescriptor(
    id: 'app-preferences',
    storageName: 'app_preferences_v1',
    backend: StorageBackend.hiveBox,
    currentVersion: 2,
    scope: LocalDataScope.sharedLibrary,
  );
  static const savedColors = SchemaDescriptor(
    id: 'saved-colors',
    storageName: 'color_history_v1',
    backend: StorageBackend.hiveBox,
    currentVersion: 1,
    scope: LocalDataScope.sharedLibrary,
  );
  static const savedPalettes = SchemaDescriptor(
    id: 'saved-palettes',
    storageName: 'color_palettes_v1',
    backend: StorageBackend.hiveBox,
    currentVersion: 1,
    scope: LocalDataScope.sharedLibrary,
  );
  static const illustratedRooms = SchemaDescriptor(
    id: 'illustrated-rooms',
    storageName: 'illustrated_room_designs_v1',
    backend: StorageBackend.hiveBox,
    currentVersion: 2,
    scope: LocalDataScope.sharedLibrary,
  );
  static const photoAcquisition = SchemaDescriptor(
    id: 'photo-acquisition',
    storageName: 'photo_acquisition_v1',
    backend: StorageBackend.hiveBox,
    currentVersion: 1,
    scope: LocalDataScope.cache,
  );
  static const gameProfiles = SchemaDescriptor(
    id: 'game-profiles',
    storageName: 'game_profiles_v2',
    backend: StorageBackend.hiveBox,
    currentVersion: 2,
    scope: LocalDataScope.gameProfile,
  );
  static const legacyGameProgress = SchemaDescriptor(
    id: 'legacy-game-progress',
    storageName: 'game_progress_v1',
    backend: StorageBackend.hiveBox,
    currentVersion: 1,
    scope: LocalDataScope.gameProfile,
  );
  static const roomProjects = SchemaDescriptor(
    id: 'room-projects',
    storageName: 'room_projects',
    backend: StorageBackend.fileTree,
    currentVersion: 2,
    scope: LocalDataScope.sharedLibrary,
  );
  static const roomModelCache = SchemaDescriptor(
    id: 'room-model-cache',
    storageName: 'room_models',
    backend: StorageBackend.appPrivateCache,
    currentVersion: 1,
    scope: LocalDataScope.cache,
  );
  static const learningLibrary = SchemaDescriptor(
    id: 'learning-library',
    storageName: 'learning_library_v1',
    backend: StorageBackend.hiveBox,
    currentVersion: 1,
    scope: LocalDataScope.sharedLibrary,
  );
  static const coloringProjects = SchemaDescriptor(
    id: 'coloring-projects',
    storageName: 'coloring_projects_v1',
    backend: StorageBackend.hiveBox,
    currentVersion: 1,
    scope: LocalDataScope.sharedLibrary,
  );

  static const List<SchemaDescriptor> all = [
    appPreferences,
    savedColors,
    savedPalettes,
    illustratedRooms,
    photoAcquisition,
    gameProfiles,
    legacyGameProgress,
    roomProjects,
    roomModelCache,
    learningLibrary,
    coloringProjects,
  ];

  static const Map<LocalDataCategory, LocalDataScope> categoryScopes = {
    LocalDataCategory.preferences: LocalDataScope.sharedLibrary,
    LocalDataCategory.savedColors: LocalDataScope.sharedLibrary,
    LocalDataCategory.savedPalettes: LocalDataScope.sharedLibrary,
    LocalDataCategory.illustratedRooms: LocalDataScope.sharedLibrary,
    LocalDataCategory.roomProjects: LocalDataScope.sharedLibrary,
    LocalDataCategory.coloringProjects: LocalDataScope.sharedLibrary,
    LocalDataCategory.learningProgress: LocalDataScope.sharedLibrary,
    LocalDataCategory.gameProfiles: LocalDataScope.gameProfile,
    LocalDataCategory.modelCache: LocalDataScope.cache,
  };
}
