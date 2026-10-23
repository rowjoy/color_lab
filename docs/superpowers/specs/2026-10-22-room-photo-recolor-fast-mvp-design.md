# Room photo recolor Fast MVP

Date: 2026-10-22. The user approved this reduced scope in chat. This document
records that decision for implementation review.

## Outcome

Color Lab will reuse its current offline room masks so a user can assign a
different color to Wall, Ceiling, Floor, and Furniture, see a lighting-aware
preview of the prepared room photo, switch between Before and After, refine the
masks with the existing tools, and export the latest result as a PNG through the
system share sheet.

This Fast MVP deliberately does not wait for the separate 24-photo protection-
model benchmark. Automatic masking quality therefore stays exactly as it is
today. The benchmark and any future protection model remain independent work.

## Scope

Included:

- four nullable, session-only layer colors;
- deterministic LAB recoloring of the current prepared photo and edited masks;
- inward-feathered boundaries that never recolor a differently owned pixel;
- After/Before buttons, per-layer color controls, and the existing manual mask
  editor on the same Room screen;
- off-UI-isolate rendering with stale-result rejection;
- sharing the current, fully rendered PNG using the existing `share_plus`
  dependency.

Excluded:

- a new model, protection pass, corpus download, annotation, or quality claim;
- durable room projects, full-resolution originals, gallery-write permission,
  cloud processing, AR, paint quantity, finish simulation, or color undo;
- APK/native build or physical-device performance claims.

## State and ownership

`RoomMaskDraft` remains the canonical session snapshot. It gains immutable
`RoomLayerColors` and an independent nonnegative `colorRevision`. A color
change increments only `colorRevision`; accepted Add, Erase, Undo, and Restore
AI operations increment only `maskRevision` and preserve colors. Importing a
new photo starts with four null colors.

`RoomLayerColors` has explicit nullable fields for Wall, Ceiling, Floor, and
Furniture. Null means keep the source pixel unchanged. The illustrated Room
study's `roomColorProvider` remains separate.

A derived preview is identified by `(photoId, maskRevision, colorRevision)`.
The UI may retain the previous valid image while a newer one renders, but it
must label the update and may export only the frame whose key matches the
current draft. Riverpod/provider identity rejects late frames without allowing
them to mutate the draft.

## Recoloring

Rendering always starts from `PreparedPhoto.rgbaBytes`, never a previous
preview. For each assigned layer, collect LAB lightness from pixels owned by
that layer and calculate deterministic 5th, 50th, and 95th percentiles using
`floor(p * (n - 1))`. For source lightness `Ls` and target lightness `Lt`:

```text
d = Ls - L50
darkScale  = min(1, Lt / max(1, L50 - L05))
lightScale = min(1, (100 - Lt) / max(1, L95 - L50))
Lr = clamp(Lt + d * (d < 0 ? darkScale : lightScale), 0, 100)
```

Combine `Lr` with the target LAB `a` and `b`, use the existing D65 LAB-to-sRGB
conversion, and blend with the source using a radius-2 feather. Feathering is
ownership-bounded: coverage is zero unless the pixel's discrete owner is that
same layer. Because ownership is exclusive, every output pixel uses at most one
target and composition order cannot change the result. Unassigned and
unselected pixels are copied byte-for-byte; output alpha is 255.

The renderer validates aligned dimensions and detached byte lengths. It returns
an immutable opaque RGBA frame plus encoded PNG bytes. Work runs in a temporary
isolate and owns no persistent native resource.

## Experience

The existing `/room/masks` destination becomes the Fast MVP editor without
adding another route. When a draft is ready it shows:

1. an image viewport with **Before** and **After** controls;
2. four surface cards showing the layer name and assigned HEX or **Not set**;
3. **Choose color** using the existing mixer color picker and **Reset color**;
4. **Share PNG**, enabled only for a current successful frame;
5. the existing Move/Add/Erase, brush, Undo, Restore AI, and overlay controls
   under **Refine masks**.

While rendering, keep the last valid image visible and show **Updating
preview...**. A preview failure leaves the source, colors, and masks intact and
offers **Retry preview**. Share errors show a short inline/SnackBar error and do
not clear the session. The system share sheet is the export surface, so Color
Lab requests no new storage permission and does not promise automatic Gallery
saving.

## Verification

TDD covers four-color state transitions, byte-identical untouched pixels,
lighting preservation, ownership-bounded feathering, deterministic output,
stale preview rejection, color persistence through manual mask edits,
Before/After behavior, and export of only the current frame. Final source-only
verification runs focused Room tests, the complete Flutter test suite, analyzer,
and read-only formatter behind the repository's native-compiler deny guard.

