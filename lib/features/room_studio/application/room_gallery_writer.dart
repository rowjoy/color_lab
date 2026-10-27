import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as permission;

final class RoomExportInterrupted implements Exception {
  const RoomExportInterrupted();
}

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
    Future<bool> Function()? requestAccess,
  }) : _putImage = putImage ?? _terminalPutImage,
       _requestAccess =
           requestAccess ??
           (putImage == null
               ? () => Gal.requestAccess(toAlbum: false)
               : () async => true),
       _temporaryRoot = temporaryRoot ?? getTemporaryDirectory,
       _cleanupOwnedDirectory = cleanupOwnedDirectory ?? _deleteOwnedDirectory,
       _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb;

  static const _pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  static final _safePngName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,195}\.png$');

  final GalPutImage _putImage;
  final Future<bool> Function() _requestAccess;
  static const _channel = MethodChannel('gal');

  // Locked gal 2.3.2 public protocol. Permission is a separate preparation
  // stage; there must be no application await between guard and invocation.
  static Future<void> _terminalPutImage(String path, {String? album}) =>
      _channel.invokeMethod<void>('putImage', {'path': path, 'album': album});

  Future<void> prepareAccess({required bool Function() isCurrent}) async {
    try {
      if (!isCurrent()) throw const RoomExportInterrupted();
      final granted = await _requestAccess();
      if (!isCurrent()) throw const RoomExportInterrupted();
      if (!granted) {
        throw const RoomGalleryWriteException(RoomGalleryFailure.accessDenied);
      }
    } on RoomExportInterrupted {
      rethrow;
    } catch (error) {
      throw _mapped(error);
    }
  }

  Future<void> savePreparedPng({
    required Uint8List pngBytes,
    required String fileName,
    required bool Function() beforeHandoff,
    bool Function()? isCurrent,
  }) {
    _validate(pngBytes, fileName);
    _checkPlatform();
    return _writeOwnedTemp(
      Uint8List.fromList(pngBytes),
      fileName,
      beforeHandoff: beforeHandoff,
      isCurrent: isCurrent,
    );
  }

  void _checkPlatform() {
    if (_isWeb ||
        (_platform != TargetPlatform.android &&
            _platform != TargetPlatform.iOS)) {
      throw const RoomGalleryWriteException(
        RoomGalleryFailure.unsupportedPlatform,
      );
    }
  }

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
      return _save(detached, fileName);
    } catch (error, stackTrace) {
      return Future<void>.error(_mapped(error), stackTrace);
    }
  }

  Future<void> _save(Uint8List bytes, String fileName) async {
    await prepareAccess(isCurrent: () => true);
    await _writeOwnedTemp(bytes, fileName);
  }

  Future<void> _writeOwnedTemp(
    Uint8List bytes,
    String fileName, {
    bool Function()? beforeHandoff,
    bool Function()? isCurrent,
  }) async {
    Directory? ownedDirectory;
    Object? primaryError;
    StackTrace? primaryStackTrace;
    try {
      final root = await _temporaryRoot();
      if (!(isCurrent?.call() ?? true)) throw const RoomExportInterrupted();
      ownedDirectory = await root.createTemp('tintatlas-gallery-');
      if (!(isCurrent?.call() ?? true)) throw const RoomExportInterrupted();
      final file = File.fromUri(ownedDirectory.uri.resolve(fileName));
      await file.writeAsBytes(bytes, flush: true);
      if (!(beforeHandoff?.call() ?? true)) throw const RoomExportInterrupted();
      await _putImage(file.path);
    } catch (error, stackTrace) {
      primaryError = error is RoomExportInterrupted ? error : _mapped(error);
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
    if (error is PlatformException) {
      return RoomGalleryWriteException(switch (error.code) {
        'ACCESS_DENIED' => RoomGalleryFailure.accessDenied,
        'NOT_ENOUGH_SPACE' => RoomGalleryFailure.notEnoughSpace,
        'NOT_SUPPORTED_FORMAT' => RoomGalleryFailure.unsupportedFormat,
        _ => RoomGalleryFailure.unexpected,
      });
    }
    if (error is FileSystemException &&
        [28, 112].contains(error.osError?.errorCode)) {
      return const RoomGalleryWriteException(RoomGalleryFailure.notEnoughSpace);
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
