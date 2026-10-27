import 'dart:async';
import 'dart:io';

import 'package:color_lab/features/room_studio/application/room_model_download_providers.dart';
import 'package:color_lab/features/room_studio/application/room_model_setup_controller.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _sha = '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824';

void main() {
  late Directory root;
  late HttpServer server;
  late RoomModelStore store;
  late ProviderContainer container;
  late Future<Directory> Function() directory;
  late Future<void> Function(HttpRequest) respond;
  late int requests;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('room-setup-controller-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = 0;
    directory = () async => root;
    respond = (request) async {
      request.response.write('hello');
      await request.response.close();
    };
    server.listen((request) async {
      requests++;
      try {
        await respond(request);
      } catch (_) {}
    });
    store = RoomModelStore(
      directory: () => directory(),
      artifacts: [
        for (final name in ['room_seg.tflite', 'room_depth.tflite'])
          RoomModelArtifact(
            name: name,
            url: 'http://127.0.0.1:${server.port}/$name',
            bytes: 5,
            sha256: _sha,
          ),
      ],
    );
    container = ProviderContainer(
      overrides: [roomModelStoreProvider.overrideWithValue(store)],
    );
  });
  tearDown(() async {
    container.dispose();
    await store.close();
    await server.close(force: true);
    await root.delete(recursive: true);
  });

  test(
    'check transitions through checking to notInstalled without network',
    () async {
      final states = <RoomModelAvailability>[];
      container.listen(
        roomModelSetupProvider,
        (_, next) => states.add(next.availability),
      );
      expect(
        container.read(roomModelSetupProvider).availability,
        RoomModelAvailability.notInstalled,
      );
      await container.read(roomModelSetupProvider.notifier).check();
      expect(states, [
        RoomModelAvailability.checking,
        RoomModelAvailability.notInstalled,
      ]);
      expect(requests, 0);
      expect(
        await container
            .read(roomModelSetupProvider.notifier)
            .continueWithCachedModels(),
        isFalse,
      );
      expect(container.read(roomModelSetupProvider).canEnter, isFalse);
    },
  );

  test('download verifies then waits for explicit offline Continue', () async {
    final states = <RoomModelAvailability>[];
    container.listen(
      roomModelSetupProvider,
      (_, next) => states.add(next.availability),
    );
    final controller = container.read(roomModelSetupProvider.notifier);
    await controller.download();
    expect(
      states,
      containsAllInOrder([
        RoomModelAvailability.downloading,
        RoomModelAvailability.verifying,
        RoomModelAvailability.ready,
      ]),
    );
    expect(container.read(roomModelSetupProvider).canEnter, isFalse);
    expect(requests, 2);
    await server.close(force: true);
    expect(await controller.continueWithCachedModels(), isTrue);
    expect(container.read(roomModelSetupProvider).canEnter, isTrue);
    expect(requests, 2);
  });

  test(
    'verified cache is ready without permission until Continue rechecks it',
    () async {
      await store.prepare();
      final controller = container.read(roomModelSetupProvider.notifier);
      await controller.check();
      expect(
        container.read(roomModelSetupProvider).availability,
        RoomModelAvailability.ready,
      );
      expect(container.read(roomModelSetupProvider).canEnter, isFalse);
      await File(
        '${root.path}/room_models/$_sha/room_depth.tflite',
      ).writeAsString('wrong');
      expect(await controller.continueWithCachedModels(), isFalse);
      expect(
        container.read(roomModelSetupProvider).availability,
        RoomModelAvailability.notInstalled,
      );
      expect(requests, 2);
    },
  );

  for (final code in [Platform.isWindows ? 112 : 28, 13]) {
    test(
      'typed I/O failure $code maps to safe state and Retry recovers',
      () async {
        directory = () async => throw FileSystemException(
          'secret',
          '/private',
          OSError('secret', code),
        );
        final controller = container.read(roomModelSetupProvider.notifier);
        await controller.download();
        expect(
          container.read(roomModelSetupProvider).availability,
          code != 13
              ? RoomModelAvailability.storageFull
              : RoomModelAvailability.failed,
        );
        directory = () async => root;
        await controller.retry();
        expect(
          container.read(roomModelSetupProvider).availability,
          RoomModelAvailability.ready,
        );
      },
    );
  }

  test(
    'Cancel is immediate and stale completion cannot overwrite fresh Retry',
    () async {
      final gate = Completer<Directory>();
      directory = () => gate.future;
      final controller = container.read(roomModelSetupProvider.notifier);
      final pending = controller.download();
      controller.cancel();
      expect(
        container.read(roomModelSetupProvider).availability,
        RoomModelAvailability.cancelled,
      );
      directory = () async => root;
      final retry = controller.retry();
      gate.complete(root);
      await pending;
      await retry;
      expect(
        container.read(roomModelSetupProvider).availability,
        RoomModelAvailability.ready,
      );
      expect(requests, 2);
    },
  );

  test('cancelled cache check cannot publish late ready', () async {
    final gate = Completer<Directory>();
    directory = () => gate.future;
    final controller = container.read(roomModelSetupProvider.notifier);
    final pending = controller.check();
    controller.cancel();
    gate.complete(root);
    await pending;
    expect(
      container.read(roomModelSetupProvider).availability,
      RoomModelAvailability.cancelled,
    );
    expect(requests, 0);
  });

  test('disposal cancels active work and ignores completion', () async {
    final gate = Completer<Directory>();
    directory = () => gate.future;
    final controller = container.read(roomModelSetupProvider.notifier);
    final pending = controller.download();
    container.dispose();
    gate.complete(root);
    await pending;
    expect(store.progress.stage, RoomModelDownloadStage.cancelled);
    expect(requests, 0);
  });
}
