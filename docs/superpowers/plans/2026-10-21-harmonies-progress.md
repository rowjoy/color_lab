# SDD ledger — plan: docs/superpowers/plans/2026-10-21-harmonies.md

Scope: Phase2 Harmonies and whole-palette persistence, per user's Next and established immediate module workflow. Architecture is documented before implementation. No Git repo exists; baseline source snapshot is `/private/tmp/color-lab-harmonies-baseline.a0Udhz` from prior Formula ZIP. Keep durable reports here and preserve earlier archives, current project/user data and existing storage schemas.

Execution uses subagent-driven-development with disjoint core/controller, palette storage and wheel paths, plus root routing/editor/library integration, per active proactive collaboration instruction. Exact APIs are fixed before dispatch. No shared-file write ownership beyond explicit root integration after delegates finish.

| Task/interface pair | Preflight check |
| --- | --- |
|1/2|HarmonyMode labels/name and generated list contract match persisted snapshot; no storage dependency in core/controller|
|1/3|Wheel consumes base/mode/actual deduped colors, neutral and mono behavior explicit|
|1/4|Exact HarmonyDraft record/notifier API, retained session and picker source behavior|
|2/4|SavedPalette.idFor/model/repository/controller API, captured recipe, durable save/retry/delete semantics|
|3/4|Read-only diagram is separate from48dp swatch actions; no fake pointer/gesture contract|
|1|Fixtures cover every exact rotation, anchor, clamping, wrap and neutral collapse|
|2|Separate Hive box/directory/provider ownership; real-file and failed-flush tests required, no history/schema edits|
|3|Code-native theme-driven diagram with honest neutral geometry/semantics; no bitmap tools needed|
|4|Awaited nested routes preserve camera ownership; same-route guard, existing Saved/Studio state and snapshots retained|

## Implementation and scoped review

Task 1: complete and independently approved. Twenty focused tests; literal
six-mode fixtures, anchor/order/dedup/neutral/clamp and session-isolation checks.
See `harmonies-task-1-report.md`.

Task 2: complete and independently approved. Thirty focused tests; strict
immutable v1 snapshots, actual disk reopen, directory isolation, corrupt-data
preservation, serialized durability/flush/no-op/close barriers and provider
retry/disposal/late-open ownership. See `harmonies-task-2-report.md`.

Task 3: complete and independently approved. Twenty-two raster/semantic tests;
all modes/themes, correct cardinal ring orientation, exact RGB markers, base
outline and distinct monochromatic/neutral rail. Deliberate ring-orientation
mutation failed before restoration. See `harmonies-task-3-report.md`.

Task 4: complete and independently approved; twenty-two integration tests pass. Independent UI review
found two P2 defects, both reproduced before fixes: small delete-dialog label
contrast and library swatch details stacking another editor. Three new tests
failed before the minimal fix and passed after it. Scoped re-review approved
both fixes with no newly introduced defect. Full root report and scoped review
record: `harmonies-task-4-report.md`, `harmonies-task-reviews.md`.

## Fresh cumulative verification

All commands below ran after the reviewed UI fixes, not concurrently with source
implementation. Earlier implementer full-suite failures were transient sibling
imports while their sources were absent; this cumulative run supersedes them.

```text
flutter test --no-pub --reporter expanded
00:22 +481: All tests passed!
exit 0

flutter analyze --no-pub
No issues found! (ran in 2.3s)
exit 0

dart format --output=none --set-exit-if-changed lib test tool
Formatted 126 files (0 changed) in 0.77 seconds.
exit 0

flutter build apk --debug --no-pub
Running Gradle task 'assembleDebug'... 17.0s
Built build/app/outputs/flutter-apk/app-debug.apk
exit 0

flutter test tool/render_previews.dart --no-pub
00:10 +2: All tests passed!
exit 0
```

Counts: 387 baseline +20 core/controller +30 snapshot/storage/provider +22
wheel +22 UI =481 app tests. The separate two-theme renderer produces68 real-font
PNGs:42 preserved and26 added. Root visually inspected triadic light, neutral
monochromatic dark, enlarged dark save dialog and enlarged light collection
after the refreshed pass; no overflow/layout/hit-test warnings. Details and
capture names: `harmonies-preview-report.md`.

Logs are `/private/tmp/color-lab-harmonies-{full-tests,analyze,apk,previews}.log`.
`pubspec.yaml` and `pubspec.lock` match the Formula baseline byte-for-byte.
Android/iOS source diffs contain no changes, only local generated/cache files
excluded from source archives. No device installation/data clear was performed.

## Final review and artifact

Independent whole-module review approved with no critical/important findings.
The reviewer checked actual code/test diffs, fresh full-suite/analyzer/preview
logs and representative images, including the two resolved UI findings. See
`harmonies-final-review.md`. No required implementation or review work remains.

Root confirmed the APK build exited0 and produced190,105,335 bytes at
`build/app/outputs/flutter-apk/app-debug.apk`. SHA-256:
`08f848f4c442419d9875f18637c761cd592b8eb28d872a5a8fbddf202107bae3`.

Cumulative handoff: `dist/color-lab-harmonies-2026-10-21.zip`. `unzip -tq`
exited0 with no compressed-data errors. Manifest checks confirmed the new core,
screens, real Hive repository, integration tests, final review and all three
license notices. An exclusion scan found no local.properties, Gradle/Kotlin
caches, Pods/symlinks, generated Xcode settings, ephemeral/build output,
xcuserdata or IDE/DS_Store files. The archive contains cumulative source, assets,
tests, renderer, native source, pubspec/lock, README and design/plan/review docs.

The six earlier milestone ZIPs remain untouched. No dependency, native source,
existing storage schema or user/device data changes. Delivery gates are complete;
the archive is refreshed and integrity-checked after final ledger/checkbox edits.

## Limits

Real-file durability/restart and controlled flush failures are exercised, not
simulated power loss. Preview camera content is synthetic. Physical-device
camera/iOS/native accessibility/predictive-back execution remain unverified.
No games, vision tests or room-photo editing are included. Next is the Color
matching game module, only on a subsequent user request.

Self-review: no placeholders/type/interface conflicts. Snapshot storage is intentionally independent of later regeneration; editor opening never mutates persisted data. Duplicate base/mode saves preserve original metadata, matching existing deduplication philosophy. Save captures the original draft across awaits. Names are user text; UI chrome remains English. No new packages/platform permissions or games/room-photo work.
