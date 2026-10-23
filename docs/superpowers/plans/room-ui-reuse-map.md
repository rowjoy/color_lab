# Read-only Room UI and preview reuse map

Prepared by `/root/room_ui_reuse_map` for Tasks8–10. No edits/tests/rendering were
performed by the mapper. Line numbers refer to the pre-editor source.

- `lib/features/picker/domain/photo_viewport.dart:20`: contain fit multiplied by
  zoom, centered in viewport plus pan. `normalizedAt`33 rejects letterboxes;
  `positionOf`47 is inverse. Right/bottom boundaries can yield1: clamp pixel
  indices. The value class does not itself validate sizes or constrain zoom.
- Actual sampler screen is
  `lib/features/picker/presentation/photo_picker_screen.dart`, not a file named
  photo_view_screen. Anchored pinch1–8 is at51–83; image/gesture container298–336.
  Reuse transform math, not immediate sampling-on-down or cancel-as-up semantics.
  Mask strokes buffer until accepted up, cancel on second pointer/tool/photo
  change, and split segments after leaving the image.
- `PreparedPhoto` contains already-oriented opaque PNG and matching immutable
  RGBA. Draw its preview unchanged; overlay, vector preview and hit testing must
  all share the identical PhotoViewport rect.
- `room_screen.dart:25–32`: CTA goes after heading, before illustration. Preserve
  illustrated semantics36/57, chips65 and explorer100. Update the lower future
  photo-editing copy88–95 truthfully: masks are not recolor/export.
- `room_color_provider.dart:4` stays independent. Color explorer113 sets its
  illustrated wall color and navigates `/room`; retain the existing Use in Room
  action and history/LAB behavior.
- `app_router.dart:26` globally guards preferences/onboarding; root list36 is
  suitable for `/room/masks`, keeping retained `/room` branch124. Back pops or
  goes `/room`, not a controller reset. Current-route/mounted acquisition guards
  must be supplied by the new editor; none exist in the old Room screen.
- `StudioPage(name:'RoomMasks')` provides required `screen-RoomMasks` scroll key,
  shared padding and max width640 (`studio_page.dart:17–22`). Root editor still
  needs deliberate title/Back behavior.
- `tool/render_previews.dart`: fonts41, themes54,390×844/DPR1 viewport56,
  ProviderContainer overrides92, real app/RepaintBoundary155, router203;
 360×800/2×/reduced-motion precedent412–465; capture helper729 writes PNGs at2×.
  Restore accessibility/viewport after narrow cases, avoid pumpAndSettle during
  indefinite progress, and use distinct names because collisions overwrite.
- Existing preview listing has104 PNG filenames (52 bases × light/dark); preserve
  those exact names/loops. Existing synthetic photo189 and camera747 are layout
  fixtures, not real model-output evidence. New previews require a portable
  recorded output from the verified model, not a dependency on temporary files
  or invented masks presented as AI. Previews themselves are not native proof.

This map is preparatory context, not a code-review verdict or replacement for
the task briefs. Acquisition source was intentionally outside its read scope.
