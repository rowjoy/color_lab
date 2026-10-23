import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

typedef RoomShare =
    Future<void> Function({
      required Uint8List bytes,
      required String fileName,
      required String mimeType,
      required Rect origin,
    });

abstract interface class RoomImageExportService {
  Future<void> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
  });
}

final roomImageExportServiceProvider = Provider<RoomImageExportService>(
  (ref) => PlatformRoomImageExportService(),
);

final class PlatformRoomImageExportService implements RoomImageExportService {
  PlatformRoomImageExportService({RoomShare? share})
    : _share = share ?? _shareWithPlatform;

  final RoomShare _share;

  @override
  Future<void> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
  }) async {
    final bytes = Uint8List.fromList(pngBytes).asUnmodifiableView();
    if (!_hasPngSignature(bytes)) {
      throw ArgumentError.value(pngBytes, 'pngBytes', 'PNG bytes required');
    }
    await _share(
      bytes: bytes,
      fileName: 'color-lab-room-${_safeId(photoId)}.png',
      mimeType: 'image/png',
      origin: origin,
    );
  }

  static Future<void> _shareWithPlatform({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required Rect origin,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType)],
        fileNameOverrides: [fileName],
        title: 'Share room preview',
        subject: 'Color Lab room preview',
        sharePositionOrigin: origin,
      ),
    );
  }

  static bool _hasPngSignature(Uint8List bytes) {
    const signature = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  static String _safeId(String photoId) {
    var value = photoId
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceFirst(RegExp(r'^-+'), '')
        .replaceFirst(RegExp(r'-+$'), '');
    if (value.isEmpty) value = 'photo';
    return value.length <= 80 ? value : value.substring(0, 80);
  }
}
