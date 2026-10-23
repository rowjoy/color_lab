import 'dart:math' as math;

import '../../features/picker/domain/camera_frame.dart';
import '../color/color_models.dart';

typedef CameraPoint = ({double x, double y});

/// Reverse a centered BoxFit.cover, a horizontal preview mirror, then clockwise
/// buffer rotation. Inputs and result are normalized to their respective image.
CameraPoint viewportToCameraPoint({
  required double x,
  required double y,
  required double viewportWidth,
  required double viewportHeight,
  required int frameWidth,
  required int frameHeight,
  int rotationDegrees = 0,
  bool mirrored = false,
}) {
  if (![x, y, viewportWidth, viewportHeight].every((v) => v.isFinite) ||
      viewportWidth <= 0 ||
      viewportHeight <= 0 ||
      frameWidth <= 0 ||
      frameHeight <= 0 ||
      ![0, 90, 180, 270].contains(rotationDegrees)) {
    throw const FormatException('Invalid camera geometry');
  }
  final swapped = rotationDegrees == 90 || rotationDegrees == 270;
  final width = swapped ? frameHeight : frameWidth;
  final height = swapped ? frameWidth : frameHeight;
  final scale = math.max(viewportWidth / width, viewportHeight / height);
  var u =
      (x.clamp(0, 1) * viewportWidth + (width * scale - viewportWidth) / 2) /
      (width * scale);
  final v =
      (y.clamp(0, 1) * viewportHeight + (height * scale - viewportHeight) / 2) /
      (height * scale);
  if (mirrored) u = 1 - u;
  return switch (rotationDegrees) {
    90 => (x: v, y: 1 - u),
    180 => (x: 1 - u, y: 1 - v),
    270 => (x: 1 - v, y: u),
    _ => (x: u, y: v),
  };
}

/// Top-level compute entry point. Only a clipped 5×5 area is converted.
RgbColor sampleCameraRequest(CameraSampleRequest request) {
  final p = viewportToCameraPoint(
    x: request.x,
    y: request.y,
    viewportWidth: request.viewportWidth,
    viewportHeight: request.viewportHeight,
    frameWidth: request.frame.width,
    frameHeight: request.frame.height,
    rotationDegrees: request.rotationDegrees,
    mirrored: request.mirrored,
  );
  return sampleCameraFrame(request.frame, x: p.x, y: p.y);
}

RgbColor sampleCameraFrame(
  CameraFrame frame, {
  required double x,
  required double y,
  int radius = 2,
}) {
  if (frame.width <= 0 ||
      frame.height <= 0 ||
      !x.isFinite ||
      !y.isFinite ||
      radius < 0) {
    throw const FormatException('Invalid camera frame');
  }
  final expectedPlanes = switch (frame.format) {
    CameraFrameFormat.yuv420 => 3,
    CameraFrameFormat.bgra8888 || CameraFrameFormat.nv21 => 1,
    CameraFrameFormat.unsupported => 0,
  };
  if (expectedPlanes == 0 || frame.planes.length != expectedPlanes) {
    throw const FormatException('Unsupported camera format');
  }
  if (frame.planes.any((p) => p.bytesPerRow <= 0 || p.bytesPerPixel <= 0)) {
    throw const FormatException('Invalid camera strides');
  }
  final cx = (x.clamp(0, 1) * frame.width).floor().clamp(0, frame.width - 1);
  final cy = (y.clamp(0, 1) * frame.height).floor().clamp(0, frame.height - 1);
  var red = 0, green = 0, blue = 0, count = 0;
  int read(CameraPlane plane, int index) {
    if (index < 0 || index >= plane.bytes.length) {
      throw const FormatException('Incomplete camera plane');
    }
    return plane.bytes[index];
  }

  for (
    var py = math.max(0, cy - radius);
    py <= math.min(frame.height - 1, cy + radius);
    py++
  ) {
    for (
      var px = math.max(0, cx - radius);
      px <= math.min(frame.width - 1, cx + radius);
      px++
    ) {
      final first = frame.planes.first;
      if (frame.format == CameraFrameFormat.bgra8888) {
        final i = py * first.bytesPerRow + px * first.bytesPerPixel;
        blue += read(first, i);
        green += read(first, i + 1);
        red += read(first, i + 2);
      } else {
        final luma = read(
          first,
          py * first.bytesPerRow + px * first.bytesPerPixel,
        );
        final int u, v;
        if (frame.format == CameraFrameFormat.nv21) {
          final i =
              first.bytesPerRow * frame.height +
              (py ~/ 2) * first.bytesPerRow +
              (px ~/ 2) * 2;
          v = read(first, i);
          u = read(first, i + 1);
        } else {
          final up = frame.planes[1], vp = frame.planes[2];
          u = read(
            up,
            (py ~/ 2) * up.bytesPerRow + (px ~/ 2) * up.bytesPerPixel,
          );
          v = read(
            vp,
            (py ~/ 2) * vp.bytesPerRow + (px ~/ 2) * vp.bytesPerPixel,
          );
        }
        // Android YUV_420_888 / NV21: BT.601 limited-range integer conversion.
        final c = math.max(0, luma - 16), d = u - 128, e = v - 128;
        red += ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
        green += ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
        blue += ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);
      }
      count++;
    }
  }
  return RgbColor(
    (red / count).round(),
    (green / count).round(),
    (blue / count).round(),
  );
}

final class CameraSamplingGate {
  CameraSamplingGate({this.interval = const Duration(microseconds: 66667)});
  final Duration interval;
  Duration? _last;
  bool _busy = false;
  bool tryBegin(Duration elapsed) {
    if (_busy || (_last != null && elapsed - _last! < interval)) return false;
    _busy = true;
    _last = elapsed;
    return true;
  }

  void complete() => _busy = false;
  void reset() {
    _busy = false;
    _last = null;
  }
}

final class CameraColorSmoother {
  final _colors = <RgbColor>[];
  RgbColor add(RgbColor color) {
    _colors.add(color);
    if (_colors.length > 3) _colors.removeAt(0);
    int mean(int Function(RgbColor) channel) =>
        (_colors.fold<int>(0, (sum, c) => sum + channel(c)) / _colors.length)
            .round();
    return RgbColor(
      mean((c) => c.red),
      mean((c) => c.green),
      mean((c) => c.blue),
    );
  }

  void reset() => _colors.clear();
}
