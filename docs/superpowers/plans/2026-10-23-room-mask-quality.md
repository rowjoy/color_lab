# Room Mask Quality Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans (Native), TDD and one final fresh review.

**Goal:** Improve two reproduced masking defects using existing models and make the requested 95% target objectively checkable, without claiming unmeasured accuracy.
**Architecture:** Retain MOSAIC semantic inference and MiDaS depth. Recover spatially supported small foreground depth variation when p05/p95 collapse; clip selected-mask preview alpha to its actual ownership. Add an offline annotation comparison tool with per-layer IoU and explicit missing-coverage failure.
**Tech Stack:** Existing Dart/Flutter, image, on-device models; no dependencies or new models.
**Spec:** User wants better auto masks and 95% results, has opted out of repeated approvals and chosen Native. This is a bounded improvement, NOT certification of 95%: no densely labeled real-room dataset exists. Original photos requested asynchronously. No photo upload, private-photo commit, model replacement, device data changes, or source push.

## Approaches / Global Constraints

- Chosen implementation approach: repair reproducible downstream defects and measure truth-labeled masks. Fast and offline, but cannot recover classes the semantic model never detects.
- A new/fine-tuned semantic model may ultimately be necessary; not selected or downloaded without evaluating annotated examples first.
- Keep clear walls and all non-Wall owners unchanged in the depth fix; never invent Furniture labels from depth.
- Keep inference, recoloring, manual strokes, undo and startup contracts intact. Preview should agree with ownership used by final recoloring.
- Working in the existing approved feature-branch workspace; preserve private temp photos and published Release.

## Review Focus

- Small coherent foreground (<5%) versus isolated depth noise: only supported variation should enable filtering.
- Flat/tilted walls and source/depth geometry: retain all existing regressions.
- Selected overlay must not paint another owner or an erased pixel; inward feather remains soft.
- Global pixel accuracy dominated by background must not pass the 95% gate.
- Missing labels, void pixels, invalid domains and dimensions must not yield invented success.

### Task 1: Small foreground depth protection

**Files:** `lib/features/room_studio/segmentation/room_wall_depth_protection.dart`, its existing test.
**Interface:** Unchanged `protectRoomWallsWithDepth(MaskBitmap, RoomDepthFrame)`.
- [ ] RED tests: 4×4 near patch over flat32×24 wall is excluded; 2×2 supported patch works; isolated depth spikes do not trigger removal.
- [ ] If trimmed span collapses, use the range supported by complete2×2 depth blocks; retain existing plane consensus/thresholds and safe no-op for unsupported variation.
- [ ] GREEN depth/segmentation tests; commit scoped files.

### Task 2: Ownership-faithful preview

**Files:** `lib/features/room_studio/application/mask_overlay_service.dart`, `test/features/room_studio/presentation/mask_overlay_service_test.dart`.
**Interface:** Existing overlay render API unchanged; shared binomial-alpha math unchanged.
- [ ] RED PNG tests: all nonselected labels including erased0 remain alpha0 for radii1/2, selected edge still feathered.
- [ ] Clip encoded alpha to the selected label; update old outward-preview fixture to the new ownership contract.
- [ ] GREEN overlay/recolor/viewport tests; commit scoped files.

### Task 3: Truth-based quality check and evidence

**Files:** `tool/room_mask/quality_metrics.dart`, `tool/verify_room_mask_quality.dart`, `test/tool/room_mask_quality_test.dart`, README.
**Interface:** Pure `evaluateRoomMaskQuality(predicted, truth, width, height)` returns JSON-ready per-class support/IoU/precision/recall/Dice, pixel accuracy, ignored count and a95% per-layer gate. Raw masks use0..4; truth255 means ignored. Missing truth coverage fails the all-four-layer gate.
- [ ] RED hand-derived confusion counts, perfect/empty coverage, ignored255, invalid shapes/domains and high-background false-pass tests.
- [ ] Add CLI reading raw ownership/truth bytes with explicit width/height; nonzero exit if95% per-layer gate is unmet; no prediction-as-truth shortcut.
- [ ] GREEN focused tests; real-model private/reference smoke; full suite, analyze/format and debug build; record actual evidence and unresolved95% validation.
- [ ] One fresh review, fix Important findings with RED/GREEN; commit locally, no push.
