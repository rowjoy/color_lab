import 'dart:async';
import '../storage/local_data_manager.dart';
import '../storage/hive_data_lease.dart';

import 'package:hive/hive.dart';
// Hive 2 has no public independent-registry factory. A private registry keeps
// equal box names in different app-private directories independent.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../features/room_studio/domain/illustrated_room.dart';
import '../../features/room_studio/domain/room_design_repository.dart';
import '../../features/room_studio/domain/saved_room_design.dart';
import '../../features/room_studio/domain/recoverable_room_draft.dart';
import '../schema/corrupt_record.dart';
import '../schema/repository_snapshot.dart';
import '../schema/schema_registry.dart';

final class HiveRoomDesignRepository
    implements RoomDesignRepository, LocalDataOwner {
  HiveRoomDesignRepository._(this._box, this._clock);

  /// Takes ownership of [box], including its close lifecycle.
  HiveRoomDesignRepository.fromBox({
    required Box<dynamic> box,
    DateTime Function()? clock,
  }) : this._(box, clock ?? DateTime.now);

  static Future<HiveRoomDesignRepository> open({
    required String directory,
    String boxName = 'illustrated_room_designs_v1',
    DateTime Function()? clock,
  }) async {
    try {
      final hive = HiveImpl();
      Future<Box<dynamic>> openBox() => hive.openBox<dynamic>(
        boxName,
        path: directory,
        // Recovery may truncate corrupt user data before a retry can inspect it.
        crashRecovery: false,
      );
      // Hive shares the opening future internally. Observe both references so
      // an open failure never escapes as an unhandled asynchronous error.
      final opened = await Future.wait([openBox(), openBox()]);
      return HiveRoomDesignRepository._(opened.first, clock ?? DateTime.now);
    } catch (_) {
      throw const RoomDesignStorageException();
    }
  }

  final Box<dynamic> _box;

  @override
  Future<T> withMaintenance<T>(Future<T> Function(LocalDataLease) action) =>
      _serialize(
        () => action(
          HiveDataLease(
            {'records': _box},
            beforeWrite: () => _needsFlush = true,
            flush: _ensureDurable,
          ),
        ),
      );
  final DateTime Function() _clock;
  Future<void> _pending = Future<void>.value();
  Future<void>? _closing;
  bool _needsFlush = false;

  Future<void> _ensureDurable() async {
    if (!_needsFlush) return;
    await _box.flush();
    _needsFlush = false;
  }

  bool _failed = false;
  Map<Object, Object?>? _rollback;

  Future<void> _restoreRollback() async {
    final rollback = _rollback;
    if (rollback == null) return;
    _needsFlush = true;
    for (final entry in rollback.entries) {
      if (entry.value == null) {
        await _box.delete(entry.key);
      } else {
        await _box.put(entry.key, entry.value);
      }
    }
    await _ensureDurable();
    _rollback = null;
  }

  /// Hive mutates its cache before flush. A failed attempt is rolled back, never
  /// implicitly promoted by a read/close. The barrier stays blocked until Retry.
  Future<void> _write(Map<Object, Object?> changes) async {
    _rollback = {for (final key in changes.keys) key: _box.get(key)};
    try {
      _needsFlush = true;
      for (final entry in changes.entries) {
        if (entry.value == null) {
          await _box.delete(entry.key);
        } else {
          await _box.put(entry.key, entry.value);
        }
      }
      await _ensureDurable();
      _rollback = null;
    } catch (_) {
      _failed = true;
      try {
        await _restoreRollback();
      } catch (_) {
        /* Retry/close must finish rollback. */
      }
      rethrow;
    }
  }

  Future<T> _serialize<T>(
    FutureOr<T> Function() operation, {
    bool retry = false,
  }) {
    if (_closing != null) {
      return Future<T>.error(const RoomDesignStorageException());
    }
    final result = _pending.then<T>((_) async {
      try {
        if (_failed && !retry) throw const RoomDesignStorageException();
        if (retry) await _restoreRollback();
        await _ensureDurable();
        return await operation();
      } catch (_) {
        throw const RoomDesignStorageException();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<void> retry() => _serialize(() {
    _failed = false;
  }, retry: true);

  RepositorySnapshot<SavedRoomDesign> _readSnapshot() {
    final designs = <SavedRoomDesign>[];
    final corruptRecords = <CorruptRecord>[];
    for (final key in _box.keys) {
      if (key is String && key.startsWith('@draft:')) continue;
      final value = _box.get(key);
      if (value is! Map) {
        corruptRecords.add(_corrupt(key, 'Stored value is not a record.'));
        continue;
      }
      late final SavedRoomDesign design;
      try {
        design = SavedRoomDesign.fromMap(value);
      } on FormatException {
        corruptRecords.add(
          _corrupt(key, 'Stored record could not be decoded.'),
        );
        continue;
      }
      if (key != design.id) {
        corruptRecords.add(
          _corrupt(key, 'Stored key does not match the record identifier.'),
        );
        continue;
      }
      designs.add(design);
    }
    designs.sort((first, second) {
      final byUpdatedAt = second.updatedAt.compareTo(first.updatedAt);
      return byUpdatedAt == 0 ? first.id.compareTo(second.id) : byUpdatedAt;
    });
    return RepositorySnapshot(
      records: List.unmodifiable(designs),
      corruptRecords: List.unmodifiable(corruptRecords),
    );
  }

  CorruptRecord _corrupt(Object key, String reason) => CorruptRecord(
    collectionId: SchemaRegistry.illustratedRooms.id,
    storageKey: key,
    reason: reason,
  );

  @override
  Future<RepositorySnapshot<SavedRoomDesign>> loadSnapshot() =>
      _serialize(() async {
        final snapshot = _readSnapshot();
        final migrations = <Object, Object?>{};
        for (final design in snapshot.records) {
          if ((_box.get(design.id) as Map)['version'] == 1) {
            migrations[design.id] = design.toMap();
          }
        }
        if (migrations.isNotEmpty) await _write(migrations);
        return snapshot;
      });

  @override
  Future<List<SavedRoomDesign>> load() =>
      loadSnapshot().then((snapshot) => snapshot.records);

  SavedRoomDesign _existing(String id) => _readSnapshot().records.firstWhere(
    (design) => design.id == id,
    orElse: () => throw const RoomDesignStorageException(),
  );

  Future<SavedRoomDesign> _save({
    SavedRoomDesign? previous,
    required String name,
    required String templateId,
    required int templateRevision,
    required RoomDesignSnapshot snapshot,
    required RoomDesignSnapshot? activeBaseline,
    bool reconcileDraftName = false,
  }) async {
    final now = _clock().toUtc();
    final saved = SavedRoomDesign(
      id:
          previous?.id ??
          _nextId(templateId, now, _box.keys.cast<Object>().toSet()),
      name: name,
      templateId: templateId,
      templateRevision: templateRevision,
      snapshot: snapshot,
      activeBaseline: activeBaseline,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    await _write({
      saved.id: saved.toMap(),
      if (reconcileDraftName)
        for (final draft in _readDraftSnapshot().records.where(
          (draft) => draft.savedDesignId == saved.id,
        ))
          '@draft:${draft.templateId}': draft.withSavedName(saved.name).toMap(),
    });
    return saved;
  }

  @override
  Future<SavedRoomDesign> saveNew({
    required String name,
    required String templateId,
    int templateRevision = 1,
    required RoomDesignSnapshot snapshot,
    RoomDesignSnapshot? activeBaseline,
  }) => _serialize(
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
  }) => _serialize(() {
    final previous = _existing(existingId);
    return _save(
      previous: previous,
      name: name,
      templateId: previous.templateId,
      templateRevision: previous.templateRevision,
      snapshot: snapshot,
      activeBaseline: activeBaseline,
      reconcileDraftName: true,
    );
  });

  @override
  Future<SavedRoomDesign> rename(String id, String name) => _serialize(() {
    final previous = _existing(id);
    return _save(
      previous: previous,
      name: name,
      templateId: previous.templateId,
      templateRevision: previous.templateRevision,
      snapshot: previous.snapshot,
      activeBaseline: previous.activeBaseline,
      reconcileDraftName: true,
    );
  });

  @override
  Future<SavedRoomDesign> saveCopy(String existingId, {required String name}) =>
      _serialize(() {
        final previous = _existing(existingId);
        return _save(
          name: name,
          templateId: previous.templateId,
          templateRevision: previous.templateRevision,
          snapshot: previous.snapshot,
          activeBaseline: previous.activeBaseline,
        );
      });

  /// Temporary four-group adapter. New callers use the explicit snapshot actions.
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
      : _serialize(() {
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

  RepositorySnapshot<RecoverableRoomDraft> _readDraftSnapshot() {
    final drafts = <RecoverableRoomDraft>[];
    final corrupt = <CorruptRecord>[];
    for (final key in _box.keys) {
      if (key is! String || !key.startsWith('@draft:')) continue;
      try {
        final value = _box.get(key);
        if (value is! Map) throw const FormatException('Invalid draft.');
        final draft = RecoverableRoomDraft.fromMap(value);
        if (key != '@draft:${draft.templateId}') {
          throw const FormatException('Draft key mismatch.');
        }
        drafts.add(draft);
      } on FormatException {
        corrupt.add(_corrupt(key, 'Stored draft could not be decoded.'));
      }
    }
    return RepositorySnapshot(records: drafts, corruptRecords: corrupt);
  }

  @override
  Future<RepositorySnapshot<RecoverableRoomDraft>> loadDraftSnapshot() =>
      _serialize(_readDraftSnapshot);

  @override
  Future<void> saveDraft(RecoverableRoomDraft draft) => _serialize(() async {
    final key = '@draft:${draft.templateId}';
    final snapshot = _readDraftSnapshot();
    if (snapshot.corruptRecords.any((record) => record.storageKey == key)) {
      throw const RoomDesignStorageException();
    }
    final previous = snapshot.records
        .where((record) => record.templateId == draft.templateId)
        .firstOrNull;
    if (previous != null && draft.updatedAt.isBefore(previous.updatedAt)) {
      throw const RoomDesignStorageException();
    }
    await _write({key: draft.toMap()});
  });

  String _nextId(String templateId, DateTime now, Set<Object> used) {
    final normalizedTemplateId = templateId.trim();
    if (normalizedTemplateId.isEmpty) {
      throw ArgumentError.value(templateId, 'templateId', 'Must not be empty');
    }
    final base = '$normalizedTemplateId-${now.microsecondsSinceEpoch}';
    if (!used.contains(base)) return base;
    var suffix = 1;
    while (used.contains('$base-$suffix')) {
      suffix++;
    }
    return '$base-$suffix';
  }

  @override
  Future<void> delete(String id) => _serialize(() async {
    if (!_readSnapshot().records.any((design) => design.id == id)) return;
    await _write({
      id: null,
      for (final draft in _readDraftSnapshot().records.where(
        (draft) => draft.savedDesignId == id,
      ))
        '@draft:${draft.templateId}': draft.withoutSavedDesign().toMap(),
    });
  });

  @override
  Future<void> close() => _closing ??= _pending.then((_) async {
    try {
      await _restoreRollback();
      await _ensureDurable();
    } catch (_) {
      // Rollback/flush failed before close: this open handle can still retry.
      _closing = null;
      throw const RoomDesignStorageException();
    }
    try {
      await _box.close();
    } catch (_) {
      // Hive marks itself closed before awaiting backend close. Keep this
      // terminal handle unavailable, including Retry; the owner must reopen.
      throw const RoomDesignStorageException();
    }
  });
}
