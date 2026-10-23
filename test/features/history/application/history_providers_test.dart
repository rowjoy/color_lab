import 'dart:async';
import 'dart:io';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/history/domain/color_history_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_color_history_repository.dart';

void main() {
  final red = SavedColor(
    id: '#FF0000',
    hex: '#FF0000',
    name: 'Scarlet',
    isFavorite: true,
    createdAt: DateTime.utc(2026, 10, 20),
    source: ColorSource.manual,
  );
  final blue = SavedColor(
    id: '#0000FF',
    hex: '#0000FF',
    name: 'Ocean blue',
    isFavorite: false,
    createdAt: DateTime.utc(2026, 10, 21),
    source: ColorSource.studio,
  );

  ProviderContainer containerFor(InMemoryColorHistoryRepository repository) {
    final container = ProviderContainer(
      overrides: [
        colorHistoryRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('loads and publishes immutable newest-first history', () async {
    final container = containerFor(
      InMemoryColorHistoryRepository(colors: [red, blue]),
    );
    final colors = await container.read(colorHistoryProvider.future);
    expect(colors.map((c) => c.name), ['Ocean blue', 'Scarlet']);
    expect(() => colors.clear(), throwsUnsupportedError);
  });

  test('serializes save and favorite and retains duplicate metadata', () async {
    final repository = InMemoryColorHistoryRepository()
      ..writeGate = Completer<void>();
    final container = containerFor(repository);
    await container.read(colorHistoryProvider.future);
    final controller = container.read(colorHistoryProvider.notifier);
    final save = controller.saveColor(
      RgbColor(255, 0, 0),
      name: 'Red',
      source: ColorSource.lab,
    );
    final favorite = controller.setFavorite('#FF0000', true);
    repository.writeGate!.complete();
    final saved = await save;
    await favorite;
    final duplicate = await controller.saveColor(
      RgbColor(255, 0, 0),
      name: 'Other name',
      source: ColorSource.room,
    );
    final colors = container.read(colorHistoryProvider).requireValue;
    expect(repository.maxConcurrentWrites, 1);
    expect(colors, hasLength(1));
    expect(colors.single.isFavorite, isTrue);
    expect(duplicate.createdAt, saved.createdAt);
    expect(duplicate.name, 'Red');
    expect(duplicate.source, ColorSource.lab);
  });

  test(
    'failed write retains loaded data and does not poison next edit',
    () async {
      final repository = InMemoryColorHistoryRepository(colors: [red])
        ..failWrites = true;
      final container = containerFor(repository);
      await container.read(colorHistoryProvider.future);
      final controller = container.read(colorHistoryProvider.notifier);
      await expectLater(controller.deleteColor(red.id), throwsStateError);
      expect(container.read(colorHistoryProvider).requireValue, [red]);
      repository.failWrites = false;
      await controller.deleteColor(red.id);
      expect(container.read(colorHistoryProvider).requireValue, isEmpty);
    },
  );

  test('initial failure can retry without erasing stored colors', () async {
    final repository = InMemoryColorHistoryRepository(colors: [red])
      ..failLoad = true;
    final container = containerFor(repository);
    await expectLater(
      container.read(colorHistoryProvider.future),
      throwsStateError,
    );
    expect(container.read(colorHistoryProvider).hasError, isTrue);
    repository.failLoad = false;
    container.invalidate(colorHistoryProvider);
    expect(await container.read(colorHistoryProvider.future), [red]);
  });

  test(
    'search combines favorites with case-insensitive names and hashless HEX',
    () async {
      final container = containerFor(
        InMemoryColorHistoryRepository(colors: [red, blue]),
      );
      await container.read(colorHistoryProvider.future);
      final filter = container.read(historyFilterProvider.notifier);
      filter.setQuery(' OCEAN ');
      expect(container.read(filteredColorsProvider).requireValue, [blue]);
      filter.toggleFavorites();
      expect(container.read(filteredColorsProvider).requireValue, isEmpty);
      filter.setQuery('ff0000');
      expect(container.read(filteredColorsProvider).requireValue, [red]);
      filter.setQuery('');
      expect(container.read(filteredColorsProvider).requireValue, [red]);
      filter.clear();
      expect(container.read(filteredColorsProvider).requireValue, [blue, red]);
    },
  );

  test(
    'retry recreates a failed factory and reuses healthy open storage',
    () async {
      final repository = InMemoryColorHistoryRepository(colors: [red]);
      var failFactory = true;
      var opens = 0;
      final container = ProviderContainer(
        overrides: [
          colorHistoryRepositoryProvider.overrideWith((ref) async {
            opens++;
            if (failFactory) throw StateError('directory unavailable');
            return repository;
          }),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(
        container.read(colorHistoryProvider.future),
        throwsStateError,
      );
      failFactory = false;
      container.read(colorHistoryProvider.notifier).retry();
      expect(await container.read(colorHistoryProvider.future), [red]);
      expect(opens, 2);
      repository.failLoad = true;
      container.invalidate(colorHistoryProvider);
      await expectLater(
        container.read(colorHistoryProvider.future),
        throwsStateError,
      );
      repository.failLoad = false;
      container.read(colorHistoryProvider.notifier).retry();
      expect(await container.read(colorHistoryProvider.future), [red]);
      expect(opens, 2);
    },
  );

  test(
    'retry resolves the documents directory again after its initial failure',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'color_lab_history_directory_retry_',
      );
      ColorHistoryRepository? opened;
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          historyStorageDirectoryProvider.overrideWith((ref) async {
            attempts++;
            if (attempts == 1) {
              throw StateError('documents directory unavailable');
            }
            return directory;
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await opened?.close();
        await directory.delete(recursive: true);
      });
      await expectLater(
        container.read(colorHistoryProvider.future),
        throwsStateError,
      );
      container.read(colorHistoryProvider.notifier).retry();
      expect(await container.read(colorHistoryProvider.future), isEmpty);
      opened = await container.read(colorHistoryRepositoryProvider.future);
      expect(attempts, 2);
    },
  );

  test(
    'disposal while resolving storage directory opens no box files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'color_lab_history_init_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final gate = Completer<Directory>();
      final container = ProviderContainer(
        overrides: [
          historyStorageDirectoryProvider.overrideWith((ref) => gate.future),
        ],
      );
      final opening = container.read(colorHistoryRepositoryProvider.future);
      final rejected = expectLater(opening, throwsA(isA<StateError>()));
      container.dispose();
      gate.complete(directory);
      await rejected;
      expect(await directory.list().toList(), isEmpty);
    },
  );
}
