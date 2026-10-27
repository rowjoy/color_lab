import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

import '../../../core/color/color_models.dart';
import '../domain/room_layer_colors.dart';
import '../domain/mask_intent_bitmap.dart';
import '../domain/mask_edit_history.dart';
import 'mask_edit_history_codec.dart';
import '../domain/room_project.dart';

final class RoomProjectAssetReference {
  const RoomProjectAssetReference({
    required this.path,
    required this.length,
    required this.sha256,
  });
  final String path;
  final int length;
  final String sha256;
  Map<String, Object> toMap() => {
    'path': path,
    'length': length,
    'sha256': sha256,
  };
}

/// Parsed metadata contains only validated, bounded values. Asset bytes are read
/// afterwards, so a manifest cannot ask the repository to allocate arbitrary data.
final class RoomProjectManifest {
  RoomProjectManifest._({
    required this.schemaVersion,
    required this.projectId,
    required this.photoId,
    required this.name,
    required this.revision,
    required this.width,
    required this.height,
    required this.maskRevision,
    required this.colorRevision,
    required this.variants,
    required this.activeVariantId,
    required this.comparisonBaselineVariantId,
    required this.createdAt,
    required this.updatedAt,
    required this.assets,
  });
  final int schemaVersion;
  final String projectId;
  final String photoId;
  final String name;
  final int revision;
  final int width;
  final int height;
  final int maskRevision;
  final int colorRevision;
  final List<RoomColorVariant> variants;
  final String activeVariantId;
  final String? comparisonBaselineVariantId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, RoomProjectAssetReference?> assets;
}

final class RoomProjectEncoding {
  RoomProjectEncoding(Uint8List manifestBytes, Map<String, Uint8List> assets)
    : manifestBytes = manifestBytes.asUnmodifiableView(),
      assets = Map.unmodifiable(assets);
  final Uint8List manifestBytes;
  final Map<String, Uint8List> assets;
}

final class RoomProjectDecoding {
  const RoomProjectDecoding(
    this.snapshot, {
    required this.thumbnailUnavailable,
  });
  final RoomProjectSnapshot snapshot;
  final bool thumbnailUnavailable;
}

/// Strict v1/v2 reader and v2-only writer. V1 gains untouched intent in memory
/// without inferring corrections or writing during reads. Unknown data fails
/// closed. Photos are prepared pixels, without source EXIF/GPS/text metadata; final platform export has its own verification gate.
final class RoomProjectCodec {
  const RoomProjectCodec();

  RoomProjectEncoding encode(RoomProjectSnapshot snapshot) {
    _png(snapshot.photoPng, width: snapshot.width, height: snapshot.height);
    if (snapshot.thumbnailPng != null) {
      _png(snapshot.thumbnailPng!, thumbnail: true);
    }
    final assets = <String, Uint8List>{};
    Map<String, Object>? asset(Uint8List? bytes, String suffix) {
      if (bytes == null) return null;
      final hash = sha256.convert(bytes).toString();
      final path = 'assets/$hash.$suffix';
      assets[path] = bytes;
      return RoomProjectAssetReference(
        path: path,
        length: bytes.length,
        sha256: hash,
      ).toMap();
    }

    final data = <String, Object?>{
      'schemaVersion': 2,
      'projectId': snapshot.projectId,
      'photoId': snapshot.photoId,
      'name': snapshot.name,
      'revision': snapshot.revision,
      'width': snapshot.width,
      'height': snapshot.height,
      'maskRevision': snapshot.maskRevision,
      'colorRevision': snapshot.colorRevision,
      'activeVariantId': snapshot.activeVariantId,
      'comparisonBaselineVariantId': snapshot.comparisonBaselineVariantId,
      'variants': [
        for (final v in snapshot.variants)
          {
            'id': v.id,
            'name': v.name,
            'colors': {
              'wall': v.colors.wall?.hex,
              'ceiling': v.colors.ceiling?.hex,
              'floor': v.colors.floor?.hex,
              'furniture': v.colors.furniture?.hex,
            },
          },
      ],
      'createdAt': snapshot.createdAt.toIso8601String(),
      'updatedAt': snapshot.updatedAt.toIso8601String(),
      'assets': {
        'photo': asset(snapshot.photoPng, 'png'),
        'aiMask': asset(snapshot.aiMaskBytes, 'mask'),
        'mask': asset(snapshot.maskBytes, 'mask'),
        'intent': asset(snapshot.intent.bytes, 'intent.bin'),
        'history': asset(
          MaskEditHistoryCodec.encode(snapshot.history),
          'history.bin',
        ),
        'thumbnail': asset(snapshot.thumbnailPng, 'png'),
      },
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    readManifest(bytes);
    return RoomProjectEncoding(bytes, assets);
  }

  RoomProjectManifest readManifest(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > RoomProjectLimits.maxManifestBytes) {
      _invalid();
    }
    try {
      final data = _map(jsonDecode(utf8.decode(bytes)), const {
        'schemaVersion',
        'projectId',
        'photoId',
        'name',
        'revision',
        'width',
        'height',
        'maskRevision',
        'colorRevision',
        'activeVariantId',
        'comparisonBaselineVariantId',
        'variants',
        'createdAt',
        'updatedAt',
        'assets',
      });
      final version = data['schemaVersion'];
      if (version is! int || (version != 1 && version != 2)) {
        _invalid();
      }
      final projectId = _id(data['projectId']);
      final photoId = _id(data['photoId']);
      final name = _name(data['name']);
      final revision = _integer(
        data['revision'],
        1,
        RoomProjectLimits.maxRevision,
      );
      final width = _integer(data['width'], 1, RoomProjectLimits.maxDimension);
      final height = _integer(
        data['height'],
        1,
        RoomProjectLimits.maxDimension,
      );
      if (width * height > RoomProjectLimits.maxPixels) _invalid();
      final maskRevision = _integer(
        data['maskRevision'],
        0,
        RoomProjectLimits.maxRevision,
      );
      final colorRevision = _integer(
        data['colorRevision'],
        0,
        RoomProjectLimits.maxRevision,
      );
      final rawVariants = data['variants'];
      if (rawVariants is! List ||
          rawVariants.isEmpty ||
          rawVariants.length > RoomProjectLimits.maxVariants) {
        _invalid();
      }
      final variants = <RoomColorVariant>[];
      for (final raw in rawVariants) {
        final v = _map(raw, const {'id', 'name', 'colors'});
        final colors = _map(v['colors'], const {
          'wall',
          'ceiling',
          'floor',
          'furniture',
        });
        variants.add(
          RoomColorVariant(
            id: _id(v['id']),
            name: _name(v['name']),
            colors: RoomLayerColors(
              wall: _color(colors['wall']),
              ceiling: _color(colors['ceiling']),
              floor: _color(colors['floor']),
              furniture: _color(colors['furniture']),
            ),
          ),
        );
      }
      final active = _id(data['activeVariantId']);
      final baseline = data['comparisonBaselineVariantId'] == null
          ? null
          : _id(data['comparisonBaselineVariantId']);
      if (variants.map((v) => v.id).toSet().length != variants.length ||
          variants.map((v) => v.name.toLowerCase()).toSet().length !=
              variants.length ||
          !variants.any((v) => v.id == active) ||
          (baseline != null && !variants.any((v) => v.id == baseline))) {
        _invalid();
      }
      final created = _date(data['createdAt']);
      final updated = _date(data['updatedAt']);
      if (updated.isBefore(created)) _invalid();
      final rawAssetMap = data['assets'];
      final hasHistory =
          version == 2 &&
          rawAssetMap is Map<String, dynamic> &&
          rawAssetMap.containsKey('history');
      final rawAssets = _map(rawAssetMap, {
        'photo',
        'aiMask',
        'mask',
        'thumbnail',
        if (version == 2) 'intent',
        if (hasHistory) 'history',
      });
      final assets = <String, RoomProjectAssetReference?>{};
      for (final key in rawAssets.keys) {
        final value = rawAssets[key];
        if (key == 'thumbnail' && value == null) {
          assets[key] = null;
          continue;
        }
        final raw = _map(value, const {'path', 'length', 'sha256'});
        final length = _integer(
          raw['length'],
          1,
          RoomProjectLimits.maxAssetBytes,
        );
        final isMask = key == 'aiMask' || key == 'mask';
        final isIntent = key == 'intent';
        final isHistory = key == 'history';
        if (isHistory &&
            (length < MaskEditHistoryCodec.headerBytes ||
                length > MaskEditHistoryCodec.maxEncodedBytes)) {
          _invalid();
        }
        if ((isMask || isIntent) && length != width * height) _invalid();
        final hash = raw['sha256'];
        if (hash is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
          _invalid();
        }
        final suffix = isHistory
            ? 'history.bin'
            : (isIntent ? 'intent.bin' : (isMask ? 'mask' : 'png'));
        final path = 'assets/$hash.$suffix';
        if (raw['path'] != path) _invalid();
        assets[key] = RoomProjectAssetReference(
          path: path,
          length: length,
          sha256: hash,
        );
      }
      return RoomProjectManifest._(
        schemaVersion: version,
        projectId: projectId,
        photoId: photoId,
        name: name,
        revision: revision,
        width: width,
        height: height,
        maskRevision: maskRevision,
        colorRevision: colorRevision,
        variants: List.unmodifiable(variants),
        activeVariantId: active,
        comparisonBaselineVariantId: baseline,
        createdAt: created,
        updatedAt: updated,
        assets: Map.unmodifiable(assets),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      _invalid();
    }
  }

  RoomProjectDecoding decode(
    RoomProjectManifest manifest,
    Map<String, Uint8List> assets,
  ) {
    Uint8List verified(String key) {
      final reference = manifest.assets[key]!;
      final bytes = assets[reference.path];
      if (bytes == null ||
          bytes.length != reference.length ||
          sha256.convert(bytes).toString() != reference.sha256) {
        _invalid();
      }
      return bytes;
    }

    final photo = verified('photo');
    _png(photo, width: manifest.width, height: manifest.height);
    final ai = verified('aiMask');
    final mask = verified('mask');
    Uint8List? thumbnail;
    var thumbnailUnavailable = false;
    if (manifest.assets['thumbnail'] != null) {
      try {
        thumbnail = verified('thumbnail');
        _png(thumbnail, thumbnail: true);
      } on FormatException {
        thumbnail = null;
        thumbnailUnavailable = true;
      }
    }
    try {
      return RoomProjectDecoding(
        RoomProjectSnapshot(
          projectId: manifest.projectId,
          photoId: manifest.photoId,
          name: manifest.name,
          revision: manifest.revision,
          width: manifest.width,
          height: manifest.height,
          photoPng: photo,
          aiMaskBytes: ai,
          maskBytes: mask,
          intent: manifest.schemaVersion == 1
              ? MaskIntentBitmap.untouched(
                  width: manifest.width,
                  height: manifest.height,
                )
              : MaskIntentBitmap.fromBytes(
                  width: manifest.width,
                  height: manifest.height,
                  bytes: verified('intent'),
                ),
          history: manifest.assets.containsKey('history')
              ? MaskEditHistoryCodec.decode(
                  verified('history'),
                  width: manifest.width,
                  height: manifest.height,
                )
              : MaskEditHistory.empty(
                  width: manifest.width,
                  height: manifest.height,
                ),
          maskRevision: manifest.maskRevision,
          colorRevision: manifest.colorRevision,
          variants: manifest.variants,
          activeVariantId: manifest.activeVariantId,
          comparisonBaselineVariantId: manifest.comparisonBaselineVariantId,
          thumbnailPng: thumbnail,
          createdAt: manifest.createdAt,
          updatedAt: manifest.updatedAt,
        ),
        thumbnailUnavailable: thumbnailUnavailable,
      );
    } on ArgumentError {
      _invalid();
    } on StateError {
      _invalid();
    }
  }

  static Never _invalid() =>
      throw const FormatException('Invalid Room project data.');
  static Map<String, dynamic> _map(Object? value, Set<String> keys) {
    if (value is! Map<String, dynamic> ||
        value.length != keys.length ||
        !keys.every(value.containsKey)) {
      _invalid();
    }
    return value;
  }

  static int _integer(Object? value, int min, int max) {
    if (value is! int || value < min || value > max) _invalid();
    return value;
  }

  static String _id(Object? value) {
    if (value is! String || !RoomProjectLimits.validId(value)) _invalid();
    return value;
  }

  static String _name(Object? value) {
    if (value is! String || !RoomProjectLimits.validName(value)) _invalid();
    return value;
  }

  static RgbColor? _color(Object? value) {
    if (value == null) return null;
    if (value is! String || !RegExp(r'^#[A-F0-9]{6}$').hasMatch(value)) {
      _invalid();
    }
    return RgbColor.fromHex(value);
  }

  static DateTime _date(Object? value) {
    if (value is! String || value.length > 32) _invalid();
    final date = DateTime.tryParse(value);
    if (date == null || !date.isUtc || date.toIso8601String() != value) {
      _invalid();
    }
    return date;
  }

  static void _png(
    Uint8List bytes, {
    int? width,
    int? height,
    bool thumbnail = false,
  }) {
    if (bytes.length < 45 || bytes.length > RoomProjectLimits.maxAssetBytes) {
      _invalid();
    }
    const signature = [137, 80, 78, 71, 13, 10, 26, 10];
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) _invalid();
    }
    final view = ByteData.sublistView(bytes);
    if (view.getUint32(8) != 13 ||
        ascii.decode(bytes.sublist(12, 16)) != 'IHDR') {
      _invalid();
    }
    final w = view.getUint32(16);
    final h = view.getUint32(20);
    final limit = thumbnail ? 1024 : RoomProjectLimits.maxDimension;
    if (w < 1 ||
        h < 1 ||
        w > limit ||
        h > limit ||
        w * h > RoomProjectLimits.maxPixels ||
        (width != null && width != w) ||
        (height != null && height != h) ||
        bytes[24] != 8 ||
        !const [2, 6].contains(bytes[25]) ||
        bytes[26] != 0 ||
        bytes[27] != 0 ||
        !const [0, 1].contains(bytes[28])) {
      _invalid();
    }
    var offset = 8;
    var ended = false;
    var idat = false;
    while (offset + 12 <= bytes.length) {
      final length = view.getUint32(offset);
      if (length > bytes.length - offset - 12) _invalid();
      final kind = ascii.decode(
        bytes.sublist(offset + 4, offset + 8),
        allowInvalid: true,
      );
      // APNG, EXIF, GPS, text and unknown ancillary chunks are not prepared pixels.
      if (!const {'IHDR', 'IDAT', 'IEND'}.contains(kind) ||
          (kind == 'IHDR' && offset != 8)) {
        _invalid();
      }
      // Check every permitted chunk, including IEND; the pixel decoder does
      // not enforce every header method or every chunk checksum itself.
      if (_pngCrc(bytes, offset + 4, offset + 8 + length) !=
          view.getUint32(offset + 8 + length)) {
        _invalid();
      }
      if (kind == 'IDAT') idat = true;
      offset += length + 12;
      if (kind == 'IEND') {
        if (length != 0) _invalid();
        ended = true;
        break;
      }
    }
    if (!ended || !idat || offset != bytes.length) _invalid();
    try {
      final decoded = img.decodePng(bytes);
      if (decoded == null || decoded.width != w || decoded.height != h) {
        _invalid();
      }
    } catch (_) {
      _invalid();
    }
  }

  static final _crcTable = List<int>.generate(256, (index) {
    var value = index;
    for (var bit = 0; bit < 8; bit++) {
      value = (value & 1) == 0 ? value >>> 1 : (value >>> 1) ^ 0xedb88320;
    }
    return value;
  }, growable: false);

  static int _pngCrc(Uint8List bytes, int start, int end) {
    var crc = 0xffffffff;
    for (var index = start; index < end; index++) {
      crc = (crc >>> 8) ^ _crcTable[(crc ^ bytes[index]) & 0xff];
    }
    return crc ^ 0xffffffff;
  }
}
