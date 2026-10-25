# Spatial Multi-Wall Protection Implementation Plan

> Use superpowers:executing-plans (Native), TDD, one final independent review. User opted out of repeated approvals.

**Goal / Spec:** Improve the existing monitor-to-Wall error without deleting a genuine second wall. Keep both downloaded models, offline processing, exclusive ownership and manual-edit lifecycle. No95% accuracy claim without independent dense labels; no model/permission/dependency changes, publication or phone restart.
**Architecture:** Ceiling-adjacent Wall samples provide independent surface context. Fit up to4 candidate planes over semantic Wall, retain only substantial ceiling-connected2D supports, and use spatially near supported planes for foreground veto. Unsupported/ambiguous areas abstain. No-ceiling scenes retain the existing single-wall path and60% confidence rule.
**Tech stack:** Existing Dart/Flutter and fixed MOSAIC/MiDaS outputs.
**Approaches:** Lowering60% is unsafe (real second wall erased). Arbitrarily accepting residual planes preserves monitors. Chosen: independently anchored, spatially restricted wall support; cached actual-photo prototype preserves inspected true walls and separates monitor interiors.

## Global Constraints / Review Focus

- Only Wall1→unselected0; every other owner and input immutable. Preserve coordinate mapping.
- No plane can influence the whole image from a narrow stripe or disconnected foreground patch.
- Large planar monitors must not become trusted walls just by residual count.
- Nearer/narrow/fragmented second walls, noisy corners, mirrored/transposed and depth-affine-equivalent scenes must remain safe.
- Unexplained ceiling anchors and distant unsupported regions preserve ownership; no invented object classes/confidence.
- Real gallery photos/evidence stay in private temp storage. Current feature branch retained; source push remains user's choice.

### Task 1: Spatial wall support and adversarial regressions

**Files:** Existing `segmentation/room_wall_depth_protection.dart`; new private part `room_wall_spatial_protection.dart`; new `test/features/room_studio/segmentation/room_multiwall_protection_test.dart`.
**Interface:** Existing public `protectRoomWallsWithDepth(masks,depth)` unchanged. Private spatial path returns null when ceiling evidence absent, a conservative mask otherwise.

- [x] RED/GREEN regression set: two walls+foreground, dominant-wall deletion,40% planar monitor, narrow/fragmented wall, unsupported ambiguity, extrapolation trap, geometry/ownership/transforms. 14 focused tests pass.
- [x] Implement bounded deterministic plane selection: ceiling distances5/256..48/256 of long depth axis, ≥64 ceiling cells, anchored connected inliers with2D covariance≥1e-5, combined support≥max(64,10% of Wall candidates), ≥max(16,longAxis/2) anchors; up to4 candidates,1500 bounded samples and1500 proposals each. Require85% anchor explanation. These are conservative engineering thresholds, not accuracy percentages.
- [x] Limit removal to spatially nearest supported planes (2-cell tie tolerance), within quarter-depth-axis support distance, and farther from unexplained anchors. Retain existing .035 fit and .08 foreground span thresholds. No least-squares post-fit.
- [x] Focused multiwall suite passes; full 980-test suite passes.

### Task 2: Real-photo evidence, verification and review

**Files:** README/plan evidence; private throwaway probes only outside repo.
**Consumes:** Unchanged public mask-protection API and current native model pipeline.
- [x] Compare the actual production runner on four cached private gallery photos. Before→after Wall pixels: photo hash79eb4db5,1,073,157→718,141 (355,016 removed); 04cfabd6,790,418→714,655 (75,763); e8d8f020,1,406,193→1,049,555 (356,638); 9d7deeca,1,863,368 unchanged. Visually inspected purple Wall overlays for the first three; walls and door regions remain, monitors are mostly excluded, while some desk/clutter false Wall pixels remain. These are visual samples without independent pixel truth, not accuracy measurements. Model SHA256s in each private report match the frozen GitHub release.
- [x] Actual two-model native host smoke passes on the four gallery photos; the unchanged reference photo passes in each invocation. Smoke timing is host-side and not phone timing.
- [x] Full Flutter suite passes (980 tests); analyzer clean; formatting clean; Android debug APK builds. APK inspection shows only the small room segmentation descriptor under assets/models; neither .tflite model nor docs are bundled.
- [x] Review the scoped diff and recorded private gallery evidence. No model-wide accuracy claim; these four unannotated samples show improvement in three and no change in one, with residual desk/clutter false positives. Commit locally; no source push/device replacement.
