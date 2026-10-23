# Room Studio Offline Photo Recoloring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user take or choose a room photo, assign independent Wall, Ceiling, Floor and Furniture colors, and view an offline lighting-preserving LAB preview through quality-gated automatic masks and an accessible Before/After editor.

**Architecture:** Keep `roomMaskProvider` and `RoomMaskDraft` as the single retained Room session, adding protected evidence, four nullable assignments, independent revisions and derived preview state. A sequential hybrid analysis service wraps the existing MOSAIC worker plus a selected independent protection worker and pure edge fusion; a separate latest-only worker renders every preview from the immutable prepared source. The existing mask viewport remains the diagnostic refinement surface while a new comparison viewport owns recolored/raw-image display.

**Tech Stack:** Existing Flutter 3.41.1 / Dart 3.11, Riverpod, go_router, `image`, `tflite_flutter` 0.12.1 and current shared color/photo infrastructure. No backend, runtime download, project database or new native runtime is planned; a candidate is promoted only if it is redistribution-permitted, works through the existing TFLite runtime and passes the frozen gate.

**Spec:** `docs/superpowers/specs/2026-10-22-room-photo-recolor-design.md`, approved by the user on 2026-10-22.

## Global Constraints

- Process photos, masks and previews entirely offline. No runtime model download, photo upload, telemetry upload or cloud fallback.
- Four exclusive editable layers remain Wall, Ceiling, Floor and Furniture. Each has one nullable color; null and all unselected pixels remain byte-identical to the prepared source.
- Protect people, windows, doors and wall decoration. Automatic protection wins after smoothing; a deliberate Add stroke overrides it only at reclaimed pixels.
- Recompute every result from the immutable oriented/opaque prepared photo, never from a recolored frame. Working images retain the current 1600-pixel long-edge maximum and existing 24 MiB acquisition, 32 MiB processing, 24-million decoded-pixel and 16,384-axis limits.
- Exact progress copy is **Preparing photo**, **Finding room surfaces**, **Protecting objects**, **Refining edges**, **Building preview**. Emit stages only on real work entry, show no fake percentage, and add **Still working locally...** after five seconds.
- The composite key is `(photoId, maskRevision, colorRevision, algorithmVersion)`. A stale progress event, result, error or decoded image never mutates newer state.
- Effective color changes increment only `colorRevision`; accepted mask changes increment only `maskRevision`. View state changes increment neither. Color changes cannot invalidate an otherwise valid in-flight mask edit.
- Preview rendering has one active request and one replaceable latest request, one retained valid frame and no unbounded queue.
- Preserve the previous committed draft through candidate analysis. Commit replacement only after complete analysis and a validated initial RGBA frame; cancellation/failure keeps the old session.
- Session-only scope: no saved room project, color undo stack, suggestion engine, export/share, full-resolution source or automatic History/Palette write.
- Keep the illustrated Room study and `roomColorProvider` independent. **Use in Room** targets the photo editor, selected layer or pending Wall default.
- Keep Android minimum SDK 24 and iOS 13. Do not silently alter platform floors, permissions or native packaging.
- English UI; existing tokens/shared controls; 360 dp, 2x text, light/dark, reduced motion, visible focus, spoken state/value labels and at least 48 dp actions.
- Current authorization is source-only: no APK/native build, install, clean, data clearing, SDK/pub-cache patch or compiler bypass. Use `tool/deny-native-compilers.sb` for every Flutter test/analyze/preview run and direct `dartvm` wrappers for real-model smoke.
- No Git repository exists. Work in place, preserve unrelated/user changes, do not initialize Git/worktrees, and append task evidence to `docs/superpowers/plans/2026-10-22-room-photo-recolor-progress.md` instead of commits.
- Task 1 needs 24 redistribution-permitted photos plus two genuine independent human annotations and adjudication. Missing human/provenance evidence is `BLOCKED/PENDING EVIDENCE`, never generated/model-derived ground truth.
- Task 2 is a hard go/no-go. Tasks 3–10 do not begin unless the frozen report says `PASS`; failure preserves the completed MOSAIC auto/manual mask module.
- Physical Android/iPhone performance and native accessibility are Task 11 and require separate explicit authorization. Until then, five seconds remains an unverified target, not a marketing claim.

## Review Focus

1. A person labeled Furniture by primary MOSAIC but protected at 255 must lose automatic ownership and remain source-identical after recolor; Task 4 pins this with a literal fusion/render test.
2. Adjacent Wall/Furniture/Wall pixels with different colors and fractional edge coverage must keep total weight at most one, remain ownership-bounded and render identically regardless of layer order; Tasks 4–5 pin it.
3. A manual Add over one protected pixel must set effective protection to zero only there, leaving neighboring protected pixels untouched; Tasks 4 and 7 pin fusion plus controller behavior.
4. Tiny/no-interior layers, `L*` near 0/100 and saturated near-gamut targets must use the exact floor-percentile fallback and finite clamp without changing zero-weight pixels; Task 5 pins it.
5. An old render success, old render error and stale decoded image arriving after newer color, mask and algorithm keys must change neither current frame nor status; Tasks 6–8 pin service, controller and viewport boundaries.

---

## Ownership and execution order

Tasks 1–2 are an isolated feasibility phase. Task 1 freezes data and scoring before any candidate output is viewed; Task 2 freezes the current production baseline, evaluates independently licensed TFLite candidates, records human review and publishes PASS/FAIL/PENDING. A PASS is the only input that authorizes Task 3.

After PASS, Task 3 defines immutable state, Task 4 promotes the chosen protector and implements fusion, Task 5 promotes the verified LAB evaluator, Task 6 adds bounded services, Task 7 integrates acquisition/controller lifecycle, Task 8 builds the editor, Task 9 connects color handoff/routing, and Task 10 performs cumulative source delivery. Task 11 stays closed until device/build authorization.

| Owner | Files and responsibility |
| --- | --- |
| Task 1 | `test/fixtures/room_recolor/v1/`, benchmark schema/metric tools, annotation protocol and frozen pre-candidate corpus. |
| Task 2 | Isolated candidate adapters/evaluator, baseline/candidate evidence, human visual review and go/no-go report. |
| Task 3 | Protection/color/preview/view domain values and extended canonical Room draft/state. |
| Task 4 | Selected protection asset/descriptor/worker, edge fusion and ownership-bounded coverage. |
| Task 5 | Exact LAB transform, linear-sRGB compositor and immutable RGBA frame. |
| Task 6 | Hybrid analysis and latest-only preview services/workers with real progress and close/cache rules. |
| Task 7 | Preparation callback plus canonical controller revisions, atomic commit, pending handoff and separate errors. |
| Task 8 | Photo editor, comparison viewport, extracted mask controls, surface cards and accessible loading/error UI. |
| Task 9 | Shared color picker, **Use in Room**, `/room/photo`, Room CTA/copy and cross-feature flows. |
| Task 10 | Full-pipeline smoke, previews, docs, independent review, full guarded verification and source archive. |
| Task 11 | Separately authorized physical-device timing, memory and native accessibility release evidence. |

Use this guarded prefix for focused Flutter commands:

```sh
COLOR_LAB_FLUTTER_ROOT=/Users/jamirulislam/Applications/flutter
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" test --no-pub test/features/room_studio/domain/room_recolor_state_test.dart --reporter expanded
```

For each task, replace the focused test path in that example only with the exact
test files named by the task. Angle-bracket names used below, such as
`<photo-id>` and `<candidate-id>`, are schema variables, not unresolved design
decisions: resolve them to the frozen manifest/register ID before creating a
file or running a command.

Each RED step requires the named expectation to fail for the missing behavior, not a syntax/setup failure. Each GREEN step requires exit 0 and `All tests passed!`. Formatting is read-only:

```sh
"$COLOR_LAB_FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart" --suppress-analytics format --output=none --set-exit-if-changed lib test tool
```

### Task 1: Freeze the licensed benchmark and scoring contract

**Files:**

- Create: `test/fixtures/room_recolor/v1/manifest.json`, `test/fixtures/room_recolor/v1/protocol.json`.
- Create: `test/fixtures/room_recolor/v1/licenses/<photo-id>.txt`, `test/fixtures/room_recolor/v1/photos/<photo-id>/{source,working}.<ext>`.
- Create: `test/fixtures/room_recolor/v1/photos/<photo-id>/annotations/{annotator-a,annotator-b,adjudicated}.{ownership,protection}.bin` and `adjudication.json`.
- Create: `tool/room_recolor/benchmark.dart`, `tool/room_recolor/quality_metrics.dart`, `tool/verify_room_recolor_benchmark.dart`.
- Create: `test/tool/room_recolor/benchmark_test.dart`, `test/tool/room_recolor/quality_metrics_test.dart`.
- Create: `docs/superpowers/plans/room-recolor-annotation-protocol.md`, `docs/superpowers/plans/2026-10-22-room-photo-recolor-progress.md`.

**Interfaces:**

- Produces `RoomRecolorBenchmark loadRoomRecolorBenchmark(Directory root, {required bool requireAdjudicatedAnnotations})`.
- Produces `RoomQualityMetrics scoreRoomQuality({required MaskBitmap predictedOwnership, required Uint8List effectiveCoverage, required MaskBitmap groundTruthOwnership, required Uint8List groundTruthProtection, int boundaryTolerancePixels = 5})`.
- Produces frozen protocol v1: labels `0..4`, protection `0/255`, 8-neighbor boundaries, Euclidean match `<= 5` pixels, coverage threshold `>= 1`, `floor(p * (n - 1))` only for the later LAB percentile rule, and explicit denominators/absent-layer handling.
- Jointly absent layer/image pairs are excluded from macro boundary/IoU means; false-positive predicted layers remain included. Every benchmark image must contain protected ground truth. A zero aggregate baseline leakage cannot prove a 10% relative improvement and fails benchmark suitability before candidate tuning.

- [ ] **Step 1: Write failing benchmark-validation tests.** Add named cases for exactly 24 distinct photos and 6/6/6/6 categories; required licenses/checksums/tags; duplicate decoded-photo rejection; malformed ownership/protection bytes; missing A/B/adjudication evidence; 23/25-photo rejection; model predictions rejected as ground truth.

```dart
expect(() => loadRoomRecolorBenchmark(root23,
  requireAdjudicatedAnnotations: true), throwsFormatException);
expect(valid.photos.length, 24);
expect(valid.photos.map((p) => p.decodedRgbaSha256).toSet().length, 24);
```

- [ ] **Step 2: Write failing literal metric tests.** Pin a boundary point exactly 5 versus 6 pixels away, false-positive absent layers, protected leakage at coverage byte 0/1, per-image denominators and dimension mismatch.

```dart
expect(atFive.boundaryTruePositive, 1);
expect(atSix.boundaryFalsePositive, 1);
expect(score.protectedColoredPixels, 1); // coverage byte 1 counts
```

- [ ] **Step 3: Run RED.** Run the two `test/tool/room_recolor/` files with the guarded focused command; expect missing loader/scoring APIs.

- [ ] **Step 4: Implement the manifest/protocol loader and exact metric functions.** Validate detached bytes, source/working hashes, license/attribution fields, distinctness and annotation dimensions before returning any benchmark object. Do not add candidate-specific tolerances.

- [ ] **Step 5: Publish the blind annotation protocol.** Annotators see only the working image and layer/protection instructions, never a model output. Record annotator identity, independent submission hash/time, disputed regions and adjudicated decision; a JSON claim without both independent byte maps fails validation.

- [ ] **Step 6: Acquire and freeze 24 redistribution-permitted distinct rooms.** Use six living rooms, six bedrooms, six kitchens/dining rooms and six other indoor rooms; cover all four layers and every scene/lighting/protection tag from the spec. Count the retained Daderot CC0 fixture once; do not count format variants or the unresolved Unsplash image. Preserve exact source URLs/revisions, creator/title, license version/text, acquisition date and source/decoded hashes.

- [ ] **Step 7: Obtain two independent annotations and adjudicate all 24 photos.** This is an external human prerequisite. If unavailable, stop with `BLOCKED/PENDING EVIDENCE`; do not synthesize labels or begin Task 2 tuning.

- [ ] **Step 8: Run GREEN and freeze the benchmark.** Run both focused tests, then direct verification:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/cache/dart-sdk/bin/dartvm" tool/verify_room_recolor_benchmark.dart --root test/fixtures/room_recolor/v1 --require-adjudicated
```

Expected: exit 0, exactly 24 accepted distinct photos, complete provenance and adjudicated annotations. Append hashes, commands and results to the progress ledger; do not modify protocol v1 after candidate output is viewed.

### Task 2: Evaluate independent protection candidates and issue PASS/no-go

**Files:**

- Create: `tool/room_recolor/{candidate,baseline_candidate,fusion,evaluation_renderer}.dart`.
- Create: `tool/room_recolor/candidates/<candidate-id>/{descriptor.json,model.tflite,LICENSE.txt,PROVENANCE.json}` only for evaluated candidates; keep them outside app assets until selection.
- Create: `tool/run_room_recolor_benchmark.dart`, `tool/score_room_recolor_quality.dart`, `tool/verify_room_recolor_pipeline.dart`.
- Create: `test/tool/room_recolor/{fusion,evaluation_renderer,candidate_runner}_test.dart`.
- Create: `docs/superpowers/plans/room-recolor-candidate-register.md`, `docs/superpowers/plans/room-recolor-feasibility-report.md`.
- Create: `docs/superpowers/evidence/room-recolor/v1/{baseline,candidates,visual-review.json,quality-summary.json}`.

**Interfaces:**

- Consumes Task 1's immutable benchmark/protocol; its hashes are inputs to every result.
- Produces `abstract interface class RoomRecolorCandidate { String get id; String get analysisVersion; Future<RoomRecolorCandidateResult> analyze(PreparedPhoto photo); Future<void> close(); }`.
- Produces `RoomRecolorCandidateResult({required MaskBitmap ownership, required Uint8List protection, required Uint8List edgeCoverage})`, with every map aligned to working pixels and coverage `0..255` for the owning layer only.
- Produces `RoomQualityDecision compareRoomQuality({required RoomQualityRun baseline, required RoomQualityRun candidate, required RoomVisualReview review})` returning only `pass`, `fail` or `pendingEvidence` with reasons.

- [ ] **Step 1: Write failing evaluator/fusion tests.** Pin source-based LAB output, binary baseline coverage, protection clamping, ownership-bounded inward coverage, a MOSAIC-Furniture/person literal and order independence. The tool evaluator must implement the approved formula and linear-sRGB blend; the current tint overlay is forbidden.

- [ ] **Step 2: Write failing candidate-contract tests.** Reject wrong checksums, absent licenses, unsupported tensors/operators, malformed maps, a protector derived only from MOSAIC argmax IDs, and any required-pass failure that returns an unprotected success.

- [ ] **Step 3: Run RED.** Run all `test/tool/room_recolor/` tests; expect missing candidate/evaluator APIs.

- [ ] **Step 4: Implement the isolated harness.** Keep `TfliteRoomModelRunner` fixed to current MOSAIC. Candidate adapters own their separate descriptor/preprocessing and feed the common evaluator. Pin artifact/source/license/operator/tensor/quantization/transform/fusion identities and close resources on all failures.

- [ ] **Step 5: Freeze the production baseline before candidate scoring.** Run the current default `IsolateRoomSegmentationService` and bundled MOSAIC on all 24 working photos. Use binary owner coverage, zero extra protection and the common LAB evaluator. Record raw maps/hashes/timings/metrics; historical four-photo scratch masks are not the baseline.

- [ ] **Step 6: Research and evaluate redistribution-permitted TFLite candidates.** A candidate must provide evidence independent enough to remove a person mislabeled Furniture and cover windows, doors and decoration. Development-time downloads are pinned inputs, never runtime behavior. If no compatible candidate exists, publish no-go without adding a new native runtime or weakening gates.

- [ ] **Step 7: Run every candidate through the frozen 24-photo harness.** Preserve per-photo ownership/protection/coverage, assignments, preview hashes, raw counts, per-layer metrics, failures and stage times. Use the guarded direct-VM wrapper, one explicit candidate/output at a time.

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/cache/dart-sdk/bin/dartvm" tool/run_room_recolor_benchmark.dart --flutter-root "$COLOR_LAB_FLUTTER_ROOT" --benchmark test/fixtures/room_recolor/v1 --candidate candidate-id-from-the-frozen-register --output docs/superpowers/evidence/room-recolor/v1/candidates/candidate-id-from-the-frozen-register
```

Run that command separately for each literal immutable `id` already written to
`room-recolor-candidate-register.md`; the command and output directory must use
the same ID.

- [ ] **Step 8: Complete dated human visual review.** Inspect all 24 baseline/candidate previews at normal and zoomed boundaries; record reviewer, hashes, view scale, severe spill/missing-surface findings and accept/reject. Missing review yields `pendingEvidence`.

- [ ] **Step 9: Apply the immutable decision.** PASS requires boundary F1 `>= baseline + 0.02`, protected leakage `<= 0.90 * baseline`, each layer IoU loss `<= 0.01`, every image leakage regression `<= 0.02`, 24 structurally valid outputs and accepted visual review. If baseline protected leakage is zero, or evidence is incomplete, PASS is impossible under v1. On FAIL/PENDING stop here and preserve the current product.

- [ ] **Step 10: Run GREEN and record the selected contract.** Run all tool tests plus `tool/verify_room_recolor_pipeline.dart`; write exact selected artifact/hash/descriptor/preprocessing/output/fusion/algorithm facts and the PASS/no-go rationale to the feasibility report and progress ledger.

### Task 3: Add immutable recolor state to the canonical Room session

**Files:**

- Create: `lib/features/room_studio/domain/room_protection_matte.dart`, `room_layer_colors.dart`, `room_coverage_map.dart`, `room_preview.dart`, `room_editor_view.dart`.
- Create: `lib/features/room_studio/domain/room_pipeline_progress.dart`.
- Modify: `lib/features/room_studio/domain/room_mask_state.dart:8-125`.
- Create: `test/features/room_studio/domain/room_recolor_state_test.dart`.
- Modify: `lib/features/room_studio/application/room_mask_controller.dart` and `test/features/room_studio/application/room_mask_controller_test.dart`, the only current direct `RoomMaskDraft` construction sites.

**Interfaces:**

- Consumes Task 2 PASS and selected `analysisVersion`/`algorithmVersion` identities.
- Produces `RoomProtectionMatte({required int width, required int height, required Uint8List coverage})` and `RoomCoverageMap` with detached exact `width * height` bytes.
- Produces explicit `RoomLayerColors({RgbColor? wall, ceiling, floor, furniture})`, `const RoomLayerColors.empty()`, `RgbColor? operator [](RoomLayer)`, `withColor(RoomLayer, RgbColor?)`, `hasAssignments`.
- Produces value `RoomPreviewKey({required String photoId, required int maskRevision, required int colorRevision, required String algorithmVersion})` and `RoomPreviewFrame({required RoomPreviewKey key, required int width, required int height, required Uint8List rgbaBytes})`; the frame defensively detaches exactly `width * height * 4` RGBA bytes.
- Produces `RoomEditorMode { previewColors, refineMasks }` and `RoomEditorView(mode, dividerFraction, zoom, panX, panY)` defaulting to Preview/.5/1/0/0.
- Produces `RoomPipelineStage { preparingPhoto, findingRoomSurfaces, protectingObjects, refiningEdges, buildingPreview }` and `RoomPipelineProgress({required int operation, required RoomPipelineStage stage, String? photoId})`; `photoId` may be null only for Preparing photo before a receipt is claimed.
- Produces `RoomPreviewStatus { idle, rendering, ready, error }`, `RoomPreviewFailureKind { processing, invalidOutput }` and keyed `RoomPreviewFailure({required RoomPreviewKey key, required RoomPreviewFailureKind kind})`.
- Extends `RoomMaskDraft` with required `protection`, `colors`, `colorRevision`, copy helpers, `hasColorAssignments` and `requiresReplaceConfirmation`; `hasEdits` remains mask-only.
- Extends canonical `RoomMaskState` with `RoomPipelineProgress? progress`, `RoomPreviewStatus previewStatus`, `RoomPreviewFrame? preview`, `RoomPreviewKey? pendingPreviewKey`, `RoomPreviewFailure? previewFailure`, `RoomMaskFailureKind? maskEditFailure`, `RoomEditorView editorView`, `RgbColor? pendingWallColor` and nonnegative `int handoffRevision`. Analysis/acquisition remains represented by existing `stage`/`failure`; mask-edit and preview failures use their separate fields. Initial state is Preview mode, 50% divider, idle preview, no pending color and handoff revision zero.

- [ ] **Step 1: Write failing value/invariant tests.** Reject mismatched matte/frame sizes, invalid revisions/divider/zoom, mutable-input aliasing and incomplete layer state. Assert value-equal keys and exactly four nullable assignments.

```dart
expect(RoomLayerColors.empty().hasAssignments, isFalse);
expect(draft.requiresReplaceConfirmation, draft.hasEdits || draft.hasColorAssignments);
expect(frame.rgbaBytes.length, frame.width * frame.height * 4);
```

- [ ] **Step 2: Write failing draft-transition tests.** Pin independent revision deltas, no-op colors, mask-copy color retention, Restore-AI color retention and ordinary replacement resetting colors/view.

- [ ] **Step 3: Run RED.** Run `room_recolor_state_test.dart` plus existing mask domain/controller tests; expect missing types/fields.

- [ ] **Step 4: Implement the immutable values and draft helpers.** Use explicit fields rather than mutable maps, defensive byte snapshots and finite/range validation. Do not put rendered pixels into `RoomMaskDraft`; they remain derived preview state.

- [ ] **Step 5: Update existing construction fixtures and run GREEN.** Run all Room domain/application tests. Record passing counts and selected version strings in the progress ledger.

### Task 4: Promote the selected protector and implement edge fusion

**Files:**

- Create after PASS: `assets/models/room_protection.tflite`, `assets/models/room_protection_descriptor.json`, `assets/licenses/room-protection-LICENSE.txt`, `assets/licenses/room-protection-PROVENANCE.txt`.
- Create: `lib/features/room_studio/protection/room_protection_descriptor.dart`, `room_protection_runner.dart`, `room_protection_worker.dart`.
- Create: `lib/features/room_studio/analysis/room_edge_fusion.dart`.
- Modify: `lib/main.dart:8-24`, `docs/asset-sources.md`. Existing `pubspec.yaml` already bundles the complete `assets/models/` and `assets/licenses/` directories, so do not change it.
- Create: `test/features/room_studio/protection/room_protection_descriptor_test.dart`, `room_protection_worker_test.dart`.
- Create: `test/features/room_studio/analysis/room_edge_fusion_test.dart`.

**Interfaces:**

- Consumes Task 2's selected TFLite bytes, literal descriptor contract, license/provenance and frozen reference outputs. Do not generalize the existing fixed MOSAIC runner.
- Produces `abstract interface class RoomProtectionWorker { String get analysisVersion; Future<RoomProtectionMatte> run(PreparedPhoto photo); Future<void> close(); }` and the asset-backed worker factory.
- Produces `MaskBitmap fuseRoomOwnership({required PreparedPhoto photo, required MaskBitmap primary, required RoomProtectionMatte protection})`.
- Produces `RoomCoverageMap buildRoomCoverage({required PreparedPhoto photo, required MaskBitmap masks, required MaskBitmap aiMasks, required RoomProtectionMatte protection})` using inward/ownership-bounded coverage and exact manual override `masks[p] != aiMasks[p] && masks[p] != 0`.

- [ ] **Step 1: Write failing descriptor/runner tests.** Pin the selected candidate's exact checksum, tensor metadata, preprocessing, alignment and protected-output interpretation from Task 2; reject wrong assets, values and close/use-after-close.

- [ ] **Step 2: Write failing literal fusion tests.** Cover primary Furniture + protection 255, partial protection multiplication, exclusive labels, malformed dimensions, adjacent owners, empty layers and one manually reclaimed protected center pixel with protected neighbors.

```dart
expect(fused.labels[personPixel], 0);
expect(weights.coverage[personPixel], 0);
expect(manualWeights.coverage[reclaimed], greaterThan(0));
expect(manualWeights.coverage[protectedNeighbor], 0);
```

- [ ] **Step 3: Run RED.** Run the new protection/analysis tests; expect missing selected adapter/fusion APIs.

- [ ] **Step 4: Promote only the PASS artifact and exact legal files.** Verify bytes against Task 2 hashes before copying. Register license entries in `main.dart`; document immutable source/revision/license and observed limits. Do not retain losing candidate binaries in app assets.

- [ ] **Step 5: Implement the worker and pure fusion/coverage engine.** Own the interpreter in one worker, keep all pixels off the UI isolate, validate every output, apply protection after smoothing and constrain coverage to current ownership.

- [ ] **Step 6: Run GREEN.** Run the new suites plus existing model/mask processing tests. Confirm the diagnostic `buildLayerAlpha` remains unchanged and unused for recolor. Record artifact hashes and results.

### Task 5: Promote the deterministic LAB recolor renderer

**Files:**

- Create: `lib/features/room_studio/recolor/room_recolor_algorithm.dart`, `room_lab_renderer.dart`.
- Create: `test/features/room_studio/recolor/room_lab_renderer_test.dart` and literal RGBA fixtures under `test/fixtures/room_recolor/unit/`.
- Modify: `tool/room_recolor/evaluation_renderer.dart` to call the production pure renderer after output parity is proven.

**Interfaces:**

- Produces constant `roomRecolorAlgorithmVersion` containing selected model/fusion/LAB contract identity.
- Produces `RoomRecolorRequest({required RoomPreviewKey key, required PreparedPhoto photo, required MaskBitmap masks, required MaskBitmap aiMasks, required RoomProtectionMatte protection, required RoomLayerColors colors})`.
- Produces pure `RoomPreviewFrame renderRoomLabPreview(RoomRecolorRequest request)`; it calls Task 4 coverage, computes 5x5 same-owner interiors, floor-index L05/L50/L95, the approved lightness formula, target `a/b`, existing gamut clamp and linear-sRGB source blend.

- [ ] **Step 1: Write failing percentile/interior tests.** Pin sorted `[10,20,40]` indices `0/1/1`, no-5x5 fallback, empty ownership and stable output for source/target edge values.

- [ ] **Step 2: Write failing pixel/composition tests.** Cover neutral/saturated/near-gamut targets, shadows/highlights, distinct adjacent layers, unassigned owners, partial protection, alpha 255, order independence and zero-weight source byte identity.

- [ ] **Step 3: Write failing determinism/parity tests.** Render the same request 100 times and through a fresh instance; assert identical RGBA. Assert Task 2 frozen evaluator hashes match before the tool switches to the production implementation.

- [ ] **Step 4: Run RED.** Run `room_lab_renderer_test.dart`; expect missing renderer APIs.

- [ ] **Step 5: Implement the minimal pure renderer.** Recompute from `PreparedPhoto.rgbaBytes` every time. Use no hidden strength, outward blur, previous frame or selected-layer ordering.

- [ ] **Step 6: Run GREEN and parity verification.** Run renderer/fusion/tool evaluator suites; regenerate no benchmark thresholds. Record algorithm version and frozen hash parity.

### Task 6: Add bounded hybrid-analysis and preview services

**Files:**

- Create: `lib/features/room_studio/analysis/room_analysis.dart`, `room_analysis_service.dart`, `room_analysis_worker.dart`.
- Create: `lib/features/room_studio/recolor/room_preview_service.dart`, `room_preview_worker.dart`.
- Create: `test/features/room_studio/analysis/room_analysis_service_test.dart`.
- Create: `test/features/room_studio/recolor/room_preview_service_test.dart`.

**Interfaces:**

- Consumes Task 3's `RoomPipelineStage`/`RoomPipelineProgress`; the analysis service emits only Finding room surfaces, Protecting objects and Refining edges. Acquisition/controller code owns Preparing photo and Building preview because only those layers know the real work boundary.
- Produces `RoomAnalysisResult({required String photoId, required String analysisVersion, required MaskBitmap aiMasks, required RoomProtectionMatte protection})`.
- Produces `abstract interface class RoomAnalysisService { Future<RoomAnalysisResult> analyze({required int operation, required String photoId, required PreparedPhoto photo, required void Function(RoomPipelineProgress) onProgress}); Future<void> close(); }`.
- Produces `abstract interface class RoomPreviewService { Future<RoomPreviewFrame> render(RoomRecolorRequest request); Future<void> close(); }` with one active, one replaceable waiting request and single-entry current-frame cache.

- [ ] **Step 1: Write failing real-stage and validation tests.** Assert primary → protection → fusion order, no fake preparation/building events from the analysis service, aligned complete result, required-pass failure and safe close/resource replacement.

- [ ] **Step 2: Write failing queue/cache tests.** Controlled Completers pin one-active/one-latest behavior, replaced-waiter cancellation, identical-key cache, stale success/error identity, failure recovery and no parallel full-image renders.

- [ ] **Step 3: Run RED.** Run both new service suites; expect missing services.

- [ ] **Step 4: Implement the analysis coordinator.** Call the existing production primary service only for the active composite request, then selected protection, pure fusion and validation. Cache by prepared-photo identity plus analysis version; never by caller photo ID alone.

- [ ] **Step 5: Implement the preview worker/service.** Transfer immutable scalar/byte data, invoke Task 5 off the UI isolate, return the full key on success/error, release dead workers after transport failures and finish an active call before close completes.

- [ ] **Step 6: Run GREEN.** Run analysis/preview services plus existing segmentation service tests. Record queue/cache/close evidence.

### Task 7: Integrate honest preparation progress and canonical controller lifecycle

**Files:**

- Modify: `lib/features/picker/application/photo_picker_service.dart:27-105`, `lib/features/picker/application/photo_acquisition_controller.dart:112-207`.
- Modify: `lib/features/room_studio/application/room_mask_controller.dart`, `domain/room_mask_state.dart`.
- Modify: `test/features/picker/photo_view/photo_picker_service_test.dart`, `test/features/picker/application/photo_acquisition_controller_test.dart` and picker fakes implementing `PhotoPickerService`.
- Modify: `test/features/room_studio/application/room_mask_controller_test.dart`.

**Interfaces:**

- Extends `PhotoPickerService.pick({PhotoSource source = PhotoSource.gallery, void Function()? onPreparationStarted})`; invoke callback only after a native file exists and immediately before bounded read/prepare. `PhotoAcquisitionController.request` forwards an owner-guarded optional callback. Recovery skips already completed stages.
- Adds controller actions `setLayerColor(RoomLayer, RgbColor?)`, `resetLayerColor(RoomLayer)`, `resetAllColors()`, `useColorInRoom(RgbColor)`, `setEditorMode(RoomEditorMode)`, `setEditorView(RoomEditorView)` and `Future<void> retryPreview()`.
- `useColorInRoom` assigns the selected layer and enters Preview when a committed draft exists; otherwise it stores latest pending Wall plus a handoff revision. Pending color clears only after a matching candidate frame commits.

- [ ] **Step 1: Write failing preparation callback tests.** Assert cancel/no-file never emits, selected file emits once before processor work, stale owner callbacks are ignored, Capture callers remain compatible and recovered prepared receipts do not replay preparation.

- [ ] **Step 2: Write failing color/revision tests.** Pin four independent assignments, no-op assignment, Reset layer/Reset all, pending Wall, selected-layer handoff, mask/color revision independence and no History/Palette mutation.

- [ ] **Step 3: Write failing race/error tests.** Use controlled analysis/render Completers for cancel/replacement, a newer pending handoff during initial render, color change during mask refine, out-of-order progress/success/error, preview retry without inference, and separate analysis/mask-edit/preview failures.

```dart
expect(afterMask.colors, latestColorDraft.colors);
expect(afterMask.colorRevision, latestColorDraft.colorRevision);
expect(primaryAnalyzeCount, 1); // color/retry-preview does not rerun AI
```

- [ ] **Step 4: Run RED.** Run focused picker acquisition/service and Room controller tests; expect missing callback/actions and old identity-guard failure.

- [ ] **Step 5: Implement preparation propagation.** Keep the existing acquisition lock, durable intent and receipt acceptance semantics unchanged. Emit only the real callback and preserve all current source callers.

- [ ] **Step 6: Replace the controller's segmentation-only candidate path.** Drive Task 6 analysis, then emit Building preview and render the candidate's initial key before atomic commit. Old committed state remains available until this completes.

- [ ] **Step 7: Implement assignment/view/preview transitions.** Coalesce renders, keep old frame explicitly keyed, clear neither masks nor colors on preview error, reset colors/view only on successful ordinary replacement and preserve them through mask edits/Restore AI.

- [ ] **Step 8: Fix mask/color merge acceptance.** Replace `identical(state.draft, capturedDraft)` with operation + `photoId` + captured `maskRevision`; merge accepted masks/history into the latest matching draft while preserving its colors/`colorRevision`. Color changes must not increment `_editSelection`.

- [ ] **Step 9: Run GREEN.** Run all picker and Room application tests. Record exact race cases/counts and confirm prior acquisition regressions remain green.

### Task 8: Build the accessible photo editor and comparison viewport

**Files:**

- Create: `lib/features/room_studio/presentation/room_photo_editor_screen.dart`, `room_comparison_viewport.dart`, `room_surface_color_cards.dart`, `room_mask_controls.dart`.
- Modify: `lib/features/room_studio/presentation/room_mask_screen.dart`, `room_mask_viewport.dart`, `room_mask_dialogs.dart`.
- Create: `test/features/room_studio/presentation/room_comparison_viewport_test.dart`, `room_photo_editor_test.dart`.
- Modify: `test/features/room_studio/presentation/room_mask_viewport_test.dart`.

**Interfaces:**

- `RoomPhotoEditorScreen` is the single host for empty/acquiring/analyzing/error/ready states, Preview colors/Refine masks, five-second local message, cancel/retry/reset confirmations and separate preview error.
- `RoomComparisonViewport({required RoomMaskDraft draft, required RoomPreviewFrame? preview, required RoomEditorView view, required ValueChanged<RoomEditorView> onViewChanged})` decodes by full key, retains the previous image until new decode succeeds and clips source/result with one `PhotoViewport` transform.
- `RoomSurfaceColorCards` renders four cards and emits select/choose/reset callbacks; `RoomMaskControls` extracts existing diagnostic controls without changing mask semantics.

- [ ] **Step 1: Write failing comparison-viewport tests.** Pin 50% default, shared pan/zoom geometry, divider endpoints, Show original/Show result semantics, old-frame retention, key-checked decode, stale decoded-image disposal and new-photo transform reset.

- [ ] **Step 2: Write failing editor-state tests.** Pin five real stage messages, no percentage, Cancel, >5-second text, previous draft during replacement, distinct preview error/retry, Not set/Not detected, mode switching and color/mask persistence.

- [ ] **Step 3: Write failing accessibility/responsive tests.** Assert 360x800, 2x text, both themes, reduced motion, 48 dp actions, focus/selected/value semantics and no requirement to drag the divider.

- [ ] **Step 4: Run RED.** Run the three presentation suites; expect missing editor/comparison APIs.

- [ ] **Step 5: Implement the comparison viewport.** Decode raw RGBA against width/height, keep source/result under one transform, generation-check after every async boundary, and never draw an old-photo result over a new source.

- [ ] **Step 6: Extract mask controls and externalize retained view state.** Keep `RoomMaskViewport` diagnostic overlay/stroke behavior and current gesture tests; mode/navigation/theme changes retain view, while accepted replacement resets it.

- [ ] **Step 7: Implement the editor and dialogs.** Add Reset all confirmation, replacement copy that mentions masks/colors, Restore AI copy that retains colors, exact loading/error actions and live-region status. `RoomMaskScreen` becomes a compatibility entry into the same host, not another controller.

- [ ] **Step 8: Run GREEN.** Run all Room presentation tests in light/dark and responsive configurations. Record semantics/layout evidence.

### Task 9: Connect color selection, Use in Room and routing

**Files:**

- Create: `lib/features/picker/presentation/color_picker_sheet.dart` by promoting the existing reusable HEX/saved-library picker.
- Modify: `lib/features/mixer/presentation/mixer_color_picker.dart` to remain a compatibility wrapper; existing Formula, Harmonies and Mixer callers continue using that public wrapper unchanged.
- Modify: `lib/features/picker/presentation/color_explorer.dart:24-123`.
- Modify: `lib/features/room_studio/presentation/room_screen.dart`, `lib/routing/app_router.dart`.
- Modify: `test/features/picker/color_details_actions_test.dart`, `test/features/mixer/presentation/mixer_color_picker_test.dart`.
- Modify: `test/features/formula/presentation/formula_integration_test.dart`, `test/features/harmonies/presentation/harmonies_integration_test.dart`, `test/features/color_test/presentation/matching_integration_test.dart`.
- Modify: `test/features/room_studio/presentation/room_masks_integration_test.dart`.

**Interfaces:**

- Produces `Future<RgbColor?> showColorPickerSheet(BuildContext context, {RgbColor? initialColor})`; it reads but never writes the saved library. Existing mixer wrapper delegates to it.
- Adds `/room/photo` for `RoomPhotoEditorScreen`; `/room/masks` remains a compatible entry to the same retained session. Route activity checks accept both paths.
- `_DetailDestination.room` calls `roomMaskProvider.notifier.useColorInRoom(color)` then navigates to `/room/photo`; it no longer writes only `roomColorProvider` or routes only to the illustration.

- [ ] **Step 1: Write failing shared-picker tests.** Pin manual HEX, saved color, load/error/retry, cancel, no repository mutation and compatibility wrapper behavior.

- [ ] **Step 2: Rewrite Use in Room expectations before production changes.** With a committed draft, assert selected-layer assignment + Preview mode; without one, assert pending Wall; assert formula/harmony/matching/palette source state and History/Palette counts remain unchanged.

- [ ] **Step 3: Write failing route/Room entry tests.** Assert **Visualize your room**, `/room/photo`, `/room/masks` compatibility, independent illustration presets and removal of “photo recoloring coming later” copy.

- [ ] **Step 4: Run RED.** Run picker/color-detail, mixer picker, Room integration and every `rg -l "Use in Room" test` suite; expect old illustration-only behavior.

- [ ] **Step 5: Promote/wire the shared picker and surface cards.** Manual/saved colors return to the active layer; **Browse palettes** uses the existing palette flow, whose **Use in Room** returns to the retained photo editor.

- [ ] **Step 6: Implement handoff and route changes.** Preserve `roomColorProvider` for illustration-only presets. A newer handoff invalidates any older pending initial-frame key; an older completion cannot clear it.

- [ ] **Step 7: Update Room entry/copy and run GREEN.** Run all focused cross-feature suites and the complete Room integration suite. Record navigation/session/storage evidence.

### Task 10: Verify the real pipeline, previews, documentation and source handoff

**Files:**

- Create: `tool/verify_room_recolor.dart`, `tool/run_room_recolor_smoke.dart`.
- Modify: `tool/render_previews.dart`.
- Modify: `README.md`, `docs/asset-sources.md`, `docs/superpowers/plans/2026-10-22-room-photo-recolor-progress.md`.
- Create: `docs/superpowers/plans/room-recolor-final-verification.md`, `docs/superpowers/plans/room-recolor-source-archive-recipe.rb`.
- Create final source archive: `dist/color-lab-room-recolor-2026-10-22.zip`; preserve all earlier archives/APKs.

**Interfaces:**

- Smoke executes actual bundled primary + selected protection + fusion + production renderer on at least one permitted fixture and records model/descriptor/source/mask/assignment/output hashes, dimensions and stage timings.
- Preview tool adds loading stages, four independent colors, Before/After endpoints, Refine masks, no-surface/manual Add, stale/preview errors and 360 dp/2x/reduced-motion light/dark captures without changing legacy filenames unexpectedly.
- Archive recipe validates exact manifest, unique safe relative paths, required model/license/evidence/docs, every archived byte and exclusions for APK/AAB/build/cache/secrets/Pods/host libraries/older ZIPs.

- [ ] **Step 1: Write the smoke verifier's failing evidence checks.** Missing selected model/license, malformed protection, zero protected-person evidence, dimension mismatch, stale key or fake runner must exit nonzero; an existing MOSAIC-only smoke is not PASS.

- [ ] **Step 2: Implement and run real full-pipeline smoke.** Use the guarded direct `dartvm` wrapper patterned after `run_room_model_smoke.dart`; no native compilation or private loader hacks.

- [ ] **Step 3: Extend and visually inspect previews.** Run the guarded preview command, inspect every new state at normal and zoomed boundaries, and record filenames/findings. Renderer previews are not physical-device evidence.

- [ ] **Step 4: Run fresh cumulative source verification.** Require all commands to exit 0:

```sh
"$COLOR_LAB_FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart" --suppress-analytics format --output=none --set-exit-if-changed lib test tool
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" analyze --no-pub
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" test --no-pub --reporter expanded
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" test tool/render_previews.dart --no-pub --reporter expanded
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/cache/dart-sdk/bin/dartvm" tool/run_room_recolor_smoke.dart --flutter-root "$COLOR_LAB_FLUTTER_ROOT"
```

- [ ] **Step 5: Run independent task reviews and whole-module review.** Resolve every Blocker/Major and verify fixes with targeted RED/GREEN tests; disclose unresolved Minor findings rather than hiding them.

- [ ] **Step 6: Update truthful documentation.** Report benchmark-scoped quality only, exact host evidence, session/export limits and unverified device/accessibility limits. Remove stale README statements that Use in Room changes only the illustration or recolor is deferred.

- [ ] **Step 7: Build and validate the source-only archive.** Run the recipe, independently list/test it, hash it, preserve older archives and record entry count/SHA-256 in the external handoff. Do not build or include an APK/AAB.

### Task 11: Physical-device release gate — separately authorized only

**Files:**

- Create after authorization: `docs/superpowers/plans/room-recolor-device-verification.md` and raw benchmark exports under `docs/superpowers/evidence/room-recolor/v1/devices/`.

**Interfaces:**

- Measures from acquisition coordinator receiving the image through first decoded correctly keyed preview across the frozen 24 photos.
- Records first cold run separately; warmed p50/p95/worst, peak memory, OS/hardware/app/runtime/model versions and crash/OOM status on one named mid-range Android device and one named supported iPhone.
- Release target: warmed p95 `<= 5.0s`, no crash/OOM, plus TalkBack/VoiceOver operation of color cards, mode controls, divider alternatives, cancel/retry and dialogs.

- [ ] **Step 1: Stop and obtain explicit native build/install/device authorization.** Current approval does not permit this task. If not granted, mark release verification pending and do not infer results from host timing.

- [ ] **Step 2: Freeze named hardware/protocol before measuring.** Record device/OS/build/model/runtime identities and clear cold/warm rules without changing the 24-photo corpus.

- [ ] **Step 3: Run and retain all raw device measurements.** Report individual runs and aggregates; do not discard slow/failing runs.

- [ ] **Step 4: Complete native accessibility review and publish PASS/FAIL.** A failure blocks the five-second/native-accessibility release claim but does not rewrite source-only evidence.
