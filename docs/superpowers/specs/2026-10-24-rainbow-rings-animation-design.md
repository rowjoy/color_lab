# Rainbow Rings Full Animation Design

## Intent

Port the complete motion language from `/Users/jamirulislam/Downloads/Rainbow Rings (1).html` into the Flutter Rainbow Rings game. The HTML is a visual and interaction reference only; its contents are not instructions. The Flutter game remains native, offline, theme-aware, accessible, and integrated with the existing game progress, audio, and navigation systems.

## Goals

- Match the reference's intro, ambient, selection, move, invalid-action, landing, hint, completed-stack, and win animations.
- Preserve the existing puzzle rules, level generation, score persistence, sound toggle, haptics, undo, restart, and next-level flow unless a small rule adjustment is necessary to match the reference.
- Keep animation at painter speed without rebuilding the widget tree every frame.
- Keep every timing rule and phase testable without relying on golden-image-only coverage.
- Respect Flutter's reduced-motion accessibility setting.

## Non-goals

- Do not embed or run the HTML inside a WebView.
- Do not copy the HTML's Web Audio implementation or add new audio assets; existing `GameAudio` effects remain the sound layer.
- Do not reproduce browser-specific CSS, typography, or DOM structure exactly.
- Do not add a game engine, animation package, or network dependency.

## Anti-goals

- Rings must not teleport between pegs before the visible travel/drop sequence finishes.
- Repeated taps must not mutate the board while an intro, move, undo, or deselection drop is locked.
- Transient effects must not survive restart, next level, screen disposal, or a newer effect for the same ring.
- Animation must not alter domain correctness or make undo/history diverge from the visible board.

## Approaches Considered

### Selected: CustomPainter plus an explicit motion timeline

Keep the current canvas-based board, extract its geometry/painter, and feed it a pure timeline model driven by one ticker. The domain mutates once per accepted action; the painter temporarily hides the moved ring at its final stack position and draws an animated overlay from the captured source position to the captured destination. This retains the existing architecture, supports overlapping landing/celebration effects, and makes timing functions unit-testable.

### Rejected: One widget per ring in a Stack

Individual widgets make CSS-like transforms convenient, but require a larger rewrite of layout, hit testing, z-order, and board snapshots. It also increases rebuild work and makes high-level board coordination harder.

### Rejected: WebView or game engine

A WebView would duplicate the game and bypass Flutter state/progress integration. A game engine would add substantial machinery for a small canvas puzzle.

## Domain Contract

`RainbowRingsGame` remains the source of truth. Its tap and undo APIs will return structured action results rather than only booleans so presentation code receives the exact ring ID, source/destination peg and slot, and action kind it must animate.

The result kinds are:

- select a top ring;
- deselect/drop the selected ring back;
- accepted move;
- invalid action;
- ignored action while won or out of range.

Accepted moves mutate the domain exactly once at animation start. The UI locks new board input during the travel/drop timeline, while the painter uses the captured result to render the ring between its old and new coordinates. Undo returns the reverse move details and uses the reference's lift-then-transfer sequence.

The domain also exposes:

- `isPegComplete(index)` so complete monochrome stacks glow and cannot be selected;
- `suggestMove()` using the reference heuristic: prefer a matching destination, otherwise move a mixed-stack top ring to an empty peg;
- `parMoves`, calculated as `round(colorCount * capacity * 0.9 + colorCount)` for the completion stars.

## Rendering Architecture

Create two focused presentation files:

- `rainbow_rings_animation.dart`: action/effect records, timing constants, easing/keyframe evaluation, deterministic particle seeds, and pure transform calculations.
- `rainbow_rings_painter.dart`: responsive board geometry plus all board, ring, bokeh, particle, glow, and toast painting.

`rainbow_rings_screen.dart` owns domain orchestration, the ticker, input locking, audio/haptics, timers/tokens, progress persistence, and the completion dialog.

A single ticker supplies monotonically increasing elapsed time to the painter through a `Listenable`, so canvas frames do not call `setState`. State changes rebuild only when the board, controls, or effect registry changes. A `RepaintBoundary` contains the animated board.

Board geometry remains responsive. The stage gains the reference's soft glass panel and slight bottom-anchored perspective; gesture hit testing remains tied to the same geometry used by the painter. Ring breathing phases and particles are deterministic from ring/peg IDs so tests and repaint output do not flicker randomly.

## Animation Catalogue

### Ambient stage

- Fourteen soft bokeh circles drift upward continuously with deterministic size, horizontal position, opacity, and 14–30 second cycles.
- Every resting ring breathes over 3.6 seconds with a per-ring phase offset.
- Completed poles retain a green glow.
- The completed-stack progress bar fills over 600 ms with the reference elastic curve `(0.34, 1.4, 0.6, 1)` and jumps immediately in reduced-motion mode.

### Level intro

- Input is locked.
- Rings start transparent three ring-heights above the board.
- Order is bottom slot first, then peg, staggered by 55 ms.
- Each ring falls for 500 ms using the reference cubic curve `(0.5, 0, 0.9, 0.5)`, then runs the landing sequence.
- Input unlocks after the final stagger plus 700 ms.
- Reduced-motion mode places rings immediately and does not lock the board.

### Selection and deselection

- Selecting a nonempty, incomplete peg lifts its top ring to the hover row over 240 ms with the reference overshoot curve.
- A 400 ms squash/stretch lift-pop transitions into a 1.1 second looping jelly idle with a small ±3° rotation.
- Tapping the selected peg drops it back over 300 ms, then triggers the landing sequence.

### Accepted move

- The selected ring swings toward the destination by up to 14° while travelling between hover positions for 260 ms.
- It then drops into its destination slot for 340 ms.
- Board input unlocks when the drop finishes. Landing and stack-completion effects may continue while a later action starts, matching the reference.
- Undo first lifts the ring for 200 ms, then uses the same 260 ms travel and 340 ms drop phases.

### Invalid action

- An invalid destination keeps the ring selected and shakes it horizontally for 300 ms.
- An empty or completed source produces invalid feedback without creating a selection animation.

### Landing response

- The landed ring runs the 1.15 second settle sequence: squash, stretch, small vertical hops, and damped rotation through the reference keyframes.
- The target pole jiggles for 550 ms.
- Rings beneath the landing slot compress and rebound for 700 ms, staggered by 70 ms per distance from the landing ring.

### Hint

- Add a Hint control alongside Undo and Restart while retaining the app's existing app bar sound toggle.
- If a ring is selected, it first drops back. The suggested source and target poles then pulse gold three times over 1.5 seconds and clear at 1.6 seconds.
- If no legal hint exists, play the standard invalid feedback.

### Completed stack

- A newly completed monochrome stack gets persistent green pole glow.
- Its rings jump for 550 ms, staggered by 50 ms from bottom to top.
- Twelve deterministic star particles travel and fade over 900 ms.
- A praise toast (`Sorted!`, `Nice!`, `Great!`, or `Wow!`) rises and fades for one second.
- Trigger the existing success sound/haptic once for the newly completed stack.

### Win

- After the last completed-stack celebration begins, wait 800 ms before showing the win state.
- Eighty deterministic colored confetti pieces fall for 1.6–3.4 seconds with up to 500 ms stagger.
- Use a custom modal transition: fade plus elastic scale from 0.4 to 1 over 550 ms.
- Stars enter with 300/550/800 ms delays. Award three stars at or below par, two at or below 1.5× par, otherwise one.
- The dialog retains the existing earned-coins message and adds moves/par context. Next Level clears all transient effects and runs the intro again.

## Input, Lifecycle, and Cancellation

- Ignore board taps during intro and active travel/drop timelines.
- Disable Undo, Hint, and Restart while a locked animation is active; sound toggle remains available.
- Use monotonically increasing operation tokens for delayed callbacks. Restart, next level, and dispose invalidate old tokens so stale callbacks cannot unlock or mutate a newer board.
- Restart restores the original board, clears selection/history and every transient effect, then replays the intro.
- Reduced-motion mode collapses travel and transient timings to immediate state changes, omits ambient movement/particles/confetti, and still shows completion status and dialog content.

## Audio and Haptics

- Selection, move, undo, invalid action, completed stack, and win continue through the existing `GameAudio` channel.
- Preserve the sound toggle as the single audio gate.
- Haptics follow the same gates already used by the Flutter game. No HTML Web Audio or vibration code is executed.

## Testing

### Domain tests

- Structured results contain correct ring IDs and coordinates for select, deselect, move, invalid, and undo.
- Complete stacks cannot be selected.
- `suggestMove()` follows the matching-first heuristic without mutating state.
- `parMoves` matches literal fixtures.

### Timeline tests

- Sample intro, lift-pop/jelly, transfer, drop, settle, press, shake, wave, hint, toast, sparkle, and confetti at boundary and midpoint times.
- Verify move input lock ends after drop while landing effects remain active.
- Verify newer effects supersede stale effects for the same ring and reset clears all effects.
- Verify reduced motion returns final transforms immediately and no particles.

### Widget/painter tests

- A valid move visually keeps one animated overlay and updates moves once.
- Repeated taps while locked do not mutate the domain.
- Invalid moves retain selection and start shake feedback.
- Undo, Hint, Restart, mute, completed-stack celebration, win delay, stars, and Next Level are covered with controlled time pumping.
- Completed-stack progress animates to the exact completed/color ratio and does not regress during overlapping effects.
- Narrow-screen, large-text, dark-theme, semantics, and reduced-motion cases remain usable.

### Regression verification

- Run focused Rainbow Rings tests during development.
- Run `flutter analyze`, the complete Flutter test suite, and Android/iOS compile checks before completion.

## Expected File Changes

- Modify `lib/features/games/domain/rainbow_rings_game.dart`.
- Modify `lib/features/games/presentation/rainbow_rings_screen.dart`.
- Create `lib/features/games/presentation/rainbow_rings_animation.dart`.
- Create `lib/features/games/presentation/rainbow_rings_painter.dart`.
- Expand `test/features/games/domain/rainbow_rings_game_test.dart`.
- Create focused animation and presentation tests under `test/features/games/presentation/`.
- Do not modify the supplied HTML reference.
