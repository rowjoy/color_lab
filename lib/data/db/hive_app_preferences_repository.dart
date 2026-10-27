import 'dart:async';
import '../storage/local_data_manager.dart';
import '../storage/hive_data_lease.dart';

import 'package:hive/hive.dart';
// Hive 2 has no public independent-registry factory. Separate registries keep
// equal box names in different directories from sharing the global box cache.
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

import '../../features/settings/domain/app_preferences.dart';
import '../../features/settings/domain/app_preferences_repository.dart';

final class HiveAppPreferencesRepository
    implements AppPreferencesRepository, LocalDataOwner {
  /// Takes ownership of [box], including closing it on [close].
  HiveAppPreferencesRepository.fromBox({required Box<dynamic> box})
    : _box = box;

  static Future<HiveAppPreferencesRepository> open({
    required String directory,
    String boxName = 'app_preferences_v1',
  }) async {
    try {
      final hive = HiveImpl();
      Future<Box<dynamic>> openBox() =>
          hive.openBox<dynamic>(boxName, path: directory, crashRecovery: false);
      // Observe Hive's shared opening future as well as the initiating one;
      // otherwise failed file opens also emit an unhandled asynchronous error.
      final opened = await Future.wait([openBox(), openBox()]);
      return HiveAppPreferencesRepository.fromBox(box: opened.first);
    } catch (_) {
      throw const PreferencesStorageException();
    }
  }

  final Box<dynamic> _box;

  @override
  Future<T> withMaintenance<T>(Future<T> Function(LocalDataLease) action) =>
      _serialize(() {
        _read(); // Unsupported preference records remain untouched.
        return action(
          HiveDataLease(
            {'preferences': _box},
            beforeWrite: () => _needsFlush = true,
            flush: _ensureDurable,
          ),
        );
      });
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
      return Future<T>.error(const PreferencesStorageException());
    }
    final result = _pending.then<T>((_) async {
      try {
        // Hive updates memory before flush; retry that durability boundary
        // before permitting reads or unchanged-value saves to report success.
        await _ensureDurable();
        return await operation();
      } catch (_) {
        throw const PreferencesStorageException();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  AppPreferences _read() {
    if (!_box.containsKey('preferences')) return const AppPreferences();
    final record = _box.get('preferences');
    if (record is! Map) throw const PreferencesStorageException();
    return AppPreferences.fromMap(record);
  }

  @override
  Future<AppPreferences> load() => _serialize(_read);

  @override
  Future<void> save(AppPreferences preferences) => _serialize(() async {
    // Validate existing records before writing; errors must never erase them.
    if (_read() == preferences) return;
    _needsFlush = true;
    await _box.put('preferences', preferences.toMap());
    await _ensureDurable();
  });

  @override
  Future<void> close() => _closing ??= _pending.then((_) async {
    try {
      await _ensureDurable();
      await _box.close();
    } catch (_) {
      _closing = null;
      throw const PreferencesStorageException();
    }
  });
}
