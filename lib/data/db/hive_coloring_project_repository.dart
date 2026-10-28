import 'dart:async';

import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../features/coloring/domain/coloring_project.dart';
import '../../features/coloring/domain/coloring_project_repository.dart';
import '../schema/corrupt_record.dart';
import '../schema/repository_snapshot.dart';
import '../schema/schema_registry.dart';
import '../storage/hive_data_lease.dart';
import '../storage/local_data_manager.dart';

typedef _CommitPointer = ({String slot, int generation});

final class HiveColoringProjectRepository
    implements ColoringProjectRepository, LocalDataOwner {
  HiveColoringProjectRepository._(this._box)
    : _committed = _readCommitPointers(_box);

  HiveColoringProjectRepository.fromBox({required Box<dynamic> box})
    : this._(box);

  static Future<HiveColoringProjectRepository> open({
    required String directory,
    String? boxName,
  }) async {
    try {
      final hive = HiveImpl();
      final name = boxName ?? SchemaRegistry.coloringProjects.storageName;
      final box = await hive.openBox<dynamic>(
        name,
        path: directory,
        crashRecovery: false,
      );
      return HiveColoringProjectRepository._(box);
    } catch (_) {
      throw const ColoringProjectStorageException();
    }
  }

  final Box<dynamic> _box;
  final Map<String, _CommitPointer> _committed;
  Future<void> _pending = Future.value();
  Future<void>? _closing;
  bool _needsFlush = false;

  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    if (_closing != null) {
      return Future.error(const ColoringProjectStorageException());
    }
    final completer = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        await _flush();
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(
          const ColoringProjectStorageException(),
          stackTrace,
        );
      }
    });
    return completer.future;
  }

  Future<void> _flush() async {
    if (!_needsFlush) return;
    await _box.flush();
    _needsFlush = false;
  }

  Future<void> _put(Object key, Object? value) async {
    _needsFlush = true;
    if (value == null) {
      await _box.delete(key);
    } else {
      await _box.put(key, value);
    }
  }

  Future<void> _write(Map<Object, Object?> changes) async {
    final rollback = {for (final key in changes.keys) key: _box.get(key)};
    try {
      for (final entry in changes.entries) {
        await _put(entry.key, entry.value);
      }
      await _flush();
    } catch (_) {
      try {
        for (final entry in rollback.entries) {
          await _put(entry.key, entry.value);
        }
        await _flush();
      } catch (_) {
        // The caller still receives a storage failure; reopen can use backup.
      }
      rethrow;
    }
  }

  RepositorySnapshot<ColoringProject> _snapshot() {
    final projects = <ColoringProject>[];
    final corrupt = <CorruptRecord>[];
    for (final entry in _committed.entries) {
      final id = entry.key;
      final active = entry.value.slot;
      ColoringProject? project = _decode(
        _box.get(_slotKey(id, active)),
        expectedId: id,
      );
      project ??= _decode(
        _box.get(_slotKey(id, active == 'a' ? 'b' : 'a')),
        expectedId: id,
      );
      if (project == null) {
        corrupt.add(
          CorruptRecord(
            collectionId: SchemaRegistry.coloringProjects.id,
            storageKey: id,
            reason: 'Stored coloring project could not be decoded.',
          ),
        );
      } else {
        projects.add(project);
      }
    }
    for (final key in _box.keys) {
      if (key is String && !key.startsWith('@')) {
        corrupt.add(
          CorruptRecord(
            collectionId: SchemaRegistry.coloringProjects.id,
            storageKey: key,
            reason: 'Uncommitted or legacy coloring record was ignored.',
          ),
        );
      }
      if (key is String &&
          key.startsWith('@commit:') &&
          !_committed.containsKey(key.substring('@commit:'.length))) {
        corrupt.add(
          CorruptRecord(
            collectionId: SchemaRegistry.coloringProjects.id,
            storageKey: key,
            reason: 'Coloring commit pointer could not be decoded.',
          ),
        );
      }
    }
    projects.sort((a, b) {
      final date = b.updatedAt.compareTo(a.updatedAt);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
    return RepositorySnapshot(records: projects, corruptRecords: corrupt);
  }

  ColoringProject? _decode(Object? raw, {required String expectedId}) {
    if (raw is! Map) return null;
    try {
      final project = ColoringProject.fromMap(raw);
      return project.id == expectedId ? project : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<RepositorySnapshot<ColoringProject>> loadSnapshot() =>
      _serialize(_snapshot);

  @override
  Future<ColoringProject?> read(String projectId) => _serialize(
    () => _snapshot().records.where((item) => item.id == projectId).firstOrNull,
  );

  @override
  Future<ColoringProject> save(ColoringProject project) => _serialize(() async {
    final snapshot = _snapshot();
    if (snapshot.corruptRecords.any((item) => item.storageKey == project.id)) {
      throw const ColoringProjectStorageException();
    }
    final previous = snapshot.records
        .where((item) => item.id == project.id)
        .firstOrNull;
    if (previous != null &&
        (previous.drawingId != project.drawingId ||
            previous.drawingRevision != project.drawingRevision ||
            previous.mode != project.mode ||
            project.createdAt != previous.createdAt)) {
      throw const ColoringProjectStorageException();
    }
    final current = _committed[project.id];
    final nextSlot = current?.slot == 'a' ? 'b' : 'a';
    final nextGeneration = (current?.generation ?? 0) + 1;
    final encoded = project.toMap();
    // The inactive slot is durable before the small authoritative pointer
    // changes. A failed pointer write keeps the previous acknowledged slot.
    await _write({_slotKey(project.id, nextSlot): encoded});
    await _write({
      _commitKey(project.id): {
        'version': 1,
        'active': nextSlot,
        'generation': nextGeneration,
      },
    });
    _committed[project.id] = (slot: nextSlot, generation: nextGeneration);
    return project;
  });

  @override
  Future<void> delete(String projectId) => _serialize(() async {
    await _write({_commitKey(projectId): null});
    _committed.remove(projectId);
    await _write({
      _slotKey(projectId, 'a'): null,
      _slotKey(projectId, 'b'): null,
    });
  });

  @override
  Future<T> withMaintenance<T>(Future<T> Function(LocalDataLease) action) =>
      _serialize(() => action(_ColoringProjectDataLease(this)));

  @override
  Future<void> close() => _closing ??= _pending.then((_) async {
    await _flush();
    await _box.close();
  });

  static String _commitKey(String id) => '@commit:$id';
  static String _slotKey(String id, String slot) => '@slot:$slot:$id';

  static Map<String, _CommitPointer> _readCommitPointers(Box<dynamic> box) {
    final pointers = <String, _CommitPointer>{};
    for (final key in box.keys) {
      if (key is! String || !key.startsWith('@commit:')) continue;
      final raw = box.get(key);
      if (raw is! Map ||
          raw.length != 3 ||
          raw['version'] != 1 ||
          !const {'a', 'b'}.contains(raw['active']) ||
          raw['generation'] is! int ||
          (raw['generation'] as int) < 1) {
        continue;
      }
      pointers[key.substring('@commit:'.length)] = (
        slot: raw['active'] as String,
        generation: raw['generation'] as int,
      );
    }
    return pointers;
  }
}

/// Counts projects while retaining every physical row for exact deletion.
final class _ColoringProjectDataLease implements LocalDataLease {
  _ColoringProjectDataLease(this._owner)
    : _rows = HiveDataLease(
        {'records': _owner._box},
        beforeWrite: () => _owner._needsFlush = true,
        flush: _owner._flush,
      );

  final HiveColoringProjectRepository _owner;
  final HiveDataLease _rows;

  @override
  Future<LocalDataManifest> inventory() async {
    final manifest = await _rows.inventory();
    final identities = <Object>{};
    for (final key in _owner._box.keys) {
      if (key is String) {
        const prefixes = ['@commit:', '@slot:a:', '@slot:b:'];
        final prefix = prefixes.where(key.startsWith).firstOrNull;
        if (prefix != null) {
          identities.add(key.substring(prefix.length));
          continue;
        }
        if (!key.startsWith('@')) {
          identities.add(key);
          continue;
        }
      }
      // Unknown rows remain visible and owned, even without a project ID.
      identities.add((key,));
    }
    return LocalDataManifest(
      manifest.entries,
      manifest.estimatedBytes,
      recordCount: identities.length,
    );
  }

  @override
  Future<void> erase(LocalDataManifest manifest) async {
    await _rows.erase(manifest);
    _owner._committed.clear();
  }
}
