# Final retained-claim and archive portability fix

Status: DONE for the two assigned defects. Work was performed in place against
`/private/tmp/color-lab-room-race-fix.97vbcb/source`, without Git, worktrees,
subagents, or unrelated product edits. The parent owns cumulative verification,
final delivery documentation, and any workspace archive refresh.

## Retained claim/photo-loss race

Root cause: the screen-local import guard disappears when Back disposes the
editor. While its retained controller is awaiting durable receipt clearing, a
reopened editor can open a second replacement confirmation. The first claim
accepts candidate B and removes its receipt. Confirming that second dialog then
called `_startImport` before checking receipt eligibility, clearing B and
reporting an acquisition error. Draft A remained, but B's sole pixels were lost.

`RoomMaskController` now retains the current claim's operation identity and
rejects duplicate continuations while that operation owns the claim. It also
checks that a matching, Room-compatible receipt is currently ready before
calling `_startImport`. An already accepted or otherwise stale continuation is
therefore a no-op before any candidate/state mutation. The claim identity uses
one nullable integer, checks the existing operation revision, and is released
in a matching-operation `finally`; old physical cleanup cannot clear a newer
claim's identity. Existing logical cancellation/supersession still invalidates
ownership and retains unaccepted receipts. No acquisition-coordinator or
presentation production change was necessary.

The new full-app test is named
`reopened editor stale Continue cannot lose a replacement accepted during durable clear`.
It uses the actual app, router, retained Room controller, acquisition
coordinator, and editor, with existing external picker/storage/segmenter
doubles. It commits Wall draft A, starts equal-sized gray50 replacement B,
withholds durable clearing, uses Back and reopens the editor, and opens Continue
before clearing completes. It then accepts the stale confirmation, verifies
the identical accepted candidate remains owned and its receipt is consumed,
decodes B's actual displayed pixels, explicitly selects Analyze, and verifies
A stays committed until B successfully commits its Floor masks. No hidden
analysis starts after the original screen is disposed.

The new controller test is named
`retained receipt claim rejects duplicate and stale continuations without losing pixels`.
It checks a duplicate continuation during clearing, a stale continuation after
hidden acceptance, preservation of A through B's analysis, and successful
continuation of a later independent receipt. This last assertion prevents a
permanent retained lock. Existing same-screen tests remain intact and pass,
including two actual Continue taps before rebuilding and cancellation followed
by an old inference completion while a newer durable claim is pending.

## Mandatory RED evidence

All Flutter commands below ran from the workspace root. The first attempt of
the first command was denied by sandbox nesting, exit71,
`sandbox-exec: sandbox_apply: Operation not permitted`, before Flutter executed.
That is infrastructure evidence, not RED. The retry used outer escalation with
the identical inner native-compiler guard; every later Flutter command retained
that guard and used the same allowed escalation.

Before any production change:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_masks_integration_test.dart --name 'reopened editor stale Continue' --reporter expanded
```

Exit1, `00:01 +0 -1: Some tests failed.` The expected failure was:

```text
Expected: same instance as <Instance of 'RoomPhotoCandidate'>
  Actual: <null>
A stale continuation must not clear the already accepted photo
```

The newly added controller regression also ran before production changes:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/application/room_mask_controller_test.dart --name 'retained receipt claim rejects' --reporter expanded
```

Exit1, `00:00 +0 -1: Some tests failed.` Expected
`RoomMaskStage.acquiring`, actual `RoomMaskStage.error`, after the duplicate
continuation during the first retained claim. Both RED results are behavioral
failures against real controllers; there were no load/compile errors.

## Archive portability RED and GREEN

Before editing the recipe, a controlled source copy was made with no `dist`
directory. The copy excluded generated build/cache/native-local files and
contained the recipe's required real source/model/fixture files:

```sh
mktemp -d /private/tmp/color-lab-archive-race.XXXXXX
rsync -a --exclude=build --exclude=.dart_tool --exclude=.gradle --exclude=.kotlin --exclude=Pods --exclude=.symlinks --exclude=ephemeral --exclude=local.properties --exclude=.DS_Store lib assets test tool docs android ios README.md pubspec.yaml pubspec.lock analysis_options.yaml .metadata .gitignore /private/tmp/color-lab-archive-race.F5yg2z/
```

The following exact documented command ran with working directory
`/private/tmp/color-lab-archive-race.F5yg2z`:

```sh
ruby docs/superpowers/plans/room-source-archive-recipe.rb
```

RED: exit1 before the fix, with
`zip I/O error: No such file or directory` and
`Could not create output file (dist/color-lab-room-masks-2026-10-22.zip)`.
An initial login-shell invocation also emitted the environment's RVM
`operation not permitted: ps`; the identical command was repeated without a
login shell and reproduced only the expected archive failure.

The recipe now creates only `File.dirname(target)` with `Dir.mkdir`, checks
that this exact parent is a real directory rather than a symlink, and preserves
the exact authorized target path. Target validation now also rejects dangling
symlinks, which `File.exist?` alone does not detect. All prior manifest,
exclusion, required-source, integrity, entry equality and every-file byte
equality checks remain unchanged.

Only the fixed recipe was copied into the same scratch source tree:

```sh
cp docs/superpowers/plans/room-source-archive-recipe.rb /private/tmp/color-lab-archive-race.F5yg2z/docs/superpowers/plans/room-source-archive-recipe.rb
```

The same `ruby docs/superpowers/plans/room-source-archive-recipe.rb` command,
still from that scratch working directory with `dist` absent, exited0:

```text
No errors detected in compressed data of dist/color-lab-room-masks-2026-10-22.zip.
PASS: 396 project-relative entries; all source bytes equal; required sources included; exclusions clean
3b9d2553bac27d2da6f5fc1475e64a42c9db00d9eece287e34571d04460aa1e8  dist/color-lab-room-masks-2026-10-22.zip
```

This hash describes the controlled scratch fixture, not a refreshed delivery
archive. The workspace archive was never opened or overwritten here.

A scratch-only behavioral harness was written with `apply_patch` at
`/private/tmp/color-lab-archive-safety.rb` and executed as:

```sh
ruby /private/tmp/color-lab-archive-safety.rb
```

Exit0, `PASS: 9/9 archive portability and exact-target safety cases`:

- Fresh source with absent `dist`: successful full recipe checks.
- Existing real output parent: successful full checks, prior ZIP preserved.
- Existing valid authorized target: successful synchronization of that target.
- File as output parent: rejected without changes.
- Symlink and dangling symlink output parents: rejected without changes.
- Directory as target: rejected without changes.
- Symlink and dangling symlink targets: rejected without changes.

For every case the harness snapshots all relative paths and file SHA-256 values
before and after running the real recipe. Successful cases permit only the
exact parent directory and exact target archive to appear/change. Rejected
cases require the entire snapshot to remain equal, including symlink targets,
external sentinel bytes, and previous ZIP bytes. Each successful case also
requires the real recipe's manifest/integrity/exclusion/byte-equality result.

## Final focused GREEN and source checks

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/presentation/room_masks_integration_test.dart test/features/room_studio/application/room_mask_controller_test.dart --reporter expanded
```

Initial GREEN: exit0, `00:05 +66: All tests passed!`. After formatting and
strengthening the later-receipt assertion to use explicit Continue, the final
same command again exited0, `00:05 +66: All tests passed!`:
27 full-app integration tests plus39 controller tests, two new tests total.
No failures or skipped tests were reported.

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics analyze lib/features/room_studio/application/room_mask_controller.dart test/features/room_studio/application/room_mask_controller_test.dart test/features/room_studio/presentation/room_masks_integration_test.dart
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test tool
```

Final analyzer exit0: `No issues found!`. Final read-only global formatter
exit0: `Formatted 186 files (0 changed)`. The initial read-only formatter
reported two unformatted owned test files, exit1; those two files alone were
then formatted, and the final global check above passed. No unrelated
formatting writes occurred.

## Files, self-review and concerns

Owned workspace changes:

- `lib/features/room_studio/application/room_mask_controller.dart`
- `test/features/room_studio/application/room_mask_controller_test.dart`
- `test/features/room_studio/presentation/room_masks_integration_test.dart`
- `docs/superpowers/plans/room-source-archive-recipe.rb`
- This report.

Read-only per-file diffs against the supplied baseline were inspected. The
only production logic change is the retained controller claim/receipt guard;
the widget-local guard, original candidate acceptance callback, operation
invalidation, explicit hidden-photo analysis and atomic draft replacement
remain in their existing components. No screen/acquisition production edits.

Baseline comparison also found these concurrent document changes that I did
not make and preserved:

- `docs/superpowers/plans/2026-10-22-room-auto-masking-progress.md`
- `docs/superpowers/plans/2026-10-22-room-auto-masking.md`
- `docs/superpowers/plans/room-final-fix-report.md`
- `docs/superpowers/plans/room-final-verification.md`
- `docs/superpowers/plans/room-task-10-report.md`

No remaining correctness concern identified within the two assigned defects.
Parent-owned cumulative tests/model smoke/review/archive gates remain outside
this focused wave. No APK inspection/modification, native build/install,
clean/data clear, dependency fetch, SDK/pub-cache patch, cache deletion,
runtime download, `dart run`, model/fixture/platform-floor edits, preview PNG
writes, previous ZIP writes, final README/ledger/archive-status edits, or Git
initialization occurred.
