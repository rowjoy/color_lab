# Preferences storage Task 1 report

Implemented the binding Task 1 brief and onboarding/settings design without new dependencies or Git operations. This task owns only the files listed below; router, Appearance UI, tour UI and integration fixtures belong to the parent task.

## Public APIs and behavior

- `AppPreferences({ThemeMode themeMode = ThemeMode.system, bool onboardingCompleted = false})` is immutable, value comparable, and has `copyWith`, `toMap`, and `AppPreferences.fromMap(Map<dynamic, dynamic>)`.
- Version 1 maps contain exactly `schemaVersion: 1`, `themeMode: 'system'|'light'|'dark'`, and `onboardingCompleted: bool`. Invalid theme and completion fields independently fall back safely. Missing/unsupported schema versions throw `const PreferencesStorageException()`.
- `AppPreferencesRepository` exposes `Future<AppPreferences> load()`, `Future<void> save(AppPreferences preferences)`, and `Future<void> close()`.
- `HiveAppPreferencesRepository.open({required String directory, String boxName = 'app_preferences_v1'})` uses an independent Hive registry and disables crash recovery. `HiveAppPreferencesRepository.fromBox({required Box<dynamic> box})` owns the supplied box. Both use the single `preferences` record.
- Empty storage returns defaults. Existing malformed/non-map/unsupported records reject both load and save without being erased. Reads, writes and close share an operation queue. Failed flushes remain a durability barrier even for reads and unchanged-value saves. Close waits for queued operations and allows explicit retry after flush or close failure.
- `preferencesStorageDirectoryProvider` is a `FutureProvider<Directory>` resolving application documents. `appPreferencesRepositoryProvider` is a `FutureProvider<AppPreferencesRepository>` storing its box under `${directory.path}/color_lab` and owning initialization/disposal. Async initialization checks disposal before opening and closes a box if disposal occurs during open.
- `appPreferencesProvider` is `AsyncNotifierProvider<AppPreferencesController, AppPreferences>`. The controller exposes `Future<void> setThemeMode(ThemeMode mode)`, `Future<void> completeOnboarding()`, and `void retry()`. Each queued edit waits for validated initial state, reloads the current durable record, applies only its own field, awaits save/flush, then publishes. Failure retains the last good snapshot and does not poison the next edit. Disposed controllers reject queued and late edits.
- The existing `themeModeProvider: NotifierProvider<ThemeModeController, ThemeMode>` remains compatible. It derives committed preferences or System during loading. `Future<void> setMode(ThemeMode mode)` delegates to the preferences controller; no independent temporary state exists.
- All three preferences async providers disable Riverpod's automatic retry so load errors become visible immediately and the product's explicit Retry action controls recovery. Retry recreates a failed factory/directory but reuses a healthy repository after read failure.

## TDD and verification

Read the TDD skill and its `writing-good-tests.md` reference before writing tests. Added all three test files before implementation and ran:

```sh
flutter test test/features/settings/domain/app_preferences_test.dart test/data/db/hive_app_preferences_repository_test.dart test/features/settings/application/app_preferences_providers_test.dart
```

RED: exit 1, all three files failed to load because the specified preference model, repository and provider APIs did not exist; old `setMode` returned void. This is missing-feature compiler RED, explicitly recorded rather than described as assertion RED.

First implementation run: 15 tests passed, then `unreadable initial state blocks writes until explicit retry` timed out after 30 seconds. Investigation of Riverpod 3.3.2 showed its default exception retry prevented the initial error future from completing promptly. The next test, `retry recreates failed factory but reuses repository after load error`, was interrupted while pending. Disabling automatic retry on the preferences async providers fixed that contract.

GREEN: the scoped command completed exit 0 with **20/20 tests passing**: 4 model, 7 real Hive storage/durability, 9 provider tests. These include actual file close/reopen, independent directories, malformed record preservation, failed flush barriers, blocked writes/load/close at injected async boundaries, close retry, concurrent theme/onboarding merge, read-before-write, last committed mode on failure, explicit load/factory/directory retry, disposal during directory lookup, and queued/late edit rejection. Test doubles replace only slow/failing repository or flush/async boundaries; real Hive boxes perform disk tests.

`dart format` ran on all eight owned Dart files. Scoped analysis initially found one redundant import and four brace infos; these were fixed. Final scoped `flutter analyze` completed exit 0 with **No issues found**.

Full `flutter test` was run while the parent/tour agents were still implementing integration: **210 passed, 22 failed**. Failures were confined to in-progress onboarding integration and tour widget tests (missing Skip/Next and not-yet-wired routes). No other agent's files were edited. The second full run, after their concurrent changes, reached **229 passed, 4 failed** (exit 1). Every remaining failure was in `test/features/onboarding/onboarding_screen_test.dart`:

- `Next, Back, and swipe move through all three tour steps`
- `reduced motion changes steps without a transition`
- `360px portrait at 2x text is usable in light`
- `360px portrait at 2x text is usable in dark`

The parent/tour agent owns those failures and final all-green integration verification.

## Changed files

- `lib/features/settings/domain/app_preferences.dart`
- `lib/features/settings/domain/app_preferences_repository.dart`
- `lib/data/db/hive_app_preferences_repository.dart`
- `lib/features/settings/application/app_preferences_providers.dart`
- `lib/features/settings/application/theme_mode_provider.dart`
- `test/features/settings/domain/app_preferences_test.dart`
- `test/data/db/hive_app_preferences_repository_test.dart`
- `test/features/settings/application/app_preferences_providers_test.dart`
- `docs/superpowers/plans/preferences-storage-report.md`

## Limits

No native device/OS durability verification is claimed. Failed flushes and close failures use injected boundaries around real disk boxes. Provider disposal during pending directory lookup and queued edits is deterministic; disposal during Hive's internal file-open interval is guarded in production but has no dedicated injected opener API. The existing Hive 2 implementation import is necessary for its isolated registry, matching the history repository's established approach. No APIs differ from the brief.
