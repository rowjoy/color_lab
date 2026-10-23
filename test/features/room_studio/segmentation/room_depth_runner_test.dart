import 'dart:typed_data';

import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/segmentation/room_depth_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'normalizes RGB in channel order without semantic letterbox padding',
    () {
      final photo = PreparedPhoto(
        width: 1,
        height: 1,
        rgbaBytes: Uint8List.fromList([115, 173, 57, 255]),
        previewBytes: Uint8List(0),
        palette: const [],
      );
      final input = prepareRoomDepthInput(photo);
      expect(input.length, 256 * 256 * 3);
      expect(
        input.indexed.every((e) => e.$2 == const [0, 1, -1][e.$1 % 3]),
        isTrue,
      );
      expect(photo.rgbaBytes, [115, 173, 57, 255]);
    },
  );

  test(
    'rejects unverified model bytes before native interpreter allocation',
    () {
      expect(() => TfliteRoomDepthRunner(Uint8List(8)), throwsFormatException);
    },
  );
}
