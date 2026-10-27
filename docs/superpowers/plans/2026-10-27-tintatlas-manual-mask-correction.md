# TintAtlas Manual Mask Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Room mask review precise, reversible, durable, and respectful of explicit user corrections without depending on unproven smart proposals.

**Architecture:** Add a separate per-pixel intent bitmap beside AI and current ownership, then replace undo-only deltas with bounded before/after commands that cover both ownership and intent. Keep input/render coordinates source-aligned, commit only completed strokes, and persist every acknowledged command through the Room project repository.

**Tech Stack:** Flutter custom painting/gestures, Riverpod, typed byte bitmaps, Room project file repository, unit/golden/widget/integration tests.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md`

## Global Constraints

- Read the master and Real-Room Projects plans first; their Global Constraints and frozen repository identities apply.
- Manual correction ships whether or not conditional smart assistance is validated; no smart button, confidence claim, or algorithm enters this plan.
- Ownership remains exclusive: every pixel is unowned or owned by exactly one of the four existing `RoomLayer` values.
- Intent encoding is `0 = untouched`, `1 = explicitly unowned`, and `2..5 = explicit owner for RoomLayer indices 0..3`; unknown values are invalid.
- AI refresh/model upgrade may update untouched pixels only; it never silently changes an explicit user intent pixel.
- History is bounded to 20 commands or 16 MiB, whichever is reached first; evict oldest complete commands only.
- Brush feedback target is under 100 ms on named supported devices; final thresholds are frozen only after baseline measurement and recorded approval.

## Review Focus

- A stroke crossing an image edge, zoom boundary, or pointer cancellation changes only in-bounds pixels and never commits a partial gesture.
- Undo/Redo after autosave, process restart, and history eviction returns exact ownership and intent bytes without merging commands.
- Re-analysis with a changed AI result preserves explicit add/erase choices, including choices that happen to equal the old AI result.
- Pan, zoom, magnifier, overlay, original/recolored switch, and high-DPI input use one invertible source-coordinate transform.
- Missing surfaces, empty masks, all-owned masks, and corrupt intent/history data show honest recovery instead of a crash or misleading percentage.

---

### Task 1: Explicit user-intent bitmap and project schema v2

**Files:**
- Create: `lib/features/room_studio/domain/mask_intent_bitmap.dart`
- Modify: `lib/features/room_studio/domain/room_project.dart`
- Modify: `lib/features/room_studio/data/room_project_codec.dart`
- Modify: `lib/data/files/file_room_project_repository.dart`
- Modify: `lib/data/schema/schema_registry.dart`
- Modify: `docs/release/schema-registry.md`
- Test: `test/features/room_studio/domain/mask_intent_bitmap_test.dart`
- Test: `test/features/room_studio/data/room_project_codec_test.dart`
- Test: `test/data/files/file_room_project_repository_test.dart`

**Interfaces:**
- Consumes: Plan 02 `RoomProjectSnapshot` and aligned `MaskBitmap` dimensions.
- Produces:
  ```dart
  final class MaskIntentBitmap {
    factory MaskIntentBitmap.untouched({required int width, required int height});
    factory MaskIntentBitmap.fromBytes({
      required int width,
      required int height,
      required Uint8List bytes,
    });
    int intentAt(int index);
    MaskIntentBitmap apply(Uint32List indices, Uint8List intents);
  }

  MaskBitmap mergeAiWithIntent({
    required MaskBitmap refreshedAi,
    required MaskIntentBitmap intent,
  });
  ```
- Project schema `2` adds required `intent.bin`; schema `1` migrates with an all-zero bitmap and preserves photo, masks, colors, revisions, variants, timestamps, and visible output exactly.
- Updates the existing `room-projects` file-tree descriptor from version 1 to version 2 without changing its storage name or ownership scope.

- [ ] **Step 1: Write RED bitmap tests.** Enforce positive aligned dimensions, immutable copied bytes, values 0–5 only, sorted unique in-bounds updates, explicit owner decoding, and explicit unowned decoding.
- [ ] **Step 2: Write RED migration/merge tests.** A v1 fixture becomes schema 2 with untouched intent and byte-identical appearance; refreshed AI changes only intent 0; intents 1–5 win even when current ownership previously matched AI by coincidence; malformed intent quarantines only that revision.
- [ ] **Step 3: Run `flutter test --no-pub test/features/room_studio/domain/mask_intent_bitmap_test.dart test/features/room_studio/data/room_project_codec_test.dart test/data/files/file_room_project_repository_test.dart --reporter expanded`.** Expected: FAIL.
- [ ] **Step 4: Implement `MaskIntentBitmap`, merge logic, and explicit v1→v2 codec migration.** Never infer intent by comparing old AI/current masks.
- [ ] **Step 5: Run the focused migration/reopen tests twice.** Expected: PASS with schema-1 fixtures retained and durable schema-2 rewrite.
- [ ] **Step 6: Commit.** `git commit -m "feat: persist explicit room mask intent"`.

### Task 2: Exact bounded Undo/Redo commands

**Files:**
- Create: `lib/features/room_studio/domain/mask_edit_command.dart`
- Create: `lib/features/room_studio/domain/mask_edit_history.dart`
- Modify: `lib/features/room_studio/domain/mask_undo.dart` (temporary deprecated adapter, then remove references)
- Modify: `lib/features/room_studio/domain/room_mask_state.dart`
- Modify: `lib/features/room_studio/domain/room_project.dart`
- Modify: `lib/features/room_studio/data/room_project_codec.dart`
- Test: `test/features/room_studio/domain/mask_edit_command_test.dart`
- Test: `test/features/room_studio/domain/mask_edit_history_test.dart`
- Modify test: `test/features/room_studio/domain/mask_undo_test.dart`

**Interfaces:**
- Produces `MaskEditCommand(width, height, indices, beforeLabels, afterLabels, beforeIntent, afterIntent)` and `MaskEditResult(masks, intent)`.
- Produces `MaskEditHistory { undoStack, redoStack, byteLength, canUndo, canRedo }` with `push()`, `undo()`, and `redo()`; a new committed edit clears redo, while Undo/Redo never coalesce or recompute pixels.

- [ ] **Step 1: Write RED command tests.** Reject empty, unsorted, duplicate, out-of-range, length-mismatched, invalid label/intent deltas; applying forward/backward yields exact bytes; command byte size includes every typed array.
- [ ] **Step 2: Write RED history tests.** Verify 20-command and 16 MiB eviction, redo invalidation after a new edit, no-op rejection, exact multi-layer restoration, and serialized reopen preserving both stacks.
- [ ] **Step 3: Run `flutter test --no-pub test/features/room_studio/domain/mask_edit_command_test.dart test/features/room_studio/domain/mask_edit_history_test.dart --reporter expanded`.** Expected: FAIL.
- [ ] **Step 4: Implement immutable commands/history and schema-2 history encoding.** Remove live references to `MaskUndoHistory`; keep only a decode adapter until all v1 in-memory tests migrate.
- [ ] **Step 5: Run domain, project codec, and repository reopen suites.** Expected: PASS and history remains within both bounds.
- [ ] **Step 6: Commit.** `git commit -m "feat: add exact room mask undo and redo"`.

### Task 3: Intent-aware stroke commits and durable controller integration

**Files:**
- Modify: `lib/features/room_studio/application/room_mask_controller.dart`
- Modify: `lib/features/room_studio/domain/mask_stroke.dart`
- Modify: `lib/features/room_studio/domain/room_mask_state.dart`
- Modify: `lib/features/room_studio/application/room_project_session_controller.dart`
- Modify: `lib/features/room_studio/refine/mask_refinement.dart`
- Modify: `lib/features/room_studio/refine/mask_refinement_service.dart`
- Test: `test/features/room_studio/application/room_mask_controller_test.dart`
- Test: `test/features/room_studio/refine/mask_refinement_test.dart`
- Test: `test/features/room_studio/manual_mask_durability_integration_test.dart`

**Interfaces:**
- Consumes: `MaskIntentBitmap`, `MaskEditCommand`, `MaskEditHistory`, and Plan 02 `RoomProjectSessionController.commitVisibleDraft()`.
- Produces: `beginStroke(Offset sourcePoint)`, `extendStroke(Offset sourcePoint)`, `commitStroke()`, `cancelStroke()`, `undo()`, `redo()`, and `refreshAiMasks(MaskBitmap refreshedAi)`.

- [ ] **Step 1: Write RED controller tests.** Add writes selected-owner labels and intent 2–5; Erase writes label 0 and intent 1; Move changes no pixels; a stroke is one command/save; cancellation/second pointer/disposal changes zero durable pixels; Undo/Redo each cause exactly one serialized autosave.
- [ ] **Step 2: Add refresh/refinement RED tests.** Existing depth/exclusive/spatial protections remain unchanged; refinement modifies untouched AI candidates but never explicit intent; mismatched dimensions and stale operation IDs are rejected.
- [ ] **Step 3: Run `flutter test --no-pub test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/refine/mask_refinement_test.dart test/features/room_studio/manual_mask_durability_integration_test.dart --reporter expanded`.** Expected: FAIL.
- [ ] **Step 4: Implement intent-aware stroke deltas and durable commit sequencing.** Compute before/after arrays in the worker, publish only a complete current-selection result, push one command, then autosave without delaying visible brush feedback.
- [ ] **Step 5: Implement re-analysis merge using `mergeAiWithIntent`; preserve the original AI baseline separately for honest comparison.**
- [ ] **Step 6: Run focused tests plus segmentation depth/multi-wall regressions.** Expected: PASS.
- [ ] **Step 7: Commit.** `git commit -m "feat: protect durable manual mask corrections"`.

### Task 4: Guided Check Masks review flow

**Files:**
- Create: `lib/features/room_studio/presentation/room_mask_review_panel.dart`
- Create: `lib/features/room_studio/presentation/room_mask_surface_status.dart`
- Modify: `lib/features/room_studio/presentation/room_mask_screen.dart`
- Modify: `lib/features/room_studio/presentation/room_layer_color_controls.dart`
- Modify: `lib/features/room_studio/application/mask_overlay_service.dart`
- Test: `test/features/room_studio/presentation/room_mask_review_panel_test.dart`
- Test: `test/features/room_studio/presentation/room_masks_integration_test.dart`
- Modify test: `test/features/room_studio/presentation/mask_overlay_service_test.dart`

**Interfaces:**
- Produces a deterministic review sequence over all `RoomLayer.values`, `selectReviewLayer(RoomLayer)`, `markLayerChecked(RoomLayer)`, original/recolored/overlay views, and statuses `notReviewed`, `absent`, `hasCoverage`, `reviewed`.
- Coverage is labeled only as the percentage of working-image pixels currently assigned to the layer; it is never called confidence, quality, or accuracy.

- [ ] **Step 1: Write RED review tests.** Every surface is reachable; zero-pixel surfaces can be marked Absent; original/recolored switch preserves edits; changing layer never reassigns pixels; completion requires each surface reviewed or absent and remains reversible.
- [ ] **Step 2: Add semantics/non-color tests.** Each layer has text plus pattern/outline identity; overlay state is announced; coverage labels include numerator context; the full flow works by buttons/keyboard without tapping hue-only canvas areas.
- [ ] **Step 3: Run the focused review/integration tests.** Expected: FAIL.
- [ ] **Step 4: Implement the review panel and statuses using existing exclusive labels.** Keep edit controls disabled while a committed operation is busy, but leave navigation/Cancel available.
- [ ] **Step 5: Run tests at compact landscape, expanded width, RTL, dark/high-contrast, and 200% text.** Expected: PASS with no overflow or hidden Done action.
- [ ] **Step 6: Commit.** `git commit -m "feat: add guided room mask review"`.

### Task 5: Precision brush, source-aligned magnifier, and accessible alternatives

**Files:**
- Create: `lib/features/room_studio/presentation/room_mask_magnifier.dart`
- Create: `lib/features/room_studio/presentation/room_mask_region_navigator.dart`
- Modify: `lib/features/room_studio/presentation/room_mask_viewport.dart`
- Modify: `lib/features/room_studio/presentation/room_mask_fullscreen_editor.dart`
- Modify: `lib/features/room_studio/domain/room_mask_state.dart`
- Test: `test/features/room_studio/presentation/room_mask_magnifier_test.dart`
- Modify test: `test/features/room_studio/presentation/room_mask_viewport_test.dart`
- Test: `test/features/room_studio/presentation/room_mask_region_navigator_test.dart`

**Interfaces:**
- Produces brush fractions `0.005..0.20`, a screen-space outline computed from source radius and current transform, magnifier center/footprint from the identical source point, plus keyboard/semantics actions to nudge cursor, Add, Erase, Undo, Redo, change layer, zoom, and pan.

- [ ] **Step 1: Write RED transform tests across contain letterboxing, device-pixel ratios, rotations, pan/zoom, and resize.** Screen→source→screen round-trip stays within 0.5 logical px; outside-letterbox input is rejected; brush and magnifier sample identical source pixels.
- [ ] **Step 2: Write RED gesture tests.** One pointer paints, two pointers transform without painting, pointer cancel commits nothing, smaller high-zoom brush remains visible, and cursor/outline cannot leave source bounds.
- [ ] **Step 3: Write RED accessible-control tests.** A keyboard/screen-reader user can select a layer, position cursor, add/erase, inspect state, undo/redo, and finish without drag gestures.
- [ ] **Step 4: Run magnifier/viewport/navigator tests.** Expected: FAIL.
- [ ] **Step 5: Implement the single source transform, magnifier, outline, fine brush range, and alternative controls.** Never maintain a second display-only coordinate map.
- [ ] **Step 6: Run tests at 320×568, 568×320, fold/split widths, keyboard inset, RTL, and 200% text.** Expected: PASS.
- [ ] **Step 7: Commit.** `git commit -m "feat: improve room mask precision controls"`.

### Task 6: Manual-mask performance and recovery gate

**Files:**
- Create: `tool/room_recolor/manual_mask_benchmark.dart`
- Create: `test/tool/room_recolor/manual_mask_benchmark_test.dart`
- Modify: `docs/release/verification-ledger.md`
- Modify: `docs/release/support-matrix.md`
- Test: `test/features/room_studio/manual_mask_recovery_integration_test.dart`

**Interfaces:**
- Produces named-device measurements for pointer-event-to-visible-brush feedback, command commit, autosave acknowledgment, peak history bytes, and reopen recovery; no smart-proposal metric is mixed into this gate.

- [ ] **Step 1: Write benchmark harness tests.** Fixed synthetic strokes produce deterministic command counts/checksums; timing clock and device metadata are injectable; unsupported/simulator evidence is labeled non-release evidence.
- [ ] **Step 2: Run the harness on named minimum and representative Android devices, and on iPhone/iPad when their gate is active.** Record p50/p95 feedback and memory, then freeze an achievable launch gate with product-owner approval; the target should remain under 100 ms where evidence supports it.
- [ ] **Step 3: Add recovery tests for background kill after visible stroke/before save, failed save Retry, corrupt newest revision, history eviction, model refresh, and reorientation mid-stroke.** Expected: last acknowledged state reopens and explicit intent is unchanged.
- [ ] **Step 4: Run `flutter test --no-pub test/features/room_studio test/tool/room_recolor --reporter expanded`, format, analyze, full tests, and Android debug build.** Expected: PASS with no depth/exclusive/multi-wall regression.
- [ ] **Step 5: Record exact commands/counts/devices/gates and obtain fresh review.** Do not claim smart correction or mask accuracy.
- [ ] **Step 6: Commit.** `git commit -m "test: verify dependable manual mask correction"`.

## Exit Gate

Every manual edit is a single exact Undo/Redo command, explicit intent survives refresh and restart, review covers all/absent surfaces with honest labels, precision and non-gesture controls share source coordinates, history/memory are bounded, and the approved manual feedback/recovery gates pass. Smart proposal UI remains absent unless the separate conditional plan later passes its external evidence gate.
