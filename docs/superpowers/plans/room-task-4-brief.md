### Task 4: Migrate Capture and camera without lifecycle regressions

**Files:**

- Create: `lib/features/picker/presentation/acquisition_recovery_scope.dart`.
- Modify: `lib/features/shell/presentation/app_shell.dart`, `lib/features/picker/presentation/{capture_screen,camera_picker_screen}.dart`.
- Modify/test: `test/features/picker/{capture_integration_test,camera_screen_test}.dart`, `test/features/settings/{onboarding_settings_integration_test,settings_modal_contrast_test}.dart`.
- Ownership-race amendment: minimally extend `lib/features/picker/application/photo_acquisition_controller.dart` and its existing `test/features/picker/application/photo_acquisition_controller_test.dart` for additive `request(isActive:)` and synchronous `claim(accept:)` boundaries; no other Task3 refactor.

**Interfaces:**

- `AcquisitionRecoveryScope({super.key, required Widget child})`, placed around the normal indexed shell, never startup/onboarding. It watches committed preferences and calls Task 3 `ensureRecovered()` only after onboarding completes. A direct root-camera acquisition request also awaits that same recovery gate. Repository initialization/recovery errors must become safe coordinator state, not uncaught root-widget errors or navigation changes.
- Capture and live-camera Choose photo call `request(source: PhotoSource.gallery, destination: AcquisitionDestination.capture)` and claim only if their original route/owner remains active. Recovery receipts appear as explicit continuation, not automatic route theft. Room destination receipts are not consumed by Capture.
- Use `claim(accept:)` to check active original ownership and synchronously dispatch/retain pixels inside the acceptance callback after durable clear. Rejection/throw keeps the receipt pending. Camera captures the photo-route future inside that callback, then awaits it outside claim while keeping its camera suspended. Test delayed clear with a hidden/disposed owner, rejection/throw followed by explicit retry, and accepted delivery while the gate remains held. Explicit Continue in Room navigates to `/room` without claiming; Room's receipt consumer is Tasks7/9.
- Pass the original active-owner callback to `request(isActive:)`; delayed recovery/intent saving must not launch a new native picker after that owner hides. Test delayed save plus rejection/throw, including durable intent cleanup and failed-clear retry. Do not claim to cancel an already-started native call.
- Unknown-origin recovery exposes explicit Capture/Room destination actions. An untrusted record without a photo offers confirmed `Dismiss unfinished request`, clearing only operational metadata, never photos/history. Failed dismissal retains the retry state. Do not leave all photo acquisition permanently blocked without a visible resolution action.

- [ ] **Write full-app regressions.** Recovery during onboarding: zero native calls. Delayed Room recovery while Capture is visible: no `/photo` push. Gallery from `/camera`: camera is disposed while picker/photo is open and resumes with fresh samples only after returning active. Two entry points racing use one picker; hidden/disposed owner does not claim or reopen a camera.

```dart
expect(find.byType(OnboardingScreen), findsOneWidget);
expect(picker.recoveries, 0);
expect(picker.picks, 0);
expect(cameras, 0);
```

- [ ] **Observe RED.** Run `flutter test --no-pub test/features/picker/capture_integration_test.dart test/features/picker/camera_screen_test.dart test/features/settings/onboarding_settings_integration_test.dart test/features/settings/settings_modal_contrast_test.dart --reporter expanded`. Prove old Capture recovery consumes an incorrectly owned result or bypasses the shared gate; preserve cancellation/photo sampling coverage.
- [ ] **Implement migration.** Remove Capture's direct `recoverLost()` ownership and route both acquisition callers through the coordinator. Explicit recovery continuation is an intentional safety change; ordinary selected-photo navigation remains the same. Update all four existing `PhotoPickerService` fakes to accept the optional source argument. Add the new in-memory intent-store override to affected full-app test harnesses rather than disabling recovery in production for tests; any additional test-only harness edits must be listed in this owner's report. Do not alter `CameraSession`, `/camera`'s sampler purpose or `/photo`'s PreparedPhoto contract.
- [ ] **Verify GREEN.** Four focused files, scoped analysis and format; inspect coordinator call sites with `rg` to ensure neither screen still invokes adapter `.pick()`/`.recoverLost()` directly.
- [ ] **Record acceptance.** `room-task-4-report.md` states changed recovery behavior and no-onboarding-camera proof. No Room UI/pixel engine edits.

