# Final onboarding/settings review fixes

The authorized final review fixes are complete. This wave changes five files:

- `lib/features/onboarding/presentation/onboarding_screen.dart`
- `lib/features/settings/presentation/settings_sheet.dart`
- `test/features/onboarding/onboarding_contrast_test.dart` (new)
- `test/features/settings/settings_modal_contrast_test.dart` (new)
- `docs/superpowers/plans/onboarding-final-fix-report.md` (new report)

## Production changes

Exactly three production changes address the reviewed behavior:

1. All three onboarding eyebrow labels use the existing `textSecondary` token instead of `primary`, matching the readable small-text convention elsewhere in the app.
2. The settings failed-save message uses the existing `textPrimary` token instead of the error accent color, retaining its friendly wording and live-region announcement.
3. `showAppSettings` supplies `useRootNavigator: true` to `showModalBottomSheet`, so the settings modal and its barrier cover the shell's bottom navigation. The outer tab controls can no longer switch branches behind pending or failed-save feedback.

No global tokens, other features, dependencies, routing, existing integration tests, or other files were modified in this wave. Test-driven-development and systematic-debugging were used to reproduce the reviewed failures before the fixes; verification-before-completion required the fresh passing results below.

## Regression coverage and RED evidence

Read `test/support/in_memory_app_preferences_repository.dart` before using its `failSave` and `saveGate` injection points. The production controller, app, theme, router, shell, settings, and rendering remain real in the settings regressions; only storage/history and native photo access are replaced at their boundaries.

Before changing production code, ran:

`flutter test test/features/onboarding/onboarding_contrast_test.dart test/features/settings/settings_modal_contrast_test.dart`

Result: **4 passing / 7 failing**, exit **1**, with the following expected failures:

- `slide 1 small label has 4.5 contrast in dark`
- `slide 2 small label has 4.5 contrast in dark`
- `slide 3 small label has 4.5 contrast in dark`

  All three measured the actual rendered label foreground and scaffold background at **3.942329901686246:1**, below the required **4.5:1**.

- `failed-save text has 4.5 contrast in light settings`

  After an actual failed repository save, measured the error paragraph foreground and its enclosing Material background at **3.763127680148142:1**, below **4.5:1**.

- `settings modal prevents hit testing every studio tab`

  The actual `nav-Capture` InkWell remained hit-testable while settings was open; the test checks all four tabs after the fix.

- `tab-position tap cannot hide a pending appearance save`
- `tab-position tap cannot hide an appearance save error`

  Both captured the real Lab-tab screen position before opening settings, attempted a pointer tap at that position while feedback was present, and observed the app route incorrectly change from `/capture` to `/lab`.

The four already-passing cases were the three light-theme onboarding labels and the dark-theme settings error. Those controls remain covered to prevent fixing one theme at the expense of the other.

## GREEN and final verification

- Reran the same two new regression files after the three production edits: **11 passing / 0 failing**, exit **0**. Actual rendered contrast now meets **4.5:1** in both themes for every affected label. All four studio tabs are excluded from hit testing while settings is modal; pointer taps at the Lab-tab position retain `/capture` during both pending and failed writes, with their feedback still present.
- `dart format lib/features/onboarding/presentation/onboarding_screen.dart lib/features/settings/presentation/settings_sheet.dart test/features/onboarding/onboarding_contrast_test.dart test/features/settings/settings_modal_contrast_test.dart`: **4 checked / 1 formatted**, exit **0**; only formatting of the new settings test changed.
- `flutter test test/features/onboarding test/features/settings`: **53 passing / 0 failing**, exit **0**, including the unchanged replay-return integration that preserves Lab's edited color, saved colors, completion, and theme.
- `flutter analyze lib/features/onboarding/presentation lib/features/settings/presentation/settings_sheet.dart test/features/onboarding test/features/settings`: **No issues found**, exit **0**.
- Fresh full project `flutter test`: **246 passing / 0 failing**, exit **0**.
- Final `dart format --output=none --set-exit-if-changed` against the same four Dart files: **4 checked / 0 changed**, exit **0**.

No unresolved failure or implementation concern remains in this fix wave. Native visual verification, independent review, rebuilt APK, refreshed previews, and final packaging remain with the root delivery task; this report does not claim those later checks were performed by this agent.
