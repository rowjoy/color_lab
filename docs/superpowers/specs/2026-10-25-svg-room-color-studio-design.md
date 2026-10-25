# SVG Room Color Studio

Date: 2026-10-25. Status: approved by the user for implementation planning.

## Intent

Color Lab will give people who are preparing to paint or furnish a room a safe,
fast way to compare coordinated colors before spending money. The first sample
is an original dedicated study-room illustration. It is deliberately
watermark-free and does not reuse either supplied reference image. Future
releases can add bedrooms, bathrooms and other room templates without rewriting
the editor.

The sample starts in black and white so that the transition is obvious. Choosing
a recommended look colorizes the whole editable room. If the first action is a
custom surface color, the editor first applies the template's recommended base
look and then replaces that surface, so the result is a complete colored room
rather than one colored patch in an otherwise grayscale scene.

This is a visual planning aid. Recommended combinations are curated starting
points, not claims that one color is universally best or that a display exactly
predicts physical paint, material, lighting or camera appearance.

## Goals

- Add one detailed, responsive, full-screen study-room SVG.
- Let users independently change Wall, Ceiling, Floor and Furniture colors.
- Offer complete, room-appropriate recommended palettes and a reusable custom
  HEX/saved-color picker.
- Begin in grayscale, provide an explicit return to grayscale, and show a fully
  colored room after the first color choice.
- Save named room designs locally and durably; reopen, edit and delete them
  after an app restart.
- Retain the existing real-photo **Visualize your room** workflow as a separate
  tool.
- Preserve existing **Use in Room** handoffs: an externally chosen color opens
  the study editor with the recommended base look and that Wall override.
- Make another template an asset/catalog addition rather than another editor.
- Cover the state, persistence, SVG mapping, interaction and responsive layout
  with automated tests.
- Run formatting, analysis and tests only. Do not build, install or package an
  APK, IPA or native artifact.

## Non-goals and anti-goals

- No real-photo segmentation or paint simulation is added here; that existing
  editor remains independent.
- No paint-brand matching, room-light measurement, calibrated display promise,
  purchasing advice or assertion of a universal "best" palette.
- No import of arbitrary user SVGs and no online room/template download.
- No image-generation dependency and no copyrighted watermark, screenshot
  control or traced reference artwork.
- Do not duplicate SVG geometry in Dart paths merely to recolor it.
- Do not overwrite or merge saved illustrated designs with saved colors,
  palettes or real-photo session state.

## Approaches considered

### 1. Template-driven SVG regions — selected

Each illustration is one SVG asset whose editable elements use stable region
IDs and reserved source colors. A typed template catalog supplies its name,
asset, editable surfaces, recommended looks and default look. One shared editor
renders every template, maps the reserved SVG colors to the current design and
stores saved designs independently.

This has the best up-front-to-future-work balance. The official `flutter_svg`
package supports asset rendering and a `ColorMapper` callback that can
substitute individual SVG colors/IDs during parsing. The scene remains one
vector illustration, scales cleanly, and new rooms do not need new screen
logic. It adds one Dart package and requires disciplined SVG IDs/colors.

### 2. `CustomClipper<Path>` overlays — rejected for room regions

Clipping colored Flutter widgets into hand-authored paths works for a few large
polygons, such as a simple wall or ceiling. A useful study room also contains
desk fronts, shelves, chair pieces and overlapping furniture. Recreating those
paths in Dart duplicates the SVG geometry, is easy to misalign at different
sizes and makes every future room a code task. Flutter also documents arbitrary
`ClipPath` clipping as more expensive than simpler clip shapes.

`ClipRect` or `ClipRRect` may still constrain the outer viewport or rounded
sheet; `CustomClipper` will not own the editable surfaces.

### 3. Raster image plus surface masks — deferred

This can look more photographic, but it is not the requested SVG medium and
requires aligned mask assets per image. It remains a possible future template
type, not part of this implementation.

## Study-room visual contract

The original wide scene uses a calm one-point perspective and includes a back
wall, visible ceiling/floor, large desk, drawers, office chair, bookshelves,
window and curtains, desk lamp, framed artwork, rug and plants. It is a dedicated
study room with no bed. Neutral line work, highlights, shadows, screens, books,
plants and small decor use authored colors in colored mode; only the four named
material groups are user-editable. In the untouched state the renderer also
converts those decorative colors to grayscale, so the whole scene is genuinely
black and white before the first choice.

The SVG has a fixed `viewBox` and uses explicit fills rather than CSS classes.
Every editable path belongs to one of these stable IDs/reserved colors:

| Surface | SVG group ID | Reserved source fill |
| --- | --- | --- |
| Wall | `surface-wall` | `#FF00A1` |
| Ceiling | `surface-ceiling` | `#00E5FF` |
| Floor | `surface-floor` | `#B7FF00` |
| Furniture | `surface-furniture` | `#7A00FF` |

The unusual source colors are authoring tokens and are never shown. The SVG
renderer maps them either to four grayscale values or to the active design.
Highlights and shadows sit above those fills as translucent geometry, so
recoloring preserves depth. In grayscale mode the mapper converts non-token
colors to luminance; in colored mode it returns them unchanged. Duplicate or
mis-grouped surface tokens fail structural asset validation rather than
silently coloring the wrong material.

## Recommended looks and first-color behavior

The study template ships with at least four complete, named looks. The exact
HEX values are a builder-owned visual-design decision, but each fixture pins a
literal Wall, Ceiling, Floor and Furniture color and includes:

- a calm focus look built around a muted sage or blue-green wall;
- a bright focus look with light warm neutrals;
- a cool concentration look with a restrained blue-gray wall; and
- a warm creative look with earth tones.

The catalog marks one as **Recommended**. It is the base used when a user
customizes the untouched grayscale room. The UI describes why a look may work
for a study without claiming objective superiority.

The draft has two explicit visual states:

1. `grayscale`: no editable colors are active and Save is disabled.
2. `colored`: all four surface colors are non-null and Save is enabled.

Applying a recommended look atomically enters `colored`. Picking a custom color
from grayscale first copies the recommended base look, overrides the selected
surface, and enters `colored`. Later custom changes replace only the selected
surface. **Black & white** returns to `grayscale` after confirmation when the
current colored draft is unsaved. Reopening a saved design always enters
`colored`.

## Full-screen experience

The Room tab continues to introduce both experiences: the existing real-photo
button and an illustrated-study entry. The study opens on a root
`/room/study` route outside the indexed tab shell so the artwork can use the
full device viewport without the bottom navigation bar.

The editor contains:

- a safe-area close/back action and the room name;
- the vector scene using `BoxFit.contain`, with optional pan/zoom only if the
  final phone layout makes small details unusable;
- an unobtrusive current-state label (`Black & white` or the active look/name);
- surface chips for Wall, Ceiling, Floor and Furniture, each showing label,
  swatch and HEX when colored;
- horizontally scrollable recommended-look cards;
- **Custom color**, **Black & white**, and **Save design** actions; and
- a saved-designs entry that lists, reopens, renames and deletes designs with
  confirmation.

On portrait phones, controls live in a draggable/collapsible bottom sheet over
the scene and remain reachable with large text and keyboard insets. In short
landscape and wide layouts, the same controls become a fixed side panel. The
close action never scrolls away. Touch targets are at least 48 logical pixels.
Changing colors cross-fades between cached SVG renderings using existing motion
tokens; reduced-motion mode switches immediately.

The first version does not make SVG furniture parts individually tappable.
Users select the clearly labeled surface chips, which is predictable for touch,
keyboard and screen-reader users.

## Domain and state

The illustrated editor uses a model separate from `RoomLayerColors`, whose
meaning and lifecycle belong to the real-photo editor.

- `IllustratedRoomSurface`: wall, ceiling, floor, furniture.
- `IllustratedRoomPalette`: stable ID, localized-ready name, short guidance and
  a complete four-color map.
- `IllustratedRoomTemplate`: stable ID, title, SVG asset, surfaces, default
  palette and ordered palettes.
- `IllustratedRoomDraft`: template ID, grayscale/colored state, four active
  colors when colored, optional source palette ID and dirty/saved identity.
- `SavedRoomDesign`: stable ID, user-visible name, template ID, complete surface
  colors, created/updated timestamps and schema version.

The typed catalog is Dart data. Adding a room requires an SVG plus one catalog
entry and palette fixtures; it does not require another state controller or
screen. The controller owns template selection, palette application, custom
surface changes, grayscale reset, save/update and saved-design reopening.

The current session draft survives route changes and theme changes. Closing an
unsaved colored draft asks for confirmation. A successfully saved draft is
clean until changed again. Storage failures keep the current draft visible,
show friendly retry feedback and never report a design as saved.

## Persistence

Add a dedicated repository contract and Hive-backed implementation using a new
`illustrated_room_designs_v1` box in the existing private app directory. It
follows the project's durability barrier: mutations serialize, flush before
success is published, and a failed flush blocks later apparent success until a
retry succeeds. Corrupt or unsupported records are preserved and surface a
recoverable load error; they are never silently cleared.

The serialized record contains only validated primitive values. IDs and
template IDs are stable strings; colors are canonical six-digit HEX values;
timestamps are UTC ISO-8601 values; schema version is `1`. Names trim outer
whitespace, have a bounded length, and default to `Study room - <local date>`
when the user does not enter one. Saving a clean existing design is a no-op;
saving edits updates the same ID and `updatedAt` while retaining `createdAt`.

Deletion requires confirmation and does not alter the current draft unless it
is the deleted design; in that case the visible colors remain as an unsaved
copy. Templates are not persisted in the box. If a future app lacks a saved
design's template, the record is retained and shown as temporarily unavailable.

## Existing integrations

- The shared `showMixerColorPicker` provides manual HEX and saved-color
  selection. Cancel makes no draft change.
- Ordinary entry begins in grayscale even though a recommended palette exists.
- An existing **Use in Room** color handoff skips grayscale, applies the default
  complete palette plus that color as Wall, and opens the study editor.
- Saving a room design does not automatically save its four colors to History.
- The real-photo Room editor, its four photo layers and its current session are
  unchanged.
- Theme changes affect controls but do not remap the authored room palette or
  reset the draft.

## Dependency and asset handling

Add `flutter_svg` with a lockfile-resolved compatible version and register
`assets/rooms/`. Use `SvgPicture.asset` with a dedicated `ColorMapper`; do not
read and mutate raw XML strings at runtime. Keep SVG features within the
package's supported static subset and validate the asset with the package's
vector-graphics compiler during source verification if the compiler is already
available. This check is not an app/native build and must not download or build
native artifacts.

If dependency resolution needs network access or native build hooks, stop and
request permission rather than bypassing the project's verification guard.

## Error, accessibility and honesty

- A missing/incompatible SVG shows a safe illustrated-room error with Retry and
  Back; controls do not pretend a color was previewed.
- Storage load/save/delete errors retain the last durable list and current
  draft, with no raw exception text.
- Scene semantics announce the template and its four current surface colors,
  or that it is black and white. Decorative SVG internals are excluded.
- Selected surface/look state is exposed to semantics independently of color;
  swatches always include names and HEX text.
- The information panel states that screen, room lighting, paint finish and
  material can change the real result and advises testing a physical sample.

## Test-first acceptance

Tests are written and observed failing before product implementation.

### Pure model/controller tests

- a fresh draft is grayscale with no saveable design;
- every recommended look is a complete four-surface literal fixture;
- applying a look colors all four surfaces atomically;
- the first custom choice seeds the default look and overrides only its target;
- subsequent choices and reset affect the intended state only;
- external Wall handoff seeds the complete look and overrides Wall;
- dirty/clean transitions, save/update/reopen/delete behavior and template
  switching are deterministic;
- malformed HEX, duplicate IDs, incomplete palettes and unsupported templates
  fail validation without partial state.

### Repository tests

- real-file save, close and fresh reopen retain exact names, IDs, colors and
  timestamps;
- update retains creation time and survives restart;
- deletion survives restart;
- concurrent writes serialize;
- flush/read/corruption/schema failures preserve data and expose retry; and
- one repository box cannot collide across different private directories.

### Renderer and widget tests

- grayscale maps all four SVG tokens to the pinned neutral values and converts
  authored decorative colors to luminance;
- colored mode maps each token to the selected surface and preserves authored
  non-token colors;
- a missing or duplicate surface mapping is rejected by validation;
- initial screen is visibly/semantically black and white with Save disabled;
- selecting each recommended look makes all surface chips colored;
- custom picker cancel is a no-op, and a valid choice changes only its target
  after full-color seeding;
- Black & white confirmation, save, rename, reopen and delete flows work;
- **Use in Room** opens the colored scene with the intended Wall color;
- current draft survives theme and route changes;
- portrait phone, 640x360 short landscape, tablet, 2x text, keyboard insets,
  both themes and reduced motion show no overflow and keep Close/controls
  reachable; and
- existing Room photo, color handoff, Palette and whole-app navigation tests
  remain green.

Tests assert observable mapping/state and rendered behavior, not source-string
presence or mocked widget existence. A mutation of any surface mapping, first-
custom seeding, durability barrier or stale template ID must fail at least one
test.

## Verification and delivery constraints

Use the repository's guarded commands and existing Flutter installation:

1. format check for changed Dart files;
2. targeted domain, repository, renderer and widget tests;
3. full `flutter test --no-pub` suite;
4. full `flutter analyze --no-pub`; and
5. optional guarded vector-graphics compatibility check for the new SVG.

Do not run `flutter build`, Gradle, CocoaPods, Xcode, native compilers, install,
clean, destructive data operations or artifact packaging. Report any dependency
cache/guard limitation honestly. Preserve all unrelated working-tree changes.

## Builder-owned details

The builder may refine exact original SVG geometry, palette HEX values, neutral
grayscale values, responsive breakpoints, control labels and file boundaries,
provided the behavior and accessibility contracts above remain intact. The
builder may omit pan/zoom if the final responsive scene remains legible without
it. These decisions do not change product scope.
