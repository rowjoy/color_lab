import 'dart:typed_data';

enum CameraFrameFormat { yuv420, nv21, bgra8888, unsupported }

/// Isolate-safe owned bytes, independent of native camera buffer lifetime.
final class CameraPlane {
  CameraPlane({
    required Uint8List bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final int bytesPerRow;
  final int bytesPerPixel;
}

final class CameraFrame {
  CameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required List<CameraPlane> planes,
  }) : planes = List.unmodifiable(planes);

  final int width;
  final int height;
  final CameraFrameFormat format;
  final List<CameraPlane> planes;
}

/// All worker inputs are values; no CameraImage/controller crosses isolates.
final class CameraSampleRequest {
  const CameraSampleRequest({
    required this.frame,
    required this.x,
    required this.y,
    required this.viewportWidth,
    required this.viewportHeight,
    required this.rotationDegrees,
    required this.mirrored,
  });

  final CameraFrame frame;
  final double x;
  final double y;
  final double viewportWidth;
  final double viewportHeight;
  final int rotationDegrees;
  final bool mirrored;
}
