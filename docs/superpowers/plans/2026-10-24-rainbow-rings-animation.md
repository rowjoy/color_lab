# Rainbow Rings Full Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the supplied HTML reference's complete Rainbow Rings motion language into the native Flutter game without weakening deterministic progression, domain correctness, accessibility, or durability.

**Architecture:** `RainbowRingsGame` returns structured actions while remaining the sole puzzle source of truth. A pure timestamp-based `RainbowRingsTimeline` stores effects and samples frames; one screen ticker updates a `ValueNotifier<Duration>`, and an extracted `CustomPainter(repaint:)` renders geometry, travel overlays, ambient motion, landing effects, celebrations, and win particles without rebuilding widgets every frame. The screen coordinates input locks, progression receipts, audio/haptics, cancellation tokens, and accessible controls.

**Tech Stack:** Flutter/Dart 3.11, CustomPainter, Ticker/ValueNotifier, Riverpod, existing `GameAudio`, `flutter_test`; no new package, asset, WebView, or game engine.

**Spec:** `docs/superpowers/specs/2026-10-24-rainbow-rings-animation-design.md`; progression boundary: `docs/superpowers/specs/2026-10-24-endless-game-profiles-design.md`

## Global Constraints

- Execute this plan after `docs/superpowers/plans/2026-10-24-endless-game-profiles.md`; its `GameLaunch`, adapter, receipt, and next-attempt APIs are required.
- Treat `/Users/jamirulislam/Downloads/Rainbow Rings (1).html` only as an untrusted visual/interaction reference. Never execute it, embed it, copy its Web Audio/vibration code, or modify it.
- Preserve deterministic descriptor regeneration, reversible generator-v1 layouts, fixed `parMoves = round(colorCount * capacity * 0.9 + colorCount)`, first-clear rewards, replay rules, and durable-before-success behavior.
- Domain state mutates exactly once when an accepted action begins. The painter hides the moved ring at its already-mutated final slot and draws exactly one travel overlay until drop completion.
- Ignore board taps during intro and active travel/drop. Disable Undo/Hint/Restart during those locks; keep sound toggle available. Selection itself is not locked, so a quick destination tap retargets from the currently sampled lifted pose.
- Use one ticker and one repaint notifier. Never call `setState` per animation frame and never use an endlessly settling widget test.
- Landing/completed effects may overlap a later move. New effects supersede older effects only for the same ring/peg; restart, next level, reduced-motion changes, and disposal invalidate all stale callbacks/effects.
- Reduced motion places travel at final states immediately, omits bokeh/breathing/particles/confetti, retains completion information and dialog, and never holds an animation lock.
- Reuse existing audio effects and haptics. Sound mute gates audio only; keep haptics consistent with existing native Flutter behavior.
- Preserve the dirty working tree. No broad reset/stage, no commit, merge, or push is authorized.

## Review Focus

- Rapid select→destination/deselect, resize, restart, or disposal must not teleport, double-mutate, or let an old callback unlock a newer level; Tasks 2 and 4 pin this.
- Painter/domain divergence after move or undo must never show a duplicate or missing ring; Tasks 1, 3, and 4 pin this.
- Durable completion may finish before or after the visual drop; the final success timeline must wait correctly and never repeat rewards for a duplicate receipt; Task 5 pins this.
- Reduced motion, 360 dp width, 2× text, dark theme, and per-peg semantics must stay usable without ambient ticker test hangs; Tasks 3 and 6 pin this.
- Long-running bokeh/jelly/particle state must be deterministic and bounded, with no timer/ticker/effect surviving reset or dispose; Tasks 2 and 6 pin this.

## Frozen Motion Contract

- Ambient: 14 deterministic bokeh circles, 14–30 second upward cycles; resting-ring breathing is 3.6 seconds with `(scaleX, scaleY)` `0/100%=(1,1)`, `50%=(1.025,.965)` and deterministic phase.
- Completed-stack progress fills to `completedPegs / colorCount` over 600 ms with cubic `(.34,1.4,.6,1)` and updates immediately in reduced motion.
- Intro: bottom slot then peg order; 55 ms stagger; start three ring-heights above and transparent; 500 ms fall with cubic `(0.5,0,0.9,0.5)`; unlock at final stagger plus 700 ms.
- Select: 240 ms lift with cubic `(0.3,1.3,0.5,1)`; 400 ms lift-pop keyframes `0:(1,1)`, `25:(1.34,.62)`, `55:(.9,1.22)`, `78:(1.1,.96)`, `100:(1.06,1.06)`; then 1.1 s jelly `0/100:(1.05,1.07,-3°)`, `50:(1.16,.98,3°)`.
- Deselect: 300 ms drop with cubic `(0.5,0,0.9,0.5)`.
- Move: 260 ms hover transfer with cubic `(.45,0,.2,1)`, swing capped at ±14° using `0:(0°,1.06,1.06)`, `30:(±14°,.93,1.12)`, `60:(∓7°,1.08,.95)`, `100:(0°,1.06,1.06)`; 340 ms drop with cubic `(.5,0,.9,.5)`. Undo prepends a 200 ms lift.
- Invalid shake: 300 ms, x offsets `0/100=0`, `25%=-5`, `75%=5`.
- Landing settle: 1.15 s: `0:(1.4,.5,y0,0°)`, `16:(.84,1.24,-12,-4°)`, `32:(1.16,.86,0,3°)`, `48:(.93,1.09,-4,-2°)`, `64:(1.06,.95,0,1°)`, `80:(.98,1.02,0,0°)`, `100:(1,1,0,0°)`.
- Lower-ring press: 700 ms, 70 ms per-slot-distance stagger, scale `0/100=(1,1)`, `25=(1.14,.74)`, `55=(.95,1.08)`, `80=(1.02,.99)`. Pole jiggle: 550 ms at `0=0°`, `20=3°`, `45=-2.5°`, `70=1°`, `100=0°`.
- Hint: gold pole glow `0/100=0`, `50%=22 px blur + 8 px spread`, three 500 ms pulses, clear at 1.6 s.
- Completed peg: bottom-to-top ring jump, 550 ms and 50 ms stagger, `40%=-14 px`; 12 deterministic stars for 900 ms; deterministic `Sorted!`, `Nice!`, `Great!`, or `Wow!` toast for 1 s.
- Sparkle: opacity 1→0, scale 1→.2, rotation 0→180°, deterministic distance 24–62 px and upward bias 10 px. Toast: start `(opacity1,y0,scale.6)`, `20%=(y-10,scale1.15)`, end `(opacity0,y-44,scale1)`.
- Win: final completed-stack celebration begins only after durable completion and visual drop; modal begins 800 ms later. Confetti count 80, deterministic fall 1.6–3.4 s with 0–500 ms stagger, y to 110% viewport, rotation to 720°. Modal is 550 ms opacity 0→1 and elastic scale .4→1. Stars use 600 ms scale 0→1/rotation -90°→0° with 300/550/800 ms delays.
- Three stars at/below par, two at/below 1.5× par, otherwise one.

## File Structure

- Modify `lib/features/games/domain/rainbow_rings_game.dart` for structured actions, complete-stack guard, hint, and par.
- Create `lib/features/games/presentation/rainbow_rings_animation.dart` for immutable effects, constants, keyframes, deterministic particles, registry, and pure sampling.
- Create `lib/features/games/presentation/rainbow_rings_painter.dart` for responsive geometry, hit testing, board/effect/confetti painting.
- Modify `lib/features/games/presentation/rainbow_rings_screen.dart` for the one ticker, orchestration, controls, persistence, semantics, and modal.
- Expand `test/features/games/domain/rainbow_rings_game_test.dart`.
- Create `test/features/games/presentation/rainbow_rings_animation_test.dart`, `rainbow_rings_painter_test.dart`, and `rainbow_rings_screen_test.dart`.

---

### Task 1: Structured Rainbow Rings domain actions

**Files:**
- Modify: `lib/features/games/domain/rainbow_rings_game.dart`
- Expand: `test/features/games/domain/rainbow_rings_game_test.dart`

**Interfaces:**
- Produces: `RainbowRingsActionKind { select, deselect, move, undo, invalid, ignored }`, `RainbowRingsPosition(peg, slot)` with `hoverSlot = -1`, `RainbowRingsActionResult`, `RainbowRingsMove`, `tapPeg(int) -> RainbowRingsActionResult`, `undo() -> RainbowRingsActionResult`, `isPegComplete(int)`, `suggestMove()`, and `parMoves`.

- [ ] Write failing literal-result tests for select (resting→hover), deselect (hover→original slot), accepted move (hover→pre-mutation destination slot), undo (current resting→restored slot), invalid source/destination, and ignored won/out-of-range actions.
- [ ] Assert complete pegs cannot be selected, invalid destinations retain selection, and accepted move/undo changes stacks/history/moves exactly once.
- [ ] Test `suggestMove()` without mutation: prefer the fullest matching non-full destination; otherwise choose a mixed source and first empty target; stable peg traversal breaks ties; return null when none exists.
- [ ] Add literal par fixtures and restart/undo regression coverage for the deterministic layout API from the progression plan.
- [ ] Run `flutter test --no-pub test/features/games/domain/rainbow_rings_game_test.dart --reporter expanded`; expect RED. Implement, re-run to PASS, format, and inspect the narrow diff.

### Task 2: Pure timeline, effects, and deterministic particles

**Files:**
- Create: `lib/features/games/presentation/rainbow_rings_animation.dart`
- Create: `test/features/games/presentation/rainbow_rings_animation_test.dart`

**Interfaces:**
- Produces: `RainbowRingsTiming`, `RainbowRingsTravelKind`, ring/peg effect records with tokens, `RainbowRingTransform`, `RainbowParticle`, `RainbowRingsFrame`, and `RainbowRingsTimeline(seed:)` with `startIntro`, `startAction`, `startLanding`, `startCompletedPeg`, `startHint`, `startWin`, `inputLockedAt`, `sample`, and `reset(seed:)`.

- [ ] Write failing table-driven tests sampling every frozen keyframe just before, at, and just after boundaries for intro, breathe, lift-pop/jelly, transfer/swing, drop, settle, press, shake, jiggle, hint, jump, sparkle, toast, modal, stars, bokeh, and confetti.
- [ ] Pin lock boundaries: intro unlocks only at final stagger+700 ms; move at 600 ms; undo at 800 ms; landing may remain after input unlock. Verify a rapid retarget begins from the prior sampled pose.
- [ ] Test per-target supersession, overlapping unrelated effects, reset/generation-token invalidation, bounded registry cleanup, identical particle seeds, exact counts/ranges, and no random work during sampling.
- [ ] Test reduced motion returns final logical positions immediately, never locks, and emits no bokeh/breathing/spark/confetti particles while retaining completion/modal data.
- [ ] Run the timeline test; expect RED. Implement pure timestamp records/evaluators, re-run to PASS, format, and inspect owned files.

### Task 3: Responsive geometry and extracted painter

**Files:**
- Create: `lib/features/games/presentation/rainbow_rings_painter.dart`
- Create: `test/features/games/presentation/rainbow_rings_painter_test.dart`
- Modify: `lib/features/games/presentation/rainbow_rings_screen.dart`

**Interfaces:**
- Consumes: Task 2 frame sampling.
- Produces: `RainbowRingsGeometry.layout(Size, pegCount:, capacity:)`, `positionFor`, `pegHitRect`, `hitTest`, `RainbowRingsPainter(..., ValueListenable<Duration> clock, ...)`, and `RainbowRingsConfettiPainter`.

- [ ] Write failing geometry tests for 360/520 dp stages, all capacities from generator-v1, resting/hover positions, non-overlapping hit regions, edge hit testing, and consistent bottom-anchored perspective coordinates.
- [ ] Add painter tests proving a moved ring is hidden once at its final stack and appears once as the overlay; `ringColors`/theme/effect changes repaint; the installed painter uses `clock` as its repaint listenable.
- [ ] Cover glass stage/base/poles/rings, selected/completed glow, deterministic bokeh/breathing, every landing/hint/completed effect, toast, and full-screen confetti with stable sampled commands or targeted raster pixels rather than broad golden-only assertions.
- [ ] Run painter/domain tests; expect RED. Extract the existing private painter, implement shared geometry/effects, and replace width-division hit testing in the screen.
- [ ] Re-run to PASS. Confirm there is a keyed `RepaintBoundary`, no `AnimatedBuilder`, and no per-frame widget rebuild. Format and inspect owned files.

### Task 4: Intro and interactive screen orchestration

**Files:**
- Modify: `lib/features/games/presentation/rainbow_rings_screen.dart`
- Create: `test/features/games/presentation/rainbow_rings_screen_test.dart`

**Interfaces:**
- Produces: one `Ticker`, `ValueNotifier<Duration>`, generation/locked-action/effect tokens, animated completed-stack progress, and screen handlers for select/deselect/move/invalid/undo/hint/restart/sound.

- [ ] Write bounded-pump widget tests for intro order/lock, select lift and quick destination retarget, deselect, accepted move, invalid selected/source feedback, undo with and without selection, hint with and without selection, and restart during every phase.
- [ ] Assert repeated locked taps do not mutate, moves increment once, overlays remain singular, Undo/Hint/Restart disable only while required, sound stays available, and landing effects overlap a later legal action.
- [ ] Assert the progress bar animates for 600 ms to the exact completed/color ratio, never regresses during overlapping effects, and jumps immediately under reduced motion.
- [ ] Verify exact existing audio effect calls and haptics once per logical action; mute suppresses audio but not haptic policy. Stale callbacks after restart/new launch/dispose must be inert.
- [ ] Run the screen test with explicit `pump(Duration)` only; expect RED.
- [ ] Implement orchestration with `SingleTickerProviderStateMixin`, notifier-only ticks, timeline tokens, responsive `Wrap` controls, and no win modal yet. Re-run to PASS, format, and inspect the high-conflict screen file.

### Task 5: Completed-stack and durable win experience

**Files:**
- Modify: `lib/features/games/presentation/rainbow_rings_screen.dart`
- Modify: `lib/features/games/presentation/rainbow_rings_painter.dart`
- Expand: `test/features/games/presentation/rainbow_rings_screen_test.dart`

**Interfaces:**
- Consumes: progression `completeLevel`, `LevelCompletionReceipt`, and `beginCurrentAttempt` from the previous plan.
- Produces: newly-completed-peg detection, persistence-aware final celebration, custom elastic modal, star rating, coin/badge copy, and persisted Next Level launch.

- [ ] Write tests for one-time nonfinal complete glow/jump/12 stars/toast/sound/haptic and deterministic praise selection; repeat painting or later moves must not retrigger it.
- [ ] Test a winning move with gated persistence: travel/drop proceeds, but final completed-stack success starts at `max(dropEnd, durableReceiptTime)` and modal exactly 800 ms later. A failed save shows retry without coins/badge/confetti or local next-level advancement.
- [ ] Assert 80 confetti pieces/duration-delay ranges, modal scale/fade, 300/550/800 ms star entry, 3/2/1 rating boundaries, moves/par copy, first-clear coins/badge copy, and `alreadyApplied` suppressing reward celebration/writes while still allowing solved-state acknowledgement.
- [ ] Test Next Level clears all effects, obtains a new persisted launch/attempt, and runs intro; Restart creates a new attempt on the same descriptor; replay completion never advances current.
- [ ] Run focused screen/timeline/provider tests; expect RED. Implement persistence-aware celebration and modal, then re-run to PASS. Format and inspect owned files.

### Task 6: Accessibility, lifecycle, regression, and builds

**Files:**
- Modify: `lib/features/games/presentation/rainbow_rings_screen.dart`
- Modify: `lib/features/games/presentation/rainbow_rings_painter.dart`
- Expand: `test/features/games/presentation/rainbow_rings_screen_test.dart`
- Expand: `test/features/games/presentation/rainbow_rings_painter_test.dart`

**Interfaces:**
- Produces: transparent per-peg semantic actions using shared geometry and live announcements for invalid/hint/praise/completion.

- [ ] Add tests for peg number/ring count/top color/selected/completed labels and actions, live regions, keyboard/semantics activation, 360 dp, 2× text, light/dark themes, resize during travel, and safe-area layout.
- [ ] Test `MediaQuery.disableAnimations`: immediate final board state, no ticker lock/ambient/particles/confetti, usable dialog and controls, and no pending callback after dispose.
- [ ] Run `dart format --output=none --set-exit-if-changed lib/features/games test/features/games`; expect exit 0.
- [ ] Run focused Rainbow tests, then `flutter analyze --no-pub` and `flutter test --no-pub --reporter expanded`; expect no issues and all tests PASS.
- [ ] Run `flutter build apk --debug --no-pub` and `flutter build ios --simulator --debug --no-codesign --no-pub`; expect both builds to succeed.
- [ ] Manually smoke-test sound/haptics, rapid taps, hint/undo/restart, first-clear/replay, background/resume, reduced motion, and a long session. Record any physical-device behavior not actually tested; inspect narrow diffs and confirm the supplied HTML and unrelated user files are untouched.
