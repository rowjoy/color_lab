# Trending Living-Room Palettes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add five generic, page-inspired living-room presets after the existing three, with no paint-brand shade names or codes anywhere in catalog metadata.

**Architecture:** Extend the existing `IllustratedRoomCatalog.living` data so the current Room Studio UI receives the five additional palettes without new persistence or dependencies. Keep the four-surface palette contract by pairing each sampled wall/accent colour with the living room's existing neutral ceiling and floor, and make shared provenance generic.

**Tech Stack:** Dart, Flutter, Riverpod-derived Room Studio UI, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-26-asian-paints-living-room-palettes-design.md`

## Global Constraints

- Preserve the existing living-room IDs and order: `warm-natural`, `soft-botanical`, `cool-airy`.
- Keep `warm-natural` as the living-room `defaultPaletteId`; fresh editors must remain grayscale.
- Append exactly five generic presets in the PDF order defined by the spec.
- Do not display or store the paint brand, proprietary shade names, or manufacturer shade codes in catalog names, guidance, provenance, or UI.
- Remove the existing `Milkshake`, `White Clay`, `Timber Glaze`, and `Gossamer` shade-family references from shared provenance without changing existing palette colours.
- Do not modify the palette colours for bedroom, study, dining, kitchen, or bathroom, and do not migrate or overwrite saved Hive designs.
- Add no dependencies and no database seeding or migration.
- The workspace grants read-only access to `.git`; replace commit steps with reviewed `git diff` checkpoints and leave committing to the user.

## Review Focus

- Living preset order or the recommended default drifts: Task 1 pins the full ordered ID list and `warm-natural` default.
- A shared catalog edit changes another room's colours: Task 1 retains the exact six-room colour matrix assertions.
- Brand, proprietary shade, or code text leaks into metadata: Task 1 scans every palette's name, guidance, and provenance for disallowed terms and paint-code patterns.
- Repeated neutral ceiling/floor colours hide the five distinct combinations: Task 2 verifies eight living look cards and eight unique wall suggestions remain available.
- The longer list makes its final item unreachable or selects the wrong data: Task 2 scrolls to and applies `peach-coral-glow`, then checks all four resulting colours and selected state.

---

### Task 1: Extend and sanitize the room palette catalog

**Files:**
- Modify: `test/features/room_studio/domain/illustrated_room_test.dart:65-190`
- Modify: `lib/features/room_studio/domain/illustrated_room.dart:247-455`

**Interfaces:**
- Consumes: Existing `IllustratedRoomCatalog`, `_room(...)`, `_lookName(String)`, `_lookGuidance(String)`, and `_lookProvenance(String)`.
- Produces: `IllustratedRoomCatalog.living.palettes` with eight ordered `IllustratedRoomPalette` values; existing public types and method signatures remain unchanged.

- [ ] **Step 1: Write failing catalog tests**

  Update the living entry in `expectedLooks` with these appended values, each ordered as wall, ceiling, floor, furniture:

  ```dart
  'soft-pink-earthy-neutrals': [
    '#E5C8BE', '#F8F4EB', '#C5AD8A', '#E1CCB7',
  ],
  'coral-peach-layers': [
    '#E49473', '#F8F4EB', '#C5AD8A', '#F1BAA2',
  ],
  'white-gentle-grey': [
    '#C8C8C6', '#F8F4EB', '#C5AD8A', '#E8E6E2',
  ],
  'pink-lavender-pairing': [
    '#DFCAC9', '#F8F4EB', '#C5AD8A', '#D4C9CF',
  ],
  'peach-coral-glow': [
    '#F1B89B', '#F8F4EB', '#C5AD8A', '#EDA28E',
  ],
  ```

  Derive each room's expected palette IDs from its ordered `expectedLooks` keys excluding `default`, so the same assertion pins three palettes for other rooms and eight for living. Add a dedicated test that pins the five display names from the spec and scans every catalog palette's `name`, `guidance`, and `provenance` for:

  - the disallowed terms `asian paints`, `milkshake`, `white clay`, `timber glaze`, `gossamer`, plus all ten source shade names;
  - the paint-code pattern `RegExp(r'\b(?:\d{4}|[0o]p\d{2})\b', caseSensitive: false)`.

- [ ] **Step 2: Run the domain test and confirm the intended failure**

  Run: `flutter test test/features/room_studio/domain/illustrated_room_test.dart`

  Expected: FAIL because the five IDs are missing and existing provenance still contains proprietary shade-family names/codes.

- [ ] **Step 3: Append the five catalog values**

  In `IllustratedRoomCatalog.living.values`, append the five IDs and exact four-colour lists from Step 1. Do not change the first three entries or `defaultPaletteId`.

- [ ] **Step 4: Add generic metadata for all five IDs**

  Extend the three existing metadata switches with these display names and guidance strings:

  - `soft-pink-earthy-neutrals` → `Soft Pink with Earthy Neutrals`; `Soft pink and warm neutrals create a calm, welcoming living room.`
  - `coral-peach-layers` → `Coral and Peach Layers`; `Coral and peach layers bring cheerful warmth to the room.`
  - `white-gentle-grey` → `White with Gentle Grey`; `Soft white and gentle grey keep the room bright and open.`
  - `pink-lavender-pairing` → `Pink and Lavender Pairing`; `Pink and lavender create a soft, relaxed living room.`
  - `peach-coral-glow` → `Peach and Coral Glow`; `Peach and coral add a lively, welcoming glow in natural light.`

  Return `Approximate display colors sampled from the supplied living-room inspiration page.` as provenance for each new ID.

- [ ] **Step 5: Sanitize existing shared provenance**

  Keep the existing three IDs and guidance, but replace proprietary references with:

  - `warm-natural` → `Inspired by warm neutrals and layered timber tones.`
  - `soft-botanical` → keep its existing generic provenance.
  - `cool-airy` → `Inspired by airy blue-grey and soft off-white combinations.`

- [ ] **Step 6: Run the domain test and confirm it passes**

  Run: `flutter test test/features/room_studio/domain/illustrated_room_test.dart`

  Expected: PASS with eight living palettes, unchanged colour matrices elsewhere, and no disallowed shade metadata.

- [ ] **Step 7: Review the Task 1 diff checkpoint**

  Run: `git diff --check && git diff -- lib/features/room_studio/domain/illustrated_room.dart test/features/room_studio/domain/illustrated_room_test.dart`

  Expected: no whitespace errors; only catalog data, generic metadata, and its tests changed.

### Task 2: Verify the longer list in the Room Studio UI

**Files:**
- Modify: `test/features/room_studio/presentation/illustrated_room_screen_test.dart:620-810`
- Modify: `lib/features/room_studio/presentation/illustrated_room_flyout.dart:129-310`

**Interfaces:**
- Consumes: The eight-entry `IllustratedRoomCatalog.living.palettes` produced by Task 1 and the existing `IllustratedRoomScreen(templateId: ...)`/`room-palette-<id>` keys.
- Produces: Dynamic surface-help copy that does not claim exactly three looks; verified scrolling and selection for the appended presets.

- [ ] **Step 1: Write a failing living-room widget test**

  Add `testWidgets('living room exposes and applies all eight generic looks', ...)` using `_pumpEditor(..., templateId: 'living', disableAnimations: true)`. Open the compact colour tools and Looks flyout, assert all eight `room-palette-<id>` keys exist, use `_tapKey` to scroll to and select `room-palette-peach-coral-glow`, and assert:

  ```dart
  expect(draft.sourcePaletteId, 'peach-coral-glow');
  expect(draft.colors!.wall.hex, '#F1B89B');
  expect(draft.colors!.ceiling.hex, '#F8F4EB');
  expect(draft.colors!.floor.hex, '#C5AD8A');
  expect(draft.colors!.furniture.hex, '#EDA28E');
  expect(
    tester.getSemantics(find.bySemanticsLabel('Peach and Coral Glow')),
    matchesSemantics(
      label: 'Peach and Coral Glow',
      isButton: true,
      isSelected: true,
      hasTapAction: true,
    ),
  );
  ```

  Read `draft` with
  `harness.container.read(illustratedRoomProvider).draftFor('living')!`.

  Then open the wall surface flyout and assert the generic help copy plus these
  eight unique wall suggestion keys: `E6D8C3`, `C4D3C1`, `D3E0E4`, `E5C8BE`,
  `E49473`, `C8C8C6`, `DFCAC9`, and `F1B89B`. Assert the old
  `Suggestions come from the three complete room looks.` text is absent.

- [ ] **Step 2: Run the widget test and confirm the intended failure**

  Run: `flutter test test/features/room_studio/presentation/illustrated_room_screen_test.dart --plain-name 'living room exposes and applies all eight generic looks'`

  Expected: FAIL until Task 1 data exists and the fixed-count help copy is replaced.

- [ ] **Step 3: Make the help copy count-independent**

  In `_SurfaceContent`, replace `Suggestions come from the three complete room looks.` with `Suggestions come from the complete room looks.` No widget structure or interaction changes are needed because the existing flyout is scrollable and renders catalog entries dynamically.

- [ ] **Step 4: Run the focused widget test and Room Studio test group**

  Run:

  ```bash
  flutter test test/features/room_studio/presentation/illustrated_room_screen_test.dart --plain-name 'living room exposes and applies all eight generic looks'
  flutter test test/features/room_studio/domain test/features/room_studio/application test/features/room_studio/presentation
  ```

  Expected: PASS; the final appended card is reachable and applying it produces the exact four colours.

- [ ] **Step 5: Format and run repository verification**

  Run:

  ```bash
  dart format lib/features/room_studio/domain/illustrated_room.dart lib/features/room_studio/presentation/illustrated_room_flyout.dart test/features/room_studio/domain/illustrated_room_test.dart test/features/room_studio/presentation/illustrated_room_screen_test.dart
  dart format --output=none --set-exit-if-changed lib test
  flutter analyze
  flutter test
  ```

  Expected: formatter reports no remaining changes, analyzer reports `No issues found!`, and the full test suite passes.

- [ ] **Step 6: Review the final diff checkpoint**

  Run: `git status --short && git diff --check && git diff --stat && git diff`

  Expected: only the approved spec/plan, catalog/test updates, and count-independent UI copy are present; no paint-brand shade metadata or unrelated edits appear.
