# TintAtlas compatibility and schema registry

**Recorded:** 2026-10-27

**Applies from:** pre-Plan-01 product baseline `b4043bc`

**Rule:** names and formats in this registry are compatibility contracts; change them only through a versioned migration with old-format fixtures.

## Storage ownership

Current durable data uses Hive beneath the application-documents `color_lab` directory. No SharedPreferences-backed product state was found.

| Schema / box | Root identity | Current version and record | Owner / deletion boundary |
| --- | --- | --- | --- |
| `app_preferences_v1` | key `preferences` | `schemaVersion: 2`; `themeMode`, `onboardingCompleted`, `motion`, `highContrast`, `alwaysShowColorLabels`. Version 1 reads use safe accessibility defaults; the next edit writes v2. | Installation-local settings. Explicit reset returns to onboarding; unsupported schemas remain untouched. Never deletes projects, colors, palettes, or games. |
| `color_history_v1` | one record per canonical HEX key | `version: 1`; `id`, `hex`, `name`, `isFavorite`, `createdAt`, `source` | Shared My Work color library. A game-profile deletion must not touch it. |
| `color_palettes_v1` | `${mode.name}-${HEX-without-#}` | `version: 1`; `id`, `name`, `base`, `mode`, `colors`, `createdAt` | Shared My Work palette library. Consumers copy color snapshots rather than retaining fragile foreign keys. |
| `illustrated_room_designs_v1` | one record per generated design ID | `version: 1`; `id`, `name`, `templateId`, wall/ceiling/floor/furniture colors, `createdAt`, `updatedAt` | Shared My Work illustrated designs. Template migrations must preserve the visible result. |
| `photo_acquisition_v1` | key `pending` | `schemaVersion: 1`; `requestId`, `source`, `destination` | Transient recoverable acquisition intent. Clearing it must not delete a selected source photo owned elsewhere. |
| `game_profiles_v2` | key `state` | root `schemaVersion: 2`; `activeProfileId`, `profiles`, `pendingLegacySnapshot`, `legacyMigrationComplete`; nested game/profile records remain v1 | Games-only profiles/progress/rewards/preferences. Profile deletion must not delete or hide shared My Work. |
| `game_progress_v1` | key `progress` | legacy aggregate schema v1 | Read as the migration source for `game_profiles_v2`; retain until migration/rollback evidence explicitly retires it. |

Immutable serialization details include root keys, enum storage strings, stable `GameId` values, UTC timestamp encoding, uppercase canonical `#RRGGBB`, and nested record versions. Corrupt-record handling must isolate the bad record and retain recoverable bytes; it must not reset an entire healthy box silently.

### Future schema ownership reserved by the approved design

Real-room projects, Coloring projects, Learning progress/notebooks, and the unified My Work index do not yet have persisted launch schemas. Their Task 2+ implementations must choose independent versioned names, add old/current/future fixtures, and update this registry before writing production data. `game_profiles_v2` must never become the owner of those shared records.

## Route registry

Routes are currently path-addressed; no GoRouter `name:` contracts exist. Preserve or explicitly migrate inbound/internal links when the adaptive shell changes.

| Area | Paths |
| --- | --- |
| Current indexed roots | `/home`, `/rooms`, `/learn`, `/games` |
| My Work and settings | `/my-work`, `/settings/privacy`, `/settings/data`, `/settings/models`, `/settings/licenses` |
| Nested/compatible tools | `/capture`, `/palette`, `/lab`, `/room` (redirect to `/rooms`) |
| Startup/onboarding | `/startup`, `/onboarding`, `/welcome` |
| Photo acquisition | `/camera`, `/photo` |
| Real/illustrated rooms | `/room/study` (redirect), `/room/illustrated`, `/room/illustrated/:templateId`, `/room/masks` |
| Color learning/tools | `/vision`, `/matching`, `/harmonies`, `/palettes`, `/formula`, `/mixer` |
| Games | `/bubble-shooter`, `/rainbow-rings`, `/water-sort`, `/fruit-pop`, `/games/badges`, `/games/leaderboard`, `/games/:gameId/map` |

The initial location is `/home`. Startup/onboarding guards can redirect to `/startup` and `/onboarding`. Settings pages return to their pushed caller or fall back to Home for direct entry.

### Explicit local data controls

Task 8 uses the active repositories' serialized maintenance operations. A preview freezes exact record keys and content fingerprints; deletion consumes that authorization, requires the same categories, and validates every selected owner before writing. Reserved Room-photo-project, Coloring-project, and Learning-progress categories are disabled. User exports and acquisition metadata are excluded. All-game deletion explicitly covers both game boxes and may be followed by a fresh default profile. Shared libraries stay independent.

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
| `assets/rooms/bathroom_room.svg` | 15,189 | `a5400b6a4e50bd9f4c4a1d058e51b189d75371564e20f1e4d60af258ed26c068` |
| `assets/rooms/bedroom_room.svg` | 14,112 | `d5f69379b8bba90a2e28fc7df0d982711a82a02701ed7fd9b564ac23a27818f4` |
| `assets/rooms/dining_room.svg` | 14,077 | `dd13522ce28cdec7eaf9a601a15eaa39c661a114a18783ae3f8bafa6c531536a` |
| `assets/rooms/kitchen_room.svg` | 13,739 | `876c7a4e136b2354a54c66d148ac28c845e5cab6506f4ae021ac219af0dc4d88` |
| `assets/rooms/living_room.svg` | 15,847 | `81a400211f87253eeb844fc9f427f164091734077c60e8d01cb8aae6d13796e6` |
| `assets/rooms/study_room.svg` | 21,279 | `3637e4f694387cb1ec2b5c2555f7cb969290ed5b9ef836fa69ce7cf8b58a8168` |

License/notice files are registered at runtime from `lib/main.dart`; their provenance and current hashes remain authoritative in `docs/asset-sources.md`. Any new palette, artwork, model, font, sound, or icon must add source, rights, checksum, and runtime-license evidence before shipping.

## Downloaded Room models

These binaries are not bundled in the APK. Verified bytes live in app-support storage at `room_models/<sha256>/<filename>` and are promoted only after exact size/hash validation.

| File | Bytes | SHA-256 | Pinned download |
| --- | ---: | --- | --- |
| `room_seg.tflite` | 1,978,000 | `da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c` | [room-models-v1 MOSAIC binary](https://github.com/rowjoy/color_lab/releases/download/room-models-v1/room_seg.tflite) |
| `room_depth.tflite` | 66,338,288 | `93d871071edff1218973ce25ee27ce95ccd20450c70a55e1b89efa3f5a772cdd` | [room-models-v1 MiDaS binary](https://github.com/rowjoy/color_lab/releases/download/room-models-v1/room_depth.tflite) |

Aggregate download: 68,316,288 bytes (65.151 MiB). Model source revisions, licenses, notices, preprocessing limits, and repository-release provenance are pinned in `docs/asset-sources.md` and the four Room model license/notice assets.

## Current export/transient boundaries

- Illustrated Room gallery export validates PNG signature and a safe filename, writes into an owned `color-lab-gallery-*` temporary directory, calls the platform gallery API, then best-effort deletes only that owned directory.
- Color sharing currently sends formatted color text through the platform share sheet; it does not own a persistent export file.
- Real-room PNG sharing validates the in-memory recolor frame's PNG signature, sanitizes/truncates the photo ID into `color-lab-room-<safe-id>.png`, and hands detached bytes to `share_plus`. The app creates no durable export record; any platform/plugin share-sheet materialization is transient rather than project storage.
- Real-room recolor frames otherwise live in memory. Durable Room projects/photos/masks/thumbnails are future schemas and must define private-storage ownership and deletion before persistence lands.
- Downloaded models are app-support data managed by the model store, not cache; model removal must not delete projects.

## Migration checklist

Every schema change must provide: previous serialized fixtures, deterministic migration, last-valid retention, isolated corruption behavior, atomic/flush-before-success writes, rollback/compatibility notes, storage-failure UX, and proof that game-profile operations cannot alter shared My Work.
