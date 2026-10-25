# Polished 3D illustrated-room artwork upgrade

Date: 2026-10-25. Status: approved by the user for implementation planning.

This design is a visual-only amendment to
`2026-10-25-realistic-multi-room-svg-gallery-design.md`. Where the documents
differ, this document owns only the authored appearance of the six SVG room
assets. The existing gallery, editor, colors, routes, persistence and export
behavior remain unchanged.

## Intent

Convert the current Living, Bedroom, Study, Dining, Kitchen and Bathroom
illustrations from clean flat vectors into polished semi-realistic 3D-style
editable SVG scenes. They should feel like premium architectural/interior
visualizations through believable geometry, depth, lighting and material cues,
while remaining deterministic pure SVGs whose Wall, Ceiling, Floor and
Furniture base colors can still be changed independently.

The generated Study concept shown in the design conversation is a visual
direction reference only. It is a raster mockup, not an asset to trace, embed or
ship. The finished rooms remain original vector artwork and should be slightly
cleaner and less photographic than that reference.

For this workspace, the exact inspected reference is:

- `/Users/jamirulislam/.codex/generated_images/01a17103-2927-7020-9d7d-ab4a4eec1a4a/exec-5f1d4bd9-09e0-4d41-a5d4-73f3029fa161.png`
- 1536 x 1024 RGB PNG
- SHA-256 `718dab98328f6156dabb2b6ea9dc5d229b7c0b61226a7d5375968805597f5851`

This file is non-shipping design evidence outside the repository. Inspect it
when authoring the Study pilot. If it is unavailable in a later workspace, the
visual-target, lighting, material and Study-specific sections below remain the
portable authority; do not substitute another generated image silently.

## User-approved approach

Use pure layered SVG artwork. Preserve each editable surface as a flat reserved
base token, then build volume with neutral translucent highlight, shade, contact
shadow and material-detail geometry above it. No raster texture, filter, script,
animation, new renderer or new color-control model is introduced.

This was selected over:

1. SVG plus raster textures, which could look more photographic but would break
   the existing safe-SVG contract and make recoloring/export less predictable.
2. New Wood/Upholstery/Cabinet controls, which would improve material separation
   but would change the UI, state, palettes and saved-design schema instead of
   keeping everything else the same.

## Invariants: everything except artwork stays the same

Implementation may re-author only these production assets:

- `assets/rooms/living_room.svg`
- `assets/rooms/bedroom_room.svg`
- `assets/rooms/study_room.svg`
- `assets/rooms/dining_room.svg`
- `assets/rooms/kitchen_room.svg`
- `assets/rooms/bathroom_room.svg`

Related SVG contract tests, exact render anchors, deterministic preview fixtures
and artwork documentation may be updated. Do not change:

- Flutter presentation, navigation, responsive layout or full-screen controls;
- the gallery card structure, text, Draft badges or Saved Designs access;
- the black-and-white first state;
- the four Wall, Ceiling, Floor and Furniture color controls;
- catalog IDs, asset paths, surface labels, focal points or 1200 x 800 artboards;
- palette IDs, names, HEX values or market guidance;
- session drafts, durable saved designs or Hive schemas;
- 2400 x 1600 PNG export behavior;
- real-photo AI masking, Room AI models or photo acquisition;
- dependencies, `pubspec.yaml`, platform configuration or platform minimums.

No native build, app install, clean or device-data operation is part of this
work.

## Visual target

The rooms should read as polished 3D-style vector interiors at phone-card size
and at full exported size. Realism comes from authored geometry rather than
photographic noise:

- coherent one- or two-point perspective;
- architectural thickness at windows, doors, trim, counters and cabinets;
- clear foreground, midground and background overlap;
- curved, proportionate furniture silhouettes rather than mostly rectangles;
- top, front and side material planes;
- directional window light, warm practical-light pools and restrained bounce;
- object-shaped cast shadows and fitted contact shadows;
- ambient-occlusion bands at wall/floor, furniture/floor and joinery contacts;
- sparse scalable material cues such as wood grain, seams, folds, grout,
  porcelain curves, stone speckle and metal/glass highlights;
- small natural asymmetry and imperfection without clutter.

The target is not a photograph. Avoid depth-of-field blur, lens effects, dense
noise, glossy render artifacts and details too fine to survive a gallery card.

## Editable color and shading contract

Keep the existing exact surface groups and tokens:

| Surface | Required group | Reserved base token |
| --- | --- | --- |
| Wall | `surface-wall` | `#FF00A1` |
| Ceiling | `surface-ceiling` | `#00E5FF` |
| Floor | `surface-floor` | `#B7FF00` |
| Furniture/cabinetry | `surface-furniture` | `#7A00FF` |

Every main editable object starts with its surface token on one or more base
planes. Lighter faces, darker faces, edge highlights, recesses and seams use
neutral white, black or restrained fixed neutral colors with opacity. Reserved
tokens never appear in gradients, definitions, decoration or another surface
group. Do not author fixed lighter/darker variants of a token, because custom
user colors must remain the only base hue.

Every major editable furniture object should have at least three visible form
cues where its geometry permits: a base-colored primary face, a lighter/top
plane or edge, and a darker side/recess/contact plane. Furniture still has one
shared user-selected base color. Neutral overlays and fixed hardware may make
wood, upholstery and cabinetry feel different, but the artwork must not imply
that those materials have separate color controls.

Black-and-white mode continues to come entirely from the existing mapper. All
new authored decoration must retain enough luminance contrast after grayscale
conversion for the room, shadows and material shapes to remain readable.

## Lighting rules

Assign one documented dominant light direction per room and keep every shadow
consistent with it. A secondary practical light may add a warm local pool, but
it does not reverse the main cast-shadow direction.

Use SVG-native geometry instead of filters:

- broad translucent polygons/gradients for window light and bounce;
- two or three nested low-opacity paths when a softer cast edge is needed;
- tight dark contact shapes fitted to furniture feet and bases;
- thin low-opacity bands for corner and joinery occlusion;
- restrained white edge highlights on surfaces facing the light.

Do not reuse generic large shadow ellipses beneath unrelated objects. An ellipse
is acceptable only when it matches a genuinely rounded footprint such as a
planter, pedestal or basin.

## Distinct room compositions

All assets retain `viewBox="0 0 1200 800"` and keep their primary comparison
surfaces inside the existing focal/crop-safe area. They should no longer look
like one shell with exchanged furniture.

### Living room

- Use an inviting slightly angled lounge composition with a broad wall and
  natural-light source.
- Give the sofa curved arms, cushion compression, seams and subtle fabric
  tension; give the accent chair its own silhouette.
- Add believable coffee-table thickness, media-console reveals and furniture-
  shaped contact/cast shadows.
- Preserve generous unobstructed wall and floor regions for color comparison.

### Bedroom

- Emphasize the bed as a deep layered form: mattress thickness, headboard
  depth, pillow compression, duvet folds and a grounded bed shadow.
- Add recessed wardrobe/door planes, dimensional side tables and restrained
  timber cues.
- Keep bedding and furniture broad enough to show the single Furniture color
  without flattening the authored textile shading.

### Study room

- Follow the approved polished Study concept direction without copying its
  raster pixels.
- Add a thick desk top, drawer reveals, sparse wood grain, an ergonomic chair
  with curved upholstery, a distinct reading chair and dimensional shelving.
- Use cool window daylight plus a localized warm task-light pool, consistent
  monitor reflection and believable floor shadows.

### Dining room

- Replace the front-on schematic arrangement with a coherent perspective that
  shows table top thickness and foreshortening.
- Vary chair scale by depth, give seats/backs real thickness and overlap them
  naturally around the table.
- Let the pendant create a restrained central light pool and fitted shadows,
  without hiding the wall/floor comparison areas.

### Kitchen

- Add cabinet carcass depth, door bevels, drawer gaps, toe-kicks and counter
  thickness rather than a flat elevation.
- Use restrained stone/counter variation, under-cabinet lighting and coherent
  island perspective.
- Keep appliances, sink and small hardware fixed neutral while cabinetry/island
  bases remain the one editable Furniture surface.

### Bathroom

- Add subtle tile/grout value variation, vanity/cabinet depth, basin and toilet/
  bath curvature, mirror/glass edge highlights and restrained chrome accents.
- Use contact shadows and reflected light appropriate to hard materials.
- Keep sanitary ware, mirror, shower glass and fittings fixed neutral; the
  editable Furniture token continues to mean Vanity & storage.

## Safe-SVG and complexity boundary

Continue to forbid embedded `<image>`, `<filter>`, scripts, animations, external
URLs and remote fonts. Use paths, rectangles, circles, ellipses, polygons,
polylines, lines, local gradients and opacity. Clipping is permitted only when
it remains local, deterministic and supported by the existing renderer and
validator; avoid complex masks.

Target roughly 25-80 KB and 150-400 simple geometry elements per room. These are
review budgets, not reasons to add meaningless detail. A room may be smaller if
it achieves the target, but any asset above the budget requires a measured
render/export justification before acceptance.

Decor must be original, watermark-free and room-specific. Do not repeat the
same mountain picture, window landscape, pendant or plant arrangement across
all six rooms. Reuse a consistent visual language, not identical geometry.

## Composition and crop safety

Gallery thumbnails remain a 3:2 view and the editor may use `BoxFit.cover` on a
portrait device. Keep the main furniture mass, an unobstructed wall sample and
the most informative lighting/material details in the central crop-safe region.
Side decor may be cropped without making the room unrecognizable or removing an
editable surface.

Preserve the existing common exact-color anchor areas where practical:

- Wall near `(600, 220)`;
- Ceiling near `(600, 40)`;
- Floor near `(1100, 760)`; and
- Furniture near `(600, 590)`.

If a richer room composition requires moving a room-specific anchor, update the
test intentionally and retain an unobstructed replacement anchor. Never weaken
the tests merely to accept an ambiguous blended or shadowed pixel.

## Verification and acceptance

Tests are updated before or alongside each asset, room by room.

- Every SVG passes the shared structural contract: canonical viewBox, exactly
  one of each surface group, non-empty correct token geometry, no token leakage,
  no forbidden element/external reference and no watermark text.
- Exact raster anchors prove all four custom colors and grayscale colors still
  substitute without blending at their designated base planes.
- Catalog, routing, session, saved-design, flyout, focus/full-screen and export
  tests remain unchanged and passing.
- Export tests still decode a complete 2400 x 1600 PNG with authored decoration
  and exact editable surface anchors.
- Deterministic previews cover all six rooms in black and white and in their
  default complete look. Inspect phone gallery cards, a portrait fill-screen
  editor, whole-room mode and at least one 2400 x 1600 export.
- Visual review checks light-direction consistency, fitted shadows, material
  readability, crop safety, grayscale contrast, room individuality and absence
  of distorted furniture at both thumbnail and full size.
- Stress previews use a light, dark and saturated custom color combination to
  verify that neutral overlays preserve volume without making the chosen hue
  unreadable.
- Record asset byte/element counts and compare preview/render time with the
  current scenes. Any material regression requires simplifying geometry before
  acceptance.

Use the existing guarded Flutter/Dart source-verification flow. Do not run a
native build or claim physical-device rendering evidence.

## Delivery order

Upgrade one room at a time so visual and token regressions stay attributable:

1. Study as the reference-quality pilot.
2. Living and Bedroom, which exercise upholstery and textiles.
3. Dining and Kitchen, which exercise perspective and cabinetry.
4. Bathroom, which exercises tile, glass, chrome and porcelain.
5. Catalog-wide previews, export inspection and regression verification.

Study establishes the shared visual grammar through contract tests and an
internal comparison with the pinned concept. It is not a separate user-review
pause: after correcting any evident pilot mismatch, implementation continues
through the other five rooms in the same delivery. The approved scope is all
six rooms. Each later room keeps its own architecture and material identity
rather than cloning the pilot.

## Approval boundary

Approval authorizes an implementation plan for the six SVG artwork upgrades and
their directly related tests/previews only. It does not authorize UI/domain
changes, new surface controls, raster assets, dependency/native changes or a
native build.
