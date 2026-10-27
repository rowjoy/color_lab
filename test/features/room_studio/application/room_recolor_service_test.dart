import 'dart:async';
import 'dart:isolate';

import 'package:color_lab/features/room_studio/application/room_recolor_scheduler.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../support/controlled_room_recolor_worker.dart';

void _hungRenderer((SendPort, SendPort) ports) {
  final commands = ReceivePort();
  ports.$1.send(commands.sendPort);
  commands.listen((_) {
    ports.$2.send(null);
    while (true) {
      // A synchronous compute hang cannot cooperate with cancellation.
    }
  });
}

IsolateRoomRecolorWorker _hungWorker(SendPort enteredCompute) =>
    IsolateRoomRecolorWorker(
      spawn: (_, output, exit, errors) => Isolate.spawn(
        _hungRenderer,
        (output, enteredCompute),
        onExit: exit,
        onError: errors,
        errorsAreFatal: true,
      ),
    );

void main() {
  test(
    'ProviderContainer disposal terminates a real worker and resolves every ticket',
    () async {
      late IsolateRoomRecolorWorker worker;
      final enteredCompute = ReceivePort();
      addTearDown(enteredCompute.close);
      final watchdogs = ManualWatchdogs();
      final container = ProviderContainer(
        overrides: [
          roomRecolorWorkerFactoryProvider.overrideWithValue(
            () => worker = _hungWorker(enteredCompute.sendPort),
          ),
          roomRecolorWatchdogFactoryProvider.overrideWithValue(
            watchdogs.create,
          ),
        ],
      );
      final scheduler = container.read(roomRecolorSchedulerProvider);
      addTearDown(() async {
        container.dispose();
        await scheduler.close();
      });
      final ticket = scheduler.renderLatest(
        RoomRecolorRequest(lifetime: Object(), active: recolorInput(0)),
      );
      await flushRecolor();
      await worker.ready;
      await enteredCompute.first;
      container.dispose();
      expect((await ticket.active).status, RoomRecolorStatus.closed);
      await scheduler.close();
      await worker.exited;
      expect(watchdogs.timers.every((timer) => timer.cancelled), isTrue);
    },
  );

  test(
    'real worker returns detached matching pixels and confirms termination',
    () async {
      final worker = IsolateRoomRecolorWorker();
      addTearDown(worker.terminate);
      await worker.ready;
      final input = recolorInput(0);
      final frame = await worker.render(input);
      expect(frame.key, input.key);
      expect(frame.width, 1);
      expect(frame.pngBytes, isNotEmpty);
      expect(() => frame.rgbaBytes[0] = 0, throwsUnsupportedError);
      frame.dispose();
      await worker.terminate();
      await worker.exited;
      await worker.terminate();
    },
  );

  test(
    'real isolate hang is killed before replacement can render same-key retry',
    () async {
      final workers = <IsolateRoomRecolorWorker>[];
      final enteredCompute = ReceivePort();
      addTearDown(enteredCompute.close);
      final watchdogs = ManualWatchdogs();
      final scheduler = RoomRecolorScheduler(
        workerFactory: () {
          final worker = workers.isEmpty
              ? _hungWorker(enteredCompute.sendPort)
              : IsolateRoomRecolorWorker();
          workers.add(worker);
          return worker;
        },
        watchdogFactory: watchdogs.create,
      );
      addTearDown(scheduler.close);
      final request = RoomRecolorRequest(
        lifetime: Object(),
        active: recolorInput(0),
      );
      final first = scheduler.renderLatest(request);
      await flushRecolor();
      await workers.single.ready;
      await enteredCompute.first;
      var exited = false;
      workers.single.exited.then((_) => exited = true);
      watchdogs.fire();
      expect((await first.active).status, RoomRecolorStatus.timeout);
      final retry = scheduler.renderLatest(request);
      await workers.first.exited;
      await flushRecolor();
      expect(exited, isTrue);
      final result = await retry.active;
      expect(workers, hasLength(2));
      expect(result.status, RoomRecolorStatus.rendered);
      expect(result.frame!.key, request.active.key);
      result.frame!.dispose();
    },
  );

  test(
    'cancellation during async spawn kills the late-created isolate',
    () async {
      final gate = Completer<void>();
      var spawned = false;
      final worker = IsolateRoomRecolorWorker(
        spawn: (entry, output, exit, errors) async {
          await gate.future;
          final isolate = await Isolate.spawn(
            entry,
            output,
            onExit: exit,
            onError: errors,
            errorsAreFatal: true,
          );
          spawned = true;
          return isolate;
        },
      );
      final ready = expectLater(
        worker.ready,
        throwsA(isA<RoomRecolorWorkerStopped>()),
      );
      var terminated = false;
      final barrier = worker.terminate().then((_) => terminated = true);
      await flushRecolor();
      expect(terminated, isFalse);
      expect(spawned, isFalse);
      gate.complete();
      await barrier;
      await ready;
      expect(spawned, isTrue);
      await worker.exited;
      expect(terminated, isTrue);
    },
  );
}
