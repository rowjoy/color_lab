# Matching diagnostic preview report

Status: complete. The scoped renderer passed and all 14 actual matching images
were visually inspected after the real matching engine and UI landed.

## Scope

Only `tool/render_previews.dart` and this report are owned by this diagnostic task.
The renderer preserves the existing 68 capture paths and appends 14 matching
captures. The generated directory contains exactly 82 PNGs in `build/previews`.

Matching uses the real app route, screen, retained controller, submissions, and
completed attempt snapshots. Its target-generator provider is overridden with
literal red, green, blue, cyan, and yellow targets. The first guess uses retained
HSL coordinates `(24, .6, .5)`; later rounds use hues 132, 228, 190, and 48 with
the same saturation and lightness. No game model or screen is faked.

Generated matching filenames:

- `matching-editing-light.png`
- `matching-editing-dark.png`
- `matching-feedback-light.png`
- `matching-feedback-dark.png`
- `matching-summary-light.png`
- `matching-summary-dark.png`
- `matching-restart-dialog-light.png`
- `matching-restart-dialog-dark.png`
- `matching-editing-360-text2x-reduced-motion-light.png`
- `matching-editing-360-text2x-reduced-motion-dark.png`
- `matching-feedback-360-text2x-reduced-motion-light.png`
- `matching-feedback-360-text2x-reduced-motion-dark.png`
- `matching-summary-360-text2x-reduced-motion-light.png`
- `matching-summary-360-text2x-reduced-motion-dark.png`

Normal captures use a 390 × 844 logical viewport. Accessibility captures use a
360 × 800 logical viewport, 2× text, and disabled animations. Existing real font
loading remains unchanged (Plus Jakarta Sans, JetBrains Mono, Material Icons).
PNG capture uses 2× pixels: normal images are 780 × 1688 and accessibility images
are 720 × 1600.

## Verification and visual inspection

`flutter test tool/render_previews.dart --no-pub` completed exit 0: **2 tests
passed** (light and dark render sequences). Elevated SDK-cache access was used.
The output contained no overflow, layout, hit-test, or other Flutter warnings.
The matching capture steps also explicitly check `tester.takeException()`.

All 14 new PNGs were opened and inspected individually. Editing captures anchor
the actual Hue control so all three HSL controls and the pinned target/guess
comparison are visible at normal and 2× text. Feedback captures anchor the result
card: the first actual submitted RGB pair is target `#FF0000` and guess
`#CC7033`, yielding **48 / 100 points** and displayed **ΔE 52.08**. Normal feedback
also shows the disabled controls and Next round action; 2× feedback wraps its
result text within the scrollable body while keeping both comparison colors
visible. The result card's larger natural height is expected at 2× text.

Summary captures anchor Total points and show the actual completed total
**261 / 500**, average **52.20 / 100**, and immutable first-round RGB chips,
score, and error. The restart dialog shows legible confirmation and cancellation
actions in both themes. Screens intentionally scroll past introductory content
to show each diagnostic state; ordinary content clipping at the scroll viewport
boundary is expected. No render overflow stripes, unintended overlaps, hidden
comparison colors, or broken modal layouts were observed. No production layout
change was needed.

The full test suite, analyzer, APK build, cumulative delivery, and source
documentation remain the parent task's responsibility. No full suite has been
run for this diagnostic extension.

Root's post-fix delivery pass reran the same renderer after the verified
summary/replay viewport correction: both theme tests passed in14 seconds,
82 PNGs remained present, and no layout/hit-test warnings appeared. The root
also inspected the refreshed enlarged dark summary. The diagnostic fixture,
capture paths and renderer behavior were unchanged by that production fix.
