import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/failing_model_removal_io.dart';

const _helloSha =
    '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824';
const _worldSha =
    '486ea46224d1bb4fb680f34f7c9ad96a8f24ec88be73ea8e5a6c65260e9cb8a7';

void main() {
  late Directory root;
  late HttpServer server;
  late List<RoomModelArtifact> artifacts;
  late List<RoomModelStore> stores;
  late List<String> requests;
  late Future<void> Function(HttpRequest) respond;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('room-model-store-test-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = [];
    stores = [];
    artifacts = [
      RoomModelArtifact(
        name: 'room_seg.tflite',
        url: 'http://127.0.0.1:${server.port}/seg',
        bytes: 5,
        sha256: _helloSha,
      ),
      RoomModelArtifact(
        name: 'room_depth.tflite',
        url: 'http://127.0.0.1:${server.port}/depth',
        bytes: 5,
        sha256: _worldSha,
      ),
    ];
    respond = (request) async {
      request.response.add(
        utf8.encode(request.uri.path == '/seg' ? 'hello' : 'world'),
      );
      await request.response.close();
    };
    server.listen((request) async {
      requests.add(request.uri.path);
      try {
        await respond(request);
      } catch (_) {
        // A cancelled client may close while the test server is responding.
      }
    });
  });

  tearDown(() async {
    for (final store in stores) {
      await store.close();
    }
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  RoomModelStore store() {
    final result = RoomModelStore(
      directory: () async => root,
      artifacts: artifacts,
    );
    stores.add(result);
    return result;
  }

  File cached(String name, String sha) =>
      File('${root.path}/room_models/$sha/$name');

  Future<List<File>> partials() async => [
    await for (final item in root.list(recursive: true))
      if (item is File && item.path.endsWith('.part')) item,
  ];

  test(
    'inventory is read only and removal leaves unrelated files intact',
    () async {
      final subject = store();
      expect((await subject.inventory()).entries, isEmpty);
      expect(requests, isEmpty);
      await subject.prepare();
      final unrelated = File('${root.path}/room_models/keep.txt');
      await unrelated.writeAsString('export');
      expect((await subject.inventory()).entries, hasLength(2));
      await subject.remove();
      expect((await subject.inventory()).entries, isEmpty);
      expect(await unrelated.readAsString(), 'export');
    },
  );

  test(
    'removal failure after first file leaves remaining model recoverable for retry',
    () async {
      final subject = store();
      await subject.prepare();
      final first = cached('room_seg.tflite', _helloSha);
      final second = cached('room_depth.tflite', _worldSha);
      final failure = FailingModelRemovalIO(
        ownedPaths: {first.path, second.path},
        failOn: second.path,
      );
      await IOOverrides.runWithIOOverrides(() async {
        await expectLater(
          subject.remove(),
          throwsA(isA<FileSystemException>()),
        );
      }, failure);
      expect(failure.deletedPaths, [first.path]);
      expect(await first.exists(), false);
      expect(await second.readAsString(), 'world');
      expect((await subject.inventory()).entries, hasLength(1));
      await subject.remove();
      expect((await subject.inventory()).entries, isEmpty);
    },
  );

  test(
    'remove cancels and awaits active download so old operation cannot recreate files',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      respond = (request) async {
        started.complete();
        await release.future;
        request.response.write('hello');
        await request.response.close();
      };
      final subject = store();
      final load = subject.prepare();
      final expectation = expectLater(
        load,
        throwsA(isA<RoomModelDownloadException>()),
      );
      await started.future;
      await subject.remove();
      release.complete();
      await expectation;
      expect((await subject.inventory()).entries, isEmpty);
      expect(await partials(), isEmpty);
    },
  );

  test(
    'preparation downloads verified files before inference loads bytes',
    () async {
      final subject = store();
      await subject.prepare();
      expect(subject.progress.stage, RoomModelDownloadStage.ready);
      expect(requests, ['/seg', '/depth']);
      final bytes = await subject.load();
      expect(utf8.decode(bytes.semantic), 'hello');
      expect(utf8.decode(bytes.depth), 'world');
      expect(requests, ['/seg', '/depth']);
    },
  );

  test(
    'fresh startup preparation verifies cache offline and rejects corruption',
    () async {
      await store().prepare();
      final offline = RoomModelStore(
        directory: () async => root,
        artifacts: artifacts,
        clientFactory: () => throw const SocketException('offline'),
      );
      stores.add(offline);
      await offline.prepare();
      expect(offline.progress.stage, RoomModelDownloadStage.ready);
      await cached('room_depth.tflite', _worldSha).writeAsString('wrong');
      await expectLater(
        offline.prepare(),
        throwsA(isA<RoomModelDownloadException>()),
      );
      expect(offline.progress.stage, RoomModelDownloadStage.failed);
      expect(requests, ['/seg', '/depth']);
    },
  );

  test('preparation and inference share one download operation', () async {
    final subject = store();
    await Future.wait([subject.prepare(), subject.load()]);
    expect(requests, ['/seg', '/depth']);
    expect(await partials(), isEmpty);
  });

  test(
    'downloads verified models and reports real aggregate progress',
    () async {
      final subject = store();
      final progress = <RoomModelDownloadProgress>[];
      final subscription = subject.changes.listen(progress.add);
      addTearDown(subscription.cancel);

      final result = await subject.load();

      expect(utf8.decode(result.semantic), 'hello');
      expect(utf8.decode(result.depth), 'world');
      expect(
        await cached('room_seg.tflite', _helloSha).readAsString(),
        'hello',
      );
      expect(
        await cached('room_depth.tflite', _worldSha).readAsString(),
        'world',
      );
      expect(requests, ['/seg', '/depth']);
      expect(subject.progress.stage, RoomModelDownloadStage.ready);
      expect(subject.progress.receivedBytes, 10);
      expect(subject.progress.totalBytes, 10);
      expect(
        progress.any((p) => p.stage == RoomModelDownloadStage.downloading),
        isTrue,
      );
      expect(
        progress.any((p) => p.stage == RoomModelDownloadStage.verifying),
        isTrue,
      );
      expect(await partials(), isEmpty);
    },
  );

  test(
    'a new store reuses verified files without creating an HTTP client',
    () async {
      await store().load();
      var clientCreated = false;
      final offline = RoomModelStore(
        directory: () async => root,
        artifacts: artifacts,
        clientFactory: () {
          clientCreated = true;
          throw const SocketException('offline');
        },
      );
      stores.add(offline);

      final bytes = await offline.load();

      expect(utf8.decode(bytes.depth), 'world');
      expect(clientCreated, isFalse);
      expect(requests, ['/seg', '/depth']);
    },
  );

  test('same-size corrupt cache is redownloaded before native use', () async {
    await store().load();
    await cached('room_depth.tflite', _worldSha).writeAsString('wrong');
    final result = await store().load();
    expect(utf8.decode(result.depth), 'world');
    expect(requests, ['/seg', '/depth', '/depth']);
  });

  test(
    'wrong hash is never promoted and verified peer remains usable',
    () async {
      respond = (request) async {
        request.response.write(request.uri.path == '/seg' ? 'hello' : 'wrong');
        await request.response.close();
      };
      await expectLater(
        store().load(),
        throwsA(isA<RoomModelDownloadException>()),
      );
      expect(
        await cached('room_seg.tflite', _helloSha).readAsString(),
        'hello',
      );
      expect(await cached('room_depth.tflite', _worldSha).exists(), isFalse);
      expect(await partials(), isEmpty);
    },
  );

  for (final body in ['hell', 'hello!']) {
    test(
      'rejects wrong byte count ${body.length} and removes partial file',
      () async {
        respond = (request) async {
          request.response.write(body);
          await request.response.close();
        };
        await expectLater(
          store().load(),
          throwsA(isA<RoomModelDownloadException>()),
        );
        expect(await cached('room_seg.tflite', _helloSha).exists(), isFalse);
        expect(await partials(), isEmpty);
      },
    );
  }

  test(
    'non-200 response fails safely and an explicit retry recovers',
    () async {
      var fail = true;
      respond = (request) async {
        if (fail) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.write(
            request.uri.path == '/seg' ? 'hello' : 'world',
          );
        }
        await request.response.close();
      };
      final subject = store();
      await expectLater(
        subject.load(),
        throwsA(isA<RoomModelDownloadException>()),
      );
      expect(subject.progress.stage, RoomModelDownloadStage.failed);
      fail = false;
      final result = await subject.load();
      expect(utf8.decode(result.depth), 'world');
    },
  );

  test('concurrent loads share a single download of each file', () async {
    final subject = store();
    final results = await Future.wait([
      subject.load(),
      subject.load(),
      subject.load(),
    ]);
    expect(results.map((r) => utf8.decode(r.semantic)), [
      'hello',
      'hello',
      'hello',
    ]);
    expect(requests, ['/seg', '/depth']);
  });

  test(
    'cancel aborts an active body, cleans partials and allows immediate retry',
    () async {
      final gate = Completer<void>();
      var block = true;
      respond = (request) async {
        if (block) {
          request.response.contentLength = 5;
          request.response.bufferOutput = false;
          request.response.add([104]);
          await request.response.flush();
          await gate.future;
        } else {
          request.response.write(
            request.uri.path == '/seg' ? 'hello' : 'world',
          );
        }
        await request.response.close();
      };
      addTearDown(() {
        if (!gate.isCompleted) gate.complete();
      });
      final subject = store();
      final firstChunk = subject.changes.firstWhere(
        (p) =>
            p.stage == RoomModelDownloadStage.downloading &&
            p.receivedBytes > 0,
      );
      final pending = subject.load();
      final cancelled = expectLater(
        pending,
        throwsA(isA<RoomModelDownloadException>()),
      );
      await firstChunk;
      subject.cancel();
      block = false;
      final retry = subject.load();
      await cancelled;
      expect(utf8.decode((await retry).depth), 'world');
      expect(await partials(), isEmpty);
      expect(subject.progress.stage, RoomModelDownloadStage.ready);
    },
  );

  test(
    'offline error does not discard previously verified model files',
    () async {
      await store().load();
      await cached('room_depth.tflite', _worldSha).delete();
      final offline = RoomModelStore(
        directory: () async => root,
        artifacts: artifacts,
        clientFactory: () => throw const SocketException('offline'),
      );
      stores.add(offline);
      await expectLater(
        offline.load(),
        throwsA(isA<RoomModelDownloadException>()),
      );
      expect(
        await cached('room_seg.tflite', _helloSha).readAsString(),
        'hello',
      );
      expect(await partials(), isEmpty);
    },
  );

  test('closed store refuses loads without touching network', () async {
    final subject = store();
    await subject.close();
    await expectLater(
      subject.load(),
      throwsA(isA<RoomModelDownloadException>()),
    );
    expect(requests, isEmpty);
  });

  test('a second cancel invalidates a retry waiting for old cleanup', () async {
    final gate = Completer<Directory>();
    var directoryCalls = 0;
    final subject = RoomModelStore(
      directory: () {
        directoryCalls++;
        return directoryCalls == 1 ? gate.future : Future.value(root);
      },
      artifacts: artifacts,
    );
    stores.add(subject);
    final first = subject.load();
    final firstCancelled = expectLater(
      first,
      throwsA(isA<RoomModelDownloadException>()),
    );
    subject.cancel();
    final waitingRetry = subject.load();
    final retryCancelled = expectLater(
      waitingRetry,
      throwsA(isA<RoomModelDownloadException>()),
    );
    subject.cancel();
    gate.complete(root);
    await firstCancelled;
    await retryCancelled;
    expect(directoryCalls, 1);
    expect(requests, isEmpty);
    expect(utf8.decode((await subject.load()).depth), 'world');
  });

  test(
    'stalled response body fails with bounded timeout and cleans partial',
    () async {
      final gate = Completer<void>();
      respond = (request) async {
        request.response.contentLength = 5;
        request.response.bufferOutput = false;
        request.response.add([104]);
        await request.response.flush();
        await gate.future;
        await request.response.close();
      };
      addTearDown(() => gate.complete());
      final subject = RoomModelStore(
        directory: () async => root,
        artifacts: artifacts,
        timeout: const Duration(milliseconds: 100),
      );
      stores.add(subject);
      await expectLater(
        subject.load(),
        throwsA(isA<RoomModelDownloadException>()),
      );
      expect(subject.progress.stage, RoomModelDownloadStage.failed);
      expect(await partials(), isEmpty);
    },
  );

  test(
    'cancellation before response headers does not wait for network timeout',
    () async {
      final receivedRequest = Completer<void>();
      final gate = Completer<void>();
      respond = (request) async {
        receivedRequest.complete();
        await gate.future;
        await request.response.close();
      };
      addTearDown(() => gate.complete());
      final subject = store();
      final pending = subject.load();
      final failure = expectLater(
        pending,
        throwsA(isA<RoomModelDownloadException>()),
      );
      await receivedRequest.future;
      subject.cancel();
      await failure.timeout(const Duration(seconds: 2));
      expect(subject.progress.stage, RoomModelDownloadStage.cancelled);
      expect(await partials(), isEmpty);
    },
  );
}
