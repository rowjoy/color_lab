import 'dart:typed_data';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PreparedPhoto fixture() => PreparedPhoto(
    width: 2,
    height: 2,
    rgbaBytes: Uint8List.fromList([
      255,
      0,
      0,
      255,
      0,
      255,
      0,
      255,
      0,
      0,
      255,
      255,
      255,
      255,
      0,
      255,
    ]),
    previewBytes: Uint8List.fromList([1]),
    palette: [PaletteColor(RgbColor(255, 0, 0), .25)],
  );

  test('samples the floor-mapped pixel and clips finite edge coordinates', () {
    final photo = fixture();
    expect(photo.sample(0, 0), RgbColor(255, 0, 0));
    expect(photo.sample(.499, .499), RgbColor(255, 0, 0));
    expect(photo.sample(.5, 0), RgbColor(0, 255, 0));
    expect(photo.sample(0, .5), RgbColor(0, 0, 255));
    expect(photo.sample(1, 1), RgbColor(255, 255, 0));
    expect(photo.sample(-2, 3), RgbColor(0, 0, 255));
  });

  test('rejects nonfinite sampling coordinates', () {
    final photo = fixture();
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(() => photo.sample(value, .5), throwsArgumentError);
      expect(() => photo.sample(.5, value), throwsArgumentError);
    }
  });

  test('takes immutable snapshots so callers cannot change sampled colors', () {
    final rgba = Uint8List.fromList([12, 34, 56, 255]);
    final preview = Uint8List.fromList([7, 8]);
    final palette = [PaletteColor(RgbColor(12, 34, 56), 1)];
    final photo = PreparedPhoto(
      width: 1,
      height: 1,
      rgbaBytes: rgba,
      previewBytes: preview,
      palette: palette,
    );
    rgba[0] = 0;
    preview[0] = 0;
    palette.clear();
    expect(photo.sample(0, 0), RgbColor(12, 34, 56));
    expect(photo.previewBytes, [7, 8]);
    expect(photo.palette.single.population, 1);
    expect(() => photo.rgbaBytes[0] = 1, throwsUnsupportedError);
    expect(
      () => photo.previewBytes.buffer.asUint8List()[0] = 1,
      throwsUnsupportedError,
    );
    expect(() => photo.palette.clear(), throwsUnsupportedError);
  });

  test('rejects invalid dimensions and incomplete RGBA buffers', () {
    for (final dimensions in [(0, 1), (1, -1), (2, 1)]) {
      expect(
        () => PreparedPhoto(
          width: dimensions.$1,
          height: dimensions.$2,
          rgbaBytes: Uint8List(4),
          previewBytes: Uint8List(1),
          palette: [],
        ),
        throwsArgumentError,
      );
    }
  });
}
