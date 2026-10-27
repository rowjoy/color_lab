# TintAtlas Real-Room Projects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make real-photo Room Studio optional to enter, dependable offline after setup, and durable across interruption through local projects, variants, bounded rendering, and privacy-safe export.

**Architecture:** Keep the existing segmentation/mask/recolor pipeline, but enter model setup only from the real-photo flow. Store each project as immutable revision directories behind an atomically replaced `current` pointer; controllers distinguish the visible draft from the last durable snapshot and reject stale async results.

**Tech Stack:** Flutter, Riverpod, GoRouter, Dart IO, TFLite, `image`, system photo picker/camera, Share Plus, unit/widget/integration tests.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md`

## Global Constraints

- Read the master plan first; its Global Constraints apply verbatim.
- Preserve the pinned model URLs, byte sizes, SHA-256 values, licenses, app-private cache path compatibility, and current mask coordinate system.
- Model download is optional until the user chooses real-photo Room Studio; Illustrated Rooms and every other root remain usable without it.
- Room photos, masks, thumbnails, variants, and metadata are installation-local shared-library data, never game-profile data.
- A project acknowledges an edit only after its revision directory and `current` pointer are durable; failed writes retain the last valid revision and the visible retryable draft.
- Preview/export copy states the processed working resolution and non-calibrated nature; it never claims original-resolution or paint-purchase accuracy.
- System/scoped photo selection remains the default and generated/shared files contain no source EXIF, GPS, or unapproved text chunks.

## Review Focus

- A killed or disk-full save reopens the last acknowledged revision and leaves an orphan revision safe to clean later.
- A partial/corrupt current revision falls back to the newest valid prior revision without deleting evidence or hiding other projects.
- Rapid recolor changes show only the latest key, never a late result from an older photo, mask revision, or color revision.
- Model cancellation, offline retry, and an already verified cache produce truthful progress without restarting a valid download unnecessarily.
- Rename, duplicate, variant, export, and delete disclose their exact storage/photo effects and remain usable at 200% text.

---

### Task 1: On-demand, resumable Room model setup

**Files:**
- Create: `lib/features/room_studio/application/room_model_setup_controller.dart`
- Create: `lib/features/room_studio/presentation/room_model_setup_panel.dart`
- Modify: `lib/features/room_studio/models/room_model_store.dart`
- Modify: `lib/features/room_studio/application/room_model_download_providers.dart`
- Modify: `lib/features/room_studio/presentation/room_screen.dart`
- Modify: `lib/routing/app_router.dart`
- Test: `test/features/room_studio/models/room_model_store_test.dart`
- Test: `test/features/room_studio/application/room_model_setup_controller_test.dart`
- Test: `test/features/room_studio/presentation/room_model_setup_panel_test.dart`

**Interfaces:**
- Consumes: Foundation shell with `/rooms`; existing `roomModelArtifacts`, `RoomModelStore.load()`, and `RoomModelDownloadProgress`.
- Produces: `RoomModelAvailability { notInstalled, checking, downloading, verifying, ready, failed, storageFull, cancelled }`, `RoomModelSetupController.check()`, `download()`, `cancel()`, `retry()`, and `continueWithCachedModels()`.

- [ ] **Step 1: Write RED model-store tests.** Pin the displayed aggregate size to the sum of artifact bytes; assert valid cached files avoid network, `.part` bytes resume with an HTTP range response, servers that reject range restart safely, hash mismatch never promotes, cancellation retains a resumable partial, and low-storage/write failures map to `storageFull` without exposing paths.
- [ ] **Step 2: Run `flutter test --no-pub test/features/room_studio/models/room_model_store_test.dart test/features/room_studio/application/room_model_setup_controller_test.dart --reporter expanded`.** Expected: FAIL on the new state/controller and resume assertions.
- [ ] **Step 3: Implement the setup controller and resumable `.part` contract.** Promote only a size/hash-verified file by atomic rename; keep incompatible cache versions isolated; serialize one download; make Cancel logical immediately and Retry create a fresh operation.
- [ ] **Step 4: Write the Room entry widget tests.** `Try an Illustrated Room` opens without setup, `Use my photo` presents exact size plus Download/Later, offline cached reuse works, and setup failure leaves Back/Illustrated Rooms reachable.
- [ ] **Step 5: Implement `RoomModelSetupPanel` and route integration with localized progress, retry, cancellation, storage, and offline copy.** Do not restore a global bootstrap gate.
- [ ] **Step 6: Run the focused tests plus `flutter test --no-pub test/bootstrap_test.dart test/features/room_studio/presentation/room_model_download_status_test.dart`.** Expected: PASS.
- [ ] **Step 7: Commit.** `git commit -m "feat: make room models an on-demand setup"`.

### Task 2: Versioned Room project aggregate and atomic file repository

**Files:**
- Create: `lib/features/room_studio/domain/room_project.dart`
- Create: `lib/features/room_studio/domain/room_project_repository.dart`
- Create: `lib/features/room_studio/data/room_project_codec.dart`
- Create: `lib/data/files/file_room_project_repository.dart`
- Create: `test/support/in_memory_room_project_repository.dart`
- Modify: `lib/data/schema/schema_registry.dart`
- Modify: `docs/release/schema-registry.md`
- Modify: `lib/data/storage/local_data_manager.dart`
- Modify: `test/data/storage/local_data_manager_test.dart`
- Test: `test/features/room_studio/domain/room_project_test.dart`
- Test: `test/features/room_studio/data/room_project_codec_test.dart`
- Test: `test/data/files/file_room_project_repository_test.dart`

**Interfaces:**
- Produces `RoomProjectSummary`, `RoomColorVariant`, and `RoomProjectSnapshot` containing project/photo IDs, prepared working-photo PNG, dimensions, AI/current mask bytes, layer colors, mask/color revisions, active variant, thumbnail PNG, created/updated UTC timestamps, and schema version. `RoomProjectReadResult` carries the chosen snapshot plus an optional typed recovery warning when a corrupt current revision fell back. Explicit intent is added by the dependent Manual Mask plan without changing these identities.
- Registers schema ID `room-projects`, `StorageBackend.fileTree`, storage name `room_projects`, version `1`, and `LocalDataScope.sharedLibrary`; the directory lives beneath the preserved private `color_lab` root.
- Registers `LocalDataCategory.roomProjects` preview/delete through the repository root; preview counts project revisions/bytes, delete never touches user-exported images, and a partial failure remains retryable.
- Produces:
  ```dart
  abstract interface class RoomProjectRepository {
    Future<RepositorySnapshot<RoomProjectSummary>> listSnapshot();
    Future<RoomProjectReadResult?> read(String projectId);
    Future<RoomProjectSnapshot> save(
      RoomProjectSnapshot snapshot, {
      required int expectedRevision,
    });
    Future<void> delete(String projectId);
    Future<void> close();
  }
  ```

- [ ] **Step 1: Write RED codec tests.** Require schema `1`, canonical UTC/HEX, finite dimensions, aligned mask byte lengths, unique variant IDs, strict relative asset names, and rejection of traversal/unknown required data without deleting the record.
- [ ] **Step 2: Write RED repository failure tests.** Cover first save, compare-and-swap conflict, serialized concurrent saves, process interruption before/after pointer replace, corrupt current revision fallback, corrupt one-project isolation, orphan cleanup, delete failure, and close during a pending save.
- [ ] **Step 3: Run `flutter test --no-pub test/features/room_studio/domain/room_project_test.dart test/features/room_studio/data/room_project_codec_test.dart test/data/files/file_room_project_repository_test.dart --reporter expanded`.** Expected: FAIL because the project/repository types do not exist.
- [ ] **Step 4: Implement immutable `projects/<id>/revisions/<revision>/` directories and a checksummed `current` pointer.** Write and fsync assets/manifest in a staging sibling, atomically rename the revision, then atomically replace the pointer; never overwrite a valid revision in place.
- [ ] **Step 5: Implement fallback reads and quarantine metadata.** `list()` returns healthy summaries even when another record is malformed; `read()` walks prior revisions newest-first and reports recovery through a typed warning consumed by the library.
- [ ] **Step 6: Run the focused repository suite twice, including a reopen between writes.** Expected: PASS with byte-identical photo/mask reload.
- [ ] **Step 7: Commit.** `git commit -m "feat: add durable room project storage"`.

### Task 3: Project session, autosave, and recoverable manual fallback

**Files:**
- Create: `lib/features/room_studio/application/room_projects_providers.dart`
- Create: `lib/features/room_studio/application/room_project_session_controller.dart`
- Modify: `lib/features/room_studio/application/room_mask_controller.dart`
- Modify: `lib/features/room_studio/domain/room_mask_state.dart`
- Modify: `lib/features/room_studio/segmentation/room_segmentation_service.dart`
- Test: `test/features/room_studio/application/room_project_session_controller_test.dart`
- Test: `test/features/room_studio/application/room_mask_controller_test.dart`
- Test: `test/features/room_studio/presentation/room_masks_integration_test.dart`

**Interfaces:**
- Consumes: `RoomProjectRepository` from Task 2 and the existing `RoomMaskDraft`/segmentation result.
- Produces: `RoomProjectSession { durable, visible, saveStatus, saveError }`, `createFromAnalysis()`, `createManualFallback()`, `commitVisibleDraft()`, `retrySave()`, `openProject()`, and `closeProject()`.

- [ ] **Step 1: Write RED session tests.** A successful analysis creates aligned AI/current masks; model/processing failure can create all-unowned masks at exact working dimensions; autosave starts only after a committed stroke/color/variant action; incomplete pointer strokes and transient animation never persist.
- [ ] **Step 2: Add failure/concurrency tests.** Disk failure leaves `visible` editable and `durable` unchanged with Retry; stale expected revision reports conflict; disposal waits for or safely abandons a serialized write; process reopen returns the last acknowledged state.
- [ ] **Step 3: Run `flutter test --no-pub test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart --reporter expanded`.** Expected: FAIL.
- [ ] **Step 4: Implement repository providers and project session controller.** Keep `RoomMaskController` focused on editing; route durable commits through the session controller and expose save state without blocking brush feedback.
- [ ] **Step 5: Implement `createManualFallback()` for analysis failures.** Preserve the prepared photo, use zero/unowned labels for every pixel, set an honest manual-mode notice, and retain Retry Analysis as a separate action.
- [ ] **Step 6: Run focused tests and background/reopen integration tests.** Expected: PASS; a failed save never presents the draft as saved.
- [ ] **Step 7: Commit.** `git commit -m "feat: autosave room projects with manual fallback"`.

### Task 4: Room project library and storage-safe actions

**Files:**
- Create: `lib/features/room_studio/presentation/room_projects_screen.dart`
- Create: `lib/features/room_studio/presentation/room_project_actions.dart`
- Create: `lib/features/room_studio/presentation/room_project_storage_notice.dart`
- Modify: `lib/features/room_studio/presentation/room_screen.dart`
- Modify: `lib/features/my_work/presentation/my_work_screen.dart`
- Modify: `lib/routing/app_router.dart`
- Test: `test/features/room_studio/presentation/room_projects_screen_test.dart`
- Test: `test/features/room_studio/presentation/room_project_actions_test.dart`
- Test: `test/routing/app_router_test.dart`

**Interfaces:**
- Consumes: `RoomProjectRepository.listSnapshot/read/save/delete` and the Foundation My Work route.
- Produces: `/rooms/projects`, `/rooms/project/:projectId`; Continue, Open, Rename, Duplicate, Compare, Delete; duplicated projects share no mutable files and variants reuse one immutable photo/mask base inside their own project.

- [ ] **Step 1: Write RED library/action tests.** Sort by updated time with stable ID tiebreak; missing/corrupt thumbnail uses a labeled fallback; rename keeps IDs/assets; duplicate gets new project/photo-independent ownership; delete requires a consequence summary and removes only the selected project.
- [ ] **Step 2: Add layout/semantics tests at 320×568, 568×320, 840 and 1200 widths with 200% text.** Primary actions remain reachable; cards expose name, date, save warning, and button semantics without relying on thumbnail color.
- [ ] **Step 3: Run `flutter test --no-pub test/features/room_studio/presentation/room_projects_screen_test.dart test/features/room_studio/presentation/room_project_actions_test.dart test/routing/app_router_test.dart --reporter expanded`.** Expected: FAIL.
- [ ] **Step 4: Implement library, actions, routes, and My Work section.** Require explicit confirmation for deletion, state that the local working photo/masks/variants are removed, and do not delete external exports.
- [ ] **Step 5: Run focused tests and restart navigation restoration tests.** Expected: PASS.
- [ ] **Step 6: Commit.** `git commit -m "feat: add the room project library"`.

### Task 5: Lightweight A/B color variants and safe comparison

**Files:**
- Create: `lib/features/room_studio/application/room_variant_controller.dart`
- Create: `lib/features/room_studio/presentation/room_variant_controls.dart`
- Modify: `lib/features/room_studio/domain/room_project.dart`
- Modify: `lib/features/room_studio/presentation/room_mask_screen.dart`
- Test: `test/features/room_studio/application/room_variant_controller_test.dart`
- Test: `test/features/room_studio/presentation/room_variant_controls_test.dart`

**Interfaces:**
- Produces: `createVariant(String name)`, `renameVariant(String id, String name)`, `selectVariant(String id)`, `updateVariantColors(RoomLayerColors colors)`, `deleteVariant(String id)`, `pinComparisonBaseline(String id)`, and `clearComparison()`; variants contain IDs/names/color snapshots only.

- [ ] **Step 1: Write RED domain/controller tests.** A/B creation duplicates only `RoomLayerColors`, never photo/masks; IDs/names are unique and bounded; deleting the active/baseline variant selects a deterministic survivor; comparison never mutates either side.
- [ ] **Step 2: Write RED interaction tests.** A/B toggle and draggable comparison remain operable through labeled buttons/keyboard, restore after reopen, and fit compact landscape/200% text.
- [ ] **Step 3: Run the focused variant tests.** Expected: FAIL.
- [ ] **Step 4: Implement variants and comparison as project metadata revisions.** Recolor keys include selected variant/color revision; temporary original view is non-destructive.
- [ ] **Step 5: Run focused tests plus the project repository reopen suite.** Expected: PASS without duplicate photo/mask files per variant.
- [ ] **Step 6: Commit.** `git commit -m "feat: add room color variants and comparison"`.

### Task 6: Latest-only recolor scheduling and lifecycle safety

**Files:**
- Create: `lib/features/room_studio/application/room_recolor_scheduler.dart`
- Modify: `lib/features/room_studio/application/room_recolor_provider.dart`
- Modify: `lib/features/room_studio/application/room_recolor_service.dart`
- Modify: `lib/features/room_studio/recolor/room_recolor_frame.dart`
- Test: `test/features/room_studio/application/room_recolor_scheduler_test.dart`
- Test: `test/features/room_studio/application/room_recolor_provider_test.dart`

**Interfaces:**
- Produces: `RoomRecolorScheduler.renderLatest(RoomRecolorRequest)`, `cancelProject(String projectId)`, and `close()`; request/result keys contain project ID, photo ID, mask revision, color revision, and variant ID.

- [ ] **Step 1: Write RED scheduler tests with controlled workers.** At most one active plus one latest pending request exists; middle requests are superseded; stale completion/error never replaces current preview; timeout replaces the worker; background/dispose cancels publication and frees frames.
- [ ] **Step 2: Run `flutter test --no-pub test/features/room_studio/application/room_recolor_scheduler_test.dart test/features/room_studio/application/room_recolor_provider_test.dart --reporter expanded`.** Expected: FAIL.
- [ ] **Step 3: Implement the serialized latest-only scheduler around the existing recolorer.** Dispose superseded `RoomRecolorFrame` resources and check the complete key immediately before state publication.
- [ ] **Step 4: Add a stress test of 100 rapid color/mask changes and lifecycle background/foreground.** Assert bounded active work, final key equality, no post-dispose update, and a usable retry after timeout.
- [ ] **Step 5: Run scheduler, recolor, viewport, and integration suites.** Expected: PASS.
- [ ] **Step 6: Commit.** `git commit -m "perf: bound room recolor work"`.

### Task 7: Privacy-safe Room export and honest failure copy

**Files:**
- Create: `lib/features/room_studio/application/room_export_metadata_verifier.dart`
- Modify: `lib/features/room_studio/application/room_image_export_service.dart`
- Modify: `lib/features/room_studio/application/room_gallery_writer.dart`
- Modify: `lib/features/room_studio/presentation/room_mask_dialogs.dart`
- Modify: `lib/features/picker/application/photo_picker_service.dart`
- Test: `test/features/room_studio/application/room_image_export_service_test.dart`
- Test: `test/features/room_studio/application/room_gallery_writer_test.dart`
- Test: `test/features/room_studio/application/room_export_metadata_verifier_test.dart`
- Test: `test/features/picker/photo_picker_service_test.dart`

**Interfaces:**
- Consumes: the current rendered working-resolution PNG and Foundation `AppIdentity`/localizations.
- Produces: `savePng(...)`, `sharePng(...)`, and `RoomExportMetadataVerifier.verify(Uint8List)` rejecting EXIF/GPS/XMP and unapproved PNG text chunks before platform handoff.

- [ ] **Step 1: Write RED metadata tests using source JPEGs with orientation/GPS/EXIF and PNGs with text/XMP chunks.** Picker requests no full metadata; prepared pixels are correctly oriented; generated/shared output contains only allowed PNG chunks and uses `tintatlas-room-<safe-id>.png`.
- [ ] **Step 2: Write RED error-copy tests.** Permission, unavailable camera, unsupported format, oversized input, processing, model, storage, save, and share failures each map to one localized recovery action without paths/stack traces.
- [ ] **Step 3: Run the focused export/picker tests.** Expected: FAIL.
- [ ] **Step 4: Implement verified clean-PNG export, Save and Share.** Show pixel dimensions and the exact preview limitation covering display calibration, camera processing, lighting, wall texture, finish, surrounding colors, and real-paint variation.
- [ ] **Step 5: Run export tests on Android and the active iOS gate; inspect one saved and one shared file with the verifier.** Expected: PASS, with no broad media permission introduced.
- [ ] **Step 6: Commit.** `git commit -m "feat: make room export private and transparent"`.

### Task 8: Real-room milestone verification

**Files:**
- Modify: `docs/release/verification-ledger.md`
- Test: `test/features/room_studio/real_room_project_integration_test.dart`

**Interfaces:**
- Produces the Plan 02 evidence record consumed by Manual Masks and the core release plan.

- [ ] **Step 1: Add an end-to-end RED-to-green scenario.** From a fresh offline install, Illustrated Rooms opens; real-photo setup can be deferred; cached setup imports a photo; failed AI creates a manual draft; edit/variant/autosave/process reopen/compare/export/delete preserve exact ownership.
- [ ] **Step 2: Run `flutter test --no-pub test/features/room_studio test/features/picker test/data/files --reporter expanded`.** Expected: PASS.
- [ ] **Step 3: Run `dart format --output=none --set-exit-if-changed lib test tool`, `flutter analyze --no-pub`, the full test suite, and Android debug build.** Expected: zero new issues and all tests/builds pass under the Foundation gate.
- [ ] **Step 4: Record exact test counts, working/export dimensions, model offline/resume evidence, failure injection, storage ownership, and known limitations in the ledger; obtain fresh review.**
- [ ] **Step 5: Commit.** `git commit -m "test: verify durable real-room projects"`.

## Exit Gate

Real-photo setup is optional and resumable; projects survive interruption and corrupt-revision recovery; manual fallback, library actions, variants, latest-only recolor, Save/Share, metadata stripping, and preview disclosures pass focused and full verification. The next plan may change mask command/history schemas only after these repository fixtures are frozen.
