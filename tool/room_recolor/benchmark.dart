import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;

/// Exact bytes of protocol v1. Editing the fixture cannot silently change the
/// rules used to accept a corpus; a future protocol needs an explicit version.
const roomRecolorProtocolSha256 =
    '9bb3b0f379054af42598deebb4cc8a90e1a3e3a3a5cb5821c9587fc1281c31fb';
const _categories = [
  'living-room',
  'bedroom',
  'kitchen-dining',
  'other-indoor',
];
const _tags = [
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
];
const _roles = ['annotator-a', 'annotator-b', 'adjudicated'];

final class RoomBenchmarkPhoto {
  RoomBenchmarkPhoto._({
    required this.id,
    required this.category,
    required List<String> tags,
    required this.decodedRgbaSha256,
    required this.width,
    required this.height,
    required Uint8List sourceBytes,
    required Uint8List workingBytes,
    required this.ownership,
    required Uint8List? protection,
  }) : tags = List.unmodifiable(tags),
       sourceBytes = _detached(sourceBytes),
       workingBytes = _detached(workingBytes),
       protection = protection == null ? null : _detached(protection);
  final String id;
  final String category;
  final List<String> tags;

  /// Oriented source RGBA identity, not compressed file identity.
  final String decodedRgbaSha256;
  final int width;
  final int height;
  final Uint8List sourceBytes;
  final Uint8List workingBytes;
  final MaskBitmap? ownership;
  final Uint8List? protection;
}

final class RoomRecolorBenchmark {
  RoomRecolorBenchmark._(
    List<RoomBenchmarkPhoto> photos,
    this.manifestSha256,
    this.hasAdjudicatedAnnotations,
  ) : photos = List.unmodifiable(photos);
  final List<RoomBenchmarkPhoto> photos;
  final String manifestSha256;
  final bool hasAdjudicatedAnnotations;
  String get protocolSha256 => roomRecolorProtocolSha256;
}

RoomRecolorBenchmark loadRoomRecolorBenchmark(
  Directory root, {
  required bool requireAdjudicatedAnnotations,
}) {
  try {
    return _CorpusReader(root).load(requireAdjudicatedAnnotations);
  } on FileSystemException catch (error) {
    throw FormatException(
      'Missing or unreadable benchmark evidence: ${error.path}',
    );
  }
}

final class _CorpusReader {
  _CorpusReader(Directory root) : root = root.resolveSymbolicLinksSync();
  final String root;

  RoomRecolorBenchmark load(bool requireAnnotations) {
    final protocol = read('protocol.json');
    _require(
      _hash(protocol) == roomRecolorProtocolSha256,
      'Frozen protocol v1 checksum mismatch',
    );
    final manifestBytes = read('manifest.json');
    final manifest = _json(manifestBytes, 'manifest');
    _require(manifest['version'] == 1, 'Manifest version must be 1');
    final records = _list(manifest['photos'], 'photos');
    _require(records.length == 24, 'Exactly 24 photos required');
    final photos = <RoomBenchmarkPhoto>[];
    final ids = <String>{};
    final decodedHashes = <String>{};
    final allTags = <String>{};
    final allLayers = <int>{};
    for (final value in records) {
      final record = _map(value, 'photo');
      final id = _text(record['id'], 'photo id');
      _require(
        RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]*$').hasMatch(id) && ids.add(id),
        'Invalid or duplicate photo ID',
      );
      final category = _text(record['category'], '$id category');
      _require(_categories.contains(category), '$id unknown category');
      final tags = _list(
        record['tags'],
        '$id tags',
      ).map((v) => _text(v, 'tag')).toList();
      _require(
        tags.isNotEmpty &&
            tags.toSet().length == tags.length &&
            tags.every(_tags.contains),
        '$id invalid tags',
      );
      allTags.addAll(tags);
      final provenance = _map(record['provenance'], '$id provenance');
      for (final field in [
        'sourceRevision',
        'creator',
        'title',
        'licenseId',
        'licenseVersion',
      ]) {
        _text(provenance[field], '$id $field');
      }
      _url(provenance['sourceUrl'], '$id source URL');
      _url(provenance['licenseUrl'], '$id license URL');
      _time(provenance['acquiredAt'], '$id acquisition time');
      _require(
        provenance['redistributionPermitted'] == true,
        '$id redistribution permission required',
      );
      final license = checkedBytes(provenance['licenseText'], '$id license');
      _require(
        utf8.decode(license).trim().isNotEmpty,
        '$id license text empty',
      );
      final sourceRef = _map(record['source'], '$id source');
      final workingRef = _map(record['working'], '$id working');
      final sourceBytes = checkedBytes(
        sourceRef,
        '$id source',
        maxBytes: 24 * 1024 * 1024,
      );
      final workingBytes = checkedBytes(
        workingRef,
        '$id working',
        maxBytes: 32 * 1024 * 1024,
      );
      final source = decode(
        sourceBytes,
        sourceRef,
        '$id source',
        working: false,
      );
      final working = decode(
        workingBytes,
        workingRef,
        '$id working',
        working: true,
      );
      final decodedHash = _hash(
        source.getBytes(order: image.ChannelOrder.rgba),
      );
      _require(
        decodedHash ==
            _digest(record['decodedRgbaSha256'], '$id decoded source'),
        '$id decoded source checksum mismatch',
      );
      _require(
        decodedHashes.add(decodedHash),
        '$id duplicates an already decoded source photo',
      );
      _require(
        _hash(working.getBytes(order: image.ChannelOrder.rgba)) ==
            _digest(workingRef['decodedRgbaSha256'], '$id decoded working'),
        '$id decoded working checksum mismatch',
      );
      MaskBitmap? ownership;
      Uint8List? protection;
      if (record['annotations'] != null) {
        final result = annotations(
          id,
          record['annotations'],
          working.width,
          working.height,
        );
        ownership = result.$1;
        protection = result.$2;
        _require(
          protection.contains(255),
          '$id must contain protected ground truth',
        );
        allLayers.addAll(ownership.labels.where((label) => label != 0));
      } else {
        _require(
          !requireAnnotations,
          '$id missing independent/adjudicated annotation evidence',
        );
      }
      photos.add(
        RoomBenchmarkPhoto._(
          id: id,
          category: category,
          tags: tags,
          decodedRgbaSha256: decodedHash,
          width: working.width,
          height: working.height,
          sourceBytes: sourceBytes,
          workingBytes: workingBytes,
          ownership: ownership,
          protection: protection,
        ),
      );
    }
    for (final category in _categories) {
      _require(
        photos.where((p) => p.category == category).length == 6,
        'Exactly six $category photos required',
      );
    }
    _require(
      allTags.containsAll(_tags),
      'Corpus missing required scene/lighting/protection tags',
    );
    final complete = photos.every((p) => p.ownership != null);
    if (complete) {
      _require(
        allLayers.containsAll([1, 2, 3, 4]),
        'Corpus must contain all four ground-truth layers',
      );
    }
    return RoomRecolorBenchmark._(photos, _hash(manifestBytes), complete);
  }

  Uint8List read(String path, {int? maxBytes, String? context}) {
    _require(
      path.isNotEmpty &&
          !path.startsWith('/') &&
          !path.contains('\\') &&
          path.split('/').every((p) => p.isNotEmpty && p != '.' && p != '..'),
      'Unsafe benchmark path',
    );
    final file = File('$root/$path');
    final resolved = file.resolveSymbolicLinksSync();
    _require(resolved.startsWith('$root/'), 'Benchmark path escapes root');
    if (maxBytes == null) return file.readAsBytesSync();
    // Stat before opening/reading. Then check the opened descriptor too: the
    // path can be replaced or the file can grow between stat and open.
    final size = file.lengthSync();
    _require(size <= maxBytes, '$context exceeds byte limit');
    final handle = File(resolved).openSync();
    try {
      final openedSize = handle.lengthSync();
      _require(openedSize <= maxBytes, '$context exceeds byte limit');
      _require(openedSize == size, '$context size changed before read');
      final bytes = Uint8List(size);
      var offset = 0;
      while (offset < size) {
        final count = handle.readIntoSync(bytes, offset, size);
        _require(count > 0, '$context truncated during read');
        offset += count;
      }
      // Never read an unbounded stream after stat. At most one sentinel byte
      // beyond the fixed-size buffer detects growth; length catches truncation.
      _require(
        handle.readByteSync() == -1 && handle.lengthSync() == size,
        '$context size changed during read',
      );
      return bytes;
    } finally {
      handle.closeSync();
    }
  }

  Uint8List checkedBytes(
    Object? value,
    String context, {
    String? requiredPath,
    int? maxBytes,
  }) {
    final ref = _map(value, context);
    final path = _text(ref['path'], '$context path');
    _require(
      requiredPath == null || path == requiredPath,
      '$context must be detached at $requiredPath',
    );
    final bytes = read(path, maxBytes: maxBytes, context: context);
    _require(
      _hash(bytes) == _digest(ref['sha256'], '$context checksum'),
      '$context checksum mismatch',
    );
    return bytes;
  }

  image.Image decode(
    Uint8List bytes,
    Map<String, dynamic> ref,
    String context, {
    required bool working,
  }) {
    _require(
      bytes.length <= (working ? 32 : 24) * 1024 * 1024,
      '$context exceeds byte limit',
    );
    final width = _positive(ref['width'], '$context width');
    final height = _positive(ref['height'], '$context height');
    _require(
      width <= 16384 && height <= 16384 && width * height <= 24000000,
      '$context dimensions exceed limits',
    );
    if (working) {
      _require(
        width <= 1600 && height <= 1600,
        '$context exceeds working long edge',
      );
    }
    final image.Image? decoded;
    try {
      // Only the six formats supported by photo preparation have an inspected
      // header-only path here. In particular EXR startDecode decodes pixels.
      // Identify by bytes, never the path extension or a manifest claim.
      final decoder = _photoDecoder(bytes, context);
      final info = decoder.startDecode(bytes);
      _require(info != null, '$context invalid encoded image header');
      _encodedDimensions(info!.width, info.height, context, working: working);
      _require(
        (info.numFrames == 1 || info is image.WebPInfo && !info.hasAnimation) &&
            !(info is image.PngInfo && info.isAnimated) &&
            !(info is image.WebPInfo && info.hasAnimation),
        '$context requires a single still image',
      );
      if (info is image.GifInfo) {
        final frame = info.frames.single;
        _encodedDimensions(
          frame.width,
          frame.height,
          context,
          working: working,
        );
        _require(
          frame.x >= 0 &&
              frame.y >= 0 &&
              frame.x + frame.width <= info.width &&
              frame.y + frame.height <= info.height,
          '$context frame exceeds canvas',
        );
      }
      if (info is image.TiffInfo) {
        final frame = info.images.single;
        _encodedDimensions(
          frame.tileWidth,
          frame.tileHeight,
          context,
          working: false,
        );
        // image 4.12 decodes JPEG-compressed TIFF tiles with JpegDecoder()
        // rather than the TIFF's local budget. Do not enter that nested path.
        _require(
          frame.compression != 6 && frame.compression != 7,
          '$context unsupported embedded JPEG in TIFF',
        );
      }
      decoded = decoder.decodeFrame(0);
    } on image.ImageException catch (error) {
      final budget =
          error.message.contains('exceed') && error.message.contains('pixel');
      throw FormatException(
        budget
            ? '$context encoded dimensions exceed limits'
            : '$context invalid encoded image: ${error.message}',
      );
    }
    _require(decoded != null, '$context cannot be decoded');
    _encodedDimensions(
      decoded!.width,
      decoded.height,
      context,
      working: working,
    );
    final oriented = image.bakeOrientation(decoded).convert(numChannels: 4);
    _require(
      oriented.width == width && oriented.height == height,
      '$context dimensions differ from bytes',
    );
    if (working) {
      _require(
        oriented.every((pixel) => pixel.a == 255),
        '$context must be opaque',
      );
    }
    return oriented;
  }

  (MaskBitmap, Uint8List) annotations(
    String id,
    Object? value,
    int width,
    int height,
  ) {
    final refs = _map(value, '$id annotations');
    final owners = <String, Uint8List>{};
    final protections = <String, Uint8List>{};
    final count = width * height;
    for (final role in _roles) {
      final ref = _map(refs[role], '$id $role');
      _require(
        ref['width'] == width && ref['height'] == height,
        '$id $role annotation dimensions differ',
      );
      final prefix = 'photos/$id/annotations/$role';
      final owner = checkedBytes(
        ref['ownership'],
        '$id $role ownership',
        requiredPath: '$prefix.ownership.bin',
      );
      final protect = checkedBytes(
        ref['protection'],
        '$id $role protection',
        requiredPath: '$prefix.protection.bin',
      );
      _require(
        owner.length == count && owner.every((v) => v <= 4),
        '$id $role malformed ownership',
      );
      _require(
        protect.length == count && protect.every((v) => v == 0 || v == 255),
        '$id $role malformed protection',
      );
      _require(
        List.generate(
          count,
          (i) => owner[i] == 0 || protect[i] == 0,
        ).every((v) => v),
        '$id $role paintable/protected conflict',
      );
      owners[role] = owner;
      protections[role] = protect;
    }
    final evidence = _json(
      checkedBytes(
        refs['adjudication'],
        '$id adjudication',
        requiredPath: 'photos/$id/annotations/adjudication.json',
      ),
      '$id adjudication',
    );
    _require(
      evidence['origin'] == 'human-independent',
      '$id ground truth must originate from independent humans, never model output',
    );
    final submissions = _list(evidence['annotators'], '$id annotators');
    _require(
      submissions.length == 2,
      '$id requires two independent submissions',
    );
    final identities = <String>{};
    final roles = <String>{};
    final adjudicatedAt = _time(
      evidence['adjudicatedAt'],
      '$id adjudication time',
    );
    for (final item in submissions) {
      final submission = _map(item, '$id submission');
      final role = _text(submission['role'], '$id submission role');
      _require(
        _roles.take(2).contains(role) && roles.add(role),
        '$id invalid or duplicate annotator role',
      );
      final identity = _text(submission['identity'], '$id annotator identity');
      _require(
        identities.add(identity) && submission['blind'] == true,
        '$id annotators must be independent and blind',
      );
      final submittedAt = _time(
        submission['submittedAt'],
        '$id submission time',
      );
      _require(
        !submittedAt.isAfter(adjudicatedAt),
        '$id adjudication predates submission',
      );
      _require(
        _hash([...owners[role]!, ...protections[role]!]) ==
            _digest(submission['submissionSha256'], '$id submission hash'),
        '$id submitted bytes mismatch',
      );
    }
    _require(
      !identities.contains(
        _text(evidence['adjudicator'], '$id adjudicator identity'),
      ),
      '$id adjudicator must be independent',
    );
    final disputed = <int>{};
    for (var i = 0; i < count; i++) {
      if (owners['annotator-a']![i] != owners['annotator-b']![i] ||
          protections['annotator-a']![i] != protections['annotator-b']![i]) {
        disputed.add(i);
      }
    }
    final recorded = <int>{};
    for (final item in _list(evidence['disputes'], '$id disputes')) {
      final dispute = _map(item, '$id disputed region');
      _text(dispute['decision'], '$id adjudicated decision');
      final pixels = _list(dispute['pixels'], '$id disputed pixels');
      _require(pixels.isNotEmpty, '$id empty disputed region');
      for (final pixel in pixels) {
        _require(
          pixel is int && disputed.contains(pixel) && recorded.add(pixel),
          '$id invalid/duplicate disputed pixel',
        );
        final index = pixel as int;
        _require(
          owners['adjudicated']![index] == dispute['ownershipLabel'] &&
              protections['adjudicated']![index] == dispute['protectionValue'],
          '$id decision differs from adjudicated bytes',
        );
      }
    }
    _require(
      recorded.length == disputed.length,
      '$id missing disputed-region decisions',
    );
    for (var i = 0; i < count; i++) {
      if (!disputed.contains(i)) {
        _require(
          owners['adjudicated']![i] == owners['annotator-a']![i] &&
              protections['adjudicated']![i] == protections['annotator-a']![i],
          '$id unexplained adjudicated edit',
        );
      }
    }
    return (
      MaskBitmap(width: width, height: height, labels: owners['adjudicated']!),
      protections['adjudicated']!,
    );
  }
}

Uint8List _detached(Uint8List value) =>
    Uint8List.fromList(value).asUnmodifiableView();
String _hash(List<int> value) => sha256.convert(value).toString();
void _require(bool value, String context) {
  if (!value) throw FormatException(context);
}

Map<String, dynamic> _map(Object? value, String context) {
  _require(value is Map<String, dynamic>, '$context must be an object');
  return value as Map<String, dynamic>;
}

Map<String, dynamic> _json(Uint8List bytes, String context) =>
    _map(jsonDecode(utf8.decode(bytes)), context);
List<dynamic> _list(Object? value, String context) {
  _require(value is List, '$context must be an array');
  return value as List<dynamic>;
}

String _text(Object? value, String context) {
  _require(value is String && value.trim().isNotEmpty, '$context required');
  return value as String;
}

int _positive(Object? value, String context) {
  _require(value is int && value > 0, '$context must be positive integer');
  return value as int;
}

String _digest(Object? value, String context) {
  final text = _text(value, context);
  _require(
    RegExp(r'^[0-9a-f]{64}$').hasMatch(text),
    '$context must be SHA-256',
  );
  return text;
}

void _url(Object? value, String context) {
  final uri = Uri.tryParse(_text(value, context));
  _require(
    uri != null &&
        ['http', 'https'].contains(uri.scheme) &&
        uri.host.isNotEmpty,
    '$context invalid',
  );
}

DateTime _time(Object? value, String context) {
  final text = _text(value, context);
  final date = DateTime.tryParse(text);
  _require(date != null && text.endsWith('Z'), '$context must be UTC ISO-8601');
  return date!;
}

void _encodedDimensions(
  int width,
  int height,
  String context, {
  required bool working,
}) {
  _require(
    width > 0 &&
        height > 0 &&
        width <= 16384 &&
        height <= 16384 &&
        width * height <= 24000000 &&
        (!working || width <= 1600 && height <= 1600),
    '$context encoded dimensions exceed limits',
  );
}

image.Decoder _photoDecoder(Uint8List bytes, String context) {
  const maxPixels = 24000000;
  bool starts(List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (starts([0xff, 0xd8])) return image.JpegDecoder(maxPixels: maxPixels);
  if (starts([137, 80, 78, 71, 13, 10, 26, 10])) {
    return image.PngDecoder(maxPixels: maxPixels);
  }
  if (starts([71, 73, 70, 56, 55, 97]) || starts([71, 73, 70, 56, 57, 97])) {
    return image.GifDecoder()..maxPixels = maxPixels;
  }
  if (starts([82, 73, 70, 70]) && starts([87, 69, 66, 80], 8)) {
    return image.WebPDecoder()..maxPixels = maxPixels;
  }
  if (starts([66, 77])) return image.BmpDecoder(maxPixels: maxPixels);
  if (starts([73, 73, 42, 0]) || starts([77, 77, 0, 42])) {
    return image.TiffDecoder(maxPixels: maxPixels);
  }
  throw FormatException('$context unsupported photo format');
}
