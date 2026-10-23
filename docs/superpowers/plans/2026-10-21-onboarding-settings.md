# Onboarding and Persistent Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish Phase1 with a skippable three-slide first-run tour and durable theme preferences.

**Architecture:** Dedicated Hive preferences repository, serialized AsyncNotifier updates, stable router startup/onboarding guard, isolated tour widget, and durable-save Appearance sheet. Reuse existing theme/history/native boundaries.

**Tech Stack:** Existing Flutter/Riverpod/go_router/Hive/path_provider only.

**Spec:** `docs/superpowers/specs/2026-10-21-onboarding-settings-design.md` and step5/Onboarding/Settings in `/Users/jamirulislam/Downloads/Color Lab App Build Spec for ChatGPT.md`.

## Global Constraints

- App UI is English only. Android first (min SDK24), iOS-ready code. All processing is on-device and offline.
- Onboarding:3 short slides plus permission rationale, skippable. No permission prompt until the relevant feature is explicitly opened.
- Theme: System/Light/Dark, defaults to System, persisted. Use existing tokens/shared widgets,48dp targets,360px width/2x text and reduced motion.
- No new dependencies, no color-history mutations or automatic corrupt-storage clearing. Work in the existing authorized folder; there is no Git repository, so no commits/worktree creation.

## Review Focus

- Concurrent theme/completion writes must merge against the last durable record, not overwrite a stale snapshot (Task1 queue/race test).
- A failed flush must not publish a theme or completed tour, even if Hive updated its memory cache (Task1 barrier test; Task3 failed-finish UI test).
- Returning-user saved theme must be selected before main content, without recreating the router or losing Lab state (Task3 startup/state-retention tests).
- Background completion/disposal and failed factory retries must not leak a box or update disposed providers (Task1 controlled factory tests).
- First-run/replay transitions must not request permissions, enter guarded camera routes prematurely, or reset saved colors (Tasks2/3 gesture/navigation tests).

### Task 1: Durable preferences and state — delegated

**Files:** Create `lib/features/settings/domain/{app_preferences,app_preferences_repository}.dart`, `lib/data/db/hive_app_preferences_repository.dart`, `lib/features/settings/application/app_preferences_providers.dart`; modify `lib/features/settings/application/theme_mode_provider.dart`. Tests under `test/features/settings/{domain,application}/` and `test/data/db/hive_app_preferences*_test.dart`.

**Interfaces:**

- `AppPreferences({ThemeMode themeMode = ThemeMode.system, bool onboardingCompleted = false})`, final fields, `copyWith`, equality, `toMap()`, `factory AppPreferences.fromMap(Map<dynamic,dynamic>)`. Version1 map keys exactly `schemaVersion`, `themeMode`, `onboardingCompleted`; names persist as strings. Unknown/invalid theme ->system, invalid completion ->false, unsupported schema ->safe error.
- `abstract interface class AppPreferencesRepository { Future<AppPreferences> load(); Future<void> save(AppPreferences preferences); Future<void> close(); }` and `const PreferencesStorageException()`.
- `HiveAppPreferencesRepository.open({required String directory, String boxName = 'app_preferences_v1'})`; `.fromBox({required Box<dynamic> box})` owns the box. One record key `preferences`. Empty ->defaults, unsupported/malformed map preserved with typed errors. Queue read/write/close, track pending flush, isolate Hive registry.
- `preferencesStorageDirectoryProvider: FutureProvider<Directory>`, `appPreferencesRepositoryProvider: FutureProvider<AppPreferencesRepository>`, `appPreferencesProvider: AsyncNotifierProvider<AppPreferencesController,AppPreferences>`.
- Controller methods `Future<void> setThemeMode(ThemeMode mode)`, `Future<void> completeOnboarding()`, `void retry()`. Serialize mutations, read durable current repository snapshot before applying each edit, save/flush then publish. Keep last good state on mutation failure, reject late edits after disposal.
- Preserve `themeModeProvider: NotifierProvider<ThemeModeController,ThemeMode>` API; `.build` watches durable preference mode or System while loading; `Future<void> setMode(ThemeMode mode)` delegates to preferences controller (no independent temporary state).

- [x] Write model/disk/provider tests first: defaults, fields, unknown theme, unsupported schema, reopen true/dark, independent dirs, failed flush blocks load/no-op, queued edits preserve dark+completed, close retry and late init disposal/factory retry.
- [x] Observe expected missing-feature RED, implement only owned files, run scoped GREEN and analysis. Root owns full-suite integration; report any full-suite failures from known missing root test overrides rather than changing root files.
- [x] Write report `docs/superpowers/plans/preferences-storage-report.md` with exact APIs, red/green evidence, failures/limits and changed files. No subagents or Git initialization.

### Task 2: Three-slide onboarding presentation — delegated

**Files:** Create `lib/features/onboarding/presentation/onboarding_screen.dart` and optional `onboarding_art.dart`; tests `test/features/onboarding/onboarding_screen_test.dart`.

**Interfaces:** `OnboardingScreen({super.key, required Future<void> Function() onFinish, bool isReplay = false})`. It owns PageController/page index/busy/error only; no providers/native plugins. Root's callback persists completion or closes replay. Buttons call callback once per attempt and await it; while pending disable page changes/finish/skip and back via PopScope as appropriate. Show safe inline error on failure and allow retry. Do not pop automatically (router/caller owns finish behavior).

- [x] Write tests first for 3 slides, Next/Back/swipe, Skip from any page, final Get started, callback only once while busy, failure retry, disposal during await,360x800 at2x text, portrait/short landscape and reduced motion.
- [x] Implement using bundled typography/tokens/shared buttons, scrollable page content, static procedural illustrations, semantic step labels and48dp controls. Copy intent: discover camera/photo shades; keep a personal offline library; privacy and explicit permission rationale. No raster/network assets or unimplemented Room claims. Replay may label exit `Done` on final page; first run `Get started`.
- [x] Scoped tests/analysis and report `docs/superpowers/plans/onboarding-ui-report.md`. No subagents or edits to routing/settings/root tests.

### Task 3: Startup guard, Appearance save/replay and delivery — root

**Files:** Modify `lib/app.dart`, `lib/routing/app_router.dart`, `lib/features/shell/presentation/studio_page.dart`; create `lib/features/settings/presentation/{preferences_startup_screen,settings_sheet}.dart`, root onboarding/settings integration tests and `test/support/in_memory_app_preferences_repository.dart`. Update existing full-app tests, `tool/render_previews.dart`, README and ledger.

- [x] Write first-run/returning-user/load-error/failed-finish/replay/persisted-theme tests. Override repository boundary in prior full-app tests (completed tour fixture), retaining real application/provider/router behavior; observe RED.
- [x] Register `/startup`, `/onboarding`, `/welcome` replay routes outside tabs. Keep one GoRouter instance and listen to preferences to refresh redirects. Loading/error ->startup, incomplete ->onboarding, completed onboarding/startup ->capture; normal completed routes unchanged. Startup shows progress or friendly Retry using controller. Never construct camera/photo entry until onboarding resolves.
- [x] Appearance sheet retains existing controls/About but awaits theme writes, disables competing edits, shows inline save errors, keeps committed selection and offers replay. Pop the settings sheet before pushing `/welcome`; replay returns to previous tab with theme/history untouched. Keep existing appearance tooltip for compatibility.
- [x] Verify real-file preferences close/reopen through fresh ProviderContainers plus first/returning app flows, saved-dark initial main frame, root camera guard, no permission requests, retained Lab tab state, replay return,360px/2x and reduced motion. Obtain scoped task review and broad final independent review; fix concrete findings.
- [x] Render light/dark onboarding/settings previews, run full `flutter test`, `flutter analyze`, format check, debug APK and native permission sanity checks. Do not claim physical-device validation from fixtures.
- [x] Update README with changed-file map, no pubspec/platform additions, behavior and exact verified results. Create/validate `dist/color-lab-onboarding-settings-2026-10-21.zip`, preserving prior archives and app data. No Git branch/integration operations apply.
