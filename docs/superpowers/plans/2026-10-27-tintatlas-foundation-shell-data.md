# TintAtlas Foundation, Shell, and Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Freeze compatibility contracts, introduce TintAtlas identity/localization/adaptive navigation, and make existing installation-local data independently recoverable before feature expansion.

**Architecture:** Preserve the internal `color_lab` package/storage identities while centralizing them behind typed registries. Mount the router without Room models, use a four-destination adaptive shell, and migrate existing repositories to snapshots that expose corrupt records without hiding healthy work.

**Tech Stack:** Flutter Material 3, Riverpod, GoRouter, Hive, generated `flutter_localizations`, Flutter unit/widget tests.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md`

## Global Constraints

- Read the master plan first; its Global Constraints apply verbatim.
- Preserve the literal private directory `color_lab`, existing Hive box names, Dart package name, model paths, and five GameIds.
- Runtime/store identity is `TintAtlas: Room Visualizer`; use `TintAtlas` where compact platform labels require it.
- Compact `<600`, Medium `600–839`, Expanded `840–1199`, Large `>=1200`.
- Home, Rooms, Learn, Games are the only root destinations; My Work is reached from Home/relevant features.
- English is complete first; all touched copy uses generated localizations and supports RTL/long strings.
- Do not execute package-ID changes until the publication-history gate records that a new ID is safe.

## Review Focus

- Existing private files under `color_lab` remain discoverable after the visible rename.
- One malformed saved color/palette/illustrated design remains quarantined while healthy records load.
- A model/network failure cannot prevent Home, illustrated Rooms, Learn, or Games from mounting.
- Shell navigation preserves each branch across width/orientation changes and system Back/predictive Back.
- 320×568, 568×320, keyboard-visible and 200% text layouts do not overflow or hide primary actions.

---

### Task 1: Baseline, identity, support, and verification ledger

**Files:**
- Create: `docs/release/verification-ledger.md`
- Create: `docs/release/identity-decision.md`
- Create: `docs/release/support-matrix.md`
- Create: `docs/release/schema-registry.md`
- Create: `docs/release/performance-budgets.md`
- Create: `tool/check_plan_coverage.dart`
- Test: `test/tool/check_plan_coverage_test.dart`
- Modify: none of the product files

**Interfaces:**
- Consumes: branch/HEAD/status, current analyzer/test output, platform configs, existing box names.
- Produces: signed-off gates `newListing`, `androidMinSdk`, `iosDeploymentTarget`, architecture list, baseline failure list, dependency/size/performance budgets, and immutable compatibility names for every later task.
- Produces: a deterministic CLI that extracts unique requirement IDs from the spec and exits non-zero when any ID is absent from the supplied plan files; `--allow` accepts only explicitly classified Post-launch/Deferred IDs.

- [ ] **Step 1: Write the coverage-tool RED tests.** Fixtures prove duplicate IDs count once, a missing launch ID fails with its name, all 161 approved-spec IDs are recognized, and only explicitly allowed Post-launch/Deferred IDs may be exempted.
- [ ] **Step 2: Run `flutter test test/tool/check_plan_coverage_test.dart`.** Expected: FAIL because the CLI does not exist.
- [ ] **Step 3: Implement the dependency-free Dart CLI and run it over the approved spec plus the complete plan set.** Expected: PASS with zero unclassified missing IDs.
- [ ] **Step 4: Capture the dirty-worktree and baseline evidence.** Record `TintAtlas`, HEAD `b4043bc`, the user-owned `lib/main.dart` diff, analyzer's one existing info, and full-test result `+1527 -38`; rerun focused failing files to list every baseline failure by test name.
- [ ] **Step 5: Run the publication/brand/support checks.** Set `newListing: true|false` with evidence, record the TintAtlas conflict screen, keep API 24/iOS 13 provisionally, and list Android/iOS release architectures and required test hardware.
- [ ] **Step 6: Inventory current schemas/routes/assets.** Pin `app_preferences_v1`, `color_history_v1`, `color_palettes_v1`, `illustrated_room_designs_v1`, `photo_acquisition_v1`, `game_profiles_v2`, `game_progress_v1`, all route paths, and the model hashes/URLs.
- [ ] **Step 7: Measure and propose numeric budgets.** Record dependency count, APK/IPA-equivalent size, first-frame time, aggregate model bytes, ten-project storage growth, peak memory, and key latency baselines on named hardware; an unmeasured/unapproved threshold is explicitly `blocked` with owner rather than invented.
- [ ] **Step 8: Verify documentation completeness.** Run `rg -ni 'PLACEHOLDER|UNRESOLVED|UNKNOWN' docs/release/{verification-ledger,identity-decision,support-matrix,schema-registry,performance-budgets}.md`; expected: no unexplained placeholder in an approved field and every blocked field names its owner/evidence.
- [ ] **Step 9: Commit only the Task 1 files.** Use explicit paths and `git commit -m "docs: record TintAtlas implementation baseline"`; verify the user-owned `lib/main.dart` is not staged.

### Task 2: Shared storage path and schema registry

**Files:**
- Create: `lib/data/storage/app_storage_directory.dart`
- Create: `lib/data/schema/schema_registry.dart`
- Test: `test/data/storage/app_storage_directory_test.dart`
- Test: `test/data/schema/schema_registry_test.dart`
- Modify: `lib/features/history/application/history_providers.dart`
- Modify: `lib/features/palette/application/saved_palettes_providers.dart`
- Modify: `lib/features/room_studio/application/room_designs_providers.dart`
- Modify: `lib/features/settings/application/app_preferences_providers.dart`
- Modify: `lib/features/games/application/game_profiles_provider.dart`
- Modify: `lib/features/picker/application/acquisition_intent_providers.dart`

**Interfaces:**
- Consumes: `Future<Directory> getApplicationDocumentsDirectory()`.
- Produces:
  ```dart
  const legacyPrivateDataDirectoryName = 'color_lab';
  enum LocalDataScope { sharedLibrary, gameProfile, cache, userExport }
  enum StorageBackend { hiveBox, fileTree, appPrivateCache }
  enum LocalDataCategory { preferences, savedColors, savedPalettes, illustratedRooms, roomProjects, coloringProjects, learningProgress, gameProfiles, modelCache }
  final appStorageDirectoryProvider = FutureProvider<Directory>(...);
  final class SchemaDescriptor { const SchemaDescriptor({required String id, required String storageName, required StorageBackend backend, required int currentVersion, required LocalDataScope scope}); }
  abstract final class SchemaRegistry { static const List<SchemaDescriptor> all = ...; }
  ```

- [ ] **Step 1: Write RED tests.** Assert the resolved directory ends in `/color_lab`, every descriptor ID plus `(backend, storageName)` is unique, every existing Hive box name/version is exact, file trees are not mislabeled as boxes, shared categories never have `gameProfile` scope, and branding never changes the private path.
- [ ] **Step 2: Run `flutter test test/data/storage/app_storage_directory_test.dart test/data/schema/schema_registry_test.dart`.** Expected: FAIL because the types do not exist.
- [ ] **Step 3: Implement the registry and replace duplicate directory providers.** Keep feature provider names as forwarding aliases for test overrides, but every production repository consumes `appStorageDirectoryProvider`.
- [ ] **Step 4: Run the new tests plus `flutter test test/data/db test/features/settings/application test/features/games/application/game_profiles_provider_test.dart`.** Expected: PASS with existing files visible.
- [ ] **Step 5: Commit.** `git commit -m "refactor: centralize compatible local storage"` with only Task 2 paths.

### Task 3: Isolate corrupt records without deleting them

**Files:**
- Create: `lib/data/schema/corrupt_record.dart`
- Create: `lib/data/schema/repository_snapshot.dart`
- Modify: `lib/features/history/domain/color_history_repository.dart`
- Modify: `lib/features/palette/domain/saved_palette_repository.dart`
- Modify: `lib/features/room_studio/domain/room_design_repository.dart`
- Modify: `lib/data/db/hive_color_history_repository.dart`
- Modify: `lib/data/db/hive_palette_repository.dart`
- Modify: `lib/data/db/hive_room_design_repository.dart`
- Modify: `lib/features/history/application/history_providers.dart`
- Modify: `lib/features/palette/application/saved_palettes_providers.dart`
- Modify: `lib/features/room_studio/application/room_designs_providers.dart`
- Test: `test/data/db/corrupt_record_isolation_test.dart`
- Modify test: `test/data/db/hive_color_history_repository_test.dart`
- Modify test: `test/data/db/hive_color_history_durability_test.dart`
- Modify test: `test/data/db/hive_palette_repository_test.dart`
- Modify test: `test/data/db/hive_palette_durability_test.dart`
- Modify test: `test/data/db/hive_room_design_repository_test.dart`
- Modify test: `test/features/history/application/history_providers_test.dart`
- Modify test: `test/features/palette/application/saved_palettes_providers_test.dart`
- Modify test: `test/features/room_studio/application/room_designs_providers_test.dart`

**Interfaces:**
- Produces:
  ```dart
  final class CorruptRecord { const CorruptRecord({required String collectionId, required Object storageKey, required String reason}); }
  final class RepositorySnapshot<T> { const RepositorySnapshot({required List<T> records, required List<CorruptRecord> corruptRecords}); }
  Future<RepositorySnapshot<T>> loadSnapshot();
  ```
- Existing `load()` remains temporarily and returns `loadSnapshot().records`; later consumers migrate without a flag day.

- [ ] **Step 1: Write RED fixtures with one valid and one malformed Hive record.** Assert the valid item loads, the malformed key appears once in `corruptRecords`, its raw box value is unchanged, and save/delete of healthy records still flushes.
- [ ] **Step 2: Run the new isolation test.** Expected: FAIL because current `_read()` throws for the entire collection.
- [ ] **Step 3: Implement per-record decode isolation and immutable snapshots.** Box-open failure remains a repository error; only individual record decode/key mismatch becomes `CorruptRecord`.
- [ ] **Step 4: Update controllers to retain prior data and expose a recoverable warning.** Do not auto-delete, overwrite, or silently reset a corrupt record.
- [ ] **Step 5: Run all `test/data/db` durability/migration tests and affected feature tests.** Expected: PASS.
- [ ] **Step 6: Commit.** `git commit -m "feat: isolate corrupt library records"`.

### Task 4: Localization and centralized visible identity

**Files:**
- Create: `lib/core/config/app_identity.dart`
- Create: `l10n.yaml`
- Create: `lib/l10n/app_en.arb`
- Create: `lib/l10n/l10n.dart`
- Modify: `pubspec.yaml`
- Modify: `lib/app.dart`
- Modify: `lib/bootstrap.dart`
- Modify: `lib/features/shell/presentation/app_shell.dart`
- Modify: `lib/features/shell/presentation/studio_page.dart`
- Modify: `lib/features/onboarding/presentation/onboarding_screen.dart`
- Modify: `lib/features/settings/presentation/settings_sheet.dart`
- Test: `test/l10n/localization_contract_test.dart`
- Modify test: `test/widget_test.dart`
- Modify test: `test/features/onboarding/onboarding_screen_test.dart`
- Modify test: `test/features/settings/onboarding_settings_integration_test.dart`
- Modify test: `test/features/settings/settings_modal_contrast_test.dart`

**Interfaces:**
- Produces:
  ```dart
  abstract final class AppIdentity { static const displayName = 'TintAtlas'; static const storeTitle = 'TintAtlas: Room Visualizer'; }
  extension AppLocalizationsContext on BuildContext { AppLocalizations get l10n; }
  ```
- Add `flutter_localizations` SDK dependency, `intl`, `flutter.generate: true`, delegates, `supportedLocales`, and English ARB descriptions/placeholders.

- [ ] **Step 1: Write RED tests.** Assert English identity/copy resolves through `AppLocalizations`, an RTL locale wrapper mirrors directional layout, no touched widget contains the old visible label, and generated locale delegates mount.
- [ ] **Step 2: Run `flutter gen-l10n` and the test.** Expected: test FAIL before integration.
- [ ] **Step 3: Implement identity/l10n and migrate only bootstrap, shell, onboarding, and settings copy.** Later feature plans own their route strings; never edit generated Dart output.
- [ ] **Step 4: Run onboarding/settings/widget suites at 100% and 200% text, then `flutter analyze`.** Expected: new paths clean; pre-existing baseline remains separately recorded until Task 10.
- [ ] **Step 5: Commit.** `git commit -m "feat: establish TintAtlas localization"`.

### Task 5: Remove the global Room-model startup gate

**Files:**
- Modify: `lib/bootstrap.dart:11-170`
- Modify: `lib/main.dart:25` only if constructor name changes; preserve lines 28–33 exactly until a separately reviewed cleanup
- Modify: `test/bootstrap_test.dart`

**Interfaces:**
- `ColorLabBootstrap.build()` mounts `ColorLabApp` immediately; Room model ownership moves to the Real-room plan.
- No app-start provider reads `RoomModelStore` or performs network/model allocation.

- [ ] **Step 1: Replace bootstrap expectations with RED tests.** With model store throwing/offline, assert Home/router appears, no model `prepare()` call occurs, and Learn/Games/illustrated routes are reachable.
- [ ] **Step 2: Run `flutter test test/bootstrap_test.dart`.** Expected: FAIL because startup currently blocks.
- [ ] **Step 3: Delete `_RoomModelSetupScreen` and startup watch from bootstrap.** Retain theme/preference startup behavior in `ColorLabApp`.
- [ ] **Step 4: Run bootstrap, onboarding, picker acquisition, and Room-model-store tests.** Expected: PASS; no model download before a real-room action.
- [ ] **Step 5: Commit.** `git commit -m "fix: defer room models to Room Studio"`.

### Task 6: Adaptive layout primitives

**Files:**
- Create: `lib/core/layout/window_size_class.dart`
- Create: `lib/core/layout/adaptive_page.dart`
- Create: `lib/core/layout/adaptive_app_shell.dart`
- Create: `test/support/responsive_test_matrix.dart`
- Test: `test/core/layout/window_size_class_test.dart`
- Test: `test/core/layout/adaptive_app_shell_test.dart`
- Modify: `lib/core/theme/tokens.dart`
- Modify: `lib/core/theme/app_theme.dart`
- Modify: `lib/core/theme/app_colors.dart`
- Modify: `lib/core/widgets/structure.dart`
- Modify: `lib/features/shell/presentation/studio_page.dart`

**Interfaces:**
- Produces:
  ```dart
  enum WindowSizeClass { compact, medium, expanded, large }
  WindowSizeClass windowSizeClassFor(double logicalWidth);
  final class AdaptivePage extends StatelessWidget { const AdaptivePage({required Widget child, Widget? inspector, double maxContentWidth = 1200, ...}); }
  final class AdaptiveAppShell extends StatelessWidget { const AdaptiveAppShell({required StatefulNavigationShell navigationShell, required List<AppDestinationSpec> destinations, ...}); }
  ```

- [ ] **Step 1: Write exact boundary and widget RED tests.** Assert widths 599/600/839/840/1199/1200, compact bottom navigation, medium+ rail, 48dp targets, preserved branch state, SafeArea/keyboard inset, reduced motion, and no overflow at 320×568, 568×320, 800×1280, 1280×800 with 200% text.
- [ ] **Step 2: Run the two focused tests.** Expected: FAIL because primitives do not exist.
- [ ] **Step 3: Implement constraints-based primitives and semantic theme states.** Never branch on a device model; keep editor canvases flexible and page content scrollable.
- [ ] **Step 4: Migrate `StudioPage` and shared empty/loading/error components.** Do not bulk-edit feature screens yet.
- [ ] **Step 5: Run focused tests, shared-widget/theme tests, format, and analyze.** Expected: PASS.
- [ ] **Step 6: Commit.** `git commit -m "feat: add adaptive TintAtlas layout primitives"`.

### Task 7: Four-root router, Home, and My Work

**Files:**
- Create: `lib/features/home/presentation/home_screen.dart`
- Create: `lib/features/my_work/presentation/my_work_screen.dart`
- Create: `lib/features/learning/presentation/learn_screen.dart` (initial tool hub; Learning plan expands it)
- Modify: `lib/features/room_studio/presentation/room_screen.dart`
- Modify: `lib/features/shell/presentation/app_shell.dart`
- Modify: `lib/routing/app_router.dart`
- Test: `test/features/home/home_screen_test.dart`
- Test: `test/features/my_work/my_work_screen_test.dart`
- Test: `test/routing/app_router_test.dart`
- Modify: `test/widget_test.dart`
- Modify: `test/features/picker/capture_integration_test.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_navigation_test.dart`
- Modify: `test/features/games/presentation/games_integration_test.dart`

**Interfaces:**
- Produces `enum AppDestination { home, rooms, learn, games }` and paths `/home`, `/rooms`, `/learn`, `/games`, `/my-work`.
- `/capture`, `/palette`, `/lab`, `/room`, and existing game/Room deep links remain valid as top-level routes or compatibility redirects; invalid typed extras render a safe recovery screen.

- [ ] **Step 1: Write RED route/shell tests.** Assert `/home` initial location after onboarding, four root destinations, tab stack restoration, legacy route compatibility, Back/predictive Back behavior, invalid/deep-link recovery, and My Work not appearing as a compact fifth tab.
- [ ] **Step 2: Write Home/My Work RED tests.** Home contains sample room, Continue placeholder, Rooms/Learn/Games/My Work cards; My Work shows existing colors/palettes/illustrated designs and isolated error/empty states.
- [ ] **Step 3: Run focused route/home tests.** Expected: FAIL against the five-tab shell.
- [ ] **Step 4: Implement routes and adaptive shell.** Assign stable navigator keys/restoration IDs and make `/room` redirect to `/rooms` without loops.
- [ ] **Step 5: Implement Home and initial My Work aggregate.** Future project/learning/coloring sections plug into this screen without owning a root tab.
- [ ] **Step 6: Run `test/widget_test.dart`, router, Home/My Work, picker, Room navigation, and game integration tests at compact/expanded widths.** Expected: PASS.
- [ ] **Step 7: Commit.** `git commit -m "feat: add room-first adaptive navigation"`.

### Task 8: Preferences v2, onboarding, privacy, and data controls

**Files:**
- Modify: `lib/features/settings/domain/app_preferences.dart`
- Modify: `lib/data/db/hive_app_preferences_repository.dart`
- Modify: `lib/features/settings/application/app_preferences_providers.dart`
- Modify: `lib/features/settings/presentation/settings_sheet.dart`
- Create: `lib/features/settings/presentation/privacy_screen.dart`
- Create: `lib/features/settings/presentation/data_management_screen.dart`
- Create: `lib/features/settings/presentation/model_storage_screen.dart`
- Create: `lib/data/storage/local_data_manager.dart`
- Modify: `lib/features/onboarding/presentation/onboarding_screen.dart`
- Modify test: `test/features/settings/domain/app_preferences_test.dart`
- Modify test: `test/data/db/hive_app_preferences_repository_test.dart`
- Modify test: `test/features/settings/application/app_preferences_providers_test.dart`
- Modify test: `test/features/settings/onboarding_settings_integration_test.dart`
- Modify test: `test/features/settings/preferences_disk_restart_test.dart`
- Modify test: `test/features/settings/settings_modal_contrast_test.dart`
- Modify test: `test/features/onboarding/onboarding_screen_test.dart`
- Create: `test/features/settings/data_management_screen_test.dart`
- Create: `test/features/settings/privacy_screen_test.dart`
- Create: `test/features/settings/model_storage_screen_test.dart`
- Create: `test/data/storage/local_data_manager_test.dart`
- Create: `test/features/games/game_profile_shared_library_isolation_test.dart`

**Interfaces:**
- Produces:
  ```dart
  enum MotionPreference { system, reduce }
  final class AppPreferences { ThemeMode themeMode; bool onboardingCompleted; MotionPreference motion; bool highContrast; bool alwaysShowColorLabels; }
  final class DataDeletionPreview { Set<LocalDataCategory> categories; int recordCount; int estimatedBytes; }
  abstract interface class LocalDataManager { Future<DataDeletionPreview> preview(Set<LocalDataCategory> categories); Future<void> delete(Set<LocalDataCategory> categories); }
  ```

- [ ] **Step 1: Write v1→v2 and deletion RED tests.** Missing new fields default safely; unknown versions preserve the record; deleting a game profile changes no shared box; category deletion requires an exact preview and never includes user exports implicitly.
- [ ] **Step 2: Run the focused preferences/storage tests.** Expected: FAIL before schema v2.
- [ ] **Step 3: Implement v2 migration and controls.** Onboarding explains Rooms/Learn/Games, local photo behavior, optional permission/model download, Skip and replay; settings expose appearance/accessibility/privacy/licenses/model/data entries.
- [ ] **Step 4: Add double-confirmed category deletion with last-valid-state/error behavior.** Never auto-reset on a failed delete.
- [ ] **Step 5: Run settings/onboarding/durability/profile-isolation tests at 200% text and dark/high-contrast themes.** Expected: PASS.
- [ ] **Step 6: Commit.** `git commit -m "feat: add durable privacy and data controls"`.

### Task 9: Platform identity and original brand assets

**Files:**
- Create: `assets/branding/tintatlas_icon_1024.png`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Move: `android/app/src/main/kotlin/com/example/color_lab/MainActivity.kt` → `android/app/src/main/kotlin/com/roomvisualizer/tintatlas/MainActivity.kt`
- Modify: `android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- Modify: `android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- Modify: `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- Modify: `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- Modify: `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- Create: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- Create: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`
- Create: `android/app/src/main/res/drawable/ic_launcher_foreground.xml`
- Create: `android/app/src/main/res/values/colors.xml`
- Modify: `android/app/src/main/res/drawable/launch_background.xml`
- Modify: `android/app/src/main/res/drawable-v21/launch_background.xml`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Modify: `ios/Runner/Info.plist`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png`
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png`
- Modify: `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`
- Modify: `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png`
- Modify: `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png`
- Modify: `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png`
- Modify: `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- Modify: `pubspec.yaml` description only; keep `name: color_lab`
- Test: `test/tool/release_identity_test.dart`

**Interfaces:**
- Consumes: `docs/release/identity-decision.md` with `newListing: true` and an approved original icon source.
- Produces: user-visible `TintAtlas`, store title metadata source, and `com.roomvisualizer.tintatlas` for a new listing.

- [ ] **Step 1: Enforce the gate.** If `newListing` is not explicitly true, stop this task and write an identity amendment; do not guess or change IDs.
- [ ] **Step 2: Write a RED repository identity test.** It rejects `com.example`, old display names in production platform metadata, debug release signing, absent icon sizes, or an accidental Dart-package rename.
- [ ] **Step 3: Install the approved original icon/splash set and change platform identity.** Move `MainActivity.kt` to the matching lowercase package path; update RunnerTests bundle IDs consistently.
- [ ] **Step 4: Run identity test, `plutil -lint ios/Runner/Info.plist`, Android manifest inspection, debug Android build, and no-codesign iOS build when its platform gate is active.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: apply TintAtlas platform identity"`.

### Task 10: Stabilize verification and close the foundation milestone

**Files:**
- Create: `.github/workflows/flutter_verify.yml`
- Modify: `docs/release/verification-ledger.md`
- Modify: `lib/features/games/presentation/fruit_pop_screen.dart:1048`
- Modify only if named by Task 1's `baselineFailureFiles`: the exact product/test paths recorded in `docs/release/verification-ledger.md`; any additional path requires a ledger amendment before editing

**Interfaces:**
- Produces repeatable format, analyze, test, localization-generation, and debug-build commands; CI never injects signing or production ad secrets.

- [ ] **Step 1: Reproduce and classify all 38 baseline test failures.** Fix code when behavior violates existing accepted contracts; update a test only when the approved spec deliberately changed that behavior, documenting the reason.
- [ ] **Step 2: Add CI after local commands are stable.** Run `flutter pub get`, `flutter gen-l10n`, format check, analyze, full tests, and Android debug build using the pinned repository SDK strategy.
- [ ] **Step 3: Run the entire foundation matrix locally.** `flutter gen-l10n`, `dart format --output=none --set-exit-if-changed lib test tool`, `flutter analyze`, `flutter test --reporter expanded`, `flutter build apk --debug`.
- [ ] **Step 4: Update the ledger with exact exit codes/counts and obtain a fresh read-only review.** No unexplained analyzer issue or test failure may remain.
- [ ] **Step 5: Commit.** `git commit -m "test: establish TintAtlas foundation gate"`.

## Exit Gate

A fresh offline install reaches Home, sample/illustrated Rooms, Learn, and Games without a Room model or permission prompt; existing local records remain visible; all four destinations adapt across the required widths; touched copy is localized; platform identity is gated correctly; and the full foundation verification is clean.
