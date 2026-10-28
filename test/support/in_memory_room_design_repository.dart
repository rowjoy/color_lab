import 'dart:async';

import 'package:color_lab/data/schema/corrupt_record.dart';
import 'package:color_lab/data/schema/repository_snapshot.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/features/room_studio/domain/recoverable_room_draft.dart';

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

  SavedRoomDesign _existing(String id) =>
      _designs[id] ?? (throw const RoomDesignStorageException());
  SavedRoomDesign _save({
    SavedRoomDesign? previous,
    required String name,
    required String templateId,
    required int templateRevision,
    required RoomDesignSnapshot snapshot,
    required RoomDesignSnapshot? activeBaseline,
  }) {
    final now = _clock().toUtc();
    final base = '$templateId-${now.microsecondsSinceEpoch}';
    var id = previous?.id ?? base;
    var suffix = 1;
    while (previous == null && _designs.containsKey(id)) {
      id = '$base-${suffix++}';
    }
    final saved = SavedRoomDesign(
      id: id,
      name: name,
      templateId: templateId,
      templateRevision: templateRevision,
      snapshot: snapshot,
      activeBaseline: activeBaseline,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    _designs[id] = saved;
    return saved;
  }

  @override
  Future<SavedRoomDesign> saveNew({
    required String name,
    required String templateId,
    int templateRevision = 1,
    required RoomDesignSnapshot snapshot,
    RoomDesignSnapshot? activeBaseline,
  }) => _write(
    () => _save(
      name: name,
      templateId: templateId,
      templateRevision: templateRevision,
      snapshot: snapshot,
      activeBaseline: activeBaseline,
    ),
  );
  @override
  Future<SavedRoomDesign> update(
    String existingId, {
    required String name,
    required RoomDesignSnapshot snapshot,
    required RoomDesignSnapshot? activeBaseline,
  }) => _write(() {
    final previous = _existing(existingId);
    final updated = _save(
      previous: previous,
      name: name,
      templateId: previous.templateId,
      templateRevision: previous.templateRevision,
      snapshot: snapshot,
      activeBaseline: activeBaseline,
    );
    for (final entry in _drafts.entries.toList()) {
      if (entry.value.savedDesignId == existingId) {
        _drafts[entry.key] = entry.value.withSavedName(updated.name);
      }
    }
    return updated;
  });
  @override
  Future<SavedRoomDesign> saveCopy(String existingId, {required String name}) =>
      _write(() {
        final previous = _existing(existingId);
        return _save(
          name: name,
          templateId: previous.templateId,
          templateRevision: previous.templateRevision,
          snapshot: previous.snapshot,
          activeBaseline: previous.activeBaseline,
        );
      });
  @override
  Future<SavedRoomDesign> rename(String id, String name) => _write(() {
    final previous = _existing(id);
    final renamed = _save(
      previous: previous,
      name: name,
      templateId: previous.templateId,
      templateRevision: previous.templateRevision,
      snapshot: previous.snapshot,
      activeBaseline: previous.activeBaseline,
    );
    for (final entry in _drafts.entries.toList()) {
      if (entry.value.savedDesignId == id) {
        _drafts[entry.key] = entry.value.withSavedName(renamed.name);
      }
    }
    return renamed;
  });
  @override
  Future<SavedRoomDesign> save({
    String? existingId,
    required String name,
    required String templateId,
    required IllustratedRoomColors colors,
  }) => existingId == null
      ? saveNew(
          name: name,
          templateId: templateId,
          snapshot: RoomDesignSnapshot.fromColors(colors),
        )
      : _write(() {
          final previous = _existing(existingId);
          // The four-color adapter cannot express overrides or a pinned baseline.
          // Preserve both while changing only the groups it actually received.
          return _save(
            previous: previous,
            name: name,
            templateId: previous.templateId,
            templateRevision: previous.templateRevision,
            snapshot: RoomDesignSnapshot(
              groupColors: RoomDesignSnapshot.fromColors(colors).groupColors,
              regionOverrides: previous.snapshot.regionOverrides,
            ),
            activeBaseline: previous.activeBaseline,
          );
        });
  final Map<String, RecoverableRoomDraft> _drafts = {};
  @override
  Future<RepositorySnapshot<RecoverableRoomDraft>> loadDraftSnapshot() async {
    if (failLoad) throw const RoomDesignStorageException();
    return RepositorySnapshot(
      records: _drafts.values.toList(),
      corruptRecords: [],
    );
  }

  @override
  Future<void> saveDraft(RecoverableRoomDraft draft) => _write(() {
    _drafts[draft.templateId] = draft;
  });
  @override
  Future<void> retry() async {}

  @override
  Future<void> delete(String id) => _write(() {
    _designs.remove(id);
    for (final entry in _drafts.entries.toList()) {
      if (entry.value.savedDesignId == id) {
        _drafts[entry.key] = entry.value.withoutSavedDesign();
      }
    }
  });

  @override
  Future<void> close() async {
    closeCount++;
  }
}
