import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/data/db/hive_acquisition_intent_store.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/application/photo_acquisition_controller.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/domain/acquisition_intent_store.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
// ignore: implementation_imports
import 'package:hive/src/hive_impl.dart';

class BoundaryBox implements Box<dynamic> {
  BoundaryBox(this.delegate);
  final Box<dynamic> delegate;
  bool failFlush = false, failClose = false;
  Completer<void>? flushGate;
  @override
  bool containsKey(dynamic key) => delegate.containsKey(key);
  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      delegate.get(key, defaultValue: defaultValue);
  @override
  Future<void> put(dynamic key, dynamic value) => delegate.put(key, value);
  @override
  Future<void> delete(dynamic key) => delegate.delete(key);
  @override
  Future<void> flush() async {
    await flushGate?.future;
    if (failFlush) throw const FileSystemException('private injected failure');
    await delegate.flush();
  }

  @override
  Future<void> close() async {
    if (failClose) throw const FileSystemException('private close failure');
    await delegate.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class NativeAdapter implements PhotoPickerService {
  int picks = 0, recoveries = 0;
  final photo = PreparedPhoto(
    width: 1,
    height: 1,
    rgbaBytes: Uint8List.fromList([1, 2, 3, 255]),
    previewBytes: Uint8List(0),
    palette: const [],
  );
  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async {
    picks++;
    return photo;
  }

  @override
  Future<PreparedPhoto?> recoverLost() async {
    recoveries++;
    return null;
  }

  @override
  Future<bool> openSettings() async => false;
}

void main() {
  late Directory directory;
  const intent = AcquisitionIntent(
    requestId: 'room-123',
    source: PhotoSource.camera,
    destination: AcquisitionDestination.room,
  );
  final storageError = throwsA(isA<AcquisitionStorageException>());
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('acquisition-store-');
  });
  tearDown(() => directory.delete(recursive: true));
  Future<(BoundaryBox, HiveAcquisitionIntentStore)> boundary() async {
    final box = BoundaryBox(
      await HiveImpl().openBox<dynamic>(
        'photo_acquisition_v1',
        path: directory.path,
      ),
    );
    return (box, HiveAcquisitionIntentStore.fromBox(box: box));
  }

  test(
    'schema 1 intent and clear survive actual file close and reopen',
    () async {
      var store = await HiveAcquisitionIntentStore.open(
        directory: directory.path,
      );
      expect((await store.load()).kind, IntentRecordKind.absent);
      await store.save(intent);
      await store.close();
      expect(
        await File('${directory.path}/photo_acquisition_v1.hive').exists(),
        true,
      );
      store = await HiveAcquisitionIntentStore.open(directory: directory.path);
      final saved = (await store.load()).intent!;
      expect(saved.requestId, 'room-123');
      expect(saved.source, PhotoSource.camera);
      expect(saved.destination, AcquisitionDestination.room);
      expect(saved.toMap(), {
        'schemaVersion': 1,
        'requestId': 'room-123',
        'source': 'camera',
        'destination': 'room',
      });
      await store.clear();
      await store.close();
      store = await HiveAcquisitionIntentStore.open(directory: directory.path);
      expect((await store.load()).kind, IntentRecordKind.absent);
      await store.close();
    },
  );

  test(
    'corrupt unknown and missing fields are preserved until explicit discard',
    () async {
      for (final raw in [
        null,
        'broken',
        {'schemaVersion': 99},
        {
          'schemaVersion': 1,
          'requestId': '',
          'source': 'camera',
          'destination': 'room',
        },
        {
          'schemaVersion': 1,
          'requestId': 'x',
          'source': 'gallery',
          'destination': 'unknown',
        },
        {'schemaVersion': 1, 'requestId': 'x', 'destination': 'room'},
      ]) {
        final (box, store) = await boundary();
        await box.put('pending', raw);
        expect((await store.load()).kind, IntentRecordKind.untrusted);
        expect((await store.load()).intent, isNull);
        await expectLater(store.save(intent), storageError);
        await expectLater(store.clear(), storageError);
        expect(box.get('pending'), raw);
        await store.close();
        final reopened = await HiveAcquisitionIntentStore.open(
          directory: directory.path,
        );
        expect((await reopened.load()).kind, IntentRecordKind.untrusted);
        await reopened.clear(discardUntrusted: true);
        expect((await reopened.load()).kind, IntentRecordKind.absent);
        await reopened.close();
      }
    },
  );

  test(
    'failed save and delete flush block subsequent reads until durable retry',
    () async {
      final (box, store) = await boundary();
      box.failFlush = true;
      await expectLater(store.save(intent), storageError);
      await expectLater(store.load(), storageError);
      await expectLater(store.save(intent), storageError);
      box.failFlush = false;
      expect((await store.load()).intent?.requestId, 'room-123');
      box.failFlush = true;
      await expectLater(store.clear(), storageError);
      await expectLater(store.load(), storageError);
      box.failFlush = false;
      expect((await store.load()).kind, IntentRecordKind.absent);
      await store.close();
      final reopened = await HiveAcquisitionIntentStore.open(
        directory: directory.path,
      );
      expect((await reopened.load()).kind, IntentRecordKind.absent);
      await reopened.close();
    },
  );

  test(
    'queued load and close wait for flush; closed operations reject',
    () async {
      final (box, store) = await boundary();
      box.flushGate = Completer<void>();
      final save = store.save(intent);
      var loaded = false;
      final load = store.load().then((value) {
        loaded = true;
        return value;
      });
      final close = store.close();
      await expectLater(store.clear(), storageError);
      await Future<void>.delayed(Duration.zero);
      expect(loaded, false);
      box.flushGate!.complete();
      await save;
      expect((await load).intent?.destination, AcquisitionDestination.room);
      await close;
      await expectLater(store.load(), storageError);
    },
  );

  test(
    'close retries failed flush and close; equal box names isolate directories',
    () async {
      final (box, store) = await boundary();
      box.failFlush = true;
      await expectLater(store.save(intent), storageError);
      await expectLater(store.close(), storageError);
      box
        ..failFlush = false
        ..failClose = true;
      await expectLater(store.close(), storageError);
      box.failClose = false;
      await store.close();
      final reopened = await HiveAcquisitionIntentStore.open(
        directory: directory.path,
      );
      final otherDirectory = Directory('${directory.path}/other');
      final other = await HiveAcquisitionIntentStore.open(
        directory: otherDirectory.path,
      );
      expect((await other.load()).kind, IntentRecordKind.absent);
      expect((await reopened.load()).intent?.requestId, 'room-123');
      await other.close();
      await reopened.close();
    },
  );

  test('open failure reports safe storage category', () async {
    await Directory('${directory.path}/photo_acquisition_v1.hive').create();
    await expectLater(
      HiveAcquisitionIntentStore.open(directory: directory.path),
      storageError,
    );
    expect(
      const AcquisitionStorageException().toString(),
      isNot(contains('private')),
    );
  });

  test(
    'coordinator waits for actual Hive flush and retains receipt after delete flush failure',
    () async {
      final (box, store) = await boundary();
      final adapter = NativeAdapter();
      final container = ProviderContainer(
        overrides: [
          acquisitionIntentStoreProvider.overrideWith((ref) async => store),
          photoPickerServiceProvider.overrideWithValue(adapter),
        ],
      );
      final controller = container.read(photoAcquisitionProvider.notifier);
      await controller.ensureRecovered();
      box.flushGate = Completer<void>();
      final request = controller.request(
        source: PhotoSource.camera,
        destination: AcquisitionDestination.room,
      );
      await Future<void>.delayed(Duration.zero);
      expect(adapter.picks, 0);
      box.flushGate!.complete();
      final acquired = await request as Acquired;
      expect(adapter.picks, 1);
      box.failFlush = true;
      expect(
        await controller.claim(
          requestId: acquired.receipt.requestId,
          destination: AcquisitionDestination.room,
        ),
        isNull,
      );
      expect(box.containsKey('pending'), false); // Hive memory already changed.
      await controller.retryStorage();
      expect(
        container.read(photoAcquisitionProvider).phase,
        AcquisitionPhase.storageError,
      );
      expect(
        container.read(photoAcquisitionProvider).pendingReceipt,
        same(acquired.receipt),
      );
      box.failFlush = false;
      await controller.retryStorage();
      expect(adapter.recoveries, 1);
      expect(
        await controller.claim(
          requestId: acquired.receipt.requestId,
          destination: AcquisitionDestination.room,
        ),
        same(adapter.photo),
      );
      container.dispose();
      await store.close();
      final reopened = await HiveAcquisitionIntentStore.open(
        directory: directory.path,
      );
      expect((await reopened.load()).kind, IntentRecordKind.absent);
      await reopened.close();
    },
  );
}
