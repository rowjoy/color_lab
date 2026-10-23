# Task 2 report: procedural plate renderer

Implemented only the owned renderer, renderer tests, and this report. No Git,
native/APK build, install, package, asset, network, or sibling source changes.

## Delivered behavior

`VisionPlateView({super.key, required VisionPlate plate})` consumes the real Task
1 models and generator. State creates and retains one painter/read-only dot list
for each displayed plate value. `initState` and value-changing `didUpdateWidget`
generate geometry; `build`, theme rebuilds, and `paint` do not. Equal plate values
retain the same painter instance. The painter draws a circular paper background
and dot circles only, using original supplied RGB values without theme tinting.
It scales and centers safely in rectangular painter bounds; the widget uses a
centered square `AspectRatio` within tight wide or tall parent constraints.

The image has the exact generic semantics label required by the brief, with no
digit, seed, ID, hint, child caption, or action. There are no gesture handlers or
animation resources. No text, numeral, font, outline, bitmap, or clinical plate
asset is drawn.

## Tests-first evidence and observed failures

Before production renderer code existed, authored all seven tests and ran:

`flutter test --no-pub test/features/color_test/presentation/vision_plate_view_test.dart`

1. Initial RED: exit 1, load error because the renderer and still-pending Task 1
   domain imports did not exist. No domain stubs or duplicate models were added.
2. After Task 1 files existed, ran the same command again: exit 1, load error
   solely from the absent renderer import/API. This is explicitly a missing-API
   compile RED, not a claimed behavioral assertion RED.
3. Implemented the renderer against the actual shared types. First runnable run:
   5 passed, 2 failed, exit 1. The failures were `hidden digit changes color at
   known point but no dot geometry` and `palette changes actual RGB and seed
   changes actual geometry`. Their exact footprint equality assumed that every
   anti-aliased edge remains distinguishable from paper after color-dependent
   RGB quantization. A color change can round a nearly clear edge to paper in one
   image and one RGB level from paper in another. The corrected comparison allows
   only that <=1 RGB-level rounding for pixels whose paper/non-paper membership
   differs; all meaningful occupied pixels must still match. Renderer production
   code did not change to accommodate this test correction.
4. Focused GREEN: the same command passed all 7 tests, exit 0. API-ready notice
   sent to root/UI after that observed result.

The Task 1 agent's concurrent full run also observed the same two in-progress
renderer assertion failures, which are disclosed here and in its report.

## Actual raster and semantics evidence

- Rasterized the actual `CustomPainter` installed by the real widget with a real
  `PictureRecorder`, `toImage`, and raw RGBA readback inside `tester.runAsync`.
  No mocks, fake canvas, replacement painter, or golden comparison.
- Every generated dot's center retains its exact opaque RGB in all three
  palettes. Independently specified literal fixtures require all 18 illustrative
  figure/field shades to occur. Paper is independently pinned to `#F4EFE5`;
  center-grid gaps and the circle's upper margin are paper; outer corners are
  transparent.
- The independently hand-checked normalized center candidate `(0.515625,
  0.515625)` maps to raster point `(132, 132)` at 256px. It is one of three literal
  olive field colors for digit 2 and one of three literal rose figure colors for
  digit 8. Dot footprints remain identical subject only to the stated edge
  quantization allowance. Changing the palette changes RGB without changing the
  meaningful footprint; changing the seed changes the footprint and raster.
- Every palette produces byte-identical full RGBA images in light/dark themes,
  for equal-value plate replacements, and after an elapsed 10-second pump.
  Painter identity remains stable for equal values and theme rebuilds;
  digit/palette/seed changes request repaint.
- Tight `320x180` and `180x320` parents each produce a `180x180` diagram. Direct
  `320x180` painter rasterization retains transparent side margins, the proper
  paper margin, and the expected scaled/centered dot fill.
- Both themes at 360px width, 2x text, and reduced motion expose exactly one
  generic image node with no semantic actions or children and no numeric answer
  leakage. No descendant `GestureDetector`, framework exception, or animation
  callback is present. Explicit semantics handles are disposed inline using
  `try/finally` even if assertions fail.

## Verification commands and outcomes

- Focused renderer command above: **7 passed, exit 0**.
- `flutter analyze --no-pub lib/features/color_test/presentation/vision_plate_view.dart test/features/color_test/presentation/vision_plate_view_test.dart`:
  **No issues found, exit 0**.
- `dart format lib/features/color_test/presentation/vision_plate_view.dart test/features/color_test/presentation/vision_plate_view_test.dart`:
  **2 files formatted, exit 0** (test formatting changed only).
- `dart format --output=none --set-exit-if-changed lib/features/color_test/presentation/vision_plate_view.dart test/features/color_test/presentation/vision_plate_view_test.dart`:
  **2 files, 0 changed, exit 0**.
- Required one full-suite attempt:
  `flutter test --no-pub --reporter expanded`, captured in
  `/private/tmp/color-lab-vision-task2-full.log`. It reached **560 passing tests**
  with no assertion failures, then stalled in the concurrently developing sibling
  test `new response updates actual plate pixels and theme preserves them` in
  `vision_integration_test.dart`. UI owner confirmed its raster helper had lacked
  `tester.runAsync`, fixed it, and subsequently reported focused 14/14 GREEN.
  This old compiled test process was stopped at root's request; this is **not a
  successful full-suite result**. Cancellation logged `loading .../vision_integration_test.dart [E]`,
  `Bad state: Cannot close sink while adding stream.`, an uncaught shutdown
  `Bad state: Cannot add event while adding stream.`, and the named test
  `- did not complete [E]`, ending `+560 -1: Some tests failed.` The session
  wrapper returned exit 0 after Ctrl-C, which does not override that failed/
  incomplete test report. No sibling file was edited. Root owns the fresh final
  integrated suite after reports.

Flutter/Dart verification used approved SDK-cache access outside the workspace.
No APK or native build/install command was run.

## Limits and self-review

These tests establish Flutter raster/semantic behavior, caching, and responsive
geometry. They do not establish device/native assistive-technology behavior,
display color calibration, or medical validity. Original illustrative patterns
are a non-diagnostic activity. The only comparison tolerance is <=1 RGB level
at almost-clear anti-aliased paper edges; dot centers, all palette RGB fixtures,
paper, and theme-repeat byte equality are exact.

Reviewed plausible regressions: omitted or shifted dots fail actual center/RGB
or footprint checks; stale cached plates fail changed-input pixels/repaint;
theme tinting fails all-palette byte equality; square stretching fails measured
bounds and rectangular raster points; answer-bearing captions/actions fail the
exact generic semantics assertions. No test-only public API was introduced.
