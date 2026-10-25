import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as permission;

enum RoomGalleryFailure {
  accessDenied,
  notEnoughSpace,
  unsupportedFormat,
  unsupportedPlatform,
  unexpected,
}

final class RoomGalleryWriteException implements Exception {
  const RoomGalleryWriteException(this.failure);

  final RoomGalleryFailure failure;

  @override
  String toString() => 'RoomGalleryWriteException: ${failure.name}';
}

abstract interface class RoomGalleryWriter {
  Future<void> savePng({required Uint8List pngBytes, required String fileName});
}

typedef GalPutImage = Future<void> Function(String path, {String? album});
typedef TemporaryRootProvider = Future<Directory> Function();
typedef OwnedDirectoryCleanup = Future<void> Function(Directory directory);
typedef RoomGallerySettings = Future<bool> Function();

final roomGalleryWriterProvider = Provider<RoomGalleryWriter>(
  (ref) => GalRoomGalleryWriter(),
);

final roomGallerySettingsProvider = Provider<RoomGallerySettings>(
  (ref) => permission.openAppSettings,
);

final class GalRoomGalleryWriter implements RoomGalleryWriter {
  GalRoomGalleryWriter({
    GalPutImage? putImage,
    TemporaryRootProvider? temporaryRoot,
    OwnedDirectoryCleanup? cleanupOwnedDirectory,
    TargetPlatform? platform,
    bool? isWeb,
  }) : _putImage = putImage ?? Gal.putImage,
       _temporaryRoot = temporaryRoot ?? getTemporaryDirectory,
       _cleanupOwnedDirectory = cleanupOwnedDirectory ?? _deleteOwnedDirectory,
       _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb;

  static const _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  static final _safePngName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,195}\.png$');

  final GalPutImage _putImage;
  final TemporaryRootProvider _temporaryRoot;
  final OwnedDirectoryCleanup _cleanupOwnedDirectory;
  final TargetPlatform _platform;
  final bool _isWeb;

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String fileName,
  }) {
    try {
      _validate(pngBytes, fileName);
      if (_isWeb ||
          (_platform != TargetPlatform.android &&
              _platform != TargetPlatform.iOS)) {
        throw const RoomGalleryWriteException(
          RoomGalleryFailure.unsupportedPlatform,
        );
      }
      // Own the bytes before returning or awaiting so caller mutation cannot
      // change the file that reaches the native Gallery boundary.
      final detached = Uint8List.fromList(pngBytes);
      return _writeOwnedTemp(detached, fileName);
    } catch (error, stackTrace) {
      return Future<void>.error(_mapped(error), stackTrace);
    }
  }

  Future<void> _writeOwnedTemp(Uint8List bytes, String fileName) async {
    Directory? ownedDirectory;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    try {
      final root = await _temporaryRoot();
      ownedDirectory = await root.createTemp('color-lab-gallery-');
      final file = File.fromUri(ownedDirectory.uri.resolve(fileName));
      await file.writeAsBytes(bytes, flush: true);
      await _putImage(file.path);
    } catch (error, stackTrace) {
      primaryError = _mapped(error);
      primaryStackTrace = stackTrace;
    }

    if (ownedDirectory != null) {
      try {
        await _cleanupOwnedDirectory(ownedDirectory);
      } catch (_) {
        // The native Gallery result is authoritative. Cleanup is best effort;
        // reporting a failure after a successful save would invite duplicates.
      }
    }

    if (primaryError != null) {
      Error.throwWithStackTrace(primaryError, primaryStackTrace!);
    }
  }

  static Future<void> _deleteOwnedDirectory(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  static void _validate(Uint8List bytes, String fileName) {
    if (bytes.length < _pngSignature.length) {
      throw const RoomGalleryWriteException(
        RoomGalleryFailure.unsupportedFormat,
      );
    }
    for (var index = 0; index < _pngSignature.length; index++) {
      if (bytes[index] != _pngSignature[index]) {
        throw const RoomGalleryWriteException(
          RoomGalleryFailure.unsupportedFormat,
        );
      }
    }
    if (!_safePngName.hasMatch(fileName)) {
      throw const RoomGalleryWriteException(
        RoomGalleryFailure.unsupportedFormat,
      );
    }
  }

  static RoomGalleryWriteException _mapped(Object error) {
    if (error is RoomGalleryWriteException) return error;
    if (error is MissingPluginException) {
      return const RoomGalleryWriteException(
        RoomGalleryFailure.unsupportedPlatform,
      );
    }
    if (error is GalException) {
      return RoomGalleryWriteException(switch (error.type) {
        GalExceptionType.accessDenied => RoomGalleryFailure.accessDenied,
        GalExceptionType.notEnoughSpace => RoomGalleryFailure.notEnoughSpace,
        GalExceptionType.notSupportedFormat =>
          RoomGalleryFailure.unsupportedFormat,
        GalExceptionType.unexpected => RoomGalleryFailure.unexpected,
      });
    }
    return const RoomGalleryWriteException(RoomGalleryFailure.unexpected);
  }
}
