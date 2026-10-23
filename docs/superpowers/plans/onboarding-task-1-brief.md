### Task 1: Durable preferences and state — delegated

**Files:** Create `lib/features/settings/domain/{app_preferences,app_preferences_repository}.dart`, `lib/data/db/hive_app_preferences_repository.dart`, `lib/features/settings/application/app_preferences_providers.dart`; modify `lib/features/settings/application/theme_mode_provider.dart`. Tests under `test/features/settings/{domain,application}/` and `test/data/db/hive_app_preferences*_test.dart`.

**Interfaces:**

- `AppPreferences({ThemeMode themeMode = ThemeMode.system, bool onboardingCompleted = false})`, final fields, `copyWith`, equality, `toMap()`, `factory AppPreferences.fromMap(Map<dynamic,dynamic>)`. Version1 map keys exactly `schemaVersion`, `themeMode`, `onboardingCompleted`; names persist as strings. Unknown/invalid theme ->system, invalid completion ->false, unsupported schema ->safe error.
- `abstract interface class AppPreferencesRepository { Future<AppPreferences> load(); Future<void> save(AppPreferences preferences); Future<void> close(); }` and `const PreferencesStorageException()`.
- `HiveAppPreferencesRepository.open({required String directory, String boxName = 'app_preferences_v1'})`; `.fromBox({required Box<dynamic> box})` owns the box. One record key `preferences`. Empty ->defaults, unsupported/malformed map preserved with typed errors. Queue read/write/close, track pending flush, isolate Hive registry.
- `preferencesStorageDirectoryProvider: FutureProvider<Directory>`, `appPreferencesRepositoryProvider: FutureProvider<AppPreferencesRepository>`, `appPreferencesProvider: AsyncNotifierProvider<AppPreferencesController,AppPreferences>`.
- Controller methods `Future<void> setThemeMode(ThemeMode mode)`, `Future<void> completeOnboarding()`, `void retry()`. Serialize mutations, read durable current repository snapshot before applying each edit, save/flush then publish. Keep last good state on mutation failure, reject late edits after disposal.
- Preserve `themeModeProvider: NotifierProvider<ThemeModeController,ThemeMode>` API; `.build` watches durable preference mode or System while loading; `Future<void> setMode(ThemeMode mode)` delegates to preferences controller (no independent temporary state).

- [ ] Write model/disk/provider tests first: defaults, fields, unknown theme, unsupported schema, reopen true/dark, independent dirs, failed flush blocks load/no-op, queued edits preserve dark+completed, close retry and late init disposal/factory retry.
- [ ] Observe expected missing-feature RED, implement only owned files, run scoped GREEN and analysis. Root owns full-suite integration; report any full-suite failures from known missing root test overrides rather than changing root files.
- [ ] Write report `docs/superpowers/plans/preferences-storage-report.md` with exact APIs, red/green evidence, failures/limits and changed files. No subagents or Git initialization.

