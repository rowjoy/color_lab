# Task 3 report: durable shared photo acquisition

Status: DONE_WITH_CONCERNS. Task 3 focused gates pass; the full suite remains red at the explicitly assigned Task 4 fake migration boundary. No commits (noGit).

## Implemented scope and APIs

Created:

- `lib/features/picker/domain/photo_acquisition.dart`: immutable intent/record/receipt/state, source and destination enums, schema-1 map serialization and validation, sealed acquisition outcomes and safe failure categories.
- `lib/features/picker/domain/acquisition_intent_store.dart`: load/save/clear/close interface and safe storage exception.
- `lib/data/db/hive_acquisition_intent_store.dart`: isolated Hive registry, `photo_acquisition_v1` / `pending`, serialized operations, explicit flush barrier, retryable close, unknown-record preservation.
- `lib/features/picker/application/acquisition_intent_providers.dart`: final-directory provider, injectable factory, retained store with disposal ownership; no automatic retry.
- `lib/features/picker/application/photo_acquisition_controller.dart`: retained `photoAcquisitionProvider`, lazy initialization, coalesced recovery, shared gate, intent persistence before native invocation, claim/dismiss/discard/retryStorage.
- `test/support/in_memory_acquisition_intent_store.dart`: UI-test repository override with the same validation/disposition contract.
- `test/features/picker/application/photo_acquisition_controller_test.dart`.
- `test/data/db/hive_acquisition_intent_store_test.dart`.

Modified:

- `lib/features/picker/application/photo_picker_service.dart`: `pick({PhotoSource source = PhotoSource.gallery})` on interface and plugin implementation, bounded camera/gallery selection.
- `test/features/picker/photo_view/photo_picker_service_test.dart`: camera options and real processing coverage; existing gallery/cancel/error/byte/recovery cases preserved.

`PhotoSource` is declared in `domain/photo_acquisition.dart`; consumers/fakes need that import. The signature was announced to the controller immediately before production editing. The four existing screen-test fake signatures were intentionally not changed.

The coordinator is initially uninitialized and does not read a storage or native provider during creation. Call `ensureRecovered()` only when onboarding allows recovery. A new request may initialize recovery if it has not yet run. Requests while another operation, receipt or untrusted record is pending return busy. Known destinations require a matching ID and destination to claim; unknown origins retain nullable source/destination and require an explicit claim destination. A successful receipt survives a failed durable clear. `retryStorage()` restores durability/readiness but never delivers a photo or automatically invokes the picker; claim/dismiss remains explicit. `discardUntrustedIntent()` requires untrusted metadata and no pending photo; UI confirmation belongs to Task 4.

## TDD and focused evidence

Tests were written before production files or the adapter change. The exact required RED command was:

```sh
flutter test --no-pub test/features/picker/application/photo_acquisition_controller_test.dart test/data/db/hive_acquisition_intent_store_test.dart test/features/picker/photo_view/photo_picker_service_test.dart --reporter expanded
```

The first sandboxed attempt exited 1 before test loading because Flutter could not update its external `engine.stamp`. The approved escalated execution of the same command then exited 1 with `+0 -3: Some tests failed.` This was a compilation RED, not an assertion RED: the new production API files and test support did not yet exist, and the adapter lacked the `source` named parameter. Those were the expected missing-feature failures. No production code preceded this observed RED.

First GREEN of the same exact command after implementation: exit 0, `+23: All tests passed!`. Added three supplemental integration/lifecycle cases covering existing implemented contracts, then ran the same command: exit 0, `+26: All tests passed!`. Final focused verification after lint cleanup again used the exact command above: exit 0, 26 passed, output pristine.

The 26 tests comprise 13 coordinator/provider tests, 7 real-Hive storage/integration tests, and 6 adapter tests.

Durability and race evidence:

- Delayed lost-data recovery coalesces to one native retrieval and blocks a new picker while retaining the old Room destination.
- Delayed save/flush admits zero picker calls; concurrent requests admit one; the gate remains held through native processing and receipt claim clearing.
- Failed save admits no picker invocation; storage retry never launches camera.
- Wrong request ID/destination consumes nothing; pending successful receipt cannot be replaced by another request.
- Missing/untrusted recovered metadata never becomes Capture by default; explicit Room claim succeeds and durably clears it.
- Untrusted metadata with no recoverable photo remains preserved and blocks acquisition until explicit discard.
- Cancellation/error clear only their request intent and expose safe failure categories.
- Recovery cleanup failure and native recovery processing failure retry without a second lost-data retrieval.
- Real Hive files preserve saved intent and deletion across close/reopen. Malformed/null/unknown schema/destination/missing fields survive reopen until explicit discard. Unknown records reject ordinary save/clear.
- Failed write and delete flushes block reads and saves behind the store retry barrier; close waits for queued work and supports flush/close failure retry.
- The coordinator + real Hive integration test observes zero native calls before flush, then a failed delete flush after Hive memory has already removed `pending`. The prepared receipt remains pending through continued storage failure, then a successful retry and explicit claim resolve it. The test closes the store, reopens the actual file, and verifies that no pending record remains (`IntentRecordKind.absent`).
- Separate directories with equal box names remain isolated.
- Disposal during directory resolution skips the factory; disposal during factory opening closes the late store. Disposal during load prevents native recovery; disposal during save prevents picker launch; disposal during native processing rejects the late result and preserves the durable intent.

## Analyzer and formatting

Final scoped analyzer command:

```sh
dart analyze lib/features/picker/domain/photo_acquisition.dart lib/features/picker/domain/acquisition_intent_store.dart lib/data/db/hive_acquisition_intent_store.dart lib/features/picker/application/acquisition_intent_providers.dart lib/features/picker/application/photo_acquisition_controller.dart lib/features/picker/application/photo_picker_service.dart test/support/in_memory_acquisition_intent_store.dart test/features/picker/application/photo_acquisition_controller_test.dart test/data/db/hive_acquisition_intent_store_test.dart test/features/picker/photo_view/photo_picker_service_test.dart
```

Exit 0: `No issues found!`. Earlier intermediate runs exposed an unused import, an incorrect override annotation and brace style issues; all were corrected before final verification.

Final format gate:

```sh
dart format --output=none --set-exit-if-changed lib/features/picker/domain/photo_acquisition.dart lib/features/picker/domain/acquisition_intent_store.dart lib/data/db/hive_acquisition_intent_store.dart lib/features/picker/application/acquisition_intent_providers.dart lib/features/picker/application/photo_acquisition_controller.dart lib/features/picker/application/photo_picker_service.dart test/support/in_memory_acquisition_intent_store.dart test/features/picker/application/photo_acquisition_controller_test.dart test/data/db/hive_acquisition_intent_store_test.dart test/features/picker/photo_view/photo_picker_service_test.dart
```

Exit 0: `Formatted 10 files (0 changed)`.

## Full suite: observed interim failure

Ran exactly once:

```sh
flutter test --no-pub --reporter expanded > /private/tmp/color-lab-task3-full-suite.log 2>&1
```

Exit 1, final output `00:35 +567 -6: Some tests failed.` The log is retained at `/private/tmp/color-lab-task3-full-suite.log`. This is not a green full-suite result.

Four root signature mismatches, all owned by Task 4:

- `test/features/settings/onboarding_settings_integration_test.dart:27`: `_NoPromptPhotoPicker.pick` lacks the optional named source parameter.
- `test/features/settings/settings_modal_contrast_test.dart:20`: `_QuietPhotoPicker.pick` lacks it.
- `test/features/picker/capture_integration_test.dart:24`: `EntryPhotoService.pick` lacks it.
- `test/features/picker/camera_screen_test.dart:82`: `FakePhotoPicker.pick` lacks it.

Two additional file-load failures are transitive imports of that same camera fake:

- `test/features/formula/presentation/formula_integration_test.dart`.
- `test/features/harmonies/presentation/harmonies_integration_test.dart`.

No other test failure was observed. No sibling test file was edited or stubbed. The full run occurred before final brace-only cleanup; final focused tests, analyzer, and format ran on the final source.

## Self-review and limits

Reviewed all new production files and diffs against `/private/tmp/color-lab-task3-base.lK18nm/source`. The changed lib/test paths match the Task 3 allowlist. Controller is roughly 290 lines and keeps one acquisition state machine; no unplanned file splitting or UI/worker changes. Removed an unnecessary retained reference to recovered pixels once the pending receipt owns them. Verified that every asynchronous continuation checks disposal before starting native work or publishing/returning a successful result, and persistence gates picker invocation and receipt handoff.

The final directory provider appends `color_lab` once; Hive factory receives that final path unchanged. The existing isolated-registry Hive implementation-import convention is reused. Only the new acquisition box is touched. Adapter retains 2048×2048/no-full-metadata requests and 24 MiB acquisition bounds. Task 2 processing remains unchanged: 32 MiB processing, 24M decoded pixels/16384 axis, working long edge 1600, orientation/aspect/alpha-on-white. Android24/iOS13 files are unchanged. No SDK/pub-cache patches, private native API hacks, APK/native build/install/clean, data clear, Git operation, or archive manipulation was performed. Old APK and nine ZIPs were untouched.

Known limits: native picker behavior is exercised through the public adapter seam, not a device build. This task persists acquisition metadata, not prepared photo bytes across a subsequent process death. Screen migration, onboarding-triggered recovery, and explicit confirmation UI remain Task 4. The six reported file-load failures must be resolved there before claiming global green. No further Task 3 correctness issue is known after self-review; independent review remains with the controller.
