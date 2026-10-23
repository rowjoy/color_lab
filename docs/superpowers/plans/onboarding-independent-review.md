# Onboarding/settings independent review

Reviewed on2026-10-21 against the design/plan, exact lib/test diffs from the preceding Capture source archive, task evidence, relevant installed Flutter/GoRouter APIs and real-font previews. Reviewer was independent of implementation and performed no source mutations or duplicate full-suite/build runs.

## Initial verdict

Overall: **With fixes**. No Critical findings.

- **Important:** small onboarding eyebrow text used primary#6C5CE7 on dark#0E0F13, approximately3.94:1 rather than the required4.5:1. All three dark slides need a readable text foreground with both themes verified.
- **Minor, accepted for repair:** Appearance settings used the nearest branch navigator, leaving AppShell's bottom navigation interactive outside its modal barrier. A user could hide a pending/error-bearing sheet by changing tabs, then open another elsewhere. This was inherited from the prior appearance implementation, but the new global settings/replay flow benefits from a root-navigator sheet and navigation regression.
- Root's follow-up measurement identified the same contrast class in the new inline settings-save error: error#EF4444 on light surface#FFFFFF is below4.5:1. Include it in the same bounded accessibility fix wave, using existing readable text tokens rather than changing global theme tokens.

Task2 spec compliance requires the contrast correction; other tour requirements are satisfied. Task2 quality is approved after that correction. Cross-cutting review found no additional actionable defect in storage durability/merge, startup guards, stable router, replay, theme startup or existing-test adaptation.

## Accepted verification boundaries

Physical screen-reader/predictive-back behavior and native permission UX were explicitly not established by widget tests/static review. These remain device checks, not silently dropped implementation requirements. No device state or saved user data is cleared to obtain a passing run.

## Fix verification

One scoped fix wave made exactly three production changes: onboarding eyebrows use textSecondary, settings-save errors use textPrimary, and the settings modal uses the root navigator. Regression tests read actual rendered text/background colors in both themes and exercise shell hit targets/pointer taps during pending and failed saves.

The fix report at `onboarding-final-fix-report.md` records seven reproduced failures/four passes before the change, followed by eleven passes. Existing replay-return tests remain green.

Independent scoped re-review inspected the exact fix diff, new tests and evidence: **all three findings addressed; Task2 spec compliance Approved; Task2 quality Approved; overall ready Yes; no Critical or Important findings remaining**. No new behavior defect was found in the fix.

Root's fresh delivery run confirms246 full-suite tests, clean analysis,87 formatted Dart files,22 rendered previews and a successful Android debug build. Final APK permission inspection remains unchanged: CAMERA present, no microphone or legacy storage permissions; camera hardware optional. Physical-device boundaries above remain explicit.
