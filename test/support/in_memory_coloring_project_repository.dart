import 'dart:async';

import 'package:color_lab/data/schema/repository_snapshot.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/coloring_project_repository.dart';

final class InMemoryColoringProjectRepository
    implements ColoringProjectRepository {
  InMemoryColoringProjectRepository([Iterable<ColoringProject> seed = const []])
    : _records = {for (final item in seed) item.id: _copy(item)};

  final Map<String, ColoringProject> _records;
  Future<void> _pending = Future.value();
  bool failNextSave = false;
  Completer<void>? saveGate;
  bool closed = false;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        result.complete(await action());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  @override
  Future<RepositorySnapshot<ColoringProject>> loadSnapshot() => _serialize(
    () async => RepositorySnapshot(
      records: _records.values.map(_copy).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
      corruptRecords: const [],
    ),
  );

  @override
  Future<ColoringProject?> read(String projectId) => _serialize(() async {
    final value = _records[projectId];
    return value == null ? null : _copy(value);
  });

  @override
  Future<ColoringProject> save(ColoringProject project) => _serialize(() async {
    await saveGate?.future;
    saveGate = null;
    if (failNextSave) {
      failNextSave = false;
      throw const ColoringProjectStorageException();
    }
    final copy = _copy(project);
    _records[copy.id] = copy;
    return _copy(copy);
  });

  @override
  Future<void> delete(String projectId) => _serialize(() async {
    _records.remove(projectId);
  });

  @override
  Future<void> close() async {
    await _pending;
    closed = true;
  }

  static ColoringProject _copy(ColoringProject value) =>
      ColoringProject.fromMap(value.toMap());
}
