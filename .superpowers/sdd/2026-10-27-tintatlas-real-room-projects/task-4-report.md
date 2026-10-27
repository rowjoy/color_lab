# Plan 02 Task 4 — Room project library and storage-safe actions

Date: 2026-10-27. Branch: `TintAtlas`, in the explicitly authorized existing checkout.

Baseline verified before edits: `266572bf064d130985a378b88e7d099eec35521b`.
Protected `lib/main.dart` unstaged diff SHA-256 before work and at the final gate:
`c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`.
That file was never edited, formatted, staged, or committed by this task.

## Implementation and action contracts

- Added the responsive local Room project library, storage/recovery notices, action controller and dialogs, and selected-project Open screen. Rooms and My Work have reachable localized library links. Healthy cards sort by descending `updatedAt`, then ascending project ID, regardless of repository input ordering. Corrupt records are disclosed without hiding healthy cards; an entirely corrupt library says that no projects are readable rather than falsely claiming there are no projects yet.
- Cards expose the saved name, locale-formatted local update date, real preview or explicitly labeled missing/corrupt preview, recovery warning, active save state, and named Open/Continue/menu semantics. Text and independently actionable semantics carry the meaning. Layout uses scrolling and wrapping cards without fixed card heights; menus and confirmations scroll at large text sizes.
- Added localized loading, empty, read failure, retry, busy, conflict, unsaved, invalid-name, limit, and missing/corrupt-project states. All new user-visible strings are ARB/generated-localization entries. Raw storage exceptions, corruption reasons and paths never reach the UI.
- Actions share a busy guard; dialog submission disables repeat submission and dismissal while a storage mutation is pending. Cancel deletion is a true no-op. Success is represented by acknowledged data and the refreshed library, never by an optimistic success message.
- Rename validates a trimmed 1–80-character safe name. Nonactive projects are read with the selected summary's acknowledged token and saved with that same token. A stale summary conflicts without rereading/rebasing for success. It preserves project/photo IDs, all photo/thumbnail/mask bytes and dimensions, independent mask/color revisions, variants/colors, active and comparison IDs, and creation time; exactly one storage revision is committed.
- Active-project rename uses a narrow `RoomProjectSessionController.renameProject` queue API. The session now exposes its actual `acknowledgedRevision` so actions can compare storage and session ownership without confusing a recovered snapshot revision with its CAS token. Rename advances name, durable snapshot, token and recovery state only after repository acknowledgement; visible draft/history identity is retained. Failure preserves those values and exposes failed/conflict save status, with no false rename success. Later editor mutations use the newly acknowledged token/name. Successful repairing saves clear a prior recovery warning; failed writes retain it.
- Rename and duplicate require a Saved session and no incompatible acquisition/analysis/refinement. They never bypass a saving, failed or conflicted visible draft. Active duplication also checks that the editor acknowledges the selected storage revision; it cannot silently copy newer external state hidden behind that editor.
- Duplicate takes a validated acknowledged snapshot, generates independent project and photo IDs with the existing injectable 128-bit ID factory, and creates revision 1 through `expectedRevision: 0`. Both timestamps are new UTC values. It preserves the source's assets, dimensions, masks/revisions, variants/colors and baseline while assigning a localized bounded copy name. ID selection is bounded to five attempts, excludes existing project/photo IDs, and retries a creation-time CAS collision without adopting or overwriting the colliding record. Missing/corrupt sources, stale source tokens and destination failures are safe typed failures. Files are newly owned under the destination project; real filesystem tests prove matching content files are neither symlinks nor the same inode.
- Delete explicitly explains that the selected local working photo, masks and color variants, including unsaved edits, are removed; images already saved/shared outside the app and other projects remain. Confirmed deletion of the active project closes the editor/session synchronously, discards queued work, and awaits accepted autosave work before repository deletion. Deleting another project leaves the active session untouched. A failed delete remains visible and retryable; cancellation performs no close or delete.

## Routes, restoration and model setup

- `/rooms/projects` is the library. `/rooms/project/:projectId` is a stable external route, redirecting to `/room/masks?project=<id>`. The ID remains in the URI for process/restoration reconstruction while the existing mask editor and its route activity checks are retained.
- Only a successful stored Open, or Continue of that same retained active draft, mounts the editor without setup. Continue does not reread/redecode or discard unsaved visible state. Opening another project uses `RoomMaskController` and the Task 3 session boundary; unsaved changes produce localized guidance and keep the current editor. Missing/corrupt/unsafe IDs show recovery and Retry instead of bypassing into an empty editor. The library's failed Open path preserves an unrelated healthy editor's stage and draft.
- Open publications are bound to the requesting current route/operation. A restored covered project does not compete with the front page for session ownership; when Back makes it current, it opens through the same safe boundary. A retained page never displays another project's draft under its old URI. A new photo/project created by the currently visible saved editor updates the URI's project identity. Rebuilds and same-project Continue preserve the current draft rather than repeatedly reopening storage.
- Pushed Back returns to the preceding route; direct saved-editor Back returns to the project library, and direct library Back returns to Rooms. Existing `/room`, Illustrated Room, original `/room/masks`, four-root shell, and onboarding behavior remain intact.
- Opening stored masks/colors requires no model setup or download. New-photo acquisition and reanalysis requested from that saved editor still require the existing explicit setup permission: those actions enter the original `/room/masks` setup route before picker/inference work. The active draft remains intact. This closes the Task 1↔4 bypass without changing model artifacts, model-store behavior or the original entry flow.

## RED evidence

The initial action, library, layout and route tests were written before production files/APIs. Required command:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_projects_screen_test.dart test/features/room_studio/presentation/room_project_actions_test.dart test/routing/app_router_test.dart --reporter expanded > /tmp/tintatlas-task4-red.log 2>&1
```

The sandbox initially stopped Flutter at its SDK `engine.stamp` write. The unchanged command was rerun with normal tool escalation. Result: exit 1, `+0 -3`, solely absent `RoomProjectsScreen`, `RoomProjectCard`, `RoomProjectActions` and related Task 4 APIs. No production implementation preceded this RED run.

Additional runtime RED cases were observed before their fixes:

- First implementation run: all action/storage and route cases passed; seven card semantics assertions failed because default Card semantics merged name/date/warning/Open and the excluded child lost its tap action. A semantics-tree diagnostic confirmed the missing independent action. Explicit semantics boundaries and a real Open semantics action fixed this. Targeted library GREEN: `+12`, `/tmp/tintatlas-task4-library-green.log`. The diagnostic initially lacked the rendering import; that temporary diagnostic was corrected, inspected, then removed.
- Ownership: `--name 'Back to a retained|new project in a saved|external changes hidden'` exited 1 at `+0 -3`, proving a retained A page displayed B, a replacement kept A's URI, and duplicate accepted an external revision hidden behind A's active session. GREEN exited 0 at `+3`. Logs: `/tmp/tintatlas-task4-ownership-red.log`, `/tmp/tintatlas-task4-ownership-green.log`. The initial new-photo fixture incorrectly assumed a draft `copyWith`; it was corrected to the actual constructor before the recorded runtime RED.
- Entirely corrupt library: `--plain-name 'entirely corrupt'` exited 1 at `+0 -1`, because the empty label falsely said no projects existed. Log: `/tmp/tintatlas-task4-corrupt-empty-red.log`. The truthful localized state passes in the final focused/full suites.
- Corrupt Open preservation: `--plain-name 'corrupt project Open leaves'` exited 1 at `+0 -1`, proving Open changed the healthy editor into a storage-error stage. Log: `/tmp/tintatlas-task4-open-failure-red.log`.
- Covered-page process restoration: `--plain-name 'fresh restoration opens covered'` exited 1 at `+0 -1`; restored covered pages competed for the shared Open operation and failed to mount the intended editor. Log: `/tmp/tintatlas-task4-covered-restore-red.log`. Current-route admission/scheduling fixed it. The combined preservation/restoration regressions passed `+5`, `/tmp/tintatlas-task4-final-ownership-green.log`.
- Explicit saved-editor analysis setup: `--plain-name 'requests setup before new photo analysis'` exited 1 at `+0 -2`; neither acquisition nor reanalysis requested setup. Log: `/tmp/tintatlas-task4-saved-analysis-red.log`. Both now assert setup, zero picker/inference calls, and retained draft/session. The first GREEN attempt timed out because `pumpAndSettle` cannot settle the setup checking spinner; the tests now use the existing bounded setup-screen wait. This harness correction and the two transient timeout failures were not reported as passing gates.

An early broad focused command also used a nonexistent `test/features/my_work/presentation/my_work_screen_test.dart` path; its other 183 cases passed, and the path was corrected to `test/features/my_work/my_work_screen_test.dart`. Initial analyzer runs reported nine, then two style infos, all corrected. No failing check is treated as the final verification.

## Final verification

Final focused command:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_projects_screen_test.dart test/features/room_studio/presentation/room_project_actions_test.dart test/routing/app_router_test.dart test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/features/room_studio/presentation/room_model_setup_panel_test.dart test/features/my_work/my_work_screen_test.dart --reporter expanded > /tmp/tintatlas-task4-focused-final.log 2>&1
```

Result: exit 0, `00:13 +203: All tests passed!`. Coverage includes all four requested layouts (320×568, 568×320, 840×800, 1200×800 at 200% text), reachable menus/confirmation actions, real/missing/corrupt thumbnail semantics, named tappable Open semantics, recovery/date exposure, sorting and isolated corruption, rename preservation/CAS/failure, active rename and continued saves, duplicate independent file ownership/deletion/reopen/external-export retention, bounded and creation-time collisions, source failures, cancel/no-recreation/delete drain, active-session retention, Continue/Open/errors, onboarding, model bypass and explicit later setup, pushed/direct Back, and fresh-container navigation restoration.

The full Flutter suite ran once at the completion gate, after all behavioral changes and style corrections:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded > /tmp/tintatlas-task4-full.log 2>&1
```

Result: exit 0, `01:00 +1855: All tests passed!`. No test failures or uncaught test exceptions were reported. This is 46 additional tests over the inherited 1809-test baseline.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub > /tmp/tintatlas-task4-analyze-final.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter gen-l10n
```

Final analyzer: exit 0, `No issues found! (ran in 2.5s)`. Localization generation: exit 0 using the existing `l10n.yaml`, no dependency changes.

Explicit formatter gate:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/features/room_studio/application/room_project_session_controller.dart lib/features/room_studio/application/room_mask_controller.dart lib/features/room_studio/presentation/room_projects_screen.dart lib/features/room_studio/presentation/room_project_actions.dart lib/features/room_studio/presentation/room_project_storage_notice.dart lib/features/room_studio/presentation/room_project_open_screen.dart lib/features/room_studio/presentation/room_screen.dart lib/features/room_studio/presentation/room_mask_screen.dart lib/features/my_work/presentation/my_work_screen.dart lib/routing/app_router.dart lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart test/features/room_studio/presentation/room_projects_screen_test.dart test/features/room_studio/presentation/room_project_actions_test.dart test/routing/app_router_test.dart
```

Result: exit 0, `Formatted 15 files (0 changed)`. Formatter verification used normal escalation for SDK telemetry; it never included `lib/main.dart`. `git diff --check` passed and the protected hash remained unchanged. The commit gate verifies explicit staged paths, staged whitespace, and an empty `git diff --cached -- lib/main.dart`.

## Scope and limits

- Compare is deliberately visible but disabled with localized “Comparison is not available yet” guidance, tested as nonactionable. Task 5 owns functional variants/comparison and their restoration. This task does not claim Compare or all of ROOM-04 complete, and introduces no fake successful placeholder route/action.
- No variant CRUD/comparison rendering, Task 6 scheduling, Task 7 export redesign, dependencies, ads, signing/store work, push, merge or publication was added. External export retention is proven with a real sentinel PNG outside the owned project root; no native Save/Share certification is claimed.
- Existing Task 2 process-interruption, same-isolate ownership and device-power-loss limits remain. Task 2/3 ledgered Minors are unchanged. Schema v1 and transient/manual-mode interpretation remain unchanged; explicit intent/history still belongs to Plan 03/schema v2.
- The library copy is a point-in-time acknowledged source snapshot. It never modifies the source; later source edits remain independent. The bounded ID loop avoids hanging or overwriting if an injected factory repeatedly collides.
- Tests cover widgets, controllers, local disk, and router restoration, not native device TalkBack/VoiceOver, OS process termination, Android APK/iOS archive, or platform photo/export QA. Those independent device/build gates remain later work.

## Commit record

Required commit message: `feat: add the room project library`.

This report is included in the implementation commit. Its exact creation commit is resolvable without a self-referential hash:

```sh
git log --diff-filter=A -1 --format=%H -- .superpowers/sdd/2026-10-27-tintatlas-real-room-projects/task-4-report.md
```

The exact SHA is returned in the implementer handoff. Only the 15 explicit Dart files above, `lib/l10n/app_en.arb`, and this report are staged. The report alone is force-added from ignored `.superpowers`; the shared progress ledger and brief are not staged. The only remaining unstaged change after the commit is the protected user-owned `lib/main.dart`.

## Fix round 1 — restoration ownership and system Back

Reviewed base: `3727d81bd893116e28660b21c145bcd11dabd83e`, branch `TintAtlas`. This round addresses the two Important review findings only. The active-rename retry Minor remains deferred; there are no Task 5, storage, localization, dependency, or unrelated changes.

### RED evidence

The regression tests in `test/routing/app_router_test.dart` were written and run before changing production files:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/routing/app_router_test.dart --name 'setup detour|project Back' --reporter expanded > /tmp/tintatlas-task4-fix1-red.log 2>&1
```

Result: exit 1, `00:03 +6 -6: Some tests failed.` The six expected failures were:

- `setup detour replacement keeps its saved identity through fresh restoration`: real UI acquisition/analysis reached a newly acknowledged revision-1 project B, but the URI's `project` value was null instead of B's ID.
- `setup detour restored before Continue retains project ownership and permission gate`: the setup URI's `setupProject` value was null instead of A's ID.
- `direct project Back from library uses system fallback` and the corresponding `saved`, `opening`, and `error` cases: `handlePopRoute()` returned false instead of true, so the expected fallback did not occur.

The six passing controls were the four direct visible-Back states and pushed system/visible Back with a real prior route. An earlier run had one additional harness timeout: `pumpAndSettle` cannot settle the library's busy spinner while a deliberately blocked Open is pending. The test was corrected to wait for its destination before releasing that Open; the corrected six-failure RED above still preceded every production edit. At RED, the only task edit was the routing test file; `lib/main.dart` remained the protected pre-existing change.

### Route design and regression coverage

- Saved-editor acquisition/reanalysis now pushes `/room/masks?setupProject=A`. The dedicated owner key preserves A through a fresh provider/container restoration while the existing setup gate still requires explicit Continue before mounting any project editor. This replaces the unkeyed setup detour described in the original route section above.
- The router checks `setupProject` before `project`; adding a `project` query cannot bypass the setup gate. After permission, a project-aware Open wrapper owns the `setupProject` route and uses the existing session/Open boundary. When real acquisition creates B, the current wrapper replaces its URI with `/room/masks?project=B`, so subsequent restoration opens B without picker/inference or another setup detour. The stable external `/rooms/project/:projectId` alias remains unchanged. Existing operation/current-route checks prevent repeated or covered-page Open publication; unsafe IDs still use localized recovery UI.
- `PopScope` on the library and project wrapper supplies `/rooms` and `/rooms/projects` fallbacks when their Navigator cannot pop. When an actual preceding page exists, the normal pop proceeds and the fallback does not run. The project scope covers loading, successful editor, and failure screens. Visible Back uses its existing behavior.
- Fourteen routing tests were added. The replacement test taps Choose photo, explicit setup Continue, Choose photo again, and confirmation; it runs the actual acquisition, mask-analysis orchestration, and session persistence, using doubles only for prepared picker bytes, segmentation, and the cached-model setup boundary. It asserts B's new project/photo identities, revision 1, exact 2×1 photo/PNG/mask draft, and one picker/segmenter call. It disposes the original ProviderContainer, restores the router in a fresh container, and verifies the same B draft with no additional picker/analysis calls.
- The pre-Continue restoration test verifies A's identity and zero picker/inference before permission, then reopens A on Continue. The two `setup detour owner project-1/unsafe! cannot bypass permission with a project query` cases verify query precedence, zero premature session/editor publication, and localized handling of the unsafe owner after Continue.
- Eight direct Back cases cover library/saved/opening/error with both system and visible Back. The opening case also completes its deferred read after leaving and verifies no late session publication. Two pushed Back cases exercise `/my-work` → library → saved editor and return one actual page at a time with system and visible Back, preventing double-pop/fallback override.

### GREEN and final verification

Incremental GREEN commands:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/routing/app_router_test.dart --plain-name 'project Back' --reporter expanded > /tmp/tintatlas-task4-fix1-back-green.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/routing/app_router_test.dart --plain-name 'setup detour' --reporter expanded > /tmp/tintatlas-task4-fix1-setup-green.log 2>&1
```

Results: exit 0, `+10` Back tests and `+2` initial setup regression tests. The query-precedence cases were then added before the complete route/focused/full gates.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/routing/app_router_test.dart --reporter expanded > /tmp/tintatlas-task4-fix1-routes-green.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_projects_screen_test.dart test/features/room_studio/presentation/room_project_actions_test.dart test/routing/app_router_test.dart test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/features/room_studio/presentation/room_model_setup_panel_test.dart test/features/my_work/my_work_screen_test.dart --reporter expanded > /tmp/tintatlas-task4-fix1-focused.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded > /tmp/tintatlas-task4-fix1-full.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub > /tmp/tintatlas-task4-fix1-analyze.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/features/room_studio/presentation/room_mask_screen.dart lib/features/room_studio/presentation/room_project_open_screen.dart lib/features/room_studio/presentation/room_projects_screen.dart lib/routing/app_router.dart test/routing/app_router_test.dart
git diff --check
```

Results: routing `00:06 +41`, focused `00:14 +217`, full `01:00 +1869`, all tests passed with exit 0. The full suite ran once this round. Final analyzer: exit 0, `No issues found! (ran in 2.6s)`; its initial three test-only brace-style infos were corrected. Explicit formatter: exit 0, `Formatted 5 files (0 changed)`; whitespace check: exit 0. SDK verification used normal escalation where required. No native OS gesture/device certification is claimed; the system Back contract is exercised through Flutter's `handlePopRoute()`.

### Fix commit gate

Required message: `fix: preserve room project restoration routes`. The exact fix commit is returned in the handoff and resolvable with:

```sh
git log -1 --format=%H --grep='^fix: preserve room project restoration routes$'
```

Only the five explicitly named Dart files in this round's formatter command and this report are staged. Before committing, `git diff --cached --check` passes, `git diff --cached -- lib/main.dart` is empty, and the only remaining unstaged path is `lib/main.dart`. The protected unstaged diff SHA-256 remains `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`; that file was never edited, formatted, staged, or committed by this fix.
