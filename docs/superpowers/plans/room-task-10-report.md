# Task 10 — preview and source-delivery preparation

Status: feature, verification and source-delivery gates complete. The final
documentation-inclusive archive is the parent terminal release step. Parent observed787 full tests, real
production-model smoke, clean whole Flutter analysis,186 formatted files and
renderer5/5 with140 fresh captures after the late retained-photo race/archive
portability fixes. Scoped re-review approved both late findings; no blocking
review finding remains. One nonblocking test-strength minor is deferred: the
full-app regression conditionally taps stale confirmation, while the controller
regression independently and unconditionally pins retained ownership. This is
not a product defect or blocking gate. See `room-final-verification.md` and
`room-final-race-fix-report.md`. Sections below preserve the scoped handoff history.
No commits or Git operations. Baseline is
`/private/tmp/color-lab-task10-base.78A8Bh/source`; brief is
`room-task-10-brief.md`, including its execution corrections.

Initial post-fix parent source refresh passed397 unique project-relative entries:
integrity, manifest safety, required files, exclusions and all archived bytes match.
Pre-documentation archive SHA-256:
`0592892f62a42d3c8004e38429016ef5b26313723d76fc4735936bf772766eac`.
The final identical recipe refresh runs after this report is saved to include these
documentation edits and revalidate every byte. Its terminal result and SHA-256
are reported in the external delivery handoff so this self-containing archive is
not mutated merely to record its own changing checksum. Task10 is complete. The
remaining scoped sections preserve earlier evidence and limits.

## Implemented scope

The existing renderer loops/calls and all104 legacy stems remain. Its normal
app harness now overrides the existing shared in-memory acquisition-intent store.
New Room tests use the real application/router, retained controller, refinement
worker and viewport. Only native photo acquisition and segmentation are boundary
replacements, with explicit completers controlling progress/pending/error cases.
The reference photo is prepared through real `preparePhoto`; segmentation replies
contain the exact recorded Task5 production-service output, never fabricated AI
masks. There is no native inference in widget previews.

New bounded waits observe actual worker/revision completion and decoded photo/
overlay fields on the actual viewport painter. No product screenshot hook,
fixed80ms completion assumption or new indefinite progress `pumpAndSettle` was
added. Captures target `room-mask-viewport`, retain real bundled fonts and verify
no framework exception. A per-invocation `build/previews/render-manifest.json`
records only stems actually written, rejecting duplicate captures.

`reference_masks.bin` is a verbatim copy of the frozen Task5 output:
SHA-256`5ab660689348ba538d622d681742d365d50ce8f08ee8bb3a8712bfa733c840ba`,
1,091,840 bytes,1280×853. `cmp` against the frozen original exited0.
Portable `reference_masks.json` retains actual runtime, model/descriptor/input/
photo identities, recipes, counts, timing/heartbeat observations and limitations,
with project-relative mask identity replacing temporary `maskPath`. It adds
Daderot CC0 attribution and visible-error context. Its SHA-256 is
`53261fbccf49a5b6d0be66483e796587e5f93bc16e4155c7c7fd91dc8fa41d0a`.
Metadata was checked for temporary absolute path leakage: none.

README and asset sources now distinguish real offline AI/manual masking from
derived display overlays, the existing illustration-only Use in Room action,
and deferred recolor/projects/export. They document session lifetime,1600px
working limit, operational acquisition intent, bounds, model notices/checksums,
TFLite Flutter0.12.1/host2.11.0 and unverified mobile/device limits. Model output
is not dense ground truth: person-as-chair, ornate surfaces and sofa/pillows
remain errors; no global-best or accuracy-percentage claim is made.

The portable guard is byte-identical to the reviewed temporary profile (`cmp`
exit0). README and guard examples use `COLOR_LAB_FLUTTER_ROOT`, guarded Flutter
commands and direct `dartvm` smoke. Fresh clones may fail closed without cached
native test assets. Documentation qualifies no-APK claims as our workflow: the
user independently built/ran the newer APK. Both retained APK copies were observed
at SHA-256`00896beade2a82a2f99908e203b1f4c56a07daa8ef678dcd7f13d85a220d2ae7`,
differing from historical`1986b60e…`. Neither was overwritten or built here.
All nine old source ZIP hashes still matched the ledger baseline when checked.

## Diagnostic RED and focused GREEN evidence

Every command ran from the project root. The first guarded Flutter attempt
exited71, `sandbox_apply: Operation not permitted`, before Flutter execution.
This was an outer execution restriction, not a behavioral RED. Reissued commands
used approved outer escalation with the identical inner compiler-denial guard.

Before adding the recorded fixtures, this command exited1 with the expected
missing-fixture failure (`PathNotFoundException` for`reference_masks.json`,+0-1):

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test tool/render_previews.dart --no-pub --plain-name 'recorded Room masks retain portable actual-model identity' --reporter expanded
```

This is diagnostic fixture RED, not a claimed product-behavior RED. No production
code was changed. The fixture check was expanded to verify actual binary SHA,
label domain/counts and model/descriptor/photo/input bytes against metadata.

The focused new-workflow run with`--plain-name 'recorded'` exited0,+3:
fixture identity and both Room themes passed. A complete renderer run then
exited0,+5. After adding stronger identity and current-invocation manifest
checks, the final scoped renderer command was:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test tool/render_previews.dart --no-pub --reporter expanded
```

Observed final output: `00:12 +5: All tests passed!`, exit0. No failing/skipped
tests or native compiler attempt appeared. The generated manifest reported
**140 actually captured PNGs: all104 original stems plus36 new Room captures**.
A Ruby comparison against the104-line frozen preview baseline confirmed no old
stem missing. This proves fresh writes, rather than counting preexisting PNGs.

Final scoped analysis and global read-only formatting checks:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics analyze tool/render_previews.dart
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test tool
```

Both exited0: `No issues found!`; `Formatted 186 files (0 changed)`.
Formatting mutations were restricted to owned`tool/render_previews.dart`.
No full suite or native smoke was rerun by this implementer; the prior reviewed
baseline is779 tests. Parent performs fresh final gates after reviews.

## New capture names

Each stem below has both`-light.png`and`-dark.png`under`build/previews/`, for36:

```text
room-masks-empty
room-masks-import-progress
room-masks-analysis-progress
room-masks-reference-wall
room-masks-reference-ceiling
room-masks-reference-floor
room-masks-reference-furniture
room-masks-add
room-masks-erase
room-masks-undo
room-masks-restore-dialog
room-masks-restored
room-masks-original
room-masks-editor-360-text2x-reduced-motion
room-masks-restore-dialog-360-text2x-reduced-motion
room-masks-replace-dialog-360-text2x-reduced-motion
room-masks-pending
room-masks-error
```

Visually inspected light Wall, dark Floor, enlarged light editor and enlarged
dark replacement dialog. The real photo/selected overlays align; model errors
remain visible, text is readable and dialog actions fit. The parent independently
inspected these same captures with no visual defect reported. These are host UI
evidence, not phone/native-inference/accuracy evidence.

## Source archive recipe and status

The reproducible checked-in helper is
`docs/superpowers/plans/room-source-archive-recipe.rb`; run exactly:

```sh
ruby docs/superpowers/plans/room-source-archive-recipe.rb
```

It writes only`dist/color-lab-room-masks-2026-10-22.zip`, synchronizing that
authorized generated archive on refresh. The exact target was checked absent
before initial creation. It includes project-relative lib/assets/tests/fixtures/
tools/docs/native source, pubspec/lock, licenses/README/config/metadata/gitignore,
including Gradle wrapper JAR/scripts. It rejects symlinks and unsafe manifest
paths, excludes build/caches/IDE/previous archives/secrets/local.properties/Pods/
ephemeral/generated plugin registrants/native host libraries/APK/AAB, runs
`unzip -tq`, verifies unique nonabsolute/nontraversal entries and exact manifest
equality, checks required sources and compares every archived file byte-for-byte
with the workspace. Final archive refresh after parent report/ledger updates is
still required; this scoped handoff is provisional until those gates pass.

The initial helper run exited0: `No errors detected in compressed data` and
`PASS: 394 project-relative entries; all source bytes equal; required sources
included; exclusions clean`. The report was then updated with that evidence and
the same helper rerun to include this report in the provisional archive. Parent
will refresh again after final gate/review/ledger changes.

## Files and self-review

Owned changes: `tool/render_previews.dart`, `tool/deny-native-compilers.sb`,
`test/fixtures/room/reference_masks.bin`, `reference_masks.json`, `README.md`,
`docs/asset-sources.md`, `room-verification-guard.md`, this report, the archive
recipe and the new source ZIP. No product API, producer, dependency/native target
or other test was edited. Read-only comparisons found no`lib`difference and only
the two new fixtures under`test`against the Task10 snapshot.

No outstanding correctness concern was found in the owned work. Final parent
gates and provisional archive refresh are expected remaining workflow, not a
product defect. No APK/native build, install, clean, data clear, cache deletion,
SDK/pub-cache patch, dependency fetch,`dart run`, Git operation or subagent
delegation was performed.

Execution was interrupted after the final scoped checks and before report/archive
creation. At resumption no process or tool session remained running/blocking.
The wall-clock gap reflects the interrupted turn; no hidden verification or
long-running tool is claimed for that interval.
