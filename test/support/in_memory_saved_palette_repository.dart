import 'dart:async';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/schema/corrupt_record.dart';
import 'package:color_lab/data/schema/repository_snapshot.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/palette/domain/saved_palette_repository.dart';

/// UI/provider test boundary. Disk durability is exercised against real Hive.
class InMemorySavedPaletteRepository implements SavedPaletteRepository {
  InMemorySavedPaletteRepository({
    Iterable<SavedPalette> palettes = const [],
    Iterable<CorruptRecord> corruptRecords = const [],
  }) : corruptRecords = List.unmodifiable(corruptRecords) {
    for (final palette in palettes) {
      // Keep the same validation boundary as a persisted record; first wins.
      final validated = SavedPalette.fromMap(palette.toMap());
      _palettes.putIfAbsent(validated.id, () => validated);
    }
  }

  final _palettes = <String, SavedPalette>{};
  List<CorruptRecord> corruptRecords;
  bool failLoad = false;
  bool failWrites = false;
  Completer<void>? writeGate;
  int closeCount = 0;
  int activeWrites = 0;
  int maxConcurrentWrites = 0;

  @override
  Future<RepositorySnapshot<SavedPalette>> loadSnapshot() async {
    if (failLoad) throw const PaletteStorageException();
    final palettes = _palettes.values.toList()
      ..sort((a, b) {
        final byDate = b.createdAt.compareTo(a.createdAt);
        return byDate == 0 ? a.id.compareTo(b.id) : byDate;
      });
    return RepositorySnapshot(
      records: List<SavedPalette>.unmodifiable(palettes),
      corruptRecords: List<CorruptRecord>.unmodifiable(corruptRecords),
    );
  }

  @override
  Future<List<SavedPalette>> load() =>
      loadSnapshot().then((snapshot) => snapshot.records);

  Future<T> _write<T>(T Function() operation) async {
    activeWrites++;
    if (activeWrites > maxConcurrentWrites) maxConcurrentWrites = activeWrites;
    try {
      await Future<void>.value();
      if (writeGate != null) await writeGate!.future;
      if (failWrites) throw const PaletteStorageException();
      return operation();
    } finally {
      activeWrites--;
    }
  }

  @override
  Future<SavedPalette> save({
    required String name,
    required RgbColor base,
    required HarmonyMode mode,
    required Iterable<RgbColor> colors,
  }) => _write(
    () => _palettes.putIfAbsent(
      SavedPalette.idFor(base, mode),
      () => SavedPalette(
        name: name,
        base: base,
        mode: mode,
        colors: colors,
        createdAt: DateTime.now(),
      ),
    ),
  );

  @override
  Future<void> delete(String id) => _write(() {
    _palettes.remove(id);
  });

  @override
  Future<void> close() async {
    closeCount++;
  }
}
