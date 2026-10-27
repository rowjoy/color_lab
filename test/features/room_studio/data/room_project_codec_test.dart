import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/features/room_studio/data/room_project_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/room_project_fixtures.dart';
import '../../../support/frozen_room_project_fixtures.dart';

void main() {
  const codec = RoomProjectCodec();
  Map<String, dynamic> manifest() =>
      jsonDecode(
            utf8.decode(
              codec.encode(roomProjectFixture(revision: 1)).manifestBytes,
            ),
          )
          as Map<String, dynamic>;
  Uint8List bytes(Map<String, dynamic> value) =>
      Uint8List.fromList(utf8.encode(jsonEncode(value)));

  test(
    'frozen independent schema-v1 manifests decode without encoding',
    () async {
      final files = await frozenRoomFiles();
      for (final id in ['v1-healthy', 'v1-manual']) {
        final prefix = 'projects/$id/';
        final manifest =
            files['${prefix}revisions/${id == 'v1-healthy' ? 3 : 1}/manifest.json']!;
        final parsed = codec.readManifest(manifest);
        final decoded = codec.decode(parsed, {
          for (final entry in files.entries)
            if (entry.key.startsWith('${prefix}assets/'))
              entry.key.substring(prefix.length): entry.value,
        }).snapshot;
        expect(decoded.projectId, id);
        expect(decoded.photoId, '$id-photo');
        expect((decoded.width, decoded.height), (3, 2));
        expect(decoded.createdAt, DateTime.utc(2026, 10, 27, 1));
        if (id == 'v1-healthy') {
          expect(decoded.revision, 3);
          expect(decoded.aiMaskBytes, [1, 1, 0, 4, 3, 0]);
          expect(decoded.maskBytes, [1, 2, 0, 4, 3, 1]);
          expect(decoded.activeVariantId, 'b');
          expect(decoded.comparisonBaselineVariantId, 'a');
          expect(decoded.variants.map((v) => v.name), ['Warm', 'Cool']);
          expect(decoded.variants[1].colors.wall!.hex, '#2255AA');
          expect(decoded.thumbnailPng, isNotNull);
        } else {
          expect(decoded.aiMaskBytes, List.filled(6, 0));
          expect(decoded.maskBytes, [0, 1, 0, 0, 0, 0]);
          expect(decoded.thumbnailPng, isNull);
        }
        for (final version in [0, 2, 999]) {
          final changed =
              jsonDecode(utf8.decode(manifest)) as Map<String, dynamic>;
          changed['schemaVersion'] = version;
          expect(
            () => codec.readManifest(bytes(changed)),
            throwsFormatException,
          );
        }
        final unsupported =
            jsonDecode(utf8.decode(manifest)) as Map<String, dynamic>;
        unsupported['intent'] = [1];
        expect(
          () => codec.readManifest(bytes(unsupported)),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'v1 roundtrip uses canonical UTC/HEX and immutable asset references',
    () {
      final encoded = codec.encode(roomProjectFixture(revision: 1));
      final data = jsonDecode(utf8.decode(encoded.manifestBytes));
      expect(data['schemaVersion'], 1);
      expect(data['createdAt'], '2026-10-27T01:00:00.000Z');
      expect(data['variants'][0]['colors']['wall'], '#ABCDEF');
      final decoded = codec.decode(
        codec.readManifest(encoded.manifestBytes),
        encoded.assets,
      );
      expect(decoded.snapshot.projectId, 'project-1');
      expect(decoded.snapshot.name, 'Living room');
      expect(decoded.snapshot.revision, 1);
      expect(decoded.snapshot.photoPng, roomProjectPng());
      expect(decoded.snapshot.aiMaskBytes, [1, 1, 0, 4]);
      expect(decoded.snapshot.maskBytes, [1, 2, 3, 4]);
      expect(decoded.snapshot.comparisonBaselineVariantId, 'variant-b');
      expect(decoded.thumbnailUnavailable, false);
    },
  );

  test('missing/unknown required v1 data and future schemas fail closed', () {
    for (final key in [
      'schemaVersion',
      'projectId',
      'name',
      'revision',
      'photoId',
      'width',
      'height',
      'assets',
      'variants',
      'activeVariantId',
      'comparisonBaselineVariantId',
      'createdAt',
      'updatedAt',
      'maskRevision',
      'colorRevision',
    ]) {
      final data = manifest()..remove(key);
      expect(
        () => codec.readManifest(bytes(data)),
        throwsFormatException,
        reason: key,
      );
    }
    for (final version in [0, 2, '1', 1.0]) {
      final data = manifest()..['schemaVersion'] = version;
      expect(() => codec.readManifest(bytes(data)), throwsFormatException);
    }
    final unknown = manifest()..['requiredFeature'] = 'intent-v2';
    expect(() => codec.readManifest(bytes(unknown)), throwsFormatException);
  });

  test(
    'untrusted dimensions, counts, dates and colors are bounded before assets',
    () {
      for (final field in ['width', 'height']) {
        for (final value in [0, -1, 100000, 1.5, 'Infinity']) {
          final data = manifest()..[field] = value;
          expect(() => codec.readManifest(bytes(data)), throwsFormatException);
        }
      }
      for (final value in [-1, 0, 2147483648, 1.5]) {
        final data = manifest()..['revision'] = value;
        expect(() => codec.readManifest(bytes(data)), throwsFormatException);
      }
      for (final date in [
        '2026-10-27T01:00:00+00:00',
        'not-a-date',
        '2026-02-30T00:00:00.000Z',
      ]) {
        final data = manifest()..['createdAt'] = date;
        expect(() => codec.readManifest(bytes(data)), throwsFormatException);
      }
      final lowercase = manifest();
      lowercase['variants'][0]['colors']['wall'] = '#abcdef';
      expect(() => codec.readManifest(bytes(lowercase)), throwsFormatException);
      final duplicate = manifest();
      duplicate['variants'].add(duplicate['variants'].first);
      expect(() => codec.readManifest(bytes(duplicate)), throwsFormatException);
    },
  );

  test(
    'only exact content-addressed relative paths and mask lengths are accepted',
    () {
      for (final path in [
        '../outside.png',
        '/tmp/x',
        'assets/../x',
        r'assets\x',
        'assets/foreign.png',
        'assets/${'a' * 64}.png/extra',
      ]) {
        final data = manifest();
        data['assets']['photo']['path'] = path;
        expect(() => codec.readManifest(bytes(data)), throwsFormatException);
      }
      for (final length in [-1, 0, 67108865, 3]) {
        final data = manifest();
        data['assets']['mask']['length'] = length;
        expect(() => codec.readManifest(bytes(data)), throwsFormatException);
      }
      final data = manifest();
      data['assets']['photo']['sha256'] = 'a' * 64;
      expect(() => codec.readManifest(bytes(data)), throwsFormatException);
      expect(
        () => codec.readManifest(Uint8List(262145)),
        throwsFormatException,
      );
    },
  );

  test(
    'core asset corruption fails but a corrupt thumbnail keeps usable data',
    () {
      final encoded = codec.encode(roomProjectFixture(revision: 1));
      final parsed = codec.readManifest(encoded.manifestBytes);
      final data = manifest();
      final corruptCore = Map<String, Uint8List>.of(encoded.assets)
        ..[data['assets']['mask']['path'] as String] = Uint8List(4);
      expect(() => codec.decode(parsed, corruptCore), throwsFormatException);
      final corruptThumbnail = Map<String, Uint8List>.of(encoded.assets)
        ..[data['assets']['thumbnail']['path'] as String] = Uint8List(5);
      final decoded = codec.decode(parsed, corruptThumbnail);
      expect(decoded.snapshot.maskBytes, [1, 2, 3, 4]);
      expect(decoded.snapshot.thumbnailPng, isNull);
      expect(decoded.thumbnailUnavailable, true);
    },
  );

  test(
    'PNG content and declared dimensions are checked before decoding pixels',
    () {
      final fixture = roomProjectFixture(revision: 1);
      expect(
        () => codec.encode(fixture.copyWith(photoPng: Uint8List(20))),
        throwsFormatException,
      );
      expect(
        () =>
            codec.encode(fixture.copyWith(photoPng: roomProjectPng(width: 3))),
        throwsFormatException,
      );
      final huge = roomProjectPng();
      ByteData.sublistView(huge).setUint32(16, 0x7fffffff);
      expect(
        () => codec.encode(fixture.copyWith(photoPng: huge)),
        throwsFormatException,
      );
    },
  );

  for (final method in [
    (name: 'compression 1', compression: 1, filter: 0, interlace: 0),
    (name: 'compression 255', compression: 255, filter: 0, interlace: 0),
    (name: 'filter 1', compression: 0, filter: 1, interlace: 0),
    (name: 'filter 255', compression: 0, filter: 255, interlace: 0),
    (name: 'interlace 2', compression: 0, filter: 0, interlace: 2),
    (name: 'interlace 255', compression: 0, filter: 0, interlace: 255),
  ]) {
    test('rejects unsupported IHDR ${method.name} with a valid CRC', () async {
      final png = roomProjectPngWithMethods(
        compression: method.compression,
        filter: method.filter,
        interlace: method.interlace,
      );
      await expectLater(_flutterImageSize(png), throwsException);
      expect(
        () => codec.encode(
          roomProjectOnePixelFixture(photoPng: png, revision: 1),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.encode(
          roomProjectFixture(revision: 1).copyWith(thumbnailPng: png),
        ),
        throwsFormatException,
      );
    });
  }

  for (final interlace in [0, 1]) {
    test(
      'preserves Flutter-renderable standard interlace method $interlace',
      () async {
        final png = roomProjectPngWithMethods(interlace: interlace);
        expect(await _flutterImageSize(png), (1, 1));
        final encoded = codec.encode(
          roomProjectOnePixelFixture(photoPng: png, revision: 1),
        );
        final decoded = codec.decode(
          codec.readManifest(encoded.manifestBytes),
          encoded.assets,
        );
        expect(decoded.snapshot.photoPng, png);
      },
    );
  }

  for (final chunk in ['IHDR', 'IDAT', 'IEND']) {
    test('rejects an invalid $chunk CRC for photo and thumbnail PNGs', () {
      final png = roomProjectPng();
      final view = ByteData.sublistView(png);
      var offset = 8;
      while (ascii.decode(png.sublist(offset + 4, offset + 8)) != chunk) {
        offset += view.getUint32(offset) + 12;
      }
      png[offset + 8 + view.getUint32(offset)] ^= 1;
      final fixture = roomProjectFixture(revision: 1);
      expect(
        () => codec.encode(fixture.copyWith(photoPng: png)),
        throwsFormatException,
      );
      expect(
        () => codec.encode(fixture.copyWith(thumbnailPng: png)),
        throwsFormatException,
      );
    });
  }
}

Future<(int, int)> _flutterImageSize(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  try {
    final frame = await codec.getNextFrame();
    try {
      return (frame.image.width, frame.image.height);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}
