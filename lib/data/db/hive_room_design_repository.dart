import 'dart:async';

import 'package:hive/hive.dart';
// Hive 2 has no public independent-registry factory. A private registry keeps
// equal box names in different app-private directories independent.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../features/room_studio/domain/illustrated_room.dart';
import '../../features/room_studio/domain/room_design_repository.dart';
import '../../features/room_studio/domain/saved_room_design.dart';

final class HiveRoomDesignRepository implements RoomDesignRepository {
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
      return Future<T>.error(const RoomDesignStorageException());
    }
    final result = _pending.then<T>((_) async {
      try {
        await _ensureDurable();
        return await operation();
      } catch (_) {
        throw const RoomDesignStorageException();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  List<SavedRoomDesign> _read() {
    final designs = <SavedRoomDesign>[];
    for (final key in _box.keys) {
      final value = _box.get(key);
      if (value is! Map) throw const RoomDesignStorageException();
      final design = SavedRoomDesign.fromMap(value);
      if (key != design.id) throw const RoomDesignStorageException();
      designs.add(design);
    }
    designs.sort((first, second) {
      final byUpdatedAt = second.updatedAt.compareTo(first.updatedAt);
      return byUpdatedAt == 0 ? first.id.compareTo(second.id) : byUpdatedAt;
    });
    return List.unmodifiable(designs);
  }

  @override
  Future<List<SavedRoomDesign>> load() => _serialize(_read);

  @override
  Future<SavedRoomDesign> save({
    String? existingId,
    required String name,
    required String templateId,
    required IllustratedRoomColors colors,
  }) => _serialize(() async {
    final existing = _read();
    final now = _clock().toUtc();
    late final SavedRoomDesign saved;
    if (existingId == null) {
      saved = SavedRoomDesign(
        id: _nextId(templateId, now, existing),
        name: name,
        templateId: templateId,
        colors: colors,
        createdAt: now,
        updatedAt: now,
      );
    } else {
      SavedRoomDesign? previous;
      for (final design in existing) {
        if (design.id == existingId) {
          previous = design;
          break;
        }
      }
      if (previous == null) throw const RoomDesignStorageException();
      saved = SavedRoomDesign(
        id: previous.id,
        name: name,
        templateId: templateId,
        colors: colors,
        createdAt: previous.createdAt,
        updatedAt: now,
      );
    }

    _needsFlush = true;
    await _box.put(saved.id, saved.toMap());
    await _ensureDurable();
    return saved;
  });

  String _nextId(
    String templateId,
    DateTime now,
    List<SavedRoomDesign> existing,
  ) {
    final normalizedTemplateId = templateId.trim();
    if (normalizedTemplateId.isEmpty) {
      throw ArgumentError.value(templateId, 'templateId', 'Must not be empty');
    }
    final base = '$normalizedTemplateId-${now.microsecondsSinceEpoch}';
    final used = existing.map((design) => design.id).toSet();
    if (!used.contains(base)) return base;
    var suffix = 1;
    while (used.contains('$base-$suffix')) {
      suffix++;
    }
    return '$base-$suffix';
  }

  @override
  Future<void> delete(String id) => _serialize(() async {
    if (!_read().any((design) => design.id == id)) return;
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
      throw const RoomDesignStorageException();
    }
  });
}
