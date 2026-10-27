import 'dart:async';
import '../storage/local_data_manager.dart';
import '../storage/hive_data_lease.dart';

import 'package:hive/hive.dart';
// Hive 2 has no public independent-registry factory. A private registry prevents
// equal box names in different app-private directories sharing a global cache.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../core/color/color_engine.dart';
import '../../features/palette/domain/saved_palette.dart';
import '../../features/palette/domain/saved_palette_repository.dart';
import '../schema/corrupt_record.dart';
import '../schema/repository_snapshot.dart';
import '../schema/schema_registry.dart';

final class HivePaletteRepository
    implements SavedPaletteRepository, LocalDataOwner {
  HivePaletteRepository._(this._box, this._clock);

  /// Takes ownership of the box, including its close lifecycle.
  HivePaletteRepository.fromBox({
    required Box<dynamic> box,
    DateTime Function()? clock,
  }) : this._(box, clock ?? DateTime.now);

  static Future<HivePaletteRepository> open({
    required String directory,
    String boxName = 'color_palettes_v1',
    DateTime Function()? clock,
  }) async {
    try {
      final hive = HiveImpl();
      Future<Box<dynamic>> openBox() => hive.openBox<dynamic>(
        boxName,
        path: directory,
        // Automatic recovery would truncate corrupt data before a user retry.
        crashRecovery: false,
      );
      // Hive exposes a second shared opening future on failures. Observe both
      // futures so an unreadable box cannot cause an unhandled async error.
      final opened = await Future.wait([openBox(), openBox()]);
      return HivePaletteRepository._(opened.first, clock ?? DateTime.now);
    } catch (_) {
      throw const PaletteStorageException();
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

  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    if (_closing != null) {
      return Future<T>.error(const PaletteStorageException());
    }
    final result = _pending.then<T>((_) async {
      try {
        // Hive updates its memory cache before flush succeeds. Reads, duplicate
        // saves and missing deletes must all wait for the durability barrier.
        await _ensureDurable();
        return await operation();
      } catch (_) {
        throw const PaletteStorageException();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  RepositorySnapshot<SavedPalette> _readSnapshot() {
    final palettes = <SavedPalette>[];
    final corruptRecords = <CorruptRecord>[];
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value is! Map) {
        corruptRecords.add(_corrupt(key, 'Stored value is not a record.'));
        continue;
      }
      late final SavedPalette palette;
      try {
        palette = SavedPalette.fromMap(value);
      } on FormatException {
        corruptRecords.add(
          _corrupt(key, 'Stored record could not be decoded.'),
        );
        continue;
      }
      if (key != palette.id) {
        corruptRecords.add(
          _corrupt(key, 'Stored key does not match the record identifier.'),
        );
        continue;
      }
      palettes.add(palette);
    }
    palettes.sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      return byDate == 0 ? a.id.compareTo(b.id) : byDate;
    });
    return RepositorySnapshot(
      records: List<SavedPalette>.unmodifiable(palettes),
      corruptRecords: List<CorruptRecord>.unmodifiable(corruptRecords),
    );
  }

  CorruptRecord _corrupt(Object key, String reason) => CorruptRecord(
    collectionId: SchemaRegistry.savedPalettes.id,
    storageKey: key,
    reason: reason,
  );

  @override
  Future<RepositorySnapshot<SavedPalette>> loadSnapshot() =>
      _serialize(_readSnapshot);

  @override
  Future<List<SavedPalette>> load() =>
      loadSnapshot().then((snapshot) => snapshot.records);

  @override
  Future<SavedPalette> save({
    required String name,
    required RgbColor base,
    required HarmonyMode mode,
    required Iterable<RgbColor> colors,
  }) => _serialize(() async {
    final id = SavedPalette.idFor(base, mode);
    for (final existing in _readSnapshot().records) {
      if (existing.id == id) return existing;
    }
    // Deterministic IDs must never overwrite an undecodable raw record.
    if (_box.keys.contains(id)) throw const PaletteStorageException();
    final saved = SavedPalette(
      name: name,
      base: base,
      mode: mode,
      colors: colors,
      createdAt: _clock(),
    );
    _needsFlush = true;
    await _box.put(saved.id, saved.toMap());
    await _ensureDurable();
    return saved;
  });

  @override
  Future<void> delete(String id) => _serialize(() async {
    if (!_readSnapshot().records.any((palette) => palette.id == id)) return;
    _needsFlush = true;
    await _box.delete(id);
    await _ensureDurable();
  });

  @override
  Future<void> close() => _closing ??= _pending.then((_) async {
    try {
      await _ensureDurable();
      await _box.close();
    } catch (_) {
      _closing = null;
      throw const PaletteStorageException();
    }
  });
}
