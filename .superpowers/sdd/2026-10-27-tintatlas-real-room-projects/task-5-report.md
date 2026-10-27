# Plan 02 Task 5 — lightweight color variants and comparison

Date: 2026-10-27. Branch: `TintAtlas`, in the user-authorized existing checkout.

Verified base: `f14bda1b3e3fb733a2bd322e9c3a9ec9ed9c0b59`.
Protected `lib/main.dart` **unstaged diff** SHA-256:
`c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`.
The exact check is `git diff -- lib/main.dart | shasum -a 256`. The initial file-content hash (`11c14bf82927540b14857b8da7a948708062b9bbb093857c7d418f7e3fb278d5`) was a different hash, not evidence of a new change; the parent verified the distinction before implementation. This task never edits, formats, stages, or commits that file.

## Implementation and decisions

- `RoomVariantSet` is immutable metadata: bounded safe IDs, trimmed 1–80 UTF-16-unit names, case-insensitive uniqueness, at most 32 variants, active ID, and nullable comparison-baseline ID. A `RoomColorVariant` still contains only its ID, name and immutable `RoomLayerColors`. No photo, mask or history is copied into a variant. All command validation failures are typed `RoomVariantException` values with localized UI recovery text.
- `RoomVariantController` is a Riverpod notifier exposing the seven requested commands. Creation copies the active color snapshot and selects the new variant; the existing injectable cryptographic ID factory gets at most five attempts to find a safe unused ID. Selecting, renaming, pinning and clearing never change either variant's stored colors. Deleting the active variant selects the first survivor in persisted list order. Deleting the baseline clears comparison; unrelated deletion preserves both IDs. Deleting the final variant is rejected and disabled in the UI.
- `RoomProjectSession.variantSet` and its convenience getters expose the latest visible metadata, independently of `durable`. `_SaveIntent` captures the exact variant set, active ID, baseline and draft at mutation time. Every accepted variant command creates one FIFO metadata intent through the existing session queue and acknowledged CAS token. Same-color `updateVariantColors` remains a no-op, matching ordinary color edits. Older acknowledgements update durable state without rolling visible metadata back.
- Normal `RoomMaskController.setLayerColor` still commits once through the session. That commit updates only the visible active variant. Variant commands publish through the session and mirror its draft into the editor with `adoptVariantDraft`, which performs no second save. Selecting a different color snapshot increments the draft's color revision once; selecting a different variant with identical colors changes variant identity without inventing a color edit. Mask commands, Restore AI and reanalysis preserve the visible variant metadata through the same session path.
- Failure/conflict retains the latest visible variant set and last acknowledged durable snapshot. Further edits remain visible without silently retrying. Explicit Retry captures the latest state and uses the old acknowledged token; it never reads or rebases another writer's revision. Close/delete keeps Task 3's invalidate-unstarted/drain-accepted barrier. A variant queued during an active Task 4 project rename inherits the acknowledged renamed project and correct next CAS token.
- Schema v1 and the file repository are unchanged. Metadata revisions reuse the existing project-owned content-addressed photo, AI-mask, current-mask and thumbnail assets. The real-file test records the complete asset path list before variant edits, closes the owner, reopens a fresh owner/container, and proves unchanged asset paths plus exact active/baseline/color restoration. Inherited file/action tests continue to verify independent project file ownership, immutable content, deletion and CAS.
- `RoomRecolorKey` now requires exactly `(projectId, photoId, maskRevision, colorRevision, variantId)`, validates all safe IDs and bounded revisions, and includes every field in equality/hash. Active and baseline previews use the existing service via separate provider generations. Both key and render inputs come from the same session-visible snapshot; the editor mirror cannot supply another project's masks during Open. Render providers subscribe directly to the session's selected full key, reject mismatched worker keys, and ignore disposed-generation output. Baseline rendering cannot publish as the active frame.
- All screen/current/export checks use the complete key. Previous frames can display only during updating and only for the same project/photo/variant. `gaplessPlayback` is disabled on the recolor image so Flutter's decoded image cache cannot temporarily retain an old variant under the new current label. Comparison also uses non-gapless images and requires two current full-key results.
- Comparison is a real aligned image split: the selected image is clipped over the pinned baseline in the same image coordinates. The image divider is draggable, and its labeled Slider supports pointer, keyboard, and semantics increase/decrease operations. The divider and temporary Original/Before view are local widget state and do not save, alter colors, select a variant, or pin/clear a baseline. A/B-style labels, selected semantics, create/rename/delete/pin/clear controls and all new visible/semantic strings use ARB/generated localizations.
- Variant name dialogs guard submission synchronously, preventing a second tap before a rebuild from creating an extra save. They retain their text controller through route exit and prevent dismissal while the accepted command settles. Validation failures leave the field editable; storage failures are owned by the session's existing save-status/Retry UI.
- The library Compare button now opens the selected project through `/rooms/project/:id?compare=1`, which preserves `project` and `compare` in `/room/masks`. The flag surfaces the actual controls near the top of the editor. One variant gets explicit creation guidance; pinning the selected variant asks the user to select another. Compare navigation itself does not fabricate or persist a baseline. Both project-aware setup detours and replacement retargeting preserve the flag. Fresh-container restoration and Back retain the existing project ownership rules.
- Share during comparison or Original still exports only the explicitly selected active variant's current full-key PNG. A ready baseline alone cannot enable Share. Changing the selected variant disables Share until that variant has a current result. No divider overlay or baseline is handed to the exporter.

## RED evidence and diagnostic corrections

The initial domain/controller/interaction/key tests were written before production implementation:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain/room_variant_set_test.dart test/features/room_studio/application/room_variant_controller_test.dart test/features/room_studio/presentation/room_variant_controls_test.dart test/features/room_studio/recolor/room_recolor_key_test.dart test/features/room_studio/presentation/room_projects_screen_test.dart --reporter expanded > /tmp/tintatlas-task5-red.log 2>&1
```

The sandbox initially blocked Flutter's SDK `engine.stamp` write. The unchanged command was rerun using normal tool escalation. Result: exit 1, `+14 -5`; missing `RoomVariantSet`, typed failures, controller/UI APIs and project/variant key arguments caused expected compilation failures, and the real library test failed because Compare was disabled. No production implementation preceded that run.

The first implementation's domain/controller/file-reopen/key segment passed. The UI harness initially constructed the in-memory repository in Flutter's fake zone and then awaited Open inside `runAsync`, stranding its queued callback. That diagnostic run was interrupted and is not a passing gate. Setup now starts Open in the fake zone and uses bounded pumps plus short real-isolate waits. A subsequent dialog transition failure was corrected by keeping the queue in that same zone. An offscreen Compare tap was a bottom-sheet animation timing error; the test now settles the sheet before tapping. The UI revision assertion was corrected from 8 to 7: six actual commands plus initial revision 1.

The route/interaction run exposed a production Riverpod issue: lazy derived-key refreshes notified dependent preview providers during a widget build. The initial screen-only correction moved the failure into `RoomComparisonPreview`; `/tmp/tintatlas-task5-routes-ui-green.log` records seven failures and was not treated as GREEN. Direct `session.select(fullKey)` subscriptions in the render providers removed the cascade. The complete route/UI/recolor rerun passed `+57`, exit 0 (`/tmp/tintatlas-task5-route-publication-green.log`). Editor regressions independently passed `+42`, exit 0 (`/tmp/tintatlas-task5-editor-green.log`).

Two final boundary tests were run before their fixes:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_variant_controls_test.dart test/features/room_studio/presentation/room_recolor_viewport_test.dart --name 'repeated rename|new current variant' --reporter expanded > /tmp/tintatlas-task5-boundary-red.log 2>&1
```

Result: exit 1, `+0 -2`. Repeated Apply produced two pending intents instead of one; the next current variant retained the previous variant's decoded `RawImage` while its own PNG decoded. After the synchronous dialog guard and non-gapless image fix, both full UI files passed `+15`, exit 0 (`/tmp/tintatlas-task5-boundary-green.log`).

Analyzer diagnostics were style-only brace warnings and a deprecated test semantics-owner accessor. They were corrected; no failing or interrupted diagnostic run is counted as final verification.

A final coherent-input probe was run after the clean global rerun and before the last production correction:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_recolor_provider_test.dart --plain-name 'session Open renders one coherent project' --reporter expanded > /tmp/tintatlas-task5-render-owner-red.log 2>&1
```

Result: exit 1, `+0 -1`. Opening another project with the same photo ID published its new full key while the active provider still supplied the old editor's masks `[1,2,3,4]` instead of the newly opened `[4,3,2,1]`. The active provider now reads `session.visible` alongside its key, matching the baseline provider. This removes the editor-mirror microtask gap without changing scheduling or storage. Impacted verification:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_recolor_provider_test.dart test/features/room_studio/presentation/room_variant_controls_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/routing/app_router_test.dart --reporter expanded > /tmp/tintatlas-task5-render-owner-green.log 2>&1
```

Result: exit 0, `00:12 +103: All tests passed!`. The parent explicitly directed a final complete focused/analyzer gate after this narrow fix, without a third global run unless it had broad reach. No other production changes followed it.

## Final verification

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain/room_variant_set_test.dart test/features/room_studio/application/room_variant_controller_test.dart test/features/room_studio/presentation/room_variant_controls_test.dart test/features/room_studio/recolor/room_recolor_key_test.dart test/features/room_studio/recolor/room_photo_recolorer_test.dart test/features/room_studio/application/room_recolor_provider_test.dart test/features/room_studio/presentation/room_recolor_viewport_test.dart test/data/files/file_room_project_repository_test.dart test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/features/room_studio/presentation/room_projects_screen_test.dart test/features/room_studio/presentation/room_project_actions_test.dart test/routing/app_router_test.dart test/features/room_studio/application/room_image_export_service_test.dart --reporter expanded > /tmp/tintatlas-task5-focused-complete.log 2>&1
```

Result: exit 0, `00:17 +294: All tests passed!`. The earlier combined run was also green at `+291`; the final run includes the two reproduced boundaries and both active/baseline late-error permutations.

After the coherent-render-input correction, the **same complete focused command** was rerun with output redirected to `/tmp/tintatlas-task5-focused-final-gate.log`: exit 0, `00:18 +295: All tests passed!`. This is the final source-state test gate. The final analyzer command shown below exited 0 with `No issues found! (ran in 5.7s)`.

Coverage includes name/ID/count limits, uniqueness, missing IDs, final deletion, deterministic survivor/baseline rules, one-save FIFO snapshots, latest visible metadata, failed-save and conflict Retry, active project rename ordering, close/delete drain, color/mask ownership, real-file asset reuse/reopen, complete key equality/validation, mismatched/late results and errors on both sides and across projects, real split controls, pointer/keyboard/semantic operation, temporary original nonmutation, and selected-side Share. At this initial gate, controls (including the direct Delete action) and create/rename dialogs were exercised at 320×568, 568×320, 840×800 and 1200×800 with 200% text. Deletion did not yet have a confirmation dialog; the earlier claim of delete-dialog coverage was incorrect. Fix round 1 below supplies that behavior and actual layout evidence. Library Compare is exercised with one/two variants, fresh-container restoration, query identity and Back.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded > /tmp/tintatlas-task5-full.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub > /tmp/tintatlas-task5-analyze-final-gate.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter gen-l10n
```

The first global run exited 1 at `14:53 +1909 -1`: `loading test/features/settings/privacy_screen_test.dart` timed out after 12 minutes before its single test ran. No Room test failed. The unchanged standalone command below passed immediately at `+1`, exit 0; the unchanged full rerun passed at `00:58 +1910: All tests passed!`, exit 0.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/settings/privacy_screen_test.dart --reporter expanded > /tmp/tintatlas-task5-privacy-recheck.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded > /tmp/tintatlas-task5-full-rerun.log 2>&1
```

That global GREEN precedes only the narrow coherent-render-input correction documented above. The timeout was not reproduced standalone or in the unchanged global rerun, and no unrelated privacy code or timeout setting was changed. Localization generation exited 0 using the existing `l10n.yaml`; there is no dependency change.

Explicit formatter gate (never includes `lib/main.dart`):

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/features/room_studio/application/room_variant_controller.dart lib/features/room_studio/application/room_mask_controller.dart lib/features/room_studio/application/room_project_session_controller.dart lib/features/room_studio/application/room_recolor_provider.dart lib/features/room_studio/domain/room_mask_state.dart lib/features/room_studio/domain/room_project.dart lib/features/room_studio/presentation/room_variant_controls.dart lib/features/room_studio/presentation/room_mask_screen.dart lib/features/room_studio/presentation/room_project_open_screen.dart lib/features/room_studio/presentation/room_projects_screen.dart lib/features/room_studio/presentation/room_recolor_viewport.dart lib/features/room_studio/recolor/room_recolor_frame.dart lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart lib/routing/app_router.dart test/features/room_studio/application/room_variant_controller_test.dart test/features/room_studio/domain/room_variant_set_test.dart test/features/room_studio/presentation/room_variant_controls_test.dart test/features/room_studio/recolor/room_recolor_key_test.dart test/features/room_studio/application/room_recolor_provider_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/features/room_studio/presentation/room_projects_screen_test.dart test/features/room_studio/presentation/room_recolor_viewport_test.dart test/features/room_studio/recolor/room_photo_recolorer_test.dart test/routing/app_router_test.dart
git diff --check
git diff -- lib/main.dart | shasum -a 256
```

Final formatter result: exit 0, `Formatted 25 files (0 changed)`. `git diff --check` passed. The final protected unstaged diff hash remained `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`.

## Boundaries and limitations

- Task 6 owns controlled workers, one-active/latest-pending scheduling, cancellation, timeout replacement, memory release and two-side scheduling fairness. This task adds identity and isolated publication only; it deliberately keeps the existing recolor service.
- Task 7 owns clean-PNG verification immediately before platform handoff, Save support and handoff revalidation. The existing Share flow is guarded here with the complete active key. Native Save/Share or TalkBack/VoiceOver device certification is not claimed by widget tests.
- Schema v1 remains unchanged; explicit manual intent/history and schema v2 are Plan 03. Task 2–4 deferred Minors are unchanged. No ads, dependency, signing, store, publication, push, merge or unrelated work is included.
- The inherited file owner remains same-isolate serialized with process-interruption guarantees, not a native multi-process database or a claim of device power-loss durability. No native build was requested for this task; Plan 02 Task 8 owns the milestone build/device gate.

## Commit record

Required message: `feat: add room color variants and comparison`.
This report is included in that implementation commit. Its final commit identity is resolvable without a self-referential hash:

```sh
git log --diff-filter=A -1 --format=%H -- .superpowers/sdd/2026-10-27-tintatlas-real-room-projects/task-5-report.md
```

The exact SHA is returned in the implementer handoff. Staging is limited to the 25 explicit Dart paths above, `lib/l10n/app_en.arb`, and this report. Only this report is force-added from ignored `.superpowers`; the shared ledger and brief remain unstaged. The commit gate checks staged whitespace, an empty staged `lib/main.dart` diff and the protected unstaged hash.

## Fix round 1 — disclose and confirm variant deletion

Reviewed base: `e0438f37285a0d90038b3fa7f23628e9bc13ff78`, branch `TintAtlas`. This round addresses the Important finding that a single adjacent Delete tap immediately removed and autosaved a color alternative without consequence disclosure or recovery. It adds confirmation only; no Task 6 work or controller/storage changes are included. The protected unstaged `lib/main.dart` diff remains untouched.

The new localized dialog names the target and explicitly states that the project photo, masks and other variants remain. If the target is active, it names the first surviving variant in persisted order; if it is the pinned baseline, it states that comparison clears. Both consequences appear when applicable. Cancel, system Back and outside dismissal are genuine zero-mutation paths. The final remaining variant's Delete action remains disabled, with the existing domain rejection unchanged.

Confirmation captures the current project ID, immutable variant set, visible draft and exact target object. Immediately before issuing the command, it revalidates those identities and the project name. A reopen, project switch, target rename/color change/removal, selection change or other visible variant/draft change makes the confirmation stale: no delete command or save is issued, and a localized live-region message asks the user to review and try again. Mere save acknowledgement can change durable status while preserving these captured identities; it does not silently discard the valid confirmation. This conservative rule also prevents acting on outdated survivor/baseline consequences.

One pending confirmation is admitted at a time. The Confirm callback guards an already-dispatched repeat activation before popping the dialog, and the accepted dialog result causes exactly one existing session-backed `deleteVariant` command. The test performs a real first tap, then re-invokes the captured callback to represent a duplicate activation already dispatched before the route leaves; a second coordinate tap would only miss because the first activation removes the dialog from hit testing immediately. No hit-test warning is suppressed. The test verifies one pending intent, one storage revision, and a retained underlying page.

Fifteen new widget cases cover regular deletion copy and asset/color preservation; Cancel/Back/outside no-op behavior; active, baseline and combined consequences; six stale ownership/target scenarios; repeated confirmation; and compact portrait/landscape at 200% text with a 100-pixel keyboard inset. The existing CRUD/four-layout interaction cases now explicitly confirm deletion too. Both cancel and confirm remain reachable through real taps in the compact keyboard-inset cases, with no overflow. The report's original delete-dialog layout overstatement is corrected above.

### RED and final GREEN evidence

Only the test file changed before this RED command:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_variant_controls_test.dart --plain-name 'delete' --reporter expanded > /tmp/tintatlas-task5-fix1-red.log 2>&1
```

Result: exit 1, `00:02 +0 -16: Some tests failed.` The new cases expected a confirmation dialog but found none; the amended existing CRUD test also found no Confirm action. This reproduces the review finding before implementation.

After implementation and diagnostic cleanup, the final covering command was:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_variant_controls_test.dart test/features/room_studio/application/room_variant_controller_test.dart test/features/room_studio/application/room_project_session_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/routing/app_router_test.dart --reporter expanded > /tmp/tintatlas-task5-fix1-focused-final.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub > /tmp/tintatlas-task5-fix1-analyze-final.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/flutter gen-l10n
```

Focused result: exit 0, `00:16 +140: All tests passed!`, with no missed-hit warnings or uncaught exceptions. Final analyzer: exit 0, `No issues found! (ran in 4.3s)`. Localization generation: exit 0 with the existing `l10n.yaml`. Initial intermediate diagnostics (a brace-style info and the redundant second coordinate tap described above) were corrected before these clean final gates.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded > /tmp/tintatlas-task5-fix1-full.log 2>&1
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/features/room_studio/presentation/room_variant_controls.dart lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart test/features/room_studio/presentation/room_variant_controls_test.dart
git diff --check
git diff -- lib/main.dart | shasum -a 256
```

Full-suite result: exit 0, `01:03 +1926: All tests passed!`; it ran once in this fix round. Formatter result: exit 0, `Formatted 4 files (0 changed)`. Whitespace check: exit 0. The protected unstaged `lib/main.dart` diff SHA-256 remained `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`. No native accessibility/device certification is claimed; the dialog evidence is widget-level pointer, dismissal, layout and state ownership coverage.

### Fix commit

Required message: `fix: confirm room variant deletion`. The commit stages only `room_variant_controls.dart`, `app_en.arb`, the two generated localization files, `room_variant_controls_test.dart`, and this report. It verifies staged whitespace and an empty staged `lib/main.dart` diff. The exact fix SHA is returned in the handoff and can be resolved with:

```sh
git log -1 --format=%H --grep='^fix: confirm room variant deletion$'
```
