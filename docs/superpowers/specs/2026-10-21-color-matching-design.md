# Color Matching Game design

Date: 2026-10-21. Implements the next Phase2 module from the supplied Color Lab
build document: match a target swatch with HSL sliders, scored by delta-E. The
user's repeated Next workflow requests immediate module implementation using
sensible defaults. This is a new architectural subsystem, kept independent of
existing Lab drafts and storage; it is not a medical/vision assessment.

## Experience and defaults

An untimed five-round offline game opens from Lab → Play color matching at
`/matching`. A fresh session creates five distinct opaque targets, with varied
hues, saturation .35–.90 and lightness .25–.75. No account, persistence, timer,
difficulty settings or leaderboard. The game stays intact while navigating in
this app session, including a submitted result and completed summary. Restarting
the app resets it. Back never silently resets a game; restart while in progress
requires confirmation. Completed Play again starts a new five-target game.

Each round shows Target and Your match swatches with no HEX/name/value hints
before submission. HSL sliders retain their own coordinates even when rendered
RGB has no hue (zero saturation/black/white). Initial guess and each next round
start at H=0°, S=0%, L=50% (#808080); no target-derived initial guess.

A compact comparison of both actual swatches stays pinned while the slider
content scrolls, so adjusting Lightness on a small phone never requires matching
from memory. It has role labels but no target values before submission, adapts
to2× text without a clipping fixed height, and reflects the same displayed RGB
as the full shared swatch tiles. Full tiles retain the post-submit detail actions.

Submit freezes that round exactly once. Feedback reveals target/actual displayed
guess HEX, CIE76 delta-E to two decimals (lower is closer) and points. Score is
`round(clamp(100 - deltaE76(target.toLab(), guess.toLab()), 0, 100))`. It is a
transparent game convention, not a scientific percentage. Exact match wording
requires RGB equality, not a rounded score of100 or error of0.00. Use existing
D65 LAB conversion of rounded display RGB, not ideal unrendered HSL coordinates.
No live score or target values appear while editing. After feedback, controls
freeze and Next round advances; fifth feedback uses See results. Summary lists
all five target/guess pairs, per-round score/error, total/500 and average/100.

Target and match details are available only after Submit, using common color
details with Lab source. Opening details/harmonies/formula/Room does not modify
the matching state. Saved-color history and saved palettes remain separate.
Screen copy explains screen/light effects and that this is a color game, not a
medical test or diagnosis. Color-vision plates remain the next module.

## Architecture

Pure scoring/target generation uses existing color math plus dart:math. A pure
immutable MatchingGame domain model owns validated five-target snapshots and
editing → feedback → next editing / complete transitions. Frozen attempts own
their exact displayed target/guess. A retained Riverpod controller delegates
transitions and injects only a target generator; no timers, plugin calls, IO,
storage schemas or new packages. Separate UI follows existing tokens/controls,
startup/onboarding guard and typed root routing. No common-details destination
or camera behavior change is required.

Target generation is bounded rather than repeated random rejection: one random
hue offset, five spaced hue bins with bounded within-bin offsets, independently
random saturation/lightness, then shuffle. Any legitimate random stream yields
five distinct RGBs without an unbounded uniqueness loop. Seeded Random tests
verify replayable generation, bounds and immutability.

Compared approaches: a single endless practice swatch is small but lacks a clear
finish; a timer/difficulty/leaderboard system expands scope and adds lifecycle
complexity. A five-round untimed session provides a useful finish and requires
only local synchronous state. That is the selected default.

## Quality and verification

48dp targets, full text scaling, readable light/dark chrome, scrollable content,
360px at2× text and reduced motion. Ordinary swatches expose Target/Your match
roles without leaking the hidden target number; post-submit values and summary
remain accessible. Slider labels expose actual hue/percent coordinates.

Tests precede implementation: independent score/ΔE fixtures, seeded target
bounds/no repetition, neutral-coordinate retention, repeated-submit/advance and
phase guards, immutable snapshots, all five rounds, restart and session isolation.
Real-router UI tests exercise Lab entry, submit/freeze/reveal, results, replay,
restart cancel, state retention, common details/Room, onboarding and enlarged
layouts. Real-font previews cover editing, feedback, summary, restart and narrow
layouts both themes. Full suite, analyzer, formatter, APK and an independently
reviewed cumulative source ZIP complete delivery. Device/iOS/native accessibility
execution remains explicitly unverified.

## Scope and self-review

No changes to existing dependencies/platform source/Hive schemas, no vision
plates, room-photo work, data deletion or unrelated refactors. Seven previous
archives are preserved. No Git repository exists, so work remains in the shared
project and prior source ZIP supplies the baseline for read-only review diffs.
Intent, assumptions, interfaces and tests agree; no placeholders remain.
