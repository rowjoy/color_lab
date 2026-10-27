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
| Implementation branch | `TintAtlas` |
| Active checkout | `/Users/jamirulislam/Movies/dart_jpo/color_lab` (shared checkout) |
| User-owned file | `lib/main.dart`, unstaged in this active checkout and excluded from every Plan 01 commit |
| Protected diff SHA-256 | `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437` |

The user-owned diff appends a comment containing the chosen working title after
`main()`. Its exact hash remains the protection boundary: it is never formatted,
staged, or overwritten by Plan 01. Tasks 1–4 were first committed on the
isolated implementation branch and then fast-forwarded to `TintAtlas` at the
user's explicit direction; later tasks run directly in this shared checkout.

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

## Task 10 failure classification and scope amendment

The baseline failures were reproduced in three read-only groups before any
Task 10 product edit: provider/integration `+30 -10`, hub/accessibility
`+21 -13`, and Fruit Pop/Level Map `+5 -15`. The following rulings bind the
repair pass:

- The approved endless-game profile contract requires a named first player.
  Loading empty storage must stay empty until the person creates that player.
  The later automatic `You` profile is a product regression: it writes during
  load, consumes injected identifiers, bypasses legacy import into the first
  named player, and causes delete-all game data to recreate data immediately.
- Shared toolbar wording is authoritative for existing controls. The Bubble
  Shooter `Restart` and Fruit Pop `Mute sounds` test finders are stale against
  the shared `Restart level` and `Mute game sounds` labels.
- Keys on Games statistic wrapper widgets are intentional. The stale test
  helper must read their descendant `Text`; production does not move those
  keys solely to satisfy a cast.
- Decorative Level Map animation may continue normally, but reduced motion
  must be static and tests must use bounded, state-specific pumping instead of
  waiting for a repeating animation to settle.

Task 10 may therefore modify these additional paths beyond the original
failure-file inventory:

- `lib/features/games/application/game_profiles_provider.dart` — restore the
  no-write empty-load contract.
- `lib/features/games/presentation/games_screen.dart` — expose the required
  first-player action and accessible Play identities.
- `lib/features/games/presentation/game_play_app_bar.dart` — use the localized
  generic Back tooltip for a toolbar shared by Games and Learn.
- `lib/features/games/presentation/game_level_map_screen.dart` — restore
  visible/action semantics and honor reduced motion.
- `test/features/games/game_profile_shared_library_isolation_test.dart` —
  replace the erroneous post-delete automatic-profile expectation with the
  approved empty state while preserving shared-library assertions.
- `lib/l10n/app_en.arb`, generated localization outputs, and
  `docs/release/schema-registry.md` — remove the inaccurate automatic-profile
  deletion claim and describe explicit player creation truthfully.
- `lib/features/color_test/presentation/matching_screen.dart` — apply the
  already-recorded baseline formatter delta only.

A supplemental full-suite RED run after the Task 7 four-root shell migration
reached `+1604 -12` before a stale navigation helper stalled teardown. A
bounded single-thread JSON rerun confirmed that these are test-only route-entry
assumptions: the accepted shell removed `nav-Lab`, `nav-Room`, and
`nav-Palette`, and Capture is no longer rendered on the initial Home root.
Task 10 may also update the following exact test paths to enter through the
current `nav-learn` / `learn-open-*` and `nav-rooms` contracts. Each helper
must assert that its target exists before tapping so a missing destination
cannot become a vacuous or hanging test:

- `test/features/picker/color_details_actions_test.dart`
- `test/features/formula/presentation/formula_integration_test.dart`
- `test/features/harmonies/presentation/harmonies_integration_test.dart`
- `test/features/mixer/presentation/mixer_screen_test.dart`
- `test/features/room_studio/presentation/room_masks_integration_test.dart`

No other production/test path is authorized without another amendment here.

## Task 10 final verification

Task 10 ran from BASE `5231b22413945d0f6c648088ac13fbfccc8e884a` on
branch `TintAtlas` with Flutter 3.41.1 and Dart 3.11.0. Package identity,
signing, icons, ad configuration, and the Task 9 gate were not changed.

| Check | Exit / count | Evidence |
| --- | --- | --- |
| Three authoritative RED groups | expected failure | Provider/integration `+30 -10`; hub/accessibility `+21 -13`; Fruit Pop/Level Map `+5 -15`. All 38 named baseline failures were observed before repair. |
| Authoritative focused GREEN | `0`, `+95` | All original failure files plus shared-library isolation passed together with `--concurrency=1 --reporter compact`. |
| Supplemental shell-contract RED | failure before repair | Default-concurrency run reached `+1604 -12` and exposed a teardown stall; the bounded single-thread JSON rerun traced it to the five exact stale Task 7 test paths authorized above. |
| Supplemental shell-contract GREEN | `0`, `+84` | Color details, Formula, Harmonies, Mixer, and Room Masks integration files passed together with `--concurrency=1 --reporter compact`. |
| `flutter pub get` | `0` | Dependencies resolved from the pinned project constraints; no dependency or lockfile change was produced. |
| `flutter gen-l10n` | `0` | `l10n.yaml` drove generation; committed English localization output is current. |
| Exact `dart format --output=none --set-exit-if-changed lib test tool` | `1`, 388 scanned / 1 reported | Only protected user-owned `lib/main.dart` was reported. The command did not mutate it; its diff SHA-256 remained `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`. |
| Eligible-tree format check excluding protected `lib/main.dart` | `0`, 387 / 387 unchanged | `rg --files lib test tool -g '*.dart' -g '!lib/main.dart' \| xargs dart format --output=none --set-exit-if-changed`. The clean CI checkout runs the exact full-tree command because the protected local diff is not committed. |
| `flutter analyze --no-pub` | `0` | `No issues found!` in 4.4 seconds. |
| `flutter test --no-pub --reporter expanded` | `0`, `+1650` | Full suite completed in 1 minute 2 seconds with `All tests passed!`; no skip or test deletion was added. |
| `flutter build apk --debug --no-pub` | `0` | `build/app/outputs/flutter-apk/app-debug.apk`; 217,348,770 bytes; SHA-256 `fb667758eabb915b3b1e103669eb558d5126a8682af9908caf19099bb6080e59`. Debug-only build; no signing or release secrets. |
| `git diff --check` | `0` | No whitespace errors. |
| Protected diff recheck | exact match | `lib/main.dart` remained unstaged with the recorded SHA-256 above. |

`.github/workflows/flutter_verify.yml` repeats dependency resolution,
localization generation, the exact full-tree format check, analyzer, full
expanded tests, and Android debug APK assembly on Ubuntu using Flutter 3.41.1
and Java 17. The workflow contains no signing, advertising, or release secret.
It has not yet run on GitHub; this ledger records the local command evidence,
not a remote CI claim. The iOS archive/device gate remains blocked as recorded.

## Task 1 gate ledger

| Requirement | State | Evidence / next owner |
| --- | --- | --- |
| BASE-01 preserve working tree | pass | Active `TintAtlas` shared checkout; protected `lib/main.dart` diff hash rechecked and excluded from Plan 01 staging. |
| BASE-02 truthful baseline | pass for inventory | Analyzer/formatter/test/build results above. Baseline failures remain repair work, not hidden passes. |
| BASE-03 inventory schemas/routes/models/exports | pass | `schema-registry.md`. |
| BASE-04 verification ledger | pass | This document and deterministic coverage CLI. |
| BASE-05 dependency/size/performance budgets | partial, measured fields recorded | `performance-budgets.md`; hardware-only rows are blocked with owners. |
| BASE-06 repeatable clean verification | pass locally; remote run pending | All eligible Task 10 files pass generation, format, analyze, `+1650` tests, and debug APK build. CI is pinned and committed; only the protected uncommitted `lib/main.dart` diff prevents the literal full-tree format command from returning zero in this shared checkout. |
| BRAND-01 screen TintAtlas | blocked before asset/store lock | Exact-name adjacent web conflict; product owner/clearance reviewer must accept or rename. See `identity-decision.md`. |
| IDENTITY-01 confirm publication history | blocked | Store-account owner must attest history; `newListing` cannot be inferred. |
| SUPPORT-01 support contract | provisional | API 24/iOS 13 and architectures documented; physical device/archive gates remain blocked. See `support-matrix.md`. |

## Evidence rules for later tasks

- Each task records its RED test, GREEN command, exact commit, migration/rollback evidence, and any blocked external input here or in a linked dated record.
- A blocked field names its owner and required evidence; code does not manufacture store history, legal clearance, human mask annotations, device access, or publication approval.
- Product files remain untouched in Task 1. Later work must preserve schema names and routes or supply migrations/redirects.
- No public release, store upload, credential change, package-ID change, signing change, or ad activation follows from this ledger.
