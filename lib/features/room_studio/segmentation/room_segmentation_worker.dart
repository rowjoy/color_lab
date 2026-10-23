import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import '../../picker/domain/prepared_photo.dart';
import '../domain/mask_bitmap.dart';
import 'raw_segmentation.dart';
import 'room_depth_runner.dart';
import 'room_mask_processing.dart';
import 'room_model_descriptor.dart';
import 'room_model_runner.dart';
import 'room_wall_depth_protection.dart';

enum RoomSegmentationFailureKind {
  modelUnavailable,
  incompatibleModel,
  invalidOutput,
  processing,
}

/// Contains no file paths, native errors, or photo data.
final class RoomSegmentationException implements Exception {
  const RoomSegmentationException(this.kind);
  final RoomSegmentationFailureKind kind;

  @override
  String toString() => 'RoomSegmentationException(${kind.name})';
}

abstract interface class RoomSegmentationWorker {
  Future<MaskBitmap> run(PreparedPhoto photo);
  Future<void> close();
}

/// Synchronous composition, called only in the production inference isolate.
MaskBitmap runRoomSegmentationFrame(
  PreparedPhoto photo,
  RoomModelDescriptor descriptor,
  RoomModelRunner runner, {
  RoomDepthRunner? depthRunner,
}) {
  try {
    final input = prepareRoomInput(photo, descriptor);
    final RawSegmentation raw;
    try {
      raw = runner.invoke(input.tensorBytes);
    } on FormatException {
      throw const RoomSegmentationException(
        RoomSegmentationFailureKind.invalidOutput,
      );
    }
    if (raw.width != descriptor.outputWidth ||
        raw.height != descriptor.outputHeight) {
      throw const RoomSegmentationException(
        RoomSegmentationFailureKind.invalidOutput,
      );
    }
    final baseline = postprocessRoomOutput(raw, input.transform, descriptor);
    return depthRunner == null
        ? baseline
        : protectRoomWallsWithDepth(baseline, depthRunner.invoke(photo));
  } on RoomSegmentationException {
    rethrow;
  } catch (_) {
    throw const RoomSegmentationException(
      RoomSegmentationFailureKind.processing,
    );
  }
}

/// The port proxy never creates a native interpreter or iterates image pixels.
final class IsolateRoomSegmentationWorker implements RoomSegmentationWorker {
  IsolateRoomSegmentationWorker._();

  final _responses = ReceivePort();
  final _ready = Completer<void>();
  final _stopped = Completer<void>();
  SendPort? _commands;
  Isolate? _isolate;
  Completer<MaskBitmap>? _pending;
  Future<void>? _closing;
  bool _dead = false;

  static Future<IsolateRoomSegmentationWorker> start({
    required Uint8List modelBytes,
    required RoomModelDescriptor descriptor,
    required Uint8List depthModelBytes,
  }) async {
    final worker = IsolateRoomSegmentationWorker._();
    worker._responses.listen(worker._receive);
    try {
      worker._isolate = await Isolate.spawn(
        _workerMain,
        (
          worker._responses.sendPort,
          TransferableTypedData.fromList([modelBytes]),
          descriptor,
          TransferableTypedData.fromList([depthModelBytes]),
        ),
        debugName: 'room-segmentation',
        onError: worker._responses.sendPort,
        onExit: worker._responses.sendPort,
      );
    } catch (_) {
      worker._responses.close();
      throw const RoomSegmentationException(
        RoomSegmentationFailureKind.processing,
      );
    }
    try {
      await worker._ready.future;
      return worker;
    } catch (_) {
      worker._isolate?.kill(priority: Isolate.immediate);
      worker._responses.close();
      rethrow;
    }
  }

  void _receive(Object? message) {
    if (message is SendPort) {
      _commands = message;
      _ready.complete();
    } else if (message is MaskBitmap) {
      final pending = _pending;
      _pending = null;
      pending?.complete(message);
    } else if (message is RoomSegmentationFailureKind) {
      final error = RoomSegmentationException(message);
      if (!_ready.isCompleted) {
        _ready.completeError(error);
      } else {
        final pending = _pending;
        _pending = null;
        pending?.completeError(error);
      }
    } else if (message == 'closed') {
      _finish();
    } else {
      // The VM sends null on exit, or [error, stack] on an uncaught error.
      _dead = true;
      const error = RoomSegmentationException(
        RoomSegmentationFailureKind.processing,
      );
      if (!_ready.isCompleted) _ready.completeError(error);
      final pending = _pending;
      _pending = null;
      pending?.completeError(error);
      _finish();
    }
  }

  void _finish() {
    _dead = true;
    _responses.close();
    if (!_stopped.isCompleted) _stopped.complete();
  }

  @override
  Future<MaskBitmap> run(PreparedPhoto photo) {
    if (_dead || _closing != null || _pending != null) {
      return Future.error(
        const RoomSegmentationException(RoomSegmentationFailureKind.processing),
      );
    }
    final pending = _pending = Completer<MaskBitmap>();
    _commands!.send((
      photo.width,
      photo.height,
      TransferableTypedData.fromList([photo.rgbaBytes]),
    ));
    return pending.future;
  }

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    try {
      await _pending?.future;
    } catch (_) {
      // Invocation errors have already been delivered to their caller.
    }
    if (!_dead) _commands!.send('close');
    await _stopped.future;
  }
}

/// Only byte data and immutable Dart values cross this boundary, never a runner.
void _workerMain(
  (SendPort, TransferableTypedData, RoomModelDescriptor, TransferableTypedData)
  boot,
) {
  final (reply, model, descriptor, depthModel) = boot;
  RoomModelRunner? runner;
  RoomDepthRunner? depthRunner;
  try {
    runner = TfliteRoomModelRunner(
      model.materialize().asUint8List(),
      descriptor,
    );
    depthRunner = TfliteRoomDepthRunner(depthModel.materialize().asUint8List());
  } catch (_) {
    runner?.close();
    depthRunner?.close();
    Isolate.exit(reply, RoomSegmentationFailureKind.incompatibleModel);
  }
  final ownedRunner = runner;
  final ownedDepthRunner = depthRunner;
  final commands = ReceivePort();
  reply.send(commands.sendPort);
  commands.listen((Object? message) {
    if (message == 'close') {
      try {
        try {
          ownedRunner.close();
        } finally {
          ownedDepthRunner.close();
        }
      } finally {
        commands.close();
        Isolate.exit(reply, 'closed');
      }
    }
    try {
      final (width, height, bytes) =
          message! as (int, int, TransferableTypedData);
      final photo = PreparedPhoto(
        width: width,
        height: height,
        rgbaBytes: bytes.materialize().asUint8List(),
        previewBytes: Uint8List(0),
        palette: const [],
      );
      reply.send(
        runRoomSegmentationFrame(
          photo,
          descriptor,
          ownedRunner,
          depthRunner: ownedDepthRunner,
        ),
      );
    } on RoomSegmentationException catch (error) {
      reply.send(error.kind);
    } catch (_) {
      reply.send(RoomSegmentationFailureKind.processing);
    }
  });
}
