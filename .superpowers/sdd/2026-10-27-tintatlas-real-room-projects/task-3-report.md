# Plan 02 Task 3 — Room sessions, autosave, and manual fallback

Date: 2026-10-27. Branch: `TintAtlas`, in the user-authorized existing checkout.

Baseline verified before edits: `6d422c8cb41c742076d1132c457b9ddd576d7798`.
Protected `lib/main.dart` unstaged diff SHA-256:
`c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`.
That file was never edited, formatted, staged, or committed by this task.

## Implementation and contracts

- Added `RoomProjectSession` with `durable` (last acknowledged `RoomProjectSnapshot`), `visible` (current editable `RoomMaskDraft`), typed `saveStatus`/`saveError`, pending count, project identity/name, and an optional recovery warning. `RoomProjectSessionController` supplies `createFromAnalysis`, `createManualFallback`, `commitVisibleDraft`, `retrySave`, `openProject`, and `closeProject`.
- Extended the existing `room_projects_providers.dart`. Its repository owner and maintenance lifecycle remain intact. Project, variant, and acquired-photo IDs use an injectable factory backed by 128 bits from `Random.secure()`, within the frozen safe-ID syntax. Initial project and variant names come from generated localizations with the supported-device-locale fallback.
- `RoomMaskController` retains edit-state ownership and never performs repository I/O. It notifies the session after initial successful analysis, completed strokes, undo, color changes, Restore AI, and successful reanalysis. Tool/layer/brush/overlay changes, unchanged colors, incomplete/cancelled gestures, stale results, and cancelled/failed refinement do not save.
- A valid prepared photo remains available after analysis failure. The explicit localized Edit manually action creates exact width × height zero/unowned AI/current masks, retains the same `PreparedPhoto`, and opens the editable project. Manual mode has an honest localized notice and a distinct Retry analysis action. Retrying uses the existing reanalysis merge and undo-rebase logic, preserving corrections and colors. A failed model run is never labeled as a successful empty detection.
- Stored photos are encoded from prepared RGBA pixels in a worker, never copied from arbitrary picker preview bytes. Encoding starts with a fresh image, containing no source metadata. A valid thumbnail has a maximum side of 256 pixels. Both pass the strict Task 2 PNG codec. Reopen validates the stored snapshot before decoding and reconstructs identical RGBA bytes, dimensions, photo identity, AI/current labels, mask/color revisions, and active colors. Dirty count is recomputed and transient undo history is empty.
- The main `/room/masks` editor presents localized Saving, Saved, failure, and conflict states with live-region semantics and an accessible Retry save button. Editing remains enabled during disk writes and save failures. The existing route, acquisition flow, reanalysis, fullscreen editing, model setup, preview, and sharing behavior remain in place.
- Photo replacement warns explicitly when the current project has unsaved edits. Cancelling retains the retryable draft. Ordinary route departure retains the session; already completed mutations can finish saving in the background. Existing route/lifecycle guards reject inactive gesture callbacks.
- Confirmed Settings deletion of `roomProjects` now awaits the editor/session close barrier before invoking the existing exact data manager. Preview and either Cancel leave the session untouched. This narrow integration was explicitly approved by the parent as a Task 3 dependency; it adds no Task 4 library actions and does not replace the repository owner.

### Queue, error, and lifecycle semantics

Each completed mutation creates one FIFO save intent. There is one active session write and no successful-path coalescing; each captured draft advances storage revision once. The visible draft updates synchronously, and an older completion updates only `durable`. Saved is published only after the latest queued intent is acknowledged. Mask/color revisions remain independent of repository revision.

The first write expects revision 0. Each subsequent write uses the last acknowledged token. Recovered snapshots retain `RoomProjectReadResult.acknowledgedRevision` as the token even when the recovered snapshot has an older revision. CAS conflict is typed and visible. Retry never reads/adopts another writer's token or silently rebases changes.

Any save failure stops the drain, settles/discards queued intents, leaves `durable` unchanged, and retains the latest visible editable draft. Further edits update that draft without automatic retry. Explicit Retry enqueues exactly the current visible draft. A repository provider that failed to initialize can be reacquired on Retry; an established owner is retained. Save-intent futures settle on acknowledgement, typed failure, or cancellation; callers inspect session state rather than treating future completion as a Saved guarantee.

`closeProject()` synchronously invalidates queued or not-yet-accepted work and then drains an accepted active save. Delete/maintenance callers must await it. Old completion/error cannot publish into another project. Provider disposal has the same invalidation/drain behavior. Editor disposal invalidates immediately, but defers the session's null-state notification by one microtask because Riverpod forbids publishing to another provider inside `onDispose`; that notification is epoch-guarded.

`openProject()` refuses to discard an unsaved draft with typed `RoomProjectUnsavedChanges`; callers must retain it or explicitly close it after resolving the consequence. Missing/corrupt opens retain the existing session. Open validates its session epoch and optional editor-operation guard before publication. A newer completed edit or photo acquisition wins over an older Open. Ownership publication has no intervening asynchronous gap after its final guard.

For future route integration, `RoomMaskController.openProject()` installs the reconstructed draft into the editor and passes its operation guard to the session; its `closeProject()` also clears editor state. Direct session Open returns the usable draft for other consumers. Task 4 should use these boundaries and await close before deleting. Tasks 5–7 can extend metadata/render/export behavior without bypassing visible/durable separation.

## RED evidence and diagnostic corrections

Session and controller tests were written before production implementation. Initial required command:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart --reporter expanded
```

The first attempt was blocked before compilation by Flutter's SDK-cache write (`engine.stamp: Operation not permitted`). The unchanged command was rerun with normal tool escalation and exited 1 at `+0 -2`, because the session file/API/status types and manual/open/close editor methods were absent. Log: `/tmp/tintatlas-task3-red.log`.

The initial standalone UI RED compile also revealed two test-only awaits of the void `handleAppLifecycleStateChanged` method. A first session production draft had just been written when this was identified. It was removed, and provider/state edits reverted with `apply_patch`; an empty production diff was verified. After correcting the test harness, the combined pre-implementation RED run below exited 1 at `+0 -3` solely on missing Task 3 APIs and their resulting type-inference diagnostics. Production implementation was then reinstated. Log: `/tmp/tintatlas-task3-red-corrected.log`.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart --reporter expanded
```

Additional runtime RED cases were observed before their fixes:

- Editor disposal and unsaved replacement warning: `+0 -2`, retained session where null was required, and absent consequence copy. `/tmp/tintatlas-task3-lifecycle-red.log`.
- Stale/duplicate draft commits, unsaved Open, and Retry after owner-initialization failure: `+0 -3`; four writes instead of two, Open returned a replacement draft instead of refusing, and Retry remained failed. `/tmp/tintatlas-task3-guards-red-runtime.log`.
- Opening a missing project detached the current session: `+0 -1`. `/tmp/tintatlas-task3-open-red.log`.
- Manual fallback incorrectly also displayed the successful-empty-detection notice: `+0 -1`. `/tmp/tintatlas-task3-manual-copy-red.log`. That run also exposed Riverpod's prohibition on cross-provider state publication inside disposal, fixed by immediate invalidation plus deferred epoch-guarded notification.
- Confirmed Settings erase began before an accepted save settled: `+0 -1`, manager attempt count 1 instead of 0. `/tmp/tintatlas-task3-settings-red-runtime.log`. Its test also verifies that preview and cancelling either confirmation retain the session.
- Final lifecycle audit: an older Open installed `another-project` after a newer import started (`+0 -1`, `/tmp/tintatlas-task3-open-owner-red.log`), and an older Open replaced an edit whose save had already completed (`+0 -1`, `/tmp/tintatlas-task3-open-edit-red.log`). Both passed together at `+2` after the operation/epoch publication fix (`/tmp/tintatlas-task3-open-owner-green.log`).

Intermediate verification failures were diagnosed and are not counted as successful gates: nullable generic inference around `compute` and an assignment-expression getter required explicit result typing/local return; a widget semantics assertion required a pumped frame after scrolling and the established button semantics; a semantics handle needed disposal inside the test body. Widget Open tests now pump the fake clock while bounded real-isolate work completes instead of awaiting across incompatible zones. Settings confirmation tests use bounded frames while the expected busy spinner is active; `pumpAndSettle` cannot settle that spinner. Interrupted diagnostic runs were stopped and are not reported as passing suites. The initial analyzer reported 10 style infos, all corrected.

## Verification

Final focused command:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/features/settings/data_management_screen_test.dart --reporter expanded
```

Result: exit 0, `00:13 +129: All tests passed!`. Log: `/tmp/tintatlas-task3-focused-final.log`.

Coverage includes aligned first save and real filesystem reopen; clean RGBA photo/thumbnail storage; manual-mode dimensions and zero labels; Retry Analysis preserving corrections; FIFO pending state and latest visible state; transient/cancelled/no-op mutation exclusion; save failure and Retry latest visible; stale CAS and localized conflict UI; recovered acknowledgement tokens; old-project late failure; close before owner initialization; accepted-write close/dispose/delete ordering; no post-delete recreation; process/repository reopen returning the last acknowledged masks/colors after pointer failure; background and inactive-route gestures; failed/missing/stale Open preservation; and existing Room editor/model/acquisition/sharing regressions.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
```

An initial full run passed at `01:05 +1795` (`/tmp/tintatlas-task3-full.log`). The final audit then reproduced the two Open races above, so a full rerun was warranted after their fixes and additional conflict UI coverage. Final result: exit 0, `01:02 +1798: All tests passed!`, with no failing tests or uncaught test exceptions. Log: `/tmp/tintatlas-task3-full-final.log`.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub
/Users/jamirulislam/Applications/flutter/bin/flutter gen-l10n
```

Final analyzer result: exit 0, `No issues found! (ran in 4.2s)`. Log: `/tmp/tintatlas-task3-analyze-final.log`. Localization generation exited 0 using the existing `l10n.yaml`; no dependency change was made.

Explicit formatter verification:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/features/room_studio/application/room_project_session_controller.dart lib/features/room_studio/application/room_projects_providers.dart lib/features/room_studio/application/room_mask_controller.dart lib/features/room_studio/domain/room_mask_state.dart lib/features/room_studio/presentation/room_project_save_status.dart lib/features/room_studio/presentation/room_mask_screen.dart lib/features/room_studio/presentation/room_mask_dialogs.dart lib/features/settings/presentation/data_management_screen.dart lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/features/settings/data_management_screen_test.dart
```

Result: exit 0, `Formatted 14 files (0 changed)`. `git diff --check` passed after the final full suite. The protected unstaged hash was rechecked as `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`. The commit gate also verifies the staged diff and that `git diff --cached -- lib/main.dart` is empty.

## Scope and limits

- Frozen schema v1 is unchanged. `manualMode` is transient and inferred from an empty AI baseline on reopen. Explicit user intent/history remains Plan 03/schema v2. ROOM-03 is not claimed complete; undo history is intentionally empty after process reopen.
- The existing segmentation service already provided the prepared-photo/result alignment needed by this boundary; it required no production change. Existing safe reanalysis semantics were reused rather than duplicated.
- No Task 4 library/routes/actions, Task 5 variants/compare UI, Task 6 recolor scheduler, Task 7 export redesign, ads, dependencies, signing, or store changes were implemented. The original variant is persisted only as required by schema v1.
- Task 2's deferred maintenance-lease misuse and additional asset/pointer write-boundary probes remain unchanged. Its process-interruption versus device power-loss and same-isolate serialization limits still apply.
- Lifecycle evidence is unit/widget and real temporary-file repository evidence. No native device lifecycle, Android build, iOS archive, or platform export certification is claimed in this task. The full-screen mask modal continues to share the same autosaving edit state; the detailed save-status panel is on its parent `/room/masks` screen.
- Normal autosave uses FIFO intents, not the Task 6 render scheduler's one-active/one-latest policy. Failure deliberately discards queued storage attempts and Retry saves the latest visible draft. Explicit close discards unstarted intents; callers must resolve any unsaved consequence before closing.

## Commit record

Required commit message: `feat: autosave room projects with manual fallback`.

This report is included in the implementation commit. Its exact creation commit can be resolved without a self-referential hash:

```sh
git log --diff-filter=A -1 --format=%H -- .superpowers/sdd/2026-10-27-tintatlas-real-room-projects/task-3-report.md
```

The final SHA is returned in the implementer handoff. Only explicit Task 3 paths are staged. This report alone is force-added from ignored `.superpowers`; no other ignored ledger/brief is staged. No push, merge, or publication is performed.

## Fix round 1 — lifecycle ownership and retained cancellation

Reviewed baseline: `2c8a78482c7f801eef51d1eb3aec83fdf0637904` on `TintAtlas`. This round addresses the four Important review findings. The deferred Minor findings (empty-AI reopen cause ambiguity and no-op Restore revision) remain unchanged.

### Changes and covering regressions

- Session `build()` revives `_alive` when Riverpod reuses the notifier after invalidation. It preserves the monotonic ownership epoch and existing drain barrier. Disposal still closes old work immediately, discards queued intents, and waits for an accepted write; old completion or deferred null notification cannot publish into the new session. Tests: `rebuilt session saves a new analyzed project`, `rebuilt session saves a new manual project`, and `rebuilt session drains old accepted save without clearing or saving over new work with disposal alone` / `with deferred close`.
- `cancelAnalysis()` invalidates late inference and retains the exact prepared candidate in the explicit Analyze/Edit manually state. Cancel download also cancels model setup. The separate, localized `Discard photo` action uses the existing candidate-discard boundary, as does Return to previous masks. Reanalysis cancellation with no candidate returns to its existing draft. Tests: `stopping analysis retains the prepared photo for manual fallback despite late success` / `late failure`; `Cancel analysis retains accessible manual choices before late success` / `late failure`; and the amended `Cancel download aborts model setup and ignores late analysis`. Semantics assertions cover the enabled Cancel analysis, Cancel download, Analyze this photo, Edit manually, and Discard photo actions. Old cancellation expectations in candidate visibility, import-guard supersession, and retained-old-draft tests now explicitly tap Discard photo when they intend to remove the candidate.
- Open applies its ownership guard to typed and raw read/decode failures as well as success. The editor also captures draft identity so an early asynchronous failure cannot hide a newer completed edit. Tests: `stale raw Open failure leaves a newer color edit usable` and `stale typed Open failure leaves a newer color edit usable`; the existing stale-success regressions remain passing.
- Editor Open rejects an incompatible acquisition, analysis, or refinement before advancing its operation token. A missing project cannot supersede active reanalysis and leave the editor busy. Test: `missing Open during reanalysis cannot strand the current operation`.

No Settings behavior changed; its existing confirmation/preview/delete-drain regression passed in the complete focused suite. Schema v1, runtime-only `manualMode`, Room routes, project library scope, and the deferred Minor boundaries are unchanged. No Task 4 work or dependency change was made.

### RED evidence

Only the three test files were changed when the first ownership RED command ran; no production fix had been applied:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart --name 'rebuilt session|stale .*Open failure|missing Open during reanalysis' --reporter expanded > /tmp/tintatlas-task3-fix1-ownership-red.log 2>&1
```

Result: exit 1, `+0 -6`. Both new-project rebuild tests and the accepted-write/deferred-close rebuild test expected a non-null new session but received null. Both stale Open failure cases expected `RoomMaskStage.ready` but received `RoomMaskStage.error`. The missing-Open/reanalysis test expected successful completion (`true`) but received `false` after Open invalidated its operation. The accepted-write regression was subsequently parameterized to cover disposal alone as well as deferred-close notification.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_masks_integration_test.dart --name 'Cancel analysis retains accessible|Cancel download aborts' --reporter expanded > /tmp/tintatlas-task3-fix1-cancel-ui-red.log 2>&1
```

Result before production edits: exit 1, `+0 -3`. Cancel analysis with late success, Cancel analysis with late failure, and Cancel download each expected a retained candidate in `RoomMaskStage.acquiring` but received `RoomMaskStage.empty`.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_mask_controller_test.dart --plain-name 'stopping analysis retains' --reporter expanded > /tmp/tintatlas-task3-fix1-cancel-controller-red.log 2>&1
```

Result before production edits: exit 1, test-file load failed because `RoomMaskController.cancelAnalysis` was not defined. This supplements the runtime cancellation RED above with the missing separate stop-analysis API; it is not a test-harness error.

### GREEN and final gates

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter gen-l10n
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart --name 'rebuilt session|stale .*Open failure|missing Open during reanalysis|stopping analysis retains|Cancel analysis retains accessible|Cancel download aborts' --reporter expanded > /tmp/tintatlas-task3-fix1-targeted-final.log 2>&1
```

Localization generation exited 0. The first targeted GREEN passed `+11` (`/tmp/tintatlas-task3-fix1-targeted-green.log`). The amended targeted run passed `00:01 +12: All tests passed!`, exit 0. The final Cancel download semantics assertion was then included in the complete focused and full runs below.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/features/settings/data_management_screen_test.dart --reporter expanded > /tmp/tintatlas-task3-fix1-focused.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded > /tmp/tintatlas-task3-fix1-full.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub > /tmp/tintatlas-task3-fix1-analyze.log 2>&1
```

Results: focused exit 0, `00:10 +140: All tests passed!`; full suite run once this fix round, exit 0, `00:58 +1809: All tests passed!`; analyzer exit 0, `No issues found! (ran in 11.8s)`.

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/features/room_studio/application/room_project_session_controller.dart lib/features/room_studio/application/room_mask_controller.dart lib/features/room_studio/presentation/room_mask_screen.dart lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart
git diff --check
git diff -- lib/main.dart | shasum -a 256
```

Explicit formatter gate: exit 0, `Formatted 8 files (0 changed)`. An earlier formatting invocation formatted those explicit paths but exited 1 because the sandbox blocked the SDK telemetry timestamp; the unchanged command was rerun with normal escalation and exited 0. Verification was not weakened. Diff whitespace check passed. The protected user-owned `lib/main.dart` was never edited, formatted, or staged; its diff hash remains `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`.

### Fix commit record

Required message: `fix: preserve room session lifecycle ownership`. This report is included in that commit; its exact SHA is returned in the handoff and can be resolved with:

```sh
git log -1 --format=%H --grep='^fix: preserve room session lifecycle ownership$'
```

The commit gate verifies the ten explicit fix/report paths, `git diff --cached --check`, an empty `git diff --cached -- lib/main.dart`, and the unchanged protected hash. The only remaining unstaged modification is the user-owned `lib/main.dart`. No push, merge, or publication is performed.
