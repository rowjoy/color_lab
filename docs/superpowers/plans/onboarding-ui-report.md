# Onboarding presentation handoff

Task 2 is implemented within its assigned files. The brief and the approved onboarding/settings design were read before implementation. Test-driven-development, its writing-good-tests reference, systematic-debugging, and verification-before-completion guided implementation and verification.

## Files

- `lib/features/onboarding/presentation/onboarding_screen.dart`: presentation-only, three-slide `OnboardingScreen({super.key, required Future<void> Function() onFinish, bool isReplay = false})`.
- `lib/features/onboarding/presentation/onboarding_art.dart`: static, procedural camera/photo, personal-library, and privacy illustrations drawn with theme tokens.
- `test/features/onboarding/onboarding_screen_test.dart`: 19 widget tests covering navigation, completion, errors, disposal, replay, motion, themes, and constrained layouts.
- `docs/superpowers/plans/onboarding-ui-report.md`: this report.

No dependencies, routing, settings, preferences, native plugins, platform configuration, other tests, or Git state were changed by this task.

## Delivered behavior

The three English titles are `Find your next shade.`, `A little library of you.`, and `Your curiosity. Your control.` Their descriptions cover camera/photo exploration, an offline personal color library, and on-device processing with permission requested only when the user chooses the corresponding feature. The presentation makes no claim about room-photo editing or a working Room feature.

Slides use existing bundled typography, spacing/radius/motion/color tokens, and shared PrimaryButton, SecondaryButton, and IconCircleButton controls. Controls retain at least 48dp height; Back is 48dp square. The decorative art is excluded from accessibility semantics. The current step has an explicit live `Step N of 3` label, and slide titles are semantic headings. Content scrolls independently of the anchored header and footer, so Skip and the primary action remain reachable at large text sizes and in short landscape. Reduced motion jumps directly between pages, and the existing shared progress indicator becomes static under that setting.

Next, Back, and horizontal swipes navigate the tour. Skip works from every slide. The final button says `Get started`, or `Done` in replay. The injected callback is invoked once per pending attempt and awaited. Beginning completion cancels any current slide movement; navigation, gestures, Skip, the primary action, and route/system back are disabled until the callback resolves. First-run system back moves to a previous slide where possible; replay allows the caller's normal route back when idle. The widget never pops a route or calls a router itself.

Callback failure retains the current slide and exposes a friendly inline live error: `We couldn’t finish the tour. Please try again.` The primary action becomes `Try again`; raw exception details are never shown. Late callback success and failure are safe after widget disposal. Persistence and navigation remain entirely owned by the parent callback.

## RED / GREEN evidence

1. Wrote the initial 18 behavioral tests before implementation. `flutter test test/features/onboarding/onboarding_screen_test.dart` first exited 1 because the requested implementation file/class did not exist.
2. Added only the public widget shell with an empty Scaffold, then reran the same command. It exited 1 with **0 passing / 18 failing** tests: the first assertion could not find `Find your next shade.`, and remaining navigation/completion/layout assertions failed because the controls and content were absent. This established behavioral RED beyond the initial missing-file compilation error.
3. Implemented the tour and illustrations. The first implementation run exited 1 with **14 passing / 4 failing** tests:
   - `Next, Back, and swipe move through all three tour steps`: test-created SemanticsHandle was disposed too late; cleanup was moved before end-of-test verification.
   - `reduced motion changes steps without a transition`: the test incorrectly treated the shared InkWell tap ripple's scheduled frame as a page animation. It now verifies the next page's immediate full-screen position and visible title after one frame.
   - `360px portrait at 2x text is usable in light` and the corresponding `dark` case: fixed-width header/step children overflowed by 95px and 22px with the test font. The brand and step label now receive flexible width.
4. Reran the scoped command: **18 passing / 0 failing**, exit 0.
5. Added an actual replay-route test that holds completion pending, verifies route back is blocked, then verifies idle back returns to the previous screen without automatic popping after completion. The scoped command passed **19/19**, exit 0.
6. Formatted the three assigned Dart files with `dart format`; **3 files formatted**, exit 0.
7. `flutter analyze lib/features/onboarding/presentation test/features/onboarding`: **No issues found**, exit 0.
8. Fresh complete project command `flutter test`: **234 passing / 0 failing**, exit 0. This run included the current concurrent root/preferences integration, legacy flows, and all 19 onboarding tests. Earlier concurrent runs that observed the four intermediate onboarding failures predated the fixes above; the fresh full run resolves those observations.
9. Final `dart format --output=none --set-exit-if-changed` against the three assigned Dart files: **3 files checked / 0 changed**, exit 0.

The six layout cases cover every slide in light and dark at 360×800 with 2× text, 800×360 with normal text, and 800×360 with 2× text. The other 13 tests cover Next/Back/swipe and semantics, Skip from each of three slides, pending final callback deduplication, pending swipe/control/system-back locks, safe error retry, disposal on both success and failure, replay Done, first-run back, actual replay route-back locking, and reduced motion.

## Integration and verification boundaries

Stable page keys are `onboarding-page-0`, `onboarding-page-1`, and `onboarding-page-2`. Literal actions remain `Skip`, `Next`, `Get started`, and replay `Done`; failure uses `Try again`. The widget imports no providers, plugins, or router. Parent routing must continue to persist first-run completion before entering Capture and to close replay in its callback.

No unresolved UI concern was found in scoped tests or the fresh full suite. Widget tests render both themes but are not a substitute for native screen-reader, system-back gesture, and physical-device visual checks; app build, native verification, preview capture, and cumulative ZIP packaging remain with the root task.
