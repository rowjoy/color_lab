# Read-only acquisition integration map

Prepared by `/root/acquisition_screen_map` for Task4 before its implementation.
Line numbers refer to the pre-migration files; recheck current code before edits.
No source changes or tests were performed for this map.

## Existing ownership

- `capture_screen.dart:35–45`: post-frame direct recovery and automatic `/photo`
  push. Remove this ownership; coordinator recovery requires explicit continuation.
- `capture_screen.dart:62–67`: direct pick/navigation or local retention if hidden.
  Active-owner check at27–30 combines ModalRoute current with `/capture` path;
  indexed branches remain mounted, so keep the path check.
- `camera_picker_screen.dart:196–248`: both Choose photo actions use `_pickPhoto`.
  Before awaiting acquisition it increments epoch, detaches/releases session,
  marks picking, clears current color and awaits serialized cleanup. It awaits
  `/photo` navigation before resuming; resume requires mounted/current/active
  original authority. Preserve these boundaries when adding recovery/claim awaits.
- Camera callbacks use epoch/app-active guards at45–69; cleanup is serialized
  at97–101; lifecycle handling at118–143 must not reopen a hidden/disposed camera.

## Shell and preferences

- `lib/routing/app_router.dart:26–34` guards startup/onboarding; those routes are
  outside the indexed shell at118–125.
- `lib/features/shell/presentation/app_shell.dart:21–22` is the normal-shell
  wrapping point. Recovery must watch committed preferences, not a pending save.
- Root `/camera` at router85–88 can bypass AppShell, so its request independently
  awaits the same coordinator recovery. `/photo` extra remains PreparedPhoto.
- Preference state commits only after successful repository save in
  `app_preferences_providers.dart:84–89`. Replay `/welcome` can overlay a mounted
  shell; do not restart recovery or camera work merely on rebuilding preferences.

## Test harnesses

The four Task4-owned picker fakes need the optional source signature and an
in-memory acquisition-store override in their existing provider harnesses:

- `test/features/picker/capture_integration_test.dart:44–53` (EntryPhotoService).
- `test/features/picker/camera_screen_test.dart:100–111` plus routed harness503–511
  (FakePhotoPicker). Existing cancellation415–439 and photo suspension467–528
  regressions are important. Standalone camera-only harnesses need no eager
  acquisition initialization.
- `test/features/settings/onboarding_settings_integration_test.dart:50–69`
  (_NoPromptPhotoPicker). Preserve zero native calls during first-run onboarding.
- `test/features/settings/settings_modal_contrast_test.dart:42–51`
  (_QuietPhotoPicker).

Other concrete full-app harnesses construct ColorLabApp with onboarding complete
and initially enter Capture, so the new normal-shell storage boundary also needs
an in-memory store override there. Task4's brief permits additional test-only
harness edits if reported explicitly:

- `test/widget_test.dart` (two containers,18/73).
- `test/features/picker/color_details_actions_test.dart:36`.
- `test/features/mixer/presentation/mixer_screen_test.dart:26`.
- `test/features/formula/presentation/formula_integration_test.dart:72`.
- `test/features/harmonies/presentation/harmonies_integration_test.dart:52`.
- `test/features/color_test/presentation/matching_integration_test.dart:46`.
- `test/features/color_test/presentation/vision_integration_test.dart:55`.

This map does not prescribe changes to the core currently owned by Task3 and is
not an independent code-review verdict.
