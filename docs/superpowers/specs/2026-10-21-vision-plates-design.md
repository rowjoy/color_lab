# Procedural Color Vision Plates activity

Date: 2026-10-21. Next module in the supplied build document: procedural dot
plates via CustomPaint, simple results and a non-diagnostic disclaimer. The user
explicitly says **do not build an APK**. No platform build/install occurs; test,
analyzer, formatting, real-font previews and source ZIP are the delivery gates.

This is a new architectural feature in the existing color_test area, not a
validated Ishihara reproduction, clinical screening tool or diagnosis. The
established Next workflow requests sensible defaults and immediate scoped work.

## Experience

Lab → Explore vision plates opens guarded `/vision`. An introduction explains
six untimed, original generated patterns, one-digit responses or Not sure, local
session-only state and the activity's limitations. Start activity shows a circular
dot pattern, Plate N of6, a numeric one-digit field, Record answer and Not sure.
There is no per-plate correctness hint. A response advances to the next pattern;
the sixth opens a summary at the top. Results list generated digits versus the
six recorded responses, pattern-match count and Not sure count, without health
interpretation, pass/fail, deficiency types or severity. Try again starts fresh.

Persistent visible copy: "Generated patterns for exploration only. This is not
a validated screening test or medical diagnosis and cannot rule out a condition."
Intro and results also explain: concerns about color vision belong with an eye
care professional. [NEI's testing guidance](https://www.nei.nih.gov/eye-health-information/eye-conditions-and-diseases/color-blindness/testing-color-vision-deficiency)
supports that clinician pathway and describes colored-dot shapes. It does not
validate our generated graphics. No NEI/Ishihara images, plate layouts, answer
keys or clinical thresholds are copied. No health data is persisted/transmitted.

The activity retains responses and the pending digit across navigation/theme
changes in this app session, independently of the matching game and other Lab
drafts. Back does not reset it. Restart activity during the active session asks
for confirmation; cancelling/system Back preserves state. Results' Try again
is explicit, starts a fresh active six-plate set and clears the old draft. App
restart returns to the introduction. No timers, leaderboard, diagnosis history,
calibration claim, account or network feature.

## Original procedural graphics

Pure Dart generates six unique digit patterns from2,3,4,5,6,8 in shuffled order,
three illustrative palette pairs and per-plate seeds. Supported glyphs0–9 are
simple original5×7 block-digit masks, not raster/text assets. Shape membership
only selects dot color. Geometry depends on seed alone, not digit/palette: a
32×32 jittered grid, normalized circle centered(.5,.5), dots fully within radius
.48, jitter±.002 and radius .009–.013. Separate geometry/shade random streams
avoid color/answer-dependent dot density or size cues. Colors are illustrative
rose/olive, teal/rose and blue/sand, with three varied shades in each group.
The same actual RGB and warm neutral paper are used in both themes.

A cached read-only CustomPainter draws only circles. It never draws a numeral,
outline of the hidden glyph or text over the dots. Its image semantics describe
the generated dot pattern and response alternatives but never reveal the expected
digit, seed or answer-coded ID. There are no copyrighted images, bitmap assets,
medical validation or simulations of named color-vision conditions. The canvas
scales with available width; page text follows system text scaling.

Compared approaches: downloading existing clinical plate images conflicts with
original/offline assets and validation boundaries; a calibrated clinical tool is
outside this app's evidence and scope. Original generated activity patterns with
honest limitations satisfy the requested drawing/summary without pretending to
diagnose. This is the selected approach.

## State, input and lifecycle

Pure immutable plates, dot lists, response snapshots and session transitions;
retained Riverpod controller with an injected plate generator. Stale response
callbacks carry the captured plate ID and cannot answer the next plate. Pending
drafts are nullable integer digits; zero is valid, null is not a typed answer,
while Not sure explicitly records null. Input formatting limits typing to one
digit. No correctness feedback or details actions appear before completion.

Viewport resets on activity start, new plate, completion or replacement set;
not while typing or changing theme. Keyboard dismisses on accepted responses.
Session/controller are independent of storage/plugins and synchronous. Geometry
is cached per displayed plate, never regenerated in paint or theme rebuilds.

## Verification and limits

Tests first: original mask/geometry bounds/determinism/color-only shape changes,
immutable valid models, stale callback guards, all six transitions and replay,
retained draft and independent controllers. Painter pixel/semantic tests pin
actual dots, no-hint semantics, theme stability, resizing/repaint and reduced
motion. Full-app tests cover intro, input/Not sure, no live answer leakage,
completion/response-only summary, retained drafts, modal cancellation/restart,
onboarding guards, real visible next/results/replay entry and360px2×both themes.

Fresh full suite, analyzer, formatter, previews, scoped and final review, source
ZIP integrity. **No APK/native build or install**, no new packages, native source,
assets or storage schema changes. Prior eight archives and existing APK/user data
stay untouched. Device/iOS/native accessibility and clinical validity are not
established by these tests. Next is Room Studio planning, not started here.
