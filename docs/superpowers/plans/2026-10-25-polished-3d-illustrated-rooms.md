# Polished 3D Illustrated Rooms Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-author all six editable illustrated-room SVGs as polished, semi-realistic 3D-style interiors while preserving the current gallery, editor, four-color model, black-and-white start state, persistence and export behavior.

**Architecture:** Keep the existing `1200 x 800` pure-SVG pipeline and reserved Wall/Ceiling/Floor/Furniture tokens. Build depth inside each asset with neutral translucent highlights, shades, material details, directional light and fitted path/polygon shadows, then prove the result through shared structural and raster-polish contracts. No production Dart behavior changes; only the six SVG assets and their test/preview/documentation evidence change.

**Tech Stack:** Flutter/Dart widget tests, `flutter_svg` rendering through the existing `IllustratedRoomSvg`, pure local SVG 1.1 geometry/gradients/clip paths, `package:image` PNG decoding, deterministic real-font preview harness.

**Spec:** `docs/superpowers/specs/2026-10-25-polished-3d-illustrated-rooms-design.md`

## Global Constraints

- Read the approved spec before implementing a task; the generated Study PNG is non-shipping visual reference only and must never be copied, traced, embedded or added to the repository.
- Re-author only `assets/rooms/living_room.svg`, `bedroom_room.svg`, `study_room.svg`, `dining_room.svg`, `kitchen_room.svg` and `bathroom_room.svg`; related tests, preview evidence and README text may change.
- Preserve `viewBox="0 0 1200 800"`, catalog IDs/paths/copy/focal points, routes, responsive UI, black-and-white first state, the four existing color controls, palettes/HEX values, persistence/schema and `2400 x 1600` export behavior.
- Keep exactly one `surface-wall`, `surface-ceiling`, `surface-floor` and `surface-furniture` group using only `#FF00A1`, `#00E5FF`, `#B7FF00` and `#7A00FF` respectively as editable base colors.
- Reserved tokens must not occur in definitions, gradients, fixed decoration or another surface group. Form cues use neutral white/black or restrained fixed neutral colors with opacity so the selected base hue stays readable.
- Give every room its own architecture/decor and coherent dominant light direction, with foreground/midground/background overlap, visible top/front/side planes, curved furniture where appropriate, object-fitted shadows, contact/AO bands and restrained room-specific material cues that survive card scale.
- Permit only the local SVG elements `svg`, `defs`, `g`, `path`, `rect`, `circle`, `ellipse`, `polygon`, `polyline`, `line`, `linearGradient`, `radialGradient`, `stop` and `clipPath`. This excludes image/filter/mask/style/script/animation/foreign-object or HTML embedding, external URLs/fonts and watermarks.
- Treat `80 KiB` and `400` simple geometry elements as review targets, not unconditional limits. Do not impose a minimum or add filler; any exceedance needs a non-empty contract justification backed by measured preview/export evidence.
- Preserve the common exact base anchors `(600,220)` Wall, `(600,40)` Ceiling, `(1100,760)` Floor and `(600,590)` Furniture, plus every existing room-specific exact Furniture anchor.
- Preserve the existing authored-decoration sample pixels listed per room below. If one truly must move, replace it with an equally unblended fixed-color point and update both raster and export expectations intentionally.
- Do not add dependencies or edit `pubspec.yaml`, platform manifests/configuration, model assets, real-photo AI code or native minimums.
- Do not run `flutter pub get`, `flutter clean`, Gradle, CocoaPods, Xcode, an APK build/install or any native build. Every Flutter command in this plan must use the checked-in `tool/deny-native-compilers.sb` sandbox.
- Before the first Flutter command in every task, run `rg -n -A 3 '"name": "objective_c"' .dart_tool/package_config.json` and confirm the package root remains `.superpowers/sdd/2026-10-25-realistic-multi-room-svg-gallery/objective_c_no_hooks/`. Stop rather than repairing or overwriting that redirect.
- Preserve unrelated dirty-worktree changes. Stage and commit only files named by the task.

## Review Focus

- **Extreme custom colors:** the preview-only stress combination `#F4EEE4 / #20242C / #0057FF / #FF4D00` must retain recognizable surface hue and neutral 3D form cues; Task 7 renders every room in it, while each room task tests a saturated Furniture hue.
- **Black-and-white readability:** neutral overlays must not collapse into a flat or muddy scene after the existing grayscale mapper runs; each room task exercises its highlight/base/shade triple in both colored and grayscale drafts.
- **Token/safe-SVG regression:** a token in a definition, wrong owner, mask or external reference must fail instead of rendering unpredictably; Task 1 adds negative fixtures around the shared validator.
- **Shadow and perspective cheats:** generic shadow ellipses or shadows lighter than clear floor must not satisfy “3D”; each room contract requires fitted path/polygon shadows and compares a contact-shadow pixel with an unobstructed floor pixel.
- **Crop/export loss:** central furniture, editable samples and authored detail must survive phone card/editor crops and the real `2400 x 1600` encoder; Task 7 tests every export and captures phone/tablet/fill/whole-room evidence.

---

## File Structure

- `test/support/illustrated_room_svg_contract.dart` — extend the existing safe/token validator with reusable polish metrics, semantic-group validation and raster luma/hue assertions.
- `test/features/room_studio/presentation/illustrated_room_polish_test.dart` — one data-driven contract/raster suite for the six polished assets; add rooms sequentially so every task returns the branch to green.
- `assets/rooms/*_room.svg` — the six independently authored room scenes; each task owns exactly one asset.
- `test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart` — prove all six final assets export at `2400 x 1600` with exact editable and fixed-detail pixels.
- `tool/render_illustrated_room_previews.dart` — produce the 27-file visual evidence set and a manifest containing measured asset complexity.
- `docs/superpowers/plans/2026-10-25-polished-3d-illustrated-rooms-evidence.md` — record pre-change asset/timing baselines, final metrics, verification results and the room-by-room visual review.
- `README.md` — document the expanded deterministic preview evidence accurately.

### Task 1: Shared Polish Contract and Study Pilot

**Files:**
- Create: `docs/superpowers/specs/2026-10-25-polished-3d-illustrated-rooms-design.md`
- Create: `docs/superpowers/plans/2026-10-25-polished-3d-illustrated-rooms.md`
- Modify: `test/support/illustrated_room_svg_contract.dart`
- Create: `test/features/room_studio/presentation/illustrated_room_polish_test.dart`
- Create: `docs/superpowers/plans/2026-10-25-polished-3d-illustrated-rooms-evidence.md`
- Modify: `assets/rooms/study_room.svg`
- Modify: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: existing `validateIllustratedRoomSvg`, `pumpIllustratedRoomRaster`, `illustratedRoomPixels`, `illustratedRoomRgb` and exact Study anchors.
- Produces: `IllustratedRoomSvgMetrics`, `IllustratedRoomToneSample`, `IllustratedRoomPolishContract`, `illustratedRoomSvgMetrics`, `validatePolishedIllustratedRoomSvg`, `illustratedRoomLuma`, `expectIllustratedRoomToneTriple`, `expectIllustratedRoomContactShadow` and `expectIllustratedRoomHueReadable` for Tasks 2–7; plus one test-local `_IllustratedRoomPolishFixture` table that later tasks extend.

- [ ] **Step 1: Record the untouched artwork baseline**

  After confirming the objective-c redirect, capture `wc -c assets/rooms/*_room.svg` and case-insensitive counts of `<path|rect|circle|ellipse|polygon|polyline|line>` per file. Confirm the untouched values are Living `8873/92`, Bedroom `9331/99`, Study `11547/125`, Dining `6964/76`, Kitchen `7138/76`, Bathroom `7137/74` (bytes/geometry); stop and re-baseline explicitly if the workspace has changed. Time the unchanged six-room grayscale/colored raster contract with:

  ```bash
  /usr/bin/time -p /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_svg_test.dart --plain-name "satisfies the catalog-wide render contract" --reporter expanded
  ```

  Create the evidence file with the measured `real/user/sys` output and asset values. Label it as a local source-render baseline, not a device benchmark; do not change any asset first.

- [ ] **Step 2: Write failing tests for the shared polish contract**

  In `illustrated_room_polish_test.dart`, add minimal canonical SVG fixtures and tests that pin these APIs and behaviors. The public types/functions below live in `illustrated_room_svg_contract.dart`; the private fixture typedef lives in the new polish test:

  ```dart
  typedef IllustratedRoomSvgMetrics = ({
    int utf8Bytes,
    int geometryCount,
    int gradientCount,
    int clipPathCount,
  });

  typedef IllustratedRoomToneSample = ({
    (int, int) highlight,
    (int, int) base,
    (int, int) shade,
  });

  final class IllustratedRoomPolishContract {
    const IllustratedRoomPolishContract({
      required this.requiredGroupIds,
      required this.editableObjectGroupIds,
      required this.toneSample,
      required this.contactShadowAnchor,
      required this.clearFloorAnchor,
      this.complexityJustification,
    });

    final List<String> requiredGroupIds;
    final List<String> editableObjectGroupIds;
    final IllustratedRoomToneSample toneSample;
    final (int, int) contactShadowAnchor;
    final (int, int) clearFloorAnchor;
    final String? complexityJustification;
  }

  IllustratedRoomSvgMetrics illustratedRoomSvgMetrics(String source);

  void validatePolishedIllustratedRoomSvg(
    String source,
    IllustratedRoomTemplate template,
    IllustratedRoomPolishContract contract,
  );

  double illustratedRoomLuma(
    Uint8List pixels,
    (int, int) anchor,
  );

  void expectIllustratedRoomToneTriple(
    Uint8List pixels,
    IllustratedRoomToneSample sample, {
    double minDelta = 8,
  });

  void expectIllustratedRoomContactShadow(
    Uint8List pixels, {
    required (int, int) shadow,
    required (int, int) clearFloor,
    double minDelta = 6,
  });

  void expectIllustratedRoomHueReadable(
    Uint8List pixels,
    (int, int) anchor, {
    int dominantChannel = 0,
    int minChannelMargin = 20,
  });

  typedef _IllustratedRoomPolishFixture = ({
    IllustratedRoomTemplate template,
    IllustratedRoomPolishContract contract,
    (int, int) decorationAnchor,
    String decorationHex,
  });
  ```

  Assert that a valid fixture reports exact UTF-8 byte/geometry/gradient/clip counts; missing/duplicate/empty named groups fail; an editable object outside `surface-furniture` fails; an editable object without token base plus translucent white and black geometry fails; and an ellipse in the contact-shadow group fails. A fixture above `81920` bytes or `400` geometry elements must fail without `complexityJustification` and pass with a non-empty measured-evidence justification. Extend the base validator fixtures so unsupported `mask`, `style`, `foreignObject`, HTML `img`, `object`, `embed` and `iframe` elements all fail.

- [ ] **Step 3: Register the failing Study polish fixture**

  Add a Study contract with required groups `study-architecture-depth`, `study-daylight`, `study-practical-light`, `study-contact-shadows`, `study-material-cues`; editable groups `study-editable-desk`, `study-editable-office-chair`, `study-editable-reading-chair`, `study-editable-shelving`; tone sample highlight/base/shade `(600,525)/(600,538)/(600,551)`; contact shadow `(1035,575)`; clear floor `(1100,760)`.

  Drive one structural test and two widget tests from a list of `_IllustratedRoomPolishFixture` records so Tasks 2–6 only add one room record. The colored draft sets Wall/Ceiling/Floor to `#808080` and Furniture to `#C93A5B`; it must satisfy tone deltas of at least `8`, red-channel dominance of at least `20` at highlight and shade, a contact-shadow-to-clear-floor delta of at least `6`, and the fixture's exact decoration RGB. The grayscale draft must retain the same tone ordering and contact-shadow delta and must map the decoration sample to equal RGB channels. Existing exact Study token tests remain the base-color authority; set its fixture decoration to `(180,250) == #9FD7EA`.

- [ ] **Step 4: Run the new suite and verify RED**

  Run:

  ```bash
  rg -n -A 3 '"name": "objective_c"' .dart_tool/package_config.json
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_polish_test.dart --reporter expanded
  ```

  Expected: FAIL first because the new helper interfaces do not exist; after Step 5, FAIL specifically because the current Study SVG lacks the required polish groups/cues.

- [ ] **Step 5: Implement the shared helper interfaces**

  Add the interfaces above to `illustrated_room_svg_contract.dart`. `validatePolishedIllustratedRoomSvg` first calls `validateIllustratedRoomSvg`, then enforces the polish contract; an `81920`-byte or `400`-geometry exceedance requires a non-blank `complexityJustification` rather than failing unconditionally. Replace the base validator's element blacklist with the exact local-element allowlist in Global Constraints so foreign/HTML content cannot bypass individual checks. Count only `path`, `rect`, `circle`, `ellipse`, `polygon`, `polyline` and `line` as simple geometry. Named groups must occur exactly once and contain geometry. Every editable group must be nested below `surface-furniture` and contain token base geometry plus at least one translucent-white and one translucent-black geometry cue. The `*-contact-shadows` group must contain a `path` or `polygon` and no ellipse. Compute luma as `0.2126R + 0.7152G + 0.0722B` on encoded 0–255 RGB values, so the `8` and `6` deltas use the same 0–255 scale; hue readability compares the requested dominant channel against both other channels.

- [ ] **Step 6: Re-author Study as the reference-quality pilot**

  Keep all existing exact base anchors. Author an original, perspective-correct study with a thick desk top/drawer reveals/sparse neutral grain, curved ergonomic chair, distinct reading chair, dimensional shelving, cool upper-left window daylight, warm task-light pool, monitor reflection and lower-right fitted shadows. Put neutral structural cues in the five required Study groups and base-plus-highlight/shade geometry for each major object in its required editable group. Do not copy raster pixels from the concept reference.

- [ ] **Step 7: Verify Study structure and color mapping**

  Run:

  ```bash
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_polish_test.dart test/features/room_studio/presentation/illustrated_room_svg_test.dart --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub tool/render_illustrated_room_previews.dart --reporter expanded
  ```

  Expected: PASS with no renderer exception and the existing preview manifest still containing 19 unique files.

- [ ] **Step 8: Visually inspect the Study pilot**

  Inspect `build/previews/illustrated-room-artwork-study-grayscale.png` and `...-recommended.png` at full size and thumbnail scale for coherent upper-left light, fitted lower-right shadows, readable materials, clean crop and no token-colored detail leaks. Correct and rerun Step 7 if any check fails.

- [ ] **Step 9: Commit the Study pilot**

  ```bash
  git add docs/superpowers/specs/2026-10-25-polished-3d-illustrated-rooms-design.md docs/superpowers/plans/2026-10-25-polished-3d-illustrated-rooms.md docs/superpowers/plans/2026-10-25-polished-3d-illustrated-rooms-evidence.md test/support/illustrated_room_svg_contract.dart test/features/room_studio/presentation/illustrated_room_polish_test.dart test/features/room_studio/presentation/illustrated_room_svg_test.dart assets/rooms/study_room.svg
  git commit -m "feat: polish illustrated study room"
  ```

### Task 2: Living Room Upholstery and Daylight

**Files:**
- Modify: `test/features/room_studio/presentation/illustrated_room_polish_test.dart`
- Modify: `assets/rooms/living_room.svg`
- Test: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: all shared polish helpers from Task 1.
- Produces: a Living asset satisfying the shared contract and its permanent fixture entry.

- [ ] **Step 1: Add the failing Living fixture**

  Require `living-architecture-depth`, `living-daylight`, `living-practical-light`, `living-contact-shadows`, `living-upholstery-details`; editable groups `living-editable-sofa`, `living-editable-accent-chair`, `living-editable-console`, `living-editable-coffee-table`; tone `(600,570)/(600,610)/(600,685)`; shadow `(1020,575)`; clear floor `(1100,760)`. Use the same colored/grayscale assertions and thresholds as Study. Preserve Furniture anchors `(600,610)`, `(190,650)`, `(590,690)` and fixed decoration `(301,226) == #F4D27B`.

- [ ] **Step 2: Run the Living test and verify RED**

  Run the guarded `illustrated_room_polish_test.dart` command from Task 1 after the objective-c redirect check. Expected: FAIL naming missing Living polish groups/cues.

- [ ] **Step 3: Re-author the Living SVG**

  Build a slightly angled lounge with a broad comparison wall, curved sofa arms, cushion compression/seams/fabric tension, a distinct accent-chair silhouette, thick coffee-table planes, dimensional media-console reveals and object-fitted lower-right shadows from coherent upper-left daylight. Keep wall/floor comparison regions unobstructed and all listed anchors exact.

- [ ] **Step 4: Verify Living automatically**

  Run the guarded polish + SVG suites and preview command from Task 1. Expected: PASS with no renderer exception.

- [ ] **Step 5: Visually inspect Living**

  Inspect Living grayscale/recommended outputs at full and card size for upholstery volume, non-elliptical shadows, crop safety and a composition distinct from Study. Correct and rerun Step 4 if any check fails.

- [ ] **Step 6: Commit Living**

  ```bash
  git add test/features/room_studio/presentation/illustrated_room_polish_test.dart assets/rooms/living_room.svg
  git commit -m "feat: polish illustrated living room"
  ```

### Task 3: Bedroom Textiles and Timber

**Files:**
- Modify: `test/features/room_studio/presentation/illustrated_room_polish_test.dart`
- Modify: `assets/rooms/bedroom_room.svg`
- Test: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: all shared polish helpers from Task 1.
- Produces: a Bedroom asset satisfying the shared contract and its permanent fixture entry.

- [ ] **Step 1: Add the failing Bedroom fixture**

  Require `bedroom-architecture-depth`, `bedroom-daylight`, `bedroom-practical-light`, `bedroom-contact-shadows`, `bedroom-textile-details`, `bedroom-timber-details`; editable groups `bedroom-editable-bed`, `bedroom-editable-wardrobe`, `bedroom-editable-side-tables`; tone `(600,630)/(600,650)/(600,710)`; shadow `(1030,580)`; clear floor `(1100,760)`. Preserve Furniture anchors `(600,455)`, `(600,650)`, `(1030,420)` and fixed decoration `(262,225) == #F3D37D`.

- [ ] **Step 2: Run the Bedroom test and verify RED**

  Run the guarded polish test after the objective-c redirect check. Expected: FAIL naming missing Bedroom polish groups/cues.

- [ ] **Step 3: Re-author the Bedroom SVG**

  Make the bed a deep layered form with headboard and mattress thickness, compressed pillows, restrained duvet folds and a fitted grounded shadow. Add recessed wardrobe/door planes, dimensional side tables and sparse neutral timber cues. Use left-window daylight as the dominant direction with casts traveling lower-right; keep practical light local. Keep broad editable bed/furniture areas and exact anchors unblended.

- [ ] **Step 4: Verify Bedroom automatically**

  Run the guarded polish + SVG suites and preview command. Expected: PASS with no renderer exception.

- [ ] **Step 5: Visually inspect Bedroom**

  Inspect Bedroom grayscale/recommended outputs at full/card size for textile readability, wardrobe depth, grounding and a composition distinct from Living. Correct and rerun Step 4 if any check fails.

- [ ] **Step 6: Commit Bedroom**

  ```bash
  git add test/features/room_studio/presentation/illustrated_room_polish_test.dart assets/rooms/bedroom_room.svg
  git commit -m "feat: polish illustrated bedroom"
  ```

### Task 4: Dining Room Perspective and Pendant Light

**Files:**
- Modify: `test/features/room_studio/presentation/illustrated_room_polish_test.dart`
- Modify: `assets/rooms/dining_room.svg`
- Test: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: all shared polish helpers from Task 1.
- Produces: a Dining asset satisfying the shared contract and its permanent fixture entry.

- [ ] **Step 1: Add the failing Dining fixture**

  Require `dining-architecture-depth`, `dining-daylight`, `dining-pendant-light`, `dining-contact-shadows`, `dining-material-cues`; editable groups `dining-editable-table`, `dining-editable-chairs`, `dining-editable-sideboard`; tone `(600,540)/(600,610)/(600,632)`; shadow `(1010,615)`; clear floor `(1100,760)`. Preserve Furniture anchors `(600,610)`, `(350,620)`, `(1000,560)` and fixed decoration `(274,226) == #F3D27A`.

- [ ] **Step 2: Run the Dining test and verify RED**

  Run the guarded polish test after the objective-c redirect check. Expected: FAIL naming missing Dining polish groups/cues.

- [ ] **Step 3: Re-author the Dining SVG**

  Replace the front-on schematic arrangement with one coherent perspective: foreshortened table top with visible thickness, naturally overlapping chairs whose scale changes with depth, dimensional sideboard and restrained central pendant-light pool. Use upper-left daylight as the dominant direction with lower-right casts; the pendant adds only a local downward pool. Keep cast/contact shadows fitted to legs and chair footprints; preserve open wall/floor samples.

- [ ] **Step 4: Verify Dining automatically**

  Run the guarded polish + SVG suites and preview command. Expected: PASS with no renderer exception.

- [ ] **Step 5: Visually inspect Dining**

  Inspect Dining outputs for convincing scale-by-depth, leg alignment, central light pool, readable custom hue and no reused Living/Bedroom shell. Correct and rerun Step 4 if any check fails.

- [ ] **Step 6: Commit Dining**

  ```bash
  git add test/features/room_studio/presentation/illustrated_room_polish_test.dart assets/rooms/dining_room.svg
  git commit -m "feat: polish illustrated dining room"
  ```

### Task 5: Kitchen Cabinetry and Counter Depth

**Files:**
- Modify: `test/features/room_studio/presentation/illustrated_room_polish_test.dart`
- Modify: `assets/rooms/kitchen_room.svg`
- Test: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: all shared polish helpers from Task 1.
- Produces: a Kitchen asset satisfying the shared contract and its permanent fixture entry.

- [ ] **Step 1: Add the failing Kitchen fixture**

  Require `kitchen-architecture-depth`, `kitchen-daylight`, `kitchen-undercabinet-light`, `kitchen-contact-shadows`, `kitchen-counter-details`; editable groups `kitchen-editable-left-cabinetry`, `kitchen-editable-right-cabinetry`, `kitchen-editable-island`; tone `(600,560)/(600,610)/(600,695)`; shadow `(950,585)`; clear floor `(1100,760)`. Preserve Furniture anchors `(600,610)`, `(250,430)`, `(950,430)` and fixed decoration `(850,532) == #C6CFD0`.

- [ ] **Step 2: Run the Kitchen test and verify RED**

  Run the guarded polish test after the objective-c redirect check. Expected: FAIL naming missing Kitchen polish groups/cues.

- [ ] **Step 3: Re-author the Kitchen SVG**

  Add cabinet-carcass depth, door bevels, drawer gaps, toe-kicks, counter thickness and a coherent perspective island. Use upper-left window daylight as the dominant direction with lower-right casts, plus localized under-cabinet illumination and restrained neutral stone variation. Keep appliances, sink and hardware fixed neutral while all cabinetry/island base faces stay under the one Furniture token.

- [ ] **Step 4: Verify Kitchen automatically**

  Run the guarded polish + SVG suites and preview command. Expected: PASS with no renderer exception.

- [ ] **Step 5: Visually inspect Kitchen**

  Inspect Kitchen outputs for aligned cabinetry perspective, clean toe-kicks, restrained stone/metal cues, readable under-cabinet light and exact editable anchors. Correct and rerun Step 4 if any check fails.

- [ ] **Step 6: Commit Kitchen**

  ```bash
  git add test/features/room_studio/presentation/illustrated_room_polish_test.dart assets/rooms/kitchen_room.svg
  git commit -m "feat: polish illustrated kitchen"
  ```

### Task 6: Bathroom Tile, Glass and Porcelain

**Files:**
- Modify: `test/features/room_studio/presentation/illustrated_room_polish_test.dart`
- Modify: `assets/rooms/bathroom_room.svg`
- Test: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: all shared polish helpers from Task 1.
- Produces: a Bathroom asset satisfying the shared contract and the complete six-room fixture table.

- [ ] **Step 1: Add the failing Bathroom fixture**

  Require `bathroom-architecture-depth`, `bathroom-reflected-light`, `bathroom-contact-shadows`, `bathroom-tile-details`, `bathroom-glass-metal-details`; editable groups `bathroom-editable-vanity`, `bathroom-editable-storage`; tone `(400,528)/(400,590)/(400,652)`; shadow `(170,575)`; clear floor `(1100,760)`. Preserve Furniture anchors `(400,590)`, `(980,480)` and fixed decoration `(245,165) == #334248`.

- [ ] **Step 2: Run the Bathroom test and verify RED**

  Run the guarded polish test after the objective-c redirect check. Expected: FAIL naming missing Bathroom polish groups/cues.

- [ ] **Step 3: Re-author the Bathroom SVG**

  Add subtle tile/grout value variation, dimensional vanity/storage, curved basin and sanitary ware, mirror/glass edge highlights, restrained chrome and hard-surface reflected light. Use upper-right reflected daylight as the dominant direction with lower-left casts. Keep sanitary ware, mirror, shower glass and fittings fixed neutral; only vanity/storage base planes use Furniture. Fit contact shadows to actual bases rather than generic ellipses.

- [ ] **Step 4: Verify Bathroom automatically**

  Run the guarded polish + SVG suites and preview command. Expected: PASS with no renderer exception.

- [ ] **Step 5: Visually inspect Bathroom**

  Inspect Bathroom outputs for tile scale, glass readability, porcelain curvature, restrained metal highlights, grounding and clean grayscale contrast. Correct and rerun Step 4 if any check fails.

- [ ] **Step 6: Commit Bathroom**

  ```bash
  git add test/features/room_studio/presentation/illustrated_room_polish_test.dart assets/rooms/bathroom_room.svg
  git commit -m "feat: polish illustrated bathroom"
  ```

### Task 7: Six-Room Export, Stress Preview and Final Evidence

**Files:**
- Modify: `test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart`
- Modify: `tool/render_illustrated_room_previews.dart`
- Modify: `docs/superpowers/plans/2026-10-25-polished-3d-illustrated-rooms-evidence.md`
- Modify: `README.md`
- Test: `test/features/room_studio/presentation/illustrated_room_polish_test.dart`
- Test: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: completed six-room polish fixture table and `illustratedRoomSvgMetrics` from Task 1.
- Produces: six-room real-encoder coverage, an exact 27-file preview manifest with per-asset metrics, and final documented evidence.

- [ ] **Step 1: Expand the real encoder acceptance test to all six rooms**

  Replace the Study-only success case with a data-driven case that encodes a distinct colored draft for every catalog template, verifies PNG signature and `(2400,1600)`, then checks common scaled anchors `(1200,440)`, `(1200,80)`, `(2200,1520)`, `(1200,1180)`. Check these scaled Furniture anchors:

  - Living: `(1200,1220)`, `(380,1300)`, `(1180,1380)`;
  - Bedroom: `(1200,910)`, `(1200,1300)`, `(2060,840)`;
  - Study: `(1200,1076)`, `(1220,1330)`, `(360,1300)`, `(760,1340)`;
  - Dining: `(1200,1220)`, `(700,1240)`, `(2000,1120)`;
  - Kitchen: `(1200,1220)`, `(500,860)`, `(1900,860)`;
  - Bathroom: `(800,1180)`, `(1960,960)`.

  Also verify one scaled fixed-detail point per room: Living `(602,452) #F4D27B`, Bedroom `(524,450) #F3D37D`, Study `(360,500) #9FD7EA`, Dining `(548,452) #F3D27A`, Kitchen `(1700,1064) #C6CFD0`, Bathroom `(490,330) #334248`.

- [ ] **Step 2: Make the preview manifest expectation fail at 27 files**

  Add `illustrated-room-artwork-<id>-stress.png` for all six rooms, `illustrated-room-editor-phone-whole-room.png` and `illustrated-room-export-study-recommended-2400x1600.png` to `_expectedNames`; change manifest count from `19` to `27`. Run the guarded preview command. Expected: FAIL because eight new files have not yet been captured.

- [ ] **Step 3: Add six stress artwork captures**

  In the canonical artwork loop, render `illustrated-room-artwork-<id>-stress.png` from a custom draft with Wall `#F4EEE4`, Ceiling `#20242C`, Floor `#0057FF`, Furniture `#FF4D00`.

- [ ] **Step 4: Add the whole-room phone capture**

  Starting from the phone editor harness, tap key `room-view-full`, settle, assert the rendered `IllustratedRoomSvg.fit == BoxFit.contain`, and capture `illustrated-room-editor-phone-whole-room.png`.

- [ ] **Step 5: Add the real encoder export capture**

  Generate `illustrated-room-export-study-recommended-2400x1600.png` with `SvgIllustratedRoomArtworkEncoder.encodePng` for Study’s recommended draft, decode/assert `2400 x 1600`, and write the returned bytes directly; do not use the fake encoder or a `RepaintBoundary` for this file.

- [ ] **Step 6: Record final SVG metrics in the manifest**

  Extend `illustrated-room-render-manifest.json` with a sorted per-room asset-metrics map from `illustratedRoomSvgMetrics`, containing `utf8Bytes`, `geometryCount`, `gradientCount`, `clipPathCount`, while preserving exact `count: 27` and the exact captured-file equality check.

- [ ] **Step 7: Update README evidence text**

  Change the illustrated-room preview paragraph from exactly 19 to exactly 27 samples and list: six grayscale, six recommended, six stress, gallery phone/tablet, phone rail closed/open/focus/whole-room, landscape, tablet and one real Study `2400 x 1600` export. State that the source test harness remains native-channel-free and uses the guarded no-native-compiler flow.

- [ ] **Step 8: Run focused verification**

  Run:

  ```bash
  rg -n -A 3 '"name": "objective_c"' .dart_tool/package_config.json
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_svg_test.dart test/features/room_studio/presentation/illustrated_room_polish_test.dart test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart test/features/room_studio/presentation/illustrated_room_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart test/features/room_studio/presentation/illustrated_room_navigation_test.dart test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart test/features/room_studio/application/illustrated_room_export_controller_test.dart --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub tool/render_illustrated_room_previews.dart --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub
  ```

  Expected: all tests PASS, preview manifest contains exactly 27 unique files, analysis reports no issues.

- [ ] **Step 9: Perform the final visual review**

  Inspect all 18 canonical room artworks plus gallery phone/tablet, portrait fill/focus/whole-room, landscape, tablet and the real export. In the evidence file, record for each room: dominant light direction is internally consistent; contact/cast shadows match objects; neutral overlays preserve stress hue; grayscale retains depth; central crop still identifies the room; materials differ without implying extra color controls; no room repeats another room’s window/art/pendant/plant layout; no distorted furniture or fine-detail noise appears at card scale.

- [ ] **Step 10: Run guarded whole-project verification**

  Run:

  ```bash
  rg -n -A 3 '"name": "objective_c"' .dart_tool/package_config.json
  /usr/bin/time -p /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_svg_test.dart --plain-name "satisfies the catalog-wide render contract" --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub
  ```

  Time the same six-room grayscale/colored raster contract used for the baseline with `/usr/bin/time -p`, then record its timing, the manifest's six asset-metric records and all focused/full verification outcomes beside the baseline. If a review target is exceeded without measured justification, or like-for-like render time regresses materially, simplify authored geometry and rerun. Expected: complete test suite PASS and whole-project analysis reports no issues. Report only this guarded source/test evidence; do not claim a native build or physical-device check.

- [ ] **Step 11: Commit final evidence**

  ```bash
  git add test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart tool/render_illustrated_room_previews.dart docs/superpowers/plans/2026-10-25-polished-3d-illustrated-rooms-evidence.md README.md
  git commit -m "test: verify polished room artwork"
  ```
