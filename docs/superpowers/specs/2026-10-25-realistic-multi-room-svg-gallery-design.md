# Realistic Multi-Room SVG Gallery

Date: 2026-10-25. Status: approved by the user for implementation planning.

This design extends **SVG Room Color Studio**. Where the two documents differ,
this document owns the multi-room catalog, gallery, full-bleed editor, market
looks, per-template sessions and Gallery export. The existing real-photo room
workflow remains a separate feature.

## Intent

Color Lab will offer six original, polished room illustrations so a person can
compare wall, ceiling, floor and furniture colors before painting or buying
materials. The catalog begins in black and white. A person chooses a room,
opens a full-screen preview, applies a coordinated look or a custom color, saves
the design in the app and can export a clean PNG directly to the device Gallery.

The selected visual direction is **pure semi-realistic SVG**. The result should
feel architectural and materially believable through perspective, layered
light, shadows and texture cues. It is not presented as a photograph or as a
calibrated prediction of real paint.

## Goals

- Ship Living room, Bedroom, Study room, Dining room, Kitchen and Bathroom
  templates in the first catalog.
- Make every catalog preview black and white, regardless of any current draft.
- Start a template's first editing session in black and white.
- Show the room edge-to-edge with a persistent compact right-side color rail.
- Let the user independently change Wall, Ceiling, Floor and the room's
  furniture/cabinetry surface.
- Make the first color action produce a complete colored room: a coordinated
  look applies all surfaces; a first custom color seeds the recommended look
  and then overrides the selected surface.
- Provide current Bangladesh-market-informed starting combinations plus custom
  HEX and saved-color selection, while clearly labeling display colors as
  approximations.
- Retain a separate in-memory draft for each room during the app session and
  keep explicitly saved designs durably across app restarts.
- Export only the colored room artwork as a 2400 x 1600 PNG to Photos/Gallery;
  never include editor controls, device chrome or a watermark.
- Keep SVG parsing and export responsive, using existing isolate-backed parsing
  rather than adding unnecessary `compute` calls for lightweight color state.
- Cover assets, state, routing, accessibility, persistence and export with unit,
  widget and integration tests.
- Run source verification only. Do not build, install or package a native app.

## Non-goals

- No claim of photographic realism, AR, 3D rendering, live lighting simulation
  or calibrated color accuracy.
- No brand purchase, availability or universal "best color" claim.
- No network-fetched palettes or templates. Market guidance is versioned app
  content and changes only in an app update.
- No arbitrary SVG import and no reuse, tracing or watermark removal from the
  supplied screenshots.
- No embedded raster image inside an SVG.
- No `CustomClipper` copy of the room geometry. The SVG remains the one source
  of truth for editable regions.
- No automatic Photo Library access or automatic export; access is requested
  only after the user taps **Save to Gallery**.
- No change to the existing real-photo segmentation, masking or share flow.

## Approach selected

Each room is an original SVG with four reserved authoring colors. The shared
renderer substitutes those colors through `flutter_svg`'s `ColorMapper` and
converts all authored decoration to luminance in black-and-white mode. A typed
catalog supplies room metadata, contextual labels, focal alignment and complete
looks. One gallery, editor and persistence system supports all templates.

This was selected over two alternatives:

1. A photo plus aligned masks could look more photographic but would not be an
   SVG, would add large assets and would need separate mask authoring.
2. SVG geometry plus raster textures could add detail but would increase size,
   make recoloring less predictable and risk inconsistent results across rooms.

## User journeys

### Choose a sample room

1. The Room tab continues to show **Visualize your room** for a real photo.
2. A separate **Try illustrated rooms** action opens `/room/illustrated`.
3. The gallery lazily shows six wide black-and-white room cards. On a phone it
   uses one column; on a wide viewport it uses two.
4. Every card has the room name, a short purpose line and a clear action. A
   retained session draft may add a **Draft** badge, but never colors the catalog
   thumbnail.
5. Selecting a room opens `/room/illustrated/:templateId` outside the indexed
   tab shell, so the editor receives the full device viewport.

### Test colors

1. A room with no session draft opens in black and white.
2. **Looks** opens the coordinated-look flyout. Selecting a look colors all four
   surfaces atomically.
3. Selecting Wall, Ceiling, Floor or the contextual furniture button opens that
   surface's flyout. It contains the current color, suggested swatches and
   **Custom color**.
4. If custom color is the first color action, the editor applies the room's
   recommended complete look and replaces only the selected surface.
5. Later custom choices replace only their selected surface.
6. **Black & white** returns the room to its untouched visual state. If the
   current colored draft has unsaved changes, reset requires confirmation.
7. The scene cross-fades between cached renderings; reduced-motion mode changes
   immediately.

Suggested swatches are not separate catalog data. For the selected surface,
they are the corresponding colors from the room's three ordered complete looks,
deduplicated by HEX while retaining look order. Choosing one is a surface
override: from grayscale it seeds the recommended complete look first; from a
colored draft it changes only that surface. The active look label becomes
**Custom combination** unless the resulting four colors exactly match one of
the room's complete looks.

### Leave, return and save

- Back on a dirty draft offers **Keep draft**, **Discard** and **Cancel**.
  Keeping returns to the gallery and retains that template's draft in memory.
  Discarding restores that draft's baseline: black and white for a never-saved
  room, or the last opened/saved colors for an existing saved design.
- Each of the six templates has its own session draft, so exploring another
  room does not destroy the current experiment.
- **Save design** creates or updates a named durable design. Saved designs are
  available across templates and app restarts.
- Reopening a saved design selects its template and restores its four exact
  colors. Deleting the currently open saved record leaves the visible result
  unchanged and reconciles its identity/baseline using the persistence rule
  below; a colored result becomes an unsaved dirty copy.
- Unsaved session drafts are not promised across a process restart; the explicit
  save action is the durability boundary.

Opening a saved design or applying an external **Use in Room** handoff can
replace the retained draft for that target template. If that target draft is
dirty, the initiating screen must offer **Save current** (only when the draft
is colored), **Replace draft** and **Cancel** before navigation or mutation.
**Save current** completes the normal name/save flow and proceeds only after
durable success. A dirty black-and-white draft cannot be saved, so that case
offers only **Replace draft** and **Cancel**. **Replace draft** explicitly
discards the target template's unsaved changes, then opens the saved design or
applies the handoff. **Cancel** leaves both state and navigation unchanged. A
clean target draft is replaced without a prompt. This rule applies even when
the dirty target draft is not the currently visible template.

### Export to the device Gallery

1. **Save to Gallery** is enabled only for a colored room.
2. The editor renders the canonical full room at 2400 x 1600, independent of
   phone shape, current crop or open control flyout.
3. The app requests the narrowest platform access only when needed and writes
   one PNG named `color-lab-<template>-<UTC timestamp>.png`.
4. Success says **Saved to Gallery**. A denial, unsupported platform, full
   storage or write error retains the draft and offers a useful retry or
   Settings action without exposing raw exception text.
5. Sharing may remain a secondary future action; direct Gallery save is the
   required primary export for illustrated rooms.

## Information architecture and compatibility

- `/room` remains the Room tab and introduces the two separate workflows.
- `/room/illustrated` is the sample-room gallery.
- `/room/illustrated/:templateId` is the shared full-screen editor.
- The existing `/room/study` location remains a compatibility redirect to
  `/room/illustrated/study`.
- Existing **Use in Room** actions continue to target Study, apply its complete
  recommended look plus the chosen Wall override, and then open the new editor
  route directly.
- An unknown template route shows an inline unavailable-room state with Back to
  gallery; it never silently substitutes a different room.

## Gallery design

The gallery title is **Choose a room** with the short explanation, "Start in
black & white, then test complete looks or your own colors." It provides Saved
designs in the app bar or header but does not mix saved-design thumbnails into
the six-template catalog.

Cards render from the same SVG asset and grayscale mapper as the editor. They
use `BoxFit.cover` with template focal alignment, a stable 3:2 frame and a text
scrim outside the artwork rather than over important furniture. A card's full
surface is tappable, has at least a 48 logical-pixel action height and announces
the room name plus "black-and-white color-testing template" to assistive
technology. A lazy sliver list/grid avoids decoding all six large scenes before
they are visible.

Load failure is isolated to its card with Retry; the remaining rooms stay
usable. Skeletons retain the final 3:2 geometry to prevent layout jumps.

## Full-screen editor design

The room occupies the complete viewport behind controls. It defaults to
**Fill screen** (`BoxFit.cover`) with each template's focal alignment; a visible
**Full room / Fill screen** toggle lets the user switch to `BoxFit.contain` when
seeing every edge matters. Fill mode may crop the sides on a portrait phone but
must never stretch the SVG. If pan is enabled, it is bounded and Reset view is
available.

A safe-area Back action, room title and view toggle float over the left/top of
the artwork. The persistent right rail is 68 logical pixels on phones and 72 on
larger touch layouts. It contains, in order:

- Looks;
- Wall;
- Ceiling;
- Floor;
- the contextual furniture surface;
- Black & white;
- Designs; and
- Save to Gallery.

Each target is at least 48 x 48, combines an icon with a short visible label,
and exposes the full label, state and HEX value through semantics. The selected
surface also has a shape/border indicator, so selection never depends on color
alone. The rail scrolls vertically on short landscape screens while Back stays
fixed outside it.

**Designs** is one rail target, not two. Its flyout contains the current
**Save design** or **Update design** action followed by **Saved designs** and
their open, rename and delete controls. Its semantic label announces whether
the current colored draft can be saved and how many durable designs exist.

Selecting a rail item opens a flyout immediately to its left without reducing
the artwork's layout width. The flyout is 232-300 logical pixels depending on
available width, scrolls independently, respects keyboard/safe-area insets and
closes by tapping the scene, Back or its close action. On wide screens it may
remain pinned as an overlay. Custom HEX/saved-color selection reuses the existing
`showMixerColorPicker` dialog so keyboard entry is not compressed into the rail.

The **Looks** flyout ends with a **Why these looks?** action. It opens the dated
market-guidance explanation, source/inspiration names and physical-sample
caveat. No additional rail item is required.

The full-artwork semantics node announces either "<room>, black and white" or
the four contextual surface labels and their colors. SVG internals and purely
decorative controls are excluded from the semantics tree.

## Template catalog and visual direction

All six assets use `viewBox="0 0 1200 800"` and a 3:2 composition. Important
editable regions cluster around the template focal alignment so Fill mode still
shows a useful color comparison. All artwork is original and watermark-free.

| ID | Asset | Key architecture and furnishings | Furniture label |
| --- | --- | --- | --- |
| `living` | `assets/rooms/living_room.svg` | sofa, chairs, media console, coffee table, rug, broad window | Furniture |
| `bedroom` | `assets/rooms/bedroom.svg` | bed, headboard, side tables, wardrobe, layered textiles | Bed & furniture |
| `study` | `assets/rooms/study_room.svg` | upgraded desk, ergonomic chair, shelving, window, task lighting; no bed | Desk & furniture |
| `dining` | `assets/rooms/dining_room.svg` | dining table/chairs, pendant, sideboard and framed art | Table & furniture |
| `kitchen` | `assets/rooms/kitchen_room.svg` | cabinetry, island, counters and fixed neutral appliances | Cabinets |
| `bathroom` | `assets/rooms/bathroom.svg` | vanity, storage, bath/shower, mirror and neutral fittings | Vanity & storage |

Semi-realism comes from consistent one- or two-point perspective, architectural
reveals, crown/skirting detail, window depth, restrained gradients, translucent
neutral highlights, contact shadows, believable material seams and two coherent
light sources. Floor seams converge toward the scene's vanishing point and row
spacing increases toward the foreground. Rugs render beneath furniture; small
decor renders after the main editable furniture.

The editable base color supplies each object's main material plane. White and
black overlays at low opacity supply top/side planes, edge highlights, cushion
seams, drawer recesses and shadows, so any user color keeps its volume. Do not
author fixed lighter/darker versions of editable colors. Avoid blur filters,
complex masks and dense patterns that render inconsistently in `flutter_svg`;
use layered vector geometry and restrained gradients instead.

## SVG authoring contract

Every asset contains exactly one of each stable group and keeps its token only
inside the matching group:

| Surface | Required group ID | Reserved source color |
| --- | --- | --- |
| Wall | `surface-wall` | `#FF00A1` |
| Ceiling | `surface-ceiling` | `#00E5FF` |
| Floor | `surface-floor` | `#B7FF00` |
| Furniture/cabinetry | `surface-furniture` | `#7A00FF` |

Reserved colors must not appear in shared definitions, decorations, gradients
or another surface group. Authored decorative colors must not equal a token.
Every editable surface includes at least one intentionally unobstructed anchor
area for exact render testing.

Assets may use paths, polygons, rectangles, ellipses, linear/radial gradients,
clipping limited to the viewport and opacity. They may not contain `<image>`,
scripts, animation, external URLs, remote fonts or unsupported filters. Asset
validation rejects a missing/duplicate group, token leakage, an incorrect
viewBox or an external reference before the asset reaches the catalog.

The existing Study asset is re-authored without changing its path or template
ID. Its tests deliberately update anchor coordinates only where the richer
composition requires it.

## Market-guided looks

Every template has exactly the same three stable look IDs in the first release:

- `warm-natural`, displayed as **Warm Natural**;
- `soft-botanical`, displayed as **Soft Botanical**; and
- `cool-airy`, displayed as **Cool Airy**.

Their guidance text is room-specific, but the display names and IDs do not gain
aliases. The complete literal fixtures are:

| Room | Look ID | Wall | Ceiling | Floor | Furniture | Default |
| --- | --- | --- | --- | --- | --- | --- |
| Living | `warm-natural` | `#E6D8C3` | `#F8F4EB` | `#C5AD8A` | `#7B5944` | Yes |
| Living | `soft-botanical` | `#C4D3C1` | `#F8F4EB` | `#BEB2A2` | `#9A7557` | No |
| Living | `cool-airy` | `#D3E0E4` | `#F7F5EF` | `#B5BEC1` | `#5F493F` | No |
| Bedroom | `warm-natural` | `#DED5C7` | `#FAF6EE` | `#C2A483` | `#785747` | Yes |
| Bedroom | `soft-botanical` | `#C8D3C2` | `#F8F4EC` | `#BCA58A` | `#80614E` | No |
| Bedroom | `cool-airy` | `#D4DFE4` | `#F8F6F0` | `#B7BEC1` | `#67514B` | No |
| Study | `warm-natural` | `#E2D5BF` | `#F8F4EB` | `#C5AA84` | `#72513D` | No |
| Study | `soft-botanical` | `#B7C5B3` | `#F8F4EB` | `#C6AC84` | `#654A39` | Yes |
| Study | `cool-airy` | `#C7D6DF` | `#F6F5F0` | `#B7A083` | `#465967` | No |
| Dining | `warm-natural` | `#D5BCAA` | `#FAF5EC` | `#A98464` | `#704C3B` | Yes |
| Dining | `soft-botanical` | `#C3D0BB` | `#F8F4EA` | `#AC9274` | `#6E5242` | No |
| Dining | `cool-airy` | `#CFDCE0` | `#F8F5EE` | `#AA927D` | `#5C4740` | No |
| Kitchen | `warm-natural` | `#E3D7C6` | `#FAF8F2` | `#BBAF9E` | `#987454` | No |
| Kitchen | `soft-botanical` | `#D8E1D3` | `#FAF8F2` | `#B8B0A3` | `#A7B39B` | Yes |
| Kitchen | `cool-airy` | `#D8E4E6` | `#FBF9F4` | `#B7C0C2` | `#718184` | No |
| Bathroom | `warm-natural` | `#E6DDD1` | `#FBF9F4` | `#C4B8AA` | `#92745F` | No |
| Bathroom | `soft-botanical` | `#D4E0D7` | `#FAFBF7` | `#B8C2BA` | `#789080` | No |
| Bathroom | `cool-airy` | `#D8E5E7` | `#FBFBF8` | `#B9C2C4` | `#8A725F` | Yes |

These literals are UI display approximations pinned in fixtures; they are not
measurements of a branded wet-paint formula. The Study Soft Botanical guidance
may describe its result as focused sage, and equivalent room-specific prose is
allowed, but that prose does not create another palette name or ID.

The static guidance is informed by current Asian Paints Bangladesh material:
light/pastel colors for local light and climate, restrained off-white ceilings,
and combinations around warm neutrals, botanical greens and cool airy tones.
Palette information may mention inspiration such as Gossamer 8052, Milkshake
8012, White Clay 8620, White Cameo L145 and Timber Glaze wood families, but must
say **display preview** and never represent an app HEX as an exact brand formula.
The info flyout says colors vary with screen, daylight, artificial light,
substrate and finish, and advises checking a physical swatch in daytime and
evening before purchase. The content is labeled **Market guide - reviewed
October 2026**, not permanently "trending" or universally "best".

## Domain and session state

The existing four-surface value objects remain separate from real-photo
`RoomLayerColors`.

`IllustratedRoomTemplate` adds:

- localized-ready summary;
- contextual labels for all four surfaces;
- canonical 1200 x 800 export size;
- focal alignment for Fill mode;
- palette review/source note; and
- ordered complete looks plus a recommended look ID.

`IllustratedRoomPalette` retains stable ID, name, guidance and four colors, and
adds optional provenance text. Recommended status is derived from the
template's recommended ID rather than duplicated booleans.

An `IllustratedRoomSession` owns:

- `draftsByTemplateId` for all opened templates;
- `activeTemplateId` while an editor is open; and
- transient view state such as selected surface, open flyout and Fit/Fill mode,
  which is not written into a saved design.

Opening a template creates a grayscale draft only when none exists. Opening a
saved design replaces that template's session draft after handling unsaved
changes. Palette selection, first-custom seeding, dirty/clean transitions and
external handoff remain atomic controller operations. Switching theme, route or
orientation must not reset colors.

Every draft stores an in-memory baseline consisting of mode, colors and saved
design identity. A fresh template's baseline is grayscale with no saved ID.
Opening a saved design makes its colored values the baseline. A successful
create/update save makes the current colored state the new baseline.

`isDirty` is computed by comparing the current mode/colors with that baseline,
not by remembering the last button press. Manually restoring all baseline
colors clears dirty state. Resetting a clean saved design to black and white
retains its saved ID but becomes dirty; **Save design** is disabled because
black and white is not a persistable design, and Discard restores the saved
colors. Resetting a fresh colored draft to its grayscale baseline makes it
clean. Save is enabled only for a colored new draft or a colored dirty saved
draft; a clean saved draft is already durable.

## Saved-design persistence and migration

Continue using the dedicated Hive illustrated-design repository and its flush
before success durability barrier. Saved records already contain stable design
ID, template ID, four canonical six-digit HEX colors, timestamps, name and
schema version, so adding catalog entries does not require a schema bump.

Existing Study designs remain valid because `study` and
`assets/rooms/study_room.svg` stay stable. The v1 saved record has no palette ID;
it stores the four resulting colors, so palette-ID changes need no migration.
When reopened, an exact match to a current palette may show that palette name;
otherwise it is labeled **Custom combination** without altering any color.
Records for an unavailable future template remain stored and are shown as
unavailable rather than deleted.

The saved-design browser can filter by room but defaults to All. Each row shows
the template name, design name, four labeled swatches and last-updated date.

After a durable rename succeeds, the session updates `savedName` in every
retained draft whose `savedDesignId` matches, including drafts for rooms not
currently visible; colors, baseline colors and dirty state remain unchanged.
After a durable delete succeeds, every matching retained draft clears that ID
and name and receives a fresh grayscale baseline while keeping its current
visual state. A matching colored draft therefore becomes a dirty/saveable
unsaved copy; a matching grayscale draft becomes a clean fresh draft. Repository
failure performs no session reconciliation. This prevents a background draft
from later overwriting a rename or trying to update a deleted record.

Save, rename and delete failures keep the last durable state and offer retry.

## Clean PNG rendering

Illustrated export does not reuse `RoomImageExportService`, which currently
shares real-photo PNG bytes. It introduces two injectable contracts:

- `IllustratedRoomArtworkEncoder`, which turns a template plus draft into PNG
  bytes; and
- `RoomGalleryWriter`, which writes validated PNG bytes to the platform photo
  library.

The encoder uses `SvgAssetLoader` with the same `ColorMapper` as the visible
scene, loads the vector picture with `vector_graphics`, draws it into a new
`PictureRecorder` canvas scaled from 1200 x 800 to 2400 x 1600, converts the
result to `ui.Image`, encodes PNG and disposes all pictures/images in `finally`.
This renders the complete canonical artwork and avoids an on-screen
`RepaintBoundary`, editor overlays and device-specific cropping.

The SVG loader already parses/compiles SVG data in a background isolate. Vector
rasterization and `ui.Image.toByteData` remain engine/UI-isolate operations
because `dart:ui` objects are not transferable. No manual `compute` is added for
four colors, file naming or byte validation. If future CPU-only image
post-processing is introduced, it must receive `TransferableTypedData` through
`compute`; it is outside this version.

Only one export may run at a time. The 2400 x 1600 RGBA working image is roughly
15.4 MB before PNG compression; pictures and images are disposed immediately
and no full-resolution export cache is retained. The button shows progress and
cannot be double-tapped while rendering or saving.

The writer validates the PNG signature and a safe filename before invoking the
platform. `gal` 2.3.x is the selected adapter because it supports saving byte
data on the project's Android/iOS and Dart/Flutter range. Direct use is hidden
behind the writer callback so tests never open a real Gallery.

Platform configuration follows least privilege:

- iOS adds `NSPhotoLibraryAddUsageDescription`; the existing read description
  remains for choosing photos.
- Android uses modern MediaStore behavior where available and no broad read
  permission. For `gal` 2.3.x compatibility on this app's Android 7-10 support,
  replace the manifest's current removal rule with exactly
  `WRITE_EXTERNAL_STORAGE` plus `android:maxSdkVersion="29"`, and request that
  legacy write access only on API 24-29. API 30+ receives no storage permission.
  Because this version saves to the general Gallery rather than a custom album,
  do not enable `requestLegacyExternalStorage`. Do not request
  `MANAGE_EXTERNAL_STORAGE` or any media/read permission.

Dependency resolution must use a lockfile-compatible version. If it needs
network access, stop and request permission; do not work around the sandbox or
run native setup/build commands.

## Failures, privacy and honesty

- SVG load/render errors show Retry and Back while leaving the draft unchanged.
- Invalid or incomplete templates fail catalog validation in development/tests;
  production shows the unavailable-room state.
- Export failure never marks a design saved and design-save failure never claims
  the image was exported; these are independent operations.
- Photo Library denial explains why access is needed, supports retry, and offers
  Settings only after a platform denial makes that useful.
- No design, color or exported image leaves the device through this feature.
- The market panel links color inspiration to a date and physical-sample caveat.
- Control contrast is evaluated against the rail/flyout surface rather than the
  changing room image.

## Test-first acceptance

Tests are written and observed failing before product implementation.

### Catalog and asset tests

- exactly six stable template IDs exist in the required order;
- every asset exists, has the 1200 x 800 viewBox and exactly one valid group for
  each reserved token;
- tokens do not leak across groups/definitions and no asset has raster images,
  scripts, external references, filters or watermark text;
- every template has contextual labels, valid focal alignment, exactly the
  three stable complete look IDs and one recommended ID;
- default market-look literals match the table; and
- grayscale and colored renders hit one unobstructed anchor per surface plus
  representative furniture/detail anchors for every asset.

### Model/controller tests

- first open creates a grayscale draft and subsequent open returns that room's
  retained draft;
- six templates retain independent session drafts;
- applying a look updates all four surfaces atomically;
- first custom choice seeds the active room's recommended look then overrides
  only its surface; later choices change only one surface;
- reset, discard, keep draft, reopen saved design and external Study handoff are
  deterministic;
- invalid route/template/palette/color input cannot partially mutate state; and
- existing Study saved records reopen with exact colors after catalog migration.

### Gallery and editor widget tests

- gallery displays six black-and-white cards even when a colored draft exists;
- every card routes to the correct template and exposes complete semantics;
- the editor scene occupies the viewport behind a persistent right rail;
- Fill/Full room never distorts geometry and uses the template focal alignment;
- every rail target is at least 48 x 48 and selected state is not color-only;
- each flyout remains usable on 320 px phones, 390 px phones, short landscape,
  tablet, keyboard inset and 2x text scale without overflow;
- custom cancel is a no-op and all first-color paths create a complete room;
- contextual furniture labels are correct for Bedroom, Study, Dining, Kitchen
  and Bathroom;
- Back keep/discard/cancel, reset confirmation, save/reopen/rename/delete and
  reduced-motion behavior work; and
- light/dark themes change controls without remapping the artwork.

### Export tests

- encoder output begins with the PNG signature and reports 2400 x 1600 pixels;
- exported pixels map all four tokens to the chosen colors and include authored
  decor, but exclude rail, flyout, top controls and watermark text;
- exported output is the complete 3:2 artwork even when the editor is in Fill
  mode on a portrait device;
- gallery writer is invoked exactly once with a safe template/timestamp filename;
- simultaneous taps cannot start two exports;
- permission grant, denial, permanently denied, unsupported platform, write
  failure and retry states show truthful results while retaining the draft; and
- platform metadata tests require Android write permission with
  `maxSdkVersion="29"`, reject the same permission without that cap plus all
  broad/media-read permissions, and require the iOS add-only purpose text.

### Regression and visual review

- real-photo masking/sharing, color **Use in Room**, app navigation and existing
  saved Study designs remain green;
- generate deterministic preview PNGs for all six grayscale cards, all six
  recommended colored rooms, phone rail closed/open, short landscape and tablet;
- inspect previews for perspective, contact shadows, material cues, rail
  contrast, focal cropping and legible surface differences; and
- mutation tests prove that swapping any token, route ID, first-custom seed,
  template ID or export dimension fails at least one focused test.

## Verification and delivery constraints

Verification uses guarded, no-build commands only:

1. format check for changed Dart files;
2. focused catalog, asset, controller, persistence, widget and export tests;
3. deterministic preview generation and visual inspection;
4. full `flutter test --no-pub` where the repository guard permits it; and
5. full `flutter analyze --no-pub` where the repository guard permits it.

Do not run `flutter build`, Gradle, CocoaPods, Xcode, native compilation,
installation, `flutter clean` or destructive data operations. Preserve all
unrelated working-tree changes and report guard/dependency limitations exactly.

## Sources informing the market and export decisions

- [Asian Paints Bangladesh: choosing wall colors for Bangladesh](https://www.asianpaints.com.bd/blogs/choosing-the-right-wall-colour-paint-for-your-home-in-bangladesh.html)
- [Asian Paints Bangladesh: interior color combinations](https://www.asianpaints.com.bd/blogs/interior-wall-paint-color-combinations-perfect-matches-for-your-home.html)
- [Gossamer 8052](https://www.asianpaints.com.bd/catalogue/colour-catalogue/gossamer-8052.html), [Milkshake 8012](https://www.asianpaints.com.bd/catalogue/colour-catalogue/milkshake-8012.html), [White Clay 8620](https://www.asianpaints.com.bd/catalogue/colour-catalogue/white-clay-8620.html) and [White Cameo L145](https://www.asianpaints.com.bd/catalogue/colour-catalogue/white-cameo-L145.html)
- [Asian Paints Bangladesh Timber Glaze product sheet](https://static.asianpaints.com/content/dam/ap-bn-revamp/products/product-information-sheet/pds-timber-glaze-pds.pdf)
- [`flutter_svg` 2.3.0 output conversion and `ColorMapper`](https://pub.dev/packages/flutter_svg)
- [`gal` Gallery saver](https://pub.dev/packages/gal)

## Builder-owned details

The builder may refine exact geometry, texture density, anchor coordinates,
flyout animation, breakpoints and file boundaries. Such refinements must
preserve the six-room scope, pinned palette fixtures, four-token SVG contract,
black-and-white catalog/first session, first-custom seeding, full artwork
export, accessibility, market caveat and no-build constraint.
