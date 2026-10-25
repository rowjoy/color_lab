# Realistic Multi-Room SVG Gallery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the illustrated Study prototype into a six-room, black-and-white-first SVG gallery with a full-screen right-rail color editor, durable per-room designs, market-guided/custom colors, and clean 2400 x 1600 Gallery export.

**Architecture:** Keep one four-token SVG renderer and one template-driven editor for every room. Add an immutable per-template session above the existing version-1 saved-design repository, split the overlay rail/flyouts from the scene, and render exports directly from the SVG picture rather than capturing screen UI. `gal` remains behind an injected writer so domain/widget tests never touch a real Photo Library.

**Tech Stack:** Flutter 3.41+/Dart 3.11, Riverpod 3.3, GoRouter 17.5, Hive 2.2, `flutter_svg` 2.3.0, direct `vector_graphics` 1.2.4, cached `gal` 2.3.2, `permission_handler` 12, Flutter unit/widget tests and guarded source verification.

**Spec:** `docs/superpowers/specs/2026-10-25-realistic-multi-room-svg-gallery-design.md`

## Global Constraints

- Preserve the existing real-photo mask/recolor flow, `RoomLayerColors`, photo sharing and legacy `roomColorProvider` state.
- Catalog order is exactly `living`, `bedroom`, `study`, `dining`, `kitchen`, `bathroom`; all assets are original, watermark-free 1200 x 800 SVGs with no embedded raster.
- Do not use `CustomClipper` or duplicated Dart room geometry; the SVG remains the only editable-region source of truth.
- Editable groups/tokens remain exactly Wall `surface-wall/#FF00A1`, Ceiling `surface-ceiling/#00E5FF`, Floor `surface-floor/#B7FF00`, Furniture `surface-furniture/#7A00FF`.
- Gallery cards are always black and white. A template's first editor draft is black and white; the first surface choice seeds its complete recommended look before applying the override.
- Every template has exactly `warm-natural`, `soft-botanical`, and `cool-airy`, with the literal fixtures and default IDs approved in the spec.
- Keep saved-record schema version 1 and Hive box `illustrated_room_designs_v1`; add no palette ID to persisted records.
- Export only a colored complete 3:2 artwork at exactly 2400 x 1600 PNG; no rail, flyout, screen crop, watermark, network upload or full-resolution cache.
- `SvgAssetLoader` already performs SVG compilation in an isolate. Keep `dart:ui` rasterization/PNG encoding on the engine isolate; do not add `compute` for color changes or UI state.
- Use exact cached dependencies `gal: 2.3.2` and `vector_graphics: 1.2.4`; dependency resolution is offline only.
- Android write access is exactly `WRITE_EXTERNAL_STORAGE` with `maxSdkVersion="29"`; retain removal of read permissions and add no `READ_MEDIA_IMAGES`, `MANAGE_EXTERNAL_STORAGE`, custom album or `requestLegacyExternalStorage`.
- iOS adds `NSPhotoLibraryAddUsageDescription`; retain the existing photo-picker read description.
- Touch targets are at least 48 x 48 logical pixels; support 320px phones, 2x text, keyboard insets, reduced motion, 640 x 360 landscape and tablets.
- Preserve unrelated dirty-worktree changes. Inspect every overlapping diff, stage only task-owned work, and never reset, clean or discard user changes.
- Do not run `flutter build`, Gradle, CocoaPods, Xcode, native compilers, install/package commands or `flutter clean`.

## Review Focus

- A saved-design open or **Use in Room** handoff targeting a dirty background draft must Save/Replace/Cancel atomically; Task 8 adds colored/grayscale target and cancellation tests.
- An async save completing after a newer edit must not mark that newer per-template draft clean; Task 2 retains a gated-write regression test.
- Malformed SVGs, leaked tokens, external/raster content and visually hidden editable regions must fail before catalog use; Tasks 3-5 add structural and rendered-anchor tests.
- A portrait Fill view must still export the full clean 2400 x 1600 scene exactly once and release its image resources; Tasks 10-11 test crop independence, duplicate taps and failure recovery.
- Android/iOS permission metadata and denied Photo Library access must stay least-privilege and truthful; Task 9 pins manifest/plist rules and Task 11 pins access-denied Settings behavior.

---

## File Structure

### New production files

- `lib/features/room_studio/domain/illustrated_room_session.dart` — immutable per-template drafts and active-template identity.
- `lib/features/room_studio/rendering/illustrated_room_color_mapper.dart` — shared four-token/grayscale mapper for screen and export.
- `lib/features/room_studio/presentation/illustrated_room_gallery_screen.dart` — lazy six-room black-and-white catalog.
- `lib/features/room_studio/presentation/illustrated_room_flyout.dart` — Looks, surface and Designs overlay panels.
- `lib/features/room_studio/presentation/illustrated_room_market_guide.dart` — dated market guidance and physical-sample caveat.
- `lib/features/room_studio/presentation/illustrated_room_navigation.dart` — dirty-target Save/Replace/Cancel coordinators.
- `lib/features/room_studio/application/room_gallery_writer.dart` — validated PNG-to-Gallery port and `gal` adapter.
- `lib/features/room_studio/application/illustrated_room_artwork_encoder.dart` — canonical SVG-to-PNG renderer.
- `lib/features/room_studio/application/illustrated_room_export_controller.dart` — serialized export state/results/filename.
- `assets/rooms/living_room.svg`, `bedroom_room.svg`, `dining_room.svg`, `kitchen_room.svg`, `bathroom_room.svg` — new original scenes.

### Existing production files modified

- `lib/features/room_studio/domain/illustrated_room.dart` and `illustrated_room_draft.dart` — catalog metadata, exact looks, focal points, contextual labels and baseline-aware dirty state.
- `lib/features/room_studio/application/illustrated_room_controller.dart` — session state, conflict guard and all-draft reconciliation.
- `lib/features/room_studio/presentation/illustrated_room_svg.dart` — shared mapper import and contextual semantics.
- `lib/features/room_studio/presentation/illustrated_room_controls.dart` — compact persistent `IllustratedRoomColorRail` only.
- `lib/features/room_studio/presentation/illustrated_room_screen.dart` — full-bleed scene, view mode, overlay flyout and export feedback.
- `lib/features/room_studio/presentation/saved_room_designs_sheet.dart` — reusable filtered saved-design list.
- `lib/features/room_studio/presentation/room_screen.dart`, `lib/routing/app_router.dart`, and `lib/features/picker/presentation/color_explorer.dart` — entry CTA, new routes and safe Study handoff.
- `assets/rooms/study_room.svg` — semi-realistic depth/material/lighting pass.
- `pubspec.yaml`, `pubspec.lock`, Android manifest and iOS plist — direct export dependencies and least-privilege metadata.
- `README.md`, `tool/render_previews.dart`, and the illustrated-room preview tool — documented behavior and visual evidence.

### New tests/support

- `test/features/room_studio/domain/illustrated_room_session_test.dart`
- `test/support/illustrated_room_svg_contract.dart`
- `test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart`
- `test/features/room_studio/presentation/illustrated_room_navigation_test.dart`
- `test/features/room_studio/application/gallery_platform_config_test.dart`
- `test/features/room_studio/application/room_gallery_writer_test.dart`
- `test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart`
- `test/features/room_studio/application/illustrated_room_export_controller_test.dart`
- `tool/render_illustrated_room_previews.dart`

Existing illustrated-room/controller/saved-design/integration tests are updated in place; real-photo regression tests change only intentional route/entry assertions.

## Command Convention

All Flutter test/analyze commands use the guarded installed SDK and never build:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter <command> --no-pub --reporter expanded
```

For `analyze`, omit `--reporter expanded`. Dependency resolution, only in Task 9, is:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter pub get --offline
```

Run ordinary Dart formatting on task-owned Dart paths, then check it with:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed <paths>
```

Every task ends with a commit checkpoint. Before staging, run `git diff -- <paths>` and `git diff --cached`; commit only when every change in a listed path belongs to this approved feature. If pre-existing user work overlaps a path and cannot be isolated safely, skip the commit, record that fact, and continue without staging unrelated work.

### Task 1: Six-room catalog, baseline draft and immutable session

**Files:**
- Modify: `lib/features/room_studio/domain/illustrated_room.dart`
- Modify: `lib/features/room_studio/domain/illustrated_room_draft.dart`
- Create: `lib/features/room_studio/domain/illustrated_room_session.dart`
- Modify: `test/features/room_studio/domain/illustrated_room_test.dart`
- Modify: `test/features/room_studio/domain/illustrated_room_draft_test.dart`
- Create: `test/features/room_studio/domain/illustrated_room_session_test.dart`

**Interfaces:**
- Consumes: existing `RgbColor`, saved-design identity strings and spec fixtures.
- Produces: enriched `IllustratedRoomTemplate`, baseline-aware `IllustratedRoomDraft`, and `IllustratedRoomSession` for every later task.

- [ ] **Step 1: Write failing catalog fixture/validation tests**

  Pin catalog order, paths, contextual furniture labels, normalized focal points, 1200 x 800 artboards, provenance and exactly this map (`[wall, ceiling, floor, furniture]`):

  Contextual furniture labels are Living `Furniture`, Bedroom
  `Bed & furniture`, Study `Desk & furniture`, Dining `Table & furniture`,
  Kitchen `Cabinets`, Bathroom `Vanity & storage`; Wall/Ceiling/Floor labels
  remain unchanged. Every template uses `Market guide - reviewed October 2026`
  and a non-empty display-preview/physical-swatch source note.

  ```dart
  const looks = {
    'living': {
      'default': 'warm-natural',
      'warm-natural': ['#E6D8C3', '#F8F4EB', '#C5AD8A', '#7B5944'],
      'soft-botanical': ['#C4D3C1', '#F8F4EB', '#BEB2A2', '#9A7557'],
      'cool-airy': ['#D3E0E4', '#F7F5EF', '#B5BEC1', '#5F493F'],
    },
    'bedroom': {
      'default': 'warm-natural',
      'warm-natural': ['#DED5C7', '#FAF6EE', '#C2A483', '#785747'],
      'soft-botanical': ['#C8D3C2', '#F8F4EC', '#BCA58A', '#80614E'],
      'cool-airy': ['#D4DFE4', '#F8F6F0', '#B7BEC1', '#67514B'],
    },
    'study': {
      'default': 'soft-botanical',
      'warm-natural': ['#E2D5BF', '#F8F4EB', '#C5AA84', '#72513D'],
      'soft-botanical': ['#B7C5B3', '#F8F4EB', '#C6AC84', '#654A39'],
      'cool-airy': ['#C7D6DF', '#F6F5F0', '#B7A083', '#465967'],
    },
    'dining': {
      'default': 'warm-natural',
      'warm-natural': ['#D5BCAA', '#FAF5EC', '#A98464', '#704C3B'],
      'soft-botanical': ['#C3D0BB', '#F8F4EA', '#AC9274', '#6E5242'],
      'cool-airy': ['#CFDCE0', '#F8F5EE', '#AA927D', '#5C4740'],
    },
    'kitchen': {
      'default': 'soft-botanical',
      'warm-natural': ['#E3D7C6', '#FAF8F2', '#BBAF9E', '#987454'],
      'soft-botanical': ['#D8E1D3', '#FAF8F2', '#B8B0A3', '#A7B39B'],
      'cool-airy': ['#D8E4E6', '#FBF9F4', '#B7C0C2', '#718184'],
    },
    'bathroom': {
      'default': 'cool-airy',
      'warm-natural': ['#E6DDD1', '#FBF9F4', '#C4B8AA', '#92745F'],
      'soft-botanical': ['#D4E0D7', '#FAFBF7', '#B8C2BA', '#789080'],
      'cool-airy': ['#D8E5E7', '#FBFBF8', '#B9C2C4', '#8A725F'],
    },
  };
  ```

  Assert IDs match `[a-z0-9-]+`, labels/text are non-empty, focal coordinates stay in `-1...1`, artboard dimensions are positive, exact-color matching returns a look, and `suggestedColors(surface)` de-duplicates projected look colors without reordering.

- [ ] **Step 2: Write failing baseline/session transition tests**

  Cover fresh grayscale; first custom seeding; exact-look/custom labels; saved reset retaining identity and becoming dirty; `discardChanges()`; manual return to baseline clearing dirty; save replacing baseline; rename updating current and baseline name; delete producing colored-dirty or grayscale-clean; six independent retained drafts; immutable map copies; activation/close; and invalid template updates.

- [ ] **Step 3: Run the three domain tests and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain/illustrated_room_test.dart test/features/room_studio/domain/illustrated_room_draft_test.dart test/features/room_studio/domain/illustrated_room_session_test.dart --reporter expanded
  ```

  Expected: compilation/assertion failures for absent metadata, baseline and session APIs.

- [ ] **Step 4: Implement the exact domain interfaces**

  ```dart
  final class IllustratedRoomFocalPoint {
    const IllustratedRoomFocalPoint({required double x, required double y});
    final double x;
    final double y;
  }

  final class IllustratedRoomSurfaceLabels {
    const IllustratedRoomSurfaceLabels({required String wall,
      required String ceiling, required String floor,
      required String furniture});
    String labelFor(IllustratedRoomSurface surface);
  }

  final class IllustratedRoomTemplate {
    IllustratedRoomTemplate({required String id, required String title,
      required String summary, required String assetPath,
      required String defaultPaletteId,
      required Iterable<IllustratedRoomPalette> palettes,
      required IllustratedRoomSurfaceLabels surfaceLabels,
      required IllustratedRoomFocalPoint focalPoint,
      int artboardWidth = 1200, int artboardHeight = 800,
      required String paletteReviewLabel,
      required String paletteSourceNote});
    IllustratedRoomPalette? matchingPalette(IllustratedRoomColors colors);
    List<RgbColor> suggestedColors(IllustratedRoomSurface surface);
  }

  final class IllustratedRoomPalette {
    IllustratedRoomPalette({required String id, required String name,
      required String guidance, required IllustratedRoomColors colors,
      String? provenance});
    final String? provenance;
  }

  final class IllustratedRoomDraft {
    bool get isDirty;
    bool get canSave;
    IllustratedRoomDraft applyPalette(String id);
    IllustratedRoomDraft setSurfaceColor(
      IllustratedRoomSurface surface, RgbColor color);
    IllustratedRoomDraft resetToGrayscale();
    IllustratedRoomDraft discardChanges();
    IllustratedRoomDraft markSaved({required String id,
      required String name});
    IllustratedRoomDraft renameSavedDesign({required String id,
      required String name});
    IllustratedRoomDraft asUnsavedAfterDelete();
  }

  final class IllustratedRoomSession {
    factory IllustratedRoomSession.empty();
    Map<String, IllustratedRoomDraft> get draftsByTemplateId;
    String? get activeTemplateId;
    IllustratedRoomDraft? get activeDraft;
    IllustratedRoomDraft? draftFor(String templateId);
    IllustratedRoomSession activate(IllustratedRoomTemplate template);
    IllustratedRoomSession closeEditor();
    IllustratedRoomSession putDraft(IllustratedRoomDraft draft,
        {bool activate = true});
    IllustratedRoomSession updateDraft(String templateId,
        IllustratedRoomDraft Function(IllustratedRoomDraft) update);
  }
  ```

  Use initial focal values Living `(0,.08)`, Bedroom `(.05,.05)`, Study `(0,0)`, Dining `(0,.08)`, Kitchen `(.05,0)`, Bathroom `(-.05,.02)`; Task 12 may update fixture and test together only if visual review proves cropping is poor.

- [ ] **Step 5: Run domain tests and formatting**

  Repeat the Step 3 command, then run the format command from Command Convention on the six Task 1 Dart paths.

  Expected: all three files PASS and format check exits 0.

- [ ] **Step 6: Commit the domain checkpoint**

  ```sh
  git add lib/features/room_studio/domain/illustrated_room.dart lib/features/room_studio/domain/illustrated_room_draft.dart lib/features/room_studio/domain/illustrated_room_session.dart test/features/room_studio/domain/illustrated_room_test.dart test/features/room_studio/domain/illustrated_room_draft_test.dart test/features/room_studio/domain/illustrated_room_session_test.dart
  git commit -m "feat: model multi-room color sessions"
  ```

### Task 2: Session controller, conflict guard and all-draft reconciliation

**Files:**
- Modify: `lib/features/room_studio/application/illustrated_room_controller.dart`
- Modify: `test/features/room_studio/application/illustrated_room_controller_test.dart`
- Minimal compile adaptations: `lib/features/room_studio/presentation/room_screen.dart`, `illustrated_room_screen.dart`

**Interfaces:**
- Consumes: `IllustratedRoomSession`, drafts and unchanged v1 repository/provider APIs.
- Produces: session-backed `illustratedRoomProvider`, typed conflict rejection and background-draft save/reconcile methods used by navigation/UI.

- [ ] **Step 1: Write failing controller tests**

  Test six retained drafts; active/close/discard; dirty target replacement rejection without mutation; accepted clean/replaced saved design; Study handoff using `soft-botanical`; background `saveDesign(name, templateId:)`; gated async save followed by newer edit; rename success updating every matching foreground/background name/baseline; delete success clearing every matching identity; and repository failure changing no draft.

- [ ] **Step 2: Run the controller test and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/illustrated_room_controller_test.dart --reporter expanded
  ```

  Expected: provider state/type and methods do not yet satisfy session cases.

- [ ] **Step 3: Implement the controller contract**

  ```dart
  final class IllustratedRoomDraftConflict implements Exception {
    const IllustratedRoomDraftConflict(this.templateId);
    final String templateId;
  }

  final illustratedRoomProvider =
      NotifierProvider<IllustratedRoomController, IllustratedRoomSession>(...);

  void openTemplate(IllustratedRoomTemplate template);
  void closeEditor();
  void discardActiveChanges();
  bool hasDirtyDraft(String templateId);
  void applyPalette(String paletteId);
  void setSurfaceColor(IllustratedRoomSurface surface, RgbColor color);
  void resetToGrayscale();
  void openDesign(SavedRoomDesign design, {bool replaceDirty = false});
  void applyWallHandoff(RgbColor color, {bool replaceDirty = false});
  Future<SavedRoomDesign> saveDesign(String name, {String? templateId});
  Future<void> deleteDesign(String id);
  Future<SavedRoomDesign> renameDesign(String id, String name);
  ```

  Snapshot and compare only the target draft when an async save returns. Reconcile rename/delete across every map entry only after repository success.

- [ ] **Step 4: Adapt current production consumers to select `activeDraft`**

  Keep current UI behavior compiling until its later replacement; do not redesign the screen in this task.

- [ ] **Step 5: Run controller, draft, saved-library and repository tests**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/illustrated_room_controller_test.dart test/features/room_studio/application/room_designs_providers_test.dart test/features/room_studio/domain/illustrated_room_draft_test.dart test/data/db/hive_room_design_repository_test.dart --reporter expanded
  ```

  Expected: all focused tests PASS; v1 persistence/schema tests remain unchanged.

- [ ] **Step 6: Commit the controller checkpoint**

  ```sh
  git add lib/features/room_studio/application/illustrated_room_controller.dart lib/features/room_studio/presentation/room_screen.dart lib/features/room_studio/presentation/illustrated_room_screen.dart test/features/room_studio/application/illustrated_room_controller_test.dart
  git commit -m "feat: retain independent room drafts"
  ```

### Task 3: Shared SVG contract, mapper and realistic Study

**Files:**
- Create: `lib/features/room_studio/rendering/illustrated_room_color_mapper.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_svg.dart`
- Modify: `assets/rooms/study_room.svg`
- Create: `test/support/illustrated_room_svg_contract.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: template/draft surfaces from Task 1.
- Produces: `IllustratedRoomColorMapper`, reusable structural scanner/raster helpers and the upgraded Study asset for screen/export and later asset tasks.

- [ ] **Step 1: Write failing shared-contract and mapper-location tests**

  `validateIllustratedRoomSvg(source, template)` must require viewBox `0 0 1200 800`, exactly one group/token owner, non-empty token geometry, no token in `<defs>`, and reject `<image>`, filters, scripts, animation, external/remote `href`, URLs and case-insensitive watermark text. Update tests to import the mapper from `rendering/` and assert contextual furniture semantics.

- [ ] **Step 2: Run the SVG test and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_svg_test.dart --reporter expanded
  ```

  Expected: missing shared helper/mapper location and new Study assertions fail.

- [ ] **Step 3: Move the shared mapper into `rendering/`**

  Preserve exact grayscale/token behavior and update the SVG widget/test imports; do not duplicate mapping logic.

- [ ] **Step 4: Re-author Study**

  Keep the four exact tokens and common unobstructed anchors Wall `(600,220)`, Ceiling `(600,40)`, Floor `(1100,760)`, Furniture `(600,590)`. Put the rug before furniture, decor after it; converge floor seams near `(600,552)`; add window reveal/folds, crown/baseboard depth, neutral-opacity volume planes, cool window light, restrained warm task light and contact shadows without SVG filters.

- [ ] **Step 5: Add rendered Study assertions**

  In grayscale and distinct-color drafts assert the four common anchors plus desktop `(600,538)`, office chair `(610,665)`, reading chair `(180,650)` and desk leg `(380,670)`. Assert one scene semantic node and authored decoration grayscale/preservation.

- [ ] **Step 6: Run SVG tests and format the task-owned Dart files**

  Repeat the Step 2 command, then format/check the mapper, SVG widget, helper and SVG test Dart paths.

  Expected: tests PASS, no render exception, and format check exits 0.

- [ ] **Step 7: Render and inspect a deterministic Study preview**

  Expected: correct depth, convergent floor, window lighting and rug/furniture layer order.

- [ ] **Step 8: Commit the Study/rendering checkpoint**

  ```sh
  git add lib/features/room_studio/rendering/illustrated_room_color_mapper.dart lib/features/room_studio/presentation/illustrated_room_svg.dart assets/rooms/study_room.svg test/support/illustrated_room_svg_contract.dart test/features/room_studio/presentation/illustrated_room_svg_test.dart
  git commit -m "feat: refine illustrated room rendering"
  ```

### Task 4: Living and Bedroom SVG assets

**Files:**
- Create: `assets/rooms/living_room.svg`
- Create: `assets/rooms/bedroom_room.svg`
- Modify: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: catalog paths, tokens and test helpers from Tasks 1/3.
- Produces: two validated semi-realistic assets.

- [ ] **Step 1: Add failing missing-asset/anchor tests for Living and Bedroom**

  Both use the four common anchors. Also pin Living sofa `(600,610)`, chair `(190,650)`, coffee table `(590,690)` and Bedroom headboard `(600,455)`, bed base `(600,650)`, wardrobe `(1030,420)` to the furniture token in distinct-color mode.

- [ ] **Step 2: Run the SVG test and verify RED for missing files**

  Repeat Task 3 Step 2. Expected: FAIL naming both missing asset paths.

- [ ] **Step 3: Author the original Living asset**

  Include sofa/chairs/media console/coffee table/rug/window with believable perspective, neutral translucent material planes, architectural depth and coherent window/lamp lighting; keep token anchor patches unobstructed.

- [ ] **Step 4: Author the original Bedroom asset**

  Include bed/headboard/side tables/wardrobe/textile seams with the same perspective, material and lighting contract.

- [ ] **Step 5: Run structural/raster tests**

  Repeat Task 3 Step 2.

  Expected: Study, Living and Bedroom validate and render without hidden editable pieces or watermarks.

- [ ] **Step 6: Inspect both grayscale/default previews**

  Expected: each scene reads as its intended room and each editable surface remains visually useful.

- [ ] **Step 7: Commit the asset pair**

  ```sh
  git add assets/rooms/living_room.svg assets/rooms/bedroom_room.svg test/features/room_studio/presentation/illustrated_room_svg_test.dart
  git commit -m "feat: add living and bedroom templates"
  ```

### Task 5: Dining, Kitchen and Bathroom SVG assets

**Files:**
- Create: `assets/rooms/dining_room.svg`
- Create: `assets/rooms/kitchen_room.svg`
- Create: `assets/rooms/bathroom_room.svg`
- Modify: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: same asset contract/renderer.
- Produces: complete six-room catalog artwork and catalog-wide render proof.

- [ ] **Step 1: Add failing tests for all three missing assets**

  Use the common surface anchors. Pin Dining table `(600,610)`, chair `(350,620)`, sideboard `(1000,560)`; Kitchen island `(600,610)`, left cabinets `(250,430)`, right cabinets `(950,430)`; Bathroom vanity `(400,590)` and storage `(980,480)` as editable furniture/cabinetry anchors.

- [ ] **Step 2: Run the SVG test and verify RED**

  Repeat Task 3 Step 2. Expected: FAIL naming Dining, Kitchen and Bathroom assets.

- [ ] **Step 3: Author Dining**

  Include table/chairs/pendant/sideboard and preserve vanishing points and contextual token meaning.

- [ ] **Step 4: Author Kitchen**

  Include cabinetry/island/counters with neutral fixed appliances and preserve vanishing points and contextual token meaning.

- [ ] **Step 5: Author Bathroom**

  Include vanity/storage/bath-or-shower/mirror with fixed neutral fittings; keep ceiling/floor visibly useful for comparison and avoid treating chrome/ceramic fixtures as user furniture.

- [ ] **Step 6: Add a catalog-wide render loop**

  For all six templates assert source validation, all-gray initial output, four distinct colored anchors, contextual scene semantics and no `tester.takeException()`.

- [ ] **Step 7: Run the catalog-wide SVG test**

  Run the exact Task 3 Step 2 command.

  Expected: PASS.

- [ ] **Step 8: Commit the remaining assets**

  ```sh
  git add assets/rooms/dining_room.svg assets/rooms/kitchen_room.svg assets/rooms/bathroom_room.svg test/features/room_studio/presentation/illustrated_room_svg_test.dart
  git commit -m "feat: complete illustrated room catalog"
  ```

### Task 6: Full-bleed editor, right rail and color flyouts

**Files:**
- Modify: `lib/features/room_studio/presentation/illustrated_room_controls.dart`
- Create: `lib/features/room_studio/presentation/illustrated_room_flyout.dart`
- Create: `lib/features/room_studio/presentation/illustrated_room_market_guide.dart`
- Rewrite: `lib/features/room_studio/presentation/illustrated_room_screen.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_screen_test.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_integration_test.dart`

**Interfaces:**
- Consumes: active session draft, template focal point/labels/looks and saved-design modal.
- Produces: template-addressed full-screen editor shell and reusable overlay controls. Task 11 later connects its export callback.

- [ ] **Step 1: Write failing full-bleed geometry/responsiveness tests**

  Test `IllustratedRoomScreen(templateId:)`, scene bounds unchanged when rail/flyout opens, rail widths 68dp below 720 and 72dp at/above 720, Fill default with focal alignment, Full room using `BoxFit.contain`, fixed Back/title/view controls, vertical rail scrolling and 48dp targets at 320 x 568, 390 x 844, 640 x 360 and 1024 x 768.

- [ ] **Step 2: Write failing interaction/accessibility tests**

  Pin keys `room-rail-looks`, `room-surface-<surface>`, `room-black-white`, `room-open-designs`, `room-save-gallery`, `room-flyout`, `room-flyout-close`, `room-view-fill`, `room-view-full`, and existing palette/custom/save keys. Test exact three looks; recommended marker; derived/deduplicated surface suggestions; first custom; contextual labels; non-color selected border/semantics; 2x text; 300dp keyboard inset; light/dark; reduced motion.

- [ ] **Step 3: Run screen/integration tests and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart --reporter expanded
  ```

  Expected: failures for the old sheet/side-panel layout and absent rail/flyout APIs.

- [ ] **Step 4: Implement the presentation interfaces**

  ```dart
  enum IllustratedRoomTool { looks, wall, ceiling, floor, furniture, designs }
  enum IllustratedRoomViewMode { fillScreen, fullRoom }

  class IllustratedRoomScreen extends ConsumerStatefulWidget {
    const IllustratedRoomScreen({super.key, required this.templateId});
    final String templateId;
  }

  class IllustratedRoomColorRail extends StatelessWidget {
    const IllustratedRoomColorRail({super.key,
      required IllustratedRoomDraft draft,
      required IllustratedRoomTool? activeTool,
      required int savedDesignCount, required bool exportBusy,
      required ValueChanged<IllustratedRoomTool> onToolSelected,
      required VoidCallback onBlackAndWhite,
      required VoidCallback? onSaveToGallery});
  }

  class IllustratedRoomFlyout extends StatelessWidget {
    const IllustratedRoomFlyout({super.key,
      required IllustratedRoomTool tool,
      required IllustratedRoomDraft draft,
      required VoidCallback onClose,
      required ValueChanged<String> onPaletteSelected,
      required ValueChanged<RgbColor> onSuggestedColor,
      required VoidCallback onCustomColor,
      required VoidCallback onMarketGuide,
      required Widget designsContent});
  }
  ```

  Keep scene `Positioned.fill`; overlay flyout width clamps to 232-300dp and never changes scene constraints. `Designs` is one rail target. Keep Gallery export visible but disabled until Task 11 supplies a colored/export-ready callback.

  Rail order is Looks, Wall, Ceiling, Floor, contextual Furniture, Black & white, Designs, Save to Gallery. The first version uses only the Fill/Full room toggle—do not add pan/zoom state.

- [ ] **Step 5: Implement Looks, surface and market-guide content**

  **Why these looks?** opens the reviewed-October-2026 guide with source inspirations and physical-swatch caveat.

- [ ] **Step 6: Implement dirty-exit semantics**

  Back on dirty shows Keep draft/Discard/Cancel; Keep calls `closeEditor`, Discard restores baseline then closes, Cancel stays.

- [ ] **Step 7: Run focused tests and format task-owned Dart files**

  Repeat the Step 3 command, then format/check the five Task 6 production/test Dart paths.

  Expected: screen/integration tests PASS at every pinned viewport and format check exits 0.

- [ ] **Step 8: Commit the editor checkpoint**

  ```sh
  git add lib/features/room_studio/presentation/illustrated_room_controls.dart lib/features/room_studio/presentation/illustrated_room_flyout.dart lib/features/room_studio/presentation/illustrated_room_market_guide.dart lib/features/room_studio/presentation/illustrated_room_screen.dart test/features/room_studio/presentation/illustrated_room_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart
  git commit -m "feat: add full-screen room color rail"
  ```

### Task 7: Lazy black-and-white gallery and routes

**Files:**
- Create: `lib/features/room_studio/presentation/illustrated_room_gallery_screen.dart`
- Modify: `lib/features/room_studio/presentation/room_screen.dart`
- Modify: `lib/routing/app_router.dart`
- Create: `test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_integration_test.dart`
- Modify intentional assertions in `test/features/room_studio/presentation/room_masks_integration_test.dart`

**Interfaces:**
- Consumes: six templates/session/editor.
- Produces: `/room/illustrated`, `/room/illustrated/:templateId`, compatibility redirect and lazy catalog.

- [ ] **Step 1: Write failing gallery/routing tests**

  Assert title **Choose a room**, approved explanatory copy, one-column phone/two-column wide lazy sliver, six 3:2 `room-template-<id>` cards in catalog order, stable 3:2 loading skeletons, text outside the important artwork, every preview constructed from a grayscale draft even with colored retained state, a Draft badge iff the retained room is not a fresh clean grayscale draft, correct focal alignment/semantics, one-card Retry isolation, and card tap activation/navigation.

- [ ] **Step 2: Add failing route tests**

  Pin `/room/illustrated`, all six dynamic routes, `/room/study` redirecting to `/room/illustrated/study`, and unknown IDs showing unavailable-room Back-to-gallery state rather than Study.

- [ ] **Step 3: Run gallery/integration tests and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart --reporter expanded
  ```

  Expected: missing gallery/routes/CTA failures.

- [ ] **Step 4: Implement the lazy gallery**

  Use `CustomScrollView` plus lazy sliver, stable skeletons, card-local error state, `BoxFit.cover` and focal alignment.

- [ ] **Step 5: Wire Room CTA and root routes**

  Replace RoomScreen's eager template loop with `open-illustrated-gallery`. Register gallery/editor routes outside the indexed tab shell. Deep-link editor initialization must activate its valid template in `initState` without needing a prior gallery tap.

- [ ] **Step 6: Run gallery, integration and Room-mask route regressions**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart --reporter expanded
  ```

  Expected: new paths/CTA pass and real-photo draft behavior remains unchanged.

- [ ] **Step 7: Commit the gallery checkpoint**

  ```sh
  git add lib/features/room_studio/presentation/illustrated_room_gallery_screen.dart lib/features/room_studio/presentation/room_screen.dart lib/routing/app_router.dart test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart
  git commit -m "feat: add illustrated room gallery"
  ```

### Task 8: Designs flyout and conflict-safe saved/handoff navigation

**Files:**
- Create: `lib/features/room_studio/presentation/illustrated_room_navigation.dart`
- Modify: `lib/features/room_studio/presentation/saved_room_designs_sheet.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_flyout.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_gallery_screen.dart`
- Modify: `lib/features/picker/presentation/color_explorer.dart`
- Create: `test/features/room_studio/presentation/illustrated_room_navigation_test.dart`
- Modify: `test/features/room_studio/presentation/saved_room_designs_sheet_test.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart`
- Modify handoff assertions in Picker, Formula and Room integration tests.

**Interfaces:**
- Consumes: controller-level dirty conflict guard, saved-design provider and new routes.
- Produces: reusable `SavedRoomDesignsList` plus two atomic coordinators.

- [ ] **Step 1: Write failing reusable Designs UI tests**

  Pin one Designs rail target whose flyout contains Save/Update and `SavedRoomDesignsList`; a gallery-header **Saved designs** action; All/room filters defaulting to All; contextual swatches; open/rename/delete; background rename/delete reconciliation; unavailable record preservation; load/mutation retry; design count/saveability semantics.

- [ ] **Step 2: Write failing replacement-coordinator tests**

  Colored dirty target: Save current/Replace/Cancel. Grayscale dirty target: Replace/Cancel only. Clean target: no prompt. Save failure/cancel, Replace, and Cancel must leave route/session/`roomColorProvider` exactly as approved; successful background save must become durable before open/handoff continues.

- [ ] **Step 3: Run navigation/saved-design tests and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_navigation_test.dart test/features/room_studio/presentation/saved_room_designs_sheet_test.dart test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart --reporter expanded
  ```

  Expected: absent coordinator/reusable-list and direct-row-mutation failures.

- [ ] **Step 4: Refactor the saved-design library into reusable filtered content**

  Keep the modal wrapper for the gallery while embedding the same list in the Designs flyout. Selection returns/calls the supplied `onOpen`; rows no longer mutate the controller directly.

- [ ] **Step 5: Implement exact navigation APIs**

  ```dart
  Future<bool> openIllustratedSavedDesign(
    BuildContext context,
    SavedRoomDesign design,
  );

  Future<bool> openStudyWallHandoff(
    BuildContext context,
    RgbColor color,
  );

  class SavedRoomDesignsList extends ConsumerWidget {
    const SavedRoomDesignsList({super.key, required this.onOpen,
      this.initialTemplateId});
    final Future<void> Function(SavedRoomDesign) onOpen;
    final String? initialTemplateId;
  }
  ```

  Add optional `templateId` to the save-name dialog/callback for background saves. Mutate `roomColorProvider` only after handoff conflict acceptance.

- [ ] **Step 6: Update intentional handoff/route assertions**

  Replace obsolete provider-state, route and palette expectations without weakening unrelated mask/history assertions.

- [ ] **Step 7: Run all handoff/navigation tests**

  Include `color_details_actions_test.dart`, Formula integration and Room-mask integration. Expected: accepted handoff opens `/room/illustrated/study`, seeds complete Soft Botanical plus Wall override, while mask/history state survives; Cancel performs no mutation.

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_navigation_test.dart test/features/room_studio/presentation/saved_room_designs_sheet_test.dart test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart test/features/picker/color_details_actions_test.dart test/features/formula/presentation/formula_integration_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart --reporter expanded
  ```

- [ ] **Step 8: Commit the navigation/designs checkpoint**

  ```sh
  git add lib/features/room_studio/presentation/illustrated_room_navigation.dart lib/features/room_studio/presentation/saved_room_designs_sheet.dart lib/features/room_studio/presentation/illustrated_room_flyout.dart lib/features/room_studio/presentation/illustrated_room_gallery_screen.dart lib/features/picker/presentation/color_explorer.dart test/features/room_studio/presentation/illustrated_room_navigation_test.dart test/features/room_studio/presentation/saved_room_designs_sheet_test.dart test/features/room_studio/presentation/illustrated_room_gallery_screen_test.dart test/features/picker/color_details_actions_test.dart test/features/formula/presentation/formula_integration_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart
  git commit -m "feat: protect retained room design drafts"
  ```

### Task 9: Gallery dependency, platform contract and injected writer

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`
- Create: `lib/features/room_studio/application/room_gallery_writer.dart`
- Create: `test/features/room_studio/application/gallery_platform_config_test.dart`
- Create: `test/features/room_studio/application/room_gallery_writer_test.dart`

**Interfaces:**
- Consumes: validated PNG bytes and existing `path_provider`/`permission_handler`.
- Produces: least-privilege `RoomGalleryWriter`, typed failures and Settings callback for Tasks 10-11.

- [ ] **Step 1: Write failing platform metadata tests**

  Require exactly capped Android write permission, read permission only as `tools:node="remove"`, no read-media/all-files/requestLegacy entry, and non-empty iOS `NSPhotoLibraryAddUsageDescription` while retaining the existing read purpose.

- [ ] **Step 2: Write failing writer validation/mapping tests**

  Test PNG signature; safe `.png` filename; detached bytes; exact-name owned temporary file existing during callback; cleanup after success/all failures; no custom album; and mappings for every `GalExceptionType`, `MissingPluginException` and unsupported target platform.

- [ ] **Step 3: Run writer/config tests and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/gallery_platform_config_test.dart test/features/room_studio/application/room_gallery_writer_test.dart --reporter expanded
  ```

  Expected: missing writer/dependency and current platform-metadata failures.

- [ ] **Step 4: Add exact dependencies and resolve offline**

  Add direct `gal: 2.3.2` and `vector_graphics: 1.2.4`, run guarded `flutter pub get --offline`, and assert lockfile marks both direct main. Do not use network fallback.

- [ ] **Step 5: Apply the platform metadata contract**

  Replace only the Android write-removal directive with capped write access; add the iOS add-only purpose string and no other permission.

- [ ] **Step 6: Implement the writer contract**

  ```dart
  enum RoomGalleryFailure {
    accessDenied, notEnoughSpace, unsupportedFormat,
    unsupportedPlatform, unexpected,
  }

  final class RoomGalleryWriteException implements Exception {
    const RoomGalleryWriteException(this.failure);
    final RoomGalleryFailure failure;
  }

  abstract interface class RoomGalleryWriter {
    Future<void> savePng({required Uint8List pngBytes,
      required String fileName});
  }
  ```

  `GalRoomGalleryWriter` writes the exact safe filename into a unique owned temp directory, flushes, calls injected `Gal.putImage(path)` (which requests access at the write boundary), and deletes only owned temp content in `finally`. Do not use an album. Provide `roomGalleryWriterProvider` and `roomGallerySettingsProvider` (`openAppSettings`). Treat plugin access denial, including repeat/permanent denial, as the same truthful `accessDenied` result; do not claim the plugin can distinguish them.

- [ ] **Step 7: Run writer/config tests and formatting**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/gallery_platform_config_test.dart test/features/room_studio/application/room_gallery_writer_test.dart --reporter expanded
  ```

  Then format/check `room_gallery_writer.dart` and its two tests.

  Expected: PASS with no real method-channel call.

- [ ] **Step 8: Commit dependency/platform writer checkpoint**

  ```sh
  git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist lib/features/room_studio/application/room_gallery_writer.dart test/features/room_studio/application/gallery_platform_config_test.dart test/features/room_studio/application/room_gallery_writer_test.dart
  git commit -m "feat: add least-privilege gallery writer"
  ```

### Task 10: Canonical SVG encoder and serialized export controller

**Files:**
- Create: `lib/features/room_studio/application/illustrated_room_artwork_encoder.dart`
- Create: `lib/features/room_studio/application/illustrated_room_export_controller.dart`
- Create: `test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart`
- Create: `test/features/room_studio/application/illustrated_room_export_controller_test.dart`

**Interfaces:**
- Consumes: shared mapper, `SvgAssetLoader`, direct `vector_graphics`, gallery writer and colored draft.
- Produces: clean PNG bytes and coalesced UI-facing export result/state.

- [ ] **Step 1: Write failing encoder tests**

  Using the real Study asset, assert colored-only input, PNG signature, decoded 2400 x 1600 size, scaled token anchors `(1200,440)`, `(1200,80)`, `(2200,1520)`, `(1200,1180)`, preserved authored decor, complete 3:2 output independent of screen crop, typed missing/incompatible asset failure and no raw exception leakage.

- [ ] **Step 2: Run encoder tests and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart --reporter expanded
  ```

  Expected: missing encoder types.

- [ ] **Step 3: Implement the encoder interface**

  ```dart
  abstract interface class IllustratedRoomArtworkEncoder {
    Future<Uint8List> encodePng(IllustratedRoomDraft draft);
  }

  final class IllustratedRoomRenderException implements Exception {
    const IllustratedRoomRenderException();
  }
  ```

  Load `SvgAssetLoader(assetPath, colorMapper:)` with `vg.loadPicture`, require 1200 x 800 `PictureInfo.size`, draw into a new recorder scaled 2x, call `toImage(2400,1600)` and PNG `toByteData`, detach bytes, and dispose source picture/scaled picture/image in `finally`. Add injectable picture loader for disposal/failure tests. No `compute`.

- [ ] **Step 4: Write failing export-controller tests**

  Pin phase sequence `idle -> rendering -> saving -> idle`, exact filename `color-lab-study-20261025T040000123Z.png`, encode-before-write, detached bytes, two gated concurrent calls coalescing into one encode/write, grayscale zero-work failure, every typed mapping, retry after failure and no retained PNG.

- [ ] **Step 5: Run export-controller tests and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/illustrated_room_export_controller_test.dart --reporter expanded
  ```

  Expected: missing controller state/result/provider types.

- [ ] **Step 6: Implement controller types/API**

  ```dart
  enum IllustratedRoomExportPhase { idle, rendering, saving }
  final class IllustratedRoomExportState {
    const IllustratedRoomExportState(this.phase);
    final IllustratedRoomExportPhase phase;
    bool get isBusy;
  }
  enum IllustratedRoomExportFailure {
    notColored, renderFailed, accessDenied, notEnoughSpace,
    unsupportedFormat, unsupportedPlatform, unexpected,
  }
  sealed class IllustratedRoomExportResult { const IllustratedRoomExportResult(); }
  final class IllustratedRoomExportSuccess extends IllustratedRoomExportResult {
    const IllustratedRoomExportSuccess(this.fileName);
    final String fileName;
  }
  final class IllustratedRoomExportFailed extends IllustratedRoomExportResult {
    const IllustratedRoomExportFailed(this.failure);
    final IllustratedRoomExportFailure failure;
  }

  Future<IllustratedRoomExportResult> saveToGallery(
      IllustratedRoomDraft draft);
  ```

  Add `illustratedRoomArtworkEncoderProvider`,
  `illustratedRoomExportProvider`, and `roomExportClockProvider`; coalesce calls
  on one `_inFlight` future and always restore idle in `finally`.

- [ ] **Step 7: Run encoder/controller tests and formatting**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart test/features/room_studio/application/illustrated_room_export_controller_test.dart --reporter expanded
  ```

  Then format/check the four Task 10 Dart paths.

  Expected: PASS; real PNG is 2400 x 1600 and no export calls a platform channel.

- [ ] **Step 8: Commit export core checkpoint**

  ```sh
  git add lib/features/room_studio/application/illustrated_room_artwork_encoder.dart lib/features/room_studio/application/illustrated_room_export_controller.dart test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart test/features/room_studio/application/illustrated_room_export_controller_test.dart
  git commit -m "feat: render illustrated rooms for gallery"
  ```

### Task 11: Save-to-Gallery editor integration

**Files:**
- Modify: `lib/features/room_studio/presentation/illustrated_room_screen.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_controls.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_screen_test.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_integration_test.dart`

**Interfaces:**
- Consumes: export provider/result from Task 10 and Settings callback from Task 9.
- Produces: final enabled/loading/success/failure UX without changing draft state.

- [ ] **Step 1: Write failing export widget tests**

  Override encoder/writer/settings. Assert Gallery action disabled in grayscale/busy, colored save invokes each service once, repeated taps while gated do not duplicate, success says `Saved to Gallery`, access denied alone shows Settings, Settings callback fires once, each storage/format/platform/render/unexpected failure has safe distinct copy, retry becomes available and draft/colors remain identical.

- [ ] **Step 2: Run screen/integration tests and verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart --reporter expanded
  ```

  Expected: Gallery action remains disabled/unwired and result feedback is absent.

- [ ] **Step 3: Connect the rail action to the export controller**

  Watch phase for progress/disable state. Handle result after `await` only while mounted; use one live-region Snackbar/message per result and never put raw exception text in UI.

- [ ] **Step 4: Run editor, export-core and integration tests**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart test/features/room_studio/application/illustrated_room_export_controller_test.dart test/features/room_studio/application/room_gallery_writer_test.dart --reporter expanded
  ```

  Expected: all PASS, no Gallery method channel reached, rail geometry still unchanged.

- [ ] **Step 5: Commit editor export integration**

  ```sh
  git add lib/features/room_studio/presentation/illustrated_room_screen.dart lib/features/room_studio/presentation/illustrated_room_controls.dart test/features/room_studio/presentation/illustrated_room_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart
  git commit -m "feat: save room artwork to gallery"
  ```

### Task 12: Preview evidence, documentation and guarded regression verification

**Files:**
- Create: `tool/render_illustrated_room_previews.dart`
- Delete: `tool/render_study_room_previews.dart`
- Modify: `tool/render_previews.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes: completed catalog/editor/export behavior.
- Produces: deterministic visual evidence, current user documentation and final verification report; no app/native artifact.

- [ ] **Step 1: Add the failing/updated preview scenarios**

  Generate six canonical grayscale artworks, six recommended-color artworks, gallery phone/tablet, editor phone rail closed/open, 640 x 360 landscape and 1024 x 768 tablet. Use fixed clock/repository/export fakes and the new palette IDs/routes.

- [ ] **Step 2: Run preview generation tests**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub tool/render_illustrated_room_previews.dart --reporter expanded
  ```

  Expected: all requested PNGs are written with no render exception.

- [ ] **Step 3: Inspect every preview PNG**

  Check perspective, rug/furniture ordering, contact shadows, material cues, four visibly distinct editable surfaces, focal crop, rail contrast and absence of overflow/watermarks. If a focal point changes, update its literal catalog fixture/test together and rerun all affected captures.

- [ ] **Step 4: Update README**

  Document six templates, B&W-first behavior, display-only market guidance, explicit durable save, clean Gallery export/privacy and physical-swatch warning.

- [ ] **Step 5: Audit for obsolete illustrated-room assertions**

  ```sh
  rg -n "/room/study|focus-sage|bright-neutral|cool-focus|warm-creative|open-illustrated-study" lib test tool README.md
  ```

  Expected: only the intentional compatibility redirect/spec/history references remain. Any product/test hit returns to its owning earlier task before final verification.

- [ ] **Step 6: Run all focused room tests under the guard**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio test/data/db/hive_room_design_repository_test.dart test/features/picker/color_details_actions_test.dart test/features/formula/presentation/formula_integration_test.dart --reporter expanded
  ```

  Expected: PASS. If the known `objective_c` host hook requests a compiler, report the guard denial and do not weaken the guard.

- [ ] **Step 7: Run formatting checks**

  ```sh
  /Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test tool
  ```

  Expected: exit 0. If unrelated pre-existing files fail, record them separately and run the same command on the exact task-owned paths.

- [ ] **Step 8: Run full tests without building**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
  ```

  Record exact pass counts or the exact guard/toolchain blocker.

- [ ] **Step 9: Run full analysis without building**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub
  ```

  Record the exact clean result or blocker. Do not invoke any build/native command.

- [ ] **Step 10: Run final fresh review**

  Use `superpowers:requesting-code-review`, resolve only verified in-scope findings, then re-run affected focused checks.

- [ ] **Step 11: Commit documentation/evidence source**

  ```sh
  git add tool/render_illustrated_room_previews.dart tool/render_study_room_previews.dart tool/render_previews.dart README.md
  git commit -m "test: verify multi-room color gallery"
  ```

  Any remaining task-owned test edits must be staged by exact reviewed path;
  never stage the whole `test` directory. Skip the commit checkpoint if an
  overlapping user change cannot be isolated safely.
