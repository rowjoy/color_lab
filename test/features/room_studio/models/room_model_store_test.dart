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
    'cache-only check never constructs a client and requires both hashes',
    () async {
      final subject = RoomModelStore(
        directory: () async => root,
        artifacts: artifacts,
        clientFactory: () => throw StateError('check must not create a client'),
      );
      stores.add(subject);
      expect(await subject.check(), isFalse);
      for (final entry in [
        ('room_seg.tflite', _helloSha, 'hello'),
        ('room_depth.tflite', _worldSha, 'world'),
      ]) {
        final file = cached(entry.$1, entry.$2);
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.$3);
      }
      expect(await subject.check(), isTrue);
      expect(subject.progress.stage, RoomModelDownloadStage.ready);
      await cached('room_depth.tflite', _worldSha).writeAsString('wrong');
      expect(await subject.check(), isFalse);
      expect(subject.progress.stage, RoomModelDownloadStage.idle);
      expect(requests, isEmpty);
    },
  );

  test('setup aggregate is derived from pinned artifact bytes', () async {
    final subject = RoomModelStore(directory: () async => root);
    stores.add(subject);
    expect(subject.progress.totalBytes, 68316288);
  });

  Future<File> seedPartial(String body) async {
    final file = File('${cached('room_seg.tflite', _helloSha).path}.part');
    await file.parent.create(recursive: true);
    await file.writeAsString(body);
    return file;
  }

  test(
    'valid range resumes actual partial bytes with identity encoding',
    () async {
      await seedPartial('he');
      final ranges = <String?>[];
      respond = (request) async {
        ranges.add(request.headers.value(HttpHeaders.rangeHeader));
        expect(
          request.headers.value(HttpHeaders.acceptEncodingHeader),
          'identity',
        );
        if (request.uri.path == '/seg') {
          request.response.statusCode = 206;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 2-4/5',
          );
          request.response.contentLength = 3;
          request.response.write('llo');
        } else {
          request.response.write('world');
        }
        await request.response.close();
      };
      expect(utf8.decode((await store().load()).semantic), 'hello');
      expect(ranges, ['bytes=2-', null]);
    },
  );

  for (final kind in [
    'ignored',
    'malformed',
    'rejected',
    'wrong-length',
    'wrong-total',
    'wrong-end',
    'overflow',
  ]) {
    test('$kind range restarts safely with at most one clean fallback', () async {
      await seedPartial('he');
      final ranges = <String?>[];
      respond = (request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range);
        if (range != null && kind != 'ignored') {
          request.response.statusCode = kind == 'rejected' ? 416 : 206;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            switch (kind) {
              'wrong-length' => 'bytes 2-4/5',
              'wrong-total' => 'bytes 2-4/6',
              'wrong-end' => 'bytes 2-3/5',
              'overflow' =>
                'bytes 9999999999999999999999999999999999999999999999999999-4/5',
              _ => 'bytes 0-4/5',
            },
          );
          if (kind == 'wrong-length') request.response.contentLength = 4;
          request.response.write('bad!');
        } else {
          request.response.write(
            request.uri.path == '/seg' ? 'hello' : 'world',
          );
        }
        await request.response.close();
      };
      expect(utf8.decode((await store().load()).semantic), 'hello');
      expect(
        ranges,
        kind == 'ignored' ? ['bytes=2-', null] : ['bytes=2-', null, null],
      );
    });
  }

  test(
    'separate duplicate Content-Range lines take one clean full fallback',
    () async {
      await seedPartial('he');
      final rawServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final sockets = <Socket>[];
      final rawRequests = <String>[];
      final subscription = rawServer.listen((socket) {
        sockets.add(socket);
        var headers = '';
        var replied = false;
        socket.listen((chunk) {
          if (replied) return;
          headers += latin1.decode(chunk);
          if (!headers.contains('\r\n\r\n')) return;
          replied = true;
          rawRequests.add(headers);
          final range = headers.toLowerCase().contains('range: bytes=2-\r\n');
          final segmentation = headers.startsWith('GET /seg ');
          final body = range
              ? 'llo'
              : segmentation
              ? 'hello'
              : 'world';
          final response = range
              ? 'HTTP/1.1 206 Partial Content\r\nContent-Range: bytes 2-4/5\r\nContent-Range: bytes 2-4/5\r\n'
              : 'HTTP/1.1 200 OK\r\n';
          socket.add(
            latin1.encode(
              '$response'
              'Content-Length: ${body.length}\r\nConnection: close\r\n\r\n$body',
            ),
          );
          unawaited(socket.flush().then((_) => socket.close()));
        }, onError: (Object _) {});
      });
      addTearDown(() async {
        for (final socket in sockets) {
          socket.destroy();
        }
        await subscription.cancel();
        await rawServer.close();
      });
      final subject = RoomModelStore(
        directory: () async => root,
        artifacts: [
          for (final artifact in artifacts)
            RoomModelArtifact(
              name: artifact.name,
              url:
                  'http://127.0.0.1:${rawServer.port}${Uri.parse(artifact.url).path}',
              bytes: artifact.bytes,
              sha256: artifact.sha256,
            ),
        ],
      );
      stores.add(subject);
      expect(utf8.decode((await subject.load()).semantic), 'hello');
      expect(rawRequests, hasLength(3));
      expect(rawRequests[0], contains('GET /seg '));
      expect(rawRequests[0].toLowerCase(), contains('range: bytes=2-\r\n'));
      expect(rawRequests[1], contains('GET /seg '));
      expect(rawRequests[1].toLowerCase(), isNot(contains('range:')));
      expect(rawRequests[2], contains('GET /depth '));
      expect(subject.progress.stage, RoomModelDownloadStage.ready);
    },
  );

  test('rejected clean fallback is bounded and never promotes', () async {
    final partial = await seedPartial('he');
    respond = (request) async {
      request.response.statusCode = 416;
      await request.response.close();
    };
    await expectLater(
      store().prepare(),
      throwsA(isA<RoomModelDownloadException>()),
    );
    expect(requests, ['/seg', '/seg']);
    expect(await partial.readAsString(), 'he');
    expect(await cached('room_seg.tflite', _helloSha).exists(), isFalse);
  });

  test(
    'complete partial verifies and promotes without requesting its model',
    () async {
      await seedPartial('hello');
      await store().prepare();
      expect(requests, ['/depth']);
      expect(
        await cached('room_seg.tflite', _helloSha).readAsString(),
        'hello',
      );
    },
  );

  test('complete wrong-hash partial is removed and never promoted', () async {
    final partial = await seedPartial('wrong');
    await expectLater(
      store().prepare(),
      throwsA(isA<RoomModelDownloadException>()),
    );
    expect(await partial.exists(), isFalse);
    expect(await cached('room_seg.tflite', _helloSha).exists(), isFalse);
    expect(requests, isEmpty);
  });

  final capacityCodes = Platform.isWindows
      ? [39, 112, 1295]
      : Platform.isMacOS || Platform.isIOS
      ? [28, 69]
      : [28, 122];
  for (final code in [28, 39, 69, 112, 122, 1295, 13, 5]) {
    test(
      'I/O code $code maps capacity separately from safe generic failure',
      () async {
        final subject = RoomModelStore(
          directory: () async => throw FileSystemException(
            'private path',
            '/secret',
            OSError('private', code),
          ),
          artifacts: artifacts,
        );
        stores.add(subject);
        await expectLater(
          subject.prepare(),
          throwsA(
            isA<RoomModelDownloadException>().having(
              (e) => e.storageFull,
              'storage full',
              capacityCodes.contains(code),
            ),
          ),
        );
        expect(
          subject.progress.stage,
          capacityCodes.contains(code)
              ? RoomModelDownloadStage.storageFull
              : RoomModelDownloadStage.failed,
        );
      },
    );
  }

  for (final code in [Platform.isWindows ? 112 : 28, 13]) {
    test(
      'partial-file write failure $code is typed without exposing paths',
      () async {
        final subject = store();
        await IOOverrides.runWithIOOverrides(() async {
          await expectLater(
            subject.prepare(),
            throwsA(
              isA<RoomModelDownloadException>().having(
                (e) => e.storageFull,
                'storage full',
                code != 13,
              ),
            ),
          );
        }, _WriteFailureIO(code));
        expect(
          subject.progress.stage,
          code != 13
              ? RoomModelDownloadStage.storageFull
              : RoomModelDownloadStage.failed,
        );
        expect(await cached('room_seg.tflite', _helloSha).exists(), isFalse);
      },
    );
  }

  for (final phase in ['addStream', 'flush', 'close']) {
    for (final code in [Platform.isWindows ? 112 : 28, 13]) {
      test(
        'deferred $phase failure $code retains safe partial and retries',
        () async {
          final subject = store();
          final fault = _AsyncSinkIO(phase, code);
          await IOOverrides.runWithIOOverrides(() async {
            await expectLater(
              subject.prepare(),
              throwsA(
                isA<RoomModelDownloadException>().having(
                  (e) => e.storageFull,
                  'capacity is distinct',
                  code != 13,
                ),
              ),
            );
          }, fault);
          expect(fault.injected, isTrue);
          expect(
            subject.progress.stage,
            code == 13
                ? RoomModelDownloadStage.failed
                : RoomModelDownloadStage.storageFull,
          );
          expect(await cached('room_seg.tflite', _helloSha).exists(), isFalse);
          final partial = File(
            '${cached('room_seg.tflite', _helloSha).path}.part',
          );
          expect(
            await partial.readAsString(),
            phase == 'addStream' ? 'he' : 'hello',
          );
          final ranges = <String?>[];
          respond = (request) async {
            final range = request.headers.value(HttpHeaders.rangeHeader);
            ranges.add(range);
            if (range != null) {
              request.response.statusCode = 206;
              request.response.headers.set(
                HttpHeaders.contentRangeHeader,
                'bytes 2-4/5',
              );
              request.response.write('llo');
            } else {
              request.response.write(
                request.uri.path == '/seg' ? 'hello' : 'world',
              );
            }
            await request.response.close();
          };
          final result = await subject.load();
          expect(utf8.decode(result.semantic), 'hello');
          expect(utf8.decode(result.depth), 'world');
          expect(ranges, phase == 'addStream' ? ['bytes=2-', null] : [null]);
          expect(await partials(), isEmpty);
          expect(subject.progress.stage, RoomModelDownloadStage.ready);
        },
      );
    }
  }

  test(
    'cancel publishes immediately and retains flushed bytes for retry',
    () async {
      final release = Completer<void>();
      final ranges = <String?>[];
      respond = (request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range);
        if (ranges.length == 1) {
          request.response.contentLength = 5;
          request.response.bufferOutput = false;
          request.response.write('he');
          await request.response.flush();
          await release.future;
        } else if (range != null) {
          request.response.statusCode = 206;
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes 2-4/5',
          );
          request.response.write('llo');
        } else {
          request.response.write(
            request.uri.path == '/seg' ? 'hello' : 'world',
          );
        }
        await request.response.close();
      };
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final subject = store();
      final chunk = subject.changes.firstWhere((p) => p.receivedBytes == 2);
      final pending = subject.prepare();
      final failure = expectLater(
        pending,
        throwsA(isA<RoomModelDownloadException>()),
      );
      await chunk;
      subject.cancel();
      expect(subject.progress.stage, RoomModelDownloadStage.cancelled);
      await failure;
      expect(
        await File(
          '${cached('room_seg.tflite', _helloSha).path}.part',
        ).readAsString(),
        'he',
      );
      await subject.prepare();
      expect(ranges, [null, 'bytes=2-', null]);
      expect(subject.progress.stage, RoomModelDownloadStage.ready);
    },
  );

  for (final body in ['he', 'hello']) {
    test(
      'cancel during partial metadata read keeps cancellation terminal for $body',
      () async {
        await seedPartial(body);
        var clients = 0;
        final subject = RoomModelStore(
          directory: () async => root,
          artifacts: artifacts,
          clientFactory: () {
            clients++;
            return HttpClient();
          },
        );
        stores.add(subject);
        final boundary = _PartialLengthIO();
        await IOOverrides.runWithIOOverrides(() async {
          final pending = subject.prepare();
          final failure = expectLater(
            pending,
            throwsA(isA<RoomModelDownloadException>()),
          );
          await boundary.started.future;
          subject.cancel();
          expect(subject.progress.stage, RoomModelDownloadStage.cancelled);
          boundary.release.complete();
          await failure;
        }, boundary);
        expect(subject.progress.stage, RoomModelDownloadStage.cancelled);
        expect(
          clients,
          0,
          reason: 'Cancelled metadata work must never create a client',
        );
      },
    );
  }

  for (final cacheOnly in [true, false]) {
    for (final boundary in ['root', 'sha', 'final', 'partial']) {
      for (final kind in ['link', 'nonregular']) {
        test(
          '${cacheOnly ? 'check' : 'prepare'} rejects $kind at $boundary boundary without following it',
          () async {
            final outside = Directory('${root.path}/unrelated');
            await outside.create();
            final target = cached('room_seg.tflite', _helloSha);
            final modelRoot = Directory('${root.path}/room_models');
            final peer = cached('room_depth.tflite', _worldSha);
            String entryPath;
            String externalPath;
            if (boundary == 'root') {
              entryPath = modelRoot.path;
              externalPath = outside.path;
              for (final entry in [
                (_helloSha, 'room_seg.tflite', 'hello'),
                (_worldSha, 'room_depth.tflite', 'world'),
              ]) {
                final file = File('${outside.path}/${entry.$1}/${entry.$2}');
                await file.parent.create(recursive: true);
                await file.writeAsString(entry.$3);
              }
            } else {
              await modelRoot.create();
              if (boundary == 'sha') {
                entryPath = target.parent.path;
                externalPath = outside.path;
                await File(
                  '${outside.path}/room_seg.tflite',
                ).writeAsString('hello');
              } else {
                await target.parent.create();
                entryPath =
                    '${target.path}${boundary == 'partial' ? '.part' : ''}';
                externalPath = '${outside.path}/original';
                await File(
                  externalPath,
                ).writeAsString(boundary == 'partial' ? 'he' : 'hello');
              }
              await peer.parent.create(recursive: true);
              await peer.writeAsString('world');
            }
            if (kind == 'link') {
              await Link(entryPath).create(externalPath);
            } else if (boundary == 'root' || boundary == 'sha') {
              await File(entryPath).writeAsString('unrelated entry');
            } else {
              await Directory(entryPath).create();
            }
            final before = await _snapshot(outside);
            var clients = 0;
            final subject = RoomModelStore(
              directory: () async => root,
              artifacts: artifacts,
              clientFactory: () {
                clients++;
                return HttpClient();
              },
            );
            stores.add(subject);
            await expectLater(
              cacheOnly ? subject.check() : subject.prepare(),
              throwsA(
                isA<RoomModelDownloadException>().having(
                  (error) => error.storageFull,
                  'safe generic failure',
                  isFalse,
                ),
              ),
            );
            expect(subject.progress.stage, RoomModelDownloadStage.failed);
            expect(clients, 0);
            expect(requests, isEmpty);
            expect(await _snapshot(outside), before);
            expect(
              await FileSystemEntity.type(entryPath, followLinks: false),
              kind == 'link'
                  ? FileSystemEntityType.link
                  : boundary == 'root' || boundary == 'sha'
                  ? FileSystemEntityType.file
                  : FileSystemEntityType.directory,
            );
            if (boundary == 'partial') {
              expect(
                await FileSystemEntity.type(target.path, followLinks: false),
                FileSystemEntityType.notFound,
              );
            }
          },
        );
      }
    }
  }

  for (final body in ['hello', null]) {
    test(
      'prepare rejects ${body == null ? 'dangling' : 'complete'} partial link without promotion',
      () async {
        final external = File('${root.path}/unrelated-model');
        if (body != null) await external.writeAsString(body);
        final target = cached('room_seg.tflite', _helloSha);
        await target.parent.create(recursive: true);
        final partial = Link('${target.path}.part');
        await partial.create(external.path);
        final peer = cached('room_depth.tflite', _worldSha);
        await peer.parent.create(recursive: true);
        await peer.writeAsString('world');
        final subject = store();
        await expectLater(
          subject.prepare(),
          throwsA(isA<RoomModelDownloadException>()),
        );
        expect(requests, isEmpty);
        expect(await partial.exists(), isTrue);
        expect(
          await FileSystemEntity.type(target.path, followLinks: false),
          FileSystemEntityType.notFound,
        );
        expect(await external.exists(), body != null);
        if (body != null) expect(await external.readAsString(), body);
      },
    );
  }

  test(
    'partial changed to a link while awaiting headers is rejected before writing',
    () async {
      final partial = await seedPartial('he');
      final external = File('${root.path}/unrelated-model');
      await external.writeAsString('he');
      final peer = cached('room_depth.tflite', _worldSha);
      await peer.parent.create(recursive: true);
      await peer.writeAsString('world');
      respond = (request) async {
        await partial.delete();
        await Link(partial.path).create(external.path);
        request.response.statusCode = 206;
        request.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes 2-4/5',
        );
        request.response.contentLength = 3;
        request.response.write('llo');
        await request.response.close();
      };
      await expectLater(
        store().prepare(),
        throwsA(isA<RoomModelDownloadException>()),
      );
      expect(await external.readAsString(), 'he');
      expect(
        await FileSystemEntity.type(partial.path, followLinks: false),
        FileSystemEntityType.link,
      );
      expect(
        await FileSystemEntity.type(
          cached('room_seg.tflite', _helloSha).path,
          followLinks: false,
        ),
        FileSystemEntityType.notFound,
      );
      expect(requests, ['/seg']);
    },
  );

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
    test('rejects wrong byte count ${body.length} without promoting', () async {
      respond = (request) async {
        request.response.write(body);
        await request.response.close();
      };
      await expectLater(
        store().load(),
        throwsA(isA<RoomModelDownloadException>()),
      );
      expect(await cached('room_seg.tflite', _helloSha).exists(), isFalse);
      expect(await partials(), body.length < 5 ? hasLength(1) : isEmpty);
    });
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
    'stalled response body fails with bounded timeout and retains partial',
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
      expect(await partials(), hasLength(1));
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

final class _WriteFailureIO extends IOOverrides {
  _WriteFailureIO(this.code);
  final int code;
  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.endsWith('.part') ? _WriteFailureFile(file, code) : file;
  }
}

class _WriteFailureFile implements File {
  _WriteFailureFile(this.delegate, this.code);
  final File delegate;
  final int code;
  @override
  String get path => delegate.path;
  @override
  Future<bool> exists() => delegate.exists();
  @override
  IOSink openWrite({
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
  }) => throw FileSystemException(
    'private write failure',
    path,
    OSError('private', code),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _PartialLengthIO extends IOOverrides {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.endsWith('.part') ? _PartialLengthFile(file, this) : file;
  }
}

class _PartialLengthFile implements File {
  _PartialLengthFile(this.delegate, this.boundary);
  final File delegate;
  final _PartialLengthIO boundary;
  @override
  String get path => delegate.path;
  @override
  Future<bool> exists() => delegate.exists();
  @override
  Future<int> length() async {
    if (!boundary.started.isCompleted) boundary.started.complete();
    await boundary.release.future;
    return delegate.length();
  }

  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      delegate.openRead(start, end);
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) =>
      delegate.open(mode: mode);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Map<String, String>> _snapshot(Directory directory) async => {
  await for (final entry in directory.list(recursive: true, followLinks: false))
    if (entry is File) entry.path: await entry.readAsString(),
};

final class _AsyncSinkIO extends IOOverrides {
  _AsyncSinkIO(this.phase, this.code);
  final String phase;
  final int code;
  bool injected = false;
  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.endsWith('.part') ? _AsyncSinkFile(file, this) : file;
  }

  Future<void> fail() async {
    await Future<void>.delayed(Duration.zero);
    injected = true;
    throw FileSystemException(
      'injected asynchronous sink error',
      '',
      OSError('', code),
    );
  }
}

class _AsyncSinkFile implements File {
  _AsyncSinkFile(this.file, this.fault);
  final File file;
  final _AsyncSinkIO fault;
  @override
  String get path => file.path;
  @override
  Directory get parent => file.parent;
  @override
  Future<bool> exists() => file.exists();
  @override
  Future<int> length() => file.length();
  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      file.openRead(start, end);
  @override
  IOSink openWrite({
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
  }) => _AsyncSink(file.openWrite(mode: mode, encoding: encoding), fault);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AsyncSink implements IOSink {
  _AsyncSink(this.sink, this.fault);
  final IOSink sink;
  final _AsyncSinkIO fault;
  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    if (fault.phase != 'addStream') return sink.addStream(stream);
    await for (final bytes in stream) {
      sink.add(bytes.take(2).toList());
      await sink.flush();
      await fault.fail();
    }
  }

  @override
  Future<void> flush() async {
    await sink.flush();
    if (fault.phase == 'flush') await fault.fail();
  }

  @override
  Future<void> close() async {
    await sink.close();
    if (fault.phase == 'close') await fault.fail();
  }

  @override
  Future<void> get done => sink.done;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
