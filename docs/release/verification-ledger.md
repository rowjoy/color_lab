# TintAtlas verification ledger

**Created:** 2026-10-27

**Milestone:** Plan 01 — foundation, shell, and data

**Purpose:** immutable baseline evidence and acceptance tracking for later tasks

## Source/worktree preservation

| Evidence | Recorded value |
| --- | --- |
| User branch | `TintAtlas` |
| Pre-plan product HEAD | `b4043bc` |
| Documentation/isolation baseline | `b254944e7f3be23199701fb9e822943d5727d201` (`docs: add TintAtlas implementation plans`) |
| Implementation branch | `codex/tintatlas-plan-01` |
| Isolated worktree | `.worktrees/tintatlas-plan-01` |
| User-owned file | `lib/main.dart`, unstaged only in the original `TintAtlas` checkout |
| Protected diff SHA-256 | `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437` |

The user-owned diff appends a comment containing the chosen working title after `main()`. It is not copied into, staged by, or overwritten in the isolated implementation branch. Before integrating this branch, re-hash the original diff and resolve `lib/main.dart` deliberately.

The documentation commit is the only difference between the product baseline and isolated branch baseline before Task 1. It contains approved plans/specs and no product code.

## Requirement-plan coverage

`tool/check_plan_coverage.dart` extracts unique IDs matching the approved requirement format, unions IDs from supplied plans, and fails by named classification for omissions. `--allow` accepts only IDs explicitly classified Post-launch or Deferred by a tag, legend label, or section heading; Launch and Conditional v1 cannot be exempted.

Evidence on the approved full-product spec plus all eleven TintAtlas plans:

```text
Coverage OK: 161 unique requirement IDs; 0 explicitly allowed omissions.
```

Focused tests cover duplicate de-duplication, named Launch failure, all 161 approved IDs, Conditional rejection, ordinary “deferred” prose remaining Launch, and explicit Post-launch/Deferred exemptions.

## Baseline command results

| Check | Result | Evidence / disposition |
| --- | --- | --- |
| `flutter pub get` | pass | Dependencies resolved with the pinned Flutter SDK. |
| `flutter analyze --no-pub` | pass with 1 pre-existing info | `lib/features/games/presentation/fruit_pop_screen.dart:1048:58` — `unnecessary_brace_in_string_interps`. Task 10 owns cleanup and clean rerun. |
| Dart format check over `lib test tool` | non-clean baseline | One pre-existing file would change: `lib/features/color_test/presentation/matching_screen.dart`. Task 10 owns focused formatting and full recheck. |
| Full `flutter test --no-pub` | fail: `+1527 -38` | All 38 failures are inventoried below and are Plan 01 Task 10 scope. Scratch log: `.superpowers/sdd/2026-10-27-tintatlas-foundation-shell-data/baseline-full-test.log`. |
| Focused failure reproduction | fail: same 38 named behaviors | 35 failures across focused game/provider/widget files plus 3 integration failures. Scratch logs: `task-1-focused-baseline.log` and `task-1-focused-integration-baseline.log` in the same SDD directory. |
| Android debug APK | pass | 185,583,606 bytes; SHA-256 `66b9d87a0aa9ca3ca9b830ed1bd328f587ed1c88c572e820271330823144bd4e`. |
| Android release-mode APK | pass | 85,949,904 bytes; SHA-256 `932f2c808c02c77317f61a42dba0675063548ea1697f175ec5da79a2c39478dd`; development signing, not a store candidate. |
| iOS build/archive | blocked | No device/simulator archive baseline was produced. Owner: iOS Release; evidence required before any iOS release claim. |

## Exact pre-existing test-failure inventory

The paths and names below are the authoritative baseline comparison set. A changed count alone is insufficient; Task 10 must make each named behavior pass without hiding or deleting coverage.

### `game_profiles_provider_test.dart` — 7

- default repository opens, loads, and closes with its container
- injected IDs and UTC clock drive CRUD and all derived providers
- queued commands use newest durable state and publish after writes
- load retry and write recovery preserve the last good AsyncData
- completion normalizes through launch adapter before any transaction
- failed post-receipt refill keeps reward launchable and retryable
- initial catalog generation failure still surfaces atomically

### `bubble_shooter_screen_test.dart` — 1

- uses the descriptor level and tier and exposes Map and fresh Restart

### `badges_screen_test.dart` — 1

- explains that a local player is required for badges

### `games_screen_test.dart` — 9

- shows loading, recoverable load error, and retry
- requires a named player before showing any game cards
- active profile controls all aggregate and per-game stats
- Play waits for its durable launch and errors never navigate
- a pending launch locks every game card
- profile switch during held resume never launches the previous player
- profile switch during held new attempt never writes for the old player
- five-game hub fits 360dp at 2x text with semantics in light
- five-game hub fits 360dp at 2x text with semantics in dark

### `leaderboard_screen_test.dart` — 1

- an empty state stays available across leaderboard filters

### `profile_management_sheet_test.dart` — 1

- required first-player dialog blocks dismissal until creation

### `fruit_pop_screen_test.dart` — 8

- a loss stays current and Try again allocates a new attempt
- win copy waits for durability and stores normalized score
- Map is disabled while a winning completion is being saved
- duplicate result hides rewards and Next Level uses persisted launch
- profile switch blocks Next Level without replacing the launch
- a failed completion keeps Retry save available
- a stale attempt is rejected without retry or rewards
- launch replacement ignores an older completion callback

### `game_level_map_screen_test.dart` — 7

- an empty profile state is safe and starts no level
- first visit prepares and exposes exactly levels 1 through 15
- completed, current, and generated future nodes expose their actions
- replay and current Play callbacks wait for durable writes
- a failed Play write shows recovery copy and never launches
- refilled map exposes level 30 and earned level-20 milestone
- dark 360dp map supports 2x text and meaningful semantics

### `games_integration_test.dart` — 2

- two named players keep independent endless progress across restart, replay, ranking, and stale launches
- legacy aggregates appear in the first named player while every game starts at level one

### `matching_integration_test.dart` — 1

- Back reentry theme and completion preserve game and independent drafts

## Task 1 gate ledger

| Requirement | State | Evidence / next owner |
| --- | --- | --- |
| BASE-01 preserve working tree | pass | Isolated branch/worktree; original `lib/main.dart` diff hash recorded and excluded. |
| BASE-02 truthful baseline | pass for inventory | Analyzer/formatter/test/build results above. Baseline failures remain repair work, not hidden passes. |
| BASE-03 inventory schemas/routes/models/exports | pass | `schema-registry.md`. |
| BASE-04 verification ledger | pass | This document and deterministic coverage CLI. |
| BASE-05 dependency/size/performance budgets | partial, measured fields recorded | `performance-budgets.md`; hardware-only rows are blocked with owners. |
| BASE-06 repeatable clean verification | pending Task 10 | Local commands exist; CI waits until baseline failures are repaired. |
| BRAND-01 screen TintAtlas | blocked before asset/store lock | Exact-name adjacent web conflict; product owner/clearance reviewer must accept or rename. See `identity-decision.md`. |
| IDENTITY-01 confirm publication history | blocked | Store-account owner must attest history; `newListing` cannot be inferred. |
| SUPPORT-01 support contract | provisional | API 24/iOS 13 and architectures documented; physical device/archive gates remain blocked. See `support-matrix.md`. |

## Evidence rules for later tasks

- Each task records its RED test, GREEN command, exact commit, migration/rollback evidence, and any blocked external input here or in a linked dated record.
- A blocked field names its owner and required evidence; code does not manufacture store history, legal clearance, human mask annotations, device access, or publication approval.
- Product files remain untouched in Task 1. Later work must preserve schema names and routes or supply migrations/redirects.
- No public release, store upload, credential change, package-ID change, signing change, or ad activation follows from this ledger.
