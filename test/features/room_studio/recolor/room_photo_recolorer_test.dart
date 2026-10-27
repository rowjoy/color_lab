import 'dart:typed_data';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/recolor/room_photo_recolorer.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

final _key = RoomRecolorKey(
  projectId: 'project',
  variantId: 'a',
  photoId: 'photo-1',
  maskRevision: 2,
  colorRevision: 3,
);

PreparedPhoto _photo(int width, int height, List<int> rgba) => PreparedPhoto(
  width: width,
  height: height,
  rgbaBytes: Uint8List.fromList(rgba),
  previewBytes: Uint8List(0),
  palette: const [],
);

MaskBitmap _masks(int width, int height, List<int> labels) => MaskBitmap(
  width: width,
  height: height,
  labels: Uint8List.fromList(labels),
);

List<int> _solidPixels(int width, int height, int red, int green, int blue) => [
  for (var i = 0; i < width * height; i++) ...[red, green, blue, 255],
];

List<int> _pixel(Uint8List bytes, int width, int x, int y) {
  final start = (y * width + x) * 4;
  return bytes.sublist(start, start + 4);
}

void main() {
  test('frame key has value equality and rejects invalid revisions', () {
    expect(
      _key,
      RoomRecolorKey(
        projectId: 'project',
        variantId: 'a',
        photoId: 'photo-1',
        maskRevision: 2,
        colorRevision: 3,
      ),
    );
    expect(
      () => RoomRecolorKey(
        projectId: 'project',
        variantId: 'a',
        photoId: '',
        maskRevision: 0,
        colorRevision: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => RoomRecolorKey(
        projectId: 'project',
        variantId: 'a',
        photoId: 'p',
        maskRevision: -1,
        colorRevision: 0,
      ),
      throwsArgumentError,
    );
  });

  test('unset colors leave every source byte unchanged', () {
    final source = <int>[
      5,
      10,
      15,
      255,
      50,
      60,
      70,
      255,
      100,
      110,
      120,
      255,
      150,
      160,
      170,
      255,
    ];

    final frame = recolorRoomPhoto(
      key: _key,
      photo: _photo(2, 2, source),
      masks: _masks(2, 2, [1, 2, 3, 4]),
      colors: const RoomLayerColors(),
    );

    expect(frame.rgbaBytes, source);
    expect(frame.key, _key);
    expect(frame.width, 2);
    expect(frame.height, 2);
    expect(frame.pngBytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final decoded = img.decodePng(frame.pngBytes)!;
    expect(decoded.getBytes(order: img.ChannelOrder.rgba), source);
  });

  test('assigned layer keeps source shadow and highlight order', () {
    const width = 5;
    const height = 5;
    const shades = [25, 70, 120, 180, 230];
    final source = <int>[
      for (var y = 0; y < height; y++)
        for (final shade in shades) ...[shade, shade, shade, 255],
    ];

    final frame = recolorRoomPhoto(
      key: _key,
      photo: _photo(width, height, source),
      masks: _masks(
        width,
        height,
        List<int>.filled(width * height, RoomLayer.wall.label),
      ),
      colors: RoomLayerColors(wall: RgbColor.fromHex('#B25030')),
    );

    final dark = _pixel(frame.rgbaBytes, width, 1, 2);
    final mid = _pixel(frame.rgbaBytes, width, 2, 2);
    final light = _pixel(frame.rgbaBytes, width, 3, 2);
    expect(
      [dark, mid, light],
      [
        [115, 32, 12, 255],
        [178, 80, 48, 255],
        [244, 142, 110, 255],
      ],
    );
    int sum(List<int> value) => value[0] + value[1] + value[2];
    expect(sum(dark), lessThan(sum(mid)));
    expect(sum(mid), lessThan(sum(light)));
    expect(mid[0], greaterThan(mid[2]));
    expect(mid, isNot([120, 120, 120, 255]));
    expect(frame.rgbaBytes.where((value) => value < 0 || value > 255), isEmpty);
  });

  test('feathering never changes a pixel owned by another layer', () {
    const width = 7;
    const height = 5;
    final source = _solidPixels(width, height, 110, 120, 130);
    final labels = <int>[
      for (var y = 0; y < height; y++)
        for (var x = 0; x < width; x++)
          if (x < 3)
            RoomLayer.wall.label
          else if (x == 3)
            RoomLayer.floor.label
          else
            0,
    ];

    final frame = recolorRoomPhoto(
      key: _key,
      photo: _photo(width, height, source),
      masks: _masks(width, height, labels),
      colors: RoomLayerColors(wall: RgbColor.fromHex('#D02020')),
    );

    expect(_pixel(frame.rgbaBytes, width, 2, 2), isNot([110, 120, 130, 255]));
    expect(_pixel(frame.rgbaBytes, width, 3, 2), [110, 120, 130, 255]);
    expect(_pixel(frame.rgbaBytes, width, 4, 2), [110, 120, 130, 255]);
  });

  test('adjacent assigned owners receive only their own target color', () {
    const width = 8;
    const height = 5;
    final source = _solidPixels(width, height, 128, 128, 128);
    final labels = <int>[
      for (var y = 0; y < height; y++)
        for (var x = 0; x < width; x++)
          x < width ~/ 2 ? RoomLayer.wall.label : RoomLayer.floor.label,
    ];

    final frame = recolorRoomPhoto(
      key: _key,
      photo: _photo(width, height, source),
      masks: _masks(width, height, labels),
      colors: RoomLayerColors(
        wall: RgbColor.fromHex('#D03030'),
        floor: RgbColor.fromHex('#3040D0'),
      ),
    );

    final wall = _pixel(frame.rgbaBytes, width, 1, 2);
    final floor = _pixel(frame.rgbaBytes, width, 6, 2);
    expect(wall[0], greaterThan(wall[2]));
    expect(floor[2], greaterThan(floor[0]));
    expect(wall[3], 255);
    expect(floor[3], 255);
  });

  for (final target in ['#000000', '#FFFFFF', '#FF00FF']) {
    test('$target target preserves variation with opaque bounded output', () {
      const width = 5;
      const height = 5;
      const shades = [25, 70, 120, 180, 230];
      final frame = recolorRoomPhoto(
        key: _key,
        photo: _photo(width, height, [
          for (var y = 0; y < height; y++)
            for (final shade in shades) ...[shade, shade, shade, 255],
        ]),
        masks: _masks(
          width,
          height,
          List<int>.filled(width * height, RoomLayer.furniture.label),
        ),
        colors: RoomLayerColors(furniture: RgbColor.fromHex(target)),
      );

      for (var i = 0; i < frame.rgbaBytes.length; i += 4) {
        expect(frame.rgbaBytes[i + 3], 255);
      }
      expect(
        {
          for (var i = 0; i < frame.rgbaBytes.length; i += 4)
            (
              frame.rgbaBytes[i],
              frame.rgbaBytes[i + 1],
              frame.rgbaBytes[i + 2],
            ),
        }.length,
        greaterThan(1),
      );
    });
  }

  test('empty assigned layer stays unchanged and inputs stay detached', () {
    const width = 5;
    const height = 5;
    final source = _solidPixels(width, height, 20, 40, 60);
    final frame = recolorRoomPhoto(
      key: _key,
      photo: _photo(width, height, source),
      masks: _masks(
        width,
        height,
        List<int>.filled(width * height, RoomLayer.floor.label),
      ),
      colors: RoomLayerColors(wall: RgbColor.fromHex('#AA3300')),
    );

    source[0] = 255;
    expect(frame.rgbaBytes[0], 20);
    expect(() => frame.rgbaBytes[0] = 0, throwsUnsupportedError);
  });

  test('dimension mismatch is rejected before rendering', () {
    expect(
      () => recolorRoomPhoto(
        key: _key,
        photo: _photo(2, 2, _solidPixels(2, 2, 0, 0, 0)),
        masks: _masks(1, 1, [RoomLayer.wall.label]),
        colors: RoomLayerColors(wall: RgbColor(1, 2, 3)),
      ),
      throwsArgumentError,
    );
  });

  test('same request produces identical RGBA and PNG bytes', () {
    const width = 5;
    const height = 5;
    final photo = _photo(
      width,
      height,
      _solidPixels(width, height, 80, 90, 100),
    );
    final masks = _masks(
      width,
      height,
      List<int>.filled(width * height, RoomLayer.ceiling.label),
    );
    final colors = RoomLayerColors(ceiling: RgbColor.fromHex('#C5B7D0'));
    final first = recolorRoomPhoto(
      key: _key,
      photo: photo,
      masks: masks,
      colors: colors,
    );

    for (var run = 0; run < 10; run++) {
      final next = recolorRoomPhoto(
        key: _key,
        photo: photo,
        masks: masks,
        colors: colors,
      );
      expect(next.rgbaBytes, first.rgbaBytes);
      expect(next.pngBytes, first.pngBytes);
    }
  });
}
