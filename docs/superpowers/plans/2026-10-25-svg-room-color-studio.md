# SVG Room Color Studio Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a full-screen, persistent SVG study-room color tester that starts in grayscale, applies complete recommended or custom color combinations to Wall, Ceiling, Floor and Furniture, and scales to future room templates.

**Architecture:** Keep the illustrated-room domain and saved designs independent from the existing real-photo mask/recolor domain. A typed template catalog drives one shared editor; `flutter_svg` maps four reserved SVG source colors to grayscale or the current complete surface palette, while Riverpod owns the session draft and a dedicated Hive repository owns durable named designs.

**Tech Stack:** Flutter 3.41+/Dart 3.11, Riverpod 3, GoRouter 17, Hive 2, `flutter_svg` 2.3, Flutter widget/unit tests, existing guarded macOS verification.

**Spec:** `docs/superpowers/specs/2026-10-25-svg-room-color-studio-design.md`

## Global Constraints

- Preserve the existing real-photo `RoomLayerColors`, masks, photo draft and **Visualize your room** flow unchanged.
- Preserve unrelated working-tree changes; stage only exact task-owned paths and never reset or clean the repository.
- The study art must be original, dedicated to studying, watermark-free and contain no bed or copied screenshot controls.
- Ordinary first entry is grayscale; a preset or first custom choice always produces a complete four-surface colored room.
- Editable surfaces are exactly Wall, Ceiling, Floor and Furniture; highlights, shadows, plants, screens, books and decor remain authored colors.
- Saved illustrated designs use a separate `illustrated_room_designs_v1` Hive box and survive fresh app/provider-container restarts.
- Recommended palettes are guidance, not calibrated paint predictions or universal “best” claims.
- Touch targets are at least 48 logical pixels; support 2x text, keyboard insets, reduced motion, portrait, 640x360 landscape and tablet layouts.
- Add no platform permission, schema migration, network service, code generation or native configuration.
- Do not run `flutter build`, Gradle, CocoaPods, Xcode, install, clean, APK/IPA packaging or native compiler commands.
- Dependency resolution may run only for `flutter_svg`; if it needs unavailable network access or native build hooks, stop and request permission.

## Review Focus

- A save that is waiting on disk while the user changes another surface must persist the captured snapshot without marking the newer draft clean; Task 4 adds the gated-write test.
- A malformed/missing SVG token must fail the renderer/asset test instead of silently leaving a region unchanged; Task 5 renders the real asset and samples all four region anchors.
- A valid saved record for a template absent from the current catalog must remain listed but disabled and preserved on disk; Tasks 2, 3 and 7 add model, repository and UI tests.
- Storage flush/load failures and concurrent save/delete requests must retain the last durable list and recover through Retry; Tasks 3, 4 and 7 exercise those paths.
- Short landscape, large text and an open keyboard must keep Back and color controls reachable with no overflow; Task 6 adds the exact viewport tests before the responsive shell.

---

## File Structure

### New production files

- `lib/features/room_studio/domain/illustrated_room.dart` — surface/color value objects, palette/template validation and the typed room catalog.
- `lib/features/room_studio/domain/illustrated_room_draft.dart` — grayscale/colored session state and pure transitions.
- `lib/features/room_studio/domain/saved_room_design.dart` — validated version-1 persistent snapshot.
- `lib/features/room_studio/domain/room_design_repository.dart` — durable repository contract and safe exception.
- `lib/data/db/hive_room_design_repository.dart` — serialized, flush-gated Hive implementation.
- `lib/features/room_studio/application/room_designs_providers.dart` — repository factory and durable saved-design library.
- `lib/features/room_studio/application/illustrated_room_controller.dart` — retained draft, palette/custom/handoff transitions and save snapshot coordination.
- `lib/features/room_studio/presentation/illustrated_room_svg.dart` — four-token `ColorMapper`, SVG widget and scene semantics.
- `lib/features/room_studio/presentation/illustrated_room_controls.dart` — surface chips, recommended looks and edit actions.
- `lib/features/room_studio/presentation/illustrated_room_screen.dart` — full-screen responsive editor shell.
- `lib/features/room_studio/presentation/saved_room_designs_sheet.dart` — save/rename/reopen/delete/retry UI.
- `assets/rooms/study_room.svg` — original vector scene with one fixed viewBox and four reserved editable fills.

### New test/support files

- `test/features/room_studio/domain/illustrated_room_test.dart`
- `test/features/room_studio/domain/illustrated_room_draft_test.dart`
- `test/features/room_studio/domain/saved_room_design_test.dart`
- `test/data/db/hive_room_design_repository_test.dart`
- `test/features/room_studio/application/room_designs_providers_test.dart`
- `test/features/room_studio/application/illustrated_room_controller_test.dart`
- `test/features/room_studio/presentation/illustrated_room_svg_test.dart`
- `test/features/room_studio/presentation/illustrated_room_screen_test.dart`
- `test/features/room_studio/presentation/saved_room_designs_sheet_test.dart`
- `test/features/room_studio/presentation/illustrated_room_integration_test.dart`
- `test/support/in_memory_room_design_repository.dart`

### Existing files modified

- `pubspec.yaml:30-46,69-73` and `pubspec.lock` — `flutter_svg` and `assets/rooms/`.
- `lib/features/room_studio/presentation/room_screen.dart:13-198` — replace the private painter demo with the reusable SVG entry card while retaining the photo CTA.
- `lib/routing/app_router.dart:13-54` — root `/room/study` route outside the tab shell.
- `lib/features/picker/presentation/color_explorer.dart:113-119` — preserve `roomColorProvider`, seed the illustrated draft and open the full-screen editor.
- Existing affected Room/handoff tests — update only assertions whose destination and illustrated UI intentionally change.
- `tool/render_previews.dart` — black-and-white and Focused Sage study-room preview scenarios.
- `README.md` — user-facing illustrated-room behavior, storage boundary and no-calibration note.

## Command convention

Every Flutter test/analyze command below means the guarded absolute invocation, with no build:

```sh
COLOR_LAB_FLUTTER_ROOT=/Users/jamirulislam/Applications/flutter
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" <command> --no-pub --reporter expanded
```

For `analyze`, omit `--reporter expanded`. For Dart formatting use:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed <paths>
```

Before each task commit, first run ordinary `dart format` on that task's listed
Dart paths, then run the non-mutating format check and the task's green tests.

### Task 1: Typed room catalog and pure draft transitions

**Files:**
- Create: `lib/features/room_studio/domain/illustrated_room.dart`
- Create: `lib/features/room_studio/domain/illustrated_room_draft.dart`
- Test: `test/features/room_studio/domain/illustrated_room_test.dart`
- Test: `test/features/room_studio/domain/illustrated_room_draft_test.dart`

**Interfaces:**
- Consumes: `RgbColor` from `lib/core/color/color_models.dart`.
- Produces: `IllustratedRoomSurface`, `IllustratedRoomColors`, `IllustratedRoomPalette`, `IllustratedRoomTemplate`, `IllustratedRoomCatalog`, `IllustratedRoomVisualMode`, and `IllustratedRoomDraft` for all later tasks.

- [ ] **Step 1: Write catalog tests with literal palette fixtures**

  Pin `IllustratedRoomCatalog.study.id == 'study'`, asset `assets/rooms/study_room.svg`, editable surfaces in enum order, default palette `focus-sage`, and these complete values:

  | Palette ID | Wall | Ceiling | Floor | Furniture |
  | --- | --- | --- | --- | --- |
  | `focus-sage` | `#A7B5A0` | `#F7F2E8` | `#C9A77B` | `#5B4636` |
  | `bright-neutral` | `#E8E0D4` | `#FCF9F2` | `#D6B889` | `#6B7280` |
  | `cool-focus` | `#A9BBC8` | `#F3F6F7` | `#B99370` | `#34495E` |
  | `warm-creative` | `#C98F76` | `#FFF4E6` | `#B98663` | `#35524A` |

  Assert duplicate palette IDs, an empty template ID/title/asset and a missing default palette are rejected. Assert `maybeById('future-room') == null`.

- [ ] **Step 2: Write pure draft RED tests**

  Cover these named behaviors:

  ```dart
  test('fresh draft is grayscale and not saveable', () { ... });
  test('recommended look colors all four surfaces atomically', () { ... });
  test('first custom color seeds focus sage then overrides its surface', () { ... });
  test('later custom color changes only the selected surface', () { ... });
  test('wall handoff creates a complete colored dirty draft', () { ... });
  test('black and white clears colors palette and saved identity', () { ... });
  test('mark saved preserves exact clean identity', () { ... });
  ```

  For a first custom Wall `#123456`, assert Ceiling/Floor/Furniture remain the exact `focus-sage` values and Wall alone becomes `#123456`.

- [ ] **Step 3: Run both tests and verify RED**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain/illustrated_room_test.dart --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain/illustrated_room_draft_test.dart --reporter expanded
  ```

  Expected: non-zero because the new types do not exist.

- [ ] **Step 4: Implement the value objects and catalog**

  Use these exact public APIs:

  ```dart
  enum IllustratedRoomSurface { wall, ceiling, floor, furniture }

  final class IllustratedRoomColors {
    IllustratedRoomColors({required RgbColor wall, required RgbColor ceiling,
      required RgbColor floor, required RgbColor furniture});
    RgbColor colorFor(IllustratedRoomSurface surface);
    IllustratedRoomColors withColor(IllustratedRoomSurface surface, RgbColor color);
  }

  final class IllustratedRoomPalette {
    IllustratedRoomPalette({required String id, required String name,
      required String guidance, required IllustratedRoomColors colors});
  }

  final class IllustratedRoomTemplate {
    IllustratedRoomTemplate({required String id, required String title,
      required String assetPath, required String defaultPaletteId,
      required Iterable<IllustratedRoomPalette> palettes});
    IllustratedRoomPalette palette(String id);
  }

  abstract final class IllustratedRoomCatalog {
    static final IllustratedRoomTemplate study;
    static final List<IllustratedRoomTemplate> all;
    static IllustratedRoomTemplate? maybeById(String id);
  }
  ```

  Make palette/template collections unmodifiable and implement value equality where state/tests need it.

- [ ] **Step 5: Implement immutable draft transitions**

  `IllustratedRoomDraft.grayscale(template)`, `applyPalette(id)`, `setSurfaceColor(surface,color)`, `applyWallHandoff(color)`, `resetToGrayscale()`, `markSaved({required id, required name})`, and `asUnsavedCopy()` must return new values. A colored draft always has a complete `IllustratedRoomColors`; `canSave` is true only when colored and dirty.

- [ ] **Step 6: Run tests and format**

  Repeat the two Step 3 commands. Then run:

  ```sh
  /Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib/features/room_studio/domain/illustrated_room.dart lib/features/room_studio/domain/illustrated_room_draft.dart test/features/room_studio/domain/illustrated_room_test.dart test/features/room_studio/domain/illustrated_room_draft_test.dart
  ```

  Expected: both task files PASS; format exits 0.

- [ ] **Step 7: Commit only Task 1 paths**

  ```sh
  git add lib/features/room_studio/domain/illustrated_room.dart lib/features/room_studio/domain/illustrated_room_draft.dart test/features/room_studio/domain/illustrated_room_test.dart test/features/room_studio/domain/illustrated_room_draft_test.dart
  git commit -m "feat: model illustrated room palettes"
  ```

### Task 2: Saved design schema and repository contract

**Files:**
- Create: `lib/features/room_studio/domain/saved_room_design.dart`
- Create: `lib/features/room_studio/domain/room_design_repository.dart`
- Test: `test/features/room_studio/domain/saved_room_design_test.dart`

**Interfaces:**
- Consumes: `IllustratedRoomColors` from Task 1.
- Produces: `SavedRoomDesign`, `RoomDesignRepository`, and `RoomDesignStorageException` for Tasks 3, 4 and 7.

- [ ] **Step 1: Write RED schema tests**

  Assert a record round-trips exactly through this version-1 map:

  ```dart
  {
    'version': 1,
    'id': 'study-1792900800000000',
    'name': 'My focused study',
    'templateId': 'study',
    'wall': '#A7B5A0',
    'ceiling': '#F7F2E8',
    'floor': '#C9A77B',
    'furniture': '#5B4636',
    'createdAt': '2026-10-25T04:00:00.000Z',
    'updatedAt': '2026-10-25T04:00:00.000Z',
  }
  ```

  Also assert names trim but reject empty or more than 60 Unicode scalar values, colors must be canonical uppercase six-digit HEX, timestamps must be canonical UTC, `updatedAt >= createdAt`, unexpected/missing keys fail, and an unknown non-empty `templateId` remains a valid preserved record.

- [ ] **Step 2: Run the test and verify RED**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain/saved_room_design_test.dart --reporter expanded
  ```

  Expected: non-zero because `SavedRoomDesign` does not exist.

- [ ] **Step 3: Implement snapshot and contract**

  ```dart
  final class SavedRoomDesign {
    SavedRoomDesign({required String id, required String name,
      required String templateId, required IllustratedRoomColors colors,
      required DateTime createdAt, required DateTime updatedAt});
    factory SavedRoomDesign.fromMap(Map<dynamic, dynamic> map);
    Map<String, Object> toMap();
  }

  abstract interface class RoomDesignRepository {
    Future<List<SavedRoomDesign>> load();
    Future<SavedRoomDesign> save({String? existingId, required String name,
      required String templateId, required IllustratedRoomColors colors});
    Future<void> delete(String id);
    Future<void> close();
  }

  final class RoomDesignStorageException implements Exception { const RoomDesignStorageException(); }
  ```

  Do not validate `templateId` against the current catalog inside `fromMap`; that would destroy forward/backward preservation.

- [ ] **Step 4: Run test and format**

  Repeat Step 2, then run:

  ```sh
  /Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib/features/room_studio/domain/saved_room_design.dart lib/features/room_studio/domain/room_design_repository.dart test/features/room_studio/domain/saved_room_design_test.dart
  ```

  Expected: test PASS and format exits 0.

- [ ] **Step 5: Commit only Task 2 paths**

  ```sh
  git add lib/features/room_studio/domain/saved_room_design.dart lib/features/room_studio/domain/room_design_repository.dart test/features/room_studio/domain/saved_room_design_test.dart
  git commit -m "feat: define saved room design schema"
  ```

### Task 3: Durable Hive room-design repository

**Files:**
- Create: `lib/data/db/hive_room_design_repository.dart`
- Test: `test/data/db/hive_room_design_repository_test.dart`

**Interfaces:**
- Consumes: `RoomDesignRepository`, `SavedRoomDesign`, and `IllustratedRoomColors` from Tasks 1–2.
- Produces: `HiveRoomDesignRepository.open({required String directory, String boxName = 'illustrated_room_designs_v1', DateTime Function()? clock})`.

- [ ] **Step 1: Write repository RED tests against real temporary files**

  Mirror the project's existing Hive durability tests and cover:

  - create, close, reopen and exact-field reload;
  - update by `existingId` retaining `createdAt` and changing `updatedAt`;
  - stable IDs `'<templateId>-<UTC microseconds>'` with `-1`, `-2` collision suffixes;
  - newest-`updatedAt` first, ID ascending for ties;
  - delete idempotence and durability across reopen;
  - concurrent create/update/delete/load/close serialized with maximum one write;
  - equal box names in separate directories stay independent;
  - unknown-template records load unchanged;
  - missing update target fails safely rather than creating another record;
  - malformed records, mismatched Hive keys, corrupt bytes, unreadable directory and failed flush preserve original bytes and expose only `RoomDesignStorageException`.

- [ ] **Step 2: Run the repository test and verify RED**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/data/db/hive_room_design_repository_test.dart --reporter expanded
  ```

  Expected: non-zero because `HiveRoomDesignRepository` does not exist.

- [ ] **Step 3: Implement the serialized Hive repository**

  Follow `HivePaletteRepository`: private `HiveImpl`, double-observed open, `_pending` serialization, `_needsFlush` durability barrier, unmodifiable snapshots and owned close lifecycle. Generate IDs only for creates; updates require an existing matching ID and retain creation time.

- [ ] **Step 4: Run repository and schema tests**

  Repeat Step 2 and the Task 2 Step 2 command. Expected: both PASS with no unhandled asynchronous errors.

- [ ] **Step 5: Commit only Task 3 paths**

  ```sh
  git add lib/data/db/hive_room_design_repository.dart test/data/db/hive_room_design_repository_test.dart
  git commit -m "feat: persist illustrated room designs"
  ```

### Task 4: Riverpod library and session controller

**Files:**
- Create: `lib/features/room_studio/application/room_designs_providers.dart`
- Create: `lib/features/room_studio/application/illustrated_room_controller.dart`
- Create: `test/support/in_memory_room_design_repository.dart`
- Test: `test/features/room_studio/application/room_designs_providers_test.dart`
- Test: `test/features/room_studio/application/illustrated_room_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 1–3.
- Produces: `roomDesignStorageDirectoryProvider`, `roomDesignRepositoryProvider`, `savedRoomDesignsProvider`, `illustratedRoomProvider`, `SavedRoomDesignsController`, and `IllustratedRoomController` for presentation and routing.

- [ ] **Step 1: Write saved-library RED tests**

  Using `InMemoryRoomDesignRepository`, assert immutable newest-first load; serialized mutations; no publication before a gated write becomes durable; failed save/delete keeps the last list; initial-load failure blocks edits until Retry; retry recreates only a failed factory; disposal closes a successfully opened repository; unresolved factory disposal creates no box; and fresh ProviderContainers reload actual Hive data.

- [ ] **Step 2: Write session/controller RED tests**

  Exercise these exact methods:

  ```dart
  void applyPalette(String paletteId);
  void setSurfaceColor(IllustratedRoomSurface surface, RgbColor color);
  void applyWallHandoff(RgbColor color);
  void resetToGrayscale();
  void openDesign(SavedRoomDesign design);
  Future<SavedRoomDesign> saveDesign(String name);
  Future<void> deleteDesign(String id);
  ```

  Assert state survives provider reads/theme-independent container activity. Gate `saveDesign`, change Furniture before the gate completes, then assert the saved record contains the earlier captured colors while the newer draft remains dirty and is not marked with the saved identity. Assert deleting the open design leaves its colors visible as an unsaved copy. Assert an unavailable template cannot open and does not alter state.

- [ ] **Step 3: Run both test files and verify RED**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_designs_providers_test.dart --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/illustrated_room_controller_test.dart --reporter expanded
  ```

  Expected: non-zero because the providers/controllers do not exist.

- [ ] **Step 4: Implement the repository providers and async library**

  Follow `saved_palettes_providers.dart`: pass the directory `${documents.path}/color_lab` to `HiveRoomDesignRepository.open` and let its default box name produce `illustrated_room_designs_v1.hive`. Expose `saveDesign(...)`, `renameDesign(String id, String name)`, `deleteDesign(id)` and `retry()`, serialize callers, await initial load before mutation, and retain the last committed list on caller-facing failures. `renameDesign` reloads the target and writes its existing template/colors; it never uses the open draft's colors.

- [ ] **Step 5: Implement the retained draft controller**

  `build()` returns `IllustratedRoomDraft.grayscale(IllustratedRoomCatalog.study)`. Capture the immutable draft before async save; mark clean only when state still equals that captured snapshot. Expose `roomDesignClockProvider` and `defaultRoomDesignName(IllustratedRoomTemplate, DateTime)` so presentation gets `'<template title> - YYYY-MM-DD'` from local client date without coupling storage to UI copy.

- [ ] **Step 6: Run application, domain and repository tests**

  Repeat Step 3, then run the Task 1–3 test commands. Expected: all Task 1–4 tests PASS.

- [ ] **Step 7: Commit only Task 4 paths**

  ```sh
  git add lib/features/room_studio/application/room_designs_providers.dart lib/features/room_studio/application/illustrated_room_controller.dart test/support/in_memory_room_design_repository.dart test/features/room_studio/application/room_designs_providers_test.dart test/features/room_studio/application/illustrated_room_controller_test.dart
  git commit -m "feat: manage illustrated room drafts"
  ```

### Task 5: Original SVG asset and dynamic renderer

**Files:**
- Modify: `pubspec.yaml:30-46,69-73`
- Modify: `pubspec.lock`
- Create: `assets/rooms/study_room.svg`
- Create: `lib/features/room_studio/presentation/illustrated_room_svg.dart`
- Test: `test/features/room_studio/presentation/illustrated_room_svg_test.dart`

**Interfaces:**
- Consumes: `IllustratedRoomDraft` and template catalog from Task 1.
- Produces: `IllustratedRoomColorMapper` and `IllustratedRoomSvg` for Tasks 6 and 8.

- [ ] **Step 1: Add configuration-only SVG support**

  Add `flutter_svg: ^2.3.0` under dependencies and `assets/rooms/` under assets. Run `/Users/jamirulislam/Applications/flutter/bin/flutter pub get` only to resolve the package/lockfile. Do not run a build. If sandboxed resolution cannot use the available cache, request network permission rather than editing the lockfile manually.

- [ ] **Step 2: Write mapper and real-asset RED tests**

  Pin authoring tokens:

  ```dart
  wall      = Color(0xFFFF00A1);
  ceiling   = Color(0xFF00E5FF);
  floor     = Color(0xFFB7FF00);
  furniture = Color(0xFF7A00FF);
  ```

  Pin grayscale output as Wall `#C8C8C8`, Ceiling `#F2F2F2`, Floor `#A9A9A9`, Furniture `#737373`. Directly assert the mapper leaves unrelated authored colors unchanged. Pump the actual asset in a `RepaintBoundary` at 1200x800, rasterize it, and sample one documented unobstructed anchor inside each region in both grayscale and a four-distinct-color draft; each sample must match the intended region within one channel value. Assert the widget exposes one scene semantic label containing all four surface names/HEX values and no decorative descendants.

- [ ] **Step 3: Run the renderer test and verify RED**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_svg_test.dart --reporter expanded
  ```

  Expected: non-zero because the renderer/asset are absent.

- [ ] **Step 4: Draw the original study-room SVG**

  Use `viewBox="0 0 1200 800"`, explicit fills and group IDs `surface-wall`, `surface-ceiling`, `surface-floor`, `surface-furniture`. Include back/side wall perspective, ceiling, floor, window/curtains, desk, drawers, office chair, shelves, books, lamp, art, rug and plants; no bed. Put neutral translucent highlights/shadows above the four base fills and record the four unobstructed test anchor coordinates in a file comment.

- [ ] **Step 5: Implement token mapping and scene widget**

  ```dart
  final class IllustratedRoomColorMapper extends ColorMapper {
    IllustratedRoomColorMapper(IllustratedRoomDraft draft);
    @override
    Color substitute(String? id, String elementName, String attributeName, Color color);
  }

  class IllustratedRoomSvg extends StatelessWidget {
    const IllustratedRoomSvg({super.key, required this.draft,
      this.fit = BoxFit.contain, this.alignment = Alignment.center});
  }
  ```

  Use `SvgPicture.asset` with `ColorMapper`, `placeholderBuilder` and `errorBuilder`; do not mutate XML strings or recreate geometry with `CustomClipper`.

- [ ] **Step 6: Run renderer tests**

  Repeat Step 3. Expected: renderer test PASS with all four real-asset anchors observed; do not run an app build or a separate asset compiler.

- [ ] **Step 7: Commit only Task 5 paths**

  ```sh
  git add pubspec.yaml pubspec.lock assets/rooms/study_room.svg lib/features/room_studio/presentation/illustrated_room_svg.dart test/features/room_studio/presentation/illustrated_room_svg_test.dart
  git commit -m "feat: render recolorable study room svg"
  ```

### Task 6: Full-screen editor and color controls

**Files:**
- Create: `lib/features/room_studio/presentation/illustrated_room_controls.dart`
- Create: `lib/features/room_studio/presentation/illustrated_room_screen.dart`
- Test: `test/features/room_studio/presentation/illustrated_room_screen_test.dart`

**Interfaces:**
- Consumes: `illustratedRoomProvider`, `IllustratedRoomSvg`, existing theme/widgets and `showMixerColorPicker`.
- Produces: `IllustratedRoomScreen` and `IllustratedRoomControls`; Task 7 plugs saved-design actions into the same screen.

- [ ] **Step 1: Write editor RED tests**

  Assert initial scene label is `Black & white`, Save is disabled, all four surface chips are present with 48dp targets, and recommended cards show Focused Sage as Recommended. Tapping `cool-focus` colors all four chips with its literal HEX values. From a fresh grayscale draft, selecting Ceiling then entering `#123456` through the real picker seeds Focused Sage and overrides only Ceiling. Picker Cancel is a no-op. Returning to black and white confirms only for a dirty colored draft. Under reduced motion, the updated scene semantics and swatches appear without an intermediate animated frame.

  In the same RED file exercise 360x800 portrait at 2x text, 640x360 landscape, 1024x768 tablet and a keyboard bottom inset. Each case must keep Back hit-testable, make all four surfaces and Custom color reachable by scrolling, keep actions at least 48dp and throw no overflow exception.

- [ ] **Step 2: Run the widget test and verify RED**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_screen_test.dart --reporter expanded
  ```

  Expected: non-zero because the editor widgets do not exist.

- [ ] **Step 3: Implement surface and palette controls**

  Provide stable keys `room-surface-<name>`, `room-palette-<id>`, `room-custom-color`, `room-black-white`, `room-save-design`, and `room-open-designs`. Surface chips show label plus HEX in colored mode and `Not set` in grayscale. `Custom color` calls the existing `showMixerColorPicker` with the selected surface's current color.

- [ ] **Step 4: Implement the responsive editor shell**

  Keep Back in a top SafeArea overlay. Use an `AnimatedSwitcher` keyed by mode/colors. Portrait uses a `DraggableScrollableSheet` (`minChildSize .16`, `initialChildSize .30`, `maxChildSize .72`); width at least 720 or short landscape (`width > height && height < 500`) uses a 320dp side panel. All control content scrolls independently. Leave saved-design callbacks ready for Task 7 rather than duplicating controls.

- [ ] **Step 5: Run widget, renderer and controller tests**

  Repeat Task 6 Step 2, Task 5 Step 3 and Task 4's controller command. Expected: all PASS at every pinned viewport with no overflow exception.

- [ ] **Step 6: Commit only Task 6 paths**

  ```sh
  git add lib/features/room_studio/presentation/illustrated_room_controls.dart lib/features/room_studio/presentation/illustrated_room_screen.dart test/features/room_studio/presentation/illustrated_room_screen_test.dart
  git commit -m "feat: add study room color editor"
  ```

### Task 7: Save, rename, reopen and delete designs

**Files:**
- Create: `lib/features/room_studio/presentation/saved_room_designs_sheet.dart`
- Test: `test/features/room_studio/presentation/saved_room_designs_sheet_test.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_screen.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_screen_test.dart`

**Interfaces:**
- Consumes: controllers/providers from Task 4 and editor hooks from Task 6.
- Produces: complete persistent editor actions and `showSavedRoomDesigns(BuildContext)`.

- [ ] **Step 1: Write saved-design UI RED tests**

  Cover Save opening a name dialog prefilled `Study room - 2026-10-25`, trimmed 1–60-character validation, disabled Save in grayscale, progress lock during writes, friendly inline failure and retry without losing colors, successful clean state, and later edit updating the same ID. In the library cover loading/error/Retry/empty states, newest-first rows, unavailable-template row retained but disabled, tap-to-reopen, rename through `SavedRoomDesignsController.renameDesign` while preserving that row's exact colors, confirmed delete, and deleting the current design leaving an unsaved colored copy.

- [ ] **Step 2: Run the saved-sheet/editor tests and verify RED**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/saved_room_designs_sheet_test.dart --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_screen_test.dart --reporter expanded
  ```

  Expected: assertions fail because save/library actions are not connected.

- [ ] **Step 3: Implement name dialog and library sheet**

  Use root-navigator safe modal surfaces, keyboard-aware scrolling, 48dp row/actions and existing motion tokens. Never show a raw storage path/exception. Rename calls `SavedRoomDesignsController.renameDesign` for the target row; delete calls controller deletion only after confirmation.

- [ ] **Step 4: Connect editor actions**

  Save uses the session controller's captured-snapshot semantics. **My designs** opens the sheet. Reopening replaces the visible draft only after validating the template is available. Failures retain the current scene and last durable list.

- [ ] **Step 5: Run presentation and application tests**

  Repeat Step 2 and Task 4's two test commands. Expected: Task 4, 6 and 7 tests PASS.

- [ ] **Step 6: Commit only Task 7 paths**

  ```sh
  git add lib/features/room_studio/presentation/saved_room_designs_sheet.dart lib/features/room_studio/presentation/illustrated_room_screen.dart test/features/room_studio/presentation/saved_room_designs_sheet_test.dart test/features/room_studio/presentation/illustrated_room_screen_test.dart
  git commit -m "feat: manage saved room designs"
  ```

### Task 8: Room entry, routing and Use in Room handoff

**Files:**
- Modify: `lib/features/room_studio/presentation/room_screen.dart:13-198`
- Modify: `lib/routing/app_router.dart:13-54`
- Modify: `lib/features/picker/presentation/color_explorer.dart:113-119`
- Create: `test/features/room_studio/presentation/illustrated_room_integration_test.dart`
- Modify: existing affected tests under `test/widget_test.dart`, `test/features/picker/`, `test/features/harmonies/`, `test/features/formula/`, `test/features/color_test/`, and `test/features/room_studio/presentation/room_masks_integration_test.dart` only where the intentional destination changes.

**Interfaces:**
- Consumes: `IllustratedRoomScreen`, SVG preview and `illustratedRoomProvider`.
- Produces: root `/room/study` flow and cross-feature wall handoff.

- [ ] **Step 1: Write full-app integration RED tests**

  Assert Room retains `open-room-masks`, adds `open-illustrated-study`, shows the SVG preview and leaves real-photo draft identity untouched. Opening the study removes the bottom navigation and Back returns to the same Room tab. Theme/tab changes preserve the session draft. A real **Use in Room** action still sets `roomColorProvider`, applies the default complete palette with the selected Wall override, navigates to `/room/study`, preserves Lab/history/photo-mask state, and does not auto-save a room design.

- [ ] **Step 2: Run the new integration file and affected handoff tests to verify RED**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_integration_test.dart --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_masks_integration_test.dart --reporter expanded
  ```

  Expected: fail on missing route/button and old `/room` destination.

- [ ] **Step 3: Replace the legacy private painter entry**

  Remove `_RoomPainter` and three wall-only chips. Keep the real-photo CTA/copy and add an illustrated study card using `IllustratedRoomSvg` plus a clear full-screen action. Do not reset a retained draft on ordinary reopen; the provider's first build already supplies grayscale.

- [ ] **Step 4: Add the root route and handoff**

  Register `/room/study` before the stateful shell, returning `const IllustratedRoomScreen()`. In `showColorDetails`, preserve `roomColorProvider.notifier.setColor(result.color)`, also call `illustratedRoomProvider.notifier.applyWallHandoff(result.color)`, then `context.go('/room/study')`.

- [ ] **Step 5: Update only intentional old expectations and run regressions**

  Repeat Step 2, then run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
  ```

  Expected: the complete suite PASS, including existing Room/picker/harmony/formula/color-test handoff behaviors; photo masks and saved color/history assertions remain unchanged.

- [ ] **Step 6: Commit only Task 8 paths**

  Stage exact modified files after inspecting `git diff` so unrelated game/routing/test changes already in the dirty worktree are not included. If exact-path staging would mix pre-existing lines in `app_router.dart` or `test/widget_test.dart`, do not commit that mixed file; document the overlap for final handoff instead of rewriting user work.

### Task 9: Accessibility semantics, preview and documentation coverage

**Files:**
- Modify: `test/features/room_studio/presentation/illustrated_room_integration_test.dart`
- Modify: `tool/render_previews.dart`
- Modify: `README.md`

**Interfaces:**
- Consumes: the complete feature.
- Produces: acceptance evidence and user/developer documentation; no new runtime API.

- [ ] **Step 1: Add RED semantic integration tests**

  Extend the integration test before changing production code. Assert the scene semantic label distinguishes grayscale from all four colored HEX values, selected surface/look state is exposed independently of color, storage errors are announced without raw exception data, and the physical-sample caveat is reachable in both light and dark themes.

- [ ] **Step 2: Run the semantic test and verify RED**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_integration_test.dart --reporter expanded
  ```

  Expected: fail on the not-yet-present caveat/error announcement or selection semantics.

- [ ] **Step 3: Make only evidence-driven accessibility adjustments**

  Fix only the failing semantics/copy without changing the domain, persistence, responsive layout or route contracts. Do not add `CustomClipper` surface overlays.

- [ ] **Step 4: Add preview scenarios and README section**

  Render deterministic light/dark previews for untouched grayscale and `focus-sage`, using the actual controller/asset, a fixed clock and an in-memory room-design repository override so preview generation never writes the user's application documents. Document recommended/custom behavior, My Room Designs persistence, how another template is registered, the physical-sample caveat and the separate real-photo editor.

- [ ] **Step 5: Run focused tests and preview renderer**

  Run:

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/data/db/hive_room_design_repository_test.dart --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub tool/render_previews.dart --reporter expanded
  ```

  Expected: PASS and new preview PNGs under `build/previews/`; these generated files are verification outputs, not manually authored source.

- [ ] **Step 6: Commit Task 9 source paths only**

  ```sh
  git add test/features/room_studio/presentation/illustrated_room_integration_test.dart tool/render_previews.dart README.md
  git commit -m "test: cover illustrated room experience"
  ```

### Task 10: Fresh no-build verification and handoff

**Files:**
- Modify only files required by verified failures; no speculative cleanup.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: fresh evidence for the final report.

- [ ] **Step 1: Inspect scope and whitespace**

  Run `git status --short`, `git diff --check`, and inspect diffs for every task-owned path. Confirm unrelated pre-existing modifications remain present and unstaged/uncommitted unless a mixed file made separation impossible.

- [ ] **Step 2: Run format verification on all changed Dart files**

  Expected: exit 0 with no changes required.

- [ ] **Step 3: Run the complete guarded test suite**

  ```sh
  COLOR_LAB_FLUTTER_ROOT=/Users/jamirulislam/Applications/flutter
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" test --no-pub --reporter expanded
  ```

  Expected: exit 0 and zero failing tests. Report every existing or new failure by test name if the suite is not green.

- [ ] **Step 4: Run guarded static analysis**

  ```sh
  COLOR_LAB_FLUTTER_ROOT=/Users/jamirulislam/Applications/flutter
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb "$COLOR_LAB_FLUTTER_ROOT/bin/flutter" analyze --no-pub
  ```

  Expected: exit 0 and `No issues found!`.

- [ ] **Step 5: Re-read the approved spec and verify each acceptance statement**

  Confirm original SVG, grayscale-first/full-color transition, four independent surfaces, presets/custom picker, durable save/reopen/rename/delete, future-template catalog, full-screen route, real-photo separation, accessibility and no-build constraint all have code plus test evidence.

- [ ] **Step 6: Request final review and address only verified findings**

  Use `superpowers:requesting-code-review` for a whole-change review, rerun every affected focused test, then repeat Steps 2–4 before any completion claim.

- [ ] **Step 7: Final handoff**

  Link the SVG, core editor, tests, approved spec and this plan; list commands and exact results. Explicitly state that no APK/IPA/native build or install was run, and call out any pre-existing dirty-file overlap or unverified device behavior.
