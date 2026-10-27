import 'dart:io';
import 'dart:typed_data';
import 'package:color_lab/features/room_studio/application/room_export_metadata_verifier.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/room_png_fixtures.dart';

void main() {
  const verifier = RoomExportMetadataVerifier();
  final invalid = throwsA(isA<RoomExportVerificationException>());
  test(
    'only complete metadata-free RGB/RGBA PNGs expose verified dimensions',
    () {
      for (final channels in [3, 4]) {
        final png = roomPng(width: 3, height: 2, channels: channels);
        final dimensions = verifier.verify(png);
        expect((dimensions.width, dimensions.height), (3, 2));
        final chunks = pngChunks(png);
        final idat = chunks[1].$2;
        final split = pngFromChunks([
          chunks.first,
          ('IDAT', idat.sublist(0, 2)),
          ('IDAT', idat.sublist(2)),
          chunks.last,
        ]);
        expect(verifier.verify(split).width, 3);
      }
    },
  );
  test('rejects signature-only data and all forbidden metadata carriers', () {
    expect(() => verifier.verify(Uint8List.fromList(pngSignature)), invalid);
    for (final name in [
      'eXIf',
      'tEXt',
      'zTXt',
      'iTXt',
      'iCCP',
      'sRGB',
      'gAMA',
      'cHRM',
      'tIME',
      'acTL',
      'PLTE',
      'vpAg',
    ]) {
      final chunks = pngChunks(roomPng());
      expect(
        () => verifier.verify(
          pngFromChunks([
            chunks.first,
            (name, [1, 2, 3]),
            ...chunks.skip(1),
          ]),
        ),
        invalid,
        reason: name,
      );
    }
  });
  test('rejects duplicate, missing, misordered, empty and trailing chunks', () {
    final c = pngChunks(roomPng());
    for (final chunks in <List<(String, List<int>)>>[
      [c[0], c[0], c[1], c[2]],
      [c[1], c[0], c[2]],
      [c[0], c[2]],
      [c[0], ('IDAT', []), c[2]],
      [c[0], c[1], c[2], c[2]],
      [
        c[0],
        c[1],
        ('IEND', [0]),
      ],
      [c[0], c[1]],
    ]) {
      expect(() => verifier.verify(pngFromChunks(chunks)), invalid);
    }
    expect(
      () => verifier.verify(Uint8List.fromList([...roomPng(), 1])),
      invalid,
    );
  });
  test('bounds lengths and checks every chunk CRC including IEND', () {
    final png = roomPng();
    for (var length = 0; length < png.length; length++) {
      expect(() => verifier.verify(png.sublist(0, length)), invalid);
    }
    var offset = 8;
    for (final chunk in pngChunks(png)) {
      final corrupt = Uint8List.fromList(png);
      corrupt[offset + 8 + chunk.$2.length] ^= 1;
      expect(() => verifier.verify(corrupt), invalid, reason: chunk.$1);
      offset += 12 + chunk.$2.length;
    }
    for (final length in [0x7fffffff, 0xffffffff]) {
      final corrupt = Uint8List.fromList(png);
      ByteData.sublistView(corrupt).setUint32(8, length);
      expect(() => verifier.verify(corrupt), invalid);
    }
  });
  test('rejects unsupported IHDR profiles and dimensions', () {
    final c = pngChunks(roomPng());
    for (final (index, value) in [
      (8, 16),
      (9, 0),
      (9, 3),
      (9, 4),
      (10, 1),
      (11, 1),
      (12, 1),
    ]) {
      final header = Uint8List.fromList(c.first.$2)..[index] = value;
      expect(
        () => verifier.verify(pngFromChunks([('IHDR', header), ...c.skip(1)])),
        invalid,
      );
    }
    for (final (w, h) in [
      (0, 1),
      (1, 0),
      (4097, 1),
      (1, 4097),
      (0xffffffff, 0xffffffff),
    ]) {
      expect(
        () => verifier.verify(rawPng([0, 1, 2, 3, 4], width: w, height: h)),
        invalid,
      );
    }
    expect(
      () => verifier.verify(
        pngFromChunks([('IHDR', c.first.$2.sublist(0, 12)), ...c.skip(1)]),
      ),
      invalid,
    );
  });
  test('validates zlib checksum, termination, exact rows and filter bytes', () {
    final compressed = zlib.encode([0, 1, 2, 3, 4]);
    final badChecksum = List<int>.from(compressed)
      ..[compressed.length - 1] ^= 1;
    for (final payload in [
      compressed.sublist(0, compressed.length - 1),
      badChecksum,
      [...compressed, 0],
      [...compressed, ...compressed],
      [0, 0, 0],
    ]) {
      expect(() => verifier.verify(rawPng([], compressed: payload)), invalid);
    }
    for (final rows in <List<int>>[
      [0, 1, 2, 3],
      [0, 1, 2, 3, 4, 5],
      [5, 1, 2, 3, 4],
      [],
    ]) {
      expect(() => verifier.verify(rawPng(rows)), invalid);
    }
    for (var filter = 0; filter < 5; filter++) {
      expect(verifier.verify(rawPng([filter, 1, 2, 3, 4])).height, 1);
    }
  });
  test('rejects output bombs and encoded/chunk budgets before large work', () {
    expect(() => verifier.verify(rawPng(List.filled(1024 * 1024, 0))), invalid);
    expect(() => verifier.verify(Uint8List(64 * 1024 * 1024 + 1)), invalid);
    final c = pngChunks(roomPng());
    expect(
      () => verifier.verify(
        pngFromChunks([
          c.first,
          for (var i = 0; i < 4095; i++) ('IDAT', [0]),
          c.last,
        ]),
      ),
      invalid,
    );
  });
}
