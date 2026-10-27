import 'dart:typed_data';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_provider.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_scheduler.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_service.dart';
import 'package:color_lab/features/room_studio/application/room_variant_controller.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/controlled_room_recolor_worker.dart';
import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/room_project_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ControlledWorkers workers;
  late ManualWatchdogs watchdogs;
  late ProviderContainer c;
  late RoomRecolorCoordinator coordinator;
  late Object owner;
  final subscriptions = <ProviderSubscription<Object?>>[];

  setUp(() async {
    workers = ControlledWorkers();
    watchdogs = ManualWatchdogs();
    final source = roomProjectFixture(revision: 1);
    final repository = InMemoryRoomProjectRepository(
      initial: [
        source,
        source.copyWith(
          projectId: 'other',
          maskBytes: Uint8List.fromList([4, 3, 2, 1]),
        ),
      ],
    );
    c = ProviderContainer(
      overrides: [
        roomProjectRepositoryProvider.overrideWith((ref) async => repository),
        roomRecolorWorkerFactoryProvider.overrideWithValue(workers.create),
        roomRecolorWatchdogFactoryProvider.overrideWithValue(watchdogs.create),
      ],
    );
    await c.read(roomMaskProvider.notifier).openProject('project-1');
    coordinator = c.read(roomRecolorCoordinatorProvider.notifier);
    owner = coordinator.attachOwner();
    subscriptions.add(c.listen(roomRecolorPreviewProvider, (_, _) {}));
    subscriptions.add(c.listen(roomComparisonPreviewProvider, (_, _) {}));
    await flushRecolor();
  });
  tearDown(() async {
    for (final subscription in subscriptions) {
      subscription.close();
    }
    subscriptions.clear();
    for (final w in workers.workers) {
      if (!w.exit.isCompleted) w.exit.complete();
    }
    c.dispose();
    await flushRecolor();
  });

  test(
    'rapid updates retain only one executing render and publish complete final keys',
    () async {
      for (var i = 1; i < 100; i++) {
        c
            .read(roomMaskProvider.notifier)
            .setLayerColor(RoomLayer.wall, RgbColor(i, 2, 3));
        await flushRecolor();
      }
      expect(workers.renders, hasLength(1));
      final stale = workers.renders.single.succeed();
      await flushRecolor();
      expect(stale.isDisposed, isTrue);
      final currentA = c.read(roomRecolorKeyProvider)!;
      final currentB = c.read(roomComparisonKeyProvider)!;
      workers.renders.last.succeed();
      await flushRecolor();
      workers.renders.last.succeed();
      await flushRecolor();
      expect(workers.renders, hasLength(3));
      expect(c.read(roomRecolorPreviewProvider).requireValue!.key, currentA);
      expect(c.read(roomComparisonPreviewProvider).requireValue!.key, currentB);
    },
  );

  test(
    'session Open captures coherent masks before editor mirror catches up',
    () async {
      await c.read(roomProjectSessionProvider.notifier).openProject('other');
      await flushRecolor();
      expect(workers.renders.last.input.key.projectId, 'other');
      expect(workers.renders.last.input.masks.labels, [4, 3, 2, 1]);
      expect(c.read(roomMaskProvider).draft!.masks.labels, [1, 2, 3, 4]);
      expect(workers.workers.first.terminations, 1);
      final stale = workers.renders.first.succeed();
      await flushRecolor();
      expect(stale.isDisposed, isTrue);
      expect(c.read(roomRecolorPreviewProvider).isLoading, isTrue);
    },
  );

  test(
    'direct session close releases both accepted frames before its worker exit barrier',
    () async {
      final a = workers.renders.single.succeed();
      await flushRecolor();
      final b = workers.renders.last.succeed();
      await flushRecolor();
      workers.workers.single.autoExit = false;
      var closed = false;
      final closing = c
          .read(roomProjectSessionProvider.notifier)
          .closeProject()
          .then((_) => closed = true);
      expect(a.isDisposed, isTrue);
      expect(b.isDisposed, isTrue);
      await flushRecolor();
      expect(closed, isFalse);
      workers.workers.single.exit.complete();
      await closing;
      expect(c.read(roomProjectSessionProvider), isNull);
      expect(c.read(roomRecolorPreviewProvider).value, isNull);
    },
  );

  test(
    'same-key close and reopen uses a new lifetime and waits for old exit',
    () async {
      final key = c.read(roomRecolorKeyProvider);
      await c.read(roomProjectSessionProvider.notifier).closeProject();
      await c.read(roomMaskProvider.notifier).closeProject();
      await c.read(roomMaskProvider.notifier).openProject('project-1');
      await flushRecolor();
      expect(c.read(roomRecolorKeyProvider), key);
      final stale = workers.renders.first.succeed();
      await flushRecolor();
      expect(stale.isDisposed, isTrue);
      expect(c.read(roomRecolorPreviewProvider).isLoading, isTrue);
      workers.renders.last.succeed();
      await flushRecolor();
      workers.renders.last.succeed();
      await flushRecolor();
      expect(c.read(roomRecolorPreviewProvider).requireValue!.key, key);
    },
  );

  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.detached,
  ]) {
    test(
      '$state releases frames, cancels work, and resumed renders latest only',
      () async {
        final activeFrame = workers.renders.single.succeed();
        await flushRecolor();
        expect(
          c.read(roomRecolorPreviewProvider).requireValue,
          same(activeFrame),
        );
        coordinator.lifecycleChanged(state);
        await flushRecolor();
        expect(activeFrame.isDisposed, isTrue);
        expect(c.read(roomRecolorPreviewProvider).value, isNull);
        c
            .read(roomMaskProvider.notifier)
            .setLayerColor(RoomLayer.wall, RgbColor(20, 30, 40));
        await flushRecolor();
        final count = workers.renders.length;
        coordinator.lifecycleChanged(AppLifecycleState.resumed);
        await flushRecolor();
        expect(workers.renders, hasLength(count + 1));
        expect([
          c.read(roomRecolorKeyProvider),
          c.read(roomComparisonKeyProvider),
        ], contains(workers.renders.last.input.key));
        workers.renders.last.succeed();
        await flushRecolor();
        workers.renders.last.succeed();
        await flushRecolor();
        expect(
          c.read(roomRecolorPreviewProvider).requireValue!.key,
          c.read(roomRecolorKeyProvider),
        );
        expect(
          c.read(roomComparisonPreviewProvider).requireValue!.key,
          c.read(roomComparisonKeyProvider),
        );
      },
    );
  }

  test(
    'covered owner does not render; returning resumes and old owner cannot cancel replacement',
    () async {
      coordinator.setOwnerVisible(owner, false);
      await flushRecolor();
      final count = workers.renders.length;
      coordinator.lifecycleChanged(AppLifecycleState.resumed);
      await flushRecolor();
      expect(workers.renders, hasLength(count));
      coordinator.setOwnerVisible(owner, true);
      await flushRecolor();
      expect(workers.renders, hasLength(count + 1));
      final newOwner = coordinator.attachOwner();
      coordinator.detachOwner(owner);
      await flushRecolor();
      expect(coordinator.owns(newOwner), isTrue);
      expect(c.read(roomRecolorPreviewProvider).isLoading, isTrue);
    },
  );

  for (final failActive in [true, false]) {
    test(
      '${failActive ? 'active' : 'baseline'} errors remain isolated; explicit retry uses exact key',
      () async {
        RoomRecolorFrame? valid;
        if (failActive) {
          workers.renders.single.fail();
        } else {
          valid = workers.renders.single.succeed();
        }
        await flushRecolor();
        if (failActive) {
          valid = workers.renders.last.succeed();
        } else {
          workers.renders.last.fail();
        }
        await flushRecolor();
        final failedProvider = failActive
            ? roomRecolorPreviewProvider
            : roomComparisonPreviewProvider;
        final goodProvider = failActive
            ? roomComparisonPreviewProvider
            : roomRecolorPreviewProvider;
        expect(c.read(failedProvider).hasError, isTrue);
        expect(c.read(goodProvider).requireValue, same(valid));
        final count = workers.renders.length;
        coordinator.retry();
        await flushRecolor();
        expect(workers.renders, hasLength(count + 1));
        workers.renders.last.succeed();
        await flushRecolor();
        expect(c.read(failedProvider).hasError, isFalse);
        expect(c.read(goodProvider).requireValue, same(valid));
      },
    );
  }

  test('timeout is explicit and same-key Retry creates a fresh worker', () async {
    watchdogs.fire();
    await flushRecolor();
    expect(c.read(roomRecolorPreviewProvider).hasError, isTrue);
    // The other lane may render after timeout; it must not retry active itself.
    if (workers.renders.length > 1) workers.renders.last.succeed();
    await flushRecolor();
    final key = c.read(roomRecolorKeyProvider);
    coordinator.retry();
    await flushRecolor();
    expect(workers.workers.length, greaterThan(1));
    expect(workers.renders.last.input.key, key);
    workers.renders.last.succeed();
    await flushRecolor();
    expect(c.read(roomRecolorPreviewProvider).requireValue!.key, key);
  });

  test(
    'clearing comparison preserves active in flight and releases baseline only',
    () async {
      await c.read(roomVariantProvider.notifier).clearComparison();
      await flushRecolor();
      expect(workers.renders, hasLength(1));
      workers.renders.single.succeed();
      await flushRecolor();
      expect(c.read(roomRecolorPreviewProvider).hasError, isFalse);
      expect(c.read(roomComparisonPreviewProvider).value, isNull);
    },
  );

  test(
    'previous same-view display is leased; variant change cannot display or share it',
    () async {
      final frame = workers.renders.single.succeed();
      await flushRecolor();
      workers.renders.last.succeed();
      await flushRecolor();
      final lease = frame.lease();
      c
          .read(roomMaskProvider.notifier)
          .setLayerColor(RoomLayer.wall, RgbColor(2, 3, 4));
      await flushRecolor();
      expect(c.read(roomRecolorDisplayProvider), same(frame));
      expect(c.read(roomRecolorPreviewProvider).isLoading, isTrue);
      await c.read(roomVariantProvider.notifier).selectVariant('variant-b');
      await flushRecolor();
      expect(c.read(roomRecolorDisplayProvider), isNull);
      expect(frame.isDisposed, isFalse);
      lease.dispose();
      expect(frame.isDisposed, isTrue);
    },
  );

  test(
    'container disposal cancels physical work and late completion releases without publication',
    () async {
      final scheduler = c.read(roomRecolorSchedulerProvider);
      for (final subscription in subscriptions) {
        subscription.close();
      }
      subscriptions.clear();
      c.dispose();
      expect(workers.workers.first.terminations, 1);
      final frame = workers.renders.first.succeed();
      await flushRecolor();
      expect(frame.isDisposed, isTrue);
      await scheduler.close();
    },
  );
}
