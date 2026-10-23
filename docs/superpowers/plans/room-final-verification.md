# Room auto and manual masks — final verification

Date:2026-10-22. Main executor ran these fresh checks after the late retained-claim
and archive portability fixes and their approved scoped re-review. Feature,
verification and source-delivery gates are complete. The documentation-inclusive
archive is generated as the terminal release step after this evidence is saved;
its final SHA-256 is reported in the external delivery handoff. No blocking review finding remains. One
nonblocking test-strength minor is disclosed below. Earlier785-test evidence is
historical, superseded by the two new regression tests and fresh787-test run.

## Observed gates

| Gate | Observed result |
| --- | --- |
| Complete Flutter test suite | Exit0, `00:22 +787: All tests passed!` |
| Actual bundled-model/default production worker smoke | Exit0,PASS,TFLite2.11.0,all1091840 aligned working pixels |
| Whole Flutter analysis | Exit0, `No issues found!`,2.4s |
| Read-only Dart formatting | Exit0,186 files,0 changed |
| Full preview renderer | Exit0,+5,All tests passed |
| Fresh capture manifest | 140 unique writes,104 legacy names retained,36 Room captures |
| Scoped late-fix review | Both retained-photo race and missing-dist portability findings approved; one nonblocking test-strength minor deferred |
| Platform floors | Android24/iOS13 configs byte-equal to original baseline |
| Old source archives | All nine original SHA-256 values still match ledger baseline |

Exact commands, run from the project root with Flutter installed at
`/Users/jamirulislam/Applications/flutter`:

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dartvm tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart --suppress-analytics format --output=none --set-exit-if-changed lib test tool
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test tool/render_previews.dart --no-pub --reporter expanded
```

Every Flutter run retained the fail-closed compiler guard. No compiler denial,
native build, APK generation, install, clean, data clear, SDK/pub-cache patch or
cache deletion occurred in these final checks. Earlier dependency-hook host
compilation is explicitly corrected in `room-verification-guard.md`.

## Real AI identity

Final smoke stage: `color-lab-room-smoke.042Bw0`; actual emitted evidence:
`color-lab-task5-evidence.3nJsKL`. These temporary names identify this run, not
runtime dependencies. Portable recorded output remains under test fixtures.

- Model SHA-256: `da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c`.
- Descriptor SHA-256: `cf1bb10c7518cb4ff5e5403f856f1342280dbce8341a72c26fbd06d2e345d533`.
- Final/portable mask SHA-256: `5ab660689348ba538d622d681742d365d50ce8f08ee8bb3a8712bfa733c840ba`.
- Working map1280×853; Wall531957,Ceiling88231,Floor46027,Furniture218905,
  unselected206720;260UI heartbeat ticks during the actual worker run.

Candidate analysis previews now show the unchanged photo before editable masks.
Main inspected light/dark candidate analysis, the selected Wall overlay, the
360dp/2× dark editor and enlarged replacement dialog; no defect was observed.
Synthetic pixel tests and recorded previews are
not represented as native inference. Model errors around people/ornate surfaces/
sofa/pillows remain visible and documented. Three candidates on a small sample
support the balanced selection, not universal accuracy or phone superiority.

## Late independent review and fix

After the earlier completion record, independent review exposed a route-lifetime
photo-loss race and source-archive failure when `dist` was absent. Both were
reproduced before fixes and approved in scoped re-review; see
[the late fix report](room-final-race-fix-report.md). Focused controller/full-app
tests passed66 cases. The retained controller now guards receipt ownership across
route disposal and rejects stale continuations before candidate mutation; the
archive recipe safely creates its exact output parent.

One nonblocking Minor remains deferred: the full-app regression conditionally
taps the stale confirmation. The controller regression independently and
unconditionally pins retained ownership. This is a test-strength concern, not
a product defect or blocking gate.

## Preservation and scope

The user confirmed independent build/run activity. The original APK hash
`1986b60e…` changed first to`00896bea…`; latest observed copies both hash
`eb36f749379d33e82644e6c61861647ccb88c685479ff780bd3bd2959fa0a3ae`,
size162563223,modified2026-10-22 10:37:35+0600. Neither was written, restored,
deleted or delivered by this workflow. No assumption is made about the precise
cause of the later update. All nine preceding source ZIP hashes still match.

Android24/iOS13 physical execution, native accessibility, mobile latency/memory
and delegates remain unverified. Photos/masks/undo are session-only, bounded to
the working image. Durable operational intent is not project persistence.
Photo recolor/comparison/suggestions/projects/export remain later modules.

## Source handoff

Only `dist/color-lab-room-masks-2026-10-22.zip` is refreshed by:

```sh
ruby docs/superpowers/plans/room-source-archive-recipe.rb
```

The helper validates integrity, safe unique project-relative paths, exact source
manifest, required files, exclusions and every archived byte. APK/AAB,build,
caches,host native libraries,local secrets/generated environment,Pods,symlinks,
IDE files and previous ZIPs are excluded. Gradle wrapper tooling, model/license
assets and real-model fixtures are included. The initial post-fix refresh exited0
with397 unique project-relative entries; integrity, exact manifest, required files,
exclusions and every archived byte passed. Its pre-documentation SHA-256 was
`0592892f62a42d3c8004e38429016ef5b26313723d76fc4735936bf772766eac`.
This supersedes the earlier396-entry archive evidence. The final identical recipe
refresh runs after this documentation state is saved, includes these edits and
revalidates every archived byte. Its exit result and SHA-256 are reported in the
external handoff rather than embedded here, because changing this file would
change the self-containing archive and its checksum.
