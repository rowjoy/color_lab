# Room Photo Recolor Fast MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reuse Color Lab's current offline masks to provide four independent room colors, a lighting-preserving photo preview, Before/After controls, and PNG share/export.

**Architecture:** Extend the canonical Room draft with four nullable colors, render immutable keyed frames from original RGBA bytes in a temporary isolate, and expose the derived frame through Riverpod. Integrate the color controls and export action into the existing Room mask screen so the established import and manual-refinement flow remains intact.

**Tech Stack:** Flutter 3.41.1, Dart 3.11, Riverpod, `image`, existing D65 LAB color engine, `share_plus`, and the current Room masking module. No new dependency or native configuration.

**Spec:** `docs/superpowers/specs/2026-10-22-room-photo-recolor-fast-mvp-design.md`

## Global Constraints

- Reuse the current MOSAIC masks; do not change/download/rebenchmark models.
- Process and render locally; never upload a photo or add telemetry.
- Four nullable colors are session-only and independent of the illustrated `roomColorProvider`.
- Recompute from immutable `PreparedPhoto.rgbaBytes`; never recolor a preview.
- Unassigned/non-owned pixels remain byte-identical and output alpha is 255.
- Rendering is off the UI isolate; only a frame matching the current photo/mask/color revisions may display or export.
- Export means PNG through the system share sheet; add no gallery/storage permission.
- Preserve Android SDK 24, iOS 13, dependencies, routes, acquisition behavior, and manual-mask semantics.
- Source-only authorization: no native build/install/clean or SDK/pub-cache mutation.
- No Git repository exists; work in place and record verification in the final handoff instead of committing.

## Review Focus

1. An unassigned owner beside an assigned owner remains byte-identical even under radius-2 feathering; Task 2 pins it.
2. Dark, white, and saturated targets produce finite clamped bytes while retaining visible source lightness variation; Task 2 pins it.
3. A late frame after a color or mask change never displays or exports; Tasks 2–4 pin it.
4. Add/Erase/Undo/Restore AI preserve all four colors and increment only the correct revision; Task 1 pins it.
5. Share cancellation/failure leaves photo, masks, colors, and current frame available; Tasks 3–4 pin it.

---

### Task 1: Four-color Room session state

**Files:**

- Create: `lib/features/room_studio/domain/room_layer_colors.dart`
- Modify: `lib/features/room_studio/domain/room_mask_state.dart`
- Modify: `lib/features/room_studio/application/room_mask_controller.dart`
- Create: `test/features/room_studio/domain/room_layer_colors_test.dart`
- Modify: `test/features/room_studio/application/room_mask_controller_test.dart`

**Interfaces:**

- Produces `const RoomLayerColors({RgbColor? wall, RgbColor? ceiling, RgbColor? floor, RgbColor? furniture})`, `colorFor(RoomLayer)`, `withColor(RoomLayer, RgbColor?)`, and `hasAny`.
- Extends `RoomMaskDraft` with `RoomLayerColors colors` and `int colorRevision`.
- Produces `RoomMaskController.setLayerColor(RoomLayer layer, RgbColor? color)` returning `bool` for an effective change.

- [ ] **Step 1: Write failing value and controller tests.** Assert exactly four nullable slots, immutable/equality behavior, no-op assignment, independent revisions, new-photo reset, and color retention through Add, Erase, Undo, and Restore AI.
- [ ] **Step 2: Run RED.** Run `/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain/room_layer_colors_test.dart test/features/room_studio/application/room_mask_controller_test.dart --reporter expanded`; expect missing `RoomLayerColors`, fields, and action.
- [ ] **Step 3: Implement minimal immutable state and transitions.** Update every `RoomMaskDraft` construction to preserve or reset colors according to the spec; do not change `roomColorProvider`.
- [ ] **Step 4: Run GREEN.** Run `/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain test/features/room_studio/application --reporter expanded`; expect exit 0 and `All tests passed!`.

### Task 2: Deterministic LAB renderer and keyed preview provider

**Files:**

- Create: `lib/features/room_studio/recolor/room_recolor_frame.dart`
- Create: `lib/features/room_studio/recolor/room_photo_recolorer.dart`
- Create: `lib/features/room_studio/application/room_recolor_service.dart`
- Create: `lib/features/room_studio/application/room_recolor_provider.dart`
- Create: `test/features/room_studio/recolor/room_photo_recolorer_test.dart`
- Create: `test/features/room_studio/application/room_recolor_provider_test.dart`

**Interfaces:**

- Produces value-equal `RoomRecolorKey(photoId, maskRevision, colorRevision)` and immutable `RoomRecolorFrame(key, width, height, rgbaBytes, pngBytes)`.
- Produces `RoomRecolorFrame recolorRoomPhoto({required RoomRecolorKey key, required PreparedPhoto photo, required MaskBitmap masks, required RoomLayerColors colors})`.
- Produces `RoomRecolorService.render({required RoomRecolorKey key, required PreparedPhoto photo, required MaskBitmap masks, required RoomLayerColors colors}) -> Future<RoomRecolorFrame>` and an `IsolateRoomRecolorService`.
- Produces `FutureProvider<RoomRecolorFrame?> roomRecolorPreviewProvider`, derived from the current draft and overridable in tests.

- [ ] **Step 1: Write failing literal renderer tests.** Hand-pin untouched bytes, one assigned layer, adjacent different owners, inward feather coverage, output alpha, percentile/fallback math, shadows/highlights, saturated targets, dimension rejection, input immutability, and repeat-run determinism.
- [ ] **Step 2: Run renderer RED.** Run the guarded Flutter command for `test/features/room_studio/recolor/room_photo_recolorer_test.dart`; expect missing renderer/frame APIs.
- [ ] **Step 3: Implement the pure renderer.** Use the spec's percentile/lightness formula, existing LAB conversion, ownership-bounded radius-2 alpha, linear-sRGB blending, and `image.encodePng`.
- [ ] **Step 4: Run renderer GREEN.** Rerun that exact focused test; expect exit 0 and `All tests passed!`.
- [ ] **Step 5: Write failing service/provider tests.** Assert rendering occurs off the direct provider path, matching key publication, previous/new key separation, late success/error isolation, and retry after failure.
- [ ] **Step 6: Implement the stateless isolate service and derived provider.** Copy/detach frame bytes and let Riverpod discard superseded provider results; never mutate `RoomMaskDraft` from a render completion.
- [ ] **Step 7: Run Task 2 GREEN.** Run the guarded Flutter command for `test/features/room_studio/recolor/room_photo_recolorer_test.dart`, `test/features/room_studio/application/room_recolor_provider_test.dart`, `test/features/room_studio/segmentation/room_mask_processing_test.dart`, and `test/features/room_studio/presentation/mask_overlay_service_test.dart`; expect exit 0.

### Task 3: Room color editor and Before/After preview

**Files:**

- Create: `lib/features/room_studio/presentation/room_recolor_viewport.dart`
- Create: `lib/features/room_studio/presentation/room_layer_color_controls.dart`
- Modify: `lib/features/room_studio/presentation/room_mask_screen.dart`
- Modify: `lib/features/room_studio/presentation/room_screen.dart`
- Create: `test/features/room_studio/presentation/room_recolor_viewport_test.dart`
- Create: `test/features/room_studio/presentation/room_layer_color_controls_test.dart`
- Modify: `test/features/room_studio/presentation/room_masks_integration_test.dart`

**Interfaces:**

- `RoomRecolorViewport` consumes source preview bytes, the latest keyed frame, and explicit Before/After selection.
- `RoomLayerColorControls` consumes `RoomLayerColors`, selected layer, and selection/assign/reset callbacks; it opens the existing `showMixerColorPicker` from its host.
- The existing `/room/masks` screen remains the route and owns only view-local Before/After and Refine-masks expansion state.

- [ ] **Step 1: Write failing viewport/control tests.** Assert Before uses source, After uses only a current-key frame, loading/error copy retains the last valid view, all four cards show HEX/Not set, reset is immediate, and controls meet 48 dp/semantics requirements.
- [ ] **Step 2: Write failing integration tests.** Import/analyze a photo, assign different Wall/Floor colors through the picker, see After update, switch Before/After, refine/undo/restore without losing colors, and preserve the illustrated provider.
- [ ] **Step 3: Run RED.** Run the guarded Flutter command for the two new presentation tests and `room_masks_integration_test.dart`; expect missing widgets and editor actions.
- [ ] **Step 4: Implement the two focused widgets and integrate them.** Reuse the mixer picker, current design tokens, import flow, and mask controls; remove only the stale “recoloring coming later” copy.
- [ ] **Step 5: Run Task 3 GREEN.** Run `/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation --reporter expanded`; expect the light/dark and 360 dp/2x text cases to exit 0.

### Task 4: Current-frame PNG share and cumulative verification

**Files:**

- Create: `lib/features/room_studio/application/room_image_export_service.dart`
- Modify: `lib/features/room_studio/presentation/room_mask_screen.dart`
- Create: `test/features/room_studio/application/room_image_export_service_test.dart`
- Modify: `test/features/room_studio/presentation/room_masks_integration_test.dart`
- Modify: `README.md`

**Interfaces:**

- Produces `RoomImageExportService.sharePng({required Uint8List pngBytes, required String photoId, required Rect origin}) -> Future<void>` and `roomImageExportServiceProvider`.
- `PlatformRoomImageExportService({RoomShare? share})` passes an in-memory `XFile` named `color-lab-room-<safe-photo-id>.png` with MIME `image/png` to `SharePlus.instance.share`; the injectable `RoomShare` boundary captures real share parameters in unit tests.

- [ ] **Step 1: Write failing export and UI tests.** Assert PNG signature/current bytes, safe deterministic filename, share origin, disabled action for missing/stale/busy frames, and retained state after cancellation/error.
- [ ] **Step 2: Run RED.** Run the guarded Flutter command for `room_image_export_service_test.dart` and `room_masks_integration_test.dart`; expect missing export service/action.
- [ ] **Step 3: Implement the share adapter and guarded button.** Add no file persistence or platform permission; expose failures through accessible UI feedback.
- [ ] **Step 4: Run focused GREEN.** Run `/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio --reporter expanded`; expect exit 0 and `All tests passed!`.
- [ ] **Step 5: Run fresh cumulative verification.** Run guarded `/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter failures-only` and guarded `/Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub`; then run `/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test`. Record exact outputs and any environmental limitation in the handoff.
- [ ] **Step 6: Request one fresh whole-change code review.** Fix Critical/Important findings with RED/GREEN tests; report deferred Minor findings.

