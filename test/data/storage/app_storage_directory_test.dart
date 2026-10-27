import 'dart:io';

import 'package:color_lab/data/storage/app_storage_directory.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolves the preserved private color_lab child exactly once', () {
    final documents = Directory.fromUri(
      Uri.directory('${Directory.systemTemp.path}/documents'),
    );

    final resolved = resolveAppStorageDirectory(documents);
    final resolvedAgain = resolveAppStorageDirectory(resolved);

    expect(
      resolved.uri.pathSegments.where((part) => part.isNotEmpty).last,
      legacyPrivateDataDirectoryName,
    );
    expect(resolved.path, endsWith('${Platform.pathSeparator}color_lab'));
    expect(resolvedAgain.path, resolved.path);
  });

  test('product branding never renames the private compatibility path', () {
    final brandedRoot = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}TintAtlas',
    );
    expect(legacyPrivateDataDirectoryName, 'color_lab');
    expect(legacyPrivateDataDirectoryName, isNot(contains('TintAtlas')));
    expect(
      resolveAppStorageDirectory(brandedRoot).path,
      '${brandedRoot.path}${Platform.pathSeparator}color_lab',
    );
    final similarSuffix = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}final-color_lab',
    );
    expect(
      resolveAppStorageDirectory(similarSuffix).path,
      '${similarSuffix.path}${Platform.pathSeparator}color_lab',
    );
  });

  test('feature directory providers remain forwarding override aliases', () {
    expect([
      historyStorageDirectoryProvider,
      paletteStorageDirectoryProvider,
      roomDesignStorageDirectoryProvider,
      preferencesStorageDirectoryProvider,
      gameProfilesDirectoryProvider,
      acquisitionStorageDirectoryProvider,
    ], everyElement(same(appStorageDirectoryProvider)));
  });
}
