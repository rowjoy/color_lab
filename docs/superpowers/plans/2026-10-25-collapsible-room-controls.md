# Collapsible Room Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give illustrated-room users a full-viewport, distraction-free preview with color tools that can be shown and hidden predictably on phones, tablets and short landscape screens.

**Architecture:** Keep rail/focus state local to `IllustratedRoomScreen`; it is presentation state, not part of a saved room design. The SVG scene remains full-viewport while an animated, semantics-safe rail overlays it. Existing fit, draft, export and persistence controllers remain unchanged.

**Tech Stack:** Flutter widgets, Riverpod, GoRouter, `flutter_svg`, Flutter widget tests and the guarded deterministic preview harness.

**Spec:** `docs/superpowers/specs/2026-10-25-collapsible-room-controls-design.md`

## Global Constraints

- Below 720dp the rail starts hidden; at 720dp and above it starts visible.
- Show/hide and focus/exit actions use exact semantic labels and keys from this plan, with at least 48dp targets.
- Hidden controls must be absent from hit testing and the semantics tree.
- `Fill screen` remains `BoxFit.cover`; `See whole room` remains `BoxFit.contain`.
- Focus Preview hides app chrome but must not change fit, draft, selected colors, saved identity or native system-bar mode.
- Hiding the rail closes its flyout; focus exits before flyout/rail/dirty-draft Back handling.
- All motion uses `AppMotion.duration(context)` and therefore respects reduced motion.
- Do not add dependencies, platform metadata or persistence fields.
- Do not run an app/native build. Every Flutter test/analyze command stays inside `tool/deny-native-compilers.sb`.

## Review Focus

- A 320×568 phone at 2x text must expose every toggle without overflow; Task 1 adds this widget regression.
- A 640×360 landscape must keep the rail scrollable and the hide action reachable; Task 1 tests it.
- Back and scene taps with focus, flyout and compact rail stacked must dismiss exactly one UI layer in the specified order; Task 1 tests each transition.
- Crossing the 720dp breakpoint must follow the default until the user explicitly chooses a rail state, then preserve that choice; Task 1 tests resizing.
- Entering/exiting focus must restore the prior rail state and unchanged fit/draft identity while hidden chrome has no semantics or hit targets; Task 1 tests restoration and semantics.

---

### Task 1: Collapsible rail and Focus Preview interaction

**Files:**
- Modify: `lib/features/room_studio/presentation/illustrated_room_screen.dart`
- Modify: `lib/features/room_studio/presentation/illustrated_room_controls.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_screen_test.dart`
- Modify: `test/features/room_studio/presentation/illustrated_room_integration_test.dart`

**Interfaces:**
- Consumes: `IllustratedRoomViewMode`, `IllustratedRoomColorRail`, `_ViewModeControl`, existing `_goBack`, `_activeTool`, `AppMotion.duration(BuildContext)` and the unchanged illustrated-room providers.
- Produces: keys `room-show-color-tools`, `room-hide-color-tools`, `room-focus-preview`, `room-exit-focus-preview`; exact semantic labels matching those keys' visible intent; `IllustratedRoomColorRail.onHide`; responsive rail/focus behavior used by Task 2 previews.

- [ ] **Step 1: Write failing phone/tablet rail tests**

  In `illustrated_room_screen_test.dart`, add tests named:

  - `phone starts with full-width scene and hidden rail then toggles tools`
  - `tablet starts with rail visible and can hide and show it`
  - `explicit rail choice survives crossing the 720dp breakpoint`

  Assert the full `room-scene` rect never changes; phone initially has no hit-testable/semantic rail actions and has `room-show-color-tools`; showing reveals `room-color-rail` and `room-hide-color-tools`; hiding removes rail hit testing/semantics and closes `room-flyout`. Assert tablet starts visible. Resize 719→720 before a choice to get the new default, then assert an explicit hide/show remains stable across another resize.

- [ ] **Step 2: Run the new rail tests to verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_screen_test.dart --plain-name 'phone starts with full-width scene and hidden rail then toggles tools' --reporter expanded
  ```

  Expected: FAIL because `room-show-color-tools` and hide/show state do not exist.

- [ ] **Step 3: Add local rail state and rail controls**

  In `_IllustratedRoomScreenState`, add:

  ```dart
  bool? _railVisibleOverride;
  bool _focusPreview = false;
  bool? _railVisibleBeforeFocus;

  bool _railVisibleFor(double width);
  void _showColorRail();
  void _hideColorRail();
  ```

  `_railVisibleFor` returns the explicit override when present, otherwise `width >= 720`. Reset these fields when `templateId` changes. `_hideColorRail` also clears `_activeTool`.

  Add required `VoidCallback onHide` to `IllustratedRoomColorRail` and render a first 48dp rail action keyed `room-hide-color-tools`, labelled `Hide color tools`. When hidden, keep the animated rail out of hit testing and semantics. Render a 48dp overlay action keyed `room-show-color-tools`, labelled `Show color tools`. Use `AnimatedSlide`/`AnimatedOpacity` with `AppMotion.duration(context)`; the positioned overlay must never change the scene constraints.

- [ ] **Step 4: Run all new rail tests to verify GREEN**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_screen_test.dart --plain-name 'rail' --reporter expanded
  ```

  Expected: all matching tests PASS with no overflow or semantics exception.

- [ ] **Step 5: Write failing Focus Preview and dismissal-order tests**

  Add tests named:

  - `Focus Preview hides chrome and restores rail fit and exact draft`
  - `Back exits focus then flyout then compact rail before dirty exit`
  - `scene tap closes a compact rail and its flyout`
  - `320dp phone at 2x text keeps controls reachable without overflow`
  - `640x360 landscape keeps rail scrollable and hide reachable`

  Focus assertions: `room-editor-back`, `room-editor-title`, `room-view-fill`, `room-view-full`, `room-color-rail` and `room-flyout` are not hit-testable or semantic; `room-exit-focus-preview` is present and at least 48dp; exit restores the prior rail visibility, the same `IllustratedRoomDraft` instance and the prior `IllustratedRoomSvg.fit`.

  Back assertions use `handlePopRoute()` one step at a time and prove no navigation/draft mutation until focus, flyout and compact rail are each dismissed. The integration test must prove the routed editor remains at `/room/illustrated/study` through those dismissals.

- [ ] **Step 6: Run one Focus Preview test to verify RED**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_screen_test.dart --plain-name 'Focus Preview hides chrome and restores rail fit and exact draft' --reporter expanded
  ```

  Expected: FAIL because Focus Preview controls do not exist.

- [ ] **Step 7: Implement Focus Preview and interaction ordering**

  Add:

  ```dart
  void _enterFocusPreview({required bool railVisible});
  void _exitFocusPreview();
  ```

  Entering stores `railVisible`, clears `_activeTool`, hides the rail and sets `_focusPreview`. Exiting restores the stored rail state without changing `_viewMode` or providers. Update `_goBack` in exact order: focus → flyout → visible compact rail → existing dirty-exit flow. Scene tap clears the flyout and, on compact layouts, hides the rail.

  Extend `_ViewModeControl` with `VoidCallback onFocusPreview` and a 48dp `room-focus-preview` action labelled `Focus preview`. Rename the current `Full room` semantic/tooltip label to `See whole room` while preserving key `room-view-full` and `BoxFit.contain`. During focus, render only the full scene plus a safe-area 48dp `room-exit-focus-preview` action labelled `Exit focus preview`.

- [ ] **Step 8: Run complete editor and routed integration tests**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/illustrated_room_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart --reporter expanded
  ```

  Expected: all PASS; no Gallery channel is reached; export, saved-design and dirty-draft tests remain unchanged.

- [ ] **Step 9: Checkpoint the interaction change**

  Stage only the four reviewed paths and commit `feat: add collapsible room controls` if they can be isolated from pre-existing user changes. Otherwise record the skipped checkpoint and reason in the execution ledger without staging.

### Task 2: Deterministic previews, documentation and final verification

**Files:**
- Modify: `tool/render_illustrated_room_previews.dart`
- Modify: `README.md`
- Create: `build/previews/illustrated-room-editor-phone-focus.png` (generated, ignored)
- Modify: `build/previews/illustrated-room-render-manifest.json` (generated, ignored)

**Interfaces:**
- Consumes: Task 1 keys and responsive defaults.
- Produces: a 19-file deterministic manifest and current user instructions for showing/hiding controls and Focus Preview.

- [ ] **Step 1: Update preview scenarios before production verification**

  Keep `illustrated-room-editor-phone-rail-closed.png` but redefine it as the initial hidden-rail phone state. For `illustrated-room-editor-phone-rail-open.png`, tap `room-show-color-tools`, then open Looks. Add `illustrated-room-editor-phone-focus.png` after tapping `room-focus-preview`. Update `_expectedNames` and manifest count from 18 to 19.

- [ ] **Step 2: Run guarded preview generation**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub tool/render_illustrated_room_previews.dart --reporter expanded
  ```

  Expected: six preview tests PASS and exactly 19 manifest-listed PNGs are written.

- [ ] **Step 3: Inspect the three phone editor previews**

  Visually verify that the hidden state gives the scene the entire phone width, the open state has an obvious close action and readable controls, Focus Preview contains only artwork plus the exit action, and none has overflow, clipped labels or a watermark.

- [ ] **Step 4: Update README**

  In `Illustrated room color gallery`, document phone default-hidden color tools, tablet default-visible tools, Show/Hide controls, Focus Preview, the difference between Fill screen and See whole room, session-only UI state and unchanged Gallery/design persistence. Update the preview evidence count and list from 18 to 19.

- [ ] **Step 5: Run exact-path formatting and analysis**

  ```sh
  /Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib/features/room_studio/presentation/illustrated_room_screen.dart lib/features/room_studio/presentation/illustrated_room_controls.dart test/features/room_studio/presentation/illustrated_room_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart tool/render_illustrated_room_previews.dart
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub lib/features/room_studio/presentation/illustrated_room_screen.dart lib/features/room_studio/presentation/illustrated_room_controls.dart test/features/room_studio/presentation/illustrated_room_screen_test.dart test/features/room_studio/presentation/illustrated_room_integration_test.dart tool/render_illustrated_room_previews.dart
  ```

  Expected: formatting exit 0 and analysis `No issues found!`.

- [ ] **Step 6: Run focused illustrated-room regression**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation test/features/room_studio/application/illustrated_room_export_controller_test.dart test/features/room_studio/application/room_gallery_writer_test.dart --reporter expanded
  ```

  Expected: all PASS with no native Gallery channel.

- [ ] **Step 7: Run whole-project tests and analysis without building**

  ```sh
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
  /usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub
  ```

  Compare with the current dirty-worktree baseline: 1,447 passes and 38 unrelated Games failures; full analysis has one unrelated `fruit_pop_screen.dart` info. Report any difference and do not edit unrelated Games work. Do not weaken the native-compiler guard.

- [ ] **Step 8: Request fresh review and checkpoint docs/evidence source**

  Review state ordering, responsive hit testing/semantics, reduced motion and preview accuracy. Resolve only verified in-scope findings and rerun affected checks. Stage only Task 2 source/doc paths and commit `test: verify collapsible room controls` if ownership is clean; otherwise ledger the skipped checkpoint.
