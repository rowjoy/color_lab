# Task 4 — Harmonies editor and collection integration

Date: 2026-10-21. Root owns routing, editor/dialog/library, integration tests,
README and delivery. Tasks 1–3 own the generator/controller, storage and wheel;
the preview worker owns only the renderer and its report.

## Implemented

- Guarded root `/harmonies` and `/palettes` routes; Lab entry and a third
  Palette → Palettes view preserve existing Saved/Studio keys and defaults.
- Independent retained base/mode, six mode chips, actual generated colors,
  semantic read-only wheel and real swatch → common details → Room actions.
- Existing manual/saved-color picker returns a shade without changing other
  drafts or history filters. Cancellation leaves the original base intact.
- Named save captures the original base/mode/colors, validates a nonblank
  80-grapheme name, waits for durable publication and exposes friendly retry.
  Status is derived from both stored identity and exact snapshot, never an
  async stale saved flag. Different snapshots keep their original data and
  show an explicit warning rather than claiming success.
- Collection cards use stored colors, not regeneration, and expose per-shade
  details, Open harmony and confirmed palette-only delete. Failed deletes
  retain the card and offer retry. Opening a saved palette never edits storage.
- Common details use a private destination enum. Exact shade selection and
  typed awaited routes keep camera sampling paused until returning. Same-route
  updates do not stack. A library navigation callback returns both card and
  swatch-detail entries to the existing editor when appropriate.

## TDD / test-harness investigation

The initial integration test was run before the screen existed. Expected
missing-feature RED: the import of `harmonies_screen.dart` and `HarmoniesScreen`
were undefined (`/private/tmp/color-lab-harmonies-ui-red.log`, exit 1).

The first implemented run exposed test-harness errors, not established product
defects: it read a lazy history provider before awaiting initialization, used a
tooltip for a camera control that is actually a text button, and awaited native
file IO in widget fake time. The existing Formula camera test supplied the
correct real control pattern. Systematic debugging traced native save → durable
repository → controller reload across real IO and fake widget microtasks. The
restart test now creates/opens/reads/closes actual files with `runAsync` and
advances both zones until a bounded, observed committed-state condition. It
does not settle an indefinitely animated pending spinner or use a fixed wait
as proof. Temporary diagnostic logging was removed.

All original 16 integration tests then passed. The scoped UI review found two
real defects; tests were added and run before fixes:

1. Editor → library → stored swatch → Explore harmonies grew editor/library
   routes. The two-trip regression failed because one Back still showed the
   library. A shared navigation policy now returns to the existing editor.
2. Delete confirmation labels inherited insufficient-contrast primary purple.
   Tests inspect actual `RenderParagraph` and opaque Material background colors
   in both themes. RED ratios were 3.9556:1 light and 2.9673:1 dark. Dialog
   buttons now use existing `textPrimary` tokens and minimum 48×48 targets.

Exact RED/GREEN logs: `/private/tmp/color-lab-harmonies-review-{red,green}.log`.
The same three regressions passed after the minimal fixes. Added planned
coverage for saved-base selection/filter isolation, failed-delete retry and
the differing-snapshot warning without changing implementation expectations.

## Focused verification

```text
flutter test --no-pub test/features/harmonies/presentation/harmonies_integration_test.dart --reporter expanded
00:04 +22: All tests passed!
exit 0

flutter analyze --no-pub
No issues found! (ran in 2.3s)
exit 0

dart format --output=none --set-exit-if-changed lib test tool
Formatted 126 files (0 changed) in 0.77 seconds.
exit 0
```

The final full suite passed481 tests; refreshed previews passed both theme tests
and generated68 PNGs; debug APK build exited0. Evidence and archive validation are
tracked in the module ledger rather than inferred from focused results. All four
scoped reviews, the UI fix re-review and whole-module final review approved the
module; see the separate review reports.

## Limits

Native device camera, iOS execution, predictive Back and screen-reader behavior
have not been exercised for this module. Widget previews are synthetic layout
evidence, while repository/provider and UI restart tests use real temporary
Hive files. No user data, platform configuration, dependencies, existing
history/preferences schema, earlier archives or unrelated modules were changed.
