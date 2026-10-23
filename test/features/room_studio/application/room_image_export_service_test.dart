import 'dart:typed_data';

import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shares detached PNG bytes with safe deterministic metadata', () async {
    Uint8List? sharedBytes;
    String? sharedName;
    String? sharedMimeType;
    Rect? sharedOrigin;
    final service = PlatformRoomImageExportService(
      share:
          ({
            required bytes,
            required fileName,
            required mimeType,
            required origin,
          }) async {
            sharedBytes = bytes;
            sharedName = fileName;
            sharedMimeType = mimeType;
            sharedOrigin = origin;
          },
    );
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
      17,
      23,
    ]);
    const origin = Rect.fromLTWH(12, 24, 80, 48);

    await service.sharePng(
      pngBytes: png,
      photoId: '../Room / north #1',
      origin: origin,
    );
    png[8] = 99;

    expect(
      sharedBytes,
      orderedEquals([0x89, 0x50, 0x4e, 0x47, 13, 10, 26, 10, 17, 23]),
    );
    expect(sharedName, 'color-lab-room-Room-north-1.png');
    expect(sharedMimeType, 'image/png');
    expect(sharedOrigin, origin);
    expect(() => sharedBytes![0] = 0, throwsUnsupportedError);
  });

  test('rejects non-PNG bytes before opening the share sheet', () async {
    var shared = false;
    final service = PlatformRoomImageExportService(
      share:
          ({
            required bytes,
            required fileName,
            required mimeType,
            required origin,
          }) async {
            shared = true;
          },
    );

    await expectLater(
      service.sharePng(
        pngBytes: Uint8List.fromList([1, 2, 3]),
        photoId: 'photo',
        origin: const Rect.fromLTWH(0, 0, 1, 1),
      ),
      throwsArgumentError,
    );
    expect(shared, isFalse);
  });
}
