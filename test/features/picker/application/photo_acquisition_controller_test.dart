import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/application/photo_acquisition_controller.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/domain/acquisition_intent_store.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_acquisition_intent_store.dart';

final photo = PreparedPhoto(
  width: 1,
  height: 1,
  rgbaBytes: Uint8List.fromList([12, 34, 56, 255]),
  previewBytes: Uint8List(0),
  palette: const [],
);
const oldIntent = AcquisitionIntent(
  requestId: 'old-room',
  source: PhotoSource.gallery,
  destination: AcquisitionDestination.room,
);

class Adapter implements PhotoPickerService {
  int pickCalls = 0, recoverCalls = 0;
  PreparedPhoto? picked = photo, lost;
  Completer<void>? recoveryGate, pickGate;
  PhotoPickFailure? failure;
  PhotoPickFailure? recoveryFailure;
  PhotoSource? source;
  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async {
    pickCalls++;
    this.source = source;
    await pickGate?.future;
    if (failure != null) throw failure!;
    return picked;
  }

  @override
  Future<PreparedPhoto?> recoverLost() async {
    recoverCalls++;
    await recoveryGate?.future;
    if (recoveryFailure != null) throw recoveryFailure!;
    return lost;
  }

  @override
  Future<bool> openSettings() async => true;
}

class Store extends InMemoryAcquisitionIntentStore {
  Store({super.initial});
  Completer<void>? saveGate, clearGate, loadGate;
  bool failSave = false, failClear = false, failLoad = false;
  int closes = 0, loads = 0;
  AcquisitionIntent? lastIntent;
  @override
  Future<AcquisitionIntentRecord> load() async {
    loads++;
    await loadGate?.future;
    if (failLoad) throw const AcquisitionStorageException();
    return super.load();
  }

  @override
  Future<void> save(AcquisitionIntent intent) async {
    lastIntent = intent;
    await saveGate?.future;
    if (failSave) throw const AcquisitionStorageException();
    await super.save(intent);
  }

  @override
  Future<void> clear({bool discardUntrusted = false}) async {
    await clearGate?.future;
    if (failClear) throw const AcquisitionStorageException();
    await super.clear(discardUntrusted: discardUntrusted);
  }

  @override
  Future<void> close() async {
    closes++;
    await super.close();
  }
}

void main() {
  ProviderContainer containerFor(Store store, Adapter adapter) {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith((ref) async => store),
        photoPickerServiceProvider.overrideWithValue(adapter),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final kind in PhotoPickFailureKind.values) {
    test(
      'recovery preserves typed $kind without reopening native picker',
      () async {
        final adapter = Adapter()..recoveryFailure = PhotoPickFailure(kind);
        final c = containerFor(Store(), adapter);
        await c.read(photoAcquisitionProvider.notifier).ensureRecovered();
        expect(c.read(photoAcquisitionProvider).failure?.name, kind.name);
        expect(adapter.pickCalls, 0);
      },
    );
  }

  for (final destination in AcquisitionDestination.values) {
    test(
      'recovered failure retains $destination intent through cleanup retry',
      () async {
        final intent = AcquisitionIntent(
          requestId: 'lost-${destination.name}',
          source: PhotoSource.camera,
          destination: destination,
        );
        final store = Store(initial: AcquisitionIntentRecord.valid(intent))
          ..failClear = true;
        final adapter = Adapter()
          ..recoveryFailure = const PhotoPickFailure(
            PhotoPickFailureKind.unsupported,
          );
        final c = containerFor(store, adapter);
        final controller = c.read(photoAcquisitionProvider.notifier);
        await controller.ensureRecovered();
        expect(
          c.read(photoAcquisitionProvider).phase,
          AcquisitionPhase.storageError,
        );
        store.failClear = false;
        await controller.retryStorage();
        final failure = c.read(photoAcquisitionProvider).recoveryFailure;
        expect(failure?.kind, AcquisitionFailureKind.unsupported);
        expect(failure?.intent.requestId, 'lost-${destination.name}');
        expect(failure?.intent.source, PhotoSource.camera);
        expect(failure?.intent.destination, destination);
        expect((await store.load()).kind, IntentRecordKind.absent);
        expect(adapter.recoverCalls, 1);
        expect(adapter.pickCalls, 0);
        adapter.picked = null;
        await controller.request(
          source: PhotoSource.gallery,
          destination: destination,
        );
        expect(c.read(photoAcquisitionProvider).recoveryFailure, isNull);
      },
    );
  }

  for (final origin in [
    const AcquisitionIntentRecord.absent(),
    const AcquisitionIntentRecord.untrusted(),
  ]) {
    test(
      'unknown ${origin.kind} recovery failure acquires no invented owner',
      () async {
        final adapter = Adapter()
          ..recoveryFailure = const PhotoPickFailure(
            PhotoPickFailureKind.invalidImage,
          );
        final c = containerFor(Store(initial: origin), adapter);
        await c.read(photoAcquisitionProvider.notifier).ensureRecovered();
        expect(
          c.read(photoAcquisitionProvider).failure,
          AcquisitionFailureKind.invalidImage,
        );
        expect(c.read(photoAcquisitionProvider).recoveryFailure, isNull);
        expect(adapter.pickCalls, 0);
      },
    );
  }

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  test(
    'owner lost during request-triggered recovery never opens picker',
    () async {
      final adapter = Adapter()..recoveryGate = Completer<void>();
      final store = Store();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      var active = true;
      final result = controller.request(
        source: PhotoSource.gallery,
        destination: AcquisitionDestination.capture,
        isActive: () => active,
      );
      await tick();
      expect(adapter.recoverCalls, 1);
      active = false;
      adapter.recoveryGate!.complete();
      expect(await result, isA<AcquisitionCancelled>());
      expect(adapter.pickCalls, 0);
      expect((await store.load()).kind, IntentRecordKind.absent);
    },
  );

  test(
    'inactive or throwing owner starts no request-triggered recovery',
    () async {
      for (final throws in [false, true]) {
        final store = Store();
        final adapter = Adapter();
        final container = containerFor(store, adapter);
        final controller = container.read(photoAcquisitionProvider.notifier);
        expect(
          await controller.request(
            source: PhotoSource.gallery,
            destination: AcquisitionDestination.capture,
            isActive: () {
              if (throws) throw StateError('owner gone');
              return false;
            },
          ),
          isA<AcquisitionCancelled>(),
        );
        expect(adapter.recoverCalls, 0);
        expect(adapter.pickCalls, 0);
        expect(
          container.read(photoAcquisitionProvider).phase,
          AcquisitionPhase.uninitialized,
        );
      }
    },
  );

  for (final throws in [false, true]) {
    test(
      'owner ${throws ? 'throws' : 'hides'} during intent save cancels before native launch',
      () async {
        final store = Store()..saveGate = Completer<void>();
        final adapter = Adapter();
        final container = containerFor(store, adapter);
        final controller = container.read(photoAcquisitionProvider.notifier);
        await controller.ensureRecovered();
        var active = true;
        final result = controller.request(
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.capture,
          isActive: () {
            if (!active && throws) throw StateError('owner gone');
            return active;
          },
        );
        await tick();
        active = false;
        store.saveGate!.complete();
        expect(await result, isA<AcquisitionCancelled>());
        expect(adapter.pickCalls, 0);
        expect((await store.load()).kind, IntentRecordKind.absent);
        expect(
          container.read(photoAcquisitionProvider).phase,
          AcquisitionPhase.ready,
        );
      },
    );
  }

  test(
    'cancelled owner cleanup failure retains storage retry barrier without native launch',
    () async {
      final store = Store()
        ..saveGate = Completer<void>()
        ..failClear = true;
      final adapter = Adapter();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      var active = true;
      final result = controller.request(
        source: PhotoSource.gallery,
        destination: AcquisitionDestination.capture,
        isActive: () => active,
      );
      await tick();
      active = false;
      store.saveGate!.complete();
      expect(await result, isA<AcquisitionFailed>());
      expect(adapter.pickCalls, 0);
      expect(
        container.read(photoAcquisitionProvider).phase,
        AcquisitionPhase.storageError,
      );
      store.failClear = false;
      await controller.retryStorage();
      expect((await store.load()).kind, IntentRecordKind.absent);
      expect(adapter.pickCalls, 0);
      expect(adapter.recoverCalls, 1);
    },
  );

  test(
    'owner hidden during durable claim retains the receipt for explicit delivery',
    () async {
      final store = Store();
      final adapter = Adapter();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      final result =
          await controller.request(
                source: PhotoSource.gallery,
                destination: AcquisitionDestination.capture,
              )
              as Acquired;
      store.clearGate = Completer<void>();
      var active = true;
      final claimed = controller.claim(
        requestId: result.receipt.requestId,
        destination: AcquisitionDestination.capture,
        accept: (_) => active,
      );
      await tick();
      active = false;
      store.clearGate!.complete();
      expect(await claimed, isNull);
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt,
        same(result.receipt),
      );
      expect(adapter.pickCalls, 1);
      expect(adapter.recoverCalls, 1);
    },
  );

  test(
    'accepted delivery runs with pending receipt and acquisition gate held',
    () async {
      final store = Store();
      final container = containerFor(store, Adapter());
      final controller = container.read(photoAcquisitionProvider.notifier);
      final result =
          await controller.request(
                source: PhotoSource.gallery,
                destination: AcquisitionDestination.capture,
              )
              as Acquired;
      Future<AcquisitionOutcome>? competing;
      var delivered = false;
      expect(
        await controller.claim(
          requestId: result.receipt.requestId,
          destination: AcquisitionDestination.capture,
          accept: (value) {
            expect(value, same(photo));
            expect(
              container.read(photoAcquisitionProvider).pendingReceipt,
              same(result.receipt),
            );
            competing = controller.request(
              source: PhotoSource.gallery,
              destination: AcquisitionDestination.room,
            );
            delivered = true;
            return true;
          },
        ),
        same(photo),
      );
      expect(delivered, true);
      expect(await competing, isA<AcquisitionBusy>());
      expect(container.read(photoAcquisitionProvider).pendingReceipt, isNull);
    },
  );

  for (final throws in [false, true]) {
    test(
      'unknown receipt survives ${throws ? 'throwing' : 'rejected'} delivery and later explicit claim',
      () async {
        final store = Store(initial: const AcquisitionIntentRecord.untrusted());
        final adapter = Adapter()..lost = photo;
        final container = containerFor(store, adapter);
        final controller = container.read(photoAcquisitionProvider.notifier);
        await controller.ensureRecovered();
        final receipt = container
            .read(photoAcquisitionProvider)
            .pendingReceipt!;
        expect(
          await controller.claim(
            requestId: receipt.requestId,
            destination: AcquisitionDestination.capture,
            accept: (_) {
              if (throws) throw StateError('owner unavailable');
              return false;
            },
          ),
          isNull,
        );
        expect(
          container.read(photoAcquisitionProvider).pendingReceipt,
          same(receipt),
        );
        expect(
          container.read(photoAcquisitionProvider).phase,
          AcquisitionPhase.ready,
        );
        expect((await store.load()).kind, IntentRecordKind.absent);
        expect(
          await controller.claim(
            requestId: receipt.requestId,
            destination: AcquisitionDestination.room,
            accept: (_) => true,
          ),
          same(photo),
        );
        expect(adapter.recoverCalls, 1);
      },
    );
  }

  test(
    'construction does no storage or native work; recovery coalesces and blocks picking',
    () async {
      final store = Store(
        initial: const AcquisitionIntentRecord.valid(oldIntent),
      );
      final adapter = Adapter()
        ..lost = photo
        ..recoveryGate = Completer<void>();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      expect(
        container.read(photoAcquisitionProvider).phase,
        AcquisitionPhase.uninitialized,
      );
      expect(adapter.recoverCalls, 0);
      final first = controller.ensureRecovered();
      final second = controller.ensureRecovered();
      await tick();
      expect(
        await controller.request(
          source: PhotoSource.camera,
          destination: AcquisitionDestination.capture,
        ),
        isA<AcquisitionBusy>(),
      );
      expect(adapter.pickCalls, 0);
      adapter.recoveryGate!.complete();
      await Future.wait([first, second]);
      expect(adapter.recoverCalls, 1);
      final receipt = container.read(photoAcquisitionProvider).pendingReceipt!;
      expect(receipt.destination, AcquisitionDestination.room);
      expect(receipt.requestId, 'old-room');
      expect(receipt.recovered, true);
      expect(
        await controller.claim(
          requestId: 'obsolete',
          destination: AcquisitionDestination.room,
        ),
        isNull,
      );
      expect(
        await controller.claim(
          requestId: receipt.requestId,
          destination: AcquisitionDestination.capture,
        ),
        isNull,
      );
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt,
        same(receipt),
      );
      expect(
        await controller.claim(
          requestId: receipt.requestId,
          destination: AcquisitionDestination.room,
        ),
        same(photo),
      );
      expect((await store.load()).kind, IntentRecordKind.absent);
    },
  );

  test(
    'intent flush and native processing share one gate with pending disposition',
    () async {
      final store = Store();
      final adapter = Adapter()..pickGate = Completer<void>();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      store.saveGate = Completer<void>();
      final request = controller.request(
        source: PhotoSource.camera,
        destination: AcquisitionDestination.room,
      );
      await tick();
      expect(adapter.pickCalls, 0);
      expect(store.lastIntent?.destination, AcquisitionDestination.room);
      expect(
        await controller.request(
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.capture,
        ),
        isA<AcquisitionBusy>(),
      );
      store.saveGate!.complete();
      await tick();
      expect(adapter.pickCalls, 1);
      expect(adapter.source, PhotoSource.camera);
      expect(
        await controller.request(
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.capture,
        ),
        isA<AcquisitionBusy>(),
      );
      adapter.pickGate!.complete();
      final result = await request as Acquired;
      expect(
        await controller.request(
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.capture,
        ),
        isA<AcquisitionBusy>(),
      );
      store.clearGate = Completer<void>();
      final claimed = controller.claim(
        requestId: result.receipt.requestId,
        destination: AcquisitionDestination.room,
      );
      await tick();
      expect(await controller.dismiss(result.receipt.requestId), false);
      expect(
        await controller.request(
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.capture,
        ),
        isA<AcquisitionBusy>(),
      );
      store.clearGate!.complete();
      expect(await claimed, same(photo));
      expect(container.read(photoAcquisitionProvider).pendingReceipt, isNull);
    },
  );

  test(
    'failed intent persistence admits no native call and retry never launches camera',
    () async {
      final store = Store()..failSave = true;
      final adapter = Adapter();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      expect(
        await controller.request(
          source: PhotoSource.camera,
          destination: AcquisitionDestination.room,
        ),
        isA<AcquisitionFailed>().having(
          (e) => e.kind,
          'kind',
          AcquisitionFailureKind.storage,
        ),
      );
      expect(adapter.pickCalls, 0);
      expect(
        container.read(photoAcquisitionProvider).phase,
        AcquisitionPhase.storageError,
      );
      store.failSave = false;
      await controller.retryStorage();
      expect(adapter.pickCalls, 0);
      expect(adapter.recoverCalls, 1);
      expect(
        container.read(photoAcquisitionProvider).phase,
        AcquisitionPhase.ready,
      );
    },
  );

  test(
    'failed clear retains receipt and retry barrier without consuming lost data twice',
    () async {
      final store = Store(
        initial: const AcquisitionIntentRecord.valid(oldIntent),
      );
      final adapter = Adapter()..lost = photo;
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      store.failClear = true;
      expect(
        await controller.claim(
          requestId: 'old-room',
          destination: AcquisitionDestination.room,
        ),
        isNull,
      );
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt?.photo,
        same(photo),
      );
      expect(
        await controller.request(
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.capture,
        ),
        isA<AcquisitionBusy>(),
      );
      store.failClear = false;
      await controller.retryStorage();
      expect(adapter.recoverCalls, 1);
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt?.photo,
        same(photo),
      );
      expect(await controller.dismiss('obsolete'), false);
      expect(await controller.dismiss('old-room'), true);
    },
  );

  test(
    'storage recovery retains exact event identity and rejects old or lookalike events',
    () async {
      final store = Store(
        initial: const AcquisitionIntentRecord.valid(oldIntent),
      );
      final adapter = Adapter()..lost = photo;
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      final receipt = container.read(photoAcquisitionProvider).pendingReceipt;
      store.failClear = true;
      final outcome =
          await controller.claimReceipt(
                requestId: 'old-room',
                destination: AcquisitionDestination.room,
              )
              as AcquisitionFailed;
      final first = outcome.storageFailure!;
      expect(first.requestId, 'old-room');
      expect(first.destination, AcquisitionDestination.room);
      expect(
        container.read(photoAcquisitionProvider).storageFailure,
        same(first),
      );
      store.failLoad = true;
      await controller.retryStorage(expectedFailure: first);
      expect(
        container.read(photoAcquisitionProvider).storageFailure,
        same(first),
      );
      expect(
        container.read(photoAcquisitionProvider).resolvedStorageFailure,
        isNull,
      );
      store.failLoad = false;
      final before = store.loads;
      await controller.retryStorage(
        expectedFailure: AcquisitionStorageFailure(
          requestId: first.requestId,
          destination: first.destination,
        ),
      );
      expect(store.loads, before);
      await controller.retryStorage(expectedFailure: first);
      expect(
        container.read(photoAcquisitionProvider).resolvedStorageFailure,
        same(first),
      );
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt,
        same(receipt),
      );
      final again =
          await controller.claimReceipt(
                requestId: 'old-room',
                destination: AcquisitionDestination.room,
              )
              as AcquisitionFailed;
      final second = again.storageFailure!;
      expect(second, isNot(same(first)));
      expect(second.requestId, first.requestId);
      final newer = container.read(photoAcquisitionProvider);
      final loads = store.loads;
      await controller.retryStorage(expectedFailure: first);
      expect(container.read(photoAcquisitionProvider), same(newer));
      expect(store.loads, loads);
      expect(adapter.recoverCalls, 1);
      expect(adapter.pickCalls, 0);
    },
  );

  test(
    'failed intent result owns its storage recovery even without a receipt',
    () async {
      final store = Store()..failSave = true;
      final adapter = Adapter();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      final outcome =
          await controller.request(
                source: PhotoSource.camera,
                destination: AcquisitionDestination.room,
              )
              as AcquisitionFailed;
      final failure = outcome.storageFailure!;
      expect(failure.requestId, store.lastIntent!.requestId);
      expect(failure.destination, AcquisitionDestination.room);
      expect(container.read(photoAcquisitionProvider).pendingReceipt, isNull);
      store.failSave = false;
      await controller.retryStorage(expectedFailure: failure);
      expect(
        container.read(photoAcquisitionProvider).resolvedStorageFailure,
        same(failure),
      );
      expect(adapter.pickCalls, 0);
    },
  );

  test(
    'empty recovery cleanup retries without retrieving lost data again',
    () async {
      final store = Store(
        initial: const AcquisitionIntentRecord.valid(oldIntent),
      )..failClear = true;
      final adapter = Adapter();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      expect(
        container.read(photoAcquisitionProvider).phase,
        AcquisitionPhase.storageError,
      );
      store.failClear = false;
      await controller.retryStorage();
      expect(adapter.recoverCalls, 1);
      expect(
        container.read(photoAcquisitionProvider).phase,
        AcquisitionPhase.ready,
      );
      expect((await store.load()).kind, IntentRecordKind.absent);
    },
  );

  test(
    'native recovery error is consumed once even if subsequent cleanup fails',
    () async {
      final store = Store(
        initial: const AcquisitionIntentRecord.valid(oldIntent),
      )..failClear = true;
      final adapter = Adapter()
        ..recoveryFailure = const PhotoPickFailure(
          PhotoPickFailureKind.processing,
        );
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      store.failClear = false;
      await controller.retryStorage();
      await controller.ensureRecovered();
      expect(adapter.recoverCalls, 1);
      expect(adapter.pickCalls, 0);
      expect(
        container.read(photoAcquisitionProvider).failure,
        AcquisitionFailureKind.processing,
      );
    },
  );

  test(
    'load retry keeps existing store and disposal during load prevents recovery',
    () async {
      final store = Store()..failLoad = true;
      final adapter = Adapter();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      expect(adapter.recoverCalls, 0);
      store.failLoad = false;
      await controller.retryStorage();
      expect(adapter.recoverCalls, 1);
      expect(
        container.read(photoAcquisitionProvider).phase,
        AcquisitionPhase.ready,
      );

      final delayedStore = Store()..loadGate = Completer<void>();
      final delayedAdapter = Adapter();
      final delayedContainer = ProviderContainer(
        overrides: [
          acquisitionIntentStoreProvider.overrideWith(
            (ref) async => delayedStore,
          ),
          photoPickerServiceProvider.overrideWithValue(delayedAdapter),
        ],
      );
      final recovery = delayedContainer
          .read(photoAcquisitionProvider.notifier)
          .ensureRecovered();
      await tick();
      delayedContainer.dispose();
      delayedStore.loadGate!.complete();
      await recovery;
      expect(delayedAdapter.recoverCalls, 0);
    },
  );

  test(
    'unknown recovered origin requires explicit destination and preserves metadata until claim',
    () async {
      for (final initial in [
        const AcquisitionIntentRecord.untrusted(),
        const AcquisitionIntentRecord.absent(),
      ]) {
        final store = Store(initial: initial);
        final adapter = Adapter()..lost = photo;
        final container = containerFor(store, adapter);
        final controller = container.read(photoAcquisitionProvider.notifier);
        await controller.ensureRecovered();
        final receipt = container
            .read(photoAcquisitionProvider)
            .pendingReceipt!;
        expect(receipt.destination, isNull);
        expect(receipt.source, isNull);
        expect(await controller.discardUntrustedIntent(), false);
        expect((await store.load()).kind, initial.kind);
        expect(
          await controller.claim(
            requestId: receipt.requestId,
            destination: AcquisitionDestination.room,
          ),
          same(photo),
        );
        expect((await store.load()).kind, IntentRecordKind.absent);
      }
    },
  );

  test(
    'untrusted metadata without photo blocks picks until explicit discard',
    () async {
      final store = Store(initial: const AcquisitionIntentRecord.untrusted());
      final adapter = Adapter();
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      expect(container.read(photoAcquisitionProvider).hasUntrustedIntent, true);
      expect(
        await controller.request(
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.capture,
        ),
        isA<AcquisitionBusy>(),
      );
      expect((await store.load()).kind, IntentRecordKind.untrusted);
      expect(await controller.discardUntrustedIntent(), true);
      expect(await controller.discardUntrustedIntent(), false);
    },
  );

  test(
    'cancel and error clear only their intent; pending success cannot be overwritten',
    () async {
      final store = Store();
      final adapter = Adapter()..picked = null;
      final container = containerFor(store, adapter);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      expect(
        await controller.request(
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.room,
        ),
        isA<AcquisitionCancelled>(),
      );
      expect((await store.load()).kind, IntentRecordKind.absent);
      adapter.failure = const PhotoPickFailure(
        PhotoPickFailureKind.permissionDenied,
      );
      expect(
        await controller.request(
          source: PhotoSource.camera,
          destination: AcquisitionDestination.capture,
        ),
        isA<AcquisitionFailed>().having(
          (e) => e.kind,
          'kind',
          AcquisitionFailureKind.permissionDenied,
        ),
      );
      adapter
        ..failure = null
        ..picked = photo;
      final acquired =
          await controller.request(
                source: PhotoSource.gallery,
                destination: AcquisitionDestination.room,
              )
              as Acquired;
      adapter
        ..picked = null
        ..failure = const PhotoPickFailure(PhotoPickFailureKind.processing);
      expect(
        await controller.request(
          source: PhotoSource.camera,
          destination: AcquisitionDestination.capture,
        ),
        isA<AcquisitionBusy>(),
      );
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt,
        same(acquired.receipt),
      );
    },
  );

  test(
    'storage initialization is lazy, explicit retry reopens failed factory',
    () async {
      final store = Store();
      final adapter = Adapter();
      var opens = 0;
      final container = ProviderContainer(
        overrides: [
          acquisitionStorageDirectoryProvider.overrideWith(
            (ref) async => Directory('/private/tmp/final-color_lab'),
          ),
          acquisitionIntentStoreFactoryProvider.overrideWithValue((path) async {
            expect(path, '/private/tmp/final-color_lab');
            if (++opens == 1) throw const AcquisitionStorageException();
            return store;
          }),
          photoPickerServiceProvider.overrideWithValue(adapter),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(photoAcquisitionProvider.notifier);
      await tick();
      expect(opens, 0);
      await controller.ensureRecovered();
      expect(adapter.recoverCalls, 0);
      await controller.retryStorage();
      expect(opens, 2);
      expect(adapter.recoverCalls, 1);
    },
  );

  test(
    'disposal during save prevents native launch and during pick rejects late result',
    () async {
      for (final duringSave in [true, false]) {
        final store = Store();
        final adapter = Adapter();
        final container = ProviderContainer(
          overrides: [
            acquisitionIntentStoreProvider.overrideWith((ref) async => store),
            photoPickerServiceProvider.overrideWithValue(adapter),
          ],
        );
        final controller = container.read(photoAcquisitionProvider.notifier);
        await controller.ensureRecovered();
        final gate = Completer<void>();
        if (duringSave) {
          store.saveGate = gate;
        } else {
          adapter.pickGate = gate;
        }
        final request = controller.request(
          source: PhotoSource.gallery,
          destination: AcquisitionDestination.room,
        );
        await tick();
        container.dispose();
        gate.complete();
        expect(await request, isA<AcquisitionCancelled>());
        expect(adapter.pickCalls, duringSave ? 0 : 1);
        expect((await store.load()).kind, IntentRecordKind.valid);
      }
    },
  );

  test(
    'provider disposal before directory resolves skips factory; late opened store closes',
    () async {
      for (final duringDirectory in [true, false]) {
        final directoryGate = Completer<Directory>();
        final storeGate = Completer<AcquisitionIntentStore>();
        final store = Store();
        var opens = 0;
        final container = ProviderContainer(
          overrides: [
            acquisitionStorageDirectoryProvider.overrideWith(
              (ref) => directoryGate.future,
            ),
            acquisitionIntentStoreFactoryProvider.overrideWithValue((_) {
              opens++;
              return storeGate.future;
            }),
          ],
        );
        final pending = expectLater(
          container.read(acquisitionIntentStoreProvider.future),
          throwsA(isA<StateError>()),
        );
        if (!duringDirectory) {
          directoryGate.complete(Directory('/private/tmp'));
          await tick();
        }
        container.dispose();
        if (duringDirectory) directoryGate.complete(Directory('/private/tmp'));
        storeGate.complete(store);
        await pending;
        await tick();
        expect(opens, duringDirectory ? 0 : 1);
        expect(store.closes, duringDirectory ? 0 : 1);
      }
    },
  );
}
