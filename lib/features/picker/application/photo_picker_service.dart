import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart' as permission;

import '../../../core/image/photo_processing.dart';
import '../domain/prepared_photo.dart';
import '../domain/photo_acquisition.dart';
import 'photo_processor.dart';

enum PhotoPickFailureKind {
  permissionDenied,
  unavailable,
  invalidImage,
  tooLarge,
  processing,
}

class PhotoPickFailure implements Exception {
  const PhotoPickFailure(this.kind);
  final PhotoPickFailureKind kind;
  @override
  String toString() => 'PhotoPickFailure($kind)';
}

abstract interface class PhotoPickerService {
  Future<PreparedPhoto?> pick({PhotoSource source = PhotoSource.gallery});
  Future<PreparedPhoto?> recoverLost();
  Future<bool> openSettings();
}

final photoPickerServiceProvider = Provider<PhotoPickerService>(
  (ref) =>
      PluginPhotoPickerService(processor: ref.watch(photoProcessorProvider)),
);

class PluginPhotoPickerService implements PhotoPickerService {
  PluginPhotoPickerService({
    required PhotoProcessor processor,
    ImagePicker? picker,
    TargetPlatform? platform,
    Future<bool> Function()? settings,
  }) : _processor = processor,
       _picker = picker ?? ImagePicker(),
       _platform = platform ?? defaultTargetPlatform,
       _settings = settings ?? permission.openAppSettings;

  static const maxEncodedBytes = 24 * 1024 * 1024;
  final PhotoProcessor _processor;
  final ImagePicker _picker;
  final TargetPlatform _platform;
  final Future<bool> Function() _settings;

  @override
  Future<PreparedPhoto?> pick({PhotoSource source = PhotoSource.gallery}) =>
      _guard(() async {
        final file = await _picker.pickImage(
          source: source == PhotoSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
          requestFullMetadata: false,
        );
        return file == null ? null : await _prepare(file);
      });

  @override
  Future<PreparedPhoto?> recoverLost() async {
    if (kIsWeb || _platform != TargetPlatform.android) return null;
    return _guard(() async {
      final lost = await _picker.retrieveLostData();
      if (lost.exception != null) throw lost.exception!;
      final file = lost.files?.firstOrNull ?? lost.file;
      return file == null ? null : _prepare(file);
    });
  }

  Future<PreparedPhoto> _prepare(XFile file) async {
    if (await file.length() > maxEncodedBytes) {
      throw const PhotoPickFailure(PhotoPickFailureKind.tooLarge);
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxEncodedBytes) {
      throw const PhotoPickFailure(PhotoPickFailureKind.tooLarge);
    }
    try {
      return await _processor.prepare(bytes);
    } on PhotoProcessingException catch (error) {
      throw PhotoPickFailure(switch (error.kind) {
        PhotoProcessingFailure.tooLarge => PhotoPickFailureKind.tooLarge,
        PhotoProcessingFailure.invalidImage ||
        PhotoProcessingFailure.unsupported => PhotoPickFailureKind.invalidImage,
      });
    } on PhotoPickFailure {
      rethrow;
    } catch (_) {
      throw const PhotoPickFailure(PhotoPickFailureKind.processing);
    }
  }

  Future<PreparedPhoto?> _guard(
    Future<PreparedPhoto?> Function() action,
  ) async {
    try {
      return await action();
    } on PhotoPickFailure {
      rethrow;
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      throw PhotoPickFailure(
        code.contains('denied') ||
                code.contains('restricted') ||
                code.contains('permission')
            ? PhotoPickFailureKind.permissionDenied
            : PhotoPickFailureKind.unavailable,
      );
    } catch (_) {
      throw const PhotoPickFailure(PhotoPickFailureKind.unavailable);
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await _settings();
    } catch (_) {
      return false;
    }
  }
}
