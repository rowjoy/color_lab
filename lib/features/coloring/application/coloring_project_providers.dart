import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/hive_coloring_project_repository.dart';
import '../../../data/schema/corrupt_record.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../data/drawing_catalog_loader.dart';
import '../domain/coloring_project.dart';
import '../domain/coloring_project_repository.dart';
import '../domain/drawing_definition.dart';

final drawingCatalogLoaderProvider = Provider<DrawingCatalogLoader>(
  (ref) => AssetDrawingCatalogLoader(),
);

final drawingCatalogProvider = FutureProvider<List<DrawingDefinition>>(
  (ref) => ref.watch(drawingCatalogLoaderProvider).load(),
  retry: (retryCount, error) => null,
);

final coloringProjectRepositoryProvider =
    FutureProvider<ColoringProjectRepository>((ref) async {
      final storage = await ref.watch(appStorageDirectoryProvider.future);
      if (!ref.mounted) throw StateError('Coloring projects were disposed.');
      final repository = await HiveColoringProjectRepository.open(
        directory: resolveAppStorageDirectory(storage).path,
      );
      if (!ref.mounted) {
        await repository.close();
        throw StateError('Coloring projects were disposed.');
      }
      ref.onDispose(() {
        unawaited(
          repository.close().catchError((Object error, StackTrace stackTrace) {
            debugPrint('Coloring projects could not close cleanly.');
          }),
        );
      });
      return repository;
    }, retry: (retryCount, error) => null);

final coloringProjectsProvider =
    AsyncNotifierProvider<ColoringProjectsController, List<ColoringProject>>(
      ColoringProjectsController.new,
      retry: (retryCount, error) => null,
    );

/// Always re-reads the authoritative committed record when a workspace opens.
final coloringProjectProvider = FutureProvider.autoDispose
    .family<ColoringProject?, String>((ref, projectId) async {
      final repository = await ref.watch(
        coloringProjectRepositoryProvider.future,
      );
      return repository.read(projectId);
    }, retry: (retryCount, error) => null);

final coloringProjectCorruptRecordsProvider = Provider<List<CorruptRecord>>((
  ref,
) {
  ref.watch(coloringProjectsProvider);
  return ref.watch(coloringProjectsProvider.notifier).corruptRecords;
});

class ColoringProjectsController extends AsyncNotifier<List<ColoringProject>> {
  Future<void> _pending = Future.value();
  List<CorruptRecord> _corruptRecords = const [];

  List<CorruptRecord> get corruptRecords => _corruptRecords;

  @override
  Future<List<ColoringProject>> build() async {
    final repository = await ref.watch(
      coloringProjectRepositoryProvider.future,
    );
    final snapshot = await repository.loadSnapshot();
    _corruptRecords = List.unmodifiable(snapshot.corruptRecords);
    return List.unmodifiable(snapshot.records);
  }

  Future<T> _mutate<T>(Future<T> Function(ColoringProjectRepository) action) {
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        await future;
        if (!ref.mounted) {
          throw StateError('Coloring projects are unavailable.');
        }
        final repository = await ref.read(
          coloringProjectRepositoryProvider.future,
        );
        final value = await action(repository);
        final snapshot = await repository.loadSnapshot();
        if (ref.mounted) {
          _corruptRecords = List.unmodifiable(snapshot.corruptRecords);
          state = AsyncData(List.unmodifiable(snapshot.records));
        }
        result.complete(value);
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<ColoringProject> create(
    DrawingDefinition definition,
    ColoringMode mode,
  ) => _mutate((repository) {
    final project = ColoringProject.create(
      drawingId: definition.id,
      drawingRevision: definition.revision,
      mode: mode,
    );
    return repository.save(project);
  });

  Future<ColoringProject> duplicate(ColoringProject source) =>
      _mutate((repository) {
        final copy =
            ColoringProject.create(
              drawingId: source.drawingId,
              drawingRevision: source.drawingRevision,
              mode: source.mode,
            ).copyWith(
              assignments: source.assignments,
              guidedFilledRegionIds: source.guidedFilledRegionIds,
              completed: source.completed,
              updatedAt: DateTime.now().toUtc(),
            );
        return repository.save(copy);
      });

  Future<void> delete(String id) =>
      _mutate((repository) => repository.delete(id));

  void publishAcknowledged(ColoringProject project) {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }
    final records =
        [
          project,
          for (final item in current)
            if (item.id != project.id) item,
        ]..sort((a, b) {
          final date = b.updatedAt.compareTo(a.updatedAt);
          return date == 0 ? a.id.compareTo(b.id) : date;
        });
    state = AsyncData(List.unmodifiable(records));
  }

  void refresh() => ref.invalidateSelf();
}
