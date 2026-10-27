import 'package:color_lab/data/schema/schema_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('descriptor IDs and backend storage identities are unique', () {
    final descriptors = SchemaRegistry.all;

    expect(
      descriptors.map((descriptor) => descriptor.id).toSet(),
      hasLength(descriptors.length),
    );
    expect(
      descriptors
          .map((descriptor) => (descriptor.backend, descriptor.storageName))
          .toSet(),
      hasLength(descriptors.length),
    );
  });

  test('descriptor identities pin storage backend version and ownership', () {
    expect(
      {
        for (final descriptor in SchemaRegistry.all)
          descriptor.id: (
            descriptor.storageName,
            descriptor.backend,
            descriptor.currentVersion,
            descriptor.scope,
          ),
      },
      {
        'app-preferences': (
          'app_preferences_v1',
          StorageBackend.hiveBox,
          2,
          LocalDataScope.sharedLibrary,
        ),
        'saved-colors': (
          'color_history_v1',
          StorageBackend.hiveBox,
          1,
          LocalDataScope.sharedLibrary,
        ),
        'saved-palettes': (
          'color_palettes_v1',
          StorageBackend.hiveBox,
          1,
          LocalDataScope.sharedLibrary,
        ),
        'illustrated-rooms': (
          'illustrated_room_designs_v1',
          StorageBackend.hiveBox,
          1,
          LocalDataScope.sharedLibrary,
        ),
        'photo-acquisition': (
          'photo_acquisition_v1',
          StorageBackend.hiveBox,
          1,
          LocalDataScope.cache,
        ),
        'game-profiles': (
          'game_profiles_v2',
          StorageBackend.hiveBox,
          2,
          LocalDataScope.gameProfile,
        ),
        'legacy-game-progress': (
          'game_progress_v1',
          StorageBackend.hiveBox,
          1,
          LocalDataScope.gameProfile,
        ),
        'room-projects': (
          'room_projects',
          StorageBackend.fileTree,
          1,
          LocalDataScope.sharedLibrary,
        ),
        'room-model-cache': (
          'room_models',
          StorageBackend.appPrivateCache,
          1,
          LocalDataScope.cache,
        ),
      },
    );
  });

  test('existing Hive boxes retain their exact names and versions', () {
    final hive = {
      for (final descriptor in SchemaRegistry.all)
        if (descriptor.backend == StorageBackend.hiveBox)
          descriptor.storageName: descriptor,
    };

    expect(hive.keys, {
      'app_preferences_v1',
      'color_history_v1',
      'color_palettes_v1',
      'illustrated_room_designs_v1',
      'photo_acquisition_v1',
      'game_profiles_v2',
      'game_progress_v1',
    });
    expect(hive['app_preferences_v1']!.currentVersion, 2);
    expect(hive['color_history_v1']!.currentVersion, 1);
    expect(hive['color_palettes_v1']!.currentVersion, 1);
    expect(hive['illustrated_room_designs_v1']!.currentVersion, 1);
    expect(hive['photo_acquisition_v1']!.currentVersion, 1);
    expect(hive['game_profiles_v2']!.currentVersion, 2);
    expect(hive['game_progress_v1']!.currentVersion, 1);
  });

  test('file and cache storage are never mislabeled as Hive boxes', () {
    final roomProjects = SchemaRegistry.all.singleWhere(
      (descriptor) => descriptor.id == 'room-projects',
    );
    final modelCache = SchemaRegistry.all.singleWhere(
      (descriptor) => descriptor.id == 'room-model-cache',
    );

    expect(roomProjects.storageName, 'room_projects');
    expect(roomProjects.backend, StorageBackend.fileTree);
    expect(roomProjects.currentVersion, 1);
    expect(roomProjects.scope, LocalDataScope.sharedLibrary);
    expect(modelCache.storageName, 'room_models');
    expect(modelCache.backend, StorageBackend.appPrivateCache);
    expect(modelCache.currentVersion, 1);
    expect(modelCache.scope, LocalDataScope.cache);
    expect(
      SchemaRegistry.all
          .where((descriptor) => descriptor.backend != StorageBackend.hiveBox)
          .map((descriptor) => descriptor.storageName),
      isNot(
        containsAll(<String>{
          'app_preferences_v1',
          'color_history_v1',
          'color_palettes_v1',
          'illustrated_room_designs_v1',
          'photo_acquisition_v1',
          'game_profiles_v2',
          'game_progress_v1',
        }),
      ),
    );
  });

  test('shared records never use game-profile ownership', () {
    const sharedIds = {
      'app-preferences',
      'saved-colors',
      'saved-palettes',
      'illustrated-rooms',
    };
    final shared = SchemaRegistry.all.where(
      (descriptor) => sharedIds.contains(descriptor.id),
    );

    expect(shared, hasLength(sharedIds.length));
    expect(
      shared.map((descriptor) => descriptor.scope),
      everyElement(LocalDataScope.sharedLibrary),
    );
    expect(
      SchemaRegistry.all
          .where((descriptor) => descriptor.scope == LocalDataScope.gameProfile)
          .map((descriptor) => descriptor.id)
          .toSet(),
      {'game-profiles', 'legacy-game-progress'},
    );
  });

  test('local deletion categories are stable and exhaustive', () {
    expect(LocalDataCategory.values, [
      LocalDataCategory.preferences,
      LocalDataCategory.savedColors,
      LocalDataCategory.savedPalettes,
      LocalDataCategory.illustratedRooms,
      LocalDataCategory.roomProjects,
      LocalDataCategory.coloringProjects,
      LocalDataCategory.learningProgress,
      LocalDataCategory.gameProfiles,
      LocalDataCategory.modelCache,
    ]);
    expect(
      SchemaRegistry.categoryScopes.keys.toSet(),
      LocalDataCategory.values.toSet(),
    );
    expect(
      SchemaRegistry.categoryScopes.entries
          .where((entry) => entry.value == LocalDataScope.gameProfile)
          .map((entry) => entry.key),
      [LocalDataCategory.gameProfiles],
    );
    expect(
      SchemaRegistry.categoryScopes[LocalDataCategory.modelCache],
      LocalDataScope.cache,
    );
    expect(
      SchemaRegistry.categoryScopes.entries
          .where(
            (entry) =>
                entry.key != LocalDataCategory.gameProfiles &&
                entry.key != LocalDataCategory.modelCache,
          )
          .map((entry) => entry.value),
      everyElement(LocalDataScope.sharedLibrary),
    );
  });
}
