import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../../features/picker/domain/prepared_photo.dart';
import '../color/color_models.dart';
import '../color/palette_extractor.dart';

const maxPhotoEncodedBytes = 32 * 1024 * 1024;
const maxPhotoDecodedPixels = 24000000;
const maxPhotoDecodedAxis = 16384;
const maxPhotoPreviewAxis = 1600;
const maxPhotoPaletteAxis = 200;

enum PhotoProcessingFailure { invalidImage, tooLarge, unsupported }

/// A safe category for user-facing recovery; never contains codec internals.
final class PhotoProcessingException implements Exception {
  const PhotoProcessingException(this.kind);

  final PhotoProcessingFailure kind;

  @override
  String toString() => 'PhotoProcessingException(${kind.name})';
}

/// Pure Dart entry point suitable for a worker isolate.
///
/// Only frame zero is decoded. Header dimensions and decoder pixel budgets
/// bound allocations before pixel decoding, then oriented output is limited
/// to 1600px and the seeded LAB palette input to 200px on its longest side.
PreparedPhoto preparePhoto(Uint8List bytes) {
  if (bytes.length > maxPhotoEncodedBytes) {
    throw const PhotoProcessingException(PhotoProcessingFailure.tooLarge);
  }
  try {
    final decoder = _decoderFor(bytes);
    final info = decoder.startDecode(bytes);
    if (info == null) {
      throw const PhotoProcessingException(PhotoProcessingFailure.invalidImage);
    }
    _checkDimensions(info.width, info.height);
    final decoded = _decodeFirstFrame(decoder, info, bytes);
    if (decoded == null) {
      throw const PhotoProcessingException(PhotoProcessingFailure.invalidImage);
    }
    _checkDimensions(decoded.width, decoded.height);
    final opaque = _firstFrameCanvas(_flattenWhite(decoded), info);
    final orientation = opaque.exif.imageIfd.orientation;
    final oriented = orientation != null && orientation != 1
        ? image.bakeOrientation(opaque)
        : opaque;
    // Sampling interprets decoded channel values as sRGB. Emit the same
    // untagged RGB, preventing a renderer from applying a source ICC profile
    // to the PNG while color values are interpreted differently by the app.
    // Wide-gamut profile conversion is intentionally outside this pipeline.
    final fitted = _fit(oriented, maxPhotoPreviewAxis);
    // Copy channels, never a source Image's metadata/frames. JPEG's decoder
    // already baked EXIF orientation; other decoders are handled above.
    final preview = image.Image.fromBytes(
      width: fitted.width,
      height: fitted.height,
      bytes: fitted.getBytes(order: image.ChannelOrder.rgb).buffer,
      numChannels: 3,
      order: image.ChannelOrder.rgb,
    );
    final paletteImage = _fit(preview, maxPhotoPaletteAxis);
    final palette = extractPalette(
      [
        for (final pixel in paletteImage)
          RgbColor(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()),
      ],
      k: 8,
      seed: 42,
      mergeThreshold: 8,
    );
    return PreparedPhoto(
      width: preview.width,
      height: preview.height,
      rgbaBytes: preview.getBytes(order: image.ChannelOrder.rgba),
      previewBytes: image.encodePng(preview),
      palette: palette,
    );
  } on PhotoProcessingException {
    rethrow;
  } on image.ImageException catch (error) {
    // image 4.12 enforces pixel budgets in header/frame parsers too, before
    // returning DecodeInfo (including nested animation/tile dimensions).
    final isBudget =
        error.message.contains('exceed') && error.message.contains('pixel');
    throw PhotoProcessingException(
      isBudget
          ? PhotoProcessingFailure.tooLarge
          : PhotoProcessingFailure.invalidImage,
    );
  } on FormatException {
    throw const PhotoProcessingException(PhotoProcessingFailure.invalidImage);
  } on RangeError {
    throw const PhotoProcessingException(PhotoProcessingFailure.invalidImage);
  }
}

void _checkDimensions(int width, int height) {
  if (width < 1 || height < 1) {
    throw const PhotoProcessingException(PhotoProcessingFailure.invalidImage);
  }
  if (width > maxPhotoDecodedAxis ||
      height > maxPhotoDecodedAxis ||
      width * height > maxPhotoDecodedPixels) {
    throw const PhotoProcessingException(PhotoProcessingFailure.tooLarge);
  }
}

bool _starts(Uint8List bytes, List<int> signature, [int offset = 0]) {
  if (bytes.length < offset + signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[offset + i] != signature[i]) return false;
  }
  return true;
}

image.Decoder _decoderFor(Uint8List bytes) {
  if (_starts(bytes, [0xff, 0xd8])) {
    return image.JpegDecoder(maxPixels: maxPhotoDecodedPixels);
  }
  if (_starts(bytes, [137, 80, 78, 71, 13, 10, 26, 10])) {
    return image.PngDecoder(maxPixels: maxPhotoDecodedPixels);
  }
  if (_starts(bytes, [71, 73, 70, 56])) {
    return image.GifDecoder()..maxPixels = maxPhotoDecodedPixels;
  }
  if (_starts(bytes, [82, 73, 70, 70]) && _starts(bytes, [87, 69, 66, 80], 8)) {
    return image.WebPDecoder()..maxPixels = maxPhotoDecodedPixels;
  }
  if (_starts(bytes, [66, 77])) {
    return image.BmpDecoder(maxPixels: maxPhotoDecodedPixels);
  }
  if (_starts(bytes, [73, 73, 42, 0]) || _starts(bytes, [77, 77, 0, 42])) {
    return image.TiffDecoder(maxPixels: maxPhotoDecodedPixels);
  }
  if (_starts(bytes, [102, 116, 121, 112], 4) ||
      _starts(bytes, [56, 66, 80, 83])) {
    // HEIF/HEIC/AVIF containers and PSD require a different decoder.
    throw const PhotoProcessingException(PhotoProcessingFailure.unsupported);
  }
  throw const PhotoProcessingException(PhotoProcessingFailure.invalidImage);
}

image.Image _flattenWhite(image.Image source) {
  if (!source.hasAlpha &&
      !source.hasPalette &&
      source.format == image.Format.uint8) {
    return source;
  }
  final opaque = image.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
    exif: source.exif,
  );
  for (final pixel in source) {
    final alpha = source.hasAlpha ? pixel.aNormalized.clamp(0, 1) : 1.0;
    int channel(num normalized) =>
        (255 * (normalized * alpha + 1 - alpha)).round().clamp(0, 255);
    opaque.setPixelRgb(
      pixel.x,
      pixel.y,
      channel(pixel.rNormalized),
      channel(pixel.gNormalized),
      channel(pixel.bNormalized),
    );
  }
  return opaque;
}

image.Image? _decodeFirstFrame(
  image.Decoder decoder,
  image.DecodeInfo info,
  Uint8List bytes,
) {
  if (info is! image.WebPInfo || !info.hasAnimation) {
    return decoder.decodeFrame(0);
  }
  // image 4.12's animated WebP path decodes its embedded VP8/VP8L stream
  // without a pixel budget. Rewrap frame zero as a still image so that its
  // actual bitstream dimensions pass a bounded header parser before decode.
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final size = data.getUint32(offset + 4, Endian.little);
    final end = offset + 8 + size;
    if (end > bytes.length) break;
    if (_starts(bytes, [65, 78, 77, 70], offset)) {
      if (size < 16 || info.frames.isEmpty) break;
      final start = offset + 24;
      var chunk = start;
      var bitstreams = 0;
      while (chunk + 8 <= end) {
        final chunkSize = data.getUint32(chunk + 4, Endian.little);
        if (chunk + 8 + chunkSize > end) break;
        if (_starts(bytes, [86, 80, 56, 76], chunk) ||
            _starts(bytes, [86, 80, 56, 32], chunk)) {
          bitstreams++;
        } else if (!_starts(bytes, [65, 76, 80, 72], chunk)) {
          break;
        }
        chunk += 8 + chunkSize + (chunkSize.isOdd ? 1 : 0);
      }
      if (chunk != end || bitstreams != 1) break;
      final still = Uint8List(12 + end - start);
      still.setRange(0, 12, [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]);
      ByteData.sublistView(still).setUint32(4, still.length - 8, Endian.little);
      still.setRange(12, still.length, bytes, start);
      final bounded = image.WebPDecoder()..maxPixels = maxPhotoDecodedPixels;
      final header = bounded.startDecode(still);
      if (header == null) break;
      _checkDimensions(header.width, header.height);
      final frame = info.frames.first;
      if (header.width != frame.width || header.height != frame.height) break;
      final decoded = bounded.decodeFrame(0);
      if (decoded != null && info.exif.isNotEmpty) {
        decoded.exif = image.ExifData.fromInputBuffer(
          image.InputBuffer(info.exif.codeUnits),
        );
      }
      return decoded;
    }
    offset = end + (size.isOdd ? 1 : 0);
  }
  throw const PhotoProcessingException(PhotoProcessingFailure.invalidImage);
}

image.Image _firstFrameCanvas(image.Image frame, image.DecodeInfo info) {
  final (int x, int y) = switch (info) {
    image.GifInfo(:final frames) when frames.isNotEmpty => (
      frames.first.x,
      frames.first.y,
    ),
    image.WebPInfo(:final frames) when frames.isNotEmpty => (
      frames.first.x,
      frames.first.y,
    ),
    _ => (0, 0),
  };
  // JPEG's decoder already applies EXIF, so its header axes can differ from
  // the returned image. Only animation frames need canvas placement.
  if (info is! image.GifInfo && info is! image.WebPInfo) return frame;
  if (x < 0 ||
      y < 0 ||
      x + frame.width > info.width ||
      y + frame.height > info.height) {
    throw const PhotoProcessingException(PhotoProcessingFailure.invalidImage);
  }
  if (x == 0 &&
      y == 0 &&
      frame.width == info.width &&
      frame.height == info.height) {
    return frame;
  }
  final canvas = image.Image(
    width: info.width,
    height: info.height,
    exif: frame.exif,
  )..clear(image.ColorRgb8(255, 255, 255));
  return image.compositeImage(canvas, frame, dstX: x, dstY: y);
}

image.Image _fit(image.Image source, int longestAxis) {
  final longest = math.max(source.width, source.height);
  if (longest <= longestAxis) return source;
  final scale = longestAxis / longest;
  return image.copyResize(
    source,
    width: math.max(1, (source.width * scale).round()),
    height: math.max(1, (source.height * scale).round()),
    interpolation: image.Interpolation.average,
  );
}
