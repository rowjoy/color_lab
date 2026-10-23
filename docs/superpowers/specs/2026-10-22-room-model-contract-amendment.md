# Room model contract amendment

Date: 2026-10-22. Status: adopted within the user's subsequent explicit direction
to test models and integrate the best tested option, retaining auto and manual.
This amends only the model/input/host-verification parts of the
[approved Room design](2026-10-22-room-auto-masking-design.md).

The intended outcome stays the same: import a room photo, generate actual offline
Wall/Ceiling/Floor/Furniture masks, then allow brush, erase and exact undo. No
APK/native build, install, clean or data clearing. Android 24/iOS 13 remain fixed.

## Recommended artifact and semantic contract

Use MLCommons MOSAIC R4 `mobile_segmenter_r4_quant_argmax_uint8.tflite`,
`mlcommons/mobile_open` revision `404e4c284d01b1c9e415b09d7cf8aa0648c4015d`, SHA-256
`da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c`.
Its 1,978,000-byte size is an explicit exception below the 5–15 MB target.
The [comparison report](../plans/room-model-comparison-report.md) records exact
primary sources and actual native runs against DeepLab UINT8 and MOSAIC FLOAT32.
Selection balances footprint, host timing and observed masks, not universal
accuracy or target-phone performance. The earlier DeepLab feasibility proposal
is superseded as the production choice; its evidence remains historical.

Replace the previous 151-class assumption with 32 output IDs: original ADE20K
IDs 1–31 plus unscored slot 0. All requested classes exist. Bind layers exactly
to Wall `{1}`, Ceiling `{6}`, Floor `{4}` and Furniture `{8,11,16,20,24}`.
Door 15, windowpane 9, armchair 31 and every other nonzero class remain unselected
and protected. Slot 0 is excluded/unscored, not a promised detector of all other
objects. Preserve ignored-only morphological closing and discrete ownership.

This is a correction to our earlier model-contract assumption, not a removal of
any requested room layer. Complete descriptor labels are:

```text
0 unscored, 1 wall, 2 building, 3 sky, 4 floor, 5 tree, 6 ceiling,
7 road, 8 bed, 9 windowpane, 10 grass, 11 cabinet, 12 sidewalk,
13 person, 14 earth, 15 door, 16 table, 17 mountain, 18 plant,
19 curtain, 20 chair, 21 car, 22 water, 23 painting, 24 sofa,
25 shelf, 26 house, 27 sea, 28 mirror, 29 rug, 30 field, 31 armchair.
```

## Fixed tensor and image recipe

Input UINT8 `[1,512,512,3]`, scale `0.007843137718737125`, zero point128; output INT32
`[1,512,512]`, valid IDs 0–31. Validate native metadata and exact byte lengths.
Feed RGB bytes directly, not normalized/requantized values; pin byte 255 → 255.

Add an explicit descriptor `inputEncoding: rgbUint8` / typed
`RoomInputEncoding.rgbUint8`. Retain `channelMeans=[0,0,0]` and
`channelStdDevs=[1,1,1]` as identity metadata for the existing getter contract.
The raw encoding bypasses generic quantization; native scale/zero point remain
validation metadata. This is a fixed-model contract, not an arbitrary-model API.

Replace the plan's centered/rounded input fit with top-left content, floor-sized
aspect fit to longest side 512, minimum one content pixel, aligned-corner
bilinear RGB and bottom/right padding `[123,115,103]`. Retain the exact inverse
transform; remove padding before mapping output to the working photo. Orientation,
alpha-on-white and working-photo limits stay as approved.

Clamp interpolated channels to 0–255 and truncate to UINT8. A one-pixel output
dimension samples source coordinate zero, avoiding division by zero in aligned-
corner interpolation. Pin these boundaries with independent literal tests.

The app will not JPEG-reencode an already prepared photo. Record the deterministic
Dart recipe and its decoder/interpolation differences from historical TensorFlow
preprocessing. Task 1 must freeze a separately generated reference input plus
independent literal pixels; Task 2 must match it. Do not claim byte-for-byte
TensorFlow equivalence based on this spike.

## Public host verification without SDK patches

Keep exact `tflite_flutter 0.12.1`. Normal unit/widget tests stay under Flutter.
Replace only the real-model host smoke command with a documented task-local
Flutter-kernel harness using the package's unmodified prebuilt dylib and a copy
of the existing prebuilt tester. No native compilation, SDK/pub-cache edits or
private TensorFlow binding access. Exclude copied host binaries from delivery.

During implementation add `tool/run_room_model_smoke.dart` as the staging wrapper;
run it with the existing Dart SDK, a validated explicit Flutter SDK root and a
fresh task-local directory. It compiles `tool/verify_room_model.dart` to Flutter
kernel bytecode, stages prebuilt host resources, launches that verifier and
propagates failures. The verifier exercises the **production runner**, not the
throwaway spike code. Task 5 extends it to the **default production worker
factory**, including actual bundled-asset loading. That asset/service path still
needs validation; the current file-input probe does not establish it.

Keep missing-library/model, incompatible metadata, malformed/out-of-range output,
and absent supported surface as nonzero smoke failures. Never skip native work
and count it as AI success. Pure tests, full suite, analyzer, formatting and UI
previews remain independent gates. Host TFLite 2.11.0 is recorded separately from
Android/iOS runtime versions; physical-device compatibility remains unverified.

## Implementation plan impact and unchanged scope

| Task | Required plan adjustment |
| --- | --- |
| 1 | UINT8 asset/hash and 32 labels; explicit raw encoding, notices/reference checks; staged production-runner smoke wrapper. |
| 2 | Four-layer/exact five-furniture-class mapping, direct RGB byte transfer, floored top-left fit/padding and independent transform/reference tests. |
| 5 | Real default-service smoke uses the staged host harness; prove asset loading and worker ownership before manual work. |
| 10 | Updated smoke command, truthful fixture/runtime documentation and exclusion of host binaries. |

Tasks 3–4 and 6–9 retain their existing interfaces and requirements. Acquisition,
candidate/committed revisions, error versus empty AI result, overlay geometry,
brush ownership, 20-command/16 MiB undo and source-only delivery do not change.
No extra furniture class, cloud service, recolor/project/export feature or
manual-first fallback is added.

## Remaining acceptance and approval

The real-photo spike found visible mask errors, including people/furniture and
floor-boundary confusion. It supports feasibility, not general segmentation
quality or a completed Room editor. Preserve honest mask-preview copy and the
original AI/manual correction order.

The user has explicitly delegated tested model selection and integration while
retaining both auto/manual tools. The previously approved architecture and
Subagent-driven method remain in force; the plan's exact Task1/2/5/10 text is
updated for this selected model and host smoke. The ledger records the executor's
scope/selection rulings. Regenerate Task1's brief before implementation. The first
Task1 attempt remains historical; production AI gates must still pass before
manual brush/erase/undo work starts. No comparison result alone marks a product
task complete.
