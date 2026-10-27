import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';
import 'local_data_manager.dart';

/// Used only while an owning repository holds its operation queue.
final class HiveDataLease implements LocalDataLease {
  HiveDataLease(this.boxes, {required this.beforeWrite, required this.flush});
  final Map<String, Box<dynamic>> boxes;
  final void Function() beforeWrite;
  final Future<void> Function() flush;

  String _key(String box, Object key) => jsonEncode([box, _canonical(key)]);

  @override
  Future<LocalDataManifest> inventory() async {
    final entries = <String, String>{};
    var bytes = 0;
    for (final box in boxes.entries) {
      for (final key in box.value.keys) {
        final encoded = utf8.encode(jsonEncode(_canonical(box.value.get(key))));
        entries[_key(box.key, key as Object)] = sha256
            .convert(encoded)
            .toString();
        bytes += encoded.length;
      }
    }
    return LocalDataManifest(entries, bytes);
  }

  @override
  Future<void> erase(LocalDataManifest manifest) async {
    if (!manifest.sameAs(await inventory())) throw const LocalDataException();
    beforeWrite();
    for (final box in boxes.entries) {
      final keys = box.value.keys
          .where(
            (key) => manifest.entries.containsKey(_key(box.key, key as Object)),
          )
          .toList();
      await box.value.deleteAll(keys);
    }
    await flush();
  }
}

Object? _canonical(Object? value) {
  if (value is Map) {
    final entries =
        value.entries
            .map((e) => [_canonical(e.key), _canonical(e.value)])
            .toList()
          ..sort((a, b) => jsonEncode(a[0]).compareTo(jsonEncode(b[0])));
    return ['map', entries];
  }
  if (value is List) return ['list', value.map(_canonical).toList()];
  if (value == null || value is String || value is bool || value is num) {
    return [value.runtimeType.toString(), value.toString()];
  }
  throw const LocalDataException(); // Unknown adapter data is never guessed.
}
