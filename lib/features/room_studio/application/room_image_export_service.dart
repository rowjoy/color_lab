import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'room_export_metadata_verifier.dart';
import 'room_gallery_writer.dart';
export 'room_gallery_writer.dart' show RoomExportInterrupted;

enum RoomShareResult { completed, dismissed, unavailable }

final class RoomShareException implements Exception {
  const RoomShareException();
  @override
  String toString() => 'RoomShareException';
}

abstract interface class RoomImageExportService {
  Future<void> prepareSave({required bool Function() isCurrent});
  Future<void> savePng({
    required Uint8List pngBytes,
    required String photoId,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  });
  Future<RoomShareResult> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
    required String title,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  });
}

final roomImageExportServiceProvider = Provider<RoomImageExportService>(
  (ref) => PlatformRoomImageExportService(),
);

final class PlatformRoomImageExportService implements RoomImageExportService {
  PlatformRoomImageExportService({
    GalRoomGalleryWriter? gallery,
    TemporaryRootProvider? temporaryRoot,
    OwnedDirectoryCleanup? cleanupOwnedDirectory,
  }) : _gallery = gallery ?? GalRoomGalleryWriter(),
       _temporaryRoot = temporaryRoot ?? getTemporaryDirectory,
       _cleanup = cleanupOwnedDirectory ?? _delete;
  final GalRoomGalleryWriter _gallery;
  final TemporaryRootProvider _temporaryRoot;
  final OwnedDirectoryCleanup _cleanup;
  static const _verifier = RoomExportMetadataVerifier();
  static const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  @override
  Future<void> prepareSave({required bool Function() isCurrent}) =>
      _gallery.prepareAccess(isCurrent: isCurrent);
  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String photoId,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    final bytes = _detach(pngBytes);
    _verifier.verify(bytes);
    await _gallery.savePreparedPng(
      pngBytes: bytes,
      fileName: _name(photoId),
      isCurrent: isCurrent,
      beforeHandoff: () {
        _verifier.verify(bytes);
        if (!isCurrent()) return false;
        onHandoff?.call();
        return true;
      },
    );
  }

  @override
  Future<RoomShareResult> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
    required String title,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    final bytes = _detach(pngBytes);
    _verifier.verify(bytes);
    if (origin.isEmpty || !origin.isFinite || title.isEmpty) {
      throw const RoomShareException();
    }
    Directory? owned;
    try {
      final root = await _temporaryRoot();
      if (!isCurrent()) throw const RoomExportInterrupted();
      owned = await root.createTemp('tintatlas-share-');
      if (!isCurrent()) throw const RoomExportInterrupted();
      final file = File.fromUri(owned.uri.resolve(_name(photoId)));
      await file.writeAsBytes(bytes, flush: true);
      final args = <String, Object>{
        'paths': [file.path],
        'mimeTypes': ['image/png'],
        'title': title,
        'subject': title,
        'originX': origin.left,
        'originY': origin.top,
        'originWidth': origin.width,
        'originHeight': origin.height,
      };
      _verifier.verify(bytes);
      if (!isCurrent()) throw const RoomExportInterrupted();
      onHandoff?.call();
      // Locked share_plus 13.3.1 protocol. No hidden XFile preparation await.
      final result = await _shareChannel.invokeMethod<String>('share', args);
      return switch (result) {
        '' => RoomShareResult.dismissed,
        null || 'dev.fluttercommunity.plus/share/unavailable' =>
          RoomShareResult.unavailable,
        _ => RoomShareResult.completed,
      };
    } on RoomExportInterrupted {
      rethrow;
    } on RoomExportVerificationException {
      rethrow;
    } catch (_) {
      throw const RoomShareException();
    } finally {
      if (owned != null) {
        try {
          await _cleanup(owned);
        } catch (_) {
          /* Native result remains authoritative. */
        }
      }
    }
  }

  static Uint8List _detach(Uint8List bytes) {
    if (bytes.length > RoomExportMetadataVerifier.maxEncodedBytes) {
      throw const RoomExportVerificationException();
    }
    return Uint8List.fromList(bytes).asUnmodifiableView();
  }

  static Future<void> _delete(Directory owned) async {
    if (await owned.exists()) await owned.delete(recursive: true);
  }

  static String _name(String id) {
    var safe = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
    if (safe.length > 80) safe = safe.substring(0, 80);
    safe = safe.replaceAll(RegExp(r'^[-_]+|[-_]+$'), '');
    if (safe.isEmpty) safe = 'photo';
    return 'tintatlas-room-$safe.png';
  }
}
