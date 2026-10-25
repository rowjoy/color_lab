# GitHub Room Model Downloads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Execute inline with TDD; one fresh final code review.

**Goal:** Deliver both room AI models from the user's public GitHub Release instead of the APK, with verified persistent offline storage and visible first-use progress.

**Architecture:** A single-flight `RoomModelStore` streams fixed, pinned release assets into app-private support storage, verifies exact byte length and SHA-256, and atomically promotes valid files. The segmentation factory reads these files, retains the bundled descriptor, and continues the existing on-device two-model pipeline. Room analysis shows real download/verification progress and cancellation; existing Retry analysis retries failures without replacing the previous draft.

**Tech Stack:** Flutter, Riverpod, dart:io HttpClient/File, existing crypto/path_provider packages, GitHub Releases.

**Spec:** The Approved scope and constraints below record the user's conversation-approved requirements; no new approval gate (user opted out).

## Approved scope / Global Constraints

- Use the existing PUBLIC repository `rowjoy/color_lab` for code and model Releases; authenticated `NecJoy` has push access.
- Fixed release tag `room-models-v1`, assets `room_seg.tflite` (1,978,000 bytes, SHA-256 `da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c`) and `room_depth.tflite` (66,338,288 bytes, SHA-256 `93d871071edff1218973ce25ee27ce95ccd20450c70a55e1b89efa3f5a772cdd`).
- No credentials in app or source. No room photo upload. HTTPS public fixed-version download links; no floating latest endpoint.
- Download on first explicit room-photo analysis, with actual progress, Cancel and existing Retry analysis; cached use is offline.
- Verify size and hash before native loading. Never promote partial/corrupt files. Preserve an existing valid model when a new download fails.
- Keep model descriptor, all licenses and license registry bundled. Exclude both .tflite files from APK/Git, but preserve local files for release and smoke verification.
- Preserve photo geometry, native model contracts, masks, manual edits, colors, and existing controller lifecycle behavior.
- Work in the current IDE workspace on a feature branch; preserve untracked models, dist and prior scratch. The user runs source-code pushes manually.

## Review Focus

- Concurrent inference/retry requests must not download duplicate files or race over a partial file.
- Cancellation and immediate retry must not complete a newer analysis with stale bytes/progress.
- Offline cold app start must reuse verified files; corrupt/missing files need a safe retry, not native allocation.
- Non-200 responses, stalled/truncated/oversized bodies and wrong hashes must never produce a ready model.
- Release Android needs Internet permission; APK inspection must prove both model binaries are absent.

### Task 1: Verified model store

**Files:** Create `lib/features/room_studio/models/room_model_store.dart`; create `test/features/room_studio/models/room_model_store_test.dart`.

**Interfaces:** `RoomModelArtifact` has name/url/bytes/sha256. `RoomModelStore({Future<Directory> Function()? directory, List<RoomModelArtifact> artifacts, HttpClient Function()? clientFactory})` exposes `Future<RoomModelBytes> load()`, current `progress`, `Stream<RoomModelDownloadProgress> get changes`, `cancel()`, and `Future<void> close()`. `RoomModelBytes` carries semantic and depth Uint8Lists. Progress stages: idle, checking, downloading, verifying, ready, failed, cancelled; counts are aggregate actual bytes, with current model label.

- [ ] Write real local HTTP + temporary filesystem tests: two-file verified download, offline second store, corrupted cache redownload, invalid hash, truncation/oversize/status failures, partial cleanup, cancellation/retry, concurrent single-flight, closed store.
- [ ] Run `flutter test --no-pub test/features/room_studio/models/room_model_store_test.dart --reporter failures-only`; observe missing implementation RED.
- [ ] Implement the minimal streaming store; version paths by pinned hash, exact-size checks, async streaming SHA-256, bounded request/body timeout, and cancellation that closes active HTTP I/O.
- [ ] Run the focused tests GREEN and format/analyze the new files.
- [ ] Commit only this task's files after passing verification.

### Task 2: Integrate analysis and progress

**Files:** Modify `segmentation/room_segmentation_service.dart`, `presentation/room_mask_screen.dart`; create `application/room_model_download_providers.dart`, `presentation/room_model_download_status.dart`; update service/integration tests and `tool/verify_room_model.dart`.

**Interfaces:** The default provider owns one `RoomModelStore`. `createRoomSegmentationWorker({RoomModelStore? modelStore})` reads bundled descriptor first, then `store.load()` and starts the unchanged worker. An omitted store is owned/closed by the factory. Tool smoke injects a store seeded from local fixture bytes so it exercises verified offline files without platform plugins. A stream provider exposes current download progress; its idle state causes no network/directory calls.

- [ ] Write RED tests for file-backed factory failure mapping, progress/verification UI, and cancellation forwarding while preserving existing room lifecycle tests.
- [ ] Run the focused tests and confirm missing behavior.
- [ ] Wire provider/factory and progress widget into analysis; cancel download when canceling candidate/refresh. Keep existing Retry analysis and previous draft behavior. Show that initial setup needs Internet but subsequent analysis is on device.
- [ ] Update smoke tool to seed and load a verified temporary model cache rather than model assets.
- [ ] Run model-store, segmentation and room UI/controller tests GREEN, plus existing whole suite.
- [ ] Commit only this task's files after passing verification.

### Task 3: Release, packaging and handoff

**Files:** Modify `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `.gitignore`, `README.md`, `docs/asset-sources.md`, relevant model notices; keep `lib/main.dart` license entries unchanged.

- [ ] Bundle only `assets/models/room_seg_descriptor.json`; add release Internet permission. Ignore model files, /dist/ and /.superpowers/ without deleting them.
- [ ] Update download/offline/setup/provenance notices; retain full upstream LICENSE/NOTICE files and publish them beside both unchanged binaries and descriptor in a new `room-models-v1` release (no replacements/overwrite).
- [ ] Verify all public release downloads against pinned sizes and hashes.
- [ ] Run full `flutter test --no-pub --reporter failures-only`, `flutter analyze`, formatter, production model smoke and Android build. Inspect APK ZIP listing to prove .tflite assets absent.
- [ ] Request one fresh review of the full diff for requirements, cancellation/races, network integrity and packaging; address important findings with RED/GREEN tests.
- [ ] Hand off verified local changes/commit and exact manual push command. Do not push source code on the user's behalf.
