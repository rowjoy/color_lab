import 'dart:async';

import 'package:color_lab/data/schema/corrupt_record.dart';
import 'package:color_lab/data/schema/repository_snapshot.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';

/// Provider/UI test boundary. Real file durability is covered by Hive tests.
final class InMemoryRoomDesignRepository implements RoomDesignRepository {
  InMemoryRoomDesignRepository({
    Iterable<SavedRoomDesign> designs = const [],
    Iterable<CorruptRecord> corruptRecords = const [],
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       corruptRecords = List.unmodifiable(corruptRecords) {
    for (final design in designs) {
      final validated = SavedRoomDesign.fromMap(design.toMap());
      _designs.putIfAbsent(validated.id, () => validated);
    }
  }

  final DateTime Function() _clock;
  final Map<String, SavedRoomDesign> _designs = {};
  List<CorruptRecord> corruptRecords;
  bool failLoad = false;
  bool failWrites = false;
  Completer<void>? writeGate;
  int closeCount = 0;
  int activeWrites = 0;
  int maxConcurrentWrites = 0;

  @override
  Future<RepositorySnapshot<SavedRoomDesign>> loadSnapshot() async {
    if (failLoad) throw const RoomDesignStorageException();
    final designs = _designs.values.toList()
      ..sort((first, second) {
        final byUpdatedAt = second.updatedAt.compareTo(first.updatedAt);
        return byUpdatedAt == 0 ? first.id.compareTo(second.id) : byUpdatedAt;
      });
    return RepositorySnapshot(
      records: List.unmodifiable(designs),
      corruptRecords: List.unmodifiable(corruptRecords),
    );
  }

  @override
  Future<List<SavedRoomDesign>> load() =>
      loadSnapshot().then((snapshot) => snapshot.records);

  Future<T> _write<T>(T Function() operation) async {
    activeWrites++;
    if (activeWrites > maxConcurrentWrites) maxConcurrentWrites = activeWrites;
    try {
      await Future<void>.value();
      if (writeGate case final gate?) await gate.future;
      if (failWrites) throw const RoomDesignStorageException();
      return operation();
    } finally {
      activeWrites--;
    }
  }

  @override
  Future<SavedRoomDesign> save({
    String? existingId,
    required String name,
    required String templateId,
    required IllustratedRoomColors colors,
  }) => _write(() {
    final now = _clock().toUtc();
    if (existingId != null) {
      final previous = _designs[existingId];
      if (previous == null) throw const RoomDesignStorageException();
      final updated = SavedRoomDesign(
        id: previous.id,
        name: name,
        templateId: templateId,
        colors: colors,
        createdAt: previous.createdAt,
        updatedAt: now,
      );
      _designs[updated.id] = updated;
      return updated;
    }

    final base = '${templateId.trim()}-${now.microsecondsSinceEpoch}';
    var id = base;
    var suffix = 1;
    while (_designs.containsKey(id)) {
      id = '$base-${suffix++}';
    }
    final saved = SavedRoomDesign(
      id: id,
      name: name,
      templateId: templateId,
      colors: colors,
      createdAt: now,
      updatedAt: now,
    );
    _designs[id] = saved;
    return saved;
  });

  @override
  Future<void> delete(String id) => _write(() {
    _designs.remove(id);
  });

  @override
  Future<void> close() async {
    closeCount++;
  }
}
