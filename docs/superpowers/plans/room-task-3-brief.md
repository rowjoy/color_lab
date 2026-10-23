### Task 3: Durable acquisition intent and shared coordinator

**Files:**

- Create: `lib/features/picker/domain/{photo_acquisition,acquisition_intent_store}.dart`.
- Create: `lib/data/db/hive_acquisition_intent_store.dart`.
- Create: `lib/features/picker/application/{acquisition_intent_providers,photo_acquisition_controller}.dart`.
- Create: `test/support/in_memory_acquisition_intent_store.dart` for integration-test repository overrides.
- Modify: `lib/features/picker/application/photo_picker_service.dart`.
- Test: `test/features/picker/application/photo_acquisition_controller_test.dart`, `test/data/db/hive_acquisition_intent_store_test.dart`, existing `test/features/picker/photo_view/photo_picker_service_test.dart`.

**Interfaces:**

- `PhotoSource { gallery, camera }`; expand adapter to `Future<PreparedPhoto?> pick({PhotoSource source = PhotoSource.gallery})`; retain `recoverLost()`/`openSettings()` and existing provider injection.
- `AcquisitionDestination { capture, room }`; immutable `AcquisitionIntent({required String requestId, required PhotoSource source, required AcquisitionDestination destination})`, schema-1 map serialization.
- `IntentRecordKind { absent, valid, untrusted }`; immutable `AcquisitionIntentRecord.absent()`, `.valid(AcquisitionIntent)` and `.untrusted()` expose kind and nullable validated intent. Unknown/corrupt records are preserved rather than defaulted to Capture.
- `AcquisitionIntentStore`: `Future<AcquisitionIntentRecord> load()`, `Future<void> save(AcquisitionIntent intent)`, `Future<void> clear({bool discardUntrusted = false})`, `Future<void> close()`. Safe `AcquisitionStorageException`; Hive box `photo_acquisition_v1`, key `pending`; existing app-private `color_lab` directory, serialized writes/flush retry barrier and no new package/schema in other boxes.
- `HiveAcquisitionIntentStore.open({required String directory, String boxName = 'photo_acquisition_v1'})` returns `Future<HiveAcquisitionIntentStore>`; `.fromBox({required Box<dynamic> box})` owns the injected box. Directory provider resolves the final `color_lab` directory; the factory does not append it twice. `InMemoryAcquisitionIntentStore({AcquisitionIntentRecord? initial})` implements the same interface for UI tests.
- Immutable `AcquisitionReceipt({required String requestId, PhotoSource? source, AcquisitionDestination? destination, required PreparedPhoto photo, required bool recovered})`; unknown recovered origin stays nullable. `AcquisitionFailureKind { permissionDenied, unavailable, invalidImage, tooLarge, processing, storage, recovery }`.
- Sealed `AcquisitionOutcome`: `Acquired(AcquisitionReceipt receipt)`, `AcquisitionCancelled`, `AcquisitionBusy`, `AcquisitionFailed(AcquisitionFailureKind kind)`. `AcquisitionPhase { uninitialized, recovering, ready, picking, storageError }`; immutable `AcquisitionState` exposes phase, at most one `pendingReceipt`, nullable failure and `hasUntrustedIntent`.
- Retained `photoAcquisitionProvider: NotifierProvider<PhotoAcquisitionController,AcquisitionState>`. Methods: `Future<void> ensureRecovered()`, `Future<AcquisitionOutcome> request({required PhotoSource source, required AcquisitionDestination destination, bool Function()? isActive})`, `Future<PreparedPhoto?> claim({required String requestId, required AcquisitionDestination destination, bool Function(PreparedPhoto photo)? accept})`, `Future<bool> dismiss(String requestId)`, `Future<bool> discardUntrustedIntent()`, `Future<void> retryStorage()`. Additive Task4 guards: request checks isActive before initialization, after recovery and after saving intent/before native launch; false/throw cancels without launching and durably clears only this request's saved intent, retaining storage barriers on failure. After durable claim clear, call accept synchronously while gate/receipt remain held; false or thrown callbacks retain the pending photo and return null, true atomically accepts delivery. Omitting callbacks retains original non-UI semantics. `acquisitionIntentStoreProvider: FutureProvider<AcquisitionIntentStore>` uses `acquisitionStorageDirectoryProvider: FutureProvider<Directory>` and `acquisitionIntentStoreFactoryProvider: Provider<Future<AcquisitionIntentStore> Function(String)>`; default app-private directory, no automatic retry. `AcquisitionState.initial()` is uninitialized; coordinator creation alone performs no native work.

- [ ] **Write race/durability tests first.** Delayed recovery must block a new native picker and retain old destination. Two requests admit one native invocation. Intent flush failure admits none. Claim with wrong ID/destination consumes nothing; unknown destination requires explicit claim choice. Cancellation/error preserve prior state; clear-flush failure retains receipt/barrier. A storage retry must not retrieve lost data again after it was already consumed. Test actual-file reopen, corrupt/unknown record preservation, explicit dismissal of an untrusted intent with no recoverable photo, and close/retry behavior.

```dart
expect(adapter.pickCalls, 0); // intent flush is still pending
expect(store.lastIntent?.destination, AcquisitionDestination.room);
expect(await coordinator.claim(requestId: 'obsolete',
  destination: AcquisitionDestination.capture), isNull);
```

- [ ] **Observe RED.** Run `flutter test --no-pub test/features/picker/application/photo_acquisition_controller_test.dart test/data/db/hive_acquisition_intent_store_test.dart test/features/picker/photo_view/photo_picker_service_test.dart --reporter expanded`; new coordinator/store cases fail before production changes. Existing picker cases retain gallery/cancellation/bounds coverage.
- [ ] **Implement the shared boundary.** One coalesced recovery future and busy gate cover recovery, picker, processing and pending-receipt disposition. Persist intent before invocation. Claim/dismiss durably resolves it before releasing another request; storage failure keeps a retry barrier and prepared receipt. Track whether native lost data was already consumed so durability retries never consume it twice. Missing/untrusted origin never assumes a destination. `discardUntrustedIntent()` is allowed only for an untrusted record with no pending photo, after an explicit UI confirmation; otherwise it returns false. Normal callers claim their matching receipt before navigation; late callers leave it pending. Broaden adapter source checks for camera, retaining 2048×2048 native request limits, no full metadata, byte/processing guards and friendly errors.
- [ ] **Verify GREEN.** Focused coordinator/store/adapter files, scoped analyzer and format pass. Count exactly one lost-data retrieval per successful startup initialization; no automatic camera pick.
- [ ] **Record acceptance.** `room-task-3-report.md` includes durable close/reopen and failed-flush evidence. Task 4 owns screen migration and all existing adapter-fake signature updates; announce the expanded adapter signature before its implementation lands so no sibling stubs are created.

