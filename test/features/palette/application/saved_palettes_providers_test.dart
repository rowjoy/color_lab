import 'dart:async';
import 'dart:io';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/palette/domain/saved_palette_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_saved_palette_repository.dart';

/// Triggers disposal precisely after the factory's initial mounted check but
/// before the asynchronous real Hive open finishes.
class _DisposingDirectory implements Directory {
  _DisposingDirectory(this.delegate, this.onPath);
  final Directory delegate;
  final void Function() onPath;
  @override
  String get path {
    onPath();
    return delegate.path;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final base = RgbColor(255, 0, 0);
  final error = throwsA(isA<PaletteStorageException>());
  final first = SavedPalette(
    name: 'First',
    base: base,
    mode: HarmonyMode.complementary,
    colors: [base, RgbColor(1, 2, 3)],
    createdAt: DateTime.utc(2026, 10, 20),
  );
  final second = SavedPalette(
    name: 'Second',
    base: base,
    mode: HarmonyMode.triadic,
    colors: [base],
    createdAt: DateTime.utc(2026, 10, 21),
  );
  ProviderContainer containerFor(InMemorySavedPaletteRepository repository) {
    final container = ProviderContainer(
      overrides: [
        savedPaletteRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<SavedPalette> save(
    SavedPalettesController controller, {
    String name = 'New',
    HarmonyMode mode = HarmonyMode.complementary,
  }) => controller.savePalette(
    name: name,
    base: base,
    mode: mode,
    colors: [base, RgbColor(1, 2, 3)],
  );

  test(
    'loads immutable newest-first palette snapshots with first duplicate preserved',
    () async {
      final duplicate = SavedPalette(
        name: 'Duplicate',
        base: base,
        mode: HarmonyMode.complementary,
        colors: [base],
        createdAt: DateTime.utc(2027),
      );
      final container = containerFor(
        InMemorySavedPaletteRepository(palettes: [first, second, duplicate]),
      );
      final palettes = await container.read(savedPalettesProvider.future);
      expect(palettes, [second, first]);
      expect(() => palettes.clear(), throwsUnsupportedError);
    },
  );

  test(
    'serializes edits and publishes only after gated durable success',
    () async {
      final repository = InMemorySavedPaletteRepository()
        ..writeGate = Completer<void>();
      final container = containerFor(repository);
      await container.read(savedPalettesProvider.future);
      final controller = container.read(savedPalettesProvider.notifier);
      final saving = save(controller, name: 'Original');
      final duplicate = save(controller, name: 'Duplicate');
      final another = save(controller, mode: HarmonyMode.triadic);
      final deletion = controller.deletePalette('triadic-FF0000');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(savedPalettesProvider).requireValue, isEmpty);
      repository.writeGate!.complete();
      final saved = await saving;
      await Future.wait([duplicate, another, deletion]);
      expect(await duplicate, saved);
      expect(repository.maxConcurrentWrites, 1);
      expect(container.read(savedPalettesProvider).requireValue, [saved]);
    },
  );

  test(
    'failed save and delete preserve committed state then permit another edit',
    () async {
      final repository = InMemorySavedPaletteRepository(palettes: [first])
        ..failWrites = true;
      final container = containerFor(repository);
      await container.read(savedPalettesProvider.future);
      final controller = container.read(savedPalettesProvider.notifier);
      await expectLater(save(controller, mode: HarmonyMode.triadic), error);
      await expectLater(controller.deletePalette(first.id), error);
      expect(container.read(savedPalettesProvider).requireValue, [first]);
      repository.failWrites = false;
      await controller.deletePalette(first.id);
      expect(container.read(savedPalettesProvider).requireValue, isEmpty);
    },
  );

  test(
    'initial load failure blocks edits until retry reuses healthy repository',
    () async {
      final repository = InMemorySavedPaletteRepository(palettes: [first])
        ..failLoad = true;
      var opens = 0;
      final container = ProviderContainer(
        overrides: [
          savedPaletteRepositoryProvider.overrideWith((ref) async {
            opens++;
            return repository;
          }),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(container.read(savedPalettesProvider.future), error);
      repository.failLoad = false;
      final controller = container.read(savedPalettesProvider.notifier);
      await expectLater(controller.deletePalette(first.id), error);
      expect(await repository.load(), [first]);
      controller.retry();
      expect(await container.read(savedPalettesProvider.future), [first]);
      expect(opens, 1);
    },
  );

  test(
    'retry recreates a failed factory and leaves healthy factory open',
    () async {
      final repository = InMemorySavedPaletteRepository(palettes: [first]);
      var failFactory = true;
      var opens = 0;
      final container = ProviderContainer(
        overrides: [
          savedPaletteRepositoryProvider.overrideWith((ref) async {
            opens++;
            if (failFactory) throw const PaletteStorageException();
            return repository;
          }),
        ],
      );
      addTearDown(container.dispose);
      await expectLater(container.read(savedPalettesProvider.future), error);
      failFactory = false;
      container.read(savedPalettesProvider.notifier).retry();
      expect(await container.read(savedPalettesProvider.future), [first]);
      repository.failLoad = true;
      container.invalidate(savedPalettesProvider);
      await expectLater(container.read(savedPalettesProvider.future), error);
      repository.failLoad = false;
      container.read(savedPalettesProvider.notifier).retry();
      expect(await container.read(savedPalettesProvider.future), [first]);
      expect(opens, 2);
      expect(repository.closeCount, 0);
    },
  );

  test(
    'retry resolves a failed documents directory and opens actual palette box',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'palette-directory-retry-',
      );
      var attempts = 0;
      final container = ProviderContainer(
        overrides: [
          paletteStorageDirectoryProvider.overrideWith((ref) async {
            if (++attempts == 1) throw const PaletteStorageException();
            return directory;
          }),
        ],
      );
      try {
        await expectLater(container.read(savedPalettesProvider.future), error);
        container.read(savedPalettesProvider.notifier).retry();
        expect(await container.read(savedPalettesProvider.future), isEmpty);
        expect(attempts, 2);
        expect(
          await File(
            '${directory.path}/color_lab/color_palettes_v1.hive',
          ).exists(),
          isTrue,
        );
        await (await container.read(
          savedPaletteRepositoryProvider.future,
        )).close();
      } finally {
        container.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'fresh containers reload every field from actual file snapshot',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'palette-container-restart-',
      );
      ProviderContainer open() => ProviderContainer(
        overrides: [
          paletteStorageDirectoryProvider.overrideWith(
            (ref) async => directory,
          ),
        ],
      );
      var container = open();
      try {
        await container.read(savedPalettesProvider.future);
        final saved = await container
            .read(savedPalettesProvider.notifier)
            .savePalette(
              name: '  Persisted  ',
              base: base,
              mode: HarmonyMode.tetradic,
              colors: [base, RgbColor(7, 8, 9), RgbColor(20, 30, 40)],
            );
        await (await container.read(
          savedPaletteRepositoryProvider.future,
        )).close();
        container.dispose();
        container = open();
        final loaded = await container.read(savedPalettesProvider.future);
        expect(loaded, [saved]);
        expect(loaded.single.name, 'Persisted');
        expect(loaded.single.mode, HarmonyMode.tetradic);
        expect(loaded.single.colors.map((color) => color.hex), [
          '#FF0000',
          '#070809',
          '#141E28',
        ]);
        await container
            .read(savedPalettesProvider.notifier)
            .deletePalette(saved.id);
        await (await container.read(
          savedPaletteRepositoryProvider.future,
        )).close();
        container.dispose();
        container = open();
        expect(await container.read(savedPalettesProvider.future), isEmpty);
        await (await container.read(
          savedPaletteRepositoryProvider.future,
        )).close();
      } finally {
        container.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  test('factory disposal closes the actual opened repository', () async {
    final directory = await Directory.systemTemp.createTemp(
      'palette-disposal-',
    );
    final container = ProviderContainer(
      overrides: [
        paletteStorageDirectoryProvider.overrideWith((ref) async => directory),
      ],
    );
    final repository = await container.read(
      savedPaletteRepositoryProvider.future,
    );
    container.dispose();
    await expectLater(repository.load(), error);
    await repository.close();
    await directory.delete(recursive: true);
  });

  test('disposal while directory is unresolved creates no box files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'palette-late-directory-',
    );
    final gate = Completer<Directory>();
    final container = ProviderContainer(
      overrides: [
        paletteStorageDirectoryProvider.overrideWith((ref) => gate.future),
      ],
    );
    final rejected = expectLater(
      container.read(savedPaletteRepositoryProvider.future),
      throwsA(isA<StateError>()),
    );
    container.dispose();
    gate.complete(directory);
    await rejected;
    await Future<void>.delayed(Duration.zero);
    expect(await directory.list().toList(), isEmpty);
    await directory.delete(recursive: true);
  });

  test('late initialized real factory closes its box after disposal', () async {
    final directory = await Directory.systemTemp.createTemp(
      'palette-late-open-',
    );
    late ProviderContainer container;
    container = ProviderContainer(
      overrides: [
        paletteStorageDirectoryProvider.overrideWith(
          (ref) async =>
              _DisposingDirectory(directory, () => container.dispose()),
        ),
      ],
    );
    await expectLater(
      container.read(savedPaletteRepositoryProvider.future),
      throwsA(isA<StateError>()),
    );
    final file = File('${directory.path}/color_lab/color_palettes_v1.hive');
    final lock = File('${directory.path}/color_lab/color_palettes_v1.lock');
    // The factory's asynchronous open continues after Riverpod cancels its
    // public future; wait until actual file creation and owned lock cleanup.
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while ((!await file.exists() || await lock.exists()) &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(await file.exists(), isTrue);
    expect(await lock.exists(), isFalse);
    await directory.delete(recursive: true);
  });

  test(
    'disposed controller rejects queued edits without touching storage',
    () async {
      final repository = InMemorySavedPaletteRepository()
        ..writeGate = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          savedPaletteRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      await container.read(savedPalettesProvider.future);
      final controller = container.read(savedPalettesProvider.notifier);
      final saving = save(controller);
      final queued = controller.deletePalette('complementary-FF0000');
      final saveRejected = expectLater(saving, throwsA(isA<StateError>()));
      final queuedRejected = expectLater(queued, throwsA(isA<StateError>()));
      await Future<void>.delayed(Duration.zero);
      container.dispose();
      repository.writeGate!.complete();
      await Future.wait([saveRejected, queuedRejected]);
      expect((await repository.load()).single.name, 'New');
      expect(repository.maxConcurrentWrites, 1);
    },
  );
}
