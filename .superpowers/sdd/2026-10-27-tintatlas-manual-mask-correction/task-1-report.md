# Plan 03 Task 1 evidence — 2026-10-28

Base `3f7f2d9f5edf1c9dd411569033b7c4cfa7141847`, branch `TintAtlas`. Task 1 only; no edit-command/history implementation.

## Change and compatibility

- Added bounded immutable `MaskIntentBitmap`: untouched/fromBytes factories, copied unmodifiable bytes (including buffer views), validated immutable ascending/unique apply, and aligned AI merge. Values 1–5 always win, including choices equal to the former AI labels.
- Snapshot schema is 2. New construction without intent deliberately initializes zero intent; `copyWith` preserves intent and rejects dimension mismatch. The one-pixel test fixture now passes aligned intent explicitly. Existing aggregate and schema-descriptor version expectations were updated.
- Codec accepts only strict known manifests 1/2 and writes only 2. V1 migration is read-only and always all-zero intent; no inference from AI/current differences. V2 requires a pixel-length, SHA-256-verified content-addressed `assets/<digest>.intent.bin`, with strict path/fields/value validation.
- Kept pointer schema 1 and acknowledged CAS/ancestry behavior. Recovery covers v2→v2 and v2→frozen-v1, invalid-value intent with valid storage hashes, missing/hash-corrupt intent, healthy-project isolation, ignored newer v2 orphan, quarantine metadata, and next v2 save with the acknowledged token. Cleanup now recognizes unreferenced `.intent.bin` files.
- Frozen v1 photo/mask/thumbnail references and visible bytes, IDs, variants/colors/baseline, revisions and UTC timestamps remain exact through decode/rewrite/reopen. Storage name `room_projects`, private `color_lab` root, shared-library owner, external/source exports and deletion boundaries remain unchanged.
- Existing immutable-asset policy remains: an already corrupt shared content address is not overwritten to repair a save. Process-interruption recovery remains the guarantee; directory-fsync/power-loss durability, cross-isolate ownership and rollback to a v1-only writer are not claimed. Controller refresh/strokes and Undo/Redo are later tasks.

## TDD commands and exact results

Executable `F=/Users/jamirulislam/Applications/flutter/bin/flutter`; bundled Dart `D=/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart`.

Focused command (RED and implementation verification):

```sh
$F test --no-pub test/features/room_studio/domain/mask_intent_bitmap_test.dart test/features/room_studio/data/room_project_codec_test.dart test/data/files/file_room_project_repository_test.dart --reporter expanded
```

- Initial sandbox startup failed before tests because Flutter could not write SDK `cache/engine.stamp`; the authorized escalated launch completed RED, exit 1, **+53 / -9**. These were real schema/required-intent assertions and a rejected v2 API path, without compiler errors. The initial domain test used the existing snapshot entry point; direct bitmap factory/apply/merge edge cases were added before production implementation once the new API could be imported.
- Implementation verification completed exit 1, **+67 / -1**. The single failure was test-fixture construction: an inferred `Map<String,Object>` rejected a null invalid-hash test value before codec execution. Corrected only that fixture literal to `Map<String,dynamic>`.
- Reran only the failed named test, exit 0, **+1 / -0**; no passing suite rerun:

```sh
$F test --no-pub test/features/room_studio/data/room_project_codec_test.dart --plain-name 'v2 intent is required and strictly validates reference and core bytes' --reporter expanded
```

Thus 68 focused tests have passing evidence, with the failed verification attempt and narrowly corrected test disclosed rather than claiming one uninterrupted green run.

Additional required aggregate/descriptor assertions (not executed by the three-file suite), exit 0, **+3 / -0**:

```sh
$F test --no-pub test/features/room_studio/domain/room_project_test.dart test/data/schema/schema_registry_test.dart --name 'snapshots detach bytes and variants and preserve render identities|descriptor identities pin storage backend version and ownership|file and cache storage are never mislabeled as Hive boxes' --reporter expanded
```

No full suite, Android/iOS build, dependencies/native configuration, ads/signing, push, publish or merge. Full-suite/native verification remains deferred until approved Plan 08 completion.

## Analyzer, format and hashes

Changed eligible Dart paths (the same 11 paths were passed explicitly to the successful bundled-Dart format check):

```text
lib/features/room_studio/domain/mask_intent_bitmap.dart
lib/features/room_studio/domain/room_project.dart
lib/features/room_studio/data/room_project_codec.dart
lib/data/files/file_room_project_repository.dart
lib/data/schema/schema_registry.dart
test/features/room_studio/domain/mask_intent_bitmap_test.dart
test/features/room_studio/data/room_project_codec_test.dart
test/data/files/file_room_project_repository_test.dart
test/support/room_project_fixtures.dart
test/features/room_studio/domain/room_project_test.dart
test/data/schema/schema_registry_test.dart
```

- `$F analyze --no-pub` with the first nine explicit paths: exit 0, no issues (1.5 s). The two additional existing expectation paths: exit 0, no issues (1.4 s). Corrected codec-test path alone was analyzed after its fixture fix.
- Initial `$D format` formatted 9 paths / changed 6, then exited 1 because sandbox telemetry modification was denied. Successful escalated `$D format --output=none --set-exit-if-changed` on all 11 paths: exit 0, 0 changes; corrected codec test rechecked alone: exit 0, 0 changes.
- `git diff --check`: clean.
- Frozen inventory SHA-256 `365055822f7b29fbff9b09afdd242c8bd597f0ff9a0980b99d559e11fbca1013`; all **13 files / 5,801 bytes** independently rechecked against inventory lengths/digests. No source fixture changed; tests consume exact static bytes, never regenerate v1 with the encoder.
- Protected `git diff -- lib/main.dart` SHA-256 remains `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`; file SHA-256 remains `11c14bf82927540b14857b8da7a948708062b9bbb093857c7d418f7e3fb278d5`. It was never edited, formatted, staged or committed.

Evidence logs in `/private/tmp/`:

| Log | SHA-256 |
| --- | --- |
| `plan03-task1-red.log` | `760c4cba2c6cc587e0c9e11330e81140178eb1cbbad49f9228c0eebfb93b1eda` |
| `plan03-task1-green.log` | `8e7639574dd15fea66555ced59268c7cc24f27605263d61a520b66fc506e1df6` |
| `plan03-task1-green-correction.log` | `53a61d4d17440ab15b026dc5ff3709fa439d0cebb29401c0e6af1ed80c886cdc` |
| `plan03-task1-green-compatibility.log` | `d8079407552b15fb4046cb7cad1d4053c6540c9c8b087de33dad16f1825353cf` |

## Explicit commit inventory

The 11 Dart paths above, `docs/release/schema-registry.md`, and this report only. Frozen fixtures and `lib/main.dart` excluded. Commit message: `feat: persist explicit room mask intent`. Expected postcommit status: only protected ` M lib/main.dart`.
