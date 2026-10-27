import 'dart:typed_data';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:image/image.dart' as img;

Uint8List roomProjectPng({int width = 2, int height = 2}) =>
    Uint8List.fromList(img.encodePng(img.Image(width: width, height: height)));

/// A one-pixel scanline is also Adam7's sole non-empty pass. Recompute the
/// IHDR CRC so method-boundary tests do not fail merely on a stale checksum.
Uint8List roomProjectPngWithMethods({
  int compression = 0,
  int filter = 0,
  int interlace = 0,
}) {
  final bytes = roomProjectPng(width: 1, height: 1);
  bytes[26] = compression;
  bytes[27] = filter;
  bytes[28] = interlace;
  var crc = 0xffffffff;
  for (final byte in Uint8List.sublistView(bytes, 12, 29)) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 0 ? crc >>> 1 : (crc >>> 1) ^ 0xedb88320;
    }
  }
  ByteData.sublistView(bytes).setUint32(29, crc ^ 0xffffffff);
  return bytes;
}

RoomProjectSnapshot roomProjectOnePixelFixture({
  required Uint8List photoPng,
  int revision = 0,
}) => roomProjectFixture(revision: revision).copyWith(
  width: 1,
  height: 1,
  photoPng: photoPng,
  aiMaskBytes: Uint8List.fromList([1]),
  maskBytes: Uint8List.fromList([1]),
);

RoomProjectSnapshot roomProjectFixture({
  String projectId = 'project-1',
  String name = 'Living room',
  int revision = 0,
}) => RoomProjectSnapshot(
  projectId: projectId,
  photoId: 'photo-1',
  name: name,
  revision: revision,
  width: 2,
  height: 2,
  photoPng: roomProjectPng(),
  aiMaskBytes: Uint8List.fromList([1, 1, 0, 4]),
  maskBytes: Uint8List.fromList([1, 2, 3, 4]),
  maskRevision: 2,
  colorRevision: 3,
  variants: [
    RoomColorVariant(
      id: 'variant-a',
      name: 'A',
      colors: RoomLayerColors(wall: RgbColor.fromHex('#ABCDEF')),
    ),
    RoomColorVariant(
      id: 'variant-b',
      name: 'B',
      colors: RoomLayerColors(floor: RgbColor.fromHex('#102030')),
    ),
  ],
  activeVariantId: 'variant-a',
  comparisonBaselineVariantId: 'variant-b',
  thumbnailPng: roomProjectPng(width: 1, height: 1),
  createdAt: DateTime.utc(2026, 10, 27, 1),
  updatedAt: DateTime.utc(2026, 10, 27, 2),
);
