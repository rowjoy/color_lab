# Task 5 — Real inference worker and aligned mask service

Status: DONE. The actual default-factory automatic inference gate passed before any Task 6 manual implementation. No commits were created.

Later execution audit: `dart run` can invoke existing native dependency hooks;
this task reused warm objective_c outputs from Task1. The root additionally
reran the real default-factory smoke successfully through direct dartvm under
a tested compiler-deny barrier. See `room-verification-guard.md` for the factual
Task1 host-hook correction and governing commands for all remaining checks.

## Implementation and public APIs

Created:

- `lib/features/room_studio/segmentation/room_segmentation_service.dart`
- `lib/features/room_studio/segmentation/room_segmentation_worker.dart`
- `test/features/room_studio/segmentation/room_segmentation_service_test.dart`

Extended `tool/verify_room_model.dart`. Added this report. The existing `tool/run_room_model_smoke.dart` wrapper is unchanged.

The service file provides immutable `RoomSegmentationResult(photoId, masks)`, `RoomSegmentationService.analyze/close`, `RoomSegmentationWorkerFactory`, lazy default `createRoomSegmentationWorker()`, `IsolateRoomSegmentationService`, and `roomSegmentationServiceProvider`. The worker file provides `RoomSegmentationWorker.run/close`, `IsolateRoomSegmentationWorker.start`, synchronous injectable `runRoomSegmentationFrame`, and safe `RoomSegmentationException` / `RoomSegmentationFailureKind` (also exported from the service).

The outer service owns one active request, one replaceable latest waiting request, and one last successful photo/result cache. Cache keys use identity of the immutable `PreparedPhoto`, never dimensions or caller revision. Cache hits produce the caller's requested `photoId`; mask snapshots remain immutable. Superseded waiting requests receive a safe processing exception. Active results retain their original revision so future callers can reject stale results; the service does not mutate any user draft.

Closing rejects new/waiting requests, waits for active initialization/invocation/cleanup, and releases the worker once. Closing an unused service initializes nothing. Provider disposal safely consumes close failures. Initialization errors are retried only on another explicit analysis. Processing/transport errors retire and close the failed worker before another explicit request can initialize a replacement; cleanup errors cannot replace the original safe failure. Invalid output keeps a healthy worker reusable. There is no automatic retry.

Default asset loading and descriptor JSON parsing run on the root isolate. Transferable model/RGBA bytes, scalar dimensions, the immutable descriptor, and immutable mask results cross the isolate boundary. No native handles or injected factory closures cross it. The Task 1 interpreter is created, invoked, and closed only in `_workerMain`. `PreparedPhoto` reconstruction, Task 2 preprocessing, the single runner invocation, output postprocessing, label validation and mask counts all occur inside that worker. The outer proxy never iterates pixels.

Missing bundled assets yield `modelUnavailable`; malformed descriptors, checksum/runtime/model contract initialization failure yield `incompatibleModel`; native format/output-shape failure yields `invalidOutput`; operational and cancellation failures yield `processing`. Valid all-unselected output succeeds, including all ignored ADE0 and all protected unsupported ADE2. Known surfaces are required only by the acceptance reference smoke.

## TDD and verification evidence

All commands below ran from `/Users/jamirulislam/Movies/dart_jpo/color_lab`.

1. Primary RED, before either production source existed:

   `flutter test --no-pub test/features/room_studio/segmentation/room_segmentation_service_test.dart --reporter expanded`

   Exit 1, `+0 -1`, expected missing `room_segmentation_service.dart` and `room_segmentation_worker.dart` / missing APIs. Fourteen lifecycle/frame tests had been written first. The first sandboxed launch stopped before tests because Flutter's normal `engine.stamp` check could not write; rerunning with approved normal SDK access produced this actual RED. No SDK/package code was patched.

2. Initial GREEN, same focused command: exit 0, `+14: All tests passed!`.

3. Self-review identified the dead-worker recovery gap. Added explicit recovery and cleanup/disposal regressions before changing production recovery. Same focused command: exit 1, `+18 -2`. Failing tests were `processing failure retires the worker so explicit retry can recover after worker exit` and `disposal during failed-worker cleanup rejects queued retry without initializing another worker`, each reporting expected close count 1, actual 0. An earlier single-regression run was also RED (`+18 -1`).

4. Final focused GREEN, same command: exit 0, `+20: All tests passed!`. Covers default asset/descriptor classification, provider disposal, lazy/idempotent close, serialization/latest waiting cancellation, identity caching/eviction and revision preservation, close during initialization/invocation, initialization retry, invalid-output recovery, operational error safety, failed-worker retirement including cleanup failure, disposal during cleanup, close error idempotence, mask dimensions, one invocation with non-square alignment, valid empty selection, output/native format rejection, and actual isolate corrupt-model initialization rejection.

5. Actual default-factory native smoke, initially and again after final functional recovery changes:

   `dart run tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter`

   Both exit 0 with JSON `status: PASS`, native runtime `2.11.0`, and `productionService.status: PASS`. No workerFactory override or fake is used in this gate. The wrapper staged the existing published tester/native dylib and compiled Flutter Dart kernel only. Final stage: `/var/folders/vn/y_l64w1143dgf2j0sjxl8z8h0000gn/T/color-lab-room-smoke.yDCY4X`. The public executable-relative native library location was used unchanged. No runtime download, APK/native compilation, installation or SDK/pub-cache patch occurred.

6. Final scoped analyzer:

   `flutter analyze --no-pub lib/features/room_studio test/features/room_studio tool/verify_room_model.dart`

   Exit 0, `No issues found! (ran in 2.2s)`.

7. Scoped formatting command:

   `dart format lib/features/room_studio/segmentation/room_segmentation_service.dart lib/features/room_studio/segmentation/room_segmentation_worker.dart test/features/room_studio/segmentation/room_segmentation_service_test.dart tool/verify_room_model.dart`

   Exit 0. Final global formatting check:

   `dart format --output=none --set-exit-if-changed lib test tool`

   Exit 0, `Formatted 170 files (0 changed) in 0.53 seconds.`

8. Exactly one full suite after all final functional edits:

   `flutter test --no-pub --reporter expanded`

   Exit 0, `00:22 +680: All tests passed!` (baseline 660 + 20 new tests). No failing tests remained.

## Actual native, asset and alignment evidence

The production service was constructed as `IsolateRoomSegmentationService()` with no worker factory argument. It loaded `assets/models/room_seg.tflite` and `assets/models/room_seg_descriptor.json` through the actual staged Flutter `rootBundle`, created a real worker interpreter, and analyzed the frozen `reference_room.png` as a prepared 1280 × 853 photo.

Final default-service inference took 272.556 ms on this host and allowed 263 root-isolate timer ticks. This heartbeat is a responsiveness sanity check; source ownership establishes that all production pixel loops and interpreter work run in the worker.

The smoke independently maps real raw model IDs with `round(x * 511 / 1279)` and `round(y * 340 / 852)`, checking every one of 1,091,840 production mask pixels. The recorded host reference has no ADE0 pixels, verified before this comparison, so protected closing cannot affect that equality. Frozen source-coordinate reference anchors also pass. Existing Task 2 tests independently verify preprocessing against every byte of the frozen RGB fixture and cover closing rules including ignored-only holes. No expected fixture was regenerated.

Final production mask counts:

| Ownership | Pixels |
| --- | ---: |
| Unselected | 206720 |
| Wall | 531957 |
| Ceiling | 88231 |
| Floor | 46027 |
| Furniture | 218905 |

All four supported surfaces are present. These are discrete exclusive labels 0–4, with the existing descriptor-derived exact five furniture classes. The complete mask contains 1,091,840 bytes.

## Retained scratch evidence for later recorded-preview use

Latest owned evidence directory:

`/var/folders/vn/y_l64w1143dgf2j0sjxl8z8h0000gn/T/color-lab-task5-evidence.WIt9x3`

- `reference-room.labels.bin`: actual production-service ownership bytes, SHA-256 `5ab660689348ba538d622d681742d365d50ce8f08ee8bb3a8712bfa733c840ba`.
- `reference-room.evidence.json`: model/photo/preprocess identities, dimensions, label mapping/counts, mask checksum/path, dense alignment count, runtime and timing; SHA-256 `63f29c6891f512819fa0ab50a6971820f9baac9fa6353cfccacb0edb7ba1044d`.

Hashes were independently checked using `shasum -a 256` on both files. Initial successful smoke evidence also remains at `/var/folders/vn/y_l64w1143dgf2j0sjxl8z8h0000gn/T/color-lab-task5-evidence.8V1CHU` with the identical mask checksum. These are diagnostic files, not new source fixtures or a product API.

Identity details:

- Model SHA-256: `da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c`.
- Descriptor SHA-256: `cf1bb10c7518cb4ff5e5403f856f1342280dbce8341a72c26fbd06d2e345d533`.
- Model source revision: `404e4c284d01b1c9e415b09d7cf8aa0648c4015d`.
- Frozen PNG SHA-256: `94023747b626de08cf3daf14695dfe5810efac833cae74f34792a9ac4005bad1`.
- Prepared RGBA SHA-256: `a0d965b90ca1d0c48070624cc9a609eb1173fb75035ebef023c7269cfb560628`.
- Frozen preprocess-input SHA-256: `b1853a64f7bf077e61e208f7c2756c21f8cf4f55f520bc0c59d0ffd668b7415a`.
- Frozen model-reference JSON SHA-256: `cc8a92f33235ba988c50675c68a921f3bf1bcd83e805d3c9a697ec0803d3b8f9`.

The recorded preprocess checksum identifies the independent Task 1 input fixture, already matched by Task 2's full-byte test; no new worker diagnostic API exports input tensors.

## Self-review and limitations

Self-review checked interpreter ownership, the single-invocation frame composition, safe exception boundaries, root-isolate pixel-loop absence, all waiting-request settlement paths, bounded cache identity, original caller revision retention, worker retirement, disposal ordering, and immutable masks. It found and fixed the dead-worker retry gap with a fresh RED/GREEN regression. There are no outstanding correctness concerns identified by this self-review; controller-arranged fresh review is still separate.

Baseline comparisons against `/private/tmp/color-lab-task5-base.6KNM3W/source` showed only the authorized two new Room source files, one new test file, and the verifier modification. The smoke wrapper and all three frozen fixtures compare unchanged. Picker preparation, photo byte/pixel/axis/working limits, orientation/aspect/white-alpha behavior, Android24/iOS13 settings, existing user drafts, unrelated source, old APK and nine ZIPs were not changed. No Git initialization, worktree or commit was performed.

Host validation uses TFLite 2.11.0 and does not establish Android/iOS runtime performance or numerical parity. No mobile/APK test or release claim is made. The reference model still has the documented semantic mistakes and sparse anchors are not dense ground truth; the dense equality here validates alignment and pipeline consistency. Native invocation is allowed to finish on close; there is no hard timeout that kills a hung native call. No manual fallback or UI behavior was added in Task 5.
