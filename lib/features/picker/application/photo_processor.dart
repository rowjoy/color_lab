import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/image/photo_processing.dart';
import '../domain/prepared_photo.dart';

abstract interface class PhotoProcessor {
  Future<PreparedPhoto> prepare(Uint8List bytes);
}

final class IsolatePhotoProcessor implements PhotoProcessor {
  const IsolatePhotoProcessor();

  @override
  Future<PreparedPhoto> prepare(Uint8List bytes) {
    if (bytes.length > maxPhotoEncodedBytes) {
      return Future.error(
        const PhotoProcessingException(PhotoProcessingFailure.tooLarge),
      );
    }
    return compute(
      preparePhoto,
      Uint8List.fromList(bytes),
      debugLabel: 'prepare-photo',
    );
  }
}

final photoProcessorProvider = Provider<PhotoProcessor>(
  (ref) => const IsolatePhotoProcessor(),
);
