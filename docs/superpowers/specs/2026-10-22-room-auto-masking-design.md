# Room Studio automatic masks and manual refinement

Date: 2026-10-22. Status: approved architecture; user authorizes tested model
selection and integration, keeping both auto and manual tools.

The original151-class assumption was incorrect for the compact MLCommons models.
After actual comparison, MOSAIC R4 UINT8 is the selected balanced candidate under
the [corrected model contract](2026-10-22-room-model-contract-amendment.md).
The earlier rejected attempt remains historical in its report. Production
runner/service gates remain mandatory; diagnostic comparison is not completion.

Color Lab will generate room masks with a bundled, offline segmentation model,
then let the user correct those masks with brush, erase and undo. This follows
the user's explicit order: **AI auto-masking first, manual refinement second**.
The earlier manual-first proposal is superseded. No APK or native build/install
is authorized for this work.

## Scope and delivery order

This module delivers room-photo acquisition, actual model inference, aligned
layer overlays and manual mask correction. It does not substitute palette
extraction, a fixed polygon or a color threshold for semantic segmentation.

The implementation order is model/runtime validation, automatic masks, then
brush/erase/undo on those masks. The four user-facing layers are Wall, Ceiling,
Floor and Furniture. Furniture combines bed, sofa, chair, table and cabinet,
following the build document's furniture-group mapping. Other classes remain
unselected; they are not implicitly counted as walls or floors.

LAB recoloring, the draggable before/after divider, suggested color combinations,
durable room projects and image export/share are subsequent Room Studio modules.
They are not represented by disabled placeholder tools in this module. Its
overlay is labeled **Mask preview**, not a painted-room result. The original
photo is never overwritten.

## Model selection and validation gate

The selected candidate is the [MOSAIC R4 quantized UINT8 artifact](https://raw.githubusercontent.com/mlcommons/mobile_open/404e4c284d01b1c9e415b09d7cf8aa0648c4015d/vision/mosaic/models_and_checkpoints/R4/mobile_segmenter_r4_quant_argmax_uint8.tflite)
at `mlcommons/mobile_open` revision `404e4c284d01b1c9e415b09d7cf8aa0648c4015d`.
Its actual size is1,978,000 bytes, below the5–15MB target; SHA-256 is
`da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c`.
Preserve the literal MLCommons Association License and applicable notices from
that revision, not a substituted generic license. Provenance and observed
regressions are recorded in `../plans/room-model-comparison-report.md`.

MOSAIC was compared with DeepLab UINT8 and MOSAIC FLOAT32 through the real public
host interpreter on the same photos. It is selected for the measured compact/
host-speed/observed-mask balance, not as a universal accuracy winner. No native
conversion is needed. A person-only/VOC model or cloud service is not substituted.

Before writing model-specific preprocessing, inspect the actual pinned binary
and record its SHA-256, required operators, tensor shapes/types, input scale and
zero point, normalization, output interpretation and semantic label mapping in
a versioned model descriptor. Add the verified asset and notices to
`assets/models/`, `assets/licenses/` and `docs/asset-sources.md` only during the
approved implementation.

The selected binary supplies32 output IDs: original ADE IDs1–31 plus unscored0,
not151classes and not SegFormer's zero-based map. Fixed input UINT8
`[1,512,512,3]` uses raw RGB bytes; scale0.007843137718737125/zeroPoint128 are
native metadata, not an instruction to normalize/requantize input. Output INT32
`[1,512,512]` must be0–31. Wall1/Ceiling6/Floor4/Furniture8,11,16,20,24 are exact;
all other nonzero classes stay protected/unselected. Do not invent confidence.

Preprocessing is top-left aspect fit with floored content dimensions, minimum1,
aligned-corner bilinear/truncated UINT8 and bottom/right RGB123/115/103 padding.
Preserve its inverse transform. Omit a lossy JPEG re-encode and explicitly record
the deterministic Dart/decoder numerical limits. The reference tensor must be
independent of the production preprocessor and pin literal boundary pixels.

Use a pinned `tflite_flutter` package and matching native runtime after checking
their declared platform requirements. The upstream
[README](https://github.com/tensorflow/flutter-tflite#android--ios) mentions API 26,
while its moving [Android configuration](https://github.com/tensorflow/flutter-tflite/blob/main/android/build.gradle)
declares API 19. These conflicting declarations do not establish compatibility
with this app. **Keep Android minimum SDK 24 and iOS 13; do not silently raise
either.** If a compatible runtime or the required model contract cannot be
verified, stop that integration and report the specific constraint rather than
substituting fake masks or enabling manual editing as an AI success.

Actual host smoke uses a task-local copy of the existing prebuilt Flutter tester
and the exact package dylib, compiling only Flutter kernel bytecode. No SDK/pub-
cache patch, private native API or native compilation. The production verifier
must exercise the real runner and later the default worker factory/asset loading;
the file-input comparison probe alone is not that gate. Host2.11.0 and mobile
dependency versions are reported separately. Copied host binaries are not shipped.

## Photo acquisition and recovery

Room offers **Choose room photo** and **Take room photo**. Both use a
source-aware system image-picker adapter and the existing bounded photo
processor. The current live camera route remains a color sampler; it is not
repurposed as still-photo capture. Camera access starts only after the explicit
Take action, never when entering Room, restoring state or retrying inference.

Retain the current 24 MiB acquisition limit and processor limits of 32 MiB,
24 million decoded pixels and a 16,384-pixel maximum axis. The working photo is
EXIF-oriented, composited onto white when transparent and reduced to a maximum
1600-pixel long edge. Inference and masks use those same working pixels. This
module does not retain an original-resolution source or promise full-resolution
export. Existing supported formats and safe errors remain unchanged.

Introduce one app-scoped acquisition coordinator for Capture and Room. One gate
covers picker invocation, preparation and startup lost-data recovery. Finish
that single recovery attempt before admitting a new picker request, so a new
intent cannot replace an older result's destination. Screens must not
independently consume `retrieveLostData`. Keep the current Capture photo/palette
flow intact behind that shared boundary.

Before opening the external picker, durably flush a small operational intent
containing schema version, request ID, source and destination. Use a separate
record with existing Hive infrastructure, not a room-project database. A failed
intent write must not launch the picker. Resolve/clear the intent with the same
serialized failure handling before admitting another request. This metadata is
necessary to route Android process-death recovery to the initiating feature.

Recovered or late results do not steal navigation or silently replace a room
draft. Offer explicit continuation at the recorded destination. If intent is
missing or invalid, offer an explicit destination choice instead of assuming
Capture. Cancellation, picker errors and busy responses preserve existing
content. The operational intent does not make the room photo or edits durable:
without the later project module, those drafts reset after process death.

Receipt delivery has a synchronous acceptance boundary after durable intent
clearing. The coordinator keeps its gate and prepared receipt until an optional
`accept(photo)` callback returns true. A rejected or throwing callback leaves
the same photo pending for explicit continuation, even if operational metadata
was already cleared. Active screens check ownership and dispatch navigation
inside this callback, without another await between checking and delivery. A
retained Room controller may instead accept into its still-current candidate;
if its screen hid during clearing, that candidate waits for explicit analysis.
This prevents an owner disappearing during storage I/O from losing the photo.
Requests also accept an optional synchronous active-owner guard. Check it before
request-triggered initialization, after recovery and after intent persistence,
immediately before native launch. A rejected/throwing guard cancels that launch;
durably clear only this request's saved intent, preserving a storage retry
barrier if clearing fails. This does not cancel an already-started native call
or replace the app-owned startup recovery/onboarding gate.

## Automatic masking pipeline

1. Accept a prepared candidate with a new photo revision. Keep the last successful
   room draft intact while processing its replacement.
2. In a dedicated worker, resize/normalize according to the verified model
   descriptor. Preserve the aspect ratio and retain the scale/padding transform;
   map output back through the inverse transform so masks align with the photo.
3. Run the bundled model through the real interpreter. Keep inference and pixel
   preprocessing/postprocessing off the UI thread; no runtime model download or
   network call is allowed.
4. Convert verified ADE20K IDs to the four room layers. Preserve a single owning
   layer per working pixel, with unselected/background as the remaining value.
5. Apply a small 3×3 morphological close, filling only the model's ignored pixels;
   protect all other predicted classes, including unselected doors/windows.
   Resolve fill conflicts in stable Wall, Ceiling, Floor, Furniture order.
   Map labels back with the inverse aligned-corner transform: for a source axis
   of length one sample content coordinate0; otherwise sample nearest coordinate
   `round(sourceCoordinate * (contentSize - 1) / (sourceSize - 1))`, adding the
   recorded padding and clamping to the content. This applies to both upscaling
   and downscaling. The comparison fixture's floor-selected sparse diagnostic
   points do not define inverse geometry. Then derive smoothed mask alpha
   with a feather radius of 1–2 working pixels. The editable ownership map stays
   discrete; feathering is a derived display mask, not a destructive label edit.
6. Publish the completed candidate atomically only if its photo/request revision
   is still current. Cache its original AI masks and current editable masks for
   that room session. A stale success/error must not attach to a newer photo.

One worker owns interpreter use; native inference calls do not overlap. Cancel
invalidates the request and keeps the UI navigable, but does not pretend to
interrupt an in-flight native call. Close/reuse the interpreter only after its
current invocation settles. No unbounded queue or extra interpreter per rebuild.

Malformed outputs, unsupported operators and runtime failures are errors with
**Retry analysis** and **Choose another photo**. They never produce an apparently
successful empty mask. A successful, valid inference with no supported surfaces
is a distinct result: explain that nothing was detected and allow manual marking
after that completed AI pass.

## Room experience and state

Room remains the entry tab and retains its clearly labeled illustrated color
study. A separate guarded mask editor owns the real photo workflow; opening it
does not initialize a camera or discard existing Capture state. Existing
**Use in Room** continues to select the illustrated study's color until the LAB
recolor module connects it to actual photo painting. Photo masks stay independent
of that selected color and of history, palettes and other Lab drafts.

The editor has empty, acquiring, analyzing, ready and recoverable-error states.
During analysis, show the candidate photo and meaningful progress text, not fake
mask animation or invented percentages. A previous successful draft remains
available for return if replacement fails or is cancelled.

When ready, show the photo, **Mask preview**, layer chips and selected-layer
coverage. The overlay must be distinguishable from paint. Allow viewing the
unmodified photo without changing any mask. A class with zero detected area stays
selectable for later manual addition and is labeled as not detected.

Back, tab navigation and theme changes retain the current in-memory draft.
Replacing a photo or restoring AI masks requires confirmation when edits exist.
Replacement discards the previous masks/history only after the new inference
succeeds; cancellation or failure keeps them. No saved colors or palettes are
automatically written. The draft and pending candidates have separate revision
tokens so asynchronous work cannot overwrite newer decisions.

## Manual brush erase and undo

Manual tools become available **only after a valid AI pass**. They operate on
the selected layer's ownership map. Add assigns touched pixels to that layer,
removing previous ownership there; Erase removes only the selected layer, leaving
other layers unchanged. Preserve the original AI result as the reset baseline.

Use explicit Move, Add and Erase tools. Move supports zoom/pan. Brush tools map
touches through the same image viewport transform, ignore letterbox space and
cancel/roll back an incomplete stroke when another pointer changes the gesture.
No accidental painting during pinch zoom. Brush diameter ranges from 1% to 20%
of the working image's shorter side, default 5%, with a visible size control.

Show a lightweight stroke preview while dragging. Rasterize and commit the
stroke in the worker, guarded by photo/mask revision. Serialize mask mutations;
do not accept overlapping edit commits. Undo restores the exact pixels changed
by one accepted stroke. No-op and cancelled strokes create no history entry.

Keep at most 20 undo commands and at most 16 MiB of typed pixel-delta buffers,
evicting oldest commands first. Empty Undo is disabled. **Restore AI masks**
requires confirmation and explicitly clears manual edits and undo history.
Replacement clears history only when the replacement draft commits. Redo,
multiple projects and mask file persistence are outside this module.

## Component boundaries

| Component | Responsibility |
| --- | --- |
| Shared acquisition adapter and coordinator | Source selection, one native picker lock, durable recovery intent and destination-safe delivery. |
| Pure room mask model | Validated dimensions, immutable ownership/alpha snapshots, layer mapping, photo and mask revisions. |
| Segmentation worker service | Model descriptor validation, preprocessing, real inference, output alignment, smoothing and cache lifecycle. |
| Refinement engine | Image-coordinate stroke rasterization, exclusive layer edits, bounded deltas and exact undo. |
| Retained room controller | Candidate versus committed state, stale completion guards, replace/reset confirmation and tool selection. |
| Mask editor presentation | Accessible photo viewport, layer overlays, progress/errors and explicit editing actions. |

Reuse existing theme tokens, shared controls, processor and viewport math. Limit
cross-feature edits to the acquisition/recovery boundary and Room entry/routing;
do not refactor unrelated tools. New native configuration must be limited to the
verified runtime's packaging needs, with no extra permission or platform-minimum
change hidden in dependency setup.

## Verification and acceptance

Tests precede product implementation. Pure fixtures pin label/background mapping,
padding/orientation transforms, non-overlapping ownership, feather bounds, exact
brush/erase/undo pixels, empty classes and history budgets. Async tests cover
stale inference/edit responses, cancellation, replacement atomicity and retained
drafts. Acquisition tests cover both sources, one global lock, durable intent
failure, lost-data destination and late results on another tab.

Run at least one real bundled-model inference on a redistribution-permitted
room-image fixture using a supported host interpreter. Record tensor metadata,
actual output and manually checked surface alignment. Fake worker tests alone
do not establish AI execution. Distinguish reference-image smoke checks from
general room accuracy, which is not guaranteed by one fixture.

Full-app tests cover the real editor flow, AI-before-manual ordering, failures
versus empty detections, layer selection, zoom/brush mapping, exact undo/reset,
replacement/Back/theme behavior and unchanged Capture/history/Lab state. Check
360 dp width, 2× text, both themes, reduced motion, readable overlays and at least
48 dp controls. Fresh full tests, analyzer, formatter, light/dark previews,
independent review and a validated cumulative source ZIP are delivery gates.

The no-build instruction remains in force: **no APK/native build, install, clean
or data clearing**. Existing APK and all nine preceding source ZIPs stay unchanged.
Native Android 24/iOS device execution, inference latency and memory on physical
devices remain explicit verification limits until separately authorized. Source
checks must not be described as proof of native compatibility or mask accuracy.

Concurrent-artifact clarification during execution: the user confirmed running/
building from another place. The newer APK timestamp2026-10-22 02:24:15+0600 and
SHA-256 `00896beade2a82a2f99908e203b1f4c56a07daa8ef678dcd7f13d85a220d2ae7`
replace the old artifact's bytes through that user action. Preserve it untouched
and disclose the difference; do not restore an old APK or claim the original
checksum still matches. This does not authorize this workflow to build an APK.

Latest artifact observation supersedes the specific preserved bytes above:
both APK copies now hash
`eb36f749379d33e82644e6c61861647ccb88c685479ff780bd3bd2959fa0a3ae`,
162,563,223 bytes, modified2026-10-22 10:37:35+0600. The origin of this later
change is not attributed. Preserve these currently observed files untouched,
without restoring a historical hash. This workflow did not build or touch them.
Nine prior ZIP hashes still match; Android24/iOS13 configs remain byte-identical
to original baseline. The historical sequence above remains evidence of the
earlier observation, rather than a requirement to preserve obsolete00896 bytes.

## Review boundary

The user approved this written design and then accepted the implementation plan
on 2026-10-22. Execution uses the recommended Subagent-driven method, beginning
with the real-model feasibility gate. This design document itself changes no
runtime package, model asset, product code or native configuration.
