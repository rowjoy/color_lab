# Plan 02 Task 2 — durable Room project storage

Date: 2026-10-27. Implementation branch: `TintAtlas`, in the user-authorized existing checkout.

Baseline verified before edits: `7fa2797ac4681dfe7a509e0f6eb1a5063c330eac`.

Protected `lib/main.dart` diff SHA-256 before work and at the completion gate:
`c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`.
That file was never edited, formatted, staged, or committed by this task.

## Implementation

- Added immutable `RoomProjectSnapshot`, `RoomColorVariant`, `RoomProjectSummary`, typed recovery/read results, typed CAS conflicts, and safe storage failures. A snapshot has project/photo IDs, name, independent storage/mask/color revisions, working dimensions/PNG, AI/current label bytes, named color variants, active and nullable comparison-baseline IDs, nullable thumbnail, and UTC creation/update times.
- Implemented the declared `RoomProjectRepository.listSnapshot/read/save/delete/close` API. `listSnapshot()` isolates corrupt projects and sorts healthy summaries by descending updated time, then ID. There is no alternate `list()` API.
- Reused the existing `SchemaRegistry.roomProjects` descriptor and `LocalDataCategory.roomProjects`; neither was duplicated. The descriptor remains file-tree version 1, shared-library scope, storage name `room_projects`.
- Added a strict schema-v1 codec. Unknown versions/fields, non-integer schema versions, unsafe IDs/paths, non-canonical timestamps/HEX, invalid variant references, duplicate variant IDs/names, invalid labels, and mismatched mask lengths fail closed. Manifest/asset/pointer sizes, dimensions, pixel counts, variant counts, and revisions are bounded before unsafe reads/allocations. PNG headers/chunks are checked before pixel decoding; source EXIF/GPS/text and APNG are excluded. The pinned `image` 4.12 decoder was inspected locally: it checks PNG checksums and inflates rows lazily.
- Added `FileRoomProjectRepository`, the production filesystem mutation boundary `RoomProjectFileIo`, and a serialized queue shared by repository handles for the same canonical root in the app isolate. Accepted operations drain before close; new operations after close fail. Saves, deletes, reads, and maintenance leases all use the owner queue. Escaped maintenance leases expire.
- Added the in-memory repository and reusable prepared-PNG/project fixtures in test support for dependent session/controller tests.
- Wired the actual Room file owner into Settings, with a minimal repository/library provider file that Task 3 can extend. Targeted refresh invalidates only Room library values and retains the repository owner. No Task 3 session/editor UI was added.
- Activated the Room-project data category. `LocalDataManifest` separates record count from fingerprint entry count and records revision count. Settings counts projects with current pointers (including corrupt pointers) as records, while aggregate bytes and revision counts are storage detail. Added localized revision-detail copy and generated it with the existing `gen-l10n` workflow. Other categories retain their previous default record semantics.
- Updated `docs/release/schema-registry.md` with the frozen v1 format, layout, bounds, ownership, cleanup, CAS, recovery, and compatibility rules.

## File layout and commit boundary

```text
<private color_lab root>/room_projects/projects/<projectId>/
  assets/<sha256>.png
  assets/<sha256>.mask
  revisions/<revision>/manifest.json
  current
  quarantine/<diagnostic-key>.json
```

Prepared photos, masks, and thumbnails are immutable content-addressed assets owned by their project. Metadata-only saves reuse those references; they do not duplicate photo/mask files. Each immutable manifest records exact relative paths, lengths, and SHA-256 values.

New assets and the manifest are written and flushed in a `.stage-<revision>-<nonce>` sibling. Assets are published under immutable names, the completed revision directory is renamed into place, and a flushed `.current-<nonce>` atomically replaces `current`. Only that final pointer replacement acknowledges the revision. A first save requires `expectedRevision: 0` and returns revision 1; later saves require the latest acknowledged revision. A stale CAS token returns `RoomProjectConflict` without rebase.

The checksummed pointer holds contiguous acknowledged ancestry and each manifest checksum. Recovery walks only that ancestry, never arbitrary revision directories. A newer valid orphan is never a fallback. `RoomProjectReadResult.acknowledgedRevision` remains the CAS token even when `snapshot.revision` is an earlier recovered state. Recovery exposes a typed warning and writes non-sensitive quarantine reason/revision/hash metadata best-effort while preserving corrupt originals. A damaged thumbnail yields usable core data and a null thumbnail/warning.

Reopen/save cleanup removes recognized staging, temporary-pointer and unacknowledged revision artifacts. Asset collection occurs only when all acknowledged manifests are valid; otherwise assets remain. Every owned path component is checked without following symlinks, and canonical private-parent ancestors are rechecked after open. Inventory includes directories, pointers, revisions, staging/orphans, quarantine, and link identities. Deletion removes owned links themselves, never their targets or external exports. Partial failures consume deletion authorization and remain retryable after a fresh preview.

## RED evidence and diagnostic corrections

The domain, codec, and repository tests were written before production implementation. Initial command:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain/room_project_test.dart test/features/room_studio/data/room_project_codec_test.dart test/data/files/file_room_project_repository_test.dart --reporter expanded
```

The first attempt was blocked before compilation by the workspace sandbox: `update_engine_version.sh: line 64: .../bin/cache/engine.stamp: Operation not permitted`. The unchanged verification command was rerun with approved tool escalation. It exited 1 at `+0 -3`, because `room_project.dart`, `room_project_codec.dart`, and `file_room_project_repository.dart` and their types did not exist. Evidence: `/tmp/tintatlas-task2-red.log`.

Additional RED evidence:

- Settings integration tests ran before owner/provider/copy wiring. The new provider file/types were absent and revision-detail copy was missing. Existing disabled-Room category assertions were updated to the still-disabled Coloring category when Room projects became available. Log: `/tmp/tintatlas-task2-settings-red.log`.
- The codec's non-integer schema case exposed Dart's `1.0 == 1` equality: the boundary suite exited 1 at `+29 -1`. The analogous pointer test exited 1 at `+0 -1`. Both now explicitly require integer schema versions. Logs: `/tmp/tintatlas-task2-boundary-red.log`, `/tmp/tintatlas-task2-pointer-red.log`.
- A final filesystem review added a test replacing the canonical private parent with a symlink after opening. It failed at `+0 -1`, proving that checking only the owned root missed redirected parents. Ancestor rechecks fixed it; the targeted GREEN run passed `+1`. Logs: `/tmp/tintatlas-task2-parent-red.log`, `/tmp/tintatlas-task2-parent-green.log`.

Intermediate failures were diagnosed rather than counted as passing verification:

- The first implementation run passed the 9 domain/codec cases but could not compile the repository because `..owners++` is invalid Dart cascade syntax. It was replaced by a separate increment.
- Two delete-injection tests initially missed their intended fault because macOS temporary paths used `/var` while the owner correctly canonicalized to `/private/var`. Canonicalizing the fixture root made the fault injection hit the real delete operation.
- An attempted combined real-I/O/widget provider test stalled across Flutter fake-clock boundaries. Boundary tracing located the waits. Coverage was retained as a real disk-backed provider/owner integration test and a widget test for targeted refresh/owner retention. A further trace proved all widget assertions completed but teardown awaited the fake-zone queue after its active zone ended; the test now drains and awaits close inside its test body. These interrupted diagnostic runs were not counted as successful focused runs, and no hanging runner was left behind. Final targeted provider verification passed `+2` (`/tmp/tintatlas-task2-providers-green.log`).
- The first analyzer run reported 59 style infos, primarily braces around wrapped `if` statements. All were corrected. One formatter attempt completed formatting only explicit Task 2 files, then failed when SDK telemetry tried to update `/Users/jamirulislam/.dart-tool/dart-flutter-telemetry-session.json` outside the sandbox. The required explicit-path format/check commands were rerun with approved escalation.

## Final verification

Both final focused runs used this unchanged command:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub test/features/room_studio/domain/room_project_test.dart test/features/room_studio/data/room_project_codec_test.dart test/data/files/file_room_project_repository_test.dart test/data/storage/local_data_manager_test.dart test/features/settings/application/local_data_providers_test.dart test/features/settings/data_management_screen_test.dart --reporter expanded
```

- Run A: exit 0, `+54: All tests passed!` — `/tmp/tintatlas-task2-focused-final-a.log`.
- Run B: exit 0, `+54: All tests passed!` — `/tmp/tintatlas-task2-focused-final-b.log`.

Those runs include first save, concurrent CAS (including two owners), metadata asset reuse, reopened byte-identical photo/AI/current-mask/thumbnail reload, partial manifest and revision/pointer publication interruption, post-pointer acknowledgement, interrupted first save, orphan rejection, older acknowledged asset retention, fallback/quarantine, pointer corruption, corrupt-project isolation, corrupt-thumbnail fallback, ID/path/symlink and size boundaries, retryable delete failures, delete queued behind save, close during pending save, maintenance exclusion/lease expiry, exact inventory/deletion, Settings owner/refresh, and localized revision detail.

The full Flutter suite was run once at the final gate:

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter test --no-pub --reporter expanded
```

Result: exit 0, `01:07 +1757: All tests passed!`. No test failures or uncaught test exceptions were reported. Log: `/tmp/tintatlas-task2-full-suite.log`.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter analyze --no-pub
```

Result: exit 0, `No issues found! (ran in 5.1s)`. Log: `/tmp/tintatlas-task2-analyze-final.log`.

```sh
/Users/jamirulislam/Applications/flutter/bin/flutter gen-l10n
```

Result: exit 0; existing `l10n.yaml` used. No dependency changes.

Final formatter check, limited to explicit Task 2 Dart paths:

```sh
/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed lib/data/files/file_room_project_repository.dart lib/data/storage/local_data_manager.dart lib/features/room_studio/domain/room_project.dart lib/features/room_studio/domain/room_project_repository.dart lib/features/room_studio/data/room_project_codec.dart lib/features/room_studio/application/room_projects_providers.dart lib/features/settings/application/local_data_providers.dart lib/features/settings/presentation/data_management_screen.dart lib/l10n/generated/app_localizations.dart lib/l10n/generated/app_localizations_en.dart test/support/room_project_fixtures.dart test/support/in_memory_room_project_repository.dart test/features/room_studio/domain/room_project_test.dart test/features/room_studio/data/room_project_codec_test.dart test/data/files/file_room_project_repository_test.dart test/data/storage/local_data_manager_test.dart test/features/settings/data_management_screen_test.dart test/features/settings/application/local_data_providers_test.dart
```

Result: exit 0, `Formatted 18 files (0 changed)`.

`git diff --check` passed. The commit gate also checks the staged diff and confirms `git diff --cached -- lib/main.dart` is empty and the protected unstaged hash is unchanged. Only the 20 implementation/documentation/test paths described above and this report are included. The report is deliberately force-added because `.superpowers` is ignored; no other ignored ledger/brief file is staged.

## Limits and dependent work

- Recovery guarantees process interruption under atomic same-filesystem renames. Device power-loss durability is not claimed; no directory fsync/platform persistence barrier was added.
- The serialization boundary covers handles in the same app isolate. The private tree is not a multi-process/multi-isolate database and does not implement native `openat` protection against hostile concurrent filesystem swaps.
- V1 retains acknowledged history rather than silently pruning it, with a typed limit after 10,000 revisions. Variant, dimension, asset, manifest, pointer, and inventory bounds are documented in the schema registry. Metadata-only saves avoid disk asset duplication; mask changes can legitimately add retained content assets.
- A wholly corrupt pointer cannot establish acknowledged ancestry, so reads fail closed and preserve the revision evidence. Quarantine writes are best-effort when storage is full/unavailable.
- Failure injection exercises real temporary files at the write/rename/delete boundary. Native device power-loss and platform lifecycle/device gates were not claimed by these tests. No Android/iOS build was required or run for this storage-only task.
- Schema v1 is frozen. Explicit manual correction intent/history remains Plan 03/schema v2. ROOM-03 is not claimed complete. Session/autosave and library/editor UI remain Tasks 3–5; only their required storage/provider contracts were established here.

## Commit record

Required commit message: `feat: add durable room project storage`.

This report is included in the Task 2 implementation commit. Its final commit identity is the creation commit of this report, resolvable without a self-referential hash:

```sh
git log --diff-filter=A -1 --format=%H -- .superpowers/sdd/2026-10-27-tintatlas-real-room-projects/task-2-report.md
```

The exact resulting SHA is also returned in the final implementer handoff. No push, publication, or merge is performed.
