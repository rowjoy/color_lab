import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../../data/db/hive_color_history_repository.dart';
import '../../../data/schema/corrupt_record.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../domain/color_history_repository.dart';
import '../domain/saved_color.dart';

final historyStorageDirectoryProvider = appStorageDirectoryProvider;

final colorHistoryRepositoryProvider = FutureProvider<ColorHistoryRepository>((
  ref,
) async {
  final storage = await ref.watch(appStorageDirectoryProvider.future);
  if (!ref.mounted) {
    throw StateError('History was disposed during initialization.');
  }
  final directory = resolveAppStorageDirectory(storage);
  final repository = await HiveColorHistoryRepository.open(
    directory: directory.path,
  );
  if (!ref.mounted) {
    await repository.close();
    throw StateError('History was disposed during initialization.');
  }
  ref.onDispose(() {
    unawaited(
      repository.close().catchError((Object error, StackTrace stack) {
        debugPrint('Color history could not be closed cleanly.');
      }),
    );
  });
  return repository;
});

final colorHistoryProvider =
    AsyncNotifierProvider<ColorHistoryController, List<SavedColor>>(
      ColorHistoryController.new,
    );

final colorHistoryCorruptRecordsProvider = Provider<List<CorruptRecord>>((ref) {
  ref.watch(colorHistoryProvider);
  return ref.watch(colorHistoryProvider.notifier).corruptRecords;
});

class ColorHistoryController extends AsyncNotifier<List<SavedColor>> {
  Future<void> _pending = Future<void>.value();
  List<CorruptRecord> _corruptRecords = const [];

  List<CorruptRecord> get corruptRecords => _corruptRecords;

  @override
  Future<List<SavedColor>> build() async {
    final repository = await ref.watch(colorHistoryRepositoryProvider.future);
    final snapshot = await repository.loadSnapshot();
    _corruptRecords = List.unmodifiable(snapshot.corruptRecords);
    return List.unmodifiable(snapshot.records);
  }

  Future<T> _mutate<T>(Future<T> Function(ColorHistoryRepository) operation) {
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        // Do not edit an unreadable library or race its initial snapshot.
        await future;
        if (!ref.mounted) throw StateError('History is no longer available.');
        final repository = await ref.read(
          colorHistoryRepositoryProvider.future,
        );
        final value = await operation(repository);
        final snapshot = await repository.loadSnapshot();
        if (ref.mounted) {
          _corruptRecords = List.unmodifiable(snapshot.corruptRecords);
          state = AsyncData(List.unmodifiable(snapshot.records));
        }
        result.complete(value);
      } catch (error, stack) {
        // Keep the last good snapshot. Each caller presents its own friendly error.
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  Future<SavedColor> saveColor(
    RgbColor color, {
    required String name,
    ColorSource source = ColorSource.manual,
  }) => _mutate(
    (repository) => repository.save(color: color, name: name, source: source),
  );

  Future<void> setFavorite(String id, bool isFavorite) =>
      _mutate((repository) => repository.setFavorite(id, isFavorite));

  Future<void> deleteColor(String id) =>
      _mutate((repository) => repository.delete(id));

  void retry() {
    if (ref.read(historyStorageDirectoryProvider).hasError) {
      ref.invalidate(historyStorageDirectoryProvider);
    }
    // A read error can be retried on the existing open box. Reopen only when
    // the factory itself failed, avoiding close/reopen races on healthy boxes.
    if (ref.read(colorHistoryRepositoryProvider).hasError) {
      ref.invalidate(colorHistoryRepositoryProvider);
    }
    ref.invalidateSelf();
  }
}

typedef HistoryFilter = ({String query, bool favoritesOnly});

final historyFilterProvider =
    NotifierProvider<HistoryFilterController, HistoryFilter>(
      HistoryFilterController.new,
    );

class HistoryFilterController extends Notifier<HistoryFilter> {
  @override
  HistoryFilter build() => (query: '', favoritesOnly: false);

  void setQuery(String query) =>
      state = (query: query, favoritesOnly: state.favoritesOnly);
  void toggleFavorites() =>
      state = (query: state.query, favoritesOnly: !state.favoritesOnly);
  void clear() => state = (query: '', favoritesOnly: false);
}

final filteredColorsProvider = Provider<AsyncValue<List<SavedColor>>>((ref) {
  final filter = ref.watch(historyFilterProvider);
  final query = filter.query.trim().toLowerCase();
  return ref
      .watch(colorHistoryProvider)
      .whenData(
        (colors) => List.unmodifiable(
          colors.where(
            (color) =>
                (!filter.favoritesOnly || color.isFavorite) &&
                (query.isEmpty ||
                    color.name.toLowerCase().contains(query) ||
                    color.hex.toLowerCase().contains(query)),
          ),
        ),
      );
});
