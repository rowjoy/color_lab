import 'dart:async';
import 'dart:io';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_design_repository.dart';

void main() {
  final focusSage = IllustratedRoomColors(
    wall: RgbColor.fromHex('#A7B5A0'),
    ceiling: RgbColor.fromHex('#F7F2E8'),
    floor: RgbColor.fromHex('#C9A77B'),
    furniture: RgbColor.fromHex('#5B4636'),
  );
  final coolFocus = IllustratedRoomColors(
    wall: RgbColor.fromHex('#A9BBC8'),
    ceiling: RgbColor.fromHex('#F3F6F7'),
    floor: RgbColor.fromHex('#B99370'),
    furniture: RgbColor.fromHex('#34495E'),
  );
  final first = SavedRoomDesign(
    id: 'study-first',
    name: 'First',
    templateId: 'study',
    colors: focusSage,
    createdAt: DateTime.utc(2026, 10, 20),
    updatedAt: DateTime.utc(2026, 10, 20),
  );
  final second = SavedRoomDesign(
    id: 'study-second',
    name: 'Second',
    templateId: 'study',
    colors: coolFocus,
    createdAt: DateTime.utc(2026, 10, 21),
    updatedAt: DateTime.utc(2026, 10, 21),
  );
  final error = throwsA(isA<RoomDesignStorageException>());

  ProviderContainer containerFor(InMemoryRoomDesignRepository repository) {
    final container = ProviderContainer(
      overrides: [
        roomDesignRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<SavedRoomDesign> save(
    SavedRoomDesignsController controller, {
    String name = 'New study',
    IllustratedRoomColors? colors,
  }) => controller.saveDesign(
    name: name,
    templateId: 'study',
    colors: colors ?? focusSage,
  );

  test('loads immutable newest-first design snapshots', () async {
    final container = containerFor(
      InMemoryRoomDesignRepository(
        designs: [first, second],
        clock: () => DateTime.utc(2026, 10, 27),
      ),
    );

    final designs = await container.read(savedRoomDesignsProvider.future);

    expect(designs, [second, first]);
    expect(() => designs.clear(), throwsUnsupportedError);
  });

  test('serializes edits and publishes only after durable success', () async {
    final repository = InMemoryRoomDesignRepository(
      clock: () => DateTime.utc(2026, 10, 27),
    )..writeGate = Completer<void>();
    final container = containerFor(repository);
    await container.read(savedRoomDesignsProvider.future);
    final controller = container.read(savedRoomDesignsProvider.notifier);

    final firstSave = save(controller, name: 'Original');
    final secondSave = save(controller, name: 'Cool room', colors: coolFocus);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(savedRoomDesignsProvider).requireValue, isEmpty);

    repository.writeGate!.complete();
    final saved = await Future.wait([firstSave, secondSave]);

    expect(repository.maxConcurrentWrites, 1);
    expect(container.read(savedRoomDesignsProvider).requireValue, saved);
  });

  test('failed save and delete preserve the last committed list', () async {
    final repository = InMemoryRoomDesignRepository(
      designs: [first],
      clock: () => DateTime.utc(2026, 10, 27),
    )..failWrites = true;
    final container = containerFor(repository);
    await container.read(savedRoomDesignsProvider.future);
    final controller = container.read(savedRoomDesignsProvider.notifier);

    await expectLater(save(controller), error);
    await expectLater(controller.deleteDesign(first.id), error);
    expect(container.read(savedRoomDesignsProvider).requireValue, [first]);

    repository.failWrites = false;
    await controller.deleteDesign(first.id);
    expect(container.read(savedRoomDesignsProvider).requireValue, isEmpty);
  });

  test('rename preserves the target template and exact colors', () async {
    final repository = InMemoryRoomDesignRepository(
      designs: [first, second],
      clock: () => DateTime.utc(2026, 10, 27),
    );
    final container = containerFor(repository);
    await container.read(savedRoomDesignsProvider.future);
    final controller = container.read(savedRoomDesignsProvider.notifier);

    final renamed = await controller.renameDesign(first.id, '  Renamed  ');

    expect(renamed.id, first.id);
    expect(renamed.name, 'Renamed');
    expect(renamed.templateId, first.templateId);
    expect(renamed.colors, first.colors);
    expect(
      container
          .read(savedRoomDesignsProvider)
          .requireValue
          .singleWhere((design) => design.id == first.id),
      renamed,
    );
  });

  test('initial load failure blocks edits until retry', () async {
    final repository = InMemoryRoomDesignRepository(
      designs: [first],
      clock: () => DateTime.utc(2026, 10, 27),
    )..failLoad = true;
    var opens = 0;
    final container = ProviderContainer(
      overrides: [
        roomDesignRepositoryProvider.overrideWith((ref) async {
          opens++;
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(container.read(savedRoomDesignsProvider.future), error);
    repository.failLoad = false;
    final controller = container.read(savedRoomDesignsProvider.notifier);
    await expectLater(controller.deleteDesign(first.id), error);
    expect(await repository.load(), [first]);

    controller.retry();
    expect(await container.read(savedRoomDesignsProvider.future), [first]);
    expect(opens, 1);
  });

  test('retry recreates only a failed repository factory', () async {
    final repository = InMemoryRoomDesignRepository(
      designs: [first],
      clock: () => DateTime.utc(2026, 10, 27),
    );
    var failFactory = true;
    var opens = 0;
    final container = ProviderContainer(
      overrides: [
        roomDesignRepositoryProvider.overrideWith((ref) async {
          opens++;
          if (failFactory) throw const RoomDesignStorageException();
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(container.read(savedRoomDesignsProvider.future), error);
    failFactory = false;
    container.read(savedRoomDesignsProvider.notifier).retry();
    expect(await container.read(savedRoomDesignsProvider.future), [first]);

    repository.failLoad = true;
    container.invalidate(savedRoomDesignsProvider);
    await expectLater(container.read(savedRoomDesignsProvider.future), error);
    repository.failLoad = false;
    container.read(savedRoomDesignsProvider.notifier).retry();
    expect(await container.read(savedRoomDesignsProvider.future), [first]);
    expect(opens, 2);
  });

  test('fresh containers reload complete snapshots from Hive', () async {
    final directory = await Directory.systemTemp.createTemp(
      'room-design-container-restart-',
    );
    ProviderContainer open() => ProviderContainer(
      overrides: [
        roomDesignStorageDirectoryProvider.overrideWith(
          (ref) async => directory,
        ),
      ],
    );
    var container = open();
    try {
      await container.read(savedRoomDesignsProvider.future);
      final saved = await container
          .read(savedRoomDesignsProvider.notifier)
          .saveDesign(
            name: '  Persisted study  ',
            templateId: 'study',
            colors: coolFocus,
          );
      await (await container.read(roomDesignRepositoryProvider.future)).close();
      container.dispose();

      container = open();
      final loaded = await container.read(savedRoomDesignsProvider.future);
      expect(loaded, [saved]);
      expect(loaded.single.name, 'Persisted study');
      expect(loaded.single.colors, coolFocus);
      await container
          .read(savedRoomDesignsProvider.notifier)
          .deleteDesign(saved.id);
      await (await container.read(roomDesignRepositoryProvider.future)).close();
      container.dispose();

      container = open();
      expect(await container.read(savedRoomDesignsProvider.future), isEmpty);
      await (await container.read(roomDesignRepositoryProvider.future)).close();
    } finally {
      container.dispose();
      await directory.delete(recursive: true);
    }
  });
}
