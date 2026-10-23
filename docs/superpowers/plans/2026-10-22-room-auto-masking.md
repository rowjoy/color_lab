# Room Studio Masks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import a room photo, generate real offline AI masks, then refine the four surface layers with brush, erase and bounded undo, without building an APK.

**Architecture:** One shared acquisition coordinator protects Capture/Room picker and recovery ownership. A retained Room controller owns candidate versus committed drafts, a dedicated inference worker produces aligned masks, and a separate pure refinement engine edits immutable pixel ownership with revision guards. Manual tools remain unavailable until an actual successful AI pass.

**Tech Stack:** Existing Flutter/Dart/Riverpod/go_router/image/Hive. Candidate exact dependency `tflite_flutter: 0.12.1`, accepted only after Task 1 validates its release artifacts and real host execution. No backend, paid service or runtime asset download.

**Spec:** `docs/superpowers/specs/2026-10-22-room-auto-masking-design.md`, approved 2026-10-22. The user accepted this plan and the recommended Subagent-driven method on 2026-10-22; execution begins with Task 1's hard feasibility gate.

**Execution status:** The user explicitly instructs keeping auto and manual,
testing the models and integrating the best tested choice. This resumes the
approved architecture/method with evidence-based model selection delegated to
the implementer. The 151-class assumption is corrected to the verified 32-output
ADE20K contract; the historical rejected attempt remains in its original report.

**Selected model:** MOSAIC R4 UINT8, compared against DeepLab UINT8 and MOSAIC
FLOAT32 on the same photos through the actual public interpreter. Selection is
the compact/host-speed/observed-mask balance, not a universal accuracy or phone
performance claim. `room-model-comparison-report.md` records exact evidence and
regressions; the revised model contract is
`../specs/2026-10-22-room-model-contract-amendment.md`.

## Global Constraints

- AI auto-masking first, manual refinement second. Four layers: Wall, Ceiling, Floor, Furniture; Furniture combines bed, sofa, chair, table and cabinet. Other classes remain unselected.
- Keep Android minimum SDK 24 and iOS 13; do not silently raise either. A declared version floor is not proof of native device compatibility.
- No APK/native build, install, clean or data clearing. Preserve the existing APK and all nine preceding source ZIPs.
- Keep 24 MiB acquisition, 32 MiB processing, 24 million decoded pixels and 16,384-pixel axis limits; working image maximum long edge 1600 pixels. Preserve orientation/aspect ratio; flatten transparency on white.
- One acquisition gate includes startup recovery, native picking and preparation. Persist request intent before opening the picker; camera requires explicit Take action. No recovery/picker/camera creation during onboarding.
- Do not overwrite the last successful room draft on cancellation, failure or stale completion. Photo, AI mask, edit and receipt identities must not be interchangeable.
- Manual Add transfers ownership to its selected layer; Erase removes only that layer. Brush diameter 1–20% of shorter image side, default 5%; undo maximum 20 commands and 16 MiB of typed deltas. Restore AI masks confirms and clears history.
- Morphological close uses 3×3 support, only fills ignored model pixels and protects other classes; fill ties are Wall, Ceiling, Floor, Furniture. Derived feather radius is 1–2 working pixels, default 2.
- English UI, existing tokens/shared controls, 360 dp/2× text/both themes/reduced motion and 48 dp controls. Mask preview is not paint; no invented confidence or progress percentages.
- LAB recolor, divider comparison, suggestions, project saving and export/share are later modules. Operational acquisition intent is not durable room-project storage.
- No Git repository exists. Work in place, preserve unrelated edits, do not initialize Git or run commit/worktree helpers. Record task evidence instead of commits.

## Review Focus

Verification execution correction: remaining Flutter test/preview commands use
the fail-closed compiler-deny prefix in `room-verification-guard.md`; smoke uses
the separate `dartvm` binary instead of `dart run`. Earlier exact commands stay
as historical evidence, but their Dart dependency hooks did compile existing
objective_c host support at01:35+0600. No APK/native app/TFLite build occurred.
This guarded prefix overrides the unprefixed command examples below without
changing their test arguments or acceptance criteria.

Artifact verification note: the user confirmed independently running/building
the app during this work. The APK changed at2026-10-22 02:24:15+0600 to SHA-256
`00896beade2a82a2f99908e203b1f4c56a07daa8ef678dcd7f13d85a220d2ae7`.
Preserve that newer user artifact; do not overwrite it to recover the historical
hash. Final checks must distinguish this confirmed concurrent change from the
nine source ZIPs, which still match their original baselines. No APK build or
delivery is authorized for this implementation.

Latest artifact observation supersedes the specific preserved bytes above:
both APK copies now hash
`eb36f749379d33e82644e6c61861647ccb88c685479ff780bd3bd2959fa0a3ae`,
162,563,223 bytes, modified2026-10-22 10:37:35+0600. The origin of this later
change is not attributed. Preserve the currently observed files untouched;
do not restore either historical APK hash. This workflow did not build or touch
them. Nine prior ZIP hashes still match; Android24/iOS13 configs remain
byte-identical to original baseline. Earlier artifact statements and checked
tasks retain their historical evidence, subject to this observation and the
terminal documentation-inclusive archive procedure in the ledger.

1. Recovery must finish before a new intent can replace its destination; concurrent Capture/camera/Room calls cannot create two pickers or consume lost data twice (Tasks 3–4).
2. A second photo, cancelled analysis, disposed container or queued edit must never receive an older inference/error/undo completion, including equal-sized photos (Tasks 5–7).
3. Letterboxing, EXIF rotation, zoom, a stroke leaving/re-entering the image and a second pointer cannot shift masks or paint a connecting line across an ignored area (Tasks 2, 6, 8).
4. A failed interpreter is not a successful empty detection. Zero-area layers remain editable only after a valid AI pass; private loader/quantization limitations cannot be hidden behind mocks (Tasks 1, 5, 7, 9).
5. History eviction does not mean edits disappeared. Restore/replace dialogs and original-photo viewing must preserve or discard exactly the intended draft, not another revision (Tasks 6–9).

---

## Ownership and order

Task 1 is a hard feasibility gate. Tasks 2–10 do not start until its actual model/runtime contract is verified. If the gate fails, report the exact constraint; do not ship fake AI or spend the remaining work on a manual-first substitute.

After Task 1, Tasks 2 and 3 are independent. Task 4 depends on 3; Task 5 depends on 1–2; Task 6 depends on 2 and starts after automatic masking passes its focused gate. Task 7 joins 3, 5 and 6; Tasks 8–9 consume its frozen interfaces; Task 10 is cumulative verification/delivery. Preserve this AI-before-manual order in execution.

| Owner | Files and responsibility |
| --- | --- |
| Task 1 | Model asset/descriptor/notices, native runner contract, dependency pin, actual interpreter verification tool and reference fixture. |
| Task 2 | Pure mask values, model transform/preprocessing, protected layer mapping and feather alpha. |
| Task 3 | Acquisition intent values/repository, source-aware picker adapter, shared lock/recovery/receipt coordinator. |
| Task 4 | Capture/live-camera acquisition migration, onboarding-safe startup recovery scope and existing fakes. |
| Task 5 | Persistent inference worker, cache, serialization, result errors and safe close. |
| Task 6 | Pure stroke/undo values, rasterization, delta budgets and isolate refinement adapter. |
| Task 7 | Retained Room draft/controller and revision-safe import/inference/edit transitions. |
| Task 8 | Actual mask overlay rendering, image viewport/gestures and raster/semantics tests. |
| Task 9 | Room entry, mask screen/dialogs/router and full-app flows. |
| Task 10 | Previews, documentation, independent gates, unchanged artifact checks and source ZIP. |

New tests live under `test/features/room_studio/{domain,segmentation,application,refine,presentation}/`. Acquisition tests remain with the picker and DB boundaries. Create only files named below; no speculative recolor/project/export scaffolding.

All short report filenames below resolve under `docs/superpowers/plans/`. Each GREEN step reruns its RED command and requires exit 0/`All tests passed!`; record actual expanded commands and counts. For Room-owned tasks, also run `flutter analyze --no-pub lib/features/room_studio test/features/room_studio` and `dart format --output=none --set-exit-if-changed lib test tool`. Acquisition-specific analysis is scoped to its listed source/test paths until the companion fake migration lands; report any known sibling compilation failure by exact file, never as success.

### Task 1: Verify and bundle the real model and runtime

**Files:**

- Create: `assets/models/room_seg.tflite`, `assets/models/room_seg_descriptor.json`, `assets/licenses/{room-model-LICENSE,room-model-NOTICE}.txt`; preserve the original license and record provenance/applicable notices.
- Create: `lib/features/room_studio/segmentation/{room_model_descriptor,raw_segmentation,room_model_runner}.dart`.
- Create: `tool/{verify_room_model,run_room_model_smoke}.dart`, `test/fixtures/room/{reference_room.png,reference_input.bin,model_reference.json,reference_room.LICENSE.txt}` and fixture attribution in `docs/asset-sources.md`.
- Test: `test/features/room_studio/segmentation/room_model_descriptor_test.dart`.
- Modify: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart` license registration, `docs/asset-sources.md`; pin `tflite_flutter: 0.12.1` and promote existing `crypto: 3.0.7` to a direct dependency for model checksum verification. Only required model-runtime packaging lines in `android/app/build.gradle.kts`/`ios/Podfile` if the verified release requires them.

**Interfaces:**

- `RoomTensorType { float32, int8, uint8, int32, int64 }`; `RoomInputEncoding { rgbUint8 }`; immutable `RoomModelDescriptor.fromMap(Map<String,Object?>)`. Exact getters: `schemaVersion`=1, `sourceRevision`, `sha256`, `requiredOperators: List<String>`, `inputShape`, `outputShape`, `inputType`, `outputType`, `inputEncoding`, `channelMeans`, `channelStdDevs`, nullable `inputScale`/`inputZeroPoint`, `classCount`=32, `ignoredLabel`=0, `labelsById: Map<int,String>`, `inputWidth`, `inputHeight`, `outputWidth`, `outputHeight`, and `int idForName(String)` (FormatException if absent). Validate 64 hex checksum, finite three-channel identity metadata, paired valid integer quantization, complete unique labels, batch-one RGB input and integer class-map output. This is a fixed-model contract: input UINT8 `[1,512,512,3]`, scale `0.007843137718737125`, zero point 128; output INT32 `[1,512,512]`. Means `[0,0,0]`/stddevs `[1,1,1]` describe raw byte transfer, NOT normalize/requantize; native quantization is validation metadata.
- `RawSegmentation({required int width, required int height, required Uint16List classIds})`: immutable snapshot, positive dimensions, exactly width×height entries.
- `abstract interface class RoomModelRunner { RoomModelDescriptor get descriptor; RawSegmentation invoke(Uint8List inputTensorBytes); void close(); }`.
- `TfliteRoomModelRunner(Uint8List modelBytes, RoomModelDescriptor descriptor)` validates native tensors against the descriptor before invocation. Task 5 constructs it inside its worker; no interpreter/native handle is sent from the UI isolate.
- Selected artifact: revision `404e4c284d01b1c9e415b09d7cf8aa0648c4015d` in `mlcommons/mobile_open`, path `vision/mosaic/models_and_checkpoints/R4/mobile_segmenter_r4_quant_argmax_uint8.tflite`; SHA-256 `da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c`, 1,978,000 bytes. Native tensor names `PreprocessedImageTensor` and `SemanticPredictions`. Required operator strings are `CONV_2D:1`, `DEPTHWISE_CONV_2D:2`, `ADD:1`, `AVERAGE_POOL_2D:1`, `SPLIT:1`, `CONCATENATION:1`, `QUANTIZE:1`, `RESIZE_BILINEAR:1`, `ARG_MAX:1`.
- `tool/run_room_model_smoke.dart` is a Dart-only staging wrapper. It accepts `--flutter-root PATH`, validates SDK/prebuilt resources, compiles `tool/verify_room_model.dart` to Flutter kernel in a fresh task-local directory, copies the existing prebuilt tester plus exact package dylib into executable-relative `host/bin` and `host/resources`, and propagates verifier failures. No native compilation, SDK/pub-cache edits, private binding hacks or host binaries in delivery. Stage the real model assets for Flutter engine loading; Task 5 must exercise default production asset loading, not replace its factory with a fake.

- [x] **Write descriptor and actual-interpreter checks.** Invalid shape/type/quantization/labels/byte lengths must fail. The real verification tool must fail nonzero on a missing library, missing model, malformed output or absent supported surface; it must never skip or count a fake runner as AI evidence.

```dart
expect(() => RoomModelDescriptor.fromMap({'schema': 99}), throwsFormatException);
expect(() => RawSegmentation(width: 2, height: 2,
  classIds: Uint16List(3)), throwsArgumentError);
```

- [x] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/segmentation/room_model_descriptor_test.dart --reporter expanded` against the revised owned APIs before implementing. The historical missing-API RED is preserved, but it does not replace fresh TDD for the revised contract.
- [x] **Acquire and pin assets.** Download/copy only the selected [immutable MOSAIC binary](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/models_and_checkpoints/R4/mobile_segmenter_r4_quant_argmax_uint8.tflite), verify its exact checksum and preserve the literal MLCommons Association License and applicable notices from that revision. Use the clear CC0 Vizcaya reference photo from the recorded spike; retain its attribution/checksum and disclose model errors. Do not bundle the historical Unsplash-review-pending comparison image.
- [x] **Freeze the inspected descriptor and reference input.** Recheck actual native/flatbuffer facts and freeze them in JSON: 32 output IDs, original ADE IDs 1–31 plus unscored zero. Wall=1, Ceiling=6, Floor=4, Furniture exactly 8/11/16/20/24; door15/window9/armchair31 and all other nonzero classes stay unselected/protected. Complete labels are in the model amendment; do not silently copy a zero-based map. Generate `reference_input.bin` independently of Task 2: raw UINT8 RGB; floored top-left aspect fit to longest side512; aligned-corner bilinear, truncate/clamp channels; pad bottom/right RGB123/115/103; record numerical/decoder differences and omit JPEG re-encode explicitly. Pin checksum and independently hand-checked boundary pixels. Existing comparison input bytes are admissible independent reference evidence, not a production preprocessor implementation.
- [x] **Pass the runtime compatibility probe.** Trial exact published [tflite_flutter 0.12.1](https://pub.dev/packages/tflite_flutter/versions/0.12.1) and inspect that release's native dependencies, not just moving `main`. Stage probes in a task-specific temporary directory before retaining app dependency/packaging changes. `Interpreter.fromBuffer`, tensor metadata and an actual invocation must execute with a compatible prebuilt host C library. The upstream [binding loader](https://github.com/tensorflow/flutter-tflite/blob/main/lib/src/bindings/bindings.dart) is private and host-path-sensitive; verify the release's actual loader rather than assuming an override API. Public [Tensor.params documentation](https://pub.dev/documentation/tflite_flutter/latest/tflite_flutter/Tensor/params.html) says Android-only; use the model schema if host inspection cannot supply quantization. No SDK/pub-cache patching, private API hacks, silent platform-floor increases or native compilation. If compatible loading cannot be demonstrated, stop with evidence and request direction; dependency resolution/analyzer alone is not a pass.
- [x] **Implement the descriptor and public runner.** Retain the verified asset/runtime pin, register assets/licenses and use public interpreter/tensor APIs for allocation, direct input-byte transfer, invocation, output snapshot and idempotent close. Reject wrong model SHA before native allocation, mismatched metadata/length, closed use and output IDs outside0–31. Close native resources on partial initialization failure. The verifier must now exercise this production runner, not the comparison probe.
- [x] **Verify and record.** `dart run tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter` and focused descriptor tests must both exit0 with real output. Verify a missing model/library is nonzero, never skipped. Record checksum, native metadata/labels, actual room output, numerical limits and host/native-device distinction in `room-model-production-validation-report.md` and `room-task-1-implementation-report.md`, preserving earlier historical reports. Freeze inspector-derived numeric expectations before later tasks. `flutter pub get` is allowed; it is not a native build. Production-service/asset loading remains Task5's separate gate.

### Task 2: Pure mask ownership and aligned processing

**Files:**

- Create: `lib/features/room_studio/domain/{room_layer,mask_bitmap}.dart`.
- Create: `lib/features/room_studio/segmentation/{room_input,room_mask_processing}.dart`.
- Test: `test/features/room_studio/domain/mask_bitmap_test.dart`, `test/features/room_studio/segmentation/room_mask_processing_test.dart`.

**Interfaces:**

- `RoomLayer { wall, ceiling, floor, furniture }`, `int get label` = 1,2,3,4; zero is unselected.
- `MaskBitmap({required int width, required int height, required Uint8List labels})`, immutable copied ownership bytes, positive dimensions and labels 0–4; `int count(RoomLayer)`, `int get pixelCount`. No Flutter imports, mutable public buffers or whole-image equality work during widget builds.
- Immutable `RoomInput { Uint8List tensorBytes; RoomInputTransform transform; }`. `RoomInputTransform` records source/input/content widths/heights and integer left/top padding; validates positive sizes and containment.
- `RoomInput prepareRoomInput(PreparedPhoto photo, RoomModelDescriptor descriptor)`; `MaskBitmap postprocessRoomOutput(RawSegmentation output, RoomInputTransform transform, RoomModelDescriptor descriptor)`; `Uint8List buildLayerAlpha(MaskBitmap masks, RoomLayer layer, {int featherRadius = 2})`.

- [x] **Write literal pixel tests.** Copy/snapshot immutability; invalid labels/dimensions; independently hand-drawn non-square input/padding and output maps; ignore-zero versus wall; furniture union; protected door/window pixels; stable fill ties; orientation already applied once; radius 1/2 alpha bounds and unchanged ownership. Include extreme wide/tall images without zero-size content.

```dart
final masks = MaskBitmap(width: 2, height: 2,
  labels: Uint8List.fromList([0, 1, 3, 4]));
expect(masks.count(RoomLayer.wall), 1);
expect(masks.count(RoomLayer.floor), 1);
expect(masks.count(RoomLayer.ceiling), 0);
```

- [x] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart --reporter expanded`; expected missing owned APIs before implementation. Use the Task 1 descriptor, never duplicate model class IDs as guesses.
- [x] **Implement the pure pipeline.** Top-left aspect fit floors content dimensions to longest side512, clamped to at least one pixel. Bilinear interpolation aligns corners; one-pixel output dimensions sample source coordinate0. Clamp interpolated channels to0–255 and truncate; transfer raw RGB bytes without normalization/requantization and pad bottom/right RGB123/115/103. Preserve inverse transform. Process output at verified dimensions, map original ADE IDs1/6/4/8,11,16,20,24 to four layers, fill only unscored zero pixels with3×3 close, resolve ties in enum order, protect all other nonzero classes, remove padding and nearest-map to original working dimensions. The inverse is aligned-corner: source axis length1 samples content coordinate0; otherwise use `round(sourceCoordinate * (contentSize - 1) / (sourceSize - 1))`, add padding and clamp to content. Include a literal three-pixel source test; the comparison fixture's floor-selected sparse points remain diagnostic, not an inverse-geometry rule. Closing uses per-layer binary dilation then erosion with zero outside the model grid, and only original ignored0 may be filled. Use separable binomial feather kernels `[1,2,1]/4` or `[1,4,6,4,1]/16` for radius1/2, zero outside the image. Ownership/counts remain discrete; feathering produces only derived alpha.
- [x] **Verify GREEN.** The two focused files, scoped analyzer and formatting must pass. Compare at least one reference tensor/output from Task 1 with independently fixed expected pixels, not expectations regenerated from the function under test.
- [x] **Record acceptance.** Report files, RED/GREEN commands/exits and transform/mapping limits in `docs/superpowers/plans/room-task-2-report.md`; announce these exact APIs ready. No acquisition/UI/native changes.

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

- [x] **Write race/durability tests first.** Delayed recovery must block a new native picker and retain old destination. Two requests admit one native invocation. Intent flush failure admits none. Claim with wrong ID/destination consumes nothing; unknown destination requires explicit claim choice. Cancellation/error preserve prior state; clear-flush failure retains receipt/barrier. A storage retry must not retrieve lost data again after it was already consumed. Test actual-file reopen, corrupt/unknown record preservation, explicit dismissal of an untrusted intent with no recoverable photo, and close/retry behavior.

```dart
expect(adapter.pickCalls, 0); // intent flush is still pending
expect(store.lastIntent?.destination, AcquisitionDestination.room);
expect(await coordinator.claim(requestId: 'obsolete',
  destination: AcquisitionDestination.capture), isNull);
```

- [x] **Observe RED.** Run `flutter test --no-pub test/features/picker/application/photo_acquisition_controller_test.dart test/data/db/hive_acquisition_intent_store_test.dart test/features/picker/photo_view/photo_picker_service_test.dart --reporter expanded`; new coordinator/store cases fail before production changes. Existing picker cases retain gallery/cancellation/bounds coverage.
- [x] **Implement the shared boundary.** One coalesced recovery future and busy gate cover recovery, picker, processing and pending-receipt disposition. Persist intent before invocation. Claim/dismiss durably resolves it before releasing another request; storage failure keeps a retry barrier and prepared receipt. Track whether native lost data was already consumed so durability retries never consume it twice. Missing/untrusted origin never assumes a destination. `discardUntrustedIntent()` is allowed only for an untrusted record with no pending photo, after an explicit UI confirmation; otherwise it returns false. Normal callers claim their matching receipt before navigation; late callers leave it pending. Broaden adapter source checks for camera, retaining 2048×2048 native request limits, no full metadata, byte/processing guards and friendly errors.
- [x] **Verify GREEN.** Focused coordinator/store/adapter files, scoped analyzer and format pass. Count exactly one lost-data retrieval per successful startup initialization; no automatic camera pick.
- [x] **Record acceptance.** `room-task-3-report.md` includes durable close/reopen and failed-flush evidence. Task 4 owns screen migration and all existing adapter-fake signature updates; announce the expanded adapter signature before its implementation lands so no sibling stubs are created.

### Task 4: Migrate Capture and camera without lifecycle regressions

**Files:**

- Create: `lib/features/picker/presentation/acquisition_recovery_scope.dart`.
- Modify: `lib/features/shell/presentation/app_shell.dart`, `lib/features/picker/presentation/{capture_screen,camera_picker_screen}.dart`.
- Modify/test: `test/features/picker/{capture_integration_test,camera_screen_test}.dart`, `test/features/settings/{onboarding_settings_integration_test,settings_modal_contrast_test}.dart`.
- Ownership-race amendment: minimally extend `lib/features/picker/application/photo_acquisition_controller.dart` and its existing `test/features/picker/application/photo_acquisition_controller_test.dart` for additive `request(isActive:)` and synchronous `claim(accept:)` boundaries; no other Task3 refactor.

**Interfaces:**

- `AcquisitionRecoveryScope({super.key, required Widget child})`, placed around the normal indexed shell, never startup/onboarding. It watches committed preferences and calls Task 3 `ensureRecovered()` only after onboarding completes. A direct root-camera acquisition request also awaits that same recovery gate. Repository initialization/recovery errors must become safe coordinator state, not uncaught root-widget errors or navigation changes.
- Capture and live-camera Choose photo call `request(source: PhotoSource.gallery, destination: AcquisitionDestination.capture)` and claim only if their original route/owner remains active. Recovery receipts appear as explicit continuation, not automatic route theft. Room destination receipts are not consumed by Capture.
- Use `claim(accept:)` to check active original ownership and synchronously dispatch/retain pixels inside the acceptance callback after durable clear. Rejection/throw keeps the receipt pending. Camera captures the photo-route future inside that callback, then awaits it outside claim while keeping its camera suspended. Test delayed clear with a hidden/disposed owner, rejection/throw followed by explicit retry, and accepted delivery while the gate remains held. Explicit Continue in Room navigates to `/room` without claiming; Room's receipt consumer is Tasks7/9.
- Pass the original active-owner callback to `request(isActive:)`; delayed recovery/intent saving must not launch a new native picker after that owner hides. Test delayed save plus rejection/throw, including durable intent cleanup and failed-clear retry. Do not claim to cancel an already-started native call.
- Unknown-origin recovery exposes explicit Capture/Room destination actions. An untrusted record without a photo offers confirmed `Dismiss unfinished request`, clearing only operational metadata, never photos/history. Failed dismissal retains the retry state. Do not leave all photo acquisition permanently blocked without a visible resolution action.

- [x] **Write full-app regressions.** Recovery during onboarding: zero native calls. Delayed Room recovery while Capture is visible: no `/photo` push. Gallery from `/camera`: camera is disposed while picker/photo is open and resumes with fresh samples only after returning active. Two entry points racing use one picker; hidden/disposed owner does not claim or reopen a camera.

```dart
expect(find.byType(OnboardingScreen), findsOneWidget);
expect(picker.recoveries, 0);
expect(picker.picks, 0);
expect(cameras, 0);
```

- [x] **Observe RED.** Run `flutter test --no-pub test/features/picker/capture_integration_test.dart test/features/picker/camera_screen_test.dart test/features/settings/onboarding_settings_integration_test.dart test/features/settings/settings_modal_contrast_test.dart --reporter expanded`. Prove old Capture recovery consumes an incorrectly owned result or bypasses the shared gate; preserve cancellation/photo sampling coverage.
- [x] **Implement migration.** Remove Capture's direct `recoverLost()` ownership and route both acquisition callers through the coordinator. Explicit recovery continuation is an intentional safety change; ordinary selected-photo navigation remains the same. Update all four existing `PhotoPickerService` fakes to accept the optional source argument. Add the new in-memory intent-store override to affected full-app test harnesses rather than disabling recovery in production for tests; any additional test-only harness edits must be listed in this owner's report. Do not alter `CameraSession`, `/camera`'s sampler purpose or `/photo`'s PreparedPhoto contract.
- [x] **Verify GREEN.** Four focused files, scoped analysis and format; inspect coordinator call sites with `rg` to ensure neither screen still invokes adapter `.pick()`/`.recoverLost()` directly.
- [x] **Record acceptance.** `room-task-4-report.md` states changed recovery behavior and no-onboarding-camera proof. No Room UI/pixel engine edits.

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

- [x] **Write serialization/error tests.** One active runner call, repeated photo cache reuse, only a bounded last-result cache, invalid output versus valid all-unselected output, caller revisions preserved, pending close waits for invocation, errors recover on explicit retry and no UI-isolate pixel processing.

```dart
expect(fakeWorker.maximumConcurrentRuns, 1);
expect(result.photoId, 'photo-B');
expect(result.masks.labels, everyElement(inInclusiveRange(0, 4)));
await expectLater(serviceAfterClose.analyze(photoId: 'closed', photo: photo),
  throwsA(isA<RoomSegmentationException>()));
```

- [x] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/segmentation/room_segmentation_service_test.dart --reporter expanded`; missing service/API or violated serialized lifecycle fails. Fakes here test lifecycle only, not AI correctness.
- [x] **Implement worker messaging.** The outer service serializes at most one active plus one waiting latest analysis; the worker owns only its interpreter/pixel pipeline. Send byte-safe immutable data, never handles or test-factory closures across isolates. Superseded waiting requests complete with a safe processing cancellation rather than hanging. `close()` is idempotent, rejects queued/new requests, and waits for the active invocation before asking the worker to release its interpreter; closing an unused service initializes nothing. The caller owns logical cancellation/stale-result rejection. Cache masks by photo identity, never dimensions alone; fake counters remain in the outer test worker, not an unobservable cloned isolate object.
- [x] **Verify GREEN and real AI.** Focused tests plus `dart run tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter` must pass using the actual bundled model through this production service and its default factory/asset loading, including non-square alignment against the recorded reference. No mocked run can satisfy the real-AI gate.
- [x] **Record acceptance.** `room-task-5-report.md`; announce the automatic pipeline gate passed before Task 6 manual work begins. If host/native validation fails, stop rather than exposing a fake ready state.

### Task 6: Brush erase and exact bounded undo

**Files:**

- Create: `lib/features/room_studio/domain/{mask_stroke,mask_undo}.dart`.
- Create: `lib/features/room_studio/refine/{mask_refinement,mask_refinement_service}.dart`.
- Test: `test/features/room_studio/refine/mask_refinement_test.dart`, `test/features/room_studio/domain/mask_undo_test.dart`.

**Interfaces:**

- Immutable `MaskPoint(double x, double y)` requires finite normalized 0–1 coordinates. `MaskEditMode { add, erase }`.
- `MaskStroke({required RoomLayer layer, required MaskEditMode mode, required List<List<MaskPoint>> segments, double diameterFraction = .05})` snapshots nonempty segments/points and validates diameter .01–.20. Separate segments prevent a line being painted across an out-of-image excursion.
- `MaskUndoCommand({required int width, required int height, required Uint32List indices, required Uint8List previousLabels})` copies sorted unique in-bounds changed indices and labels 0–4; `int get byteLength` counts its typed buffers. No unchanged-pixel entries or empty command.
- `MaskUndoHistory()` exposes immutable commands, nullable `last`, `byteLength`, `canUndo`, `push(MaskUndoCommand)` and `withoutLast()`. Caps are exactly 20 commands and 16×1024×1024 typed bytes; evict oldest first, sharing immutable command objects rather than copying their buffers on every push.
- `MaskEditResult` exposes new `MaskBitmap masks`, nullable `MaskUndoCommand undo`, and `int changedFromAiCount`.
- `MaskEditResult applyMaskStroke({required MaskBitmap current, required MaskBitmap ai, required MaskStroke stroke})`; `MaskEditResult undoMaskStroke({required MaskBitmap current, required MaskBitmap ai, required MaskUndoCommand command})`.
- `MaskRefinementService`: `Future<MaskEditResult> apply({required MaskBitmap current, required MaskBitmap ai, required MaskStroke stroke})` and `Future<MaskEditResult> undo({required MaskBitmap current, required MaskBitmap ai, required MaskUndoCommand command})`. `IsolateMaskRefinementService` calls the pure functions through `compute`; `maskRefinementServiceProvider` provides this adapter. It owns no interpreter or persistent project store.

- [x] **Write exact-pixel tests.** A point stroke at normalized (.25,.25), diameter .01, on a 2×2 map `[1,2,0,4]` must produce `[3,2,0,4]` when adding Floor and undo to the original bytes. Erasing Wall over an owned Floor is a no-op. Pin interpolated segment coverage using pixel-center distance, disconnected segments, border clipping, invalid points, no-op command absence, exact restore, full-byte budget and oldest-first eviction. Dirty count remains positive when an earlier non-undoable edit survives history eviction.

```dart
final before = MaskBitmap(width: 2, height: 2,
  labels: Uint8List.fromList([1, 2, 0, 4]));
final stroke = MaskStroke(layer: RoomLayer.floor, mode: MaskEditMode.add,
  segments: [[MaskPoint(.25, .25)]], diameterFraction: .01);
final edit = applyMaskStroke(current: before, ai: before, stroke: stroke);
expect(edit.masks.labels, [3, 2, 0, 4]);
expect(undoMaskStroke(current: edit.masks, ai: before,
  command: edit.undo!).masks.labels, before.labels);
```

- [x] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/refine/mask_refinement_test.dart test/features/room_studio/domain/mask_undo_test.dart --reporter expanded` after Task 5's AI gate; missing refinement APIs or incorrect pixels fail. Do not substitute manual-first work for a failed model gate.
- [x] **Implement the pure operations.** Paint pixel centers whose distance to a segment/point is at most half the selected fraction of the shorter image side. Add transfers ownership; Erase touches selected ownership only. Collect previous labels once per changed index. Undo restores those bytes exactly; calculate differences from the original AI map in the worker, not by history length. No smoothing of ownership during strokes.
- [x] **Verify GREEN.** Both test files, scoped analyzer/format and real `compute` adapter round trip pass. Count delta buffers precisely; the 1600×1600 image limit permits one full-frame 5-byte-per-pixel delta within 16 MiB. No UI-isolate pixel loops.
- [x] **Record acceptance.** `room-task-6-report.md` with independent expected bytes and budget evidence. No controller, acquisition or screen changes.

### Task 7: Retained revision safe Room controller

**Files:**

- Create: `lib/features/room_studio/domain/room_mask_state.dart`.
- Create: `lib/features/room_studio/application/room_mask_controller.dart`.
- Test: `test/features/room_studio/application/room_mask_controller_test.dart`.

**Interfaces:**

- `RoomMaskStage { empty, acquiring, analyzing, ready, error }`; `RoomMaskTool { move, add, erase }`; `RoomMaskFailureKind { permissionDenied, acquisitionUnavailable, invalidImage, tooLarge, storage, modelUnavailable, incompatibleModel, invalidOutput, processing }`.
- Immutable `RoomPhotoCandidate` has photoId/PreparedPhoto. Immutable `RoomMaskDraft` has photoId/photo, original `aiMasks`, current `masks`, `MaskUndoHistory history`, nonnegative `maskRevision` and `changedFromAiCount`; `hasEdits` means changedFromAiCount > 0, not nonempty history. Both maps must match the photo dimensions.
- `RoomMaskState.initial()` exposes stage, nullable committed draft/candidate/failure, selectedLayer=Wall, tool=Move, brushFraction=.05, showOverlay=true, editBusy=false; `canEdit` only for ready, nonbusy, visible-overlay state with a committed AI draft. Keep immutable snapshots; avoid byte-array comparison on normal rebuilds.
- Retained `roomMaskProvider: NotifierProvider<RoomMaskController,RoomMaskState>`; `roomPhotoIdFactoryProvider: Provider<String Function()>` supplies unique in-session IDs and deterministic test IDs.
- Controller methods: `Future<void> importPhoto(PhotoSource source, {required bool Function() isActive})`, `Future<void> continueImport(String requestId, {required bool Function() isActive})`, `Future<void> analyzeCandidate()`, `Future<void> retryAnalysis()`, `void cancelCandidate()`, `void setLayer(RoomLayer)`, `void setTool(RoomMaskTool)`, `void setBrushFraction(double)`, `void setShowOverlay(bool)`.
- Captured mutation methods: `Future<bool> applyStroke({required String photoId, required int maskRevision, required MaskStroke stroke})`, `Future<bool> undo({required String photoId, required int maskRevision})`, `bool restoreAiMasks({required String photoId, required int maskRevision})`. Return false with no side effects for stale/busy/invalid-phase actions. `restoreAiMasks` is called only after UI confirmation.

- [x] **Write real-provider transition tests.** Inject delayed acquisition/segmentation/refinement services and actual immutable maps. Assert no editing in empty/analyzing/failure states; valid all-empty AI result does permit manual marking. Old A success/error cannot replace equal-sized B. Late receipt remains pending rather than claimed; last successful draft survives pick cancel, failed inference and logical cancellation. Captured old stroke/undo/reset cannot affect a replacement or new revision. Test budget eviction still leaves `hasEdits=true`, and selection/theme/navigation do not reset masks.

```dart
expect(container.read(roomMaskProvider).canEdit, isFalse); // inference pending
expect(await controller.undo(photoId: 'photo-A', maskRevision: 0), isFalse);
expect(container.read(roomMaskProvider).draft, same(committedB));
```

- [x] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/application/room_mask_controller_test.dart --reporter expanded` before its implementation. Use actual Task 3/5/6 contracts, not duplicate pending types.
- [x] **Implement state ownership.** Read injected services without dependency-driven draft resets. Import starts a candidate operation while keeping committed data. Pass a live/current-operation and screen-active guard to acquisition `request(isActive:)`. Check isActive before claiming a receipt; use `claim(accept:)` to atomically retain prepared pixels only for the still-current live operation. If hidden during claim, retain the prepared candidate for explicit `analyzeCandidate()` instead of starting unseen analysis; if disposed/superseded, reject acceptance so the receipt remains pending. A staged candidate remains acquiring with no busy animation and an explicit Continue action. Analyze success commits atomically and clears old history; failure preserves committed data. Logical cancel invalidates operation tokens. Serialize refinement; reject mismatched photo/revision/tool/layer and discard late worker completions. Hiding overlay switches to Move and disables painting; show original changes no mask. Dispose invalidates callbacks, not an active native call's memory.
- [x] **Verify GREEN.** Focused tests, analyzer and format pass, including fresh ProviderContainers and independence from roomColorProvider, matching, HSL/mixer/formula/harmonies, history and saved palettes.
- [x] **Record acceptance.** `room-task-7-report.md`, exact transition/race evidence and API-ready announcement. No disk persistence of photos/masks/edits and no UI edits.

### Task 8: Real overlay rendering and transform safe viewport

**Files:**

- Create: `lib/features/room_studio/presentation/room_mask_viewport.dart`.
- Create: `lib/features/room_studio/application/mask_overlay_service.dart`.
- Test: `test/features/room_studio/presentation/{mask_overlay_service_test,room_mask_viewport_test}.dart`.

**Interfaces:**

- `MaskOverlayService`: `Future<Uint8List> render({required MaskBitmap masks, required RoomLayer layer, required RgbColor tint, int featherRadius = 2})` returns PNG RGBA, using Task 2 alpha and worker encoding. `IsolateMaskOverlayService` implements it; `maskOverlayServiceProvider` supplies that adapter.
- `RoomMaskViewport({super.key, required String photoId, required int maskRevision, required PreparedPhoto photo, required MaskBitmap masks, required RoomLayer layer, required RoomMaskTool tool, required double brushFraction, required bool showOverlay, required bool editingEnabled, required ValueChanged<MaskStroke> onStroke})`.
- Reuse `PhotoViewport` for both display and hit testing; zoom 1–8, explicit Move versus Add/Erase. Diagram callbacks carry the gesture's captured layer/mode; screen captures photoId/maskRevision for Task 7.

- [x] **Write raster and gesture tests.** Actual PNG alpha/tint at independently known points, unchanged photo bytes, selected-only overlay, resize/letterbox alignment, non-square input, zoom mapping, no old overlay on a new photo/revision, no recomputation while moving/rebuilding unchanged geometry, and async old PNG completion ignored. A one-finger brush commits once; a second pointer cancels without a command; leaving/re-entering the image creates disconnected segments. Image semantics describe a mask preview, never a painted room or invented accuracy.

For a 7×7 mask whose central 3×3 pixels are Wall, rendered at feather radius 1:

```dart
final decoded = img.decodePng(png)!;
expect(decoded.getPixel(3, 3).a, 255);
expect(decoded.getPixel(0, 0).a, 0);
```

- [x] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/presentation/mask_overlay_service_test.dart test/features/room_studio/presentation/room_mask_viewport_test.dart --reporter expanded` before implementation. Rasterize actual painter/image output and dispose explicit semantics handles inline, not only in late teardown.
- [x] **Implement viewport and cache.** Cache by photoId/maskRevision/layer/tint/feather. Never run model, pixel masks or PNG encoding in build/paint. Clear stale overlay immediately when its key changes, then publish decoded output only for that key. Render photo and overlay through the same rect. During drag draw lightweight vector preview; no mask commits until accepted pointer-up. Second-pointer/cancel/tool/photo changes roll back preview. Original-only mode is nonpainting; no saturation filter masquerading as recolor.
- [x] **Verify GREEN.** Focused pixel/gesture/semantics tests, analyzer and format; both themes and 360 dp/2× text/reduced motion. Explicitly inspect mask alignment rather than asserting only widget existence.
- [x] **Record acceptance.** `room-task-8-report.md`; expose exact APIs to Task 9. No model/controller/Capture/README edits.

### Task 9: Room entry editor and full application flows

**Files:**

- Create: `lib/features/room_studio/presentation/{room_mask_screen,room_mask_dialogs}.dart`.
- Modify: `lib/features/room_studio/presentation/room_screen.dart`, `lib/routing/app_router.dart`.
- Test: `test/features/room_studio/presentation/room_masks_integration_test.dart`.
- Consume the Task 3 test boundary `test/support/in_memory_acquisition_intent_store.dart`; do not create a duplicate store or take ownership of its production interface.

**Interfaces and exact UI:**

- Root guarded `/room/masks` route, `RoomMaskScreen`, title `Room masks`, scroll key `screen-RoomMasks`; Back pops or goes `/room` without reset.
- Room entry `Prepare room masks`, key `open-room-masks`, ahead of the retained explicitly labeled illustrated color study. Existing Use in Room color behavior remains intact and is not described as photo painting.
- Buttons `Choose room photo`/`Take room photo`, keys `room-mask-gallery`/`room-mask-camera`. Recovered receipts use `room-mask-continue-import`; unknown destination recovery offers explicit Capture/Room choice. If a claimed candidate is awaiting user acceptance, show `Analyze this photo`, key `room-mask-continue-analysis`.
- Analysis text `Finding room surfaces on this device…`; `Cancel analysis`, `Retry analysis`, `Choose another photo`. No fake percentages. A valid empty result says `No supported surfaces were found. You can mark them manually.` Runtime errors say `Room analysis could not finish. Try again or choose another photo.`
- Ready: actual viewport key `room-mask-viewport`, visible `Mask preview`, Wall/Ceiling/Floor/Furniture chips with coverage and `Not detected` for zero counts. Move/Add/Erase, brush size, `Show original`, Undo (`room-mask-undo`), `Restore AI masks` (`room-mask-restore`) and replace-photo actions.
- Confirm restore/replace in root shared-token dialogs, minimum 48 dp, reduced motion. Restore confirmation key `confirm-room-mask-restore`; replace confirmation `confirm-room-mask-replace`. Recheck captured photo/revision after dialog acceptance. Persistent copy: `Automatic masks may miss surfaces or include nearby objects. Check each layer and refine it before recoloring.`
- Dialog helpers: `Future<bool> confirmRestoreAiMasks(BuildContext context)` and `Future<bool> confirmReplaceRoomPhoto(BuildContext context)` in `room_mask_dialogs.dart`; cancellation/system Back return false. They do not mutate controller state themselves.

- [x] **Write full-app behavior tests.** First real Room entry test must fail before the CTA exists. Use actual router/controller/refinement/viewport, in-memory repository boundaries and delayed segmentation output. Cover both acquisition sources; AI-before-manual; failed versus empty detection; edits/undo exact pixels; selected-layer ownership; original-only no edits; cancelled/stale root dialogs; replaced photo resets view/history only on success; pending/late receipts never steal routes; preserved old draft on error and unchanged common Use in Room/history/Lab state. Include direct-route onboarding guard.

```dart
await tester.tap(find.byKey(const ValueKey('nav-Room')));
await tester.pumpAndSettle();
expect(find.byKey(const ValueKey('open-room-masks')), findsOneWidget);
```

- [x] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/presentation/room_masks_integration_test.dart --reporter expanded`; first behavioral failure must identify the missing Room action. Do not create fake production workers to compile tests.
- [x] **Implement UI against ready APIs.** Watch retained state, dispatch source-aware imports, and provide an active-owner callback checking mounted/current route before claiming asynchronous photos. Rendering/typing/theme changes do not reset viewport; a committed new photo or restore resets it intentionally. Capture photo/revision/tool in action callbacks and clear gesture/local busy state only for accepted mutations. Show the preserved previous draft as an explicit Return option after failure; do not automatically enable manual editing on a failed candidate.
- [x] **Verify GREEN.** Full-app tests, scoped analyzer/format, plus 360 dp/2× light and dark/reduced-motion dialogs and visible new-photo entry without `ensureVisible` hiding a viewport bug. Faked lifecycle output here is UI evidence only; actual AI execution remains Task 1/5's separate gate.
- [x] **Record acceptance.** `room-task-9-report.md` with observed failures/fixes and no raw errors/clinical/paint claims. Run one cumulative full suite and report any unfinished sibling failure by exact name; do not count a cancelled suite as success.

### Task 10: Independent gates previews and source only handoff

**Files:** `tool/render_previews.dart`, `tool/deny-native-compilers.sb`, `test/fixtures/room/{reference_masks.bin,reference_masks.json}`, `docs/asset-sources.md`, `README.md`, current Room spec/plan/progress/reports, `docs/superpowers/plans/room-source-archive-recipe.rb`, `dist/color-lab-room-masks-2026-10-22.zip`.

**Consumes:** All frozen interfaces above and real model evidence; no new product API.

- [x] **Extend diagnostic captures first.** Preserve the 104 existing stems. Add Room empty/import progress, actual reference-mask layers, Add/Erase, undo/restore and pending/error states, both themes; narrow 360×800/2× text/reduced-motion editor/dialog cases. Use real controller/viewport and a static output recorded from the verified model for repeatable preview fixtures, not hand-made masks presented as model execution. Retain actual Task5 service bytes as `test/fixtures/room/reference_masks.bin` (SHA-256 `5ab660689348ba538d622d681742d365d50ce8f08ee8bb3a8712bfa733c840ba`,1280×853), plus portable identity/provenance/count/checksum metadata in `reference_masks.json`; no absolute temporary dependency in rendering. Do not regenerate masks from a fake or alter Task1's independent fixtures. Record fixture attribution in asset sources. State that previews are not native inference or hardware evidence.
- [x] **Run independent gates.** Each task report supplies exact brief/files/RED/GREEN/exits; review task source/test deltas, fix through its owner and re-review the fix. One most-capable whole-module review follows the scoped gates. Main executor performs the plan/spec coverage and signature check itself, not via delegated plan self-review.
- [x] **Run fresh final verification.** `dart run tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter`, `flutter test --no-pub --reporter expanded`, `flutter analyze --no-pub`, `dart format --output=none --set-exit-if-changed lib test tool`, and `flutter test tool/render_previews.dart --no-pub --reporter expanded` all exit0. Inspect actual reference masks/overlays and enlarged layouts. No APK/native build/install/clean command. Record counts only after observing output;569 was the preceding milestone, not this module's result.
- [x] **Write truthful handoff documentation.** README distinguishes real AI, manual refinement, derived mask overlays and subsequent recolor/project/export work; records working-image resolution, session-only photo/edits, operational recovery intent, runtime version/notice requirements and device limits. Preserve and recheck the old APK SHA-256 `1986b60e39c94af8bbc2bacb71b14dc7cf427899f3476ff60bbb581d56b12b2c` and nine old ZIP hashes. Keep both platform floors unchanged. Model/fixture provenance and checksums must appear in asset sources; no runtime model URL.
- [x] **Package and validate the cumulative source ZIP.** Include sources/assets/test fixtures/tests/tools/docs/native source/pubspec/lock/licenses/README/metadata. Exclude APK/AAB, build output, native binaries used only by host checks, local.properties, caches, Pods/symlinks, ephemeral/Xcode environment/xcuserdata, IDE files and previous ZIPs. `unzip -tq` must pass; compare required archived files with workspace bytes and scan for duplicates/absolute/traversal entries. Refresh final plan/progress/report edits into the ZIP and recheck integrity before delivery. Do not link the old APK as this delivery.

## Self review and handoff

Main-agent self-review maps the approved design as follows:

| Design requirement | Owning tasks |
| --- | --- |
| Real model, provenance, runtime/platform floors and metadata gate | 1, 5 |
| Photo limits, explicit camera action, durable intent and safe recovery | 3, 4, 9 |
| Aligned preprocessing, protected classes, exclusive layers and feather | 2, 5, 8 |
| Candidate/committed drafts, retention and stale completion guards | 7, 9 |
| AI-before-manual, stroke geometry, ownership and bounded exact undo | 5, 6, 7, 8, 9 |
| Accessible UI, independent tests/review and source-only delivery | 8, 9, 10 |

Cross-task signatures and all five Review Focus cases are checked against their
owning test steps. The first gate does not depend on the later preprocessor:
it uses a separately recorded reference tensor. Worker tests do not pretend a
copied isolate fake is observable from the UI. The binary's unknown numeric
metadata remains an explicit inspection gate, not an invented constant.
No spec coverage gap remains in the plan. This is planning evidence, not passing
product-test or native-runtime evidence. Execution status and evidence are tracked
in `2026-10-22-room-auto-masking-progress.md`; checklists change only after the
corresponding work is verified.

Recommended method: **Subagent-driven**, because acquisition recovery, native
worker lifecycle and immutable edit revisions cross independent boundaries
where scoped fresh reviews are valuable. Native execution remains a valid
alternative, with one final independent review. The user accepted the recommended
method before implementation began.
