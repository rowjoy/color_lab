import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/segmentation/raw_segmentation.dart';
import 'package:color_lab/features/room_studio/segmentation/room_depth_runner.dart';
import 'package:color_lab/features/room_studio/segmentation/room_wall_depth_protection.dart';
import 'package:color_lab/features/room_studio/segmentation/room_model_descriptor.dart';
import 'package:color_lab/features/room_studio/segmentation/room_model_runner.dart';
import 'package:color_lab/features/room_studio/segmentation/room_segmentation_service.dart';
import 'package:color_lab/features/room_studio/segmentation/room_segmentation_worker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final descriptor = RoomModelDescriptor.fromMap(
  (jsonDecode(File('assets/models/room_seg_descriptor.json').readAsStringSync())
          as Map)
      .cast<String, Object?>(),
);

PreparedPhoto photo([int red = 10]) => PreparedPhoto(
  width: 3,
  height: 2,
  rgbaBytes: Uint8List.fromList([
    red,
    20,
    30,
    255,
    40,
    50,
    60,
    255,
    70,
    80,
    90,
    255,
    100,
    110,
    120,
    255,
    130,
    140,
    150,
    255,
    160,
    170,
    180,
    255,
  ]),
  previewBytes: Uint8List(0),
  palette: const [],
);

MaskBitmap masks([int label = 1]) => MaskBitmap(
  width: 3,
  height: 2,
  labels: Uint8List(6)..fillRange(0, 6, label),
);

Matcher failure(RoomSegmentationFailureKind kind) =>
    isA<RoomSegmentationException>().having((e) => e.kind, 'kind', kind);

/// Only the external worker is replaced; the real queue/cache owns these calls.
final class ControlledWorker implements RoomSegmentationWorker {
  ControlledWorker({this.closeError, this.closeGate});
  final Object? closeError;
  final Completer<void>? closeGate;
  final photos = <PreparedPhoto>[];
  final invocations = <Completer<MaskBitmap>>[];
  int concurrent = 0;
  int maximumConcurrentRuns = 0;
  int closes = 0;

  @override
  Future<MaskBitmap> run(PreparedPhoto photo) async {
    photos.add(photo);
    final result = Completer<MaskBitmap>();
    invocations.add(result);
    concurrent++;
    if (concurrent > maximumConcurrentRuns) maximumConcurrentRuns = concurrent;
    try {
      return await result.future;
    } finally {
      concurrent--;
    }
  }

  @override
  Future<void> close() async {
    expect(concurrent, 0, reason: 'Interpreter cannot close during invocation');
    closes++;
    await closeGate?.future;
    if (closeError != null) throw closeError!;
  }
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

final class FrameRunner implements RoomModelRunner {
  FrameRunner(this.output, {this.error});
  final RawSegmentation output;
  final Object? error;
  int calls = 0;
  Uint8List? input;
  @override
  RoomModelDescriptor get descriptor => RoomModelDescriptor.fromMap(
    (jsonDecode(
              File('assets/models/room_seg_descriptor.json').readAsStringSync(),
            )
            as Map)
        .cast<String, Object?>(),
  );
  @override
  RawSegmentation invoke(Uint8List bytes) {
    calls++;
    input = bytes;
    if (error != null) throw error!;
    return output;
  }

  @override
  void close() {}
}

final class DepthRunner implements RoomDepthRunner {
  int calls = 0;

  @override
  RoomDepthFrame invoke(PreparedPhoto photo) {
    calls++;
    final values = Float32List(32 * 32)..fillRange(0, 32 * 32, 10);
    for (var y = 12; y < 20; y++) {
      for (var x = 12; x < 20; x++) {
        values[y * 32 + x] = 30;
      }
    }
    return RoomDepthFrame(width: 32, height: 32, inverseDepth: values);
  }

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('production frame excludes nearer foreground from semantic Wall', () {
    final image = PreparedPhoto(
      width: 64,
      height: 64,
      rgbaBytes: Uint8List(64 * 64 * 4),
      previewBytes: Uint8List(0),
      palette: const [],
    );
    final runner = FrameRunner(
      RawSegmentation(
        width: 512,
        height: 512,
        classIds: Uint16List(512 * 512)..fillRange(0, 512 * 512, 1),
      ),
    );
    final depth = DepthRunner();
    final masks = runRoomSegmentationFrame(
      image,
      descriptor,
      runner,
      depthRunner: depth,
    );
    expect(masks.labels[32 * 64 + 32], 0);
    expect(masks.labels[10 * 64 + 10], 1);
    expect(runner.calls, 1);
    expect(depth.calls, 1);
  });

  test(
    'default factory classifies absent assets separately from invalid descriptor',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() {
        messenger.setMockMessageHandler('flutter/assets', null);
        rootBundle.clear();
      });
      messenger.setMockMessageHandler('flutter/assets', (_) async => null);
      await expectLater(
        createRoomSegmentationWorker(),
        throwsA(failure(RoomSegmentationFailureKind.modelUnavailable)),
      );
      messenger.setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(
          message!.buffer.asUint8List(
            message.offsetInBytes,
            message.lengthInBytes,
          ),
        );
        return ByteData.sublistView(
          key.endsWith('.json')
              ? Uint8List.fromList(utf8.encode('{}'))
              : Uint8List(8),
        );
      });
      rootBundle.clear();
      await expectLater(
        createRoomSegmentationWorker(),
        throwsA(failure(RoomSegmentationFailureKind.incompatibleModel)),
      );
    },
  );

  test(
    'provider disposal closes its unused service without initializing assets',
    () async {
      final container = ProviderContainer();
      final service = container.read(roomSegmentationServiceProvider);
      container.dispose();
      await expectLater(
        service.analyze(photoId: 'disposed', photo: photo()),
        throwsA(failure(RoomSegmentationFailureKind.processing)),
      );
      await service.close();
    },
  );

  test(
    'unused close is idempotent and rejects new analysis without initialization',
    () async {
      var starts = 0;
      final service = IsolateRoomSegmentationService(
        workerFactory: () async {
          starts++;
          return ControlledWorker();
        },
      );
      await service.close();
      await service.close();
      await expectLater(
        service.analyze(photoId: 'closed', photo: photo()),
        throwsA(failure(RoomSegmentationFailureKind.processing)),
      );
      expect(starts, 0);
    },
  );

  test(
    'one active and latest waiting run; superseded request settles safely',
    () async {
      final worker = ControlledWorker();
      var starts = 0;
      final service = IsolateRoomSegmentationService(
        workerFactory: () async {
          starts++;
          return worker;
        },
      );
      final aPhoto = photo();
      final bPhoto = photo(20);
      final cPhoto = photo(30);
      final a = service.analyze(photoId: 'photo-A', photo: aPhoto);
      await pump();
      final b = service.analyze(photoId: 'photo-B', photo: bPhoto);
      final rejected = expectLater(
        b,
        throwsA(failure(RoomSegmentationFailureKind.processing)),
      );
      final c = service.analyze(photoId: 'photo-C', photo: cPhoto);
      await rejected;
      expect(worker.photos, [aPhoto]);
      worker.invocations[0].complete(masks());
      expect((await a).photoId, 'photo-A');
      await pump();
      expect(worker.photos, [aPhoto, cPhoto]);
      worker.invocations[1].complete(masks(4));
      final result = await c;
      expect(result.photoId, 'photo-C');
      expect(result.masks.labels, everyElement(4));
      expect(starts, 1);
      expect(worker.maximumConcurrentRuns, 1);
      await service.close();
      expect(worker.closes, 1);
    },
  );

  test('same photo caches masks but preserves each caller revision', () async {
    final worker = ControlledWorker();
    final service = IsolateRoomSegmentationService(
      workerFactory: () async => worker,
    );
    final source = photo();
    final first = service.analyze(photoId: 'revision-1', photo: source);
    final second = service.analyze(photoId: 'revision-2', photo: source);
    await pump();
    worker.invocations.single.complete(masks());
    final a = await first;
    final b = await second;
    final c = await service.analyze(photoId: 'revision-3', photo: source);
    expect(
      [a.photoId, b.photoId, c.photoId],
      ['revision-1', 'revision-2', 'revision-3'],
    );
    expect(identical(a.masks, b.masks), isTrue);
    expect(identical(a.masks, c.masks), isTrue);
    expect(worker.photos, [source]);
    expect(() => c.masks.labels[0] = 4, throwsUnsupportedError);
    await service.close();
  });

  test(
    'cache keys photo identity not dimensions or caller id and retains only last photo',
    () async {
      final worker = ControlledWorker();
      final service = IsolateRoomSegmentationService(
        workerFactory: () async => worker,
      );
      final a = photo();
      final b = photo(20);
      for (final entry in [(a, 1), (b, 2), (a, 3)]) {
        final pending = service.analyze(photoId: 'same-id', photo: entry.$1);
        await pump();
        worker.invocations.last.complete(masks(entry.$2));
        expect((await pending).masks.labels, everyElement(entry.$2));
      }
      expect(worker.photos, [a, b, a]);
      await service.close();
    },
  );

  test(
    'close rejects waiting, waits for active invocation, and releases once',
    () async {
      final worker = ControlledWorker();
      final service = IsolateRoomSegmentationService(
        workerFactory: () async => worker,
      );
      final a = service.analyze(photoId: 'active', photo: photo());
      await pump();
      final b = service.analyze(photoId: 'waiting', photo: photo(20));
      final rejected = expectLater(
        b,
        throwsA(failure(RoomSegmentationFailureKind.processing)),
      );
      var closed = false;
      final closing = service.close().then((_) => closed = true);
      await rejected;
      await pump();
      expect(closed, isFalse);
      expect(worker.closes, 0);
      worker.invocations.single.complete(masks());
      expect((await a).photoId, 'active');
      await closing;
      await service.close();
      expect(worker.closes, 1);
      expect(worker.photos.length, 1);
      await expectLater(
        service.analyze(photoId: 'new', photo: photo()),
        throwsA(failure(RoomSegmentationFailureKind.processing)),
      );
    },
  );

  test(
    'close during initialization waits through the already active request',
    () async {
      final initialization = Completer<RoomSegmentationWorker>();
      final worker = ControlledWorker();
      final service = IsolateRoomSegmentationService(
        workerFactory: () => initialization.future,
      );
      final pending = service.analyze(photoId: 'active', photo: photo());
      final closing = service.close();
      initialization.complete(worker);
      await pump();
      expect(worker.closes, 0);
      worker.invocations.single.complete(masks());
      await pending;
      await closing;
      expect(worker.closes, 1);
    },
  );

  test(
    'failed initialization is safe and retries on explicit analysis',
    () async {
      final worker = ControlledWorker();
      var starts = 0;
      final service = IsolateRoomSegmentationService(
        workerFactory: () async {
          if (++starts == 1) {
            throw const RoomSegmentationException(
              RoomSegmentationFailureKind.modelUnavailable,
            );
          }
          return worker;
        },
      );
      await expectLater(
        service.analyze(photoId: 'failed', photo: photo()),
        throwsA(failure(RoomSegmentationFailureKind.modelUnavailable)),
      );
      final retry = service.analyze(photoId: 'retry', photo: photo());
      await pump();
      worker.invocations.single.complete(masks());
      expect((await retry).photoId, 'retry');
      expect(starts, 2);
      await service.close();
    },
  );

  test('invalid output is not cached and waiting work recovers', () async {
    final worker = ControlledWorker();
    final service = IsolateRoomSegmentationService(
      workerFactory: () async => worker,
    );
    final source = photo();
    final first = service.analyze(photoId: 'bad', photo: source);
    final rejected = expectLater(
      first,
      throwsA(failure(RoomSegmentationFailureKind.invalidOutput)),
    );
    final retry = service.analyze(photoId: 'retry', photo: source);
    await pump();
    worker.invocations[0].completeError(
      const RoomSegmentationException(
        RoomSegmentationFailureKind.invalidOutput,
      ),
    );
    await rejected;
    await pump();
    worker.invocations[1].complete(masks(0));
    expect((await retry).masks.labels, everyElement(0));
    expect(worker.photos.length, 2);
    await service.close();
  });

  test(
    'unexpected worker errors expose only safe processing failures',
    () async {
      final worker = ControlledWorker();
      final service = IsolateRoomSegmentationService(
        workerFactory: () async => worker,
      );
      final pending = service.analyze(photoId: 'bad', photo: photo());
      final rejected = expectLater(
        pending,
        throwsA(failure(RoomSegmentationFailureKind.processing)),
      );
      await pump();
      worker.invocations.single.completeError(StateError('/private/secret'));
      await rejected;
      expect(
        const RoomSegmentationException(
          RoomSegmentationFailureKind.processing,
        ).toString(),
        isNot(contains('/private/secret')),
      );
      await service.close();
    },
  );

  test(
    'processing failure retires the worker so explicit retry can recover after worker exit',
    () async {
      for (final closeError in [null, StateError('cleanup failed')]) {
        final dead = ControlledWorker(closeError: closeError);
        final healthy = ControlledWorker();
        var starts = 0;
        final service = IsolateRoomSegmentationService(
          workerFactory: () async => ++starts == 1 ? dead : healthy,
        );
        final source = photo();
        final first = service.analyze(photoId: 'failed', photo: source);
        final rejected = expectLater(
          first,
          throwsA(failure(RoomSegmentationFailureKind.processing)),
        );
        await pump();
        dead.invocations.single.completeError(
          const RoomSegmentationException(
            RoomSegmentationFailureKind.processing,
          ),
        );
        await rejected;
        expect(dead.closes, 1);
        final retry = service.analyze(photoId: 'retry', photo: source);
        await pump();
        expect(starts, 2);
        healthy.invocations.single.complete(masks());
        expect((await retry).photoId, 'retry');
        await service.close();
        expect(dead.closes, 1);
        expect(healthy.closes, 1);
      }
    },
  );

  test(
    'disposal during failed-worker cleanup rejects queued retry without initializing another worker',
    () async {
      final cleanup = Completer<void>();
      final worker = ControlledWorker(closeGate: cleanup);
      var starts = 0;
      final service = IsolateRoomSegmentationService(
        workerFactory: () async {
          starts++;
          return worker;
        },
      );
      final pending = service.analyze(photoId: 'failed', photo: photo());
      final rejected = expectLater(
        pending,
        throwsA(failure(RoomSegmentationFailureKind.processing)),
      );
      await pump();
      worker.invocations.single.completeError(StateError('worker exited'));
      await pump();
      expect(worker.closes, 1);
      final waiting = service.analyze(photoId: 'waiting', photo: photo(20));
      final cancelled = expectLater(
        waiting,
        throwsA(failure(RoomSegmentationFailureKind.processing)),
      );
      final closing = service.close();
      await cancelled;
      cleanup.complete();
      await rejected;
      await closing;
      expect(starts, 1);
      expect(worker.closes, 1);
    },
  );

  test(
    'worker close errors remain safe and repeated close does not release twice',
    () async {
      final worker = ControlledWorker(
        closeError: StateError('/private/secret'),
      );
      final service = IsolateRoomSegmentationService(
        workerFactory: () async => worker,
      );
      final pending = service.analyze(photoId: 'ok', photo: photo());
      await pump();
      worker.invocations.single.complete(masks());
      await pending;
      for (var attempt = 0; attempt < 2; attempt++) {
        await expectLater(
          service.close(),
          throwsA(failure(RoomSegmentationFailureKind.processing)),
        );
      }
      expect(worker.closes, 1);
    },
  );

  test('worker mask dimensions must match the photo before caching', () async {
    final worker = ControlledWorker();
    final service = IsolateRoomSegmentationService(
      workerFactory: () async => worker,
    );
    final pending = service.analyze(photoId: 'bad-shape', photo: photo());
    final rejected = expectLater(
      pending,
      throwsA(failure(RoomSegmentationFailureKind.invalidOutput)),
    );
    await pump();
    worker.invocations.single.complete(
      MaskBitmap(width: 1, height: 1, labels: Uint8List(1)),
    );
    await rejected;
    await service.close();
  });

  test(
    'frame invokes once, supplies prepared RGB and aligns non-square ownership',
    () {
      final ids = Uint16List(512 * 512)..fillRange(0, 512 * 512, 2);
      ids[0] = 1;
      ids[256] = 6;
      ids[511] = 4;
      ids[340 * 512] = 8;
      ids[340 * 512 + 256] = 9;
      ids[340 * 512 + 511] = 24;
      final runner = FrameRunner(
        RawSegmentation(width: 512, height: 512, classIds: ids),
      );
      final result = runRoomSegmentationFrame(photo(), descriptor, runner);
      expect(runner.calls, 1);
      expect(runner.input!.length, 786432);
      expect(runner.input!.sublist(0, 3), [10, 20, 30]);
      expect(runner.input!.sublist(341 * 512 * 3, 341 * 512 * 3 + 3), [
        123,
        115,
        103,
      ]);
      expect([result.width, result.height], [3, 2]);
      expect(result.labels, [1, 2, 3, 4, 0, 4]);
    },
  );

  test('valid all-unselected model output succeeds', () {
    for (final id in [0, 2]) {
      final runner = FrameRunner(
        RawSegmentation(
          width: 512,
          height: 512,
          classIds: Uint16List(512 * 512)..fillRange(0, 512 * 512, id),
        ),
      );
      expect(
        runRoomSegmentationFrame(photo(), descriptor, runner).labels,
        everyElement(0),
      );
      expect(runner.calls, 1);
    }
  });

  test(
    'wrong output dimensions and native output-format errors are invalidOutput',
    () {
      final raw = RawSegmentation(width: 1, height: 1, classIds: Uint16List(1));
      for (final runner in [
        FrameRunner(raw),
        FrameRunner(raw, error: const FormatException('private native detail')),
      ]) {
        expect(
          () => runRoomSegmentationFrame(photo(), descriptor, runner),
          throwsA(failure(RoomSegmentationFailureKind.invalidOutput)),
        );
      }
    },
  );

  test('invocation operational failure is processing, not invalid output', () {
    final runner = FrameRunner(
      RawSegmentation(width: 1, height: 1, classIds: Uint16List(1)),
      error: StateError('native unavailable'),
    );
    expect(
      () => runRoomSegmentationFrame(photo(), descriptor, runner),
      throwsA(failure(RoomSegmentationFailureKind.processing)),
    );
  });

  test(
    'real isolate rejects corrupt model as incompatible without native initialization',
    () async {
      await expectLater(
        IsolateRoomSegmentationWorker.start(
          depthModelBytes: Uint8List(8),
          modelBytes: Uint8List(8),
          descriptor: descriptor,
        ),
        throwsA(failure(RoomSegmentationFailureKind.incompatibleModel)),
      );
    },
  );
}
