# Task 2 implementation report

Status: DONE. Commits: none (no Git repository; no Git initialization, worktrees, or commits performed).

## Delivered files

- `lib/features/room_studio/domain/room_layer.dart`: exclusive wall/ceiling/floor/furniture labels 1/2/3/4; zero stays unselected.
- `lib/features/room_studio/domain/mask_bitmap.dart`: positive dimensions, matching length, validated labels 0–4, detached immutable ownership bytes (including buffer views), cached per-layer counts and pixel count. No whole-image equality override or Flutter dependency.
- `lib/features/room_studio/segmentation/room_input.dart`: detached immutable tensor bytes plus immutable validated source/input/content geometry and integer left/top padding.
- `lib/features/room_studio/segmentation/room_mask_processing.dart`: pure RGB preparation, output ownership mapping/closing/inverse alignment, and derived layer alpha.
- `test/features/room_studio/domain/mask_bitmap_test.dart`: 3 tests.
- `test/features/room_studio/segmentation/room_mask_processing_test.dart`: 17 tests.
- This report.

Only those six Task 2 source/test files and this report were authored by this implementer. The controller separately amended the source spec/plan/brief to clarify aligned-corner inverse geometry. No acquisition, UI, native, dependency, descriptor, runner, existing fixture, or model changes were made.

## Public APIs ready

```dart
enum RoomLayer { wall, ceiling, floor, furniture }
// int RoomLayer.label: 1, 2, 3, 4.

MaskBitmap({required int width, required int height, required Uint8List labels});
// Immutable Uint8List labels; int pixelCount; int count(RoomLayer layer).

RoomInput({required Uint8List tensorBytes, required RoomInputTransform transform});
RoomInputTransform({
  required int sourceWidth, required int sourceHeight,
  required int inputWidth, required int inputHeight,
  required int contentWidth, required int contentHeight,
  required int paddingLeft, required int paddingTop,
});

RoomInput prepareRoomInput(PreparedPhoto photo, RoomModelDescriptor descriptor);
MaskBitmap postprocessRoomOutput(
  RawSegmentation output, RoomInputTransform transform,
  RoomModelDescriptor descriptor,
);
Uint8List buildLayerAlpha(
  MaskBitmap masks, RoomLayer layer, {int featherRadius = 2},
);
```

The existing Task 1 descriptor/raw output/runner interfaces remain frozen. These APIs are ready for the later worker/state integration tasks; this task does not wire them into UI or invoke native inference.

## Processing contract and limits

Preparation consumes the existing `PreparedPhoto.rgbaBytes` without decoding its preview or reapplying EXIF. It fits to the fixed descriptor input (512×512), floors content dimensions, clamps each to at least one, aligns bilinear corners, samples source coordinate zero for a one-pixel content axis, and clamps/truncates channels to bytes. RGB transfers without normalization or requantization; alpha is not transferred. Content starts at the top left, with bottom/right RGB padding 123/115/103.

The double interpolation expression preserves the operation order recorded in the independent Task 1 fixture. All 786432 input bytes match the preexisting `reference_input.bin`; no expected input was generated from production code. Its existing SHA-256 is `b1853a64f7bf077e61e208f7c2756c21f8cf4f55f520bc0c59d0ffd668b7415a`; the existing PNG hash remains `94023747b626de08cf3daf14695dfe5810efac833cae74f34792a9ac4005bad1`.

Postprocessing rejects raw output or input-transform dimensions that do not match the verified descriptor. Descriptor name lookups map ADE wall1, ceiling6 and floor4 to layers1/2/3. Furniture4 is exactly bed8/sofa24/chair20/table16/cabinet11. Every other nonzero model class remains unselected/protected, including windowpane9, door15 and armchair31.

Closing is per-layer 3×3 binary dilation then erosion on the original mapped output with zero outside the model grid. Only original ignored0 pixels may receive a fill; original ownership and all other nonzero model classes cannot be overwritten. Ties resolve in enum order, and previous fills cannot seed a subsequent layer. Literal synthetic hole/tie/border tests establish this behavior: the real Task 1 output has no class0 and cannot prove ignored-only closing.

After closing, source pixels sample only the content region, adding the recorded padding. As clarified by the controller and amended brief, the inverse axis coordinate is zero for source size1, otherwise `round(sourceCoordinate * (contentSize - 1) / (sourceSize - 1))`, clamped to content. A three-pixel literal test verifies samples0/256/511, and a non-square padded test verifies both axes. Historical floor-selected sparse source diagnostics in `model_reference.json` are not used as an inverse geometry rule.

Feather radii1/2 use separable integer binomial weights `[1,2,1]/4` and `[1,4,6,4,1]/16`, with zero exterior. Integer intermediate sums retain precision; alpha rounds once after both passes. Radius0 returns binary alpha; other radii reject. Returned alpha is a separate mutable derived buffer; ownership and cached counts remain unchanged.

Existing upstream limits are unchanged: acquisition24MiB, processing32MiB, decoded24M pixels/16384 per axis, working longest edge1600. This pure pipeline trusts the established `PreparedPhoto` boundary and does not decode or change upstream budgets. Transform validation enforces positive geometry and content containment, not a duplicate acquisition policy. Model sizes/class IDs remain fixed by Task 1. Android24/iOS13 remain unchanged.

## TDD and verification evidence

RED, before any production implementation:

```sh
flutter test --no-pub test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart --reporter expanded
```

Exit1, `+0 -2: Some tests failed.` Both test files failed to load because the four owned source APIs did not yet exist (`mask_bitmap.dart`, `room_layer.dart`, `room_input.dart`, `room_mask_processing.dart`; missing constructors/functions). This is the brief's expected missing-API RED, not a claimed runtime assertion failure. A preceding sandbox-restricted launch exited1 before tests because Flutter tried to write its SDK `engine.stamp`; the approved escalated invocation above produced the actual RED.

First implementation iteration with the same command: exit1, 19 passed/1 failed. The failing test was `already baked EXIF orientation is consumed once at picker boundary`: PNG encoding did not preserve the constructed EXIF tag, so acquisition returned3×2 instead of the fixture's expected2×3. The test fixture was corrected to use an EXIF-bearing JPEG with large colored regions and a literal ±3 JPEG tolerance; no production change was needed for this failure.

GREEN, after the fixture correction:

```sh
flutter test --no-pub test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart --reporter expanded
```

Exit0, `+20: All tests passed!` (3 domain +17 processing). This includes detached snapshots/buffer views, bad dimensions/labels/transform containment, hand-drawn wide/tall color maps and padding, interpolation truncation/corners, already-baked orientation, 1600×1/1×1600/1×1 inputs, all32 ADE mappings, padded non-square inverse pixels, the three-pixel inverse, ignored-only fill/protected pixels/ties/borders, verified dimension rejection, radius1/2 alpha literals/bounds/zero exterior, and unchanged ownership/counts.

Formatting applied after that run:

```sh
dart format lib/features/room_studio/domain/room_layer.dart lib/features/room_studio/domain/mask_bitmap.dart lib/features/room_studio/segmentation/room_input.dart lib/features/room_studio/segmentation/room_mask_processing.dart test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart
```

Exit0, 6 files checked/4 formatted. An initial restricted invocation exited1 at the same SDK cache boundary; the approved command completed.

Scoped analysis:

```sh
dart analyze lib/features/room_studio/domain/room_layer.dart lib/features/room_studio/domain/mask_bitmap.dart lib/features/room_studio/segmentation/room_input.dart lib/features/room_studio/segmentation/room_mask_processing.dart test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart
```

Exit0: `No issues found!`

Formatting check:

```sh
dart format --output=none --set-exit-if-changed lib/features/room_studio/domain/room_layer.dart lib/features/room_studio/domain/mask_bitmap.dart lib/features/room_studio/segmentation/room_input.dart lib/features/room_studio/segmentation/room_mask_processing.dart test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart
```

Exit0: `Formatted 6 files (0 changed)`.

One fresh full suite, after the final functional change and formatting:

```sh
flutter test --no-pub --reporter expanded
```

Exit0, `00:25 +613: All tests passed!` Baseline593 +20 new tests =613. No failed/skipped tests were reported. The existing formula timing diagnostic printed during the suite; no new warnings/errors were reported. No production/test edits followed this full run, only this report. No native smoke rerun, native build, APK install, clean, or data clearing was performed.

## Self-review and concerns

Read the four production files and both test files against the amended Task 2 brief. Verified validation and immutable byte-buffer ownership, cached discrete counts, exact five-class furniture mapping through descriptor names, protected original nonzero IDs, ignored-only close on original snapshots, stable ties, aligned inverse with padding, radius bounds/zero exterior, independent reference bytes, and absence of Flutter imports in the domain/processing files. No whole-image equality work was added. No extra acquisition/UI/manual-paint functionality was introduced.

There is no `.git` directory, so no Git diff or commit was available. Scope was checked against the explicit edit calls and file inspection; artifacts and unrelated files were not edited. The original APK and all nine distribution ZIPs retain their earlier timestamps. Existing fixtures' hashes match their frozen metadata. SDK access was limited to normal approved Dart/Flutter command execution; no SDK/pub-cache source patch or private API was used.

No known correctness concerns remain for this pure task. Model segmentation errors and cross-device inference differences documented by Task 1 remain existing model limitations; these pixel transformations do not establish new model accuracy claims. Integration/lifecycle/UI/native behavior is outside Task 2 and has not been claimed complete here.

## Review fix round 1: exact dominant dimension

Status: DONE. Commits: none. The review found that floating scale multiplication could yield 511.99999999999994, which was floored to 511. The original 20 tests did not expose this case, so the earlier self-review conclusion was incomplete.

Added literal regression `49 by 49 fit fills exactly 512 without a rounding padding strip`. It requires a 49×49 photo to produce content 512×512 and verifies the last row/column/corner contain source RGB 7/8/9 rather than padding 123/115/103. Before the production fix, this covering command was run fresh:

```sh
flutter test --no-pub test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart --reporter expanded
```

RED exit1, 20 passed/1 failed (`+20 -1: Some tests failed.`). The new regression failed with `Expected: [512, 512]`, `Actual: [511, 511]` at its transform assertion, confirming the review's root cause against the existing production function.

Replaced floating fit arithmetic with integer ratio arithmetic: select the limiting axis using integer cross products, assign its descriptor dimension directly (512), and use integer division for the proportional other axis, clamping it to at least 1. The bilinear interpolation expression and all downstream processing are unchanged. This implements mathematical floor fit and removes floating-point rounding from content geometry.

GREEN, same exact covering command after the minimal correction:

```sh
flutter test --no-pub test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart --reporter expanded
```

Exit0, `+21: All tests passed!` (3 domain +18 processing). The full independent 1280×853 Task1 tensor comparison still passes byte-for-byte. No fixture was regenerated.

Formatting command:

```sh
dart format lib/features/room_studio/domain/room_layer.dart lib/features/room_studio/domain/mask_bitmap.dart lib/features/room_studio/segmentation/room_input.dart lib/features/room_studio/segmentation/room_mask_processing.dart test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart
```

Exit0: `Formatted 6 files (0 changed)`.

Scoped analyzer:

```sh
dart analyze lib/features/room_studio/domain/room_layer.dart lib/features/room_studio/domain/mask_bitmap.dart lib/features/room_studio/segmentation/room_input.dart lib/features/room_studio/segmentation/room_mask_processing.dart test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart
```

Exit0: `No issues found!`

Formatting check:

```sh
dart format --output=none --set-exit-if-changed lib/features/room_studio/domain/room_layer.dart lib/features/room_studio/domain/mask_bitmap.dart lib/features/room_studio/segmentation/room_input.dart lib/features/room_studio/segmentation/room_mask_processing.dart test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart
```

Exit0: `Formatted 6 files (0 changed)`.

Per the controller's scoped-fix instruction, the full suite was not rerun for this round. The earlier 613-test full run is historical evidence for the initial implementation, not a fresh result for this correction.

Self-review compared the production/test changes against `/private/tmp/color-lab-task2-fixbase.WwPMj3/source`: only the fit block and new 49×49 regression changed, plus this appended report. Existing wide/tall/extreme geometry, interpolation/reference bytes, mapping/closing/inverse alignment, alpha tests and public APIs remain verified by the 21 covering tests. No native builds, installs, dependency changes, subagents, or other task work. No unresolved concern remains from this finding.
