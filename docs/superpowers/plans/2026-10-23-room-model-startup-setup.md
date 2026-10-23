# Room Model Startup Setup

> Execute inline using superpowers:executing-plans and TDD; one final fresh review.

**Spec / Goal:** On every cold app launch, verify saved room models. Missing or corrupt models download automatically behind a full-screen Room Studio setup gate showing real aggregate progress (1–100%). Only verified completion opens the existing onboarding/home flow. Failures remain gated with Retry. Existing valid files work offline.

**Architecture:** Reuse the pinned GitHub Release and single-flight store. Add a files-only `prepare()` operation so startup does not allocate inference model buffers. A production bootstrap wraps the existing app, consumes a non-autoDispose readiness provider, shows setup/checking/download/verification/error, then permanently hands off to `ColorLabApp` without disturbing its router.

**Global constraints:** No artificial countdown; cap progress at 99 until verified. Keep photos local, models outside APK, licenses intact, current cancellation safeguards and all existing app flows. No new dependencies or model publishing. Work on the existing feature branch; user pushes source manually. Approval already granted; no further approval gate.

### Task 1: Files-only preparation

**Files:** `room_model_store.dart`, `room_model_store_test.dart`.
**Interfaces:** `Future<void> prepare()` shares verification/download with `load()`; only `load()` reads model bytes for inference. Preserve cancellation epochs and single-flight cleanup.

- [ ] Write RED preparation/download, fresh offline validation, corrupt-cache and concurrent prepare/load tests.
- [ ] Implement files-only preparation and run store + segmentation regressions GREEN.
- [ ] Commit scoped changes.

### Task 2: Production startup gate

**Files:** New `lib/bootstrap.dart`, readiness provider, startup widget tests; update `main.dart`, room first-use copy and README.
**Interfaces:** Bootstrap watches preparation and progress using the same store. Inner app never mounts before ready. Verified completion displays 100%, then advances without bypassing onboarding. Errors expose safe Retry; no Skip. Once entered, readiness refreshes cannot remount the app.

- [ ] Write RED gate tests for progress/verification, success, cached launch, safe failure/retry, narrow large-text layout, disposal and stable post-setup app state.
- [ ] Implement minimal themed responsive setup UI and production entry wiring; update documentation.
- [ ] Run focused and whole tests, analysis, formatting and debug Android build.
- [ ] One fresh final review; fix important findings with RED/GREEN; commit and hand off without source push.
