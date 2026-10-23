# SDD ledger — plan: docs/superpowers/plans/2026-10-21-onboarding-settings.md

Scope: user “Next” continues the previously proposed Onboarding + persistent Settings module, step5 of the supplied document. Phase2 and real Room Studio remain out of scope.

Execution notes: no Git repository exists (`git rev-parse` returned fatal not-a-repository), so use the authorized folder and file-scoped reviews/reports. Existing source archives are preserved. Root implements integration while two delegates own disjoint storage/UI paths; parallel work is authorized by the active collaboration instructions. No new dependencies or native permissions.

## Preflight

| Task pair / task | Produced / consumed contract | Check |
| --- | --- | --- |
| 1 / 3 | AppPreferences + provider/controller + persistent themeModeProvider | Exact ThemeMode/completion/method/schema names in plan; root owns router and settings UI |
| 2 / 3 | OnboardingScreen async onFinish/isReplay | Root persists or pops; widget never navigates itself |
| 1 / 2 | No direct dependency | Tour widget has no native/provider side effects |
| 1 | Tests vs implementation | Durable file reopen, pending flush, provider lifecycle/retry and merged edits required |
| 2 | Tests vs implementation | Async busy/failure, all slides, accessibility and reduced-motion required |
| 3 | Tests vs implementation | Existing tests seed completed preferences; guards and replay preserve router/tab/history state |

Task1: implemented, scoped20 tests and analysis pass; independent task review: spec compliant and quality approved. Reviewer inspected the owned diff; no must-fix findings. Factory/memory-cache/durability behavior is in `preferences-storage-report.md`.

Task2: implemented, scoped19 tests and analysis pass; tour report is `onboarding-ui-report.md`. Final independent review will cover its spec/quality gate together with integrated behavior.

Task3: integrated; root settings/onboarding scoped42 tests pass, including actual-disk close/reopen across fresh ProviderContainers, saved-dark first Capture frame, camera guard/no permission calls, first-run completion retry, replay preserving Lab/history, safe startup retry, and enlarged settings UI. Whole-project analysis currently clean; both theme render cases generate22 previews. Final review/build/suite/package pending.

Final whole-module review: no Critical defects. Task2 needs readable eyebrow contrast (3.94:1 on dark); root also includes the same below4.5:1 contrast class in light settings-error text. Inherited nested Appearance modal leaves bottom tabs active; accepted for a root-navigator fix rather than deferral because it can hide new saving/error feedback. One bounded fix wave owns these changes/tests, followed by one independent scoped re-review. Other cross-cutting code approved. Physical screen-reader/predictive-back/native permission behavior stays explicitly unverified.

Pre-fix root full verification:235 tests passed, analyzer clean,85 Dart files formatted,22 previews rendered, debug APK built. Final APK capabilities unchanged (CAMERA present, no audio or legacy read/write storage). These results are not substituted for the required post-fix delivery run.

## Final completion

Task 1: complete — independent storage review spec compliant/quality approved,20 focused tests and actual-file durability evidence.

Task 2: complete — three-slide presentation19 tests; final11 contrast/modal regressions reproduced seven RED failures then passed; independent scoped re-review approved all fixes and Task2 spec/quality.

Task 3: complete — stable startup/router and durable Appearance/replay integrated; full existing workflows remain green. Settings now overlays the entire shell through the root navigator. Readable text tokens replace below4.5:1 accent/error foregrounds without changing global theme tokens.

Fresh root delivery commands, all exit0:

- `flutter test --reporter expanded`: **246 passed**, zero failures.
- `flutter analyze`: **No issues found**.
- `dart format --output=none --set-exit-if-changed lib test tool`: **87 files,0 changes**.
- `flutter test tool/render_previews.dart --reporter expanded`: both render cases passed, **22 PNGs**; first/third onboarding and settings previews visually inspected, including the corrected root-modal preview.
- `flutter build apk --debug`: built `build/app/outputs/flutter-apk/app-debug.apk`.
- `aapt dump permissions` and merged-manifest inspection: unchanged camera-only feature access, no audio/legacy storage, optional camera hardware.
- `plutil -lint ios/Runner/Info.plist` and `ruby -c ios/Podfile`: pass; no iOS build/device claim.

Source handoff: `dist/color-lab-onboarding-settings-2026-10-21.zip`, integrity checked after creation. All previous archives preserved. No user/device data was cleared. Phase1 implementation is complete; physical-device validation remains explicit, and Phase2 mixer is next.

## Test-first/debugging evidence

- Baseline full suite:186 passed before product edits.
- Root's initial integration test run failed with expected missing preference/onboarding APIs. The tour task separately used an empty public widget shell to establish18 behavioral REDs before full implementation.
- A dedicated first-Capture-frame test observed expectedDark/actualLight even though settled theme tests passed. Installed MaterialApp source uses AnimatedTheme during mode changes: the initial stored-mode load interpolated from temporary System. App now skips only the initial theme animation and honors reduced motion on later changes; that exact regression passed after the correction.
- Preferences async providers disable Riverpod automatic retry to make safe explicit-retry startup errors visible immediately. Interrupted implementation-time full suites were recorded by delegates; final root verification replaces those transient observations.
- No native device state or user data changed during this module. Device-specific camera/iOS limits from the prior module still apply.
