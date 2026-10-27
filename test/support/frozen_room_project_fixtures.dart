import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Frozen v1 bytes are read, never regenerated with the encoder under test.
Future<Map<String, Uint8List>> frozenRoomFiles() async {
  final root = Directory('test/fixtures/room_projects/v1');
  final source = await File('${root.path}/inventory.json').readAsBytes();
  expect(
    sha256.convert(source).toString(),
    '365055822f7b29fbff9b09afdd242c8bd597f0ff9a0980b99d559e11fbca1013',
  );
  final inventory = jsonDecode(utf8.decode(source)) as Map<String, dynamic>;
  expect(inventory['schemaVersion'], 1);
  expect(
    inventory['originatingCommit'],
    '4d98b1604d6901086035dd8eb7af26b61ced824f',
  );
  final result = <String, Uint8List>{};
  for (final entry in inventory['files'] as List) {
    final path = entry['path'] as String;
    expect(path, isNot(contains('..')));
    final bytes = await File('${root.path}/$path').readAsBytes();
    expect(bytes.length, entry['length'], reason: path);
    expect(sha256.convert(bytes).toString(), entry['sha256'], reason: path);
    result[path] = bytes;
  }
  return result;
}

Future<void> copyFrozenRooms(Directory root) async {
  for (final entry in (await frozenRoomFiles()).entries) {
    final file = File('${root.path}/room_projects/${entry.key}');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(entry.value, flush: true);
  }
}
