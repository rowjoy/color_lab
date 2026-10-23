import 'dart:async';

import 'package:hive/hive.dart';
// Independent registries prevent equal box names in different directories
// from sharing Hive's global cache, as in the preferences repository.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../features/picker/domain/acquisition_intent_store.dart';
import '../../features/picker/domain/photo_acquisition.dart';

final class HiveAcquisitionIntentStore implements AcquisitionIntentStore {
  /// Takes ownership of the injected box, including closing it.
  HiveAcquisitionIntentStore.fromBox({required Box<dynamic> box}) : _box = box;

  static Future<HiveAcquisitionIntentStore> open({
    required String directory,
    String boxName = 'photo_acquisition_v1',
  }) async {
    try {
      final hive = HiveImpl();
      Future<Box<dynamic>> openBox() =>
          hive.openBox<dynamic>(boxName, path: directory, crashRecovery: false);
      // Observe both Hive opening futures, including a failed file open.
      final boxes = await Future.wait([openBox(), openBox()]);
      return HiveAcquisitionIntentStore.fromBox(box: boxes.first);
    } catch (_) {
      throw const AcquisitionStorageException();
    }
  }

  final Box<dynamic> _box;
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
      return Future<T>.error(const AcquisitionStorageException());
    }
    final result = _pending.then<T>((_) async {
      try {
        await _ensureDurable();
        return await operation();
      } catch (_) {
        throw const AcquisitionStorageException();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  AcquisitionIntentRecord _read() {
    if (!_box.containsKey('pending')) {
      return const AcquisitionIntentRecord.absent();
    }
    final raw = _box.get('pending');
    final intent = raw is Map ? AcquisitionIntent.fromMap(raw) : null;
    return intent == null
        ? const AcquisitionIntentRecord.untrusted()
        : AcquisitionIntentRecord.valid(intent);
  }

  @override
  Future<AcquisitionIntentRecord> load() => _serialize(_read);

  @override
  Future<void> save(AcquisitionIntent intent) => _serialize(() async {
    if (_read().kind == IntentRecordKind.untrusted ||
        AcquisitionIntent.fromMap(intent.toMap()) == null) {
      throw const AcquisitionStorageException();
    }
    _needsFlush = true;
    await _box.put('pending', intent.toMap());
    await _ensureDurable();
  });

  @override
  Future<void> clear({bool discardUntrusted = false}) => _serialize(() async {
    final record = _read();
    if (record.kind == IntentRecordKind.untrusted && !discardUntrusted) {
      throw const AcquisitionStorageException();
    }
    if (record.kind == IntentRecordKind.absent) return;
    _needsFlush = true;
    await _box.delete('pending');
    await _ensureDurable();
  });

  @override
  Future<void> close() => _closing ??= _pending.then((_) async {
    try {
      await _ensureDurable();
      await _box.close();
    } catch (_) {
      _closing = null;
      throw const AcquisitionStorageException();
    }
  });
}
