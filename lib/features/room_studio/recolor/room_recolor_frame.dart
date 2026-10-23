import 'dart:typed_data';

final class RoomRecolorKey {
  RoomRecolorKey({
    required this.photoId,
    required this.maskRevision,
    required this.colorRevision,
  }) {
    if (photoId.isEmpty || maskRevision < 0 || colorRevision < 0) {
      throw ArgumentError('Valid photo and nonnegative revisions required');
    }
  }

  final String photoId;
  final int maskRevision;
  final int colorRevision;

  @override
  bool operator ==(Object other) =>
      other is RoomRecolorKey &&
      photoId == other.photoId &&
      maskRevision == other.maskRevision &&
      colorRevision == other.colorRevision;

  @override
  int get hashCode => Object.hash(photoId, maskRevision, colorRevision);
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
