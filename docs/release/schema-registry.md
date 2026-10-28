# TintAtlas compatibility and schema registry

**Recorded:** 2026-10-27

**Applies from:** pre-Plan-01 product baseline `b4043bc`

**Rule:** names and formats in this registry are compatibility contracts; change them only through a versioned migration with old-format fixtures.

## Storage ownership

Durable data uses Hive and the Room project file tree beneath the application-documents `color_lab` directory. No SharedPreferences-backed product state was found.

| Schema / box | Root identity | Current version and record | Owner / deletion boundary |
| --- | --- | --- | --- |
| `app_preferences_v1` | key `preferences` | `schemaVersion: 2`; `themeMode`, `onboardingCompleted`, `motion`, `highContrast`, `alwaysShowColorLabels`. Version 1 reads use safe accessibility defaults; the next edit writes v2. | Installation-local settings. Explicit reset returns to onboarding; unsupported schemas remain untouched. Never deletes projects, colors, palettes, or games. |
| `color_history_v1` | one record per canonical HEX key | `version: 1`; `id`, `hex`, `name`, `isFavorite`, `createdAt`, `source` | Shared My Work color library. A game-profile deletion must not touch it. |
| `color_palettes_v1` | `${mode.name}-${HEX-without-#}` | `version: 1`; `id`, `name`, `base`, `mode`, `colors`, `createdAt` | Shared My Work palette library. Consumers copy color snapshots rather than retaining fragile foreign keys. |
| `illustrated_room_designs_v1` | design ID; reserved `@draft:<templateId>` for one recoverable draft per template | `version: 2`; design `id`, `name`, `templateId`, `templateRevision`, `groupColors`, `regionOverrides`, nullable `activeBaseline`, `createdAt`, `updatedAt` | Shared My Work illustrated designs and isolated local drafts. V1 maps exact four colors to groups with no overrides or palette link; healthy rows rewrite only after flush. |
| `photo_acquisition_v1` | key `pending` | `schemaVersion: 1`; `requestId`, `source`, `destination` | Transient recoverable acquisition intent. Clearing it must not delete a selected source photo owned elsewhere. |
| `game_profiles_v2` | key `state` | root `schemaVersion: 2`; `activeProfileId`, `profiles`, `pendingLegacySnapshot`, `legacyMigrationComplete`; nested game/profile records remain v1 | Games-only profiles/progress/rewards/preferences. Profile deletion must not delete or hide shared My Work. |
| `game_progress_v1` | key `progress` | legacy aggregate schema v1 | Read as the migration source for `game_profiles_v2`; retain until migration/rollback evidence explicitly retires it. |
| `room_projects` (`room-projects`) | `projects/<projectId>/current` | file-tree schema v2 (strict v1 read migration); project/photo IDs, name, storage revision, prepared PNG/dimensions, AI/current masks, explicit intent, mask/color revisions, named color variants, active and nullable comparison-baseline IDs, thumbnail, UTC timestamps | Installation-local shared Room library. Its serialized `LocalDataOwner` owns this tree only; external exports and game data are excluded. |
| `learning_library_v1` (`learning-library`) | `@library`; `progress:<lessonId>`; `practice:<attemptId>`; `experiment:<experimentId>` | strict schema v1 rows for topics-to-revisit, lesson progress/answer history, practice explanations, and typed experiment records | Installation-local shared Color Learning library. Learning reset/delete cannot touch colors, palettes, rooms, or game profiles; games cannot own or delete learning records. |

Immutable serialization details include root keys, enum storage strings, stable `GameId` values, UTC timestamp encoding, uppercase canonical `#RRGGBB`, and nested record versions. Corrupt-record handling must isolate the bad record and retain recoverable bytes; it must not reset an entire healthy box silently.

### Illustrated designs and recoverable drafts v2

The box name stays `illustrated_room_designs_v1`. Group keys are exactly `walls`,
`ceiling`, `floor`, `furniture`; region keys are stable lowercase hyphenated IDs.
Snapshots contain only immutable canonical uppercase HEX copies, never a palette
ID or inferred catalogue link. `activeBaseline` is the pinned comparison
snapshot (nullable), independent of current assignments. Template revision is a
positive integer; the current editor accepts revision 1 and validates group and
region membership at materialization. Storage decoding preserves unknown
future templates and regions without requiring the live catalogue.

A draft row contains exactly `version: 2`, `templateId`, `templateRevision`,
nullable `visible`, `activeBaseline`, `savedSnapshot`, `savedDesignId`,
`savedName`, and canonical UTC `updatedAt`. `visible` is null for grayscale;
`savedSnapshot` and the paired saved identity retain the discard/dirty baseline.
Each nested snapshot has exactly `groupColors` and `regionOverrides`. Undo
history and temporary B&W remain session-only. Draft rows are excluded from
the saved library and have independent corrupt-record warnings. Corrupt draft
bytes are never overwritten by retain or Retry.

V1 migration preserves IDs, names, template IDs, UTC timestamps and the exact
four colors for all six frozen fixtures. It introduces revision 1, empty
region overrides and null comparison baseline. A corrupt row is retained while
healthy rows migrate. Unknown versions/fields/types are rejected without reset.
An older v1 reader cannot consume v2; downgrade rewriting is unsupported.

Writes serialize through the owning repository and publish only after flush.
Hive changes its cache before flush, so a failed write restores the previous
payloads and retains a blocked barrier. Reads and later mutations cannot turn
that failed attempt into success. Explicit Retry finishes rollback and allows
the caller to reapply its visible failed draft. Close finishes rollback before
closing; fresh handles reopen the previous acknowledged state. If rollback
itself cannot flush, Retry/close fails and the handle remains open. Once the
box close begins, a close error is terminal for that repository handle: Retry
must fail, and the owner must replace/reopen the repository (provider owners
invalidate `roomDesignRepositoryProvider` before loading a fresh instance). This is a
flush/close-reopen contract, not an atomic device-power-loss guarantee during a
failed write and rollback. The draft store exposes `saved`, `saving`, `failed`
and retains both the visible attempt and last acknowledged draft.

### Learning library v1

`learning_library_v1` stores independent strict rows so one corrupt progress,
practice, or experiment record is reported without hiding healthy learning
data. All experiment colors are canonical uppercase `#RRGGBB` value copies;
timestamps are canonical UTC; tool payloads are versioned and typed for Lab,
Mixer, Harmonies, Formula, and Matching. Unknown versions are retained and
reported rather than coerced. Serialized writes flush before success and
restore the last acknowledged rows after a failed write. Data-management
preview/delete is limited to this box and refreshes only Learning state.

### Future schema ownership reserved by the approved design

Coloring projects and the unified My Work index do not yet have persisted
launch schemas. Their implementations must choose independent versioned names,
add old/current/future fixtures, and update this registry before writing
production data. `game_profiles_v2` must never become the owner of those shared
records.

### Room project schema v2 and frozen v1 reads

`SchemaRegistry.roomProjects` reuses the reserved `fileTree` / `sharedLibrary` descriptor, version `2`, storage name `room_projects`. The layout is:

```text
color_lab/room_projects/projects/<projectId>/
  assets/<lowercase-sha256>.png
  assets/<lowercase-sha256>.mask
  assets/<lowercase-sha256>.intent.bin
  assets/<lowercase-sha256>.history.bin
  revisions/<positive-storage-revision>/manifest.json
  current
  quarantine/<diagnostic-key>.json
```

Assets are immutable and project-owned. A metadata/variant-only revision reuses the exact photo/mask references, including the SHA-256 and length; a different project gets independent ownership. Masks store one discrete label byte per working pixel, `0` (unowned) through `4`, with the existing Room coordinate system. Schema v2 additionally requires one intent byte per working pixel: `0` untouched, `1` explicitly unowned, and `2..5` explicit owner for `RoomLayer.values[0..3]`. Intent is immutable, aligned, and independent of AI/current equality. Refreshed AI can control only intent `0`; every explicit choice wins. Prepared photos and thumbnails are RGB/RGBA 8-bit PNG pixels with only `IHDR`, `IDAT`, `IEND` chunks; source EXIF/GPS/text and APNG are excluded. Every permitted chunk's CRC is verified, including `IEND`. IHDR compression and filter methods must be `0`; interlace may be `0` (none) or `1` (Adam7), as defined by the [PNG header specification](https://www.w3.org/TR/png-3/#11IHDR). Both supported interlace forms are tested through Flutter's image codec. Export still has an independent platform-handoff verification boundary.

The manifest contains exactly `schemaVersion`, `projectId`, `photoId`, `name`, `revision`, `width`, `height`, `maskRevision`, `colorRevision`, `activeVariantId`, `comparisonBaselineVariantId`, `variants`, `createdAt`, `updatedAt`, and `assets`. Each variant contains exactly `id`, `name`, `colors`; colors contain nullable canonical `#RRGGBB` values for wall/ceiling/floor/furniture. New v2 `assets` contains `photo`, `aiMask`, `mask`, required `intent` and `history`, and nullable `thumbnail`; every reference has exactly `path`, `length`, and lowercase `sha256`. Photo/thumbnail paths are exactly `assets/<sha256>.png`, ownership paths `assets/<sha256>.mask`, intent paths `assets/<sha256>.intent.bin`, and edit-history paths `assets/<sha256>.history.bin`. Intent length equals the pixel count; digest and values 0–5 are verified as core data. Missing, malformed, unexpected-field, wrong-path, wrong-length, wrong-hash or invalid-value intent rejects the revision. A missing/corrupt thumbnail yields a typed warning and a null thumbnail while preserving otherwise valid core data.

IDs match `[A-Za-z0-9][A-Za-z0-9_-]{0,79}`. Names are trimmed, nonempty, at most 80 UTF-16 code units, with no control characters; variant names are case-insensitively unique. There are 1–32 variants. Dimensions are positive integers up to 4096 each / 16,777,216 pixels; thumbnail dimensions are at most 1024 each. Masks must match the pixel count exactly. Every asset is at most 64 MiB, each manifest at most 256 KiB, and each pointer at most 2 MiB. Integer revisions are in `0..2147483647`, with persisted storage revisions starting at `1`; a project retains at most 10,000 acknowledged revisions, then returns a typed limit error. The owner does not silently prune acknowledged revisions. Dates use canonical UTC `toIso8601String()` encoding and updated time cannot precede creation.

`current` retains pointer schema `1`, independently of manifest schema `1` or `2`, and contains `schemaVersion`, `projectId`, descending `ancestry` (`revision`, `manifestSha256`), and a SHA-256 `checksum` over the canonical JSON payload excluding `checksum`. The ancestry is contiguous back to revision 1. First save requires CAS `expectedRevision: 0`; subsequent saves require the current acknowledged revision. A conflict never rebases. Recovery walks only this checksummed ancestry, checking manifest and asset hashes; a valid unacknowledged revision is never promoted. A fallback result distinguishes `snapshot.revision` from `acknowledgedRevision` (the required CAS token), with a typed warning. Invalid pointer data fails closed and its revision evidence is preserved. Corrupt projects do not hide healthy projects.

New asset bytes and a manifest are flushed in a `.stage-<revision>-<nonce>` sibling, assets are published under their immutable content references, and the completed revision directory is renamed into place. A flushed `.current-<nonce>` replaces `current` atomically as the commit boundary. Process interruption before that boundary reopens the prior acknowledged state; after it, the new state is committed even if the caller did not receive the result. This is **process-interruption recovery**, not a device power-loss guarantee: no directory fsync/platform persistence barrier is currently available here. Concurrent handles in the same app isolate share the queue; the tree is not a multi-process or multi-isolate database.

Reopen/save cleanup removes recognized staging, temporary-pointer and unacknowledged revision artifacts. It removes an unreferenced content asset only when all acknowledged manifests can be validated; otherwise assets are retained. Quarantine writes safe reason/revision/hash metadata best-effort, without moving/deleting corrupt originals. All owned path components are checked without following symlinks. Inventory streams file hashes and includes directories, pointers, every revision, orphan/staging/quarantine files and link identities; deletion removes links themselves without touching their targets. Inventory bounds depth to 16 and entries to 100,000, failing closed beyond that. The private app-storage parent is canonicalized once, and its canonical ancestors are rechecked on subsequent operations so later parent redirection fails closed. This is not an `openat`-style hostile-filesystem sandbox against external path swaps racing individual syscalls.

Schema v1 manifests retain their exact frozen field/asset set without intent. The decoder accepts only known manifest schemas `1` and `2`, rejecting unknown versions/fields. V1 reads migrate only in memory to an all-zero intent bitmap, even when current labels differ from AI; provenance is never inferred. Opening does not rewrite v1 files. The next acknowledged save writes v2 only, reusing valid immutable photo/mask/thumbnail assets and preserving appearance, IDs, variants, comparison baseline, UTC timestamps and CAS/revision semantics. An older v1-only reader rejects v2 revisions; downgrades cannot preserve new intent through a v1 rewrite. Checksummed ancestry may mix v1/v2 manifests. Corrupt intent falls back only through acknowledged ancestry, retaining original evidence and the current acknowledged CAS token; a newer orphan is never promoted. Shared corrupt content addresses still fail immutable-asset reuse rather than overwrite retained evidence.

Plan 03 Task 2 also persists exact command history in schema 2. Frozen v1 and transitional Task 1 v2 manifests without a history key read as empty aligned history; a present history key must be valid and non-null. Every new v2 write includes its content-addressed history asset, including empty history. History is not inlined into the bounded manifest. An older Task 1 v2 reader rejects this new field rather than discard it.

The deterministic binary format is `TAEH`, version 1, big endian. Its 28-byte header contains four magic bytes, uint16 version `1`, uint16 reserved `0`, then uint32 width, height, undo-count, redo-count and typed-payload byte count. Records serialize oldest-first undo entries followed by redo entries in stack order (last redo is next to replay). Each record begins with uint32 width/height/changed-index-count, followed by all uint32 indices, then before-label, after-label, before-intent and after-intent uint8 arrays. Indices are strictly ascending, unique and in bounds; labels are 0–4 and intent 0–5; a complete no-op command is invalid. Header/record extents, count/payload limits and exact end-of-input are checked before delta allocation, then complete undo and redo chains are validated against the current snapshot. Invalid order, stale state, bad bytes/digest/path/length or trailing data rejects only that revision.

Both stacks together retain at most 20 complete commands and 16 MiB of typed-array payload (8 bytes per changed pixel); binary overhead is bounded separately to 28 + 20 × 12 bytes, making the maximum asset 16,777,484 bytes. Push clears redo and evicts oldest complete undo commands only. An individual newest command over 16 MiB clears all history rather than retain a broken chain or partial command. Undo/Redo move complete immutable commands and restore exact ownership/intent, without recomputing deltas. A deprecated, transient legacy refinement adapter exists only until Task 3; it is never persisted as an undo-only type. Controller intent-aware strokes/refresh and user-facing Redo remain Task 3. **ROOM-03 remains partial** until those durable edit paths land. Unknown data is retained and rejected, never auto-reset.

### Frozen Plan 02 migration artifacts

`test/fixtures/room_projects/v1/` is the immutable Plan 03 input. Its
`inventory.json` (SHA-256
`365055822f7b29fbff9b09afdd242c8bd597f0ff9a0980b99d559e11fbca1013`)
pins 13 files / 5,801 bytes: two checksummed pointers, four acknowledged
manifests, independent project-owned PNG/mask assets, and a null-thumbnail case.
The independent synthetic fixture assembly targets schema v1 at commit
`4d98b1604d6901086035dd8eb7af26b61ced824f`; no personal photo or model is included.
The fixture README records fixed IDs, UTC timestamps, 3 × 2 corner pixels,
AI/current labels, variants/colors and baseline expectations. Consumer tests
verify every file's size/hash, copy exact bytes into owned temporary storage,
and reopen without using the current encoder to produce their input. They
exercise unknown versions/fields, corrupt-current acknowledged-ancestry
fallback, the distinct CAS token, and rejection of a valid newer orphan.
Plan 03 must migrate these exact bytes rather than regenerate them. These
fixtures do not broaden strict export PNG support or establish device
power-loss durability.

## Route registry

Routes are currently path-addressed; no GoRouter `name:` contracts exist. Preserve or explicitly migrate inbound/internal links when the adaptive shell changes.

| Area | Paths |
| --- | --- |
| Current indexed roots | `/home`, `/rooms`, `/learn`, `/games` |
| My Work and settings | `/my-work`, `/settings/privacy`, `/settings/data`, `/settings/models`, `/settings/licenses` |
| Nested/compatible tools | `/capture`, `/palette`, `/lab` (redirect to `/learn/experiment/lab`), `/room` (redirect to `/rooms`) |
| Startup/onboarding | `/startup`, `/onboarding`, `/welcome` |
| Photo acquisition | `/camera`, `/photo` |
| Real/illustrated rooms | `/room/study` (redirect), `/room/illustrated`, `/room/illustrated/:templateId`, `/room/masks`, `/rooms/projects`, `/rooms/project/:projectId` |
| Color learning/tools | `/learn/lesson/:lessonId`, `/learn/notebook`, `/learn/experiment/:experimentId`, `/vision`, `/matching`, `/harmonies`, `/palettes`, `/formula`, `/mixer` |
| Games | `/bubble-shooter`, `/rainbow-rings`, `/water-sort`, `/fruit-pop`, `/games/badges`, `/games/leaderboard`, `/games/:gameId/map` |

The initial location is `/home`. Startup/onboarding guards can redirect to `/startup` and `/onboarding`. Settings pages return to their pushed caller or fall back to Home for direct entry.

### Explicit local data controls

Data controls use the active repositories' serialized maintenance operations. A preview freezes exact record keys and content fingerprints; deletion consumes that authorization, requires the same categories, and validates every selected owner before writing. Room-photo projects are active: preview records count projects with a current pointer (including corrupt pointers), not files; stored revision directories and aggregate owned bytes are separate detail. Learning-progress controls are active and own only `learning_library_v1`; Coloring projects remain disabled. User exports and acquisition metadata are excluded. All-game deletion explicitly covers both game boxes and leaves the Games section empty until the person creates a new named player. Shared libraries stay independent.

Model inventory is read-only. Model removal cancels and drains active work, blocks new preparation during removal, and touches only pinned model files and partials beneath `room_models`; directory symlinks are rejected. Data-management preview fails safely while a model download is active, leaving explicit cancellation/removal to Model storage. No repository is closed/reopened to perform deletion. Storage I/O failures can leave partially removed selected data across independent owners; the UI retains its selection and last preview, reports failure, and requires a fresh review.

## Bundled runtime assets

`pubspec.yaml` declares the audio file, color-name JSON, model descriptor, all files under `assets/rooms/` and `assets/licenses/`, and the two fonts. Hashes below pin the current bytes.

| Asset | Bytes | SHA-256 |
| --- | ---: | --- |
| `assets/audio/pour_bottle_clean.mp3` | 26,596 | `dc5d4345cf9bf40d0d6f9bc37041c85b56a47f0fec83c970f2508ab5fe470827` |
| `assets/data/color_names.json` | 1,276,570 | `09e8c114d57f63cde82dad08a0aaf2c5d88c9234aa4f6dc171f54b5b7d9b4b8a` |
| `assets/models/room_seg_descriptor.json` | 1,160 | `cf1bb10c7518cb4ff5e5403f856f1342280dbce8341a72c26fbd06d2e345d533` |
| `assets/fonts/JetBrainsMono-Variable.ttf` | 187,208 | `48715a42ec242c21e9f02692891e147d022299a52e48d5e413e1a942193ffeda` |
| `assets/fonts/PlusJakartaSans-Variable.ttf` | 176,288 | `89b3fb38aa0d275d7a731d0d817a4f1622b316b4d7fbdedcf02ee9099ff68bc8` |
| `assets/rooms/bathroom_room.svg` | 18,492 | `61c12bdca53ffc595b2396991c5468865eeee4461764892ae570e811b7e3add6` |
| `assets/rooms/bedroom_room.svg` | 15,669 | `51239f270468bcb7b84393ef432c2b3c8eda076aee456c215cfd6770e47a7bdd` |
| `assets/rooms/dining_room.svg` | 15,823 | `bc3464d1fbf701104ead3a3de053b7ad565bd6d871b2a5672fdb50b32c177e39` |
| `assets/rooms/kitchen_room.svg` | 16,249 | `d08f2a4a444c8d7fadf7e7ca97f695155c46373611a525dbb4fbc0c29336af93` |
| `assets/rooms/living_room.svg` | 17,168 | `17b9b89abf503af23faf2d18fc84bf94665df24a15289c570ed32c317a228b86` |
| `assets/rooms/study_room.svg` | 24,114 | `d547a004155670db40e058afe1a4fb0a06c0d83e0376189ca210f45655e6ee0a` |
| `assets/rooms/regions/bathroom_room.v1.json` | 9,271 | `3d0edf621aa7aac0da31a2e001d525d0191a3ddc089e1dfc32ce6687424715fa` |
| `assets/rooms/regions/bedroom_room.v1.json` | 18,293 | `8d97f12556aade078b89fd5b29123c7ce01c8752299b83ba5d945ce4c39704ae` |
| `assets/rooms/regions/dining_room.v1.json` | 18,738 | `b0ac3e9d192b65ec26a93fa676e1cbf731e453e4b27c47d8fcefc28b10cd47eb` |
| `assets/rooms/regions/kitchen_room.v1.json` | 17,489 | `c7390a425eb5a84a8f933745586b20eb77bdd1e0cf8bcc0f7622d05dd3a5340a` |
| `assets/rooms/regions/living_room.v1.json` | 20,402 | `577ea777d36e5a8378aa9181cdac7bbde575f0ca0537340eb8bc614e7a3feafe` |
| `assets/rooms/regions/study_room.v1.json` | 22,294 | `4b753ef541f8ee2a3011f80e7ad6bb499f96c17c248100d04e94733f7c8c1185` |
| `assets/rooms/palettes/starter_palettes.v1.json` | 1,722 | `985ee30d37ea07270c50a35144fdc7669a2dba61e70783fa96d989a7875edf1c` |
| `assets/licenses/illustrated-room-palettes-NOTICE.txt` | 843 | `e1bf7191aaf19a20ef9507636ba067033e950374e74fab9d558a8f75f048b8ba` |

Existing model/font/data license and notice files are registered at runtime
from `lib/main.dart`. The illustrated-room palette NOTICE listed above is
bundled but its runtime registration remains explicitly deferred. Provenance
and current hashes remain authoritative in `docs/asset-sources.md`. Any new
palette, artwork, model, font, sound, or icon must add source, rights, checksum,
and runtime-license evidence before shipping.

### Illustrated Rooms v2 artwork catalogue

The shared vector-region contract is schema 1. All six template IDs and artwork
revisions remain stable at revision 1; every artboard is 1200 × 800. JSON owns
all fill geometry and SVG owns fixed decoration plus only the bounded,
allowlisted shared-path recipes recorded by the loader. Region identity, group,
paint order and contiguous part slots are compatibility data consumed by both
Illustrated Rooms and the future Coloring Studio.

| Template | Revision | Regions | Parts | Decoration slots | Final SVG / JSON SHA-256 |
| --- | ---: | ---: | ---: | ---: | --- |
| `living` | 1 | 9 | 19 | 20 | `17b9b89a…228b86` / `577ea777…feafe` |
| `bedroom` | 1 | 9 | 20 | 21 | `51239f27…a7bdd` / `8d97f125…9704ae` |
| `study` | 1 | 8 | 21 | 22 | `d547a004…5e6ee0a` / `4b753ef5…c8c1185` |
| `dining` | 1 | 10 | 21 | 22 | `bc3464d1…c177e39` / `b0ac3e9d…cd47eb` |
| `kitchen` | 1 | 10 | 18 | 19 | `d08f2a4a…36af93` / `c7390a42…a5340a` |
| `bathroom` | 1 | 7 | 11 | 12 | `61c12bdc…e3add6` / `3d0edf62…4715fa` |

The exact pre-region SVG inputs remain test-only fixtures. Their SHA-256 values
are, respectively: Living `81a400211f87253eeb844fc9f427f164091734077c60e8d01cb8aae6d13796e6`,
Bedroom `d5f69379b8bba90a2e28fc7df0d982711a82a02701ed7fd9b564ac23a27818f4`,
Study `3637e4f694387cb1ec2b5c2555f7cb969290ed5b9ef836fa69ce7cf8b58a8168`,
Dining `dd13522ce28cdec7eaf9a601a15eaa39c661a114a18783ae3f8bafa6c531536a`,
Kitchen `876c7a4e136b2354a54c66d148ac28c845e5cab6506f4ae021ac219af0dc4d88`,
and Bathroom `a5400b6a4e50bd9f4c4a1d058e51b189d75371564e20f1e4d60af258ed26c068`.
The frozen six-design schema-v1 fixture is 1,818 bytes, SHA-256
`c34d867347480f5916a6bf79a69c5b7b5a5840c3b19cb752ca6f051e15714a8f`.
These hashes preserve migration evidence; they are not current runtime assets.

The palette NOTICE is bundled but is not yet registered by the protected
`lib/main.dart` runtime license list. That release gap remains open and the
NOTICE grants no rights to the room illustrations.

## Downloaded Room models

These binaries are not bundled in the APK. Verified bytes live in app-support storage at `room_models/<sha256>/<filename>` and are promoted only after exact size/hash validation.

| File | Bytes | SHA-256 | Pinned download |
| --- | ---: | --- | --- |
| `room_seg.tflite` | 1,978,000 | `da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c` | [room-models-v1 MOSAIC binary](https://github.com/rowjoy/color_lab/releases/download/room-models-v1/room_seg.tflite) |
| `room_depth.tflite` | 66,338,288 | `93d871071edff1218973ce25ee27ce95ccd20450c70a55e1b89efa3f5a772cdd` | [room-models-v1 MiDaS binary](https://github.com/rowjoy/color_lab/releases/download/room-models-v1/room_depth.tflite) |

Aggregate download: 68,316,288 bytes (65.151 MiB). Model source revisions, licenses, notices, preprocessing limits, and repository-release provenance are pinned in `docs/asset-sources.md` and the four Room model license/notice assets.

## Current export/transient boundaries

- Illustrated Room gallery export validates PNG signature and a safe filename, writes into an owned `tintatlas-gallery-*` temporary directory, requests the platform-specific non-album permission and calls the platform gallery API, then best-effort deletes only that owned directory.
- Color sharing currently sends formatted color text through the platform share sheet; it does not own a persistent export file.
- Real-room Save/Share detach only the selected current working-resolution frame, validate its dimensions and strict metadata-free RGB/RGBA PNG structure, checksums and bounded zlib rows, and use `tintatlas-room-<safe-id>.png`. A lifetime/full-key/owner guard is repeated synchronously at the terminal native channel call after permission and owned-temp preparation. Save creates an external Photos/Gallery image; Share opens the native sheet. Neither mutates project save state. Owned `tintatlas-gallery-*` / `tintatlas-share-*` directories are cleaned best-effort after native completion; a successful native result survives cleanup failure. Plugin-managed share caches retain the plugin/OS lifecycle. Source picker files are read only, never deleted by this pipeline; only prepared working copies/thumbnails/recolor exports are proven metadata-free. Non-album access preserves gal's iOS 14+ add-only / iOS 13 authorization behavior and Android version-specific scoped storage behavior. No broad media-read permission is added.
- Real-room recolor frames live in memory. Durable Room projects/photos/masks/thumbnails use the independently owned `room_projects` schema above.
- Downloaded models are app-support data managed by the model store, not cache; model removal must not delete projects.

## Migration checklist

Every schema change must provide: previous serialized fixtures, deterministic migration, last-valid retention, isolated corruption behavior, atomic/flush-before-success writes, rollback/compatibility notes, storage-failure UX, and proof that game-profile operations cannot alter shared My Work.
