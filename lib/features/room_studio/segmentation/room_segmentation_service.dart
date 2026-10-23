import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../picker/domain/prepared_photo.dart';
import '../application/room_model_download_providers.dart';
import '../domain/mask_bitmap.dart';
import '../models/room_model_store.dart';
import 'room_model_descriptor.dart';
import 'room_segmentation_worker.dart';

export 'room_segmentation_worker.dart'
    show RoomSegmentationException, RoomSegmentationFailureKind;

final class RoomSegmentationResult {
  const RoomSegmentationResult({required this.photoId, required this.masks});

  final String photoId;
  final MaskBitmap masks;
}

abstract interface class RoomSegmentationService {
  Future<RoomSegmentationResult> analyze({
    required String photoId,
    required PreparedPhoto photo,
  });
  Future<void> close();
}

typedef RoomSegmentationWorkerFactory =
    Future<RoomSegmentationWorker> Function();

/// Asset access stays on the root isolate; native handles and pixels do not.
Future<RoomSegmentationWorker> createRoomSegmentationWorker({
  RoomModelStore? modelStore,
}) async {
  late String json;
  try {
    json = await rootBundle.loadString(
      'assets/models/room_seg_descriptor.json',
    );
  } catch (_) {
    throw const RoomSegmentationException(
      RoomSegmentationFailureKind.modelUnavailable,
    );
  }
  late RoomModelDescriptor descriptor;
  try {
    descriptor = RoomModelDescriptor.fromMap(
      (jsonDecode(json) as Map).cast<String, Object?>(),
    );
  } catch (_) {
    throw const RoomSegmentationException(
      RoomSegmentationFailureKind.incompatibleModel,
    );
  }
  final store = modelStore ?? RoomModelStore();
  try {
    final models = await store.load();
    return await IsolateRoomSegmentationWorker.start(
      modelBytes: models.semantic,
      descriptor: descriptor,
      depthModelBytes: models.depth,
    );
  } on RoomModelDownloadException {
    throw const RoomSegmentationException(
      RoomSegmentationFailureKind.modelUnavailable,
    );
  } finally {
    if (modelStore == null) await store.close();
  }
}

/// One active request, one replaceable waiting request, one cached photo.
/// Identity refers to the immutable PreparedPhoto object, not a caller revision.
final class IsolateRoomSegmentationService implements RoomSegmentationService {
  IsolateRoomSegmentationService({RoomSegmentationWorkerFactory? workerFactory})
    : _workerFactory = workerFactory ?? createRoomSegmentationWorker;

  final RoomSegmentationWorkerFactory _workerFactory;
  RoomSegmentationWorker? _worker;
  _Request? _active;
  _Request? _waiting;
  PreparedPhoto? _cachedPhoto;
  MaskBitmap? _cachedMasks;
  bool _closed = false;
  Future<void>? _closing;

  @override
  Future<RoomSegmentationResult> analyze({
    required String photoId,
    required PreparedPhoto photo,
  }) {
    if (_closed) return Future.error(_cancelled);
    final request = _Request(photoId, photo);
    if (_active == null) {
      _start(request);
    } else {
      _waiting?.result.completeError(_cancelled);
      _waiting = request;
    }
    return request.result.future;
  }

  void _start(_Request request) {
    _active = request;
    unawaited(_run(request));
  }

  Future<void> _run(_Request request) async {
    try {
      final cached = identical(_cachedPhoto, request.photo)
          ? _cachedMasks
          : null;
      final MaskBitmap masks;
      if (cached != null) {
        masks = cached;
      } else {
        final worker = _worker ??= await _workerFactory();
        masks = await worker.run(request.photo);
        if (masks.width != request.photo.width ||
            masks.height != request.photo.height) {
          throw const RoomSegmentationException(
            RoomSegmentationFailureKind.invalidOutput,
          );
        }
        if (!_closed) {
          _cachedPhoto = request.photo;
          _cachedMasks = masks;
        }
      }
      request.result.complete(
        RoomSegmentationResult(photoId: request.photoId, masks: masks),
      );
    } catch (error) {
      final safeError = error is RoomSegmentationException ? error : _cancelled;
      if (safeError.kind == RoomSegmentationFailureKind.processing) {
        // A transport/native failure may leave a dead worker. Release it before
        // another explicit request can initialize a replacement.
        final failedWorker = _worker;
        _worker = null;
        try {
          await failedWorker?.close();
        } catch (_) {
          // Cleanup must not replace the original safe failure or strand work.
        }
      }
      request.result.completeError(safeError);
    } finally {
      _active = null;
      request.finished.complete();
      final next = _waiting;
      _waiting = null;
      if (!_closed && next != null) _start(next);
    }
  }

  @override
  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _waiting?.result.completeError(_cancelled);
    _waiting = null;
    _cachedPhoto = null;
    _cachedMasks = null;
    return _closing = _release();
  }

  Future<void> _release() async {
    await _active?.finished.future;
    final worker = _worker;
    _worker = null;
    try {
      await worker?.close();
    } catch (_) {
      throw _cancelled;
    }
  }

  static const _cancelled = RoomSegmentationException(
    RoomSegmentationFailureKind.processing,
  );
}

final class _Request {
  _Request(this.photoId, this.photo);
  final String photoId;
  final PreparedPhoto photo;
  final result = Completer<RoomSegmentationResult>();
  final finished = Completer<void>();
}

final roomSegmentationServiceProvider = Provider<RoomSegmentationService>((
  ref,
) {
  final store = ref.watch(roomModelStoreProvider);
  final service = IsolateRoomSegmentationService(
    workerFactory: () => createRoomSegmentationWorker(modelStore: store),
  );
  ref.onDispose(() {
    unawaited(service.close().catchError((Object _) {}));
  });
  return service;
});
