import 'dart:async';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/schema/corrupt_record.dart';
import 'package:color_lab/data/schema/repository_snapshot.dart';
import 'package:color_lab/features/history/domain/color_history_repository.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';

/// A test-local repository boundary. Durable behavior is tested with real Hive.
class InMemoryColorHistoryRepository implements ColorHistoryRepository {
  InMemoryColorHistoryRepository({
    Iterable<SavedColor> colors = const [],
    Iterable<CorruptRecord> corruptRecords = const [],
  }) : _colors = {for (final color in colors) color.id: color},
       corruptRecords = List.unmodifiable(corruptRecords);

  final Map<String, SavedColor> _colors;
  List<CorruptRecord> corruptRecords;
  bool failLoad = false;
  bool failWrites = false;
  int activeWrites = 0;
  int maxConcurrentWrites = 0;
  int closeCount = 0;
  Completer<void>? writeGate;

  @override
  Future<RepositorySnapshot<SavedColor>> loadSnapshot() async {
    if (failLoad) throw StateError('private storage load failure');
    final result = _colors.values.toList()
      ..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate == 0 ? a.id.compareTo(b.id) : byDate;
      });
    return RepositorySnapshot(
      records: List.unmodifiable(result),
      corruptRecords: List.unmodifiable(corruptRecords),
    );
  }

  @override
  Future<List<SavedColor>> load() =>
      loadSnapshot().then((snapshot) => snapshot.records);

  Future<T> _write<T>(T Function() operation) async {
    activeWrites++;
    if (activeWrites > maxConcurrentWrites) maxConcurrentWrites = activeWrites;
    try {
      await Future<void>.value();
      if (writeGate != null) await writeGate!.future;
      if (failWrites) throw StateError('private storage write failure');
      return operation();
    } finally {
      activeWrites--;
    }
  }

  @override
  Future<SavedColor> save({
    required RgbColor color,
    required String name,
    required ColorSource source,
  }) => _write(
    () => _colors.putIfAbsent(
      color.hex,
      () => SavedColor(
        id: color.hex,
        hex: color.hex,
        name: name,
        isFavorite: false,
        createdAt: DateTime.now().toUtc(),
        source: source,
      ),
    ),
  );

  @override
  Future<void> setFavorite(String id, bool isFavorite) => _write(() {
    final color = _colors[id];
    if (color == null) throw StateError('saved color not found');
    _colors[id] = color.copyWith(isFavorite: isFavorite);
  });

  @override
  Future<void> delete(String id) => _write(() {
    _colors.remove(id);
  });

  @override
  Future<void> close() async {
    closeCount++;
  }
}
