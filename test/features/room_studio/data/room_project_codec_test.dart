import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/features/room_studio/data/room_project_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';

import '../../../support/room_project_fixtures.dart';
import '../../../support/frozen_room_project_fixtures.dart';
import '../../../support/mask_edit_fixtures.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/data/mask_edit_history_codec.dart';

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
        for (final version in [0, 3, 999]) {
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
    'frozen v1 migrates without inferring corrections or changing appearance',
    () async {
      final files = await frozenRoomFiles();
      for (final id in ['v1-healthy', 'v1-manual']) {
        final prefix = 'projects/$id/';
        final oldBytes =
            files['${prefix}revisions/${id == 'v1-healthy' ? 3 : 1}/manifest.json']!;
        final old = jsonDecode(utf8.decode(oldBytes)) as Map<String, dynamic>;
        final decoded = codec.decode(codec.readManifest(oldBytes), {
          for (final entry in files.entries)
            if (entry.key.startsWith('${prefix}assets/'))
              entry.key.substring(prefix.length): entry.value,
        }).snapshot;
        expect(decoded.schemaVersion, 2);
        expect(decoded.intent.bytes, [0, 0, 0, 0, 0, 0]);
        final encoded = codec.encode(decoded);
        final rewritten =
            jsonDecode(utf8.decode(encoded.manifestBytes))
                as Map<String, dynamic>;
        expect(rewritten['schemaVersion'], 2);
        for (final key in old.keys.where(
          (key) => key != 'schemaVersion' && key != 'assets',
        )) {
          expect(rewritten[key], old[key], reason: key);
        }
        for (final key in ['photo', 'aiMask', 'mask', 'thumbnail']) {
          expect(rewritten['assets'][key], old['assets'][key], reason: key);
        }
        final ref = rewritten['assets']['intent'];
        expect(ref['length'], 6);
        expect(
          ref['path'],
          'assets/${sha256.convert(Uint8List(6))}.intent.bin',
        );
        final reopened = codec
            .decode(codec.readManifest(encoded.manifestBytes), encoded.assets)
            .snapshot;
        expect(reopened.photoPng, decoded.photoPng);
        expect(reopened.aiMaskBytes, decoded.aiMaskBytes);
        expect(reopened.maskBytes, decoded.maskBytes);
        expect(reopened.thumbnailPng, decoded.thumbnailPng);
      }
    },
  );

  test(
    'v2 rewrite reopens detached explicit intent including erased and matching AI pixels',
    () {
      final source = Uint8List.fromList([2, 1, 4, 5]);
      final snapshot = roomProjectFixture(revision: 1).copyWith(
        intent: MaskIntentBitmap.fromBytes(width: 2, height: 2, bytes: source),
      );
      final encoded = codec.encode(snapshot);
      source.fillRange(0, 4, 0);
      final decoded = codec
          .decode(codec.readManifest(encoded.manifestBytes), encoded.assets)
          .snapshot;
      expect(decoded.intent.bytes, [2, 1, 4, 5]);
      expect(decoded.aiMaskBytes, [1, 1, 0, 4]);
      expect(decoded.maskBytes, [1, 2, 3, 4]);
      expect(() => decoded.intent.bytes[0] = 0, throwsUnsupportedError);
    },
  );

  test(
    'v2 intent is required and strictly validates reference and core bytes',
    () {
      final encoded = codec.encode(roomProjectFixture(revision: 1));
      Map<String, dynamic> v2() {
        final data =
            jsonDecode(utf8.decode(encoded.manifestBytes))
                as Map<String, dynamic>;
        final zeros = Uint8List(4);
        final hash = sha256.convert(zeros).toString();
        data['schemaVersion'] = 2;
        data['assets']['intent'] = <String, dynamic>{
          'path': 'assets/$hash.intent.bin',
          'length': 4,
          'sha256': hash,
        };
        return data;
      }

      final good = v2();
      final assets = Map<String, Uint8List>.of(encoded.assets)
        ..[good['assets']['intent']['path'] as String] = Uint8List(4);
      final decoded = codec
          .decode(codec.readManifest(bytes(good)), assets)
          .snapshot;
      expect(decoded.intent.bytes, [0, 0, 0, 0]);
      for (final bad in [
        null,
        1,
        <String, dynamic>{},
        {...good['assets']['intent'], 'extra': true},
      ]) {
        final data = v2();
        data['assets']['intent'] = bad;
        expect(() => codec.readManifest(bytes(data)), throwsFormatException);
      }
      final missing = v2();
      missing['assets'].remove('intent');
      expect(() => codec.readManifest(bytes(missing)), throwsFormatException);
      final extra = v2();
      extra['assets']['futureHistory'] = [];
      expect(() => codec.readManifest(bytes(extra)), throwsFormatException);
      for (final key in ['length', 'path', 'sha256']) {
        for (final value
            in key == 'length'
                ? [0, 3, 5, 4.0, '4']
                : key == 'path'
                ? [
                    '../intent.bin',
                    'assets/${'a' * 64}.intent.bin',
                    good['assets']['intent']['path'].replaceAll(
                      '.intent.bin',
                      '.mask',
                    ),
                  ]
                : ['A' * 64, 'a' * 64, null]) {
          final data = v2();
          data['assets']['intent'][key] = value;
          expect(
            () => codec.readManifest(bytes(data)),
            throwsFormatException,
            reason: '$key=$value',
          );
        }
      }
      for (final invalid in [
        null,
        Uint8List(3),
        Uint8List.fromList([1, 0, 0, 0]),
      ]) {
        final changed = Map<String, Uint8List>.of(assets);
        final path = good['assets']['intent']['path'] as String;
        if (invalid == null) {
          changed.remove(path);
        } else {
          changed[path] = invalid;
        }
        expect(
          () => codec.decode(codec.readManifest(bytes(good)), changed),
          throwsFormatException,
        );
      }
      for (final value in [6, 255]) {
        final data = v2();
        final invalid = Uint8List.fromList([value, 0, 0, 0]);
        final hash = sha256.convert(invalid).toString();
        final path = 'assets/$hash.intent.bin';
        data['assets']['intent'] = {'path': path, 'length': 4, 'sha256': hash};
        expect(
          () => codec.decode(codec.readManifest(bytes(data)), {
            ...assets,
            path: invalid,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'v2 writer persists bounded deterministic history as a required asset',
    () {
      final encoded = codec.encode(roomProjectFixture(revision: 1));
      final data = jsonDecode(utf8.decode(encoded.manifestBytes));
      expect(data['assets'].containsKey('history'), isTrue);
      final reference = data['assets']['history'];
      expect(reference['path'], endsWith('.history.bin'));
      expect(reference['length'], 28);
      expect(encoded.assets[reference['path']], [
        84,
        65,
        69,
        72,
        0,
        1,
        0,
        0,
        0,
        0,
        0,
        2,
        0,
        0,
        0,
        2,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
    },
  );

  test(
    'v1 and Task 1 transitional v2 migrate to empty history and new v2 reopens both stacks exactly',
    () async {
      final files = await frozenRoomFiles();
      final source = files['projects/v1-manual/revisions/1/manifest.json']!;
      final old = codec.decode(codec.readManifest(source), {
        for (final entry in files.entries)
          if (entry.key.startsWith('projects/v1-manual/assets/'))
            entry.key.substring('projects/v1-manual/'.length): entry.value,
      }).snapshot;
      expect(old.history.undoStack, isEmpty);
      expect(old.history.redoStack, isEmpty);
      final encoded = codec.encode(maskHistoryProjectFixture());
      final data =
          jsonDecode(utf8.decode(encoded.manifestBytes))
              as Map<String, dynamic>;
      final ref = data['assets']['history'];
      expect(ref['length'], 68);
      expect(
        ref['path'],
        'assets/${sha256.convert(encoded.assets[ref['path']]!)}.history.bin',
      );
      expect(
        codec.encode(maskHistoryProjectFixture()).manifestBytes,
        encoded.manifestBytes,
      );
      final decoded = codec
          .decode(codec.readManifest(encoded.manifestBytes), encoded.assets)
          .snapshot;
      expect(decoded.history.undoStack, hasLength(1));
      expect(decoded.history.redoStack, hasLength(1));
      expect(decoded.history.byteLength, 16);
      final undone = decoded.history.undo(
        masks: MaskBitmap(width: 2, height: 2, labels: decoded.maskBytes),
        intent: decoded.intent,
      );
      expect(undone.result.masks.labels, [1, 2, 3, 4]);
      expect(undone.result.intent.bytes, [0, 0, 0, 0]);
      final redo = decoded.history.redo(
        masks: MaskBitmap(width: 2, height: 2, labels: decoded.maskBytes),
        intent: decoded.intent,
      );
      expect(redo.result.masks.labels, [4, 0, 3, 4]);
      expect(redo.result.intent.bytes, [5, 1, 0, 0]);
      data['assets'].remove('history');
      final transitional = codec
          .decode(codec.readManifest(bytes(data)), encoded.assets)
          .snapshot;
      expect(transitional.history.undoStack, isEmpty);
      expect(transitional.history.redoStack, isEmpty);
      expect(transitional.maskBytes, [4, 2, 3, 4]);
      expect(transitional.intent.bytes, [5, 0, 0, 0]);
      final rewritten = jsonDecode(
        utf8.decode(codec.encode(transitional).manifestBytes),
      );
      expect(rewritten['assets'].containsKey('history'), isTrue);
      final v1 = jsonDecode(utf8.decode(source)) as Map<String, dynamic>;
      v1['assets']['history'] = ref;
      expect(() => codec.readManifest(bytes(v1)), throwsFormatException);
    },
  );

  test(
    'history binary fails closed on magic, version, bounds, deltas, ordering, truncation and trailing bytes',
    () {
      final encoded = codec.encode(maskHistoryProjectFixture());
      final original =
          jsonDecode(utf8.decode(encoded.manifestBytes))
              as Map<String, dynamic>;
      final valid = encoded.assets[original['assets']['history']['path']]!;
      final cases = <Uint8List>[];
      void mutate(void Function(Uint8List, ByteData) change) {
        final copy = Uint8List.fromList(valid);
        change(copy, ByteData.sublistView(copy));
        cases.add(copy);
      }

      mutate((b, d) => b[0] = 0);
      mutate((b, d) => d.setUint16(4, 2));
      mutate((b, d) => d.setUint16(6, 1));
      mutate((b, d) => d.setUint32(8, 1));
      mutate((b, d) => d.setUint32(16, 21));
      mutate((b, d) => d.setUint32(24, 16777224));
      mutate((b, d) => d.setUint32(28, 1));
      mutate((b, d) => d.setUint32(36, 0));
      mutate((b, d) => d.setUint32(36, 0xffffffff));
      mutate((b, d) => d.setUint32(40, 4));
      mutate((b, d) => b[44] = 5);
      mutate((b, d) => b[45] = 255);
      mutate((b, d) => b[46] = 6);
      mutate((b, d) => b[47] = 255);
      mutate((b, d) {
        b[44] = b[45];
        b[46] = b[47];
      });
      mutate((b, d) {
        d.setUint32(16, 2);
        d.setUint32(20, 0);
      });
      mutate((b, d) {
        d.setUint32(16, 0);
        d.setUint32(20, 2);
      });
      cases.add(Uint8List.fromList(valid.sublist(0, valid.length - 1)));
      cases.add(Uint8List.fromList([...valid, 0]));
      cases.add(Uint8List(0));
      cases.add(Uint8List(27));
      for (var i = 0; i < cases.length; i++) {
        final data =
            jsonDecode(utf8.decode(encoded.manifestBytes))
                as Map<String, dynamic>;
        final bad = cases[i];
        final hash = sha256.convert(bad).toString();
        final path = 'assets/$hash.history.bin';
        data['assets']['history'] = <String, dynamic>{
          'path': path,
          'length': bad.length,
          'sha256': hash,
        };
        expect(
          () => codec.decode(codec.readManifest(bytes(data)), {
            ...encoded.assets,
            path: bad,
          }),
          throwsFormatException,
          reason: 'binary case $i',
        );
      }
    },
  );

  test(
    'history references verify exact path, digest, bounded length and data presence',
    () {
      final encoded = codec.encode(maskHistoryProjectFixture());
      Map<String, dynamic> data() =>
          jsonDecode(utf8.decode(encoded.manifestBytes))
              as Map<String, dynamic>;
      for (final bad in [
        null,
        1,
        <String, dynamic>{},
        <String, dynamic>{...data()['assets']['history'], 'extra': true},
      ]) {
        final changed = data();
        changed['assets']['history'] = bad;
        expect(() => codec.readManifest(bytes(changed)), throwsFormatException);
      }
      for (final entry in <(String, Object?)>[
        ('length', 0),
        ('length', 27),
        ('length', 16777485),
        ('length', 68.0),
        ('path', '../history.bin'),
        ('path', 'assets/${'a' * 64}.history.bin'),
        ('sha256', 'A' * 64),
      ]) {
        final changed = data();
        changed['assets']['history'][entry.$1] = entry.$2;
        expect(() => codec.readManifest(bytes(changed)), throwsFormatException);
      }
      final parsed = codec.readManifest(encoded.manifestBytes);
      final path = data()['assets']['history']['path'] as String;
      expect(
        () => codec.decode(
          parsed,
          Map<String, Uint8List>.of(encoded.assets)..remove(path),
        ),
        throwsFormatException,
      );
      expect(
        () => codec.decode(parsed, {...encoded.assets, path: Uint8List(68)}),
        throwsFormatException,
      );
    },
  );

  test(
    'binary decode rejects unsorted and duplicate indices in a multi-pixel record',
    () {
      final valid = Uint8List(56);
      valid.setRange(0, 4, [84, 65, 69, 72]);
      final data = ByteData.sublistView(valid);
      data.setUint16(4, 1);
      data.setUint32(8, 2);
      data.setUint32(12, 2);
      data.setUint32(16, 1);
      data.setUint32(24, 16);
      data.setUint32(28, 2);
      data.setUint32(32, 2);
      data.setUint32(36, 2);
      data.setUint32(40, 0);
      data.setUint32(44, 2);
      valid.setRange(48, 56, [1, 3, 4, 2, 0, 0, 5, 3]);
      expect(
        MaskEditHistoryCodec.decode(
          valid,
          width: 2,
          height: 2,
        ).undoStack.single.indices,
        [0, 2],
      );
      for (final indices in [
        [2, 0],
        [0, 0],
      ]) {
        final bad = Uint8List.fromList(valid);
        final view = ByteData.sublistView(bad);
        view.setUint32(40, indices[0]);
        view.setUint32(44, indices[1]);
        expect(
          () => MaskEditHistoryCodec.decode(bad, width: 2, height: 2),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'v2 roundtrip uses canonical UTC/HEX and immutable asset references',
    () {
      final encoded = codec.encode(roomProjectFixture(revision: 1));
      final data = jsonDecode(utf8.decode(encoded.manifestBytes));
      expect(data['schemaVersion'], 2);
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

  test('missing/unknown required data and future schemas fail closed', () {
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
    for (final version in [0, 3, '1', 1.0, '2', 2.0]) {
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
