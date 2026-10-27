import 'dart:typed_data';

import '../domain/room_project.dart';

final class RoomRecolorKey {
  RoomRecolorKey({
    required this.projectId,
    required this.photoId,
    required this.maskRevision,
    required this.colorRevision,
    required this.variantId,
  }) {
    if (!RoomProjectLimits.validId(projectId) ||
        !RoomProjectLimits.validId(photoId) ||
        !RoomProjectLimits.validId(variantId) ||
        !RoomProjectLimits.validRevision(maskRevision) ||
        !RoomProjectLimits.validRevision(colorRevision)) {
      throw ArgumentError('Safe complete render identity required');
    }
  }

  final String photoId;
  final String projectId;
  final String variantId;
  final int maskRevision;
  final int colorRevision;

  @override
  bool operator ==(Object other) =>
      other is RoomRecolorKey &&
      projectId == other.projectId &&
      variantId == other.variantId &&
      photoId == other.photoId &&
      maskRevision == other.maskRevision &&
      colorRevision == other.colorRevision;

  @override
  int get hashCode =>
      Object.hash(projectId, photoId, maskRevision, colorRevision, variantId);

  /// Previous frames are display-only, and never cross these ownership fields.
  bool sameView(RoomRecolorKey other) =>
      projectId == other.projectId &&
      photoId == other.photoId &&
      variantId == other.variantId;
}

final class RoomRecolorFrame {
  RoomRecolorFrame({
    required this.key,
    required this.width,
    required this.height,
    required Uint8List rgbaBytes,
    required Uint8List pngBytes,
  }) : rgbaBytes = Uint8List.fromList(rgbaBytes).asUnmodifiableView(),
       pngBytes = Uint8List.fromList(pngBytes).asUnmodifiableView() {
    if (width < 1 ||
        height < 1 ||
        rgbaBytes.length != width * height * 4 ||
        pngBytes.isEmpty) {
      throw ArgumentError('Aligned RGBA and encoded PNG bytes required');
    }
  }

  final RoomRecolorKey key;
  final int width;
  final int height;
  final Uint8List rgbaBytes;
  final Uint8List pngBytes;
}
