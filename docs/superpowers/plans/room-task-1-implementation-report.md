# Task 1 production model implementation

Date: 2026-10-22. Status: **DONE_WITH_CONCERNS** — fixed production model/host gate
passes; normal mobile/device and later-task gates remain unverified. Commits:
**none (no Git repository)**. Historical `room-task-1-report.md` and
`room-model-validation-report.md` were not edited or replaced.

Verification correction: the earlier blanket no-native-compilation wording was
too broad. Normal dependency hooks compiled existing objective_c9.5.0 macOS host
support at01:35:35/39+0600; no APK/native application/TFLite library was built.
See [guarded verification correction](room-verification-guard.md). Remaining
checks use a compiler-deny barrier and direct Dart VM; historical counts remain.

## Delivered scope

Created:

- `assets/models/room_seg.tflite`, `assets/models/room_seg_descriptor.json`.
- `assets/licenses/room-model-LICENSE.txt`, `assets/licenses/room-model-NOTICE.txt`.
- `lib/features/room_studio/segmentation/room_model_descriptor.dart`.
- `lib/features/room_studio/segmentation/raw_segmentation.dart`.
- `lib/features/room_studio/segmentation/room_model_runner.dart`.
- `tool/verify_room_model.dart`, `tool/run_room_model_smoke.dart`.
- `test/features/room_studio/segmentation/room_model_descriptor_test.dart`.
- `test/fixtures/room/reference_room.png`, `reference_input.bin`,
  `model_reference.json`, `reference_room.LICENSE.txt` in that same directory.
- This report and `room-model-production-validation-report.md`.

Modified: `pubspec.yaml`, `pubspec.lock`, `lib/main.dart`, `docs/asset-sources.md`.
Lock changes are only direct crypto3.0.7, new tflite_flutter0.12.1 and its
quiver3.2.2 dependency. No platform configuration edits were necessary;
`android/app/build.gradle.kts` and `ios/Podfile` compare byte-for-byte with the
controller's baseline. No future Task2/worker/acquisition/UI/manual code exists
in this change. All other baseline `lib/` source compares unchanged except the
authorized `main.dart` license registration and new segmentation directory.

The descriptor is immutable and strict for this fixed model, including exact
labels, byte encoding, shapes/types, quantization, operators and integer fields.
The runner rejects SHA mismatch before native allocation, validates tensors,
transfers raw bytes, invokes public APIs, rejects signed output IDs outside0–31
before Uint16 conversion and returns an immutable detached snapshot. It closes
the interpreter on validation failure after acquisition and disposes its options
in `finally`; successful close is idempotent. Library-internal allocation failures
before `Interpreter.fromBuffer` returns are owned by the published package; no
private handle recovery/hacks were introduced.

## RED/GREEN evidence

Commands were run from `/Users/jamirulislam/Movies/dart_jpo/color_lab`.
`FLUTTER` below denotes the literal executable
`/Users/jamirulislam/Applications/flutter/bin/flutter`; `DART` denotes
`/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart`.

1. **Fresh revised-contract RED**, before the three owned production files:

   ```sh
   /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/segmentation/room_model_descriptor_test.dart --reporter expanded
   ```

   Exit1: missing `raw_segmentation.dart`, `room_model_descriptor.dart`,
   `room_model_runner.dart` and their APIs; `+0 -1: Some tests failed`.
   This is the plan's explicit missing-API RED, independent of historical RED.
   First implemented GREEN: exit0, `+22: All tests passed!`.

2. **Strict integer regression RED**:

   ```sh
   /Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/segmentation/room_model_descriptor_test.dart --plain-name 'rejects floating-point values in integer-only metadata' --reporter expanded
   ```

   Exit1: expected FormatException but returned a descriptor for numeric1.0.
   Fixed explicit integer validation for schemaVersion/classCount/ignoredLabel.

3. Added the malformed-output/absent-surface acceptance boundary check first,
   reran the full focused command in step1: exit1, missing
   `supportedSurfaceCounts`. Extracted the real verifier's boundary logic.
   Final focused GREEN (same step1 command): exit0, **24 tests passed**.

4. Wrapper preimplementation RED:

   ```sh
   /Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart run tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter
   ```

   Exit1: `Could not find file tool/run_room_model_smoke.dart` (also an SDK
   telemetry permission diagnostic on that un-escalated attempt). Authorized
   SDK/cache-aware runs used the tool's escalation mechanism thereafter.
   First implemented smoke: exit1 because package-config directory URI lacked a
   trailing slash. Investigated actual package config and fixed directory URI
   resolution. The next tester returned silent exit0 before asynchronous asset
   completion; that was **not accepted as native success**. The documented
   `--run-forever` lifetime flag produced actual inference. The final wrapper also
   rejects missing PASS output and imposes a60-second process timeout.

5. Final actual wrapper command in step4: **exit0**, parsed PASS, native runtime
   **2.11.0**, 262,144 actual IDs, all four supported surfaces; exact reference
   histogram match. Final staging is
   `/var/folders/vn/y_l64w1143dgf2j0sjxl8z8h0000gn/T/color-lab-room-smoke.SoCrkN`.
   See the [production validation report](room-model-production-validation-report.md)
   for tensor facts, counts, points, fixture recipe and failure evidence.

The TDD and systematic-debugging skills guided the fresh negative tests and
root-cause fixes. No scratch prototype runner was promoted. The verification
skill required observed command outcomes before this handoff.

## Final verification

| Command (using literal FLUTTER/DART paths above) | Actual result |
| --- | --- |
| `FLUTTER pub get` | exit0; exact runtime pin resolved, crypto promoted, quiver added |
| `FLUTTER test --no-pub test/features/room_studio/segmentation/room_model_descriptor_test.dart --reporter expanded` | exit0,24 passed |
| `FLUTTER test --no-pub --reporter expanded` | exit0,**593 passed**, no failures (569 baseline +24) |
| `FLUTTER analyze --no-pub lib/features/room_studio test/features/room_studio tool/verify_room_model.dart tool/run_room_model_smoke.dart lib/main.dart` | final exit0,No issues found |
| `DART format --output=none --set-exit-if-changed lib test tool` | exit0,152 files,0 changed |
| `DART run tool/run_room_model_smoke.dart --flutter-root /Users/jamirulislam/Applications/flutter` | exit0,actual production-runner PASS |
| same smoke + `--model /private/tmp/color-lab-task1.beKWbF/missing.tflite` | exit1,missing file |
| same smoke + `--native-library /private/tmp/color-lab-task1.beKWbF/missing.dylib` | exit1,missing library |
| same smoke + `--model assets/models/room_seg_descriptor.json` | exit1 propagated from actual verifier,production model SHA mismatch |

Initial analyzer found9 style diagnostics (multiline if braces and tool print).
They were corrected; the final analyzer is clean. The full suite ran once after
functional production integration; remaining edits were those style corrections
and strengthening the smoke's snapshot check with a different second input,
followed by final smoke/analyzer/format gates.

No native test was silently skipped. Descriptor/raw negative unit checks do not
count as AI evidence; native evidence comes only from the real staged runner.
The normal Flutter test suite does not attempt unsupported stock-SDK native
loading. The wrapper compiled kernel bytecode, not an APK or native library.

## Self-review and remaining concerns

Self-review checked exact scope, all descriptor fields/labels, preallocation hash,
public APIs, output range before truncation, resource ownership, immutable byte
views, wrapper failure propagation, asset staging, exact license, fixture RGB
and checksums. Baseline comparison shows no unrelated production-source edit.
All requested owned source/test/asset/tool paths are present.

The fixture's full input SHA remains
`b1853a64f7bf077e61e208f7c2756c21f8cf4f55f520bc0c59d0ffd668b7415a`.
Lossless PNG round-trip and four independent source/input corner RGB values
agree; first/last padding pixels agree. No PNG/source anchor difference was hidden.
Task2 must independently match the frozen input and prove ignored-only closing
using literal tests: this real model output contains **no class0** and Task1
does not perform closing. Task5 must separately exercise the default worker
factory, lifecycle and asset ownership; direct rootBundle+runner success here
does not complete that task. Mobile build/device execution remains unverified,
Android24/iOS13 unchanged. Person/furniture and other visible model errors remain.

Only the explicit Task1 gate is handed off for independent review. No Git init,
worktree, commit, native compilation, APK/install/clean/data-clear, SDK/pub-cache
patch or platform-floor increase was performed. Temporary host binaries are
outside the source workspace and are not delivery assets.
