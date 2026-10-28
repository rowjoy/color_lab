# TintAtlas Coloring Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an offline, calm, original, and accessible Coloring Studio with 12 drawings, separate Guided and Free projects, durable editing, clean export/share, and value-copy bridges to Learning and Illustrated Rooms.

**Architecture:** Use a restricted versioned JSON artwork format containing only explicit `M`, `L`, `Q`, `C`, and `Z` path commands. The shared vector-region contract builds one authoritative `Path` per region and reuses it for paint, reverse-order hit testing, accessibility bounds, thumbnails, and export. Store each project independently with atomic acknowledgement and bounded edit history.

**Tech Stack:** Flutter CustomPainter/Path/Matrix4, Riverpod, GoRouter, Hive, `image`/Share services already used by the app, generated Flutter localization, Flutter unit/golden/widget tests.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md` (COLOR-01–12)

## Execution status — 2026-10-28

Implementation is on branch `TintAtlas`. The approved coding and focused automated scope is complete. Android/iOS builds and the full repository suite remain deferred until Plans 01–08 are ready together. The user owns the commit. No separate Plan 07 progress document was created; this is the authoritative execution record. The detailed checkboxes below retain the original implementation procedure, including commit and external-review steps, so this table records the actual result.

| Task | Status | Implemented / verified | Still open |
|---|---|---|---|
| 1. Shared schema | **Automated scope done** | Added immutable drawing/slot/rule types on the shared vector contract. Runtime and standalone validation share strict path rules for initial move, command arity/order, closed contours, finite in-bounds coordinates, IDs, labels, slots, and paint order. Domain and malformed-fixture tests pass. | Independent release review only. |
| 2. Shared geometry | **Automated scope done** | Paint, reverse hit testing, focus semantics, thumbnails, and clean export use the same paths/transform. Covered fit, pan, zoom, resize, overlap, holes, tiny regions, clipping, second-pointer cancellation, and export parity. | Real-device gesture and assistive-technology checks. |
| 3. Pilot art | **Automated scope done** | Added original Apple and Cozy Living assets, strict localized manifest metadata/hash loading, artwork notice, exact file-set validation, and recursive forbidden manufacturer/shade metadata checks. | Independent human light/dark/high-contrast and rights acceptance. |
| 4. Durable projects | **Automated scope done** | Added independent Guided/Free projects, bounded history, schema/local-data registration, corrupt-row isolation, and dual-slot generation commits. Local Data now reports logical project IDs while retaining every physical commit/slot row for exact deletion and invalidation. | Real process-death/storage-pressure evidence. |
| 5. Save-aware controller | **Done** | Added visible/durable state, serialized saves, retry, acknowledgement publishing, authoritative reopen, and revision-bound Finish. Controller/provider focused tests pass. | Full lifecycle/process-death device evidence. |
| 6. Guided Color | **Automated scope done** | Added adaptive workspace, exact authored-color acceptance, labeled/numbered swatches, region list, explicit no-canvas Apply, progress, Find, Undo/Redo, save failure/retry, and compact-landscape handling. Automated compact, 200% text, RTL, and semantics checks pass. | Manual keyboard, TalkBack/VoiceOver, reduced-motion, and real-device matrix. |
| 7. Free Color | **Automated scope done** | Added suggested, copied Learning, My Colors, My Palettes, and validated custom HEX sources with region-first interaction and Undo/Redo. Tests prove invalid HEX is rejected and copied RGB/HEX values remain unchanged after source color/palette deletion. | Manual exploratory input/accessibility checks. |
| 8. Catalog/library/export | **Automated scope done** | Added `/coloring` routes, All/Guided/Free catalog filter, direct selected-mode start, separate IDs, retained filters after Back, responsive content-driven compact cards, completion, My Artwork actions, metadata-clean PNG export, and shared canonical linework. Real-provider route tests cover export/save failure, dismissed/unavailable share, invalid projects, and project preservation. | Native gallery/share permission denial and low-space checks on devices. |
| 9. Twelve-drawing pack | **Automated scope done** | Added exactly 12 original JSON drawings, three per category, with locked slots, hashes, localization keys, and rights notice. Validator passes. A 96-render matrix covers every drawing in four states at compact and tablet sizes; the agent review found no obvious missing regions or seams. | Independent human art/interaction acceptance and release-ledger sign-off. |
| 10. Accessibility/bridges | **Automated scope done** | Externalized 112 Coloring messages with safe fallbacks and locale-aware canvas semantics. Tests cover RTL, Learning payload/return navigation, source deletion, explicit room assignment/cancel preservation, catalog Back behavior, responsive layouts, and semantics. | Real TalkBack/VoiceOver, keyboard, and RTL-device checks. |
| 11. Verification close | **Focused automated gate complete** | Catalog validation reports 12 drawings/4 balanced categories; scoped analysis is clean; the final integrated focused suite passed 142/142. A fresh read-only review found no Critical issue; its two Important and two Minor findings were fixed, four focused regressions passed, and re-review found no remaining Critical/Important issue. | Full repository suite, Android/iOS builds, device/process-death/low-storage/native-share checks, independent rights/visual acceptance, and the user-owned commit. |

### Focused evidence retained for this execution

- Catalog validator: `Coloring catalog valid: 12 original drawings, 4 balanced categories.`
- Final integrated command: `flutter test --no-pub test/core/vector_regions test/features/coloring test/data/db/hive_coloring_project_repository_test.dart test/tool/validate_coloring_catalog_test.dart test/l10n/localization_contract_test.dart --reporter compact` — **142/142 passed**.
- Scoped final analysis of the Plan 07 production, validator, localization, storage, and test paths reported **No issues found** after two info-only style corrections.
- Localization generation produced 112 Coloring messages; translated RTL catalog/canvas coverage and safe unknown-key fallbacks pass.
- Render evidence: 12 drawings × 4 project states × 2 viewport sizes = 96 renders, plus overlap/hole/tiny-region/pan/zoom/resize parity checks.
- Local Data repository, manager, and settings verification passed with logical project counts and physical-row deletion coverage.
- Post-review regressions pass for delayed save after Back, compact 320×568 catalog at 200% text, generated Games entry copy, and unavailable My Artwork sharing; affected-path analysis is clean and read-only re-review reports no remaining Critical/Important issue.

### Deliberately deferred, not silently marked complete

- Full repository suite and Android/iOS builds, per the approved Plans 01–08 workflow.
- Real-device process death, low storage, native gallery/share permission, keyboard, TalkBack/VoiceOver, reduced-motion, and RTL checks.
- Independent human artwork/rights review in light, dark, and high-contrast modes at phone and tablet sizes.
- Release-ledger sign-off and commit; the user owns the commit.

## Global Constraints

- Read the master, Foundation, and Illustrated Rooms v2 plans first; consume the shared vector-region contract frozen by the Illustrated pilot instead of creating a second geometry model.
- The first pack contains exactly 12 original drawings: three Fruit, three Animals, three Trees/Nature, and three Rooms; source/license evidence is mandatory.
- Guided Color accepts only the exact authored slot color, wrong taps change zero assignments, Find Region is free, and there is no timer, score, lives, coins, or penalty.
- Free Color accepts suggested colors, saved colors, saved palettes, or custom HEX and supports Undo/Redo.
- Guided and Free always use different project IDs and never overwrite one another.
- Projects copy HEX values; deleting a source palette/color cannot alter a project. Room designs and Coloring projects remain separate records.
- The workspace and completion flow are ad-free; user content stays local unless the user explicitly invokes platform Share.
- COLOR-13/14 are post-launch and COLOR-15 is deferred; do not add Match the Picture scoring or freehand brushes here.

## Review Focus

- Screen paint, hit testing, focus/highlight, thumbnails, and export resolve from identical path geometry at every pan/zoom/window state.
- A failed write retains the visible draft and exposes Retry while restart restores the last acknowledged revision.
- Holes, overlaps, reverse paint order, tiny regions, second pointers, and resize cannot fill the wrong region.
- A screen-reader/keyboard user can choose a region and labeled swatch, find remaining work, undo, finish, and export without canvas gestures.
- All art is demonstrably original and contains no copied competitor composition, names, codes, trademarks, or metadata.

## Locked launch artwork manifest

These are authored target snapshots for Guided mode, not claims that an object has only one possible real-world color. Region rules reference stable slot IDs; labels remain visible so correctness never depends on hue alone.

| Drawing ID / asset | Category | Difficulty | Ordered target slots |
|---|---|---|---|
| `fruit_red_apple` / `fruit_red_apple.json` | Fruit | Easy | apple red `#D94B45`, leaf green `#4F8A4C`, stem brown `#7A5230`, highlight cream `#F7D7C4` |
| `fruit_orange_slice` / `fruit_orange_slice.json` | Fruit | Easy | peel orange `#F28C28`, flesh orange `#FFB347`, pith cream `#FFF1D0`, seed tan `#C9914B` |
| `fruit_berry_bowl` / `fruit_berry_bowl.json` | Fruit | Medium | berry red `#D94B45`, berry blue `#4F5FA8`, leaf green `#4F8A4C`, bowl blue `#6FA8C9`, rim cream `#E8E1D5` |
| `animal_butterfly` / `animal_butterfly.json` | Animals | Easy | wing gold `#F4B942`, wing coral `#E76F51`, body charcoal `#4A4A4A`, spot violet `#5B5F97` |
| `animal_tropical_fish` / `animal_tropical_fish.json` | Animals | Medium | body turquoise `#2A9D8F`, stripe yellow `#F4D35E`, stripe coral `#F28C6B`, fin blue `#3D5A80`, eye charcoal `#1F2933` |
| `animal_parrot` / `animal_parrot.json` | Animals | Hard | feather red `#D64545`, feather green `#4F8A4C`, feather blue `#3D7EA6`, chest yellow `#F2C94C`, beak orange `#D9822B` |
| `nature_leafy_tree` / `nature_leafy_tree.json` | Trees/Nature | Easy | leaf green `#4F8A4C`, leaf light green `#8FBF5F`, trunk brown `#7A5230`, ground tan `#C9A66B` |
| `nature_sunflower` / `nature_sunflower.json` | Trees/Nature | Medium | petal yellow `#F2C94C`, center brown `#6B4423`, leaf green `#4F8A4C`, sky blue `#A7D8F0` |
| `nature_mountain_grove` / `nature_mountain_grove.json` | Trees/Nature | Hard | mountain slate `#768692`, pine green `#365C45`, sky blue `#A7D8F0`, snow white `#F2F4F3`, earth gray `#8A7F68` |
| `room_cozy_living` / `room_cozy_living.json` | Rooms | Medium | wall linen `#D8C7AC`, sofa sage `#78866B`, wood brown `#7A5230`, rug coral `#C9826B`, accent slate `#3F5362` |
| `room_calm_bedroom` / `room_calm_bedroom.json` | Rooms | Medium | wall mist `#C9D3D8`, bedding cream `#ECE9DF`, blanket blue `#667989`, wood tan `#A89073`, accent sage `#B7C2A3` |
| `room_reading_corner` / `room_reading_corner.json` | Rooms | Hard | wall linen `#F2E9DA`, chair clay `#9B6553`, shelf brown `#5C554D`, plant green `#4F8A4C`, lamp gold `#D8B96A` |

---

### Task 1: Freeze the shared vector-region and drawing schemas

**Files:**
- Consume unchanged: `lib/core/vector_regions/domain/vector_region_geometry.dart`
- Consume unchanged: `lib/core/vector_regions/data/vector_region_json_codec.dart`
- Consume unchanged: `lib/core/vector_regions/rendering/vector_region_renderer.dart`
- Create: `lib/features/coloring/domain/drawing_definition.dart`
- Create: `lib/features/coloring/domain/drawing_geometry.dart`
- Consume unchanged: `test/core/vector_regions/vector_region_json_codec_test.dart`
- Create: `test/features/coloring/domain/drawing_definition_test.dart`

**Interfaces:**

```dart
enum VectorPathVerb { move, line, quadratic, cubic, close }

final class VectorRegionGeometry {
  final List<VectorPathCommand> commands;
  Path toPath();
}

enum DrawingCategory { fruit, animals, treesNature, rooms }
enum DrawingDifficulty { easy, medium, hard }
enum ColoringMode { guided, free }

final class DrawingDefinition {
  final String id;
  final int revision;
  final DrawingCategory category;
  final DrawingDifficulty difficulty;
  final VectorArtworkDefinition artwork;
  final List<DrawingColorSlot> slots;
  final Map<String, DrawingRegionRule> regionRules;
}

final class DrawingRegionRule {
  final String regionId;
  final String? targetSlotId;
  final bool required;
}
```

`DrawingDefinition.artwork` is the exact shared `VectorArtworkDefinition`; its regions are the exact shared `VectorRegionDefinition(id, labelKey, groupId, fillable, paintOrder, geometry)`. `regionRules` may add coloring behavior by stable region ID but may not duplicate a path, label, order, or bounds. Schema version 1 allows only finite intrinsic/coordinate values and `M/L/Q/C/Z`; no arbitrary SVG/XML, script, external reference, transform string, raster data, or executable input is accepted.

- [ ] **Step 1: Write RED drawing validator tests and rerun the frozen core codec tests.** Cover unknown versions/keys/commands, nonfinite and out-of-bounds points, missing initial move/close, holes, duplicate IDs/orders, missing labels/slots, empty paths, and deterministic round trips.
- [ ] **Step 2: Run `flutter test --no-pub test/core/vector_regions test/features/coloring/domain/drawing_definition_test.dart --reporter expanded`.** Expected: FAIL.
- [ ] **Step 3: Implement immutable drawing types on the already-frozen restricted codec.** If the shared contract is absent or incompatible, stop and amend the Illustrated plan; do not create a feature-local substitute.
- [ ] **Step 4: Re-run parser/domain tests and format the touched files.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: define Coloring Studio artwork contract"`.

### Task 2: Implement one transform for render, hit testing, focus, and export

**Files:**
- Consume unchanged: `lib/core/vector_regions/application/vector_region_transform.dart`
- Consume unchanged: `lib/core/vector_regions/application/vector_region_hit_tester.dart`
- Consume unchanged: `lib/core/vector_regions/rendering/vector_region_renderer.dart`
- Create: `lib/features/coloring/presentation/coloring_canvas.dart`
- Create: `test/features/coloring/application/coloring_vector_region_integration_test.dart`
- Create: `test/features/coloring/presentation/coloring_canvas_test.dart`

**Interfaces:**

```dart
final class VectorRegionTransform {
  factory VectorRegionTransform.fit({required Size viewportSize, required Rect artworkBounds, required double userScale, required Offset userPan});
  Matrix4 get artworkToScreen;
  Offset screenToArtwork(Offset point);
  Offset artworkToScreenPoint(Offset point);
}

VectorRegionDefinition? hitTestVectorRegion({required VectorArtworkDefinition artwork, required Offset artworkPoint});
```

The renderer caches only values derived from the immutable definition and invalidates on definition, assignment, selection, viewport, scale, pan, text direction, or contrast changes.

- [ ] **Step 1: Write RED coordinate tests.** Use the same artwork point through fit/pan/zoom/resize, holes, overlapping reverse paint order, clipped bounds, tiny regions, and a second-pointer cancellation sequence.
- [ ] **Step 2: Run the focused transform/hit/canvas tests.** Expected: FAIL.
- [ ] **Step 3: Adapt drawing regions to the shared renderer, transform, and reverse-order hit tester; implement highlight and semantic bounds from the same built Paths.** Pan/zoom and a second pointer cannot commit a fill; do not add a feature-local renderer, second transform, or hit-test engine.
- [ ] **Step 4: Add a rendered-image comparison proving viewport paint and clean export use the same assignments/geometry after only the expected fit transform.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: add transform-safe coloring renderer"`.

### Task 3: Create and validate the first two original pilot drawings

**Files:**
- Create: `assets/coloring/manifest.json`
- Create: `assets/coloring/fruit_red_apple.json`
- Create: `assets/coloring/room_cozy_living.json`
- Create: `assets/licenses/coloring-artwork-NOTICE.txt`
- Create: `lib/features/coloring/data/drawing_catalog_loader.dart`
- Create: `test/features/coloring/data/drawing_catalog_loader_test.dart`
- Create: `tool/validate_coloring_catalog.dart`
- Modify: `pubspec.yaml`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**

```dart
abstract interface class DrawingCatalogLoader {
  Future<List<DrawingDefinition>> load();
  Future<DrawingDefinition> loadById(String drawingId);
}
```

Manifest entries include stable ID/revision, asset path, localized title/description keys, category, difficulty, authorship/source note, and content hash.

- [ ] **Step 1: Record authorship and review evidence before drawing production.** The notice states creator/source/tool and confirms no competitor artwork was traced or copied.
- [ ] **Step 2: Write RED catalog tests and validator fixtures.** Assert content hashes, exact manifest/file agreement, approximately three-to-five authored color slots, large usable regions, labels, bounds, hole validity, and no forbidden manufacturer/shade terms.
- [ ] **Step 3: Create the Apple and Cozy Living pilot JSON assets with distinct original compositions and run `dart run tool/validate_coloring_catalog.dart`.** Expected: PASS only after every path/metadata issue is resolved.
- [ ] **Step 4: Visually inspect light/dark/high-contrast previews at phone and tablet sizes and attach evidence to the verification ledger.** Do not approve art from parser tests alone.
- [ ] **Step 5: Commit.** `git commit -m "feat: add original Coloring Studio pilot art"`.

### Task 4: Define project edits and durable independent records

**Files:**
- Create: `lib/features/coloring/domain/coloring_edit.dart`
- Create: `lib/features/coloring/domain/coloring_project.dart`
- Create: `lib/features/coloring/domain/coloring_project_repository.dart`
- Create: `lib/data/db/hive_coloring_project_repository.dart`
- Create: `test/support/in_memory_coloring_project_repository.dart`
- Create: `test/features/coloring/domain/coloring_project_test.dart`
- Create: `test/data/db/hive_coloring_project_repository_test.dart`
- Modify: `lib/data/schema/schema_registry.dart`
- Modify: `docs/release/schema-registry.md`
- Modify: `lib/data/storage/local_data_manager.dart`
- Modify: `test/data/storage/local_data_manager_test.dart`

**Interfaces:**

```dart
final class ColoringProject {
  final String id;
  final String drawingId;
  final int drawingRevision;
  final ColoringMode mode;
  final Map<String, RgbColor> assignments;
  final Set<String> guidedFilledRegionIds;
  final List<ColoringEdit> undoStack;
  final List<ColoringEdit> redoStack;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;
}

abstract interface class ColoringProjectRepository {
  Future<RepositorySnapshot<ColoringProject>> loadSnapshot();
  Future<ColoringProject?> read(String projectId);
  Future<ColoringProject> save(ColoringProject project);
  Future<void> delete(String projectId);
  Future<void> close();
}
```

Register `coloring_projects_v1` under shared-library ownership. Each record is independently decoded; accepted writes use temp→flush→replace with last-valid backup. Edit history is capped at 50 committed edits.

Register `LocalDataCategory.coloringProjects` preview/delete for editable records and disposable thumbnails; externally exported PNGs are never included implicitly.

- [ ] **Step 1: Write RED project/repository tests.** Cover Guided/Free ID separation, strict revisions, 50-edit trimming, undo/redo serialization, reopen, atomic failure, backup recovery, one corrupt project beside healthy records, and unknown drawing revision.
- [ ] **Step 2: Run domain/Hive tests.** Expected: FAIL.
- [ ] **Step 3: Implement types, file-safe repository behavior, thumbnail invalidation metadata, and in-memory fake.** Never reset a corrupt library automatically.
- [ ] **Step 4: Re-run tests and verify deleting a game profile or source palette leaves raw project records byte-for-byte unchanged.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: persist independent coloring projects"`.

### Task 5: Build the save-aware editing controller

**Files:**
- Create: `lib/features/coloring/application/coloring_project_providers.dart`
- Create: `lib/features/coloring/application/coloring_session_controller.dart`
- Create: `test/features/coloring/application/coloring_session_controller_test.dart`

**Interfaces:**

```dart
enum ProjectSaveStatus { saved, saving, failed }

final class ColoringSession {
  final ColoringProject durable;
  final ColoringProject visible;
  final ProjectSaveStatus saveStatus;
  final Object? saveError;
}

Future<void> fillRegion(String regionId, RgbColor color);
Future<void> undo();
Future<void> redo();
Future<void> retrySave();
Future<void> finish();
```

- [ ] **Step 1: Write RED controller tests.** Cover serialized rapid fills, stale completion, undo/redo branching, process-lifecycle flush, save failure with visible draft, retry, dispose during write, and illegal drawing/mode mutation.
- [ ] **Step 2: Run `flutter test --no-pub test/features/coloring/application/coloring_session_controller_test.dart --reporter expanded`.** Expected: FAIL.
- [ ] **Step 3: Implement the controller with separate visible/durable state and monotonic revision tokens.** Only acknowledged saves update `durable`; later stale futures cannot replace newer state.
- [ ] **Step 4: Re-run application plus repository suites.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: add reliable coloring edit sessions"`.

### Task 6: Implement Guided Color behavior and UI

**Files:**
- Create: `lib/features/coloring/presentation/coloring_workspace_screen.dart`
- Create: `lib/features/coloring/presentation/color_source_sheet.dart`
- Create: `lib/features/coloring/presentation/coloring_region_list.dart`
- Create: `test/features/coloring/presentation/guided_coloring_test.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Progress is `filled required regions / total required regions`.
- A Guided fill commits only when `selectedSlotId == definition.regionRules[region.id]!.targetSlotId` and uses the slot's exact authored `RgbColor`.
- `findNextRegion()` chooses a deterministic unfilled required region, focuses/highlights it, and changes neither assignments nor rewards.

- [ ] **Step 1: Write RED Guided tests.** Assert exact accepted color, wrong tap no-op plus gentle text/icon feedback, auto-next, free deterministic Find Region, no scoring/lives/timer/coins, resume, and mode-safe project identity.
- [ ] **Step 2: Run the focused Guided test.** Expected: FAIL.
- [ ] **Step 3: Build the adaptive workspace, numbered/labeled swatches, progress, undo/redo, Find Region, save failure/retry, and completion affordance.** Keep controls outside export boundaries.
- [ ] **Step 4: Run pointer, keyboard, semantics, compact landscape, 200% text, reduced-motion, and RTL variants.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: add calm Guided Color mode"`.

### Task 7: Implement Free Color and source-value copying

**Files:**
- Modify: `lib/features/coloring/presentation/color_source_sheet.dart`
- Modify: `lib/features/coloring/presentation/coloring_workspace_screen.dart`
- Create: `test/features/coloring/presentation/free_coloring_test.dart`
- Create: `test/features/coloring/color_source_copy_integration_test.dart`
- Modify: `lib/features/history/application/history_providers.dart`
- Modify: `lib/features/palette/application/saved_palettes_providers.dart`

**Interfaces:**
- Color sources expose read-only `RgbColor` values from suggested, My Colors, My Palettes, and validated custom `#RRGGBB`; project records save only copied HEX assignments.

- [ ] **Step 1: Write RED Free tests.** Cover region-first selection, each source type, invalid HEX, undo/redo, deletion of source records after assignment, duplicate-as-new-project, and Guided/Free isolation.
- [ ] **Step 2: Run Free and source-copy tests.** Expected: FAIL.
- [ ] **Step 3: Implement value-copy selection and Free controls.** Never store a durable palette/color source ID or mutate source objects.
- [ ] **Step 4: Rerun Free, history, palette, controller, and repository tests.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: add Free Color palette workflow"`.

### Task 8: Build catalog, routes, completion, My Artwork, export, and share

**Files:**
- Create: `lib/features/coloring/presentation/coloring_catalog_screen.dart`
- Create: `lib/features/coloring/presentation/coloring_mode_sheet.dart`
- Create: `lib/features/coloring/presentation/coloring_completion_screen.dart`
- Create: `lib/features/coloring/presentation/my_artwork_section.dart`
- Create: `lib/features/coloring/application/coloring_export_service.dart`
- Create: `test/features/coloring/presentation/coloring_catalog_screen_test.dart`
- Create: `test/features/coloring/presentation/coloring_completion_screen_test.dart`
- Create: `test/features/coloring/application/coloring_export_service_test.dart`
- Modify: `lib/routing/app_router.dart`
- Modify: `lib/features/my_work/presentation/my_work_screen.dart`
- Modify: `lib/features/games/presentation/games_screen.dart`

**Interfaces:**
- Canonical paths: `/coloring`, `/coloring/project/:projectId`, `/coloring/complete/:projectId`.
- `MyArtworkSection` exposes resume, duplicate, export, share, and confirmed delete.
- Export uses intrinsic artwork coordinates, contains no UI, strips metadata, writes only after an explicit user action, and distinguishes exported PNG from editable local project.

- [ ] **Step 1: Write RED route/catalog/export tests.** Cover Continue Coloring ordering, category/difficulty/mode filters, invalid IDs, Back restoration, project vs export language, clean pixels, no controls/EXIF/location, share cancellation, and deletion confirmation.
- [ ] **Step 2: Run focused route/presentation/export tests.** Expected: FAIL.
- [ ] **Step 3: Implement catalog, mode choice, completion, My Artwork, clean PNG export/share, and a prominent Games-hub creative card without adding a `GameId`.**
- [ ] **Step 4: Inspect generated PNGs at native and scaled output sizes and test offline/denied-share/no-space failures.** Expected: PASS with recoverable project state.
- [ ] **Step 5: Commit.** `git commit -m "feat: add Coloring Studio catalog and artwork library"`.

### Task 9: Add the remaining ten drawings and freeze the launch pack

**Files:**
- Create: `assets/coloring/fruit_orange_slice.json`
- Create: `assets/coloring/fruit_berry_bowl.json`
- Create: `assets/coloring/animal_butterfly.json`
- Create: `assets/coloring/animal_tropical_fish.json`
- Create: `assets/coloring/animal_parrot.json`
- Create: `assets/coloring/nature_leafy_tree.json`
- Create: `assets/coloring/nature_sunflower.json`
- Create: `assets/coloring/nature_mountain_grove.json`
- Create: `assets/coloring/room_calm_bedroom.json`
- Create: `assets/coloring/room_reading_corner.json`
- Modify: `assets/coloring/manifest.json`
- Modify: `assets/licenses/coloring-artwork-NOTICE.txt`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/features/coloring/data/drawing_catalog_loader_test.dart`

**Interfaces:**
- Final manifest contains the two pilots plus these ten assets, exactly three per category, with immutable ID/revision/hash metadata.

- [ ] **Step 1: Extend the RED catalogue test to require all 12 exact IDs and balanced categories, with difficulty/progress metadata and complete localization/source notes.**
- [ ] **Step 2: Produce the ten original JSON drawings, updating evidence per asset; do not trace or adapt a competitor page.**
- [ ] **Step 3: Run the catalog validator and render every drawing in empty, partial, completed Guided, and arbitrary Free states.** Expected: PASS without invalid paths, missing regions, or seams that make a required region unreachable.
- [ ] **Step 4: Perform a human visual/interaction review at compact and tablet sizes and record every accepted asset hash in the ledger.**
- [ ] **Step 5: Commit.** `git commit -m "feat: complete original Coloring Studio pack"`.

### Task 10: Add accessible region flow and Learning/Room bridges

**Files:**
- Modify: `lib/features/coloring/presentation/coloring_region_list.dart`
- Modify: `lib/features/learning/application/experiment_restore_service.dart`
- Modify: `lib/features/room_studio/application/illustrated_room_controller.dart`
- Create: `test/features/coloring/coloring_accessibility_integration_test.dart`
- Create: `test/features/coloring/coloring_bridge_integration_test.dart`

**Interfaces:**
- Region list exposes label, required/filled state, target swatch label in Guided, current HEX/name in Free, select/focus, apply, undo, Find Remaining, Finish, and Export.
- Cross-feature payload is an immutable copied `List<RgbColor>` with an explicit target route; no Coloring project ID is embedded in a Room design and vice versa.

- [ ] **Step 1: Write RED end-to-end tests for a no-canvas-gesture completion path and both value-copy bridges.** Include source deletion and navigation back to the unchanged originating lesson/project.
- [ ] **Step 2: Run accessibility and bridge tests.** Expected: FAIL.
- [ ] **Step 3: Implement semantic list actions, focus synchronization, announcements, and explicit palette assignment in Illustrated Rooms.** Never make canvas semantics the only usable control.
- [ ] **Step 4: Run keyboard/screen-reader semantics, 200% text, RTL, and project-isolation tests.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: make coloring accessible and connected"`.

### Task 11: Close Coloring Studio verification

**Files:**
- Modify: `docs/release/verification-ledger.md`
- Future consumer, no edit in this plan: `docs/release/content-rights-register.md` (Quality Task 5 imports the accepted asset hashes and notice evidence)

**Interfaces:**
- Produces the final COLOR-01–12 coverage record, 12 accepted hashes, art-rights evidence, failure/restart evidence, responsive/accessibility matrix, and export samples.
- A reproduced defect or review finding reopens its exact owning Task 1–10 file list; Task 11 itself does not authorize an unlisted product/test edit.

- [ ] **Step 1: Run `dart run tool/validate_coloring_catalog.dart` and `flutter test --no-pub test/core/vector_regions test/features/coloring test/data/db/hive_coloring_project_repository_test.dart --reporter expanded`.** Expected: PASS.
- [ ] **Step 2: Run localization generation, format, scoped analyze, then the full repository test suite.** No unexplained failure remains.
- [ ] **Step 3: Test process death after acknowledged and failed writes, low-storage export, orientation/live resize, multitouch, and fresh offline install on the required device classes.** Record artifacts/results.
- [ ] **Step 4: Obtain a fresh read-only review against COLOR-01–12 and the rights register, resolve findings, and commit.** `git commit -m "test: verify TintAtlas Coloring Studio"`.

## Exit Gate

All 12 validated original drawings work entirely offline; display, hit, accessibility, thumbnail, and export geometry agree; every acknowledged edit survives restart; failed saves retain a retryable visible draft; Guided and Free never overwrite one another; source deletion cannot change copied colors; keyboard/screen-reader users can complete and export; the workspace is ad-free. COLOR-13/14 remain post-launch and COLOR-15 remains deferred pending a new approved design.
