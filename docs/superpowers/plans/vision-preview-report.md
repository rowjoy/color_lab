# Vision Plates preview evidence

Root ran `flutter test tool/render_previews.dart --no-pub --reporter expanded`
after integration. Final run: exit 0, both theme tests passed in seven seconds.
The renderer produced 104 PNGs under `build/previews/`: the previous 82 stems
are retained and 22 Vision captures are added.

## Fixture and real interaction

The real generator/controller use fixed digits 2, 3, 4, 5, 6 and 8, seeds 11,
22, 33, 44, 55 and 66, with all three original palettes. No painter replacement,
clinical image or fake result model is used. Real Start/Record/Not sure controls
record 2, null, 9, 5, null and 8. Each transition asserts the actual response
count; final literal expectations are three pattern matches and two Not sure.

Per theme: introduction, all six actual patterns at their natural entry
viewport, restart dialog, plate/input viewport at 360px/2x text/reduced motion,
results and narrow results. Results are captured at natural entry, without
scrolling the destination into view. The narrow active capture deliberately
scrolls to the diagram/input; its counter/instruction remains above that
viewport, not removed from the screen.

## Observed RED and correction

The first root run failed in both themes at the results-key assertion: the
harness typed a digit then tapped the build-captured Record callback without
pumping a rebuild. The independent UI tests already pump after typing. Added
that frame synchronization and response-count assertions, not a product change.
The corrected run passed. A final framing pass removed unnecessary scrolling
before ordinary plate captures, keeping the counter/instruction visible, and
both theme tests passed again. No failed/cancelled run is counted as success.

## Visual inspection

Inspected all six normal light-theme plate captures: each expected original
block-digit shape is legible in colored dots, with consistent circular paper,
no numeral/text overlay, no visible tracing or density-shaped glyph. Counter,
instruction, input and controls remain aligned at the natural entry viewport.
Intro, response summary, light narrow active, dark narrow results and dark
restart modal were also opened as actual PNGs. Text wraps vertically without
horizontal overflow; the modal retains clear shared controls and contrast.
The summary reports three of six pattern matches and two Not sure, never a
health classification. Introduction and visible footer retain the caveat.

Painter tests independently establish byte-identical pattern RGBA between
themes for all three palettes, real dot fills and paper, geometry-only seed
changes, cache replacement, square resize and answer-free generic semantics.
These are Flutter layout/pixel observations, not display calibration, native
assistive-technology or medical validation. No APK/native build/install ran.
