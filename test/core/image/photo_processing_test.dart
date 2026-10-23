import 'dart:typed_data';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/image/photo_processing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  Matcher fails(PhotoProcessingFailure kind) => throwsA(
    isA<PhotoProcessingException>().having((error) => error.kind, 'kind', kind),
  );

  test('preserves literal pixels in preview and sampling RGBA', () {
    final input = image.Image(width: 2, height: 2, numChannels: 3)
      ..setPixelRgb(0, 0, 255, 0, 0)
      ..setPixelRgb(1, 0, 0, 255, 0)
      ..setPixelRgb(0, 1, 0, 0, 255)
      ..setPixelRgb(1, 1, 255, 255, 0);
    final photo = preparePhoto(image.encodePng(input));
    expect((photo.width, photo.height), (2, 2));
    expect(photo.rgbaBytes, [
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
    ]);
    final preview = image.decodePng(photo.previewBytes)!;
    expect((preview.width, preview.height), (2, 2));
    expect(preview.getBytes(order: image.ChannelOrder.rgba), photo.rgbaBytes);
  });

  test('emits untagged display RGB so preview and sampled channels agree', () {
    final input = image.Image(width: 1, height: 1)
      ..setPixelRgb(0, 0, 12, 34, 56)
      ..iccProfile = image.IccProfile(
        'source profile',
        image.IccProfileCompression.none,
        Uint8List.fromList([1, 2, 3]),
      );
    final photo = preparePhoto(image.encodePng(input));
    final preview = image.decodePng(photo.previewBytes)!;
    expect(preview.iccProfile, isNull);
    expect(photo.sample(.5, .5), RgbColor(12, 34, 56));
  });

  test('composites partial and fully transparent pixels over white', () {
    final input = image.Image(width: 3, height: 1, numChannels: 4)
      ..setPixelRgba(0, 0, 255, 0, 0, 128)
      ..setPixelRgba(1, 0, 10, 20, 30, 0)
      ..setPixelRgba(2, 0, 10, 20, 30, 255);
    final photo = preparePhoto(image.encodePng(input));
    expect(photo.rgbaBytes, [
      255,
      127,
      127,
      255,
      255,
      255,
      255,
      255,
      10,
      20,
      30,
      255,
    ]);
    expect(
      image
          .decodePng(photo.previewBytes)!
          .getBytes(order: image.ChannelOrder.rgba),
      photo.rgbaBytes,
    );
  });

  test('reports actual color populations without inventing swatches', () {
    final input = image.Image(width: 4, height: 1, numChannels: 3)
      ..setPixelRgb(0, 0, 255, 0, 0)
      ..setPixelRgb(1, 0, 255, 0, 0)
      ..setPixelRgb(2, 0, 255, 0, 0)
      ..setPixelRgb(3, 0, 0, 0, 255);
    final bytes = image.encodePng(input);
    final first = preparePhoto(bytes).palette;
    final second = preparePhoto(bytes).palette;
    expect(first.length, 2);
    expect(first[0].color, RgbColor(255, 0, 0));
    expect(first[0].population, .75);
    expect(first[1].color, RgbColor(0, 0, 255));
    expect(first[1].population, .25);
    expect(
      second.map((entry) => (entry.color, entry.population)),
      first.map((entry) => (entry.color, entry.population)),
    );
  });

  test('bounds the preview with the same aspect ratio and sample pixels', () {
    final input = image.Image(width: 1800, height: 900, numChannels: 3)
      ..clear(image.ColorRgb8(42, 67, 89));
    final photo = preparePhoto(image.encodePng(input));
    expect((photo.width, photo.height), (1600, 800));
    expect(photo.rgbaBytes.length, 1600 * 800 * 4);
    expect(photo.sample(1, 1), RgbColor(42, 67, 89));
    final preview = image.decodePng(photo.previewBytes)!;
    expect((preview.width, preview.height), (1600, 800));
  });

  test('preserves one-pixel dimension when downsizing very thin images', () {
    final input = image.Image(width: 3000, height: 1)
      ..clear(image.ColorRgb8(33, 66, 99));
    final photo = preparePhoto(image.encodePng(input));
    expect((photo.width, photo.height), (1600, 1));
    expect(photo.sample(.5, .5), RgbColor(33, 66, 99));
  });

  test('palette downsizing keeps actual area proportions on a large image', () {
    final input = image.Image(width: 400, height: 100, numChannels: 3);
    for (final pixel in input) {
      pixel.setRgb(pixel.x < 300 ? 255 : 0, 0, pixel.x < 300 ? 0 : 255);
    }
    final photo = preparePhoto(image.encodePng(input));
    expect(photo.palette.length, 2);
    expect(photo.palette[0].population, .75);
    expect(photo.palette[1].population, .25);
  });

  final orientations = <int, List<int>>{
    1: [0, 1, 2, 3],
    2: [1, 0, 3, 2],
    3: [3, 2, 1, 0],
    4: [2, 3, 0, 1],
    5: [0, 2, 1, 3],
    6: [2, 0, 3, 1],
    7: [3, 1, 2, 0],
    8: [1, 3, 0, 2],
  };
  final colors = [
    RgbColor(255, 0, 0),
    RgbColor(0, 255, 0),
    RgbColor(0, 0, 255),
    RgbColor(255, 255, 0),
  ];
  for (final entry in orientations.entries) {
    test('bakes JPEG EXIF orientation ${entry.key} exactly once', () {
      final input = image.Image(width: 32, height: 16, numChannels: 3);
      for (final pixel in input) {
        final color = colors[(pixel.y < 8 ? 0 : 2) + (pixel.x < 16 ? 0 : 1)];
        pixel.setRgb(color.red, color.green, color.blue);
      }
      input.exif.imageIfd.orientation = entry.key;
      final photo = preparePhoto(image.encodeJpg(input, quality: 100));
      expect((photo.width, photo.height), entry.key < 5 ? (32, 16) : (16, 32));
      final positions = [(0.25, 0.25), (.75, .25), (.25, .75), (.75, .75)];
      for (var i = 0; i < positions.length; i++) {
        final actual = photo.sample(positions[i].$1, positions[i].$2);
        final expected = colors[entry.value[i]];
        expect(actual.red, closeTo(expected.red, 3));
        expect(actual.green, closeTo(expected.green, 3));
        expect(actual.blue, closeTo(expected.blue, 3));
      }
      final preview = image.decodePng(photo.previewBytes)!;
      expect(preview.getBytes(order: image.ChannelOrder.rgba), photo.rgbaBytes);
    });
  }

  test('samples only the first frame of an animated image', () {
    // Explicit palettes avoid an encoder's lossy tiny-image quantization.
    final first = image.Image(width: 2, height: 1, withPalette: true)
      ..palette!.setRgb(0, 255, 0, 0);
    first.addFrame(
      image.Image(width: 2, height: 1, withPalette: true)
        ..palette!.setRgb(0, 0, 0, 255),
    );
    final bytes = image.encodeGif(first);
    final photo = preparePhoto(bytes);
    expect(photo.sample(.5, .5), RgbColor(255, 0, 0));
    expect(photo.palette.single.population, 1);
    expect(image.decodePng(photo.previewBytes)!.numFrames, 1);
  });

  test('places a partial first GIF frame on its transparent canvas', () {
    final first = image.Image(width: 2, height: 1, withPalette: true)
      ..palette!.setRgb(0, 255, 0, 0);
    final bytes = image.encodeGif(first);
    final data = ByteData.sublistView(bytes);
    data.setUint16(6, 4, Endian.little);
    data.setUint16(8, 2, Endian.little);
    final descriptor = bytes.indexOf(0x2c);
    data.setUint16(descriptor + 1, 1, Endian.little);
    data.setUint16(descriptor + 3, 1, Endian.little);
    final photo = preparePhoto(bytes);
    expect((photo.width, photo.height), (4, 2));
    expect(photo.sample(0, 0), RgbColor(255, 255, 255));
    expect(photo.sample(.25, .5), RgbColor(255, 0, 0));
    expect(photo.sample(.75, .5), RgbColor(255, 255, 255));
    expect(photo.palette.first.population, .75);
  });

  test('samples the first WebP frame and preserves container EXIF', () {
    final first = image.Image(width: 2, height: 1)
      ..setPixelRgb(0, 0, 255, 0, 0)
      ..setPixelRgb(1, 0, 0, 0, 255);
    first.exif.imageIfd.orientation = 6;
    first.addFrame(
      image.Image(width: 2, height: 1)..clear(image.ColorRgb8(0, 255, 0)),
    );
    final photo = preparePhoto(image.encodeWebP(first));
    expect((photo.width, photo.height), (1, 2));
    expect(photo.sample(0, 0), RgbColor(255, 0, 0));
    expect(photo.sample(0, 1), RgbColor(0, 0, 255));
  });

  test('applies EXIF after placing a partial WebP frame on its canvas', () {
    final first = image.Image(width: 2, height: 1)
      ..setPixelRgb(0, 0, 255, 0, 0)
      ..setPixelRgb(1, 0, 0, 0, 255);
    first.exif.imageIfd.orientation = 6;
    first.addFrame(
      image.Image(width: 2, height: 1)..clear(image.ColorRgb8(0, 255, 0)),
    );
    final bytes = image.encodeWebP(first);
    bytes[24] = 3; // VP8X canvas width minus one.
    bytes[27] = 1; // VP8X canvas height minus one.
    final frame = String.fromCharCodes(bytes).indexOf('ANMF');
    bytes[frame + 8] = 1; // x offset is stored divided by two.
    final photo = preparePhoto(bytes);
    expect((photo.width, photo.height), (2, 4));
    expect(photo.sample(.75, .5), RgbColor(255, 0, 0));
    expect(photo.sample(.75, .75), RgbColor(0, 0, 255));
    expect(photo.sample(0, 0), RgbColor(255, 255, 255));
  });

  test('bounds the embedded bitstream of a WebP animation before decoding', () {
    final first = image.Image(width: 2, height: 1)
      ..clear(image.ColorRgb8(255, 0, 0));
    first.addFrame(
      image.Image(width: 2, height: 1)..clear(image.ColorRgb8(0, 0, 255)),
    );
    final bytes = image.encodeWebP(first);
    final bitstream = String.fromCharCodes(bytes).indexOf('VP8L') + 8;
    expect(bitstream, greaterThan(8));
    // Outer canvas and ANMF descriptor still declare only 2x1. The nested
    // VP8L header claims 5000x5000 with the original tiny encoded payload.
    ByteData.sublistView(
      bytes,
    ).setUint32(bitstream + 1, 4999 | (4999 << 14), Endian.little);
    expect(() => preparePhoto(bytes), fails(PhotoProcessingFailure.tooLarge));
  });

  test('normalizes indexed transparency to opaque display channels', () {
    final input = image.Image(
      width: 2,
      height: 1,
      numChannels: 4,
      withPalette: true,
    );
    input.palette!
      ..setRgba(0, 99, 33, 11, 0)
      ..setRgba(1, 0, 0, 255, 128);
    input.setPixelIndex(1, 0, 1);
    final photo = preparePhoto(image.encodePng(input));
    expect(photo.rgbaBytes, [255, 255, 255, 255, 127, 127, 255, 255]);
  });

  test('normalizes 16-bit channels before composing transparency', () {
    final input = image.Image(
      width: 1,
      height: 1,
      numChannels: 4,
      format: image.Format.uint16,
    )..setPixelRgba(0, 0, 65535, 0, 0, 32768);
    final photo = preparePhoto(image.encodePng(input));
    expect(photo.rgbaBytes, [255, 127, 127, 255]);
  });

  test('flattens hidden transparent RGB before downsampling', () {
    final input = image.Image(width: 3200, height: 1, numChannels: 4);
    for (final pixel in input) {
      pixel.setRgba(
        pixel.x.isEven ? 255 : 0,
        0,
        pixel.x.isEven ? 0 : 255,
        pixel.x.isEven ? 255 : 0,
      );
    }
    final photo = preparePhoto(image.encodePng(input));
    expect(photo.sample(.5, .5), RgbColor(255, 127, 127));
  });

  test('rejects an oversized PNG directly from its header', () {
    final bytes = image.encodePng(image.Image(width: 1, height: 1));
    final data = ByteData.sublistView(bytes);
    data.setUint32(16, 6000);
    data.setUint32(20, 5000);
    expect(() => preparePhoto(bytes), fails(PhotoProcessingFailure.tooLarge));
  });

  test('rejects corrupt or empty inputs with a safe typed error', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    ]) {
      expect(
        () => preparePhoto(bytes),
        fails(PhotoProcessingFailure.invalidImage),
      );
    }
  });

  test('reports a known unsupported HEIC container safely', () {
    expect(
      () => preparePhoto(
        Uint8List.fromList([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          104,
          101,
          105,
          99,
          0,
          0,
          0,
          0,
          104,
          101,
          105,
          99,
          109,
          105,
          102,
          49,
        ]),
      ),
      fails(PhotoProcessingFailure.unsupported),
    );
  });

  test('rejects encoded files larger than 32 MiB', () {
    expect(
      () => preparePhoto(Uint8List(32 * 1024 * 1024 + 1)),
      fails(PhotoProcessingFailure.tooLarge),
    );
  });

  test(
    'rejects decoded pixel and axis bombs from header before pixel decode',
    () {
      final original = image.encodeBmp(image.Image(width: 1, height: 1));
      for (final dimensions in [(6000, 5000), (17000, 1)]) {
        final bytes = Uint8List.fromList(original);
        final data = ByteData.sublistView(bytes);
        data.setInt32(18, dimensions.$1, Endian.little);
        data.setInt32(22, dimensions.$2, Endian.little);
        // Payload still contains only a single pixel. A pixel decode would fail
        // as truncated; tooLarge proves rejection happened from header metadata.
        expect(
          () => preparePhoto(bytes),
          fails(PhotoProcessingFailure.tooLarge),
        );
      }
    },
  );
}
