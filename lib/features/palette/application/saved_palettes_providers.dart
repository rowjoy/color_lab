import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/color/color_engine.dart';
import '../../../data/db/hive_palette_repository.dart';
import '../domain/saved_palette.dart';
import '../domain/saved_palette_repository.dart';

final paletteStorageDirectoryProvider = FutureProvider<Directory>(
  (ref) => getApplicationDocumentsDirectory(),
  retry: (retryCount, error) => null,
);

final savedPaletteRepositoryProvider = FutureProvider<SavedPaletteRepository>((
  ref,
) async {
  final documents = await ref.watch(paletteStorageDirectoryProvider.future);
  if (!ref.mounted) {
    throw StateError('Palettes were disposed during initialization.');
  }
  final repository = await HivePaletteRepository.open(
    directory: '${documents.path}/color_lab',
  );
  if (!ref.mounted) {
    await repository.close();
    throw StateError('Palettes were disposed during initialization.');
  }
  ref.onDispose(() {
    unawaited(
      repository.close().catchError((Object error, StackTrace stack) {
        debugPrint('Saved palettes could not be closed cleanly.');
      }),
    );
  });
  return repository;
}, retry: (retryCount, error) => null);

final savedPalettesProvider =
    AsyncNotifierProvider<SavedPalettesController, List<SavedPalette>>(
      SavedPalettesController.new,
      retry: (retryCount, error) => null,
    );

class SavedPalettesController extends AsyncNotifier<List<SavedPalette>> {
  Future<void> _pending = Future<void>.value();

  @override
  Future<List<SavedPalette>> build() async {
    final repository = await ref.watch(savedPaletteRepositoryProvider.future);
    if (!ref.mounted) throw StateError('Palettes are no longer available.');
    return List<SavedPalette>.unmodifiable(await repository.load());
  }

  Future<T> _mutate<T>(Future<T> Function(SavedPaletteRepository) operation) {
    if (!ref.mounted) {
      return Future<T>.error(StateError('Palettes are no longer available.'));
    }
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        if (!ref.mounted) throw StateError('Palettes are no longer available.');
        // A failed initial load must be retried before this library is edited.
        await future;
        if (!ref.mounted) throw StateError('Palettes are no longer available.');
        final repository = await ref.read(
          savedPaletteRepositoryProvider.future,
        );
        if (!ref.mounted) throw StateError('Palettes are no longer available.');
        final value = await operation(repository);
        if (!ref.mounted) throw StateError('Palettes are no longer available.');
        final palettes = List<SavedPalette>.unmodifiable(
          await repository.load(),
        );
        if (!ref.mounted) throw StateError('Palettes are no longer available.');
        state = AsyncData(palettes);
        result.complete(value);
      } catch (error, stack) {
        // Mutation errors belong to the caller; keep the last committed list.
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<SavedPalette> savePalette({
    required String name,
    required RgbColor base,
    required HarmonyMode mode,
    required Iterable<RgbColor> colors,
  }) => _mutate(
    (repository) =>
        repository.save(name: name, base: base, mode: mode, colors: colors),
  );

  Future<void> deletePalette(String id) =>
      _mutate((repository) => repository.delete(id));

  void retry() {
    if (!ref.mounted) return;
    if (ref.read(paletteStorageDirectoryProvider).hasError) {
      ref.invalidate(paletteStorageDirectoryProvider);
    }
    // Healthy open boxes can reload in place; failed factories need recreation.
    if (ref.read(savedPaletteRepositoryProvider).hasError) {
      ref.invalidate(savedPaletteRepositoryProvider);
    }
    ref.invalidateSelf();
  }
}
