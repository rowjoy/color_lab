# Three-model bedroom room-color sample

Date: 2026-10-25. Status: draft for user approval.

## Intent

Add one honest, offline-bundled Bedroom sample that demonstrates how Color Lab
can combine its existing MOSAIC R4 semantic segmentation and MiDaS relative
depth protection with Android ML Kit Subject Segmentation. The sample is the
feasibility gate before expanding the same experience to Bedroom, Study,
Kitchen, Bathroom and Drawing/Living room.

The three models do not vote on the same answer:

- MOSAIC R4 owns semantic labels: Wall, Ceiling, Floor and supported Furniture.
- MiDaS estimates relative inverse depth and removes near objects that MOSAIC
  incorrectly included in Wall.
- ML Kit supplies an optional foreground-confidence mask. It may veto
  foreground pixels from structural Wall, Ceiling or Floor ownership, but it
  never invents a room label and never replaces MOSAIC Furniture ownership.

The original photo remains immutable. Recoloring uses the final fused mask and
the existing manual Add/Erase tools remain the final correction path.

## Honest offline boundary

The Bedroom image and thumbnail are packaged in the app and require no network.
No precomputed runtime mask is bundled in this prototype: selecting the sample
always follows the live analysis path. Any retained diagnostic mask is test
evidence tied to exact model and image checksums, not an editor shortcut.
Inference always receives the original full-color pixels even when the initial
UI preview is rendered in black and white.

This design does not describe ML Kit as bundled or immediately offline. The
[Android Subject Segmentation API](https://developers.google.com/ml-kit/vision/subject-segmentation/android)
is beta and its model is supplied through Google Play services. It can work
on-device after that module has downloaded,
but it can be unavailable on first use or on devices without the required Play
services support. MOSAIC plus MiDaS therefore remains the required baseline and
ML Kit is fail-open enhancement only. The current iOS path remains MOSAIC plus
MiDaS because Google's current
[release table](https://developers.google.com/ml-kit/release-notes) does not
publish the corresponding iOS Subject Segmentation artifact.

The existing MOSAIC/MiDaS model setup policy is unchanged. This prototype does
not bundle, replace or silently redownload either existing model.

## Bedroom sample asset

Create one original, watermark-free photorealistic 3:2 Bedroom bitmap for the
project. It should be level, evenly lit and naturally textured, with a broad
plain wall, visible wall/ceiling boundary, visible floor, a canonical bed,
simple chair or cabinet, and one small foreground object such as a lamp or
plant that can demonstrate protection. Avoid people, pets, mirrors, screens,
strong reflections, murals, extreme wide-angle perspective, heavy pattern,
deep shadow and clutter.

Generate the asset as a full-color image, inspect it for visual defects and run
the actual existing MOSAIC/MiDaS pipeline against it. Regenerate or reject it
when the supported room regions are not plausible. Do not hand-paint a mask and
present it as model output. Record the final generation prompt, output path,
dimensions and asset provenance in the project documentation.

The sample starts visually in black and white only at presentation time. The
source pixels, AI inputs, manual masks and exported result remain based on the
full-color asset. Choosing a look or custom surface color switches the editor
to the colored/recolored result without re-running inference.

## User experience

Add a **Try Bedroom sample** action before the existing Gallery and Camera
actions on the Room Masks empty state. Selecting it loads the bundled image
through the existing bounded `PhotoProcessor`, bypassing native picker intent,
permissions and recovery receipts. Replacing an existing draft keeps the
current confirmation and atomic replacement behavior.

The prototype exposes an **AI mask steps** diagnostic for this bundled sample.
The normal editor starts in black and white; its original full-color photo is
visible only after the user explicitly opens this diagnostic:

1. Original full-color photo.
2. MOSAIC semantic ownership overlay.
3. MOSAIC plus MiDaS wall protection.
4. ML Kit foreground confidence, only when a real result is available.
5. Final fused mask and recolored preview.

The diagnostic never fabricates an ML Kit result. When the Android module is
not ready, the fourth step says **Foreground protection unavailable** and the
final step truthfully shows MOSAIC plus MiDaS. On iOS and unsupported platforms,
the diagnostic explains that the baseline protection is active. A technical
failure is non-blocking and does not discard the photo or previous draft.

After analysis, the existing Wall, Ceiling, Floor and Furniture color controls,
Before/After preview, full-screen mask editor, manual correction and share flow
remain available. The sample-specific diagnostic is informational and does not
add another editable mask state.

The previously requested durable saved design and direct **Save to gallery**
action are not delivered by this feasibility prototype. The existing session
draft and Share PNG behavior remain unchanged. Persistence and gallery saving
must be restored to scope in the later five-room product design; approving this
Bedroom prototype must not be interpreted as completing those requirements.

## Processing architecture

Introduce a narrow `RoomSubjectSegmentationService` returning an immutable,
source-sized quantized confidence map plus an availability status. The default
unsupported implementation returns immediately. Android uses a dedicated
platform channel such as `com.colorlab/room_subject`; it does not extend the
unrelated game-audio channel.

The Dart side sends the prepared photo's PNG preview plus its width and height.
Those bytes are already EXIF-oriented, opaque and pixel-aligned with the RGBA
buffer used by MOSAIC and MiDaS. Android decodes the PNG, verifies dimensions,
runs ML Kit on the static bitmap, quantizes confidence values from floats to
one byte per pixel, and returns explicit dimensions and bytes. Raw photos or
masks are not written to disk or logged.

Start the optional platform request on the Flutter/root side concurrently with
the existing worker request. Keep MOSAIC and MiDaS inside their current owned
inference isolate; a MethodChannel call must not be moved into `_workerMain`.
For the bundled diagnostic request only, extend the worker result to carry both
the immutable raw MOSAIC ownership map and the immutable MiDaS-protected map in
one invocation. Ordinary user-photo requests retain only the final map, avoiding
a second full-size mask in normal session state. The isolate never reruns
MOSAIC merely to render a diagnostic stage.

After the worker returns its depth-protected semantic mask, join a valid ML Kit
result and perform the final pixel fusion in `compute`. Existing request,
cancellation-generation and stale-result guards cover both branches. Convert
the platform future to a safe value/status future immediately when it is
created, so an early native error is never temporarily unhandled while the
worker is still running.

Conceptually:

```text
PreparedPhoto
 ├─ MOSAIC → semantic owners → MiDaS wall protection ─┐
 └─ Android ML Kit → foreground confidence ───────┘
                                                    ↓
                                          conservative fusion
                                                    ↓
                                               final mask
```

The prototype uses an injectable five-second optional deadline. This is a UX
safety bound, not a latency claim, and must be reviewed with later device
evidence. Timeout, missing module, platform error, malformed dimensions or
invalid bytes all resolve to an explicit unavailable status and retain the
MOSAIC/MiDaS mask. They do not turn the whole analysis into an error. A timeout
invalidates that optional request token; its late native completion is ignored
and cannot attach to the current or a newer photo. Refresh AI masks explicitly
retries the optional pass.

Cache the final mask together with the protection status and a pipeline version.
An unavailable cached result must not be described as subject-protected. The
existing explicit refresh invalidation is the route for adopting a module that
became available later.

## Conservative mask fusion

Validate that subject confidence dimensions exactly match the prepared photo.
This single Bedroom experiment uses a conservative byte threshold of 179
(`179 / 255 ≈ 0.70`) and labels it **Experimental foreground protection** in
the diagnostic. This number is a prototype parameter, not a measured accuracy
claim or a production threshold for user photos and the other four samples.
Inspect and calibrate it from a real Android Bedroom capture before expansion.

For each source pixel:

```text
if confidence >= experimental threshold and owner is Wall/Ceiling/Floor:
    owner = Unselected
else:
    preserve owner
```

Never convert a subject pixel to Furniture. Never clear an existing Furniture
owner in this first prototype, because beds, sofas, chairs and tables are also
likely to be foreground subjects and remain user-recolorable. This deliberate
rule means ML Kit cannot protect a person that MOSAIC has already mislabeled as
Furniture; the UI must not claim otherwise. MiDaS runs before subject fusion so
removing subject pixels cannot weaken its wall-plane evidence.

No dilation, edge expansion or class reassignment is included initially. Those
operations require separate visual evidence because they can erase valid wall
or floor near furniture edges.

## Native Android boundary

Use the official Android Subject Segmentation dependency and its install-time
module metadata, preserving Android minimum SDK 24. The platform handler must
be asynchronous, single-request or explicitly serialized, dimension-bounded
and safe when its Activity/engine is detached. It returns stable safe status
codes rather than native exception text.

No new photo/storage permission is required. No iOS stub pretends to run ML
Kit. The iOS service reports unsupported and continues through the existing
two-model pipeline.

## State and failure behavior

- Loading a sample receives the same photo/request identity and stale-response
  protection as gallery/camera imports.
- Cancelling analysis logically releases the UI immediately. Late worker or
  platform results cannot attach to a newer candidate.
- A subject failure preserves the MOSAIC/MiDaS success.
- A MOSAIC or MiDaS failure remains an analysis failure; ML Kit cannot replace
  semantic segmentation or depth protection.
- Final masks retain exclusive ownership labels and current manual edit/undo
  semantics.
- The original sample asset and previous successful room draft are never
  overwritten by an analysis attempt.

## Tests and evidence

Tests precede implementation.

- Pure fusion tests cover exact dimensions, threshold boundaries, immutable
  input, removal from each structural layer, preservation of Furniture and
  Unselected, malformed confidence maps and deterministic output.
- Subject-service contract tests cover quantized bytes, safe availability
  statuses, platform exceptions, timeout and disposal.
- Segmentation-service tests use a fake subject service to prove concurrent
  composition, fail-open behavior, stale/cancelled completion rejection,
  cache status and explicit refresh.
- Controller/widget tests cover the Bedroom sample action, no native picker
  call, replacement confirmation, black-and-white initial presentation,
  diagnostic step labels, unsupported/unavailable states, color activation,
  accessibility and narrow layouts.
- Asset tests require a decodable bundled image, unique catalog identity,
  recorded prompt/provenance and bounded dimensions.
- Diagnostic trace tests prove the raw MOSAIC and MiDaS-protected maps come
  from one worker invocation, are labeled correctly and are not retained for
  ordinary user-photo requests.
- Actual MOSAIC/MiDaS evidence uses the production host runner and retains
  honest diagnostic output. Fake masks are never reported as inference.

The standing no-build instruction remains in force: do not run an Android/iOS
build, APK task, install, clean or device action. Flutter/Dart unit, widget,
analysis and preview checks may run under the existing native-compiler guard.
Consequently, source and MethodChannel contract tests cannot prove that Google
Play services downloads or executes the ML Kit module. Real ML Kit output,
latency and memory remain an explicit Android-device verification gate for the
user or for a later separately authorized native run.

## Expansion gate

Do not generate and integrate all five room samples before reviewing the
Bedroom result. Expansion to Study, Kitchen, Bathroom and Drawing/Living room
requires:

- plausible actual MOSAIC/MiDaS masks on the Bedroom asset;
- a real Android ML Kit diagnostic capture supplied by an authorized device
  run, or an explicit decision to ship the fail-open baseline without it;
- acceptable recoloring and manual correction UX; and
- an agreed asset-size budget.

Kitchen appliances and bathroom sinks, toilets, tubs, mirrors and glass remain
unsupported semantic objects. Their sample descriptions must not imply that
the three-model pipeline makes them separately recolorable.

## Alternatives rejected

- ML Kit Object Detection returns coarse bounding boxes and categories, not
  aligned room-surface masks; using rectangles would color surrounding pixels.
- Replacing MOSAIC with Subject Segmentation loses Wall/Ceiling/Floor/Furniture
  semantics.
- Making Subject Segmentation mandatory would break first-use/offline and
  unsupported-platform behavior.
- Clearing every ML Kit subject from every layer would remove the furniture
  the feature is meant to recolor.
- Bundling hand-corrected masks as if they were live three-model output would
  make the diagnostic misleading.

## Approval boundary

Approval of this document authorizes a detailed implementation plan for the
single Bedroom prototype only. Study, Kitchen, Bathroom and Drawing/Living room
will not be implemented in this phase. Approval also does not authorize a
native build/device run, a platform-minimum increase, durable project saving,
direct gallery saving, or a claim that ML Kit has executed successfully on this
project.
