# Harmonies Task 3 report

Completed the owned read-only procedural wheel and its widget tests on 2026-10-21.

## Files and API

- `lib/features/harmonies/presentation/harmony_wheel.dart`
- `test/features/harmonies/presentation/harmony_wheel_test.dart`
- `docs/superpowers/plans/harmonies-task-3-report.md`

Exact public API: `HarmonyWheel({super.key, required RgbColor base, required HarmonyMode mode, required List<RgbColor> colors})`, a stateless widget importing the real core types through `color_engine.dart`. The API was signaled ready to the parent before final verification. No additional public helper API is required.

No sibling, controller, persistence, routing, root, package, asset, Git, or infrastructure edits were made. No subagents or reviewers were used.

## Behavior

The painter draws an HSL sweep ring with red at the top and clockwise hue progression. Chromatic markers use the exact supplied RGB fills and their real HSL hue positions, with connecting relationships behind them. A double outline and a readable base-HEX legend identify the base.

Monochromatic shades use separate ordinal positions from darker to lighter on an inner lightness rail. This avoids hiding coincident same-hue shades and keeps very close endpoint shades visible. Their accessible HEX list retains the supplied order. Neutral shades use the lightness rail rather than treating the color model's canonical zero hue as a red-angle position. Readable text and the image description explain that neutrals have no hue. The gradient hue ring remains a reference, not a claim that neutral colors have a hue.

Chrome, outlines, text, and spacing use existing theme tokens. Actual palette colors are not recolored for either theme. The diagram scales to its parent's width, and ordinary widget text inherits text scaling. There are no animations, interactive hit targets, picker affordances, or canvas text. Parent screens retain ownership of mode controls and tappable swatches. All app chrome added here is English and works offline.

Accessibility exposes one image with its mode, base HEX, exact ordered supplied HEX shades, applicable neutral/lightness explanation, and base-outline legend. Its visible caption is excluded from duplicate semantic reading. The image has no tap action or button role.

## Test-first and RED evidence

Read the exact Task 3 brief first, then the TDD skill and its complete `writing-good-tests.md` reference. Wrote the widget tests before the wheel implementation. No fake core types or mocked painters were introduced.

Initial command:

```text
flutter test test/features/harmonies/presentation/harmony_wheel_test.dart
```

The sandbox initially prevented Flutter from updating its SDK `engine.stamp`; rerunning with the approved Flutter test escalation reached the test compiler. Initial feature-missing RED was exit 1:

```text
Error when reading 'lib/features/harmonies/presentation/harmony_wheel.dart': No such file or directory
Error: Method not found: 'HarmonyWheel'.
00:00 +0 -1: Some tests failed.
```

After implementation, a test-harness cleanup issue produced 5 passes / 16 failures: `A SemanticsHandle was active at the end of the test.` Investigation of this Flutter SDK's `WidgetTester._endOfTestVerifications` showed that explicit semantics handles must be disposed before the test body ends, rather than in `addTearDown`. Corrected only the tests' handle disposal; no production behavior change was needed. The next run passed all 21 then-current tests. Added stronger marker-location assertions and an isolated base-outline behavior test; all 22 passed.

Performed a deliberate orientation mutation to prove the render assertion rejects a realistic visual regression: temporarily changed the ring rotation from `-math.pi / 2` to `0`, then ran:

```text
flutter test test/features/harmonies/presentation/harmony_wheel_test.dart --plain-name 'hue ring starts red at top and progresses clockwise'
Expected: a numeric value within <3> of <255>
Actual: <128>
00:00 +0 -1: Some tests failed.
```

Restored the correct rotation immediately, formatted, and reran the full scoped file to GREEN. The mutation is absent from the delivered source.

## Meaningful verification coverage

The 22 tests use real MaterialApp/theme/widget layout, image semantics, and rasterized pixels from the actual CustomPainter installed by the widget. There are no mocks or source-text assertions. Hand-checked marker centers independently pin every supplied shade in each of six modes in both themes; a hue ring alone cannot satisfy these assertions.

- Literal red-base fixtures cover Complementary, Analogous, Triadic, Tetradic, Split complementary, and Monochromatic. Each theme verifies all marker centers, exact actual shades, exact ordered semantic HEX values, base/mode description, image role, no tap action, and theme surface pixels.
- Cardinal ring samples independently pin top red, clockwise right yellow-green, bottom cyan, and left violet. Inner marker positions and the complementary relationship line are checked separately.
- Desaturated green/purple markers verify actual RGB fills rather than saturated ring colors. Changing supplied colors removes the former marker. Repaint decisions are checked alongside actual output.
- Changing only the base moves its identifying double outline while retaining the supplied palette.
- Monochromatic red shades and neutral monochromatic shades each occupy five distinct darker-to-lighter locations with exact fills; input-order HEX semantics remain intact.
- Black, gray, and white expose the no-hue explanation and paint at the lightness rail, with no false zero-degree marker.
- Both themes exercise every mode at a 360px viewport, 320px content width, 2x text, and reduced motion; neutral caption layout is checked too. No layout/canvas exceptions or animation callbacks remain.

## Final scoped results

```text
dart format lib/features/harmonies/presentation/harmony_wheel.dart test/features/harmonies/presentation/harmony_wheel_test.dart
Formatted 2 files (2 changed) in 0.01 seconds.

flutter test test/features/harmonies/presentation/harmony_wheel_test.dart
00:01 +22: All tests passed!
exit 0

flutter analyze lib/features/harmonies/presentation/harmony_wheel.dart test/features/harmonies/presentation/harmony_wheel_test.dart
No issues found! (ran in 1.8s)
exit 0

dart format --output=none --set-exit-if-changed lib/features/harmonies/presentation/harmony_wheel.dart test/features/harmonies/presentation/harmony_wheel_test.dart
Formatted 2 files (0 changed) in 0.01 seconds.
exit 0
```

## Required full-suite result and integration concern

Ran one full suite after scoped verification:

```text
flutter test --reporter expanded > /private/tmp/color-lab-harmonies-task-3-full-suite.log 2>&1
00:15 +459 -1: Some tests failed.
exit 1
```

All 22 wheel tests passed in that full run. The sole failing test target was:

```text
loading test/features/harmonies/presentation/harmonies_integration_test.dart [E]
```

Its compilation failed because the concurrently implemented sibling file `lib/features/harmonies/presentation/harmonies_screen.dart` did not yet exist. The import error was at integration-test line 10, with `Undefined name 'HarmoniesScreen'` at lines 306, 312, and 373. This transient sibling integration failure was reported to the parent, with the exact log path above. No sibling files were changed to mask it. Final integration and a fresh cumulative suite remain the parent's responsibility after the screen lands; the owned wheel work has no scoped failures or analyzer findings.
