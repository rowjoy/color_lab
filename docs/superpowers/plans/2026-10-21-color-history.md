# Color History Implementation Plan

> For agentic workers: use the subagent-driven-development workflow with disjoint file ownership, test-first behavior, and an integrated final review.

**Goal:** Deliver the next requested module: durable saved colors with favorites, deletion, search, and a favorites filter.

**Authority:** Phase 1 / local database plus history feature in the supplied Color Lab build spec. Foundation is already complete. The user said “next”, authorizing this next module and its normal integration.

**Design:** Use the document's simpler Hive option. Store versioned plain maps in an app-private documents-directory box; no generated adapters or runtime network. Keep an immutable domain model and a repository interface separate from Hive. Riverpod exposes a loaded immutable list and serializes edits, while search/filter remain transient view state. Put real saved colors first in Palette and keep curated studies explicitly separate as inspiration. Add Save and Favorite to every existing color detail entry point.

## Decisions and constraints

- `SavedColor` has id, normalized uppercase hex, nonempty name, isFavorite, UTC createdAt, and `ColorSource source`.
- `ColorSource` values: manual, studio, lab, room, camera, gallery. Future capture sources are represented without adding camera features now.
- ID is the normalized HEX, so the same opaque RGB has exactly one saved record. Repeat save returns existing metadata unchanged, including favorite and original timestamp.
- Newest first; deterministic id ordering breaks equal timestamps. Reads and results are immutable.
- Storage failures never clear/recreate the database automatically. Unreadable records raise a storage error while preserving stored bytes; UI offers a friendly Retry state.
- Failed mutations preserve the last successful list. Mutations serialize, await durable writes, and only then publish new state.
- History search matches name and HEX without case sensitivity and accepts a hashless HEX fragment. Favorites filtering combines with search. No-result and genuinely empty-library states are distinct.
- Delete requires confirmation. No automatic deletion or bulk-clear action.
- Existing color math, curated palettes, route state, light/dark tokens, reduced-motion handling, 48dp targets, 360px / 2x text support remain intact.
- No Git repository is present; implement in the authorized workspace without fabricating commits.

## Shared interfaces

`lib/features/history/domain/saved_color.dart` exports:

- `enum ColorSource { manual, studio, lab, room, camera, gallery }`
- immutable `SavedColor({required String id, required String hex, required String name, required bool isFavorite, required DateTime createdAt, required ColorSource source})`, value equality, `copyWith`, map serialization with schema version 1.

`lib/features/history/domain/color_history_repository.dart` exports:

- `abstract interface class ColorHistoryRepository`
- `Future<List<SavedColor>> load()`
- `Future<SavedColor> save({required RgbColor color, required String name, required ColorSource source})`
- `Future<void> setFavorite(String id, bool isFavorite)`
- `Future<void> delete(String id)` (missing id is an idempotent no-op)
- `Future<void> close()`

`HiveColorHistoryRepository.open({required String directory, String boxName = 'color_history_v1', DateTime Function()? clock})` in `lib/data/db/hive_color_history_repository.dart` produces a durable implementation. The caller owns the directory and repository lifetime; box files remain on close.

`lib/features/history/application/history_providers.dart` exports:

- `colorHistoryRepositoryProvider`: `FutureProvider<ColorHistoryRepository>` with path_provider documents directory, safe disposal, and an override boundary for tests.
- `colorHistoryProvider`: `AsyncNotifierProvider<ColorHistoryController, List<SavedColor>>`.
- Controller methods `saveColor(RgbColor color, {required String name, ColorSource source = ColorSource.manual})`, `setFavorite(String id, bool isFavorite)`, `deleteColor(String id)` return Futures; `saveColor` returns `SavedColor`.
- `historyFilterProvider`: `NotifierProvider<HistoryFilterController, HistoryFilter>`; `HistoryFilter` is `({String query, bool favoritesOnly})`; methods `setQuery(String)`, `toggleFavorites()`, `clear()`.
- `filteredColorsProvider`: `Provider<AsyncValue<List<SavedColor>>>`.

## Task 1: Durable domain and repository

**Owns:** `lib/features/history/domain/`, `lib/data/db/`, `test/features/history/domain/`, `test/data/db/`.

- [x] Write and run failing tests for immutable serialization, validation, save/reopen persistence, favorite/reopen, delete/reopen, duplicate saves preserving metadata, newest-first sorting, concurrent duplicate operations, missing-id operations, and unreadable records preserving stored data.
- [x] Implement the agreed model/interface and Hive repository. Use plain maps with validated version/schema; await writes and serialize concurrent repository edits. Do not mutate caller data or expose mutable collections.
- [x] Run scoped tests and analysis; document exact APIs and results in `docs/superpowers/plans/history-storage-report.md`.

## Task 2: Saved-library UI

**Owns:** `lib/features/history/presentation/color_history_section.dart`, supporting history tile files, `lib/features/palette/presentation/palette_screen.dart`, and `test/features/history/presentation/`. Root separately owns `save_color_actions.dart`.

- [x] Write failing widget tests with an injected repository for loading/error/retry, empty library, displayed saved records, search, combined favorites, favorite updates, delete cancellation/confirmation, and 360px / 2x text layout.
- [x] Implement `ColorHistorySection` against the shared providers. The UI has a named search field, a clear-search affordance, an accessible favorites filter, count, loading/empty/no-match/error states, and accessible per-color actions. Display error copy without exception contents.
- [x] Integrate Palette with Saved / Studio views; default Saved, preserve original curated inspiration under Studio. Studio colors open details with source studio; saved records use their original source. Empty-library action opens manual color entry.
- [x] Run scoped tests and analysis; document results in `docs/superpowers/plans/history-ui-report.md`.

## Task 3: Application and detail actions

**Owns:** providers/controller, controller tests, root test support, existing app tests, `save_color_actions.dart`, color detail integrations, README, pubspec/lock, delivery plan/ZIP.

- [x] Add only hive/path_provider dependencies. Baseline the existing suite.
- [x] Write failing controller tests for loaded state, persistence errors, sequential/concurrent writes, retained state on failure, combined filters, and retry/lifetime handling.
- [x] Implement providers with overridable storage, serialized mutation state publication, and explicit retry behavior. Keep platform directory access at the repository factory boundary.
- [x] Write failing save-action integration tests; implement saving/loading/already-saved/favorite/error/retry behavior in color details. Propagate manual/studio/lab/room sources from existing entry points.
- [x] Update preexisting app/preview tests to inject test-local storage instead of calling a platform plugin. Exercise the actual Hive repository in separate filesystem tests.
- [x] Run formatting, full suite, static analysis, Android debug build, and real-font previews. Obtain independent review and address required findings.
- [x] Update README with module scope, duplicate/delete/error policies, exact additions and commands; package a new source ZIP without modifying the Foundation archive.

## Review focus

- A reopened box must retain favorite/deletion/creation date, not just a process-local cache (Task 1).
- Two quickly queued saves must not lose a favorite or create duplicates (Tasks 1 and 3).
- Write/read failure must not silently blank or erase a previously loaded library (Tasks 1 and 3).
- Search and favorite filters must work together and clear correctly (Tasks 2 and 3).
- Sheets/buttons must remain usable during asynchronous work, under large text, and after their widget is dismissed (Tasks 2 and 3).

