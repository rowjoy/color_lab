# Saved-library UI report

## Implementation

- `ColorHistorySection` consumes the shared repository-backed Riverpod providers, displays named search, clear search, favorite filtering, visible result counts, and distinct loading, empty library, no-match, and generic error states.
- Favorite and delete actions await controller mutations, disable both row actions during a pending write, preserve loaded content on failure, and show a friendly snackbar. Delete requires a scrollable confirmation dialog. Completion handlers check widget lifetime before updating the view.
- Retry calls `ColorHistoryController.retry()`, the root-owned extension that reuses an already-open repository after load failure and retries the factory only when opening failed.
- Palette defaults to Saved, with separate Saved / Studio choices. Studio retains all three original curated studies. The existing `StudioPage(name: 'Palette')` keeps the `screen-Palette` navigation key.
- Saved details propagate the stored `ColorSource`; curated Studio details pass `ColorSource.studio`. Both the empty library and populated library offer manual color entry.
- Search text follows external filter clearing, so no-match recovery clears both the provider and visible input. Actions have accessible labels and 48dp targets; layouts use wrapping controls and flexible text.

## Shared interfaces used

- `colorHistoryRepositoryProvider`, `colorHistoryProvider`, `filteredColorsProvider`, `historyFilterProvider` from `history_providers.dart`.
- Controller mutations: `setFavorite(id, bool)`, `deleteColor(id)`, `retry()`.
- Filter mutations: `setQuery`, `toggleFavorites`, `clear`.
- `SavedColor`, `ColorSource`, `showColorDetails(context, rgb, source: ...)`, and `showColorEntry(context)`.
- Test repository: root-owned `InMemoryColorHistoryRepository(colors: ...)`, `failLoad`, `failWrites`, `writeGate`.

## Verification

Thirteen widget tests were written before UI implementation. The initial test invocation failed compilation because the planned feature files and shared interfaces did not yet exist. A subsequent invocation reached only the remaining source-argument integration gap while root was implementing color details.

- `flutter test test/features/history/presentation/color_history_section_test.dart`: **13 passed**.
- `flutter analyze lib/features/history/presentation/color_history_section.dart lib/features/palette/presentation/palette_screen.dart test/features/history/presentation/color_history_section_test.dart`: **No issues found**.
- `dart format` on those three files: **0 changes**, exit 0.
- Full `flutter test`: **84 passed, 2 failed** during concurrent root integration. Both failures belong to `test/features/history/save_color_actions_test.dart`: `saves a color with its source and persists favorite changes` and `failed save shows friendly feedback and can be retried`; each timed out in `pumpAndSettle`. Root was informed. All saved-library UI tests passed within that full run.

The UI harness overrides `colorNamerProvider` with a deterministic real `ColorNamer` fixture, because bundled naming calls `compute` and unsaved-detail loading otherwise waits on an isolate while the widget test advances its fake clock. Bundled asset naming has separate tests. This removed the initial Studio-detail timeout without changing production code.

Coverage includes loading, empty-library entry, record names/HEX/count, name and hashless-HEX search, clear search, combined favorites, no-match recovery, favorite persistence, delete cancellation/confirmation, friendly errors and retry, retained list on mutation failure, stored source propagation, pending-write disposal, default Saved/Studio separation, and 360px / 2x text with minimum action sizes.

Formatting ran successfully with `dart format` for the three owned Dart files. Flutter and Dart startup require sandbox escalation to access the SDK cache and telemetry metadata outside the writable workspace.
