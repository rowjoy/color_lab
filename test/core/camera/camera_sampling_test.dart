import 'dart:typed_data';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/utils/camera_sampling.dart';
import 'package:color_lab/features/picker/domain/camera_frame.dart';
import 'package:flutter_test/flutter_test.dart';

CameraPlane plane(List<int> bytes, int row, [int pixel = 1]) => CameraPlane(
  bytes: Uint8List.fromList(bytes),
  bytesPerRow: row,
  bytesPerPixel: pixel,
);

void main() {
  test('BGRA samples channels and clipped 5 by 5 uses real edge pixels', () {
    // 6 x 6 red ramp with 4 trailing padding bytes per row.
    final bytes = <int>[];
    for (var y = 0; y < 6; y++) {
      for (var x = 0; x < 6; x++) {
        bytes.addAll([3, 7, x * 10 + y * 20, 255]);
      }
      bytes.addAll([255, 255, 255, 255]);
    }
    final frame = CameraFrame(
      width: 6,
      height: 6,
      format: CameraFrameFormat.bgra8888,
      planes: [plane(bytes, 28, 4)],
    );
    expect(sampleCameraFrame(frame, x: 0, y: 0), RgbColor(30, 7, 3));
    expect(sampleCameraFrame(frame, x: 1, y: 1), RgbColor(120, 7, 3));
    expect(sampleCameraFrame(frame, x: .5, y: .5), RgbColor(90, 7, 3));
  });

  test('YUV420 respects independent padded rows and chroma pixel stride', () {
    final frame = CameraFrame(
      width: 4,
      height: 2,
      format: CameraFrameFormat.yuv420,
      planes: [
        plane([81, 81, 41, 41, 0, 0, 81, 81, 41, 41, 0, 0], 6),
        plane([90, 0, 240, 0, 0], 5, 2),
        plane([240, 0, 110, 0, 0, 0], 6, 2),
      ],
    );
    expect(
      sampleCameraFrame(frame, x: 0, y: 0, radius: 0),
      RgbColor(255, 0, 0),
    );
    expect(
      sampleCameraFrame(frame, x: .99, y: 1, radius: 0),
      RgbColor(0, 0, 255),
    );
  });

  test('NV21 reads V then U after padded luma plane', () {
    final frame = CameraFrame(
      width: 2,
      height: 2,
      format: CameraFrameFormat.nv21,
      planes: [
        plane([145, 145, 0, 0, 145, 145, 0, 0, 34, 54, 0, 0], 4),
      ],
    );
    expect(sampleCameraFrame(frame, x: .5, y: .5), RgbColor(0, 255, 1));
  });

  test('malformed or unknown planes fail with a safe format exception', () {
    for (final frame in [
      CameraFrame(
        width: 2,
        height: 2,
        format: CameraFrameFormat.bgra8888,
        planes: [
          plane([0], 8, 4),
        ],
      ),
      CameraFrame(
        width: 2,
        height: 2,
        format: CameraFrameFormat.unsupported,
        planes: [],
      ),
    ]) {
      expect(
        () => sampleCameraFrame(frame, x: .5, y: .5),
        throwsFormatException,
      );
    }
  });

  test('cover mapping reverses cropping before every rotation and mirror', () {
    // Landscape 400x200 frame fills square: visible raw horizontal range .25..75.
    final p = viewportToCameraPoint(
      x: 0,
      y: .25,
      viewportWidth: 100,
      viewportHeight: 100,
      frameWidth: 400,
      frameHeight: 200,
    );
    expect(p.x, .25);
    expect(p.y, .25);
    const wanted = [(0, .2, .3), (90, .3, .8), (180, .8, .7), (270, .7, .2)];
    for (final (rotation, x, y) in wanted) {
      final p = viewportToCameraPoint(
        x: .2,
        y: .3,
        viewportWidth: 100,
        viewportHeight: 100,
        frameWidth: 100,
        frameHeight: 100,
        rotationDegrees: rotation,
      );
      expect(p.x, closeTo(x, 1e-10));
      expect(p.y, closeTo(y, 1e-10));
      final mirrored = viewportToCameraPoint(
        x: .8,
        y: .3,
        viewportWidth: 100,
        viewportHeight: 100,
        frameWidth: 100,
        frameHeight: 100,
        rotationDegrees: rotation,
        mirrored: true,
      );
      expect(mirrored.x, closeTo(x, 1e-10));
      expect(mirrored.y, closeTo(y, 1e-10));
    }
    final rotated = viewportToCameraPoint(
      x: 0,
      y: .25,
      viewportWidth: 100,
      viewportHeight: 100,
      frameWidth: 400,
      frameHeight: 200,
      rotationDegrees: 90,
    );
    expect(rotated.x, .375);
    expect(rotated.y, 1);
  });

  test(
    'gate drops overlapping work and admits at most about 15 frames a second',
    () {
      final gate = CameraSamplingGate();
      expect(gate.tryBegin(Duration.zero), isTrue);
      expect(gate.tryBegin(const Duration(milliseconds: 100)), isFalse);
      gate.complete();
      expect(gate.tryBegin(const Duration(milliseconds: 66)), isFalse);
      expect(gate.tryBegin(const Duration(milliseconds: 67)), isTrue);
      gate.complete();
      gate.reset();
      expect(gate.tryBegin(const Duration(milliseconds: 68)), isTrue);
    },
  );

  test(
    'smoothing retains only the last three actual samples and can reset',
    () {
      final smoothing = CameraColorSmoother();
      expect(smoothing.add(RgbColor(0, 30, 60)), RgbColor(0, 30, 60));
      expect(smoothing.add(RgbColor(30, 60, 90)), RgbColor(15, 45, 75));
      smoothing.add(RgbColor(60, 90, 120));
      expect(smoothing.add(RgbColor(90, 120, 150)), RgbColor(60, 90, 120));
      smoothing.reset();
      expect(smoothing.add(RgbColor(255, 0, 0)), RgbColor(255, 0, 0));
    },
  );
}
