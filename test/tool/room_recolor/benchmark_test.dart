import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../../../tool/room_recolor/benchmark.dart';
import '../../../tool/verify_room_recolor_benchmark.dart' as verifier;

// Synthetic corpus exists ONLY in OS temp directories. Hash helpers encode test
// inputs; acceptance expectations (24, category counts, bytes) are literal.
class Corpus {
  Corpus()
    : root = Directory.systemTemp.createTempSync('room-benchmark-test.') {
    File(
      'test/fixtures/room_recolor/v1/protocol.json',
    ).copySync('${root.path}/protocol.json');
    for (var i = 0; i < 24; i++) {
      final id = 'photo-$i';
      final dir = Directory('${root.path}/photos/$id')
        ..createSync(recursive: true);
      final decoded = image.Image(width: 3, height: 2, numChannels: 4);
      for (final pixel in decoded) {
        pixel.setRgba(i * 10, 20, 30, 255);
      }
      final png = image.encodePng(decoded);
      final source = put('photos/$id/source.png', png);
      final working = put('photos/$id/working.png', png);
      final license = put(
        'licenses/$id.txt',
        utf8.encode('TEST ONLY: public domain synthetic input.'),
      );
      final annotations = <String, dynamic>{};
      for (final role in ['annotator-a', 'annotator-b', 'adjudicated']) {
        annotations[role] = {
          'width': 3,
          'height': 2,
          'ownership': put('photos/$id/annotations/$role.ownership.bin', [
            0,
            1,
            2,
            3,
            4,
            0,
          ]),
          'protection': put('photos/$id/annotations/$role.protection.bin', [
            255,
            0,
            0,
            0,
            0,
            0,
          ]),
        };
      }
      final evidence = {
        'origin': 'human-independent',
        'annotators': [
          for (final role in ['annotator-a', 'annotator-b'])
            {
              'role': role,
              'identity': 'test-$role',
              'blind': true,
              'submittedAt': '2026-10-20T10:00:00Z',
              'submissionSha256': hash([0, 1, 2, 3, 4, 0, 255, 0, 0, 0, 0, 0]),
            },
        ],
        'adjudicator': 'test-adjudicator',
        'adjudicatedAt': '2026-10-21T10:00:00Z',
        'disputes': <dynamic>[],
      };
      annotations['adjudication'] = put(
        'photos/$id/annotations/adjudication.json',
        utf8.encode(jsonEncode(evidence)),
      );
      photos.add({
        'id': id,
        'category': [
          'living-room',
          'bedroom',
          'kitchen-dining',
          'other-indoor',
        ][i ~/ 6],
        'tags': [
          'people',
          'windows',
          'doors',
          'wall-decoration',
          'furniture-touching-walls',
          'low-contrast',
          'patterned',
          'daylight',
          'artificial-light',
          'shadows',
          'reflections',
        ],
        'provenance': {
          'sourceUrl': 'https://example.test/$id',
          'sourceRevision': 'revision-$i',
          'creator': 'Test generator',
          'title': 'Synthetic $id',
          'licenseId': 'CC0-1.0',
          'licenseVersion': '1.0',
          'licenseUrl': 'https://creativecommons.org/publicdomain/zero/1.0/',
          'redistributionPermitted': true,
          'acquiredAt': '2026-10-20T00:00:00Z',
          'licenseText': license,
        },
        'source': {...source, 'width': 3, 'height': 2},
        'working': {
          ...working,
          'width': 3,
          'height': 2,
          'decodedRgbaSha256': hash(
            decoded.getBytes(order: image.ChannelOrder.rgba),
          ),
        },
        'decodedRgbaSha256': hash(
          decoded.getBytes(order: image.ChannelOrder.rgba),
        ),
        'annotations': annotations,
      });
      expect(dir.existsSync(), isTrue);
    }
    save();
  }
  final Directory root;
  final photos = <Map<String, dynamic>>[];
  static String hash(List<int> bytes) => sha256.convert(bytes).toString();
  Map<String, dynamic> put(String path, List<int> bytes) {
    final file = File('${root.path}/$path')..parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    return {'path': path, 'sha256': hash(bytes)};
  }

  void save() => File(
    '${root.path}/manifest.json',
  ).writeAsStringSync(jsonEncode({'version': 1, 'photos': photos}));
  void editEvidence(void Function(Map<String, dynamic>) edit) {
    final annotations = photos.first['annotations'] as Map;
    final ref = annotations['adjudication'] as Map;
    final evidence =
        (jsonDecode(File('${root.path}/${ref['path']}').readAsStringSync())
                as Map)
            .cast<String, dynamic>();
    edit(evidence);
    annotations['adjudication'] = put(
      ref['path'] as String,
      utf8.encode(jsonEncode(evidence)),
    );
    save();
  }

  void replaceMap(String role, String kind, List<int> bytes) {
    final annotation = photos.first['annotations'][role] as Map;
    annotation[kind] = put(annotation[kind]['path'] as String, bytes);
    save();
  }

  RoomRecolorBenchmark load({bool adjudicated = true}) {
    save();
    return loadRoomRecolorBenchmark(
      root,
      requireAdjudicatedAnnotations: adjudicated,
    );
  }
}

void main() {
  late Corpus corpus;
  setUp(() => corpus = Corpus());
  tearDown(() => corpus.root.deleteSync(recursive: true));

  test(
    'accepts exactly 24 distinct decoded photos in six of each category',
    () {
      final valid = corpus.load();
      expect(valid.photos.length, 24);
      expect(valid.photos.map((p) => p.decodedRgbaSha256).toSet().length, 24);
      expect(valid.photos.where((p) => p.category == 'living-room').length, 6);
      expect(valid.photos.first.ownership!.labels, [0, 1, 2, 3, 4, 0]);
      expect(valid.photos.first.protection, [255, 0, 0, 0, 0, 0]);
      expect(() => valid.photos.clear(), throwsUnsupportedError);
      expect(
        () => valid.photos.first.protection![0] = 0,
        throwsUnsupportedError,
      );
      corpus.replaceMap('adjudicated', 'protection', [0, 0, 0, 0, 0, 0]);
      expect(
        valid.photos.first.protection![0],
        255,
      ); // detached after disk mutation
    },
  );

  for (final count in [23, 25]) {
    test('rejects $count photos', () {
      if (count == 23) {
        corpus.photos.removeLast();
      } else {
        corpus.photos.add(Map.from(corpus.photos.last)..['id'] = 'extra');
      }
      expect(corpus.load, throwsFormatException);
    });
  }
  test('rejects unbalanced categories even with 24 photos', () {
    corpus.photos.first['category'] = 'bedroom';
    expect(corpus.load, throwsFormatException);
  });
  test('rejects duplicate IDs', () {
    corpus.photos[1]['id'] = corpus.photos.first['id'];
    expect(corpus.load, throwsFormatException);
  });
  test('rejects duplicate decoded photo under a different encoded format', () {
    final first = corpus.photos.first;
    final second = corpus.photos[1];
    final decoded = image.decodePng(
      File('${corpus.root.path}/${first['source']['path']}').readAsBytesSync(),
    )!;
    second['source'] = {
      ...corpus.put('photos/photo-1/source.bmp', image.encodeBmp(decoded)),
      'width': 3,
      'height': 2,
    };
    second['decodedRgbaSha256'] = first['decodedRgbaSha256'];
    expect(corpus.load, throwsFormatException);
  });

  for (final field in [
    'sourceUrl',
    'sourceRevision',
    'creator',
    'title',
    'licenseId',
    'licenseVersion',
    'licenseUrl',
    'acquiredAt',
    'licenseText',
  ]) {
    test('requires provenance $field', () {
      (corpus.photos.first['provenance'] as Map).remove(field);
      expect(corpus.load, throwsFormatException);
    });
  }
  test('rejects licenses without explicit redistribution permission', () {
    corpus.photos.first['provenance']['redistributionPermitted'] = false;
    expect(corpus.load, throwsFormatException);
  });
  for (final kind in ['source', 'working']) {
    test('checks $kind encoded hash', () {
      corpus.photos.first[kind]['sha256'] = '0' * 64;
      expect(corpus.load, throwsFormatException);
    });
  }
  test('checks source decoded hash', () {
    corpus.photos.first['decodedRgbaSha256'] = '0' * 64;
    expect(corpus.load, throwsFormatException);
  });
  test('checks working decoded hash', () {
    corpus.photos.first['working']['decodedRgbaSha256'] = '0' * 64;
    expect(corpus.load, throwsFormatException);
  });
  test('checks license text bytes', () {
    File(
      '${corpus.root.path}/licenses/photo-0.txt',
    ).writeAsStringSync('changed');
    expect(corpus.load, throwsFormatException);
  });
  test(
    'requires every scene, lighting and protection tag across the corpus',
    () {
      for (final photo in corpus.photos) {
        (photo['tags'] as List).remove('reflections');
      }
      expect(corpus.load, throwsFormatException);
    },
  );
  test('rejects unknown tags', () {
    corpus.photos.first['tags'] = ['unreviewed-tag'];
    expect(corpus.load, throwsFormatException);
  });
  test('rejects missing or changed frozen protocol', () {
    final protocol = File('${corpus.root.path}/protocol.json');
    final data = jsonDecode(protocol.readAsStringSync()) as Map;
    data['boundaryTolerancePixels'] = 6;
    protocol.writeAsStringSync(jsonEncode(data));
    expect(corpus.load, throwsFormatException);
    protocol.deleteSync();
    expect(corpus.load, throwsFormatException);
  });
  test('rejects traversal and symlinks outside corpus', () {
    corpus.photos.first['working']['path'] = '../outside.png';
    expect(corpus.load, throwsFormatException);
    corpus.photos.first['working']['path'] = 'escape.png';
    Link('${corpus.root.path}/escape.png').createSync('/etc/hosts');
    expect(corpus.load, throwsFormatException);
  });
  test('rejects image dimensions inconsistent with bytes', () {
    corpus.photos.first['working']['width'] = 2;
    expect(corpus.load, throwsFormatException);
  });

  for (final (kind, maxBytes) in [
    ('source', 24 * 1024 * 1024),
    ('working', 32 * 1024 * 1024),
  ]) {
    // Catches reading or hashing the payload before enforcing its file size.
    // A sparse unreadable file needs no large allocation to prove the order.
    test('rejects oversized $kind file before trying to read its payload', () {
      final ref = corpus.photos.first[kind] as Map;
      final path = '${corpus.root.path}/${ref['path']}';
      final file = File(path).openSync(mode: FileMode.write);
      try {
        file.truncateSync(maxBytes + 1);
      } finally {
        file.closeSync();
      }
      expect(Process.runSync('/bin/chmod', ['000', path]).exitCode, 0);
      addTearDown(() => Process.runSync('/bin/chmod', ['600', path]));
      expect(
        corpus.load,
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'reason',
            contains('exceeds byte limit'),
          ),
        ),
      );
    });
  }

  for (final (kind, width, height) in [
    ('source', 16385, 1),
    ('source', 6000, 4001),
    ('working', 1601, 1),
  ]) {
    // The tiny header has no pixel payload. A full BMP decode would fail as
    // truncated; accepting manifest dimensions would miss the budget reason.
    test(
      'preflights $kind encoded dimensions $width x $height despite small manifest',
      () {
        final header = ByteData(54)
          ..setUint16(0, 0x4d42, Endian.little)
          ..setUint32(2, 54, Endian.little)
          ..setUint32(10, 54, Endian.little)
          ..setUint32(14, 40, Endian.little)
          ..setInt32(18, width, Endian.little)
          ..setInt32(22, height, Endian.little)
          ..setUint16(26, 1, Endian.little)
          ..setUint16(28, 24, Endian.little);
        final old = corpus.photos.first[kind] as Map;
        corpus.photos.first[kind] = {
          ...old,
          ...corpus.put(
            'photos/photo-0/$kind.bmp',
            header.buffer.asUint8List(),
          ),
        };
        expect(
          corpus.load,
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'reason',
              contains('encoded dimensions exceed limits'),
            ),
          ),
        );
      },
    );
  }

  test('rejects an animated photo before decoding any frame', () {
    final ref = corpus.photos.first['source'] as Map;
    final animation = image.decodePng(
      File('${corpus.root.path}/${ref['path']}').readAsBytesSync(),
    )!;
    animation.addFrame(image.Image.from(animation));
    corpus.photos.first['source'] = {
      ...ref,
      ...corpus.put(ref['path'] as String, image.encodePng(animation)),
    };
    expect(
      corpus.load,
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'reason',
          contains('single still image'),
        ),
      ),
    );
  });

  // Preserve valid still-photo compatibility while hardening decoder selection.
  // An unrelated extension ensures detection depends on bytes rather than name.
  for (final (format, encode) in <(String, Uint8List Function(image.Image))>[
    ('JPEG', (photo) => image.encodeJpg(photo)),
    ('PNG', (photo) => image.encodePng(photo)),
    ('GIF', (photo) => image.encodeGif(photo)),
    ('WebP', (photo) => image.encodeWebP(photo)),
    ('BMP', (photo) => image.encodeBmp(photo)),
    ('TIFF', (photo) => image.encodeTiff(photo)),
  ]) {
    test(
      'accepts a bounded $format still from its signature with unrelated extension',
      () {
        final source = corpus.photos.first['source'] as Map;
        final photo = image.decodePng(
          File('${corpus.root.path}/${source['path']}').readAsBytesSync(),
        )!;
        final encoded = encode(photo);
        corpus.photos.first['source'] = {
          ...corpus.put('photos/photo-0/source.data', encoded),
          'width': 3,
          'height': 2,
        };
        corpus.photos.first['decodedRgbaSha256'] = Corpus.hash(
          image.decodeImage(encoded)!.getBytes(order: image.ChannelOrder.rgba),
        );
        expect(corpus.load().photos.first.sourceBytes, encoded);
      },
    );
  }

  test(
    'rejects TIFF embedded JPEG whose nested decoder has no local pixel budget',
    () {
      final source = corpus.photos.first['source'] as Map;
      final photo = image.decodePng(
        File('${corpus.root.path}/${source['path']}').readAsBytesSync(),
      )!;
      final encoded = image.encodeTiff(photo);
      final data = ByteData.sublistView(encoded);
      final endian = encoded[0] == 73 ? Endian.little : Endian.big;
      final ifd = data.getUint32(4, endian);
      final entries = data.getUint16(ifd, endian);
      var changed = false;
      for (var i = 0; i < entries; i++) {
        final offset = ifd + 2 + i * 12;
        if (data.getUint16(offset, endian) == 259) {
          data.setUint16(offset + 8, 7, endian); // TIFF JPEG compression.
          changed = true;
          break;
        }
      }
      expect(changed, isTrue);
      corpus.photos.first['source'] = {
        ...corpus.put('photos/photo-0/source.tiff', encoded),
        'width': 3,
        'height': 2,
      };
      expect(
        corpus.load,
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'reason',
            contains('unsupported embedded JPEG'),
          ),
        ),
      );
    },
  );

  for (final role in [
    'annotator-a',
    'annotator-b',
    'adjudicated',
    'adjudication',
  ]) {
    test('requires detached $role evidence, not just a JSON claim', () {
      (corpus.photos.first['annotations'] as Map).remove(role);
      expect(corpus.load, throwsFormatException);
    });
  }
  test(
    'allows acquisition-only loading without annotations when explicitly requested',
    () {
      for (final photo in corpus.photos) {
        photo.remove('annotations');
      }
      expect(corpus.load, throwsFormatException);
      expect(corpus.load(adjudicated: false).photos.first.ownership, isNull);
    },
  );
  test('optional annotation mode still rejects partial evidence', () {
    (corpus.photos.first['annotations'] as Map).remove('annotator-a');
    expect(() => corpus.load(adjudicated: false), throwsFormatException);
  });
  for (final role in ['annotator-a', 'annotator-b', 'adjudicated']) {
    test('rejects malformed $role ownership length or label', () {
      corpus.replaceMap(role, 'ownership', [0, 1]);
      expect(corpus.load, throwsFormatException);
      corpus.replaceMap(role, 'ownership', [0, 1, 2, 3, 5, 0]);
      expect(corpus.load, throwsFormatException);
    });
    test('rejects malformed $role protection bytes', () {
      corpus.replaceMap(role, 'protection', [255]);
      expect(corpus.load, throwsFormatException);
      corpus.replaceMap(role, 'protection', [1, 0, 0, 0, 0, 0]);
      expect(corpus.load, throwsFormatException);
    });
  }
  test('rejects annotation hash and dimension mismatches', () {
    corpus.photos.first['annotations']['annotator-a']['width'] = 2;
    expect(corpus.load, throwsFormatException);
    corpus.photos.first['annotations']['annotator-a']['width'] = 3;
    corpus.photos.first['annotations']['annotator-a']['ownership']['sha256'] =
        '0' * 64;
    expect(corpus.load, throwsFormatException);
  });
  test('rejects no protected ground truth per image', () {
    for (final role in ['annotator-a', 'annotator-b', 'adjudicated']) {
      corpus.replaceMap(role, 'protection', [0, 0, 0, 0, 0, 0]);
    }
    corpus.editEvidence((e) {
      for (final submission in e['annotators'] as List) {
        submission['submissionSha256'] = Corpus.hash([
          0,
          1,
          2,
          3,
          4,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
        ]);
      }
    });
    expect(
      corpus.load,
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'reason',
          contains('protected ground truth'),
        ),
      ),
    );
  });
  test('rejects model predictions declared as ground truth', () {
    corpus.editEvidence((e) => e['origin'] = 'model-prediction');
    expect(corpus.load, throwsFormatException);
  });
  test('rejects nonblind or same-identity submissions', () {
    corpus.editEvidence((e) => e['annotators'][0]['blind'] = false);
    expect(corpus.load, throwsFormatException);
    corpus.editEvidence((e) {
      e['annotators'][0]['blind'] = true;
      e['annotators'][1]['identity'] = e['annotators'][0]['identity'];
    });
    expect(corpus.load, throwsFormatException);
  });
  test(
    'rejects mismatched submission hash and adjudication preceding submission',
    () {
      corpus.editEvidence(
        (e) => e['annotators'][0]['submissionSha256'] = '0' * 64,
      );
      expect(corpus.load, throwsFormatException);
      corpus.editEvidence((e) {
        e['annotators'][0]['submissionSha256'] = Corpus.hash([
          0,
          1,
          2,
          3,
          4,
          0,
          255,
          0,
          0,
          0,
          0,
          0,
        ]);
        e['adjudicatedAt'] = '2026-10-19T10:00:00Z';
      });
      expect(corpus.load, throwsFormatException);
    },
  );
  test(
    'requires disputed-region decision and forbids unexplained adjudicated edits',
    () {
      corpus.replaceMap('annotator-b', 'ownership', [0, 4, 2, 3, 4, 0]);
      corpus.editEvidence(
        (e) => e['annotators'][1]['submissionSha256'] = Corpus.hash([
          0,
          4,
          2,
          3,
          4,
          0,
          255,
          0,
          0,
          0,
          0,
          0,
        ]),
      );
      expect(corpus.load, throwsFormatException);
      corpus.editEvidence(
        (e) => e['disputes'] = [
          {
            'pixels': [1],
            'decision': 'Working image confirms wall.',
            'ownershipLabel': 1,
            'protectionValue': 0,
          },
        ],
      );
      expect(corpus.load().photos.length, 24);
      corpus.replaceMap('adjudicated', 'ownership', [0, 1, 2, 4, 4, 0]);
      expect(corpus.load, throwsFormatException);
    },
  );

  test(
    'verifier accepts controlled complete corpus and reports exactly 24 photos',
    () {
      final output = StringBuffer();
      final errors = StringBuffer();
      expect(
        verifier.verifyRoomRecolorBenchmark(
          ['--root', corpus.root.path, '--require-adjudicated'],
          out: output,
          err: errors,
        ),
        0,
      );
      expect(jsonDecode(output.toString())['acceptedDistinctPhotos'], 24);
      expect(errors.toString(), isEmpty);
    },
  );
  test(
    'verifier returns failure for absent corpus and rejects unknown options',
    () {
      final errors = StringBuffer();
      expect(
        verifier.verifyRoomRecolorBenchmark(
          ['--root', '${corpus.root.path}/absent', '--require-adjudicated'],
          out: StringBuffer(),
          err: errors,
        ),
        1,
      );
      expect(errors.toString(), contains('FAILED'));
      expect(
        verifier.verifyRoomRecolorBenchmark(
          ['--unknown'],
          out: StringBuffer(),
          err: StringBuffer(),
        ),
        64,
      );
      expect(
        verifier.verifyRoomRecolorBenchmark(
          ['--root'],
          out: StringBuffer(),
          err: StringBuffer(),
        ),
        64,
      );
    },
  );
}
