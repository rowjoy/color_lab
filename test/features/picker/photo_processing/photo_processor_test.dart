import 'dart:typed_data';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/image/photo_processing.dart';
import 'package:color_lab/features/picker/application/photo_processor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('isolate adapter returns the prepared pixel result', () async {
    final input = image.Image(width: 1, height: 1)
      ..setPixelRgb(0, 0, 12, 34, 56);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final photo = await container
        .read(photoProcessorProvider)
        .prepare(image.encodePng(input));
    expect(photo.sample(.5, .5), RgbColor(12, 34, 56));
    expect(photo.palette.single.population, 1);
    expect(() => photo.rgbaBytes[0] = 0, throwsUnsupportedError);
  });

  test('isolate adapter preserves safe processing failure category', () async {
    await expectLater(
      IsolatePhotoProcessor().prepare(Uint8List(0)),
      throwsA(
        isA<PhotoProcessingException>().having(
          (error) => error.kind,
          'kind',
          PhotoProcessingFailure.invalidImage,
        ),
      ),
    );
  });

  test(
    'snapshots caller bytes before asynchronous processing begins',
    () async {
      final input = image.Image(width: 1, height: 1)
        ..setPixelRgb(0, 0, 98, 76, 54);
      final bytes = image.encodePng(input);
      final result = IsolatePhotoProcessor().prepare(bytes);
      bytes.fillRange(0, bytes.length, 0);
      final photo = await result;
      expect(photo.sample(.5, .5), RgbColor(98, 76, 54));
    },
  );
}
