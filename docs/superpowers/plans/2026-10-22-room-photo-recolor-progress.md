# Room photo recolor progress

## 2026-10-22 — Task 1, execution slice 1A

Status: slice 1A infrastructure implemented; Task 1 is **BLOCKED/PENDING
EVIDENCE** for slice 1B. Task 2 remains closed. No candidate tuning has begun.

Implemented the offline manifest/protocol loader, literal quality metrics,
macro aggregation and baseline-suitability check, read-only verifier, and blind
annotation/submission/adjudication instructions. No runtime/product module,
model asset, dependency or native configuration changed. Work occurred in place;
there is no Git repository and no commits were attempted.

Frozen v1 protocol:
`test/fixtures/room_recolor/v1/protocol.json`
SHA-256: `9bb3b0f379054af42598deebb4cc8a90e1a3e3a3a5cb5821c9587fc1281c31fb`.
The loader pins its exact bytes. Boundaries use class-specific inner pixels,
eight neighbors, outside-image background, independent any-match precision and
recall within Euclidean distance <= 5, and no match consumption. Coverage byte
1 counts as colored. Jointly absent layer/image pairs are excluded, one-sided
absence scores zero, leakage divides by each image's protected pixels, and
zero aggregate baseline leakage fails suitability before candidate tuning.

All controlled synthetic corpora and annotation bytes used in the tests were
created in OS temporary directories and removed in test teardown. The sole
production fixture created by slice 1A is `protocol.json`. There is no
production `manifest.json`, licensed photo collection or A/B/adjudicated bytes.

Verification (compiler-deny guard applied to every Flutter run):

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/tool/room_recolor/benchmark_test.dart test/tool/room_recolor/quality_metrics_test.dart
```

RED: exit 1; both files failed to load because the benchmark, scoring and
verifier APIs/files were absent. GREEN: exit 0; `00:01 +54: All tests passed!`.

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter failures-only
```

Full suite: exit 0; `+841: All tests passed!`.

Final focused run after five brace-only lint corrections: exit 0, 54 passed.
No implementation behavior changed after the full suite. Guarded
`flutter analyze --no-pub` initially reported those five brace infos, then
returned exit 0: `No issues found! (ran in 1.6s)`. Guarded read-only
`dart format --output=none --set-exit-if-changed` on all five new Dart files
returned exit 0: `Formatted 5 files (0 changed) in 0.02 seconds.` Exact commands,
RED output, final source hashes and self-review are retained in
`.superpowers/sdd/2026-10-22-room-photo-recolor/task-1-report.md`.

```sh
/usr/bin/sandbox-exec -f tool/deny-native-compilers.sb /Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dartvm tool/verify_room_recolor_benchmark.dart --root test/fixtures/room_recolor/v1 --require-adjudicated
```

Direct production verifier: expected exit 1, with:

```text
ROOM RECOLOR BENCHMARK FAILED: Missing or unreadable benchmark evidence: /Users/jamirulislam/Movies/dart_jpo/color_lab/test/fixtures/room_recolor/v1/manifest.json
```

This is pending evidence, not a frozen benchmark. Source/photo/annotation
production hashes and real human identities/times cannot be recorded yet.
Slice 1B must acquire 24 permitted distinct rooms, preserve full provenance,
obtain two genuine blind human submissions plus independent adjudication,
verify all detached bytes, and freeze the manifest/evidence before Task 2.
Baseline scoring remains separate required evidence; the corpus verifier
explicitly does not claim to have measured it. No builds, installs, cleans,
SDK/pub-cache edits, native compiler invocations or compiler bypasses occurred.

## 2026-10-22 — Task 1A independent review and resource-bound fix

Independent task review approved the frozen scoring/evidence semantics but
found one Important loader issue: an encoded image could be fully read or
decoded before its actual file and header dimensions were bounded. The fix now
checks source/working file sizes before opening, performs fixed-capacity
descriptor reads with growth/truncation detection, selects inspected decoders
by byte signature, validates real encoded axes/pixel counts before frame decode,
and retains post-decode dimension/hash/opacity checks. Animated or multi-frame
containers and unsafe nested TIFF JPEG decoding are rejected; the benchmark
accepts deterministic still JPEG, PNG, GIF, WebP, BMP and TIFF inputs.

Thirteen review-fix cases were added without allocating giant images: sparse
oversized inputs, tiny over-budget headers, animation/container rejection,
nested TIFF rejection and positive compatibility for all six formats. The
final guarded focused run passed all 67 tests. Guarded analyzer returned
`No issues found!`; the read-only formatter check reported zero changes. The
full suite was not rerun for this isolated tool-only fix, so the earlier
841-test result remains historical rather than post-fix evidence.

Scoped independent re-review found the resource-limit issue **ADDRESSED** with
no new Critical or Important breakage. Task 1A is approved. Task 1 overall is
still **BLOCKED/PENDING EVIDENCE** for the licensed 24-photo corpus, genuine
independent A/B human annotations and independent adjudication; Task 2 remains
closed.
