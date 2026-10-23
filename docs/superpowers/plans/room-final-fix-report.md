# Room final review fix wave

Status: DONE. Four bounded findings addressed. No commits, Git operations,
worktrees or subagents. Baseline:
`/private/tmp/color-lab-room-final-fixbase.n3aFzW/source`.
Parent owns the next scoped review, fresh full suite/model smoke and final
archive/documentation gates; those were not rerun or updated here.

Parent final acceptance: scoped re-review read all779 fix lines and approved all
four findings with no new breakage. Main subsequently observed785 full tests,
real bundled-model/default-worker smoke, clean whole Flutter analysis,186-file
format check and renderer5/5 with140 fresh captures. See
`room-final-verification.md` for final source-only delivery evidence.

## Changes and per-finding evidence

1. Candidate photo: the screen renders `Image.memory` from the candidate's
   unchanged prepared preview bytes during analysis and staged continuation.
   It has a stable accessible key, image semantics, finite 300dp height and
   contain fitting. No masks/editing are attached to it. The keyed offstage
   editor remains intact. `candidate photo is visible through initial and
   replacement analysis` waits for actual RawImage decoding and reads decoded
   RGBA: initial gray100 and equal-sized replacement gray50. It checks absent
   editing, retained old-photo ownership, the exact same viewport element after
   cancellation and failure/Return, and ignored late cancelled completion.
   The existing hidden-during-durable-claim case now verifies the actual decoded
   candidate before Analyze. Both existing 360dp/2x-text/reduced-motion theme
   cases now inspect the analysis photo and its visibility without layout errors.
   Existing zoom/revision/theme/failure/reset and stale callback coverage passes.

2. Repeated continuation: a synchronous screen-local operation identity guards
   import/claim dispatch before the first await and disables the continuation
   action while outstanding. Logical Cancel releases it immediately; a stale
   finally only clears its own operation. This does not disable all acquiring
   states. `repeated Continue cannot invalidate a durable claim` sends two actual
   taps before a rebuild with durable clearing withheld: one clear, one analysis,
   no failure, consumed receipt and editable successful result. The original
   RED dispatched the same pre-rebuild callback twice; the final test strengthens
   this to actual taps. `cancel releases import guard and stale completion cannot
   release a newer claim` starts a new import before cancelled inference ends,
   completes that old inference while the new durable clear is held, verifies
   the new continuation is still disabled, then commits the new Floor result.
   Existing hidden-owner, late-picker and explicit recovered-owner paths pass.

3. Empty AI copy: the explanation uses immutable `draft.aiMasks` counts.
   `erasing all detected pixels does not describe an empty AI result` starts
   with exactly one detected Wall pixel at index55, erases it through the real
   viewport/worker, verifies zero editable pixels but one AI pixel and no false
   empty-inference explanation. `manual addition preserves the genuine empty AI
   explanation` starts with valid empty AI, manually adds a pixel and retains
   the truthful AI explanation.

4. Raster completion: viewport tests now poll the actual painter's decoded photo
   and, where required, overlay with a bounded 500x10ms wait. Pending-overlay
   cases explicitly wait for photo only; post-disposal completion only pumps
   the stale-result microtask. No intentionally withheld result is awaited.
   `raster completion waits for output slower than eighty milliseconds` schedules
   a controlled real-time 250ms completion and verifies both the actual red
   raster pixel and elapsed time >=250ms. It genuinely failed under the old
   80ms helper. Real isolate-render/decode tests use the same observable wait.
   There is no product test hook or viewport production change.

The preview renderer now observes the candidate's actual RawImage decoded image
before the existing analysis capture, using its existing bounded wait. All
capture stems remain. Both analysis captures were visually inspected: original
room photo, progress text and Cancel are visible in light/dark.

## TDD RED

All commands ran from `/Users/jamirulislam/Movies/dart_jpo/color_lab`.
The first guarded test attempt was stopped by the outer sandbox, exit71,
`sandbox_apply: Operation not permitted`, before Flutter ran. It is not RED.
The retry retained the exact inner compiler barrier and used approved outer
escalation. Before any product edits or replacement of the old flush helper:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_masks_integration_test.dart test/features/room_studio/presentation/room_mask_viewport_test.dart --name 'candidate photo is visible|repeated Continue|cancel releases import guard|erasing all detected|manual addition preserves|raster completion waits' --reporter expanded
```

Exit1, `+0 -6`, six expected behavior failures, no load/compile errors:

- Candidate photo: expected one `room-mask-candidate-photo`, found zero.
- Repeated Continue: expected disabled action, got a callback.
- Cancel/new claim: expected disabled new continuation, got a callback.
- Complete erasure: false empty-AI explanation was present.
- Manual addition after empty AI: expected AI explanation, found zero.
- Controlled slow raster: expected red channel >100, actual100; output had not
  completed at the fixed80ms assumption.

## Focused GREEN

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_masks_integration_test.dart test/features/room_studio/presentation/room_mask_viewport_test.dart --reporter expanded
```

Initial implementation run: exit0, `00:04 +44: All tests passed!`.
After strengthening duplicate dispatch to actual taps and asserting retained
viewport element identity on Cancel/Return, the final same command exited0,
`00:05 +44: All tests passed!`: 26 integration +18 viewport tests, six new tests
over the 38-test focused baseline. No failed/skipped tests or warnings/errors.

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test tool/render_previews.dart --no-pub --reporter expanded
```

Exit0, `00:12 +5: All tests passed!`. No renderer changes occurred after this run.
Manifest validation:

```sh
ruby -rjson -e 'm=JSON.parse(File.read("build/previews/render-manifest.json")); names=m.fetch("files"); room=names.count { |n| n.start_with?("room-masks-") }; abort "unexpected preview set" unless names.uniq.length == 140 && room == 36 && names.length-room == 104; puts "PASS: #{names.length} fresh captures, #{room} Room + #{names.length-room} legacy"'
shasum -a 256 test/fixtures/room/reference_masks.bin
```

Both exit0. Manifest: `PASS: 140 fresh captures, 36 Room + 104 legacy`.
Recorded mask SHA-256 remains
`5ab660689348ba538d622d681742d365d50ce8f08ee8bb3a8712bfa733c840ba`.
The renderer's recorded-fixture test also passed its full identity checks.

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics analyze lib/features/room_studio/presentation/room_mask_screen.dart test/features/room_studio/presentation/room_masks_integration_test.dart test/features/room_studio/presentation/room_mask_viewport_test.dart tool/render_previews.dart
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test tool
```

Final checks after the last test edit both exit0: `No issues found!` and
`Formatted 186 files (0 changed)`. Formatting writes were restricted to owned
Dart files. Earlier versions of these gates also passed; no failure was omitted.

## Files and self-review

- `lib/features/room_studio/presentation/room_mask_screen.dart`
- `test/features/room_studio/presentation/room_masks_integration_test.dart`
- `test/features/room_studio/presentation/room_mask_viewport_test.dart`
- `tool/render_previews.dart` (candidate capture wait only)
- This report; generated existing preview PNGs/manifest from the renderer.

Read-only diffs against the supplied baseline were inspected for all four Dart
files. The screen-only production changes preserve the existing viewport key,
offstage retention, captured controller revisions and route/lifecycle checks.
No producer/controller/viewport/core/native/dependency edits were needed.
No root README/ledger, archive or fixture edit. No APK/native build, install,
clean/data clear, dependency fetch, cache deletion, SDK/pub-cache patch,
private native bindings or `dart run`. Every Flutter command kept the native
compiler barrier. Existing APKs and all old source ZIPs were untouched.

No outstanding correctness concern was identified in this bounded wave.
Host UI tests/previews do not establish native phone compatibility or model
accuracy. Parent-owned final full verification and archive refresh remain.
