import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/segmentation/room_wall_depth_protection.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Scene = ({MaskBitmap masks, RoomDepthFrame depth, Uint8List expected});

Scene room({
  double corner = .5,
  bool single = false,
  bool ceiling = true,
  bool fragmented = false,
  bool extrapolation = false,
  bool noisy = false,
  List<(int, int, int, int)> objects = const [],
}) {
  const width = 96, height = 72;
  final labels = Uint8List(width * height);
  final expected = Uint8List(width * height);
  final values = Float32List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * width + x, u = (x + .5) / width, v = (y + .5) / height;
      labels[i] = ceiling && y < 8 ? 2 : 1;
      if (fragmented && x >= 68 && x < 72 && y >= 8) labels[i] = 0;
      expected[i] = labels[i];
      var z = single
          ? 100 + 40 * u + 10 * v
          : extrapolation
          ? (u < corner ? 300 - 250 * u : 800 - 600 * u) + 10 * v
          : 100 +
                (u < corner ? 140 * (corner - u) : 420 * (u - corner)) +
                10 * v;
      if (labels[i] == 2) z = 30;
      for (final r in objects) {
        if (x >= r.$1 && y >= r.$2 && x < r.$3 && y < r.$4) {
          z += 200;
          if (labels[i] == 1) expected[i] = 0;
        }
      }
      if (noisy && labels[i] == 1) z += ((x * 13 + y * 7) % 7 - 3) * .15;
      values[i] = z;
    }
  }
  return (
    masks: MaskBitmap(width: width, height: height, labels: labels),
    depth: RoomDepthFrame(width: width, height: height, inverseDepth: values),
    expected: expected,
  );
}

Scene transform(
  Scene scene, {
  bool mirror = false,
  bool transpose = false,
  bool affineDepth = false,
}) {
  final width = transpose ? scene.masks.height : scene.masks.width;
  final height = transpose ? scene.masks.width : scene.masks.height;
  final labels = Uint8List(width * height),
      expected = Uint8List(width * height);
  final depth = Float32List(width * height);
  for (var y = 0; y < scene.masks.height; y++) {
    for (var x = 0; x < scene.masks.width; x++) {
      final sx = mirror ? scene.masks.width - 1 - x : x;
      final dx = transpose ? y : sx, dy = transpose ? sx : y;
      final source = y * scene.masks.width + x, target = dy * width + dx;
      labels[target] = scene.masks.labels[source];
      expected[target] = scene.expected[source];
      depth[target] =
          scene.depth.inverseDepth[source] * (affineDepth ? 2 : 1) +
          (affineDepth ? 100 : 0);
    }
  }
  return (
    masks: MaskBitmap(width: width, height: height, labels: labels),
    depth: RoomDepthFrame(width: width, height: height, inverseDepth: depth),
    expected: expected,
  );
}

void main() {
  for (final corner in [.5, .73, .875]) {
    test('preserves both genuine walls with corner$corner', () {
      final scene = room(corner: corner);
      final result = protectRoomWallsWithDepth(scene.masks, scene.depth);
      expect(result.labels, scene.expected);
    });
  }

  for (final object in [(14, 42, 28, 58), (74, 42, 88, 58), (42, 46, 54, 60)]) {
    test('separates foreground$object while retaining both walls', () {
      final scene = room(objects: [object]);
      final before = scene.masks.labels.toList();
      final result = protectRoomWallsWithDepth(scene.masks, scene.depth);
      expect(result.labels, scene.expected);
      expect(scene.masks.labels, before);
    });
  }

  test('large planar monitor is not promoted to a second wall', () {
    final scene = room(single: true, objects: [(12, 32, 84, 68)]);
    expect(
      protectRoomWallsWithDepth(scene.masks, scene.depth).labels,
      scene.expected,
    );
  });

  test('door fragments do not erase a supported secondary wall', () {
    final scene = room(fragmented: true, objects: [(76, 42, 88, 58)]);
    expect(
      protectRoomWallsWithDepth(scene.masks, scene.depth).labels,
      scene.expected,
    );
  });

  test('a distant wall plane cannot shield unrelated foreground', () {
    final scene = room(extrapolation: true, objects: [(10, 40, 24, 54)]);
    expect(
      protectRoomWallsWithDepth(scene.masks, scene.depth).labels,
      scene.expected,
    );
  });

  test('ambiguous adjacent planes without ceiling evidence abstain', () {
    final scene = room(ceiling: false);
    expect(
      protectRoomWallsWithDepth(scene.masks, scene.depth).labels,
      scene.expected,
    );
  });

  for (final variant in ['mirror', 'transpose', 'depth-affine', 'noisy']) {
    test('$variant equivalent corner scene keeps geometry and ownership', () {
      final source = room(
        noisy: variant == 'noisy',
        objects: [(14, 42, 28, 58), (74, 42, 88, 58)],
      );
      final scene = transform(
        source,
        mirror: variant == 'mirror',
        transpose: variant == 'transpose',
        affineDepth: variant == 'depth-affine',
      );
      final first = protectRoomWallsWithDepth(scene.masks, scene.depth);
      expect(first.labels, scene.expected);
      expect(
        protectRoomWallsWithDepth(scene.masks, scene.depth).labels,
        first.labels,
      );
    });
  }
}
