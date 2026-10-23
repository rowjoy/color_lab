### Task 5: Real inference worker and aligned mask service

**Files:**

- Create: `lib/features/room_studio/segmentation/{room_segmentation_service,room_segmentation_worker}.dart`.
- Test: `test/features/room_studio/segmentation/room_segmentation_service_test.dart`.
- Extend: `tool/verify_room_model.dart` with the production service round trip.

**Interfaces:**

- Immutable `RoomSegmentationResult({required String photoId, required MaskBitmap masks})`.
- `RoomSegmentationService`: `Future<RoomSegmentationResult> analyze({required String photoId, required PreparedPhoto photo})`, `Future<void> close()`.
- `RoomSegmentationFailureKind { modelUnavailable, incompatibleModel, invalidOutput, processing }`, safe `RoomSegmentationException(kind)`.
- `RoomSegmentationWorker`: `Future<MaskBitmap> run(PreparedPhoto photo)`, `Future<void> close()`; `RoomSegmentationWorkerFactory = Future<RoomSegmentationWorker> Function()`.
- `IsolateRoomSegmentationWorker.start({required Uint8List modelBytes, required RoomModelDescriptor descriptor})` returns `Future<IsolateRoomSegmentationWorker>`. Create/use/close the Task 1 runner only inside this worker. `MaskBitmap runRoomSegmentationFrame(PreparedPhoto photo, RoomModelDescriptor descriptor, RoomModelRunner runner)` composes Task 2 preprocessing/postprocessing around exactly one invocation; local unit tests can inject a runner into this synchronous helper.
- `IsolateRoomSegmentationService({RoomSegmentationWorkerFactory? workerFactory})` owns the outer queue/cache. Default `createRoomSegmentationWorker()` loads bundled bytes/descriptor on demand and starts the production worker; no asset download or native initialization in widget build/onboarding. `roomSegmentationServiceProvider: Provider<RoomSegmentationService>` owns safe close. Lifecycle tests may inject a fake worker factory; the real-AI gate must use the default factory.

- [ ] **Write serialization/error tests.** One active runner call, repeated photo cache reuse, only a bounded last-result cache, invalid output versus valid all-unselected output, caller revisions preserved, pending close waits for invocation, errors recover on explicit retry and no UI-isolate pixel processing.

```dart
expect(fakeWorker.maximumConcurrentRuns, 1);
expect(result.photoId, 'photo-B');
expect(result.masks.labels, everyElement(inInclusiveRange(0, 4)));
await expectLater(serviceAfterClose.analyze(photoId: 'closed', photo: photo),
  throwsA(isA<RoomSegmentationException>()));
```

- [ ] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/segmentation/room_segmentation_service_test.dart --reporter expanded`; missing service/API or violated serialized lifecycle fails. Fakes here test lifecycle only, not AI correctness.
- [ ] **Implement worker messaging.** The outer service serializes at most one active plus one waiting latest analysis; the worker owns only its interpreter/pixel pipeline. Send byte-safe immutable data, never handles or test-factory closures across isolates. Superseded waiting requests complete with a safe processing cancellation rather than hanging. `close()` is idempotent, rejects queued/new requests, and waits for the active invocation before asking the worker to release its interpreter; closing an unused service initializes nothing. The caller owns logical cancellation/stale-result rejection. Cache masks by photo identity, never dimensions alone; fake counters remain in the outer test worker, not an unobservable cloned isolate object.
- [ ] **Verify GREEN and real AI.** Focused tests plus `dart run tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter` must pass using the actual bundled model through this production service and its default factory/asset loading, including non-square alignment against the recorded reference. No mocked run can satisfy the real-AI gate.
- [ ] **Record acceptance.** `room-task-5-report.md`; announce the automatic pipeline gate passed before Task 6 manual work begins. If host/native validation fails, stop rather than exposing a fake ready state.

