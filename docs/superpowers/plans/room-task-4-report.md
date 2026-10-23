# Task 4 implementation report

Status: DONE. Commits: none. Implemented the amended Task4 brief only; controller authorized the two additive coordinator callbacks. Source compared with `/private/tmp/color-lab-task4-base.QQodkA/source`; that baseline was not modified.

## Result

Capture no longer calls the picker adapter's `pick` or `recoverLost`. The normal shell starts coordinator recovery only after committed onboarding preferences, and skips startup/onboarding/welcome paths. Storage/recovery exceptions remain safe coordinator states with visible retry controls. Root camera gallery requests await the same recovery gate.

Both gallery callers request `PhotoSource.gallery` for `AcquisitionDestination.capture`. `request(isActive:)` checks the original owner before request-triggered initialization, after recovery/store acquisition, and after intent persistence immediately before native launch. False/throw cancels without opening the picker; a saved intent is durably cleared, and failed cleanup retains the storage retry barrier. Already-started native calls are not cancelled.

`claim(accept:)` clears operational metadata, then invokes the synchronous acceptance callback while the gate and receipt are still held. The UI rechecks mounted/current/foreground ownership and dispatches navigation inside that callback. Rejection/throw retains the same in-memory prepared receipt for later explicit continuation, even if its operational metadata has already been cleared. Existing callers without either callback retain their compatible behavior.

Capture uses `GoRouter.state.uri.path` rather than the route-information URI: imperative root pushes can leave the latter at the underlying Capture URI. Late, background, recovered, and unknown results do not auto-navigate. Capture never claims a Room receipt. Unknown receipts show Capture and Room continuation actions; Continue in Room navigates without claiming, leaving the receipt for the specified Tasks7/9 consumer. An untrusted request without a photo requires confirmed Dismiss unfinished request. Failed dismissal shows Retry photo request and preserves the need for explicit disposition.

Camera preserves serialized disposal, epochs, permission handling, and sampling. It disposes before gallery/recovery awaits, stays suspended through the actual photo route, and resumes with fresh samples only after returning active. Covering it with welcome also releases its native session. The photo-navigation Future is captured inside the synchronous claim acceptance callback and awaited outside claim.

## Files

Production files (five):

- `lib/features/picker/presentation/acquisition_recovery_scope.dart` — new normal-shell recovery boundary.
- `lib/features/shell/presentation/app_shell.dart` — wraps normal indexed content in that boundary.
- `lib/features/picker/presentation/capture_screen.dart` — coordinator ownership, explicit continuation/disposition/retry controls, foreground and actual route checks.
- `lib/features/picker/presentation/camera_picker_screen.dart` — coordinator migration, guarded delivery, covered-route suspension.
- `lib/features/picker/application/photo_acquisition_controller.dart` — authorized additive `request(isActive:)` and `claim(accept:)` only.

Task-owned tests:

- `test/features/picker/capture_integration_test.dart` — full-app ownership/recovery/foreground/claim/save races, metadata confirmation and retries, actual photo navigation, 360dp/2x themes. Added delayed in-memory store and camera/native-picker boundary fakes, and a deterministic color-namer provider override so real photo screens settle without asynchronous asset loading.
- `test/features/picker/camera_screen_test.dart` — source-compatible picker fake, in-memory intent-store overrides, direct-camera recovery gate regression; existing cancellation, sampler, permission, disposal, and photo-return tests preserved.
- `test/features/settings/onboarding_settings_integration_test.dart` — compatible fake/store harness; pending and failed onboarding writes cause zero recovery/picker/camera calls until commit.
- `test/features/settings/settings_modal_contrast_test.dart` — compatible fake and in-memory intent-store harness.
- `test/features/picker/application/photo_acquisition_controller_test.dart` — authorized ownership-callback tests, rejection/throw, gate-held delivery, delayed save/recovery cancellation and failed-clear retry.

Every additional test-only harness edit (seven files):

- `test/widget_test.dart` — intent-store override in both full-app containers.
- `test/features/picker/color_details_actions_test.dart` — intent-store override.
- `test/features/mixer/presentation/mixer_screen_test.dart` — intent-store override.
- `test/features/formula/presentation/formula_integration_test.dart` — intent-store override.
- `test/features/harmonies/presentation/harmonies_integration_test.dart` — intent-store override.
- `test/features/color_test/presentation/matching_integration_test.dart` — intent-store override.
- `test/features/color_test/presentation/vision_integration_test.dart` — intent-store override.

The shared `test/support/in_memory_acquisition_intent_store.dart` was consumed unchanged. No production bypasses were introduced for tests.

## TDD evidence

Exact required four-file command, used for RED and final GREEN:

```sh
flutter test --no-pub test/features/picker/capture_integration_test.dart test/features/picker/camera_screen_test.dart test/features/settings/onboarding_settings_integration_test.dart test/features/settings/settings_modal_contrast_test.dart --reporter expanded
```

RED: exit 1, 33 passed / 2 failed, `/private/tmp/color-lab-task4-red.log`. All four source-signature fakes were already fixed; this was not a compilation-error RED. The shared-gate regression failed with native picker calls `Actual: 1`, `Expected: 0` while recovery was pending. The Room recovery regression timed out in `pumpAndSettle` after the old screen opened Photo and the original harness lacked a color-namer override; it did not reach its route assertion. The native-call assertion is the direct pre-implementation behavioral proof. Final Room ownership assertions pass with the corrected harness.

Final GREEN: exit 0, 49 passed / 0 failed, `/private/tmp/color-lab-task4-green.log`.

Claim ownership RED/GREEN command:

```sh
flutter test --no-pub test/features/picker/application/photo_acquisition_controller_test.dart --reporter expanded
```

Claim RED: exit 1, 13 passed / 4 failed, `/private/tmp/color-lab-task4-claim-red.log`. Only the optional argument seam was added before this run; old disposal behavior still ignored acceptance. Hidden/rejected/throwing delivery returned a photo instead of null and lost the pending receipt; accepted-delivery callback was never invoked (`false` instead of `true`). The subsequent implementation now retains rejected receipts and invokes acceptance with the gate/pending receipt held.

Native-launch/foreground RED command:

```sh
flutter test --no-pub test/features/picker/application/photo_acquisition_controller_test.dart test/features/picker/capture_integration_test.dart --reporter expanded
```

Exit 1, 33 passed / 6 failed, `/private/tmp/color-lab-task4-launch-guard-red.log`. The optional request argument seam was present but ignored. Inactive/throwing owner tests and delayed-save cleanup tests returned Acquired instead of cancellation/storage failure; welcome-during-save launched one picker instead of zero; background Capture opened `/photo` instead of remaining `/capture`. Guards were implemented after this observed RED.

Final core GREEN: exit 0, 22 passed / 0 failed, `/private/tmp/color-lab-task4-core-green.log`.

Additional diagnostic iterations are recorded honestly:

- `flutter test --no-pub test/features/picker/capture_integration_test.dart --reporter expanded`, `/private/tmp/color-lab-task4-camera-overlay-red.log`: exit 1, 7 passed / 4 failed. Welcome overlay had the genuine expected disposal 1 / actual 0 failure before route suspension. Three other tests had temporary harness pumping/asset-loading timeouts, subsequently corrected using bounded pumps for pending operations and the deterministic color-namer override.
- Expanded five-file runs (the four-file command above plus `test/features/picker/application/photo_acquisition_controller_test.dart` before `--reporter expanded`): `focus-work2.log` had 59 passed / 2 photo-screen harness timeouts; `focus-work3.log` had 46 passed / 1 capture-test load failure from the newly added color-namer override's missing import. Both were fixed; `focus-work4.log` passed 62/62 and `focus-work5.log` passed 69/69 before the final two added ownership regressions. Log prefix is `/private/tmp/color-lab-task4-`.
- Initial scoped analysis reported five brace-style infos in the migrated camera method; all were fixed before final analysis.
- The first non-escalated Flutter invocation could not update the standard SDK cache stamp. Subsequent approved tool runs used the installed SDK normally; no SDK or pub-cache source patching occurred.

## Final verification

```sh
flutter analyze --no-pub lib/features/picker/presentation lib/features/picker/application/photo_acquisition_controller.dart lib/features/shell/presentation/app_shell.dart test/features/picker/capture_integration_test.dart test/features/picker/camera_screen_test.dart test/features/picker/application/photo_acquisition_controller_test.dart test/features/settings/onboarding_settings_integration_test.dart test/features/settings/settings_modal_contrast_test.dart test/widget_test.dart test/features/picker/color_details_actions_test.dart test/features/mixer/presentation/mixer_screen_test.dart test/features/formula/presentation/formula_integration_test.dart test/features/harmonies/presentation/harmonies_integration_test.dart test/features/color_test/presentation/matching_integration_test.dart test/features/color_test/presentation/vision_integration_test.dart
dart format --output=none --set-exit-if-changed lib test
flutter test --no-pub --reporter expanded
```

- Scoped analyzer: exit 0, no issues; `/private/tmp/color-lab-task4-analyze.log`.
- Global formatter check: exit 0, 164 files / 0 changed; `/private/tmp/color-lab-task4-format.log`.
- One fresh full suite after the final functional/test changes: exit 0, 660 passed / 0 failed; `/private/tmp/color-lab-task4-full-suite.log`. All six baseline load failures are resolved. No further functional changes followed this run.
- `rg -n '\.pick\(|\.recoverLost\(|\.request\(|\.claim\(' lib/features/picker/presentation/capture_screen.dart lib/features/picker/presentation/camera_picker_screen.dart` found only coordinator request/claim calls, no direct adapter pick/recovery calls.

## Acceptance and self-review

- Initial onboarding and attempted camera deep-link: OnboardingScreen visible; recovery calls 0, picker calls 0, cameras 0. Pending/failed completion saves retain all zero counts; successful committed completion starts recovery once without creating a camera or opening a picker.
- Delayed Room recovery leaves `/capture` visible and retains Room intent/receipt. Recovery while another tab or color-entry sheet is visible never steals navigation.
- Capture and camera racing invoke one picker. Hidden Capture and hidden/disposed camera leave receipts pending. Delayed durable clear checks ownership inside synchronous acceptance, so no prepared pixels are lost in the await gap.
- Background Capture retains selected pixels and requires explicit continuation after resume. Welcome during delayed save cancels before native launch; failed cleanup remains retryable.
- Actual full-app `/camera` → gallery → `/photo` → camera test proves disposal before picker, no reopening during photo/background/resume, and no stale sample on return. Existing camera epoch/permission/serialized-cleanup tests remain passing. Direct standalone camera request waits for coordinator recovery before gallery launch.
- Unknown-origin actions are usable at 360dp with 2x text in both light and dark themes, with at least 48dp action heights and no widget exceptions. Existing themed controls/tokens are reused. Confirmed metadata dismissal, cancel, failed clear, retry, and repeated explicit confirmation are exercised without deleting photos/history.
- Source diff is limited to the five production and twelve test paths above. No Room UI, room pixels, manual selection, or AI implementation changed. No fake AI proof claims. Room receipt consumption remains the specified later Tasks7/9 handoff.
- `/camera` remains the live color sampler; `/photo` still receives PreparedPhoto. CameraSession and native camera APIs are unchanged. Acquisition 24MiB, processing 32MiB, 24Mpixel, 16384-axis, working-1600, alpha-to-white, orientation and aspect behavior were not changed. Android24/iOS13 remain unchanged.
- No native build/APK/install/clean/data clear, Git initialization/worktrees/commits, SDK/pub-cache hacks, or artifact deletion. Existing APK and nine ZIP artifacts were not edited. No unresolved correctness concerns found in self-review. Camera and Capture retain their existing large presentation files; no unrelated restructuring was performed.
