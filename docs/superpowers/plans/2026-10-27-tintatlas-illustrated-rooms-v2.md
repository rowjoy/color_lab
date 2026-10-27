# TintAtlas Illustrated Rooms v2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the six illustrated templates into a predictable, brand-neutral surface editor with stable region identities, copied palettes, safe comparison, durable drafts/designs, and clean export.

**Architecture:** Introduce a shared restricted vector-region contract whose JSON-authored fill path is the sole geometry used for render, hit testing, accessibility bounds, thumbnails, and export. Existing SVGs become decoration-only overlays after their fill regions are migrated. Retain legacy four-group colors as the migration baseline, layer explicit region overrides above them, and store snapshot values rather than catalogue/source IDs so saved work cannot drift.

**Tech Stack:** Flutter CustomPainter and `Path`, `flutter_svg` for legacy/decorative art, Riverpod, Hive, restricted versioned JSON assets, PNG export, unit/widget/golden tests.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md`

## Global Constraints

- Read the master/Foundation plans first; shared localization, storage snapshots, adaptive layout, and My Work contracts apply.
- Do not include Asian Paints or any other manufacturer's shade names, codes, images, recommendations, article wording, provenance claims, or lookalike catalogue structure.
- The six template IDs and existing v1 saved-design appearances remain compatible: `living`, `bedroom`, `study`, `dining`, `kitchen`, `bathroom`.
- Shared vector JSON accepts only versioned `M`, `L`, `Q`, `C`, and `Z` commands with finite in-bounds coordinates; no arbitrary SVG/HTML/script parser is added.
- Render, reverse-paint-order hit testing, semantics bounds, thumbnails, and export consume the same region geometry and transform.
- Applying a look is explicit and undoable; a single-surface edit changes only the active region; catalogue/palette changes never rewrite saved snapshots.
- Lighting modes and finish simulations (ILL-14/15) are post-launch and must not be approximated by global brightness changes.

## Review Focus

- Migrating a v1 design preserves its exact four visible colors even if starter palette IDs/names later change or disappear.
- Taps on holes, decorative strokes, region boundaries, and overlapping regions select only the topmost fillable authored region.
- Resizing, RTL, keyboard insets, 200% text, and pan/zoom do not change region identity or make Save/Undo/Redo unreachable.
- A failed/corrupt design or recoverable draft remains isolated while healthy designs and the last acknowledged revision stay available.
- A deleted source saved palette does not alter an open/saved design because only copied HEX values cross the boundary.

---

### Task 1: Remove manufacturer references and freeze original starter palettes

**Files:**
- Create: `assets/rooms/palettes/starter_palettes.v1.json`
- Create: `assets/licenses/illustrated-room-palettes-NOTICE.txt`
- Create: `lib/features/room_studio/data/illustrated_room_palette_catalog.dart`
- Modify: `lib/features/room_studio/domain/illustrated_room.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_market_guide.dart`
- Modify: `pubspec.yaml`
- Test: `test/features/room_studio/data/illustrated_room_palette_catalog_test.dart`
- Test: `test/tool/brand_neutral_assets_test.dart`

**Interfaces:**
- Produces read-only palette records `{schemaVersion, catalogueRevision, id, nameKey, descriptionKey, colors}` with four canonical uppercase HEX values; all templates reference snapshot-capable palettes through `IllustratedRoomPaletteCatalog`.
- Version 1 contains exactly `soft-linen`, `quiet-sage`, `airy-slate`, `clay-and-cream`, `mist-and-ink`, and `sunwashed-olive`; the approved notice records original authorship and standard color values, not external recommendations.

| Palette ID | Ordered v1 HEX snapshot |
|---|---|
| `soft-linen` | `#F2E9DA`, `#D8C7AC`, `#A89073`, `#5C554D` |
| `quiet-sage` | `#ECE9DF`, `#B7C2A3`, `#78866B`, `#4E5B4A` |
| `airy-slate` | `#F2F4F3`, `#C9D3D8`, `#8396A5`, `#3F5362` |
| `clay-and-cream` | `#F5EBDD`, `#D79A7A`, `#9B6553`, `#5E4A42` |
| `mist-and-ink` | `#ECEFF1`, `#B8C4CE`, `#667989`, `#263746` |
| `sunwashed-olive` | `#F3E7C7`, `#D8B96A`, `#8B8F58`, `#4F5A3F` |

The ordered values map to the catalogue's declared wall/ceiling/floor/furniture roles; later region assignments copy a value, never retain a live palette link.

- [ ] **Step 1: Write RED catalogue tests.** Require unique lowercase IDs, six palettes, four valid HEX values each, generated localization keys, immutable order, and read-only copy semantics.
- [ ] **Step 2: Write a RED repository asset/copy scan.** Fail on the current manufacturer-derived strings and known shade/code phrases in source, tests, bundled assets, UI copy, and metadata; exclude Git history and the design spec's prohibition sentence from the scan input.
- [ ] **Step 3: Run `flutter test --no-pub test/features/room_studio/data/illustrated_room_palette_catalog_test.dart test/tool/brand_neutral_assets_test.dart --reporter expanded`.** Expected: FAIL on current `illustrated_room.dart` source/provenance copy.
- [ ] **Step 4: Implement the original catalogue and generic preview guidance.** Use plain descriptive names, the six fixed original color arrays, and the common non-calibrated preview limitation; remove `paletteReviewLabel`, `paletteSourceNote`, and `provenance` where they imply external market guidance.
- [ ] **Step 5: Run the scan plus all current Illustrated Room domain/UI tests.** Expected: PASS after updating intentional copy expectations without changing existing saved-design colors.
- [ ] **Step 6: Commit.** `git commit -m "fix: replace room palettes with original neutral content"`.

### Task 2: Shared vector-region contract and Study Room pilot

**Files:**
- Create: `lib/core/vector_regions/domain/vector_region_geometry.dart`
- Create: `lib/core/vector_regions/data/vector_region_json_codec.dart`
- Create: `lib/core/vector_regions/application/vector_region_transform.dart`
- Create: `lib/core/vector_regions/application/vector_region_hit_tester.dart`
- Create: `lib/core/vector_regions/rendering/vector_region_renderer.dart`
- Create: `assets/rooms/regions/study_room.v1.json`
- Modify: `assets/rooms/study_room.svg`
- Modify: `lib/features/room_studio/domain/illustrated_room.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_svg.dart`
- Create: `lib/features/room_studio/presentation/illustrated_room_region_artwork.dart`
- Modify: `lib/features/room_studio/rendering/illustrated_room_color_mapper.dart`
- Modify: `lib/features/room_studio/application/illustrated_room_artwork_encoder.dart`
- Test: `test/core/vector_regions/vector_region_json_codec_test.dart`
- Test: `test/core/vector_regions/vector_region_transform_test.dart`
- Test: `test/core/vector_regions/vector_region_hit_tester_test.dart`
- Test: `test/core/vector_regions/vector_region_renderer_test.dart`
- Test: `test/features/room_studio/presentation/study_room_region_pilot_test.dart`

**Interfaces:**
- Produces `VectorRegionGeometry.toPath()`, `VectorRegionDefinition(id, labelKey, groupId, fillable, paintOrder, geometry)`, `VectorArtworkDefinition(id, revision, intrinsicSize, regions)`, strict `VectorRegionJsonCodec.decode()`, `VectorRegionTransform.fit(...)`, `VectorRegionRenderer.draw(...)`, and `hitTestVectorRegion(...)` using reverse paint order.
- Study pilot region IDs are `wall-back`, `wall-side`, `wall-accent`, `ceiling`, `floor`, `desk`, `chair`, and `shelves`; group IDs are `walls`, `ceiling`, `floor`, and `furniture`.
- The JSON definition owns every fill boundary. `study_room.svg` owns decoration/strokes only and may not repeat a fillable region path or contain the four legacy replacement-token colors after migration.

- [ ] **Step 1: Write RED JSON/path tests.** Accept only schema 1 and M/L/Q/C/Z, require a starting M and closed fillable paths, finite coordinates inside 1200×800, stable unique IDs, valid group IDs/localization keys, unique paint order, and geometry bounds matching the built Path.
- [ ] **Step 2: Write RED transform/hit tests.** Cover contain letterboxing, pan/zoom, resize, boundary epsilon, holes, overlap, reverse paint order, and screen→artwork→screen tolerance within 0.5 logical px.
- [ ] **Step 3: Write a RED Study single-source/parity test.** The decoration SVG contains no fillable region IDs, token colors, or duplicate fill paths; widget, hit tester, semantics bounds, thumbnail, and export receive the same built `Path` objects from the JSON definition; decorative elements are never fillable/hittable.
- [ ] **Step 4: Run the five focused suites.** Expected: FAIL because the shared region contract and pilot metadata do not exist.
- [ ] **Step 5: Implement the restricted codec/geometry/transform/hit tester/renderer and author the Study pilot.** Extract each Study fill boundary once into JSON, remove the corresponding token-filled SVG geometry, and composite the decoration-only SVG over `VectorRegionRenderer`; keep `IllustratedRoomColorMapper` only for the five not-yet-migrated legacy templates.
- [ ] **Step 6: Run focused suites and visually inspect compact/tablet Study previews plus a 2400×1600 exported PNG.** Expected: PASS with exact selected region identity.
- [ ] **Step 7: Commit.** `git commit -m "feat: pilot shared regions in illustrated rooms"`.

### Task 3: Region assignments and exact edit history

**Files:**
- Create: `lib/features/room_studio/domain/illustrated_room_assignments.dart`
- Create: `lib/features/room_studio/domain/illustrated_room_edit.dart`
- Create: `lib/features/room_studio/domain/illustrated_room_history.dart`
- Modify: `lib/features/room_studio/domain/illustrated_room_draft.dart`
- Modify: `lib/features/room_studio/domain/illustrated_room_session.dart`
- Modify: `lib/features/room_studio/application/illustrated_room_controller.dart`
- Test: `test/features/room_studio/domain/illustrated_room_assignments_test.dart`
- Test: `test/features/room_studio/domain/illustrated_room_history_test.dart`
- Modify test: `test/features/room_studio/application/illustrated_room_controller_test.dart`

**Interfaces:**
- Produces `IllustratedRoomAssignments(groupColors, regionOverrides)`; `colorFor(region)` resolves override then group; `setRegionColor()` changes one override; `setGroupColor()` changes exactly declared members without deleting unrelated overrides.
- Produces bounded 50-command `IllustratedRoomHistory` with exact before/after assignments and `undo()/redo()`; actions are `applyCompleteLook`, `setRegionColor`, `setGroupColor`, `pinBaseline`, and `restoreSnapshot`.

- [ ] **Step 1: Write RED assignment tests.** The first custom edit from grayscale seeds groups once and overrides only the selected region; `All Walls` changes exactly three Study wall members; furniture group changes desk/chair/shelves only; invalid/missing region/group IDs are rejected.
- [ ] **Step 2: Write RED history/controller tests.** Complete Look is one undoable command; one-surface edit is one command; Undo/Redo round-trips exact maps; a new edit clears redo; comparison/temporary B&W creates no destructive assignment mutation.
- [ ] **Step 3: Run focused domain/controller tests.** Expected: FAIL.
- [ ] **Step 4: Implement immutable assignments, 50-command history, and controller methods.** Keep v1 group colors as a compatibility adapter until persistence migration completes.
- [ ] **Step 5: Run focused tests plus existing draft/session regressions.** Expected: PASS.
- [ ] **Step 6: Commit.** `git commit -m "feat: make illustrated surface edits predictable"`.

### Task 4: Saved-design schema v2 and recoverable drafts

**Files:**
- Modify: `lib/features/room_studio/domain/saved_room_design.dart`
- Modify: `lib/features/room_studio/domain/room_design_repository.dart`
- Modify: `lib/data/db/hive_room_design_repository.dart`
- Modify: `lib/features/room_studio/application/room_designs_providers.dart`
- Modify: `lib/data/schema/schema_registry.dart`
- Modify: `docs/release/schema-registry.md`
- Create: `lib/features/room_studio/application/illustrated_room_draft_store.dart`
- Test: `test/features/room_studio/domain/saved_room_design_test.dart`
- Test: `test/data/db/hive_room_design_repository_test.dart`
- Test: `test/features/room_studio/application/illustrated_room_draft_store_test.dart`

**Interfaces:**
- Saved schema `2` stores template ID/revision, group color HEX snapshots, region override HEX snapshots, active baseline snapshot, and created/updated UTC; schema `1` maps its wall/ceiling/floor/furniture values to groups with no overrides.
- The `illustrated_room_designs_v1` Hive storage name stays fixed while its registry current version advances to 2.
- Repository/controller actions are `saveNew`, `update(existingId)`, `saveCopy`, `rename`, and `delete`; `IllustratedRoomDraftStore` retains one recoverable local draft per template with visible `saved/saving/failed` status and Retry.

- [ ] **Step 1: Write RED v1→v2 migration fixtures for all six template IDs.** Assert exact pre/post effective four-color output, original IDs/names/timestamps, no inferred starter palette link, and durable rewrite only after successful flush.
- [ ] **Step 2: Add RED repository/draft failure tests.** One corrupt design is quarantined while healthy designs load; failed update retains previous durable design and visible draft; Save a Copy creates an independent ID; deleted/renamed defaults do not alter snapshots.
- [ ] **Step 3: Run saved-design, Hive, provider, and draft-store suites.** Expected: FAIL.
- [ ] **Step 4: Implement schema-2 codec/repository/controller integration using Foundation `RepositorySnapshot`.** Never auto-reset or overwrite corrupt records.
- [ ] **Step 5: Run focused tests twice with repository close/reopen and one injected flush failure.** Expected: PASS.
- [ ] **Step 6: Commit.** `git commit -m "feat: migrate illustrated designs to durable regions"`.

### Task 5: Clear editor flow and copied My Palettes values

**Files:**
- Create: `lib/features/room_studio/presentation/illustrated_room_surface_picker.dart`
- Create: `lib/features/room_studio/presentation/illustrated_room_palette_sheet.dart`
- Create: `lib/features/room_studio/presentation/illustrated_room_history_controls.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_screen.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_controls.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_flyout.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_navigation.dart`
- Test: `test/features/room_studio/presentation/illustrated_room_surface_picker_test.dart`
- Test: `test/features/room_studio/presentation/illustrated_room_palette_sheet_test.dart`
- Modify test: `test/features/room_studio/presentation/illustrated_room_integration_test.dart`

**Interfaces:**
- Consumes: Foundation saved-palette snapshots and Task 3 controller; only `List<RgbColor>`/selected `RgbColor` crosses from My Palettes.
- Produces the localized sequence Choose a Look → Change a Surface → Save, with explicit `Apply Complete Look`, active-region label/outline, Undo/Redo, Save/Update/Save a Copy, and My Designs.

- [ ] **Step 1: Write RED interaction tests.** Choosing a look previews then applies only after explicit confirmation; tapping/list-selecting one region changes only it; selecting My Palettes copies a chosen swatch; deleting/editing the source palette later changes nothing.
- [ ] **Step 2: Write RED semantics/responsive tests.** Every region exposes localized name, group, HEX, selected state, and button alternative; flow is complete without canvas taps at all required widths, short landscape, RTL, keyboard inset, 200% text, dark/high contrast.
- [ ] **Step 3: Run focused picker/palette/integration tests.** Expected: FAIL.
- [ ] **Step 4: Implement progressive controls and explicit actions; hide implementation terms such as token, SVG, mapper, and group ID.**
- [ ] **Step 5: Run focused and existing navigation/polish tests.** Expected: PASS.
- [ ] **Step 6: Commit.** `git commit -m "feat: simplify illustrated room editing"`.

### Task 6: Non-destructive compare and clean export

**Files:**
- Create: `lib/features/room_studio/domain/illustrated_room_comparison.dart`
- Create: `lib/features/room_studio/presentation/illustrated_room_compare_controls.dart`
- Modify: `lib/features/room_studio/application/illustrated_room_artwork_encoder.dart`
- Modify: `lib/features/room_studio/application/illustrated_room_export_controller.dart`
- Modify: `lib/features/room_studio/application/room_gallery_writer.dart`
- Test: `test/features/room_studio/domain/illustrated_room_comparison_test.dart`
- Test: `test/features/room_studio/presentation/illustrated_room_compare_controls_test.dart`
- Modify test: `test/features/room_studio/application/illustrated_room_artwork_encoder_test.dart`
- Modify test: `test/features/room_studio/application/illustrated_room_export_controller_test.dart`

**Interfaces:**
- Produces `pinBaseline()`, `setComparisonVariant()`, `showTemporaryOriginal()`, `showTemporaryGrayscale()`, and `clearComparison()` without changing assignments/history.
- Export produces clean room PNG and optional separate labeled palette-card PNG with region/group names, uppercase HEX snapshots, TintAtlas identity, and the preview limitation.

- [ ] **Step 1: Write RED comparison tests.** A/B, original, and B&W views never alter dirty state/history/baseline; dismiss restores the exact visible draft; deleting a compared saved design preserves the pinned in-memory snapshot until close.
- [ ] **Step 2: Write RED render/export parity and metadata tests.** Region colors at representative interior pixels equal assignment resolution; output dimensions are declared; PNG excludes editor controls and source metadata; palette card labels do not overflow at 200% text/RTL.
- [ ] **Step 3: Run focused comparison/encoder/export tests.** Expected: FAIL.
- [ ] **Step 4: Implement snapshot comparison and shared render pipeline.** Reuse Task 2 region IDs/geometry and change filenames/subjects to TintAtlas.
- [ ] **Step 5: Inspect Study widget, thumbnail, A/B, room PNG, and palette card side-by-side.** Expected: identical assignments and clean output.
- [ ] **Step 6: Commit.** `git commit -m "feat: add safe illustrated room comparison"`.

### Task 7: Migrate the remaining five templates

**Files:**
- Create: `assets/rooms/regions/living_room.v1.json`
- Create: `assets/rooms/regions/bedroom_room.v1.json`
- Create: `assets/rooms/regions/dining_room.v1.json`
- Create: `assets/rooms/regions/kitchen_room.v1.json`
- Create: `assets/rooms/regions/bathroom_room.v1.json`
- Modify: `assets/rooms/living_room.svg`
- Modify: `assets/rooms/bedroom_room.svg`
- Modify: `assets/rooms/dining_room.svg`
- Modify: `assets/rooms/kitchen_room.svg`
- Modify: `assets/rooms/bathroom_room.svg`
- Modify: `lib/features/room_studio/domain/illustrated_room.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_region_artwork.dart`
- Modify: `lib/features/room_studio/application/illustrated_room_artwork_encoder.dart`
- Delete after all six templates migrate: `lib/features/room_studio/rendering/illustrated_room_color_mapper.dart`
- Test: `test/features/room_studio/data/illustrated_room_region_catalog_test.dart`
- Modify test: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: the frozen Study/shared region contract; each template declares its own stable region IDs, localized labels, group membership, paint order, and revision without changing the six template IDs.
- Produces six fully region-aware templates and a catalogue validator that loads every SVG/JSON pair.

- [ ] **Step 1: Author RED catalogue assertions before each asset migration.** Require JSON-only fill geometry, decoration SVGs with no fill tokens/region paths, at least separate back/side/accent walls where artwork contains them, individual major furniture, nonempty All Walls/furniture groups, valid bounds, and a semantics label per fillable region.
- [ ] **Step 2: Migrate one template per commit-sized substep in this order: living, bedroom, dining, kitchen, bathroom.** For each, run catalogue, render, hit, migration, and export parity tests before continuing.
- [ ] **Step 3: Run all six templates at compact/tablet sizes with representative boundary/overlap taps and generated golden/PNG inspection.** Expected: the same region ID receives the same snapshot color in screen/thumbnail/export.
- [ ] **Step 4: Run schema-1 saved-design fixtures for all six after the final asset revision, remove the legacy color mapper, and scan production code/assets for replacement-token colors.** Expected: unchanged legacy appearance with zero data loss and one fill-geometry source.
- [ ] **Step 5: Commit.** `git commit -m "feat: add regions to every illustrated room"`.

### Task 8: Illustrated Rooms v2 milestone verification

**Files:**
- Modify: `docs/release/verification-ledger.md`
- Test: `test/features/room_studio/illustrated_room_v2_integration_test.dart`

**Interfaces:**
- Freezes the shared vector-region API consumed by Coloring Studio and records all six artwork/catalogue revisions.

- [ ] **Step 1: Add an end-to-end test.** Open each room offline, apply a complete look, edit one region, group-edit walls, Undo/Redo, copy a saved swatch, autosave/restart, Save a Copy/rename/delete, compare, export, and reopen a migrated v1 design.
- [ ] **Step 2: Run `flutter test --no-pub test/core/vector_regions test/features/room_studio test/data/db/hive_room_design_repository_test.dart test/tool/brand_neutral_assets_test.dart --reporter expanded`.** Expected: PASS.
- [ ] **Step 3: Run format, analyze, full tests, Android debug build, and active iOS build gate.** Expected: clean under the Foundation baseline policy.
- [ ] **Step 4: Record catalogue checksums, asset rights/notice, migration fixtures, responsive/accessibility evidence, and inspected exports; obtain fresh review.**
- [ ] **Step 5: Commit.** `git commit -m "test: verify illustrated rooms v2"`.

## Exit Gate

All six rooms use stable accessible regions; single/group/look edits, Undo/Redo, copied palettes, recoverable drafts, v1→v2 migration, My Designs, comparison, and clean exports pass. Brand scans find no manufacturer material, and the shared vector-region contract is frozen for Coloring Studio. ILL-14 lighting and ILL-15 finishes remain explicitly deferred.
