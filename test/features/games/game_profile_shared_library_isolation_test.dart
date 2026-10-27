import 'dart:io';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/storage/local_data_manager.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import '../../support/room_project_fixtures.dart';
import 'package:color_lab/features/settings/application/local_data_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'switch, profile deletion and all game deletion preserve every shared library',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'game-isolation-',
      );
      final container = ProviderContainer(
        overrides: [
          gameProfilesDirectoryProvider.overrideWith((ref) async => directory),
        ],
      );
      final colors = await container.read(
        colorHistoryRepositoryProvider.future,
      );
      final palettes = await container.read(
        savedPaletteRepositoryProvider.future,
      );
      final rooms = await container.read(roomDesignRepositoryProvider.future);
      final games = await container.read(gameProfilesRepositoryProvider.future);
      final projects = await container.read(
        roomProjectRepositoryProvider.future,
      );
      try {
        await colors.save(
          color: RgbColor.fromHex('#AABBCC'),
          name: 'Saved',
          source: ColorSource.manual,
        );
        await palettes.save(
          name: 'Shared pair',
          base: RgbColor.fromHex('#AABBCC'),
          mode: HarmonyMode.complementary,
          colors: [RgbColor.fromHex('#AABBCC'), RgbColor.fromHex('#CCBBAA')],
        );
        await rooms.save(
          name: 'Shared illustrated room',
          templateId: 'study',
          colors: IllustratedRoomColors(
            wall: RgbColor.fromHex('#AABBCC'),
            ceiling: RgbColor.fromHex('#EEEEEE'),
            floor: RgbColor.fromHex('#554433'),
            furniture: RgbColor.fromHex('#102030'),
          ),
        );
        final project = await projects.save(
          roomProjectFixture(),
          expectedRevision: 0,
        );
        final before = <LocalDataManifest>[];
        for (final repo in [colors, palettes, rooms, projects]) {
          before.add(
            await (repo as LocalDataOwner).withMaintenance(
              (lease) => lease.inventory(),
            ),
          );
        }
        await container.read(gameProfilesProvider.future);
        final controller = container.read(gameProfilesProvider.notifier);
        final first = await controller.createProfile(name: 'First');
        final second = await controller.createProfile(name: 'Second');
        await controller.setActiveProfile(profileId: second.id);
        await controller.deleteProfile(profileId: first.id);
        final manager = container.read(localDataManagerProvider);
        final preview = await manager.preview({LocalDataCategory.gameProfiles});
        expect(preview.recordCount, greaterThan(0));
        await manager.delete({LocalDataCategory.gameProfiles});
        expect((await games.loadState()).profiles, isEmpty);
        expect((await games.loadState()).legacyMigrationComplete, true);
        container.invalidate(gameProfilesProvider);
        final reloaded = await container.read(gameProfilesProvider.future);
        expect(reloaded.profiles, isEmpty);
        expect(reloaded.activeProfileId, isNull);
        final room = (await projects.read(project.projectId))!.snapshot;
        expect(room.photoId, project.photoId);
        expect(room.photoPng, project.photoPng);
        expect(room.aiMaskBytes, project.aiMaskBytes);
        expect(room.maskBytes, project.maskBytes);
        expect(room.activeVariantId, project.activeVariantId);
        expect(
          room.comparisonBaselineVariantId,
          project.comparisonBaselineVariantId,
        );
        var index = 0;
        for (final repo in [colors, palettes, rooms, projects]) {
          final after = await (repo as LocalDataOwner).withMaintenance(
            (lease) => lease.inventory(),
          );
          expect(after.sameAs(before[index++]), true);
        }
        await projects.delete(project.projectId);
        expect((await projects.listSnapshot()).records, isEmpty);
        index = 0;
        for (final repo in [colors, palettes, rooms]) {
          final after = await (repo as LocalDataOwner).withMaintenance(
            (lease) => lease.inventory(),
          );
          expect(after.sameAs(before[index++]), true);
        }
        expect((await games.loadState()).profiles, isEmpty);
      } finally {
        await colors.close();
        await palettes.close();
        await rooms.close();
        await projects.close();
        await games.close();
        container.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
}
