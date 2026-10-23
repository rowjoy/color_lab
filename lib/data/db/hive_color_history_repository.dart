import 'dart:async';

import 'package:hive/hive.dart';
// Hive 2 exposes no public factory for an independent Hive registry. Each
// repository needs its own registry so equal box names in separate directories
// cannot accidentally share data through Hive's process-global cache.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../core/color/color_engine.dart';
import '../../features/history/domain/color_history_repository.dart';
import '../../features/history/domain/saved_color.dart';

final class HiveColorHistoryRepository implements ColorHistoryRepository {
  HiveColorHistoryRepository._(this._box, this._clock);

  /// Takes ownership of an already opened box and closes it on [close].
  HiveColorHistoryRepository.fromBox({
    required Box<dynamic> box,
    DateTime Function()? clock,
  }) : this._(box, clock ?? DateTime.now);

  /// The caller selects app-private storage and owns this repository's lifetime.
  static Future<HiveColorHistoryRepository> open({
    required String directory,
    String boxName = 'color_history_v1',
    DateTime Function()? clock,
  }) async {
    try {
      final hive = HiveImpl();
      Future<Box<dynamic>> openBox() => hive.openBox<dynamic>(
        boxName,
        path: directory,
        // Recovery truncates corrupt bytes. Preserve data for an explicit retry.
        crashRecovery: false,
      );
      // Hive 2 reports failed opens both on this future and an internal shared
      // opening future. A joining waiter observes the latter too, preventing an
      // otherwise unhandled asynchronous error on unreadable storage.
      final opened = await Future.wait([openBox(), openBox()]);
      final box = opened.first;
      return HiveColorHistoryRepository._(box, clock ?? DateTime.now);
    } catch (_) {
      throw const HistoryStorageException();
    }
  }

  final Box<dynamic> _box;
  final DateTime Function() _clock;
  Future<void> _pending = Future<void>.value();
  Future<void>? _closing;
  bool _needsFlush = false;

  Future<void> _ensureDurable() async {
    if (!_needsFlush) return;
    await _box.flush();
    _needsFlush = false;
  }

  /// Includes reads so callers always observe a consistent point in the queue.
  Future<T> _serialize<T>(FutureOr<T> Function() operation) {
    if (_closing != null) {
      return Future<T>.error(const HistoryStorageException());
    }
    final result = _pending.then<T>((_) async {
      try {
        // Hive commits its cache before flush. Failed flushes must block reads
        // and duplicate/no-op mutations until those writes become durable.
        await _ensureDurable();
        return await operation();
      } catch (_) {
        throw const HistoryStorageException();
      }
    });
    // A failed operation reports to its caller without poisoning later retries.
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  List<SavedColor> _read() {
    final colors = <SavedColor>[];
    for (final key in _box.keys) {
      final map = _box.get(key);
      if (map is! Map) throw const HistoryStorageException();
      final color = SavedColor.fromMap(map);
      if (key != color.id) throw const HistoryStorageException();
      colors.add(color);
    }
    colors.sort((a, b) {
      final dateOrder = b.createdAt.compareTo(a.createdAt);
      return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
    });
    return List.unmodifiable(colors);
  }

  @override
  Future<List<SavedColor>> load() => _serialize(_read);

  @override
  Future<SavedColor> save({
    required RgbColor color,
    required String name,
    required ColorSource source,
  }) => _serialize(() async {
    final existing = _read();
    for (final saved in existing) {
      if (saved.id == color.hex) return saved;
    }
    final saved = SavedColor(
      id: color.hex,
      hex: color.hex,
      name: name,
      isFavorite: false,
      createdAt: _clock(),
      source: source,
    );
    _needsFlush = true;
    await _box.put(saved.id, saved.toMap());
    await _ensureDurable();
    return saved;
  });

  @override
  Future<void> setFavorite(String id, bool isFavorite) => _serialize(() async {
    final colors = _read();
    final normalized = RgbColor.fromHex(id).hex;
    final saved = colors.firstWhere(
      (color) => color.id == normalized,
      orElse: () => throw const HistoryStorageException(),
    );
    if (saved.isFavorite == isFavorite) return;
    _needsFlush = true;
    await _box.put(normalized, saved.copyWith(isFavorite: isFavorite).toMap());
    await _ensureDurable();
  });

  @override
  Future<void> delete(String id) => _serialize(() async {
    final colors = _read();
    final normalized = RgbColor.fromHex(id).hex;
    if (!colors.any((color) => color.id == normalized)) return;
    _needsFlush = true;
    await _box.delete(normalized);
    await _ensureDurable();
  });

  @override
  Future<void> close() => _closing ??= _pending.then((_) async {
    try {
      await _ensureDurable();
      await _box.close();
    } catch (_) {
      // A failed barrier leaves the box open so a later explicit retry can
      // finish flushing and closing instead of caching a permanent close error.
      _closing = null;
      throw const HistoryStorageException();
    }
  });
}
