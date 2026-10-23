import 'dart:math' as math;
import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/segmentation/room_wall_depth_protection.dart';
import 'package:flutter_test/flutter_test.dart';

MaskBitmap walls(int width, int height) => MaskBitmap(
  width: width,
  height: height,
  labels: Uint8List(width * height)..fillRange(0, width * height, 1),
);

RoomDepthFrame scene({
  int width = 32,
  int height = 24,
  bool tilted = false,
  int left = 3,
  int top = 2,
  int right = 12,
  int bottom = 10,
}) {
  final values = Float32List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      values[y * width + x] =
          100 +
          (tilted ? 50 * x / width + 30 * y / height : 0) +
          (x >= left && x < right && y >= top && y < bottom ? 200 : 0);
    }
  }
  return RoomDepthFrame(width: width, height: height, inverseDepth: values);
}

void main() {
  test('depth owns a detached immutable Float32 snapshot', () {
    final values = Float32List.fromList([1, 2, 3, 4]);
    final depth = RoomDepthFrame(width: 2, height: 2, inverseDepth: values);
    values[0] = 99;
    expect(depth.inverseDepth, [1, 2, 3, 4]);
    expect(() => depth.inverseDepth[0] = 99, throwsUnsupportedError);
    expect(
      () => depth.inverseDepth.buffer.asFloat32List()[0] = 99,
      throwsUnsupportedError,
    );
  });

  test('rejects corrupt dimensions and nonfinite or negative depth', () {
    for (final dimensions in [(0, 2), (2, 0), (-1, 2), (2, -1), (2, 3)]) {
      expect(
        () => RoomDepthFrame(
          width: dimensions.$1,
          height: dimensions.$2,
          inverseDepth: Float32List(4),
        ),
        throwsArgumentError,
      );
    }
    for (final value in [double.nan, double.infinity, -double.infinity, -1.0]) {
      expect(
        () => RoomDepthFrame(
          width: 2,
          height: 2,
          inverseDepth: Float32List.fromList([1, 2, value, 4]),
        ),
        throwsArgumentError,
      );
    }
  });

  test('removes a closer object at the top left of a frontal wall', () {
    final baseline = walls(32, 24);
    final result = protectRoomWallsWithDepth(baseline, scene());
    expect(result.labels[4 * 32 + 5], 0);
    expect(result.labels[18 * 32 + 20], 1);
    expect(result.labels.where((label) => label == 0).length, 72);
    expect(baseline.labels.every((label) => label == 1), isTrue);
  });

  test('fits a tilted wall instead of removing its nearer side', () {
    final result = protectRoomWallsWithDepth(
      walls(32, 24),
      scene(tilted: true),
    );
    expect(result.labels[4 * 32 + 5], 0);
    expect(result.labels[23 * 32 + 31], 1);
    expect(result.labels.where((label) => label == 0).length, 72);
  });

  test('maps a non-square depth frame into source mask geometry', () {
    final result = protectRoomWallsWithDepth(
      walls(96, 48),
      scene(tilted: true),
    );
    expect(result.labels[8 * 96 + 15], 0);
    expect(result.labels[40 * 96 + 90], 1);
    expect(result.labels[0], 1);
    expect(result.labels.last, 1);
    expect(result.labels.where((label) => label == 0).length, 432);
  });

  test(
    'maps source pixel centers consistently at fractional cell boundaries',
    () {
      final result = protectRoomWallsWithDepth(walls(97, 49), scene());
      expect(result.labels[4 * 97 + 9], 0);
      expect(result.labels[3 * 97 + 9], 1);
      expect(result.labels[4 * 97 + 8], 1);
      expect(result.labels[19 * 97 + 35], 0);
      expect(result.labels[20 * 97 + 35], 1);
      expect(result.labels[19 * 97 + 36], 1);
    },
  );

  test('preserves every non-Wall owner even inside the foreground', () {
    final labels = Uint8List(32 * 24)..fillRange(0, 32 * 24, 1);
    for (var i = 0; i < 5; i++) {
      labels[4 * 32 + 4 + i] = i;
    }
    final baseline = MaskBitmap(width: 32, height: 24, labels: labels);
    final result = protectRoomWallsWithDepth(baseline, scene());
    expect(result.labels.sublist(4 * 32 + 4, 4 * 32 + 9), [0, 0, 2, 3, 4]);
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] != 1) expect(result.labels[i], labels[i]);
    }
  });

  test('keeps masks unchanged for flat depth or no wall ownership', () {
    final baseline = walls(32, 24);
    final flat = RoomDepthFrame(
      width: 32,
      height: 24,
      inverseDepth: Float32List(32 * 24)..fillRange(0, 32 * 24, 100),
    );
    expect(protectRoomWallsWithDepth(baseline, flat), same(baseline));
    final noWall = MaskBitmap(
      width: 32,
      height: 24,
      labels: Uint8List(32 * 24),
    );
    expect(protectRoomWallsWithDepth(noWall, scene()), same(noWall));
  });

  test('keeps masks when depth provides fewer than 64 wall samples', () {
    final baseline = walls(8, 7);
    final depth = scene(
      width: 8,
      height: 7,
      left: 1,
      top: 1,
      right: 4,
      bottom: 4,
    );
    expect(protectRoomWallsWithDepth(baseline, depth), same(baseline));
  });

  test('keeps a large mask when its depth frame has fewer than 64 samples', () {
    final baseline = walls(96, 84);
    final depth = scene(
      width: 8,
      height: 7,
      left: 1,
      top: 1,
      right: 4,
      bottom: 4,
    );
    expect(protectRoomWallsWithDepth(baseline, depth), same(baseline));
  });

  test('keeps masks when wall samples cannot establish a spatial plane', () {
    final labels = Uint8List(64 * 64);
    for (var y = 0; y < 64; y++) {
      labels[y * 64 + 32] = 1;
    }
    final baseline = MaskBitmap(width: 64, height: 64, labels: labels);
    expect(
      protectRoomWallsWithDepth(baseline, scene(width: 64, height: 64)),
      same(baseline),
    );
  });

  test('keeps masks when no plane has a strong majority of wall samples', () {
    final random = math.Random(7);
    final depth = RoomDepthFrame(
      width: 32,
      height: 24,
      inverseDepth: Float32List.fromList([
        for (var i = 0; i < 32 * 24; i++) 10 + random.nextDouble() * 300,
      ]),
    );
    final baseline = walls(32, 24);
    expect(protectRoomWallsWithDepth(baseline, depth), same(baseline));
  });

  test('is deterministic and safely clamps source edge coordinates', () {
    final baseline = walls(97, 49);
    final depth = scene(tilted: true, left: 23, top: 16, right: 32, bottom: 24);
    final first = protectRoomWallsWithDepth(baseline, depth);
    final second = protectRoomWallsWithDepth(baseline, depth);
    expect(first.labels, second.labels);
    expect(first.labels.first, 1);
    expect(first.labels.last, 0);
    expect(first.labels[40 * 97 + 80], 0);
  });
}
