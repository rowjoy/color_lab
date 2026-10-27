import 'package:color_lab/features/room_studio/application/room_recolor_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/controlled_room_recolor_worker.dart';

void main() {
  late ControlledWorkers workers;
  late ManualWatchdogs watchdogs;
  late RoomRecolorScheduler scheduler;
  final lifetime = Object();
  RoomRecolorRequest request(
    int revision, {
    bool compare = false,
    String project = 'project',
  }) => RoomRecolorRequest(
    lifetime: lifetime,
    active: recolorInput(revision, project: project),
    baseline: compare
        ? recolorInput(revision, project: project, variant: 'b')
        : null,
  );
  setUp(() {
    workers = ControlledWorkers();
    watchdogs = ManualWatchdogs();
    scheduler = RoomRecolorScheduler(
      workerFactory: workers.create,
      watchdogFactory: watchdogs.create,
    );
  });
  tearDown(() async {
    for (final w in workers.workers) {
      if (!w.exit.isCompleted) w.exit.complete();
    }
    await scheduler.close();
  });

  test(
    '100 callers settle; only request 0 and latest 99 physically execute',
    () async {
      final tickets = [scheduler.renderLatest(request(0))];
      await flushRecolor();
      for (var i = 1; i < 100; i++) {
        tickets.add(scheduler.renderLatest(request(i)));
      }
      await flushRecolor();
      expect(workers.renders, hasLength(1));
      for (final ticket in tickets.take(99)) {
        expect((await ticket.active).status, RoomRecolorStatus.superseded);
      }
      final stale = workers.renders.single.succeed();
      await flushRecolor();
      expect(stale.isDisposed, isTrue);
      expect(workers.renders.map((r) => r.input.key.maskRevision), [0, 99]);
      final finalFrame = workers.renders.last.succeed();
      final result = await tickets.last.active;
      expect(result.status, RoomRecolorStatus.rendered);
      expect(result.frame!.key, recolorInput(99).key);
      result.frame!.dispose();
      expect(finalFrame.retainedByteCount, 0);
    },
  );

  test(
    'cancellation between queue adoption and worker creation does not spawn',
    () async {
      final ticket = scheduler.renderLatest(request(0));
      await Future<void>.value();
      await scheduler.cancelProject('project');
      await flushRecolor();
      expect((await ticket.active).status, RoomRecolorStatus.projectCancelled);
      expect(workers.workers, isEmpty);
    },
  );

  test(
    'cancelling a superseded physical project waits for its exit without cancelling pending other project',
    () async {
      workers.autoExit = false;
      final first = scheduler.renderLatest(request(0));
      await flushRecolor();
      final other = scheduler.renderLatest(request(1, project: 'other'));
      var cancelled = false;
      final barrier = scheduler
          .cancelProject('project')
          .then((_) => cancelled = true);
      await flushRecolor();
      expect((await first.active).status, RoomRecolorStatus.superseded);
      expect(workers.workers.single.terminations, 1);
      expect(cancelled, isFalse);
      workers.workers.single.exit.complete();
      await barrier;
      await flushRecolor();
      expect(workers.workers, hasLength(2));
      expect(workers.renders.last.input.key.projectId, 'other');
      workers.renders.last.succeed();
      (await other.active).frame!.dispose();
    },
  );

  test(
    'cancel also retires an idle worker belonging to the requested project',
    () async {
      final ticket = scheduler.renderLatest(request(0));
      await flushRecolor();
      workers.renders.single.succeed();
      (await ticket.active).frame!.dispose();
      await flushRecolor();
      await scheduler.cancelProject('unrelated');
      expect(workers.workers.single.terminations, 0);
      await scheduler.cancelProject('project');
      expect(workers.workers.single.terminations, 1);
    },
  );

  test(
    'two lanes alternate first demand and discard obsolete unstarted sides',
    () async {
      var ticket = scheduler.renderLatest(request(0, compare: true));
      await flushRecolor();
      expect(workers.renders.last.input.key.variantId, 'a');
      for (var revision = 1; revision <= 10; revision++) {
        ticket = scheduler.renderLatest(request(revision, compare: true));
        workers.renders.last.succeed();
        await flushRecolor();
        expect(workers.renders, hasLength(revision + 1));
        expect(
          workers.renders.last.input.key.variantId,
          revision.isOdd ? 'b' : 'a',
        );
      }
      workers.renders.last.succeed();
      await flushRecolor();
      expect(workers.renders.last.input.key.variantId, 'b');
      workers.renders.last.succeed();
      final a = await ticket.active;
      final b = await ticket.baseline;
      expect(a.frame!.key, recolorInput(10).key);
      expect(b.frame!.key, recolorInput(10, variant: 'b').key);
      a.frame!.dispose();
      b.frame!.dispose();
      expect(workers.workers, hasLength(1));
    },
  );

  test('clearing baseline keeps an executing active render eligible', () async {
    final ticket = scheduler.renderLatest(request(0, compare: true));
    await flushRecolor();
    scheduler.clearBaseline();
    expect((await ticket.baseline).status, RoomRecolorStatus.superseded);
    workers.renders.single.succeed();
    final a = await ticket.active;
    expect(a.status, RoomRecolorStatus.rendered);
    a.frame!.dispose();
    await flushRecolor();
    expect(workers.renders, hasLength(1));
    expect(workers.workers.single.terminations, 0);
  });

  for (final wrongKey in [true, false]) {
    test(
      'rejects wrong ${wrongKey ? 'full key' : 'dimensions'} and releases result',
      () async {
        final ticket = scheduler.renderLatest(request(0));
        await flushRecolor();
        final frame = workers.renders.single.succeed(
          key: wrongKey ? recolorInput(0, variant: 'b').key : null,
          width: wrongKey ? null : 2,
        );
        expect((await ticket.active).status, RoomRecolorStatus.invalidOutput);
        expect(frame.isDisposed, isTrue);
      },
    );
  }

  test('late error from superseded set cannot fail latest set', () async {
    final old = scheduler.renderLatest(request(0));
    await flushRecolor();
    final next = scheduler.renderLatest(request(1));
    workers.renders.single.fail();
    await flushRecolor();
    expect((await old.active).status, RoomRecolorStatus.superseded);
    workers.renders.last.succeed();
    expect((await next.active).status, RoomRecolorStatus.rendered);
    (await next.active).frame!.dispose();
  });

  for (final duringStartup in [true, false]) {
    test(
      'timeout during ${duringStartup ? 'startup' : 'render'} waits for physical exit before same-key retry',
      () async {
        workers.ready = !duringStartup;
        workers.autoExit = false;
        final first = scheduler.renderLatest(request(0));
        await flushRecolor();
        watchdogs.fire();
        expect((await first.active).status, RoomRecolorStatus.timeout);
        expect(workers.workers.single.terminations, 1);
        workers.ready = true;
        final retry = scheduler.renderLatest(request(0));
        await flushRecolor();
        expect(workers.workers, hasLength(1));
        final old = workers.workers.single;
        if (duringStartup) old.startup.complete();
        old.exit.complete();
        await flushRecolor();
        expect(workers.workers, hasLength(2));
        if (!duringStartup) old.renders.single.fail();
        workers.renders.last.succeed();
        expect((await retry.active).status, RoomRecolorStatus.rendered);
        (await retry.active).frame!.dispose();
      },
    );
  }

  test(
    'project cancellation revokes startup immediately; other project waits for exit',
    () async {
      workers.ready = false;
      workers.autoExit = false;
      final first = scheduler.renderLatest(request(0));
      await flushRecolor();
      final barrier = scheduler.cancelProject('project');
      expect((await first.active).status, RoomRecolorStatus.projectCancelled);
      workers.ready = true;
      final other = scheduler.renderLatest(request(0, project: 'other'));
      await scheduler.cancelProject('unrelated');
      await flushRecolor();
      expect(workers.workers, hasLength(1));
      workers.workers.first.startup.complete();
      workers.workers.first.exit.complete();
      await barrier;
      await flushRecolor();
      expect(workers.renders.single.input.key.projectId, 'other');
      workers.renders.single.succeed();
      (await other.active).frame!.dispose();
    },
  );

  test(
    'suspend is reversible; close is permanent and repeated close shares barrier',
    () async {
      final first = scheduler.renderLatest(request(0));
      await flushRecolor();
      await scheduler.suspend();
      expect((await first.active).status, RoomRecolorStatus.suspended);
      expect(
        (await scheduler.renderLatest(request(1)).active).status,
        RoomRecolorStatus.suspended,
      );
      scheduler.resume();
      workers.autoExit = false;
      final next = scheduler.renderLatest(request(2));
      await flushRecolor();
      final close1 = scheduler.close();
      final close2 = scheduler.close();
      expect(identical(close1, close2), isTrue);
      expect((await next.active).status, RoomRecolorStatus.closed);
      expect(
        (await scheduler.renderLatest(request(3)).active).status,
        RoomRecolorStatus.closed,
      );
      final late = workers.workers.first.renders.single.succeed();
      await flushRecolor();
      expect(late.isDisposed, isTrue);
      workers.workers.last.exit.complete();
      await close1;
      expect(watchdogs.timers.every((t) => t.cancelled), isTrue);
    },
  );
}
