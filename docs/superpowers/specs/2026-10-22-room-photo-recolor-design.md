# Room Studio offline photo recoloring

Date: 2026-10-22. Status: approved by the user for implementation planning.

This specification adds realistic, offline recoloring of a user's prepared room
photo. It depends on the completed
[automatic-mask module](2026-10-22-room-auto-masking-design.md) and supersedes
that document only where it defers LAB photo recoloring, Before/After comparison
and the photo destination of **Use in Room**. Its acquisition recovery, working
photo limits, exclusive editable masks, exact mask undo, session lifetime and
stale-result rules remain in force.

The product outcome is simple: a user takes or chooses a room photo, waits for
real local analysis, assigns different colors to Wall, Ceiling, Floor and
Furniture, and sees a believable digital preview that retains the photograph's
lighting and texture. The source working photo is immutable. This is a visual
aid, not a calibrated prediction of physical paint, material, lighting or
camera color.

## Scope

This module includes:

- the existing Take/Choose room-photo flow and a **Visualize your room** entry;
- a quality-gated hybrid analysis pipeline: primary room segmentation,
  protected-object processing and image-edge-aware fusion;
- separate nullable color assignments for Wall, Ceiling, Floor and Furniture;
- deterministic LAB recoloring at the existing prepared-photo resolution;
- a synchronized draggable Before/After comparison;
- direct access to the existing Add, Erase, Undo and Restore AI masks workflow;
- the shared manual HEX, color details, saved-color and palette entry points;
- honest stage-based progress, cancellation, retries and retained prior results;
- session retention across navigation and theme changes.

Suggested combinations, opacity/strength controls, color-change undo/redo,
durable room projects, full-resolution source retention, image export/share,
multi-project libraries, cloud inference, model downloads, live-camera AR and
physical-paint simulation remain outside this first version. Recoloring stays
at the current oriented, opaque working image's maximum 1600-pixel long edge.

## Experience and loading flow

Room keeps the illustrated study as a separate local demonstration, but its
primary real-photo action becomes **Visualize your room**. The photo editor has
two explicit modes:

1. **Preview colors** is the default ready mode. It shows the recolored working
   photo, Before/After comparison and the four surface color cards.
2. **Refine masks** exposes the current Move, Add, Erase, Undo, Restore AI masks,
   layer, brush-size and mask-overlay controls. The mask overlay remains labeled
   as a mask and is never presented as a painted result.

After acquisition starts, progress text is driven by actual pipeline entry
events. Stages may be skipped when their work is already complete, and the UI
must not hold a stage open to simulate activity:

1. **Preparing photo**
2. **Finding room surfaces**
3. **Protecting objects**
4. **Refining edges**
5. **Building preview**

Do not show an invented percentage or fake mask animation. A visible **Cancel**
action logically invalidates the candidate immediately. If the operation has
not completed after five seconds, retain its actual stage and add **Still
working locally...**. A native call may finish physically after cancellation,
but none of its later progress, success or error events may alter visible or
committed state.

The previous committed photo, masks, colors and valid preview remain available
through replacement analysis. A replacement commits only after the complete
hybrid result, aligned data and an exactly sized, correctly keyed RGBA preview
payload are validated. The viewport retains its prior visible frame until the
new payload decodes and swaps atomically. Cancellation or any required-pass
failure returns to the prior session. With no prior session, it returns to the
empty acquisition state.

## Preview interaction

The Preview colors view uses one photo coordinate system and one pan/zoom
transform. The draggable divider only clips the immutable prepared photo and
the current recolored result; both sides therefore stay registered during zoom
and pan. Its initial position is 50 percent. Divider position, zoom and pan are
view state and increment neither mask nor color revision.

Provide **Show original** and **Show result** buttons as keyboard and screen-
reader-friendly alternatives to dragging. These controls change comparison
visibility only. They do not switch into Refine masks, change `showOverlay`,
modify assignments or mutate pixels.

Each surface card shows its layer name and either its assigned color/HEX or
**Not set**. Selecting a card selects the target layer. Choosing a color assigns
it to that layer; a null assignment leaves that layer's pixels byte-identical
to the prepared source. **Reset layer** is immediate. **Reset all colors**
requires confirmation when at least one assignment exists. The first version
has no color undo stack: mask Undo remains an exact mask operation and color
reset remains a separate action.

Changing a layer or color never reruns AI analysis and never discards mask
edits. A color change schedules a new preview while retaining the previous
valid frame as explicitly marked last-preview content. While the keys differ,
the UI shows **Updating preview...** and must not label the older pixels as the
new selected color. On rendering failure, Before stays usable, the last frame
remains clearly marked, and an inline **Retry preview** action does not rerun
inference or hide Refine masks.

Returning from Refine masks to Preview colors renders the existing assignments
through the updated ownership map. Accepted Add, Erase, Undo and Restore AI
masks operations increment `maskRevision` and preserve assignments. Restore AI
masks keeps colors but resets the editable mask and mask history to the fused AI
baseline.

## Color handoff

**Use in Room** becomes a handoff to the real-photo editor rather than writing
only the illustrated wall provider:

- When a committed room photo exists, apply the chosen color to the currently
  selected surface and open Preview colors. Wall is the selected default before
  the user has made a layer choice.
- When no committed photo exists, retain one pending handoff color for Wall and
  open the photo-acquisition experience. Apply it only after the candidate
  analysis and initial preview succeed. Failure or cancellation keeps it staged
  for a later attempt in the same session; a newer handoff replaces it.

The illustrated study's own preset color remains independent. A photo
assignment is not automatically saved to History or Palettes, and choosing an
existing saved/manual/palette color does not rewrite that source record.

## Committed state and invariants

`RoomMaskDraft` remains the canonical immutable committed photo snapshot and is
extended with:

- an aligned immutable protected-object matte;
- exactly one nullable `RgbColor` assignment for every `RoomLayer`;
- a nonnegative `colorRevision` independent of `maskRevision`.

The protected matte is an 8-bit coverage map at working-photo dimensions. It is
evidence from the complete automatic pipeline, not confidence invented from the
current argmax segmentation output. A nullable layer color means original
pixels, not a transparent or default paint. Every effective assignment change,
including a reset, increments `colorRevision` once. Layer selection, editor
mode, comparison position, overlay visibility, tool and brush size do not.

The existing `aiMasks` field becomes the fused automatic ownership baseline;
`masks` remains its editable descendant. Both stay discrete and exclusive: each
working pixel belongs to at most one of Wall, Ceiling, Floor or Furniture.
Protected evidence removes automatic surface ownership before that baseline is
published.

Automatic protection is not an uneditable veto. A deliberate Add stroke may
reclaim a falsely protected pixel for the selected layer. Such a manual
override is derived where current ownership differs from fused AI ownership and
the current owner is nonzero. Final protection still clamps feathering on all
neighboring pixels that were not deliberately reclaimed, so an Add stroke does
not disable protection for an entire object. Erase and Undo retain their current
literal semantics.

Navigation, Back, indexed-tab changes and theme changes retain the committed
photo, masks, assignments, selected layer, preview mode and divider during the
current app session. App/process restart resets room content because project
persistence is deferred. A successful ordinary photo replacement clears the
old colors, mask history and view transform and selects Wall; an explicit
pending Use in Room handoff initializes only Wall on the new photo. Replacement
requires confirmation when manual mask edits or any color assignment exists.

## Hybrid analysis pipeline

The candidate pipeline is sequential and entirely local:

1. Prepare and validate the oriented working photo through the existing bounded
   processor.
2. Run the selected primary room segmentation and align its surface labels to
   the exact working pixels.
3. Run a bundled protective foreground/object pass capable of addressing
   failures that primary class IDs cannot, especially a person mislabeled as
   Furniture. Merely re-reading the same hard argmax label does not qualify as
   this pass.
4. Fuse primary surfaces, protected evidence and source-image edges. Protected
   evidence wins over automatic surface ownership. Preserve a discrete editable
   ownership result and separately derive bounded antialias weights.
5. Validate dimensions, value ranges, exclusivity and protection, then render
   the initial source or pending-color preview.
6. Publish the complete candidate atomically only when its operation and photo
   identity are still current.

The protective pass may be a secondary bundled model or another independently
validated bundled vision component selected by the feasibility gate below. All
artifacts, licenses, descriptors, preprocessing and output contracts must be
pinned and versioned. Do not infer confidence from the existing MOSAIC argmax
IDs. All preprocessing, inference, fusion, statistics and rendering run outside
the UI isolate. Native inference is serialized; it does not create an
interpreter per rebuild.

One physical analysis may run with one replaceable latest request waiting.
Superseded queued requests are dropped. A required primary, protection, fusion
or validation failure is an analysis failure; it never silently publishes an
unprotected fallback as an enhanced result. If no complete candidate passes the
quality gate, the existing MOSAIC masking feature remains available unchanged
and this enhanced recoloring release is reported as a feasibility no-go.

## Edge weights and composition

Edge refinement never destructively blurs the editable ownership map. It derives
per-layer coverage weights for rendering. At every pixel:

- total effective layer weight is between zero and one;
- remaining weight belongs to the immutable source photo;
- fully protected pixels have zero automatic layer weight after all smoothing;
- only an explicit manual Add override can relax protection at that exact pixel;
- a layer's weight is zero unless the current ownership map assigns that pixel
  to the same layer; and
- output is independent of selected layer and composition order.

All four assigned layers are composed in one deterministic pass from the
prepared source, never by recoloring an already recolored frame. Edge smoothing
is inward or ownership-bounded; it can reduce coverage near a boundary but can
never spread one layer into a pixel owned by another layer or by the unselected
background. Normalize weights defensively before composition rather than
painting layers sequentially. Consequently an unassigned layer and every
unselected pixel remain byte-identical to the prepared source.

For stored protection value `P` in 0...255, automatic effective coverage is the
ownership-bounded edge weight multiplied by `(1 - P / 255)`. At a deliberate
manual Add override pixel, use `P = 0` only for that pixel; protection remains in
force around it.

## LAB recoloring contract

Use the existing D65 sRGB/LAB conversions. For each assigned layer, calculate
robust source lightness statistics from its automatically or manually owned
interior pixels: the 5th percentile (`L05`), median (`L50`) and 95th percentile
(`L95`). An interior pixel has the same owner throughout its clipped 5x5
neighborhood. If no interior pixels exist, use all owned pixels. Sort their L*
values and select deterministic zero-based index `floor(p * (n - 1))` for
percentile `p`. An empty layer produces no recoloring.

For source lightness `Ls` and target LAB lightness `Lt`, retain local contrast
around the layer median while limiting avoidable clipping:

```text
d = Ls - L50
darkScale  = min(1, Lt / max(1, L50 - L05))
lightScale = min(1, (100 - Lt) / max(1, L95 - L50))
Lr = clamp(Lt + d * (d < 0 ? darkScale : lightScale), 0, 100)
```

Use `Lr` with the target color's `a` and `b`, then convert through the existing
gamut-clamping LAB-to-sRGB path. The preserved per-pixel L difference carries
source shadows, highlights and luminance texture; the target chroma replaces the
old surface hue. Composite source and recolored candidates using the normalized
edge weights in linear sRGB, then encode the aligned opaque preview. There is no
hidden strength adjustment in this version.

Percentile selection, interior rules, conversion constants, rounding, gamut
clamping and blend space form a versioned algorithm contract. The same RGBA
source, masks and assignments must produce identical RGBA output across runs on
the same supported runtime.

## Revisions, scheduling and cache

The visible composite key is:

```text
(photoId, maskRevision, colorRevision, algorithmVersion)
```

Preview resolution is fixed to the prepared working photo, so it is not a
variable key in version one. `algorithmVersion` identifies model artifacts,
fusion, protection, edge-weight and LAB-render rules. Analysis caching uses
photo identity plus analysis version; color changes never invalidate inference.

Preview rendering uses one active worker request and one replaceable latest
request. Rapid color changes coalesce to the newest key; no unbounded queue or
parallel full-image renders are allowed. Retain a single current preview cache
entry plus the immutable prepared source. Any progress event, render response,
error or decoded image carries its operation/key and is checked after every
asynchronous boundary. Stale output is disposed and cannot replace, blank or
report an error against newer content.

Color changes do not alter the edit-selection token used to validate an
in-flight mask stroke. Mask completion validates captured `photoId` and
`maskRevision`, then merges accepted mask data into the latest matching draft,
preserving assignments and `colorRevision` even if a color change replaced the
immutable draft object while the stroke was running. Conversely, an accepted
mask mutation invalidates its old render key and schedules the latest color
assignments against the new mask.

Analysis, mask-edit and preview failures have separate status so a preview error
cannot hide a valid editor or offer an irrelevant analysis retry.

## Component boundaries

| Component | Responsibility |
| --- | --- |
| Existing acquisition coordinator | Source selection, bounded photo preparation, recovery intent and destination-safe delivery. |
| Hybrid analysis coordinator | Real stage events, primary/protection/fusion sequencing, candidate validation and cancellation identity. |
| Primary segmentation worker | Versioned surface inference and aligned hard labels. |
| Protection worker | Independently validated people/window/door/decoration evidence with a pinned offline contract. |
| Edge fusion engine | Exclusive fused AI ownership, retained protection and normalized render weights. |
| Extended room draft/controller | Atomic candidate/commit lifecycle, layer assignments, separate revisions, mask history and stale guards. |
| LAB preview renderer | Deterministic source-based statistics, recolor, normalized composition and bounded latest-work scheduling. |
| Comparison viewport | Shared geometry, Before/After clipping, pan/zoom, decoded-image lifecycle and accessible alternatives. |
| Color handoff | Pending/default-Wall behavior and direct delivery from shared color details to the photo editor. |

Do not reuse the current flat-tint mask overlay as the recolor renderer. Keep it
as the diagnostic mask display inside Refine masks. Reuse shared theme tokens,
buttons, color models, picker surfaces and viewport math without unrelated
refactoring.

## Error and recovery behavior

- Acquisition cancellation/error preserves the pending handoff and committed
  session.
- Analysis failure preserves the candidate for Retry analysis and the complete
  previous committed session for return.
- A structurally valid analysis with no supported surfaces is distinct from a
  failure. It can commit, shows all layers as Not detected/Not set and permits
  manual Add before coloring.
- Preview rendering failure preserves the source, masks, assignments and last
  valid keyed frame, clearly marks that frame as old and offers Retry preview.
- A layer with no owned pixels may receive a color, but remains visibly labeled
  Not detected and unchanged until the user adds mask pixels.
- Malformed dimensions, nonexclusive labels, invalid matte values, nonfinite LAB
  values or an incorrectly sized output are recoverable errors, never partial
  success.
- Replacing a photo commits nothing from the candidate until the complete first
  frame is ready; a late success/error from the replaced candidate is ignored.

## Model and quality feasibility gate

Model selection is the first implementation gate, not an assumed success. Freeze
a versioned, redistribution-permitted benchmark of 24 distinct real-room photos:
six living rooms, six bedrooms, six kitchens/dining rooms and six other indoor
rooms. Across the set include every supported surface plus people, windows,
doors, wall decoration, furniture touching walls, low-contrast and patterned
surfaces, daylight/artificial light, shadows and reflections. Preserve source,
license and attribution for every fixture.

Two human annotators independently mark paintable ownership and protected
regions at working resolution; disagreements are adjudicated before candidate
tuning. Ground truth, not model class IDs, defines protected people, windows,
doors and decoration. Use a fixed five-working-pixel boundary tolerance and the
same decoded pixels, target colors and settings for every candidate and the
frozen current MOSAIC baseline.

Report per-image, per-layer and macro results. A candidate passes only when:

- macro boundary F1 improves by at least 0.02 absolute over the baseline;
- macro protected-region recolor leakage is at least 10 percent lower;
- macro per-layer IoU is not more than 0.01 below baseline for any Room layer;
- no image regresses by more than two absolute percentage points in protected
  leakage; and
- dated normal/zoomed visual review finds no new severe spill or missing-surface
  defect.

Effective recolor weight of at least `1/255` counts as colored for leakage.
These thresholds apply only to the frozen set and do not support a universal
accuracy claim. A failed gate requires candidate reselection or a no-go report;
it must not be weakened after looking at candidate output.

## Performance and privacy

All analysis and rendering are offline. No photo, mask, color, telemetry or model
request leaves the device. Bundled artifact changes retain Android minimum SDK
24 and iOS 13 and must pass license, operator and runtime compatibility review.

The user-perceived analysis target is five seconds. Measure from the acquisition
coordinator receiving the selected/captured image through first decoded,
correctly keyed preview; exclude time spent in the external picker UI. This
includes photo preparation, model cold/warm behavior, protection, fusion,
initial recolor when a pending color exists, encoding and display decoding.

On one named mid-range physical Android device and one named supported iPhone,
run the frozen 24-photo set and report the first cold run separately. The warmed
p95 must be at most 5.0 seconds with no crash or out-of-memory event; record p50,
p95, worst time, peak memory, OS, hardware, app/runtime and model versions. Host
timings and widget tests do not satisfy this gate. Until separately authorized
physical-device runs produce that evidence, five seconds remains a target and
must not be marketed as a verified guarantee.

## Verification and acceptance

Tests precede product implementation. Required coverage includes:

- independent literal fixtures for protected-map alignment, exclusive fusion,
  normalized weights, manual protection override and empty layers;
- deterministic LAB cases for neutral, saturated and near-gamut targets,
  highlights, shadows, texture, adjacent layers and antialiased/protected edges;
- byte-identical repeated RGBA output, unchanged dimensions and byte-identical
  source pixels wherever effective recolor weight is zero;
- all four independent assignments, Reset layer, confirmed Reset all, pending
  Wall handoff, existing-photo handoff and no automatic History/Palette writes;
- controller races for photo, analysis, progress, mask, color, algorithm and
  decoded-image revisions, including deliberately out-of-order completions;
- rapid color coalescing, render retry, cancellation, replacement atomicity and
  preservation of colors across mask edits/Restore AI masks;
- the complete Preview colors / Refine masks / Before-After flow and unchanged
  existing acquisition, illustration, Capture, Lab, History and Palette state;
- 360 dp width, 2x text, light/dark themes, reduced motion, no overflow, at least
  48 dp actions, visible focus and spoken label/value/selected semantics;
- accessible Show original/Show result operation without requiring divider drag.

Run the actual pinned production model path plus the real recolor renderer on at
least one retained permitted fixture, recording model, descriptor, source, mask,
assignments, output identities and full-pipeline elapsed time. Fake workers and
recorded masks remain unit/presentation tools, not proof of native inference or
accuracy. Manually inspect all 24 benchmark previews at normal and zoomed edge
views and retain the dated accept/reject record.

Fresh full tests, analyzer, read-only formatter, real-model smoke, light/dark
previews, independent code review and a validated cumulative source archive are
source-delivery gates. TalkBack/VoiceOver use, native device performance, memory
and delegates remain physical-device release gates.

The existing no-build boundary remains active for this workflow: no APK/native
build, install, clean or data clearing is authorized by this design approval.
Physical-device work requires separate explicit authorization. Source checks
must not be described as proof of native compatibility, five-second performance
or general segmentation accuracy.

## Delivery order and review boundary

Implementation planning must begin with the fixed-fixture/model feasibility gate.
Only a passing candidate proceeds to state/pipeline integration, deterministic
renderer work, editor/color handoff, then complete source and separately
authorized device verification. A no-go preserves the completed mask module and
reports evidence instead of substituting a lower-quality pipeline.

This document changes no runtime package, model asset, product source or native
configuration. Conversational design approval permits this written specification
only. Product implementation starts after the user approves this file and then
approves the separate implementation plan and execution method.
