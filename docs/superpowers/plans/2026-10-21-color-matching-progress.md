# SDD ledger — plan: docs/superpowers/plans/2026-10-21-color-matching.md

Scope: user Next continues supplied build document module-by-module. Color
matching only; vision plates and room photos are out of scope. Design/plan are
written before code. No Git repo exists; work in place, retain earlier files and
seven ZIPs. Prior Harmonies snapshot extracted to
`/private/tmp/color-lab-matching-baseline.eVdpa3` for review comparison. Skill
Git-worktree/commit helpers cannot operate; no repository is initialized.

Execution: disjoint core/domain/controller and screen/router/Lab tasks can run
in parallel under explicit proactive multi-agent instruction; stable APIs above
are the dependency contract. Root owns diagnostic previews/reports/docs, not
delegate implementation files. Fresh scoped task reviews precede acceptance.

| Task/interface pair | Preflight check |
| --- | --- |
|1/2|Exact MatchingGame, MatchingAttempt, MatchingPhase and retained controller getters/methods agree; actual displayed RGB is score input|
|1/3|Preview uses public target generator override/actual controller, no production testing hooks|
|2/3|Exact route, controls/keys and actual UI flows permit real-font capture; renderer changes are disjoint|
|1|Raw HSL coordinates retained independently, bounded random targets avoid infinite dedup loops, one-shot frozen attempts and strict phases have literal behavior tests|
|2|No target hints before submit, frozen slider/no mutation feedback, details after only, confirmed restart, guarded route,48dp and token contrast explicit|
|3|Prior68 captures/source snapshots retained; fresh evidence and source ZIP inspection required|

Self-review: no conflicting files/interfaces, undefined types or placeholders.
No medical claims or new software/services are needed; target generation and
scoring reuse existing pure color math. A five-round untimed session is an
explicit sensible default, not a document-mandated scoring standard.

Task 1: complete (no Git commits; scoped spec and quality review approved).
Task 2: complete (no Git commits; scoped spec and quality review approved).
Task 3: complete (reviews, post-fix verification and validated cumulative source ZIP).

## Baseline and dispatch

`flutter test --no-pub --reporter expanded` exited0:
`00:15 +481: All tests passed!` before implementation. Log:
`/private/tmp/color-lab-matching-baseline-tests.log`.

Task1 dispatched `/root/matching_engine`; Task2 dispatched `/root/matching_ui`.
Both receive exact extracted briefs, fixed interface contracts, no-subagents
ownership and test-first/report instructions. The preview-only worker
`/root/matching_previews` owns renderer/report, preserving68 prior captures.
Explicit task-brief output paths avoid Git-only workspace setup in this project.

Task2 design clarification during layout review: stacked full swatches would
scroll out of view while adjusting Lightness at360px. The game needs simultaneous
visual comparison, not memory matching. Add a natural-height compact pinned
Target/Your match comparison using the same actual RGB and hidden-value policy;
pin behavior gets an observed scroll-to-Lightness RED before implementation.
Design/plan/task brief updated; no interface, dependency or product-scope change.

## Task1 evidence and review

Twenty-eight focused core/domain/controller tests pass, seven owned Dart files
format clean, scoped analysis reports no issues. The first missing-API RED
showed+0−3 compilation failures; its shell wrapper ended in tail and masked
Flutter's exit, explicitly disclosed in `matching-task-1-report.md`. Later
focused GREEN/analyzer/formatter exits are preserved. No assertion RED is
claimed for the initial absent APIs.

The implementer's one full suite ran before sibling UI was ready:510 passes,
12 matching UI failures, all named in the report; no legacy/core failure.
Root must supersede that intermediate failure with a fresh cumulative run.

Independent reviewer `/root/matching_engine_review` inspected the full scoped
baseline diff, brief/report and existing RGB immutability/equality/neutral-HSL
normalization dependency. Spec compliance and code quality approved, no
critical/important/minor findings. Confirmed actual RGB score/exactness, bounded
targets, raw-coordinate restoration, private immutable phase transitions,
retention/container isolation and atomic failed restart behavior. Platform/UI
compatibility remains root verification, not inferred from this scoped review.

## Task2 implementation and visual handoff

Fourteen matching integration tests pass. Lab CTA and guarded root route, exact
display-RGB feedback, hidden values/detail actions, neutral-coordinate retention,
frozen/repeated callbacks, five-pair summary/replay, restart modal/system Back,
other draft/storage isolation and360px2×reduced-motion states are covered.
The pinned comparison had an observed behavioral RED after scrolling to Lightness,
then GREEN. Earlier fixture/import/semantics/scroll misses were diagnosed and
documented without relaxing literal RGB/score/hidden-hint expectations. Scoped
analysis and four-file formatting passed; the implementer's own full suite
passed523/523. See `matching-task-2-report.md`.

Task2 scoped reviewer approved actual baseline diff, spec compliance and quality
with no findings. Existing shared widget semantics/48dp sizing and reduced-motion
propagation were checked as named external risks. Core/generator correctness is
independently covered by Task1 review; native execution is a stated device limit.
Diagnostic renderer worker preserved68 capture paths and added14 matching views;
it used actual controllers/screens/submission snapshots, not fake UI/model data.
Root formatted the preview-only extension after the first full formatting check
found one unformatted file, then reran formatting and the complete renderer.

## Pre-fix root verification (superseded below)

After all production implementation and the preview formatting normalization:

```text
flutter test --no-pub --reporter expanded
00:18 +523: All tests passed!
exit 0

flutter analyze --no-pub
No issues found! (ran in 5.1s)
exit 0

dart format --output=none --set-exit-if-changed lib test tool
Formatted 134 files (0 changed) in 0.42 seconds.
exit 0

flutter build apk --debug --no-pub
Running Gradle task 'assembleDebug'... 15.1s
Built build/app/outputs/flutter-apk/app-debug.apk
exit 0

flutter test tool/render_previews.dart --no-pub
00:09 +2: All tests passed!
exit 0
```

Counts:481 baseline +28 core/domain/controller +14 matching UI =523 tests.
Renderer:82 actual PNGs, preserving68 and adding14. Root inspected editing,
feedback, restart and summary across themes, including360px2×editing/feedback/
summary; both actual comparison colors stay visible with controls, no overflow
or missed-hit warnings. Preview worker inspected every new output; see
`matching-preview-report.md` for filenames, fixture scores and limitations.

Logs: `/private/tmp/color-lab-matching-{full-tests,analyze,apk,previews}.log`.
This fresh full suite supersedes Task1's transient unfinished-UI failures.
No required tests are excluded, and no device installation/data clear occurred.
`pubspec.yaml`/lock match the baseline. Android/iOS diffs contain only local
generated/cache files, no native source changes. Seven older ZIP hashes match
the pre-implementation snapshot. Source packaging excludes generated/local files.

At that stage, remaining gates were whole-module final review and validated
cumulative source archive. Physical camera/device, iOS, native screen-reader and
predictive-back execution remain unverified; game points are not medical results.

## Final interaction probe / one fix wave

Whole-module independent review approved the cumulative diff without findings.
Before packaging, root noticed that the unchanged scroll view might retain its
offset when showing results or replaying. The original UI implementer added a
focused real-button360px test, without scrolling totals/target into view after
the transition. It reproduced `[summaryVisible,replayVisible]=[false,false]`:
summary offset1098 put Total points at y−792..−770; replay offset840 put the
new full Target at y−492..−292. Existing tests asserted generated content, not
its entry viewport. This is a verified usability defect, not a speculative fix.

The one final fix wave is scoped to the screen's scroll ownership and behavioral
test. Reset on new round/new target snapshot or entering/leaving completion;
do not reset coordinate/theme edits or editing→feedback. Domain, scoring and
controller remain unchanged. Cover summary/replay visibility and retained
ordinary-edit offset, then scoped re-review and fresh aggregate checks before
source packaging. Earlier523-test/APK evidence is pre-fix, not final delivery.

## Final fix acceptance and post-fix proof

The viewport finding was addressed by the original implementer in one fix wave.
Scoped re-review approved: no new breakage or outside observations. Screen-owned
scroll lifecycle and exact reset conditions match the intended behavior; two new
tests verify both visible result/replay entry and ordinary offset retention.
No core/domain/controller, package, native or storage changes in the fix wave.
Whole-module and scoped final verdicts: `matching-final-review.md`.

All commands below ran after the final narrowed viewport fix, with actual exit0:

```text
flutter test --no-pub --reporter expanded
00:24 +525: All tests passed!

flutter analyze --no-pub
No issues found! (ran in 4.5s)

dart format --output=none --set-exit-if-changed lib test tool
Formatted 134 files (0 changed) in 0.65 seconds.

flutter build apk --debug --no-pub
Running Gradle task 'assembleDebug'... 40.3s
Built build/app/outputs/flutter-apk/app-debug.apk

flutter test tool/render_previews.dart --no-pub
00:14 +2: All tests passed!
```

Final count:481 baseline +28 core/domain/controller +16 UI =525. Renderer remains
82 PNGs (68 preserved +14 matching). Root inspected refreshed enlarged dark
summary as well as earlier editing/feedback/restart and both-theme enlarged
views. No layout/overflow/hit-test warnings in the final run. Exact logs retain
the same paths above, now containing post-fix proof.

Final APK: `build/app/outputs/flutter-apk/app-debug.apk`,190,124,533 bytes;
SHA-256 `1986b60e39c94af8bbc2bacb71b14dc7cf427899f3476ff60bbb581d56b12b2c`.
No device installation or data clear. Prior seven archives and all user/device
data remain untouched.

## Source handoff and completion

`dist/color-lab-matching-2026-10-21.zip` created from cumulative lib/assets/test/
tool/docs/native-source, pubspec/lock, analysis options, README and app metadata.
`unzip -tq` exited0 with no compressed-data errors. Manifest inspection confirmed
the new pure math, domain/controller, screen, integration tests, final review
and all three bundled license notices. Exclusion scan found no local.properties,
Gradle/Kotlin caches, Pods/symlinks, generated Xcode settings, ephemeral/build
output, xcuserdata, IDE/DS_Store files or Flutter shell environment scripts.

Seven preceding ZIP hashes still match the pre-implementation snapshot. No
dependencies, native source, assets or existing storage schema changed. The
archive is refreshed and integrity-checked after final plan/ledger edits; all
required work for this module is complete. Next module is procedural color-vision
plates, only on a subsequent request; no vision plates/room-photo work started.
