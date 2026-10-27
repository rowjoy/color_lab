import 'dart:io';
import 'dart:async';
import 'package:color_lab/data/db/hive_game_profiles_repository.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';
import 'package:color_lab/data/db/hive_color_history_repository.dart';
import 'package:color_lab/data/db/hive_palette_repository.dart';
import 'package:color_lab/data/storage/local_data_manager.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late HiveColorHistoryRepository colors;
  late HivePaletteRepository palettes;
  late LocalDataManager manager;
  const selected = {LocalDataCategory.savedColors};
  setUp(() async {
    root = await Directory.systemTemp.createTemp('data-controls-');
    colors = await HiveColorHistoryRepository.open(directory: root.path);
    palettes = await HivePaletteRepository.open(directory: root.path);
    manager = ExactLocalDataManager(
      owners: {
        LocalDataCategory.savedColors: () async => colors,
        LocalDataCategory.savedPalettes: () async => palettes,
      },
    );
    await colors.save(
      color: RgbColor.fromHex('#FF0000'),
      name: 'Red',
      source: ColorSource.manual,
    );
  });
  tearDown(() async {
    await colors.close();
    await palettes.close();
    await root.delete(recursive: true);
  });
  test('missing preview and unsupported categories fail closed', () async {
    await expectLater(
      manager.delete(selected),
      throwsA(isA<LocalDataException>()),
    );
    await expectLater(
      manager.preview({LocalDataCategory.roomProjects}),
      throwsA(isA<LocalDataException>()),
    );
    expect(await colors.load(), hasLength(1));
  });
  test(
    'exact immutable preview deletes only selected records and preserves exports',
    () async {
      final export = File('${root.path}/my-export.png');
      await export.writeAsString('mine');
      final preview = await manager.preview(selected);
      expect(preview.recordCount, 1);
      expect(preview.estimatedBytes, greaterThan(0));
      expect(() => preview.categories.clear(), throwsUnsupportedError);
      await manager.delete(selected);
      expect(await colors.load(), isEmpty);
      expect(await export.readAsString(), 'mine');
      await expectLater(
        manager.delete(selected),
        throwsA(isA<LocalDataException>()),
      );
    },
  );
  test('selection mismatch consumes authorization without writing', () async {
    await manager.preview(selected);
    await expectLater(
      manager.delete({LocalDataCategory.savedPalettes}),
      throwsA(isA<LocalDataException>()),
    );
    await expectLater(
      manager.delete(selected),
      throwsA(isA<LocalDataException>()),
    );
    expect(await colors.load(), hasLength(1));
  });
  test('changed content invalidates preview before any deletion', () async {
    await manager.preview({
      LocalDataCategory.savedColors,
      LocalDataCategory.savedPalettes,
    });
    await colors.setFavorite('#FF0000', true);
    await expectLater(
      manager.delete({
        LocalDataCategory.savedColors,
        LocalDataCategory.savedPalettes,
      }),
      throwsA(isA<LocalDataException>()),
    );
    expect((await colors.load()).single.isFavorite, true);
  });

  test(
    'all game deletion includes legacy records and preserves shared data',
    () async {
      final hive = HiveImpl();
      final Box<dynamic> profiles = await hive.openBox(
        'game_profiles_v2',
        path: root.path,
      );
      final Box<dynamic> legacy = await hive.openBox(
        'game_progress_v1',
        path: root.path,
      );
      await profiles.put('state', {'schemaVersion': 999});
      await legacy.put('progress', {'legacy': 'private game data'});
      final games = HiveGameProfilesRepository.fromBoxes(
        profilesBox: profiles,
        legacyBox: legacy,
      );
      final data = ExactLocalDataManager(
        owners: {LocalDataCategory.gameProfiles: () async => games},
      );
      final preview = await data.preview({LocalDataCategory.gameProfiles});
      expect(preview.recordCount, 2);
      await data.delete({LocalDataCategory.gameProfiles});
      expect(profiles.keys, isEmpty);
      expect(legacy.keys, isEmpty);
      expect(await colors.load(), hasLength(1));
      await games.close();
    },
  );

  test(
    'repository maintenance excludes ordinary writes until release',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      final held = colors.withMaintenance((lease) async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      var finished = false;
      final write = colors
          .setFavorite('#FF0000', true)
          .then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, false);
      release.complete();
      await held;
      await write;
      expect((await colors.load()).single.isFavorite, true);
    },
  );

  test('simultaneous delete calls consume one authorization only', () async {
    await manager.preview(selected);
    final first = manager.delete(selected);
    final second = expectLater(
      manager.delete(selected),
      throwsA(isA<LocalDataException>()),
    );
    await first;
    await second;
    expect(await colors.load(), isEmpty);
  });
}
