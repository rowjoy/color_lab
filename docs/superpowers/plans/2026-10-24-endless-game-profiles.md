# Endless Game Profiles and Progression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give all five Games entries named local profiles, deterministic endless per-game levels, first-clear rewards and badges, replay maps, and offline leaderboards with durable restart behavior.

**Architecture:** A pure progression engine owns profiles, catalogs, attempts, rewards, and ranking. Versioned game adapters turn stored descriptors into deterministic layouts; a schema-v2 Hive repository persists pure engine transitions atomically while retaining schema-v1 data for one-time migration. Riverpod exposes the active profile and commands, and every game screen receives an immutable `GameLaunch` instead of a selected difficulty.

**Tech Stack:** Flutter/Dart 3.11, Riverpod 3, GoRouter 17, Hive 2, `crypto`, `characters`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-24-endless-game-profiles-design.md`

## Global Constraints

- Apply this system to Bubble Shooter, Fruit & Veggie Pop, Water Sort, Rainbow Rings, and Games-launched Color Match; Lab-launched Color Match remains practice-only.
- Keep all data local/offline. Do not add accounts, network calls, cloud sync, or a mutable leaderboard table.
- Levels begin at 1 and have no product-visible end. Levels 1–9 are Easy, 10–19 Medium, and 20+ Hard; rewards are exactly 10/25/50 coins.
- Prepare 15 descriptors initially. After a first clear leaves `generatedThrough - currentLevel + 1 <= 10`, append exactly 15 descriptors.
- Grant coins and a per-game badge at each positive multiple of 20 only on first clear. Replays may improve score but never repeat rewards.
- A begun launch counts as one play. Abandoning it does not count as a win. Only a matching open attempt can complete; duplicate submissions are idempotent and stale attempts are rejected.
- Do not snapshot a partially played board. A new attempt regenerates the same initial layout from its stored descriptor.
- Use permanent string IDs, generator versions, a project-owned PRNG/shuffle, and canonical starting-layout fingerprints. Never persist enum ordinals or use SDK `List.shuffle` in a versioned generator.
- Preserve legacy schema-v1 coins, plays, wins, and global best score exactly once in the first profile; do not attribute legacy values to any game or level.
- Preserve the current Water Sort pour-audio timing/API and all existing Lab practice behavior.
- The working tree contains user-owned modified and untracked files. Do not reset, delete, overwrite, or broadly stage them. No commit, merge, or push is authorized; end each task with a narrow diff checkpoint instead of a commit.
- This plan leaves Rainbow Rings visually functional but does not implement the approved full animation catalogue; execute `docs/superpowers/plans/2026-10-24-rainbow-rings-animation.md` afterward.

## Review Focus

- Unicode/control-character/case variants in profile names must enforce 2–20 visible grapheme clusters and device-wide uniqueness; Task 8 pins this.
- Corrupt/unsupported v1 or v2 records and failed flushes must never be overwritten or reported as success; Task 11 pins this.
- Concurrent, duplicate, retry, replay, and stale completion callbacks must not double-count attempts, wins, coins, badges, or scores; Tasks 9 and 11 pin this.
- Very large levels, repeated fingerprint collisions, bounded generator failure, and refill restart must terminate predictably while leaving prepared play available; Tasks 2–7 and 9 pin this.
- Invalid route extras, profile changes while a game is open, and Lab Color Match practice must never mutate the wrong profile; Tasks 12 and 18 pin this.

## Frozen Generator-v1 Rules

- `levelPressure(level) = log(level) / log(2)` for every positive level; store the finite result in the descriptor.
- Derive a candidate seed from the first four big-endian bytes of SHA-256 over `v1|<profileId>|<gameId>|<level>|<retrySalt>`. Use xorshift32 and a descending Fisher–Yates shuffle owned by this project.
- Fingerprint the full canonical initial layout and its gameplay parameters with SHA-256. Retry collisions by incrementing `retrySalt`; never compare only the previous board.
- Move-efficiency score is `round(100 * parMoves / max(parMoves, actualMoves))`, clamped to `0..100`.
- Bubble v1: `colorCount = min(6, 3 + floor(pressure / 2))`, `rows = min(8, 4 + floor(pressure / 2))`, `dropEvery = max(4, 8 - floor(pressure / 2))`, and `parShots = ceil(initialBubbleCount / 3)`. Canonical data includes grid, current/next colors, pressure-row stream seed, and these parameters. Accept within 64 candidates only a clustered layout cleared by the bounded logical `landBubble` solver; retain its transient placement certificate and provide a deterministic known-clear fallback.
- Fruit v1: 8×8 board; `typeCount = min(6, 5 + floor(pressure / 4))`; `target = min(3000, 300 + round(pressure * 250))`; base moves `max(14, 22 - floor(pressure / 2))`; blockers `min(8, max(0, floor(pressure - 3)))`. A maximum of 64 board candidates and 16 greedy simulations per candidate may raise the budget through 30 until at least 8 simulations win; `parMoves` is the median winning count.
- Water v1: capacity 4, two empty tubes, `colorCount = min(9, 3 + floor(pressure))`, and reverse-scramble depth `min(80, max(8, colorCount * 2 + floor(pressure * 3)))`. Retain a transient inverse solution and verify it with the real domain before accepting a candidate; its length is `parMoves`.
- Rainbow v1: two empty pegs, `colorCount = min(6, 3 + floor(pressure / 2))`, `capacity = min(8, 4 + floor(pressure / 3))`, and reverse-scramble depth `min(120, max(10, colorCount * capacity + floor(pressure * 3)))`. Verify the inverse solution. Stars/par always use `round(colorCount * capacity * 0.9 + colorCount)`.
- Color Match v1: `roundCount = min(12, 3 + floor(pressure))`, `winningAverage = min(90, 55 + floor(pressure * 4))`, deterministic distinct RGB targets with saturation at least `max(.35, .65 - pressure * .03)`, lightness in `.25..75`, and hue separation at least `max(18, 60 - floor(pressure * 3))` degrees. Its normalized score is the rounded average round score.
- Every bounded generator must provide a deterministic valid fallback for its version; it must not loop forever or silently change an existing descriptor.

## File Structure

Create focused shared files:

- `lib/features/games/domain/game_id.dart`: stable game identity.
- `lib/features/games/domain/game_level.dart`: tier, pressure, descriptor, parsing.
- `lib/features/games/domain/deterministic_random.dart`: seed derivation, xorshift32, shuffle.
- `lib/features/games/domain/game_level_adapter.dart`: layout/outcome contracts and registry interface.
- `lib/features/games/domain/game_level_catalog.dart`: batches, collision handling, refill predicate.
- `lib/features/games/domain/game_launch.dart`: play kind, attempts, launch, completion receipt.
- `lib/features/games/domain/game_badge.dart`: milestone IDs and metadata.
- `lib/features/games/domain/player_profile.dart`: profile and per-game progress.
- `lib/features/games/domain/game_profiles_state.dart`: validated schema-v2 root and legacy snapshot.
- `lib/features/games/domain/game_progression_engine.dart`: pure profile/catalog/attempt/reward transitions.
- `lib/features/games/domain/game_leaderboard.dart`: derived rankings.
- `lib/features/games/domain/adapters/`: four native game adapters; Color Match adapter remains in its feature.
- `lib/features/games/domain/game_profiles_repository.dart`: atomic transition persistence contract.
- `lib/data/db/hive_game_profiles_repository.dart`: schema-v2 Hive store and v1 reader.
- `lib/features/games/application/game_adapter_registry.dart`: production adapter registry.
- `lib/features/games/application/game_profiles_provider.dart`: repository lifecycle, controller, derived providers.
- `lib/features/games/presentation/`: profile dialog/sheet, metadata, map, badges, leaderboard, and invalid-launch UI.
- `test/support/in_memory_game_profiles_repository.dart`: provider/widget-test repository.

Retain `game_progress.dart`, `game_difficulty.dart`, and the schema-v1 Hive box as migration/practice contracts. Modify the existing game domains/screens, Color Match, `games_screen.dart`, and `app_router.dart` only in their owning tasks.

## Exact Shared Interfaces

```dart
abstract interface class GameLevelAdapter {
  GameId get gameId;
  int get currentGeneratorVersion;
  bool supportsVersion(int version);
  GameLevelLayout build(GameLevelDescriptor descriptor);
  int normalizeScore(GameLevelOutcome outcome);
}

abstract interface class GameLevelAdapterRegistry {
  GameLevelAdapter adapterFor(GameId gameId);
}

final class GameLevelCatalog {
  List<GameLevelDescriptor> generateBatch({
    required String profileId,
    required GameId gameId,
    required int startLevel,
    required int count,
    required Map<int, GameLevelDescriptor> existingByLevel,
    required Set<String> existingFingerprints,
  });
  bool needsRefill({required int currentLevel, required int generatedThrough});
}

final class ProgressionChange<T> {
  final GameProfilesState state;
  final T value;
}

abstract interface class GameProfilesRepository {
  Future<GameProfilesState> loadState();
  Future<ProgressionChange<T>> transact<T>(
    ProgressionChange<T> Function(GameProfilesState current) transition,
  );
  Future<void> close();
}
```

`GameProgressionEngine` exposes pure `createProfile`, `renameProfile`, `deleteProfile`, `setActiveProfile`, `prepareGame`, `beginCurrentAttempt`, `beginReplayAttempt`, and `completeLevel` transitions. Every transition accepts the current `GameProfilesState`; time and new profile ID are explicit parameters. Attempt IDs are exactly `<profileId>:<gameId.storageId>:<monotonicSequence>`. `completeLevel` accepts a `GameLaunch`, normalized `0..100` score, and UTC completion time.

`GameProfilesController` mirrors those commands asynchronously; begin methods return `Future<GameLaunch>`, and `completeLevel(GameLaunch launch, GameLevelOutcome outcome)` returns `Future<LevelCompletionReceipt>`. It publishes the `ProgressionChange.state` only after the repository transaction is durable.

---

### Task 1: Stable identity, tiers, descriptors, and PRNG

**Files:**
- Create: `lib/features/games/domain/game_id.dart`
- Create: `lib/features/games/domain/game_level.dart`
- Create: `lib/features/games/domain/deterministic_random.dart`
- Create: `test/features/games/domain/game_level_test.dart`
- Create: `test/features/games/domain/deterministic_random_test.dart`

**Interfaces:**
- Produces: `GameId.storageId`, `GameId.parse(String)`, `GameTier.forLevel(int)`, `levelPressureFor(int)`, immutable `GameLevelDescriptor`, `StableRandom`, `deriveLevelSeed(...)`, and `stableShuffle<T>(...)`.

- [ ] Write failing tests for permanent game-ID round trips, unknown IDs, tier/reward boundaries at 1/9/10/19/20, monotonic finite pressure through Level 1,000,000,000, descriptor equality/map validation, and non-finite/invalid fields.
- [ ] Add literal stability fixtures: xorshift32 seed `1` yields `[270369, 67634689, 2647435461, 307599695, 2398689233]`; shuffling `[0,1,2,3,4,5]` with seed `1` yields `[0,5,2,1,4,3]`; the approved seed string for profile `profile-a`, Water Sort Level 1, retry 0 yields `3628656079`.
- [ ] Run `flutter test --no-pub test/features/games/domain/game_level_test.dart test/features/games/domain/deterministic_random_test.dart --reporter expanded`; expect RED for missing APIs.
- [ ] Implement the interfaces and strict map parsing without relying on enum indexes, `Random`, or `List.shuffle`.
- [ ] Re-run the focused tests; expect all PASS. Format owned files and inspect only their diff.

### Task 2: Adapter contracts and endless catalog

**Files:**
- Create: `lib/features/games/domain/game_level_adapter.dart`
- Create: `lib/features/games/domain/game_level_catalog.dart`
- Create: `test/features/games/domain/game_level_catalog_test.dart`

**Interfaces:**
- Consumes: Task 1 descriptor/PRNG contracts.
- Produces: sealed `GameLevelLayout`, sealed `GameLevelOutcome`, `GameLevelAdapter`, `GameLevelAdapterRegistry.adapterFor(GameId)`, `GameLevelCatalog.generateBatch(...)`, `needsRefill(...)`, and constants `initialBatchSize = 15`, `refillThreshold = 10`, `refillBatchSize = 15`.

- [ ] Write a fake-adapter test proving Levels 1–15 are ordered, Level 5 completion makes Level 6 trigger a 15-level append through 30, more than 10 remaining does not refill, and retrying the same append is idempotent by level number.
- [ ] Add collision tests where the fake adapter returns the same signature twice: retry salt and seed must change, historical fingerprints remain, and a bounded adapter failure returns a typed generation error without partial output.
- [ ] Run the catalog test; expect RED.
- [ ] Implement batch creation, full-SHA-256 fingerprints, version checks, and the pure refill predicate. Do not introduce profile storage yet.
- [ ] Re-run focused tests; expect PASS. Format and inspect the narrow diff.

### Task 3: Bubble Shooter generator-v1 adapter

**Files:**
- Create: `lib/features/games/domain/adapters/bubble_shooter_level_adapter.dart`
- Modify: `lib/features/games/domain/bubble_shooter_game.dart`
- Expand: `test/features/games/domain/bubble_shooter_game_test.dart`
- Create: `test/features/games/domain/adapters/bubble_shooter_level_adapter_test.dart`

**Interfaces:**
- Produces: `BubbleShooterLevelLayout`, `BubbleShooterOutcome`, `BubbleShooterLevelAdapter`, and `BubbleShooterGame.fromLayout(...)`; the game exposes `shotsFired`, `initialBubbleCount`, and uses the layout's stable runtime stream.

- [ ] Write failing fixtures at Levels 1/9/10/19/20/30/100/1,000,000 for the frozen bounds, identical descriptor regeneration, changed retry salt, canonical fingerprint input, clustered opening opportunity, and deterministic pressure-row/current-color sequence.
- [ ] Replay every candidate's bounded placement certificate through `landBubble` and assert the real domain clears; prove candidate search stops at 64 and the known-clear fallback is deterministic.
- [ ] Add normalization tests: at/below `parShots` is 100, twice par is 50, and raw display scores above 100 never escape the adapter.
- [ ] Run both Bubble tests; expect RED.
- [ ] Implement the version-1 layout builder, deterministic fallback, from-layout factory, shot counter, and normalized outcome while preserving collision/physics fixtures.
- [ ] Re-run focused tests; expect PASS. Format and inspect owned files.

### Task 4: Fruit Pop bounded adapter and playable blockers

**Files:**
- Create: `lib/features/games/domain/adapters/fruit_pop_level_adapter.dart`
- Modify: `lib/features/games/domain/fruit_pop_game.dart`
- Expand: `test/features/games/domain/fruit_pop_game_test.dart`
- Create: `test/features/games/domain/adapters/fruit_pop_level_adapter_test.dart`

**Interfaces:**
- Produces: `FruitPopLevelLayout`, `FruitPopOutcome`, `FruitPopLevelAdapter`, and `FruitPopGame.fromLayout(...)`; layouts contain initial board, blocker indices, target, move budget, par, type count, and refill seed.

- [ ] Write failing tests for all boundary levels, stable board/refills, no initial matches, at least one legal move, blocker-aware swap/match/gravity segments, 64-candidate/16-simulation/30-move bounds, and the “at least 8 simulated wins” acceptance rule.
- [ ] Add fallback and normalization fixtures, including a raw cascade score above 100 and a twice-par win normalizing to 50.
- [ ] Run both Fruit tests; expect RED.
- [ ] Implement blocker-safe mechanics and the deterministic greedy simulator/layout builder. Preserve current swipe and cascade semantics for unblocked cells.
- [ ] Run Fruit domain, adapter, and `fruit_pop_swipe_test.dart`; expect PASS. Format and inspect owned files.

### Task 5: Solvable Water Sort reverse generator

**Files:**
- Create: `lib/features/games/domain/adapters/water_sort_level_adapter.dart`
- Modify: `lib/features/games/domain/water_sort_game.dart`
- Expand: `test/features/games/domain/water_sort_game_test.dart`
- Create: `test/features/games/domain/adapters/water_sort_level_adapter_test.dart`

**Interfaces:**
- Produces: `WaterSortLevelLayout`, `WaterSortMove`, `WaterSortOutcome`, `WaterSortLevelAdapter`, and `WaterSortGame.fromLayout(...)`; layout exposes a test-only immutable inverse solution and `parMoves`.

- [ ] Write failing boundary/fixture tests for color/depth caps, exact descriptor regeneration, non-won starts, four units per color, two empty tubes, and canonical initial signatures.
- [ ] For every boundary fixture, replay the adapter's inverse solution through the real `canPour/pour` API and assert `isWon`; add bounded-failure/fallback and 100/50 normalization cases.
- [ ] Run Water domain/adapter tests; expect RED.
- [ ] Implement deterministic reverse-split scrambling, inverse validation, fallback, and from-layout construction without changing pour/undo/restart contracts.
- [ ] Run Water tests plus `water_pour_motion_test.dart` and `game_audio_test.dart`; expect PASS and unchanged pour-audio behavior. Format and inspect owned files.

### Task 6: Solvable Rainbow Rings generator-v1 adapter

**Files:**
- Create: `lib/features/games/domain/adapters/rainbow_rings_level_adapter.dart`
- Modify: `lib/features/games/domain/rainbow_rings_game.dart`
- Expand: `test/features/games/domain/rainbow_rings_game_test.dart`
- Create: `test/features/games/domain/adapters/rainbow_rings_level_adapter_test.dart`

**Interfaces:**
- Produces: `RainbowRingsLevelLayout`, `RainbowRingsMoveOutcome`, `RainbowRingsLevelAdapter`, and `RainbowRingsGame.fromLayout(...)`; generation remains separate from the later animation action-result API.

- [ ] Write failing boundary tests for color/capacity/depth caps, two empty pegs, exact regeneration/fingerprint input, mixed starts, inverse solution replay, and deterministic fallback.
- [ ] Pin literal `parMoves` fixtures and normalization at par/2× par; prove level pressure changes puzzle generation but never changes the par formula.
- [ ] Run Rainbow domain/adapter tests; expect RED.
- [ ] Implement reverse one-ring scrambling, inverse verification, fallback, and from-layout construction while keeping current tap/undo presentation compatible.
- [ ] Re-run focused tests; expect PASS. Format and inspect owned files.

### Task 7: Color Match level rules without breaking Lab practice

**Files:**
- Create: `lib/features/color_test/domain/color_match_level_adapter.dart`
- Modify: `lib/core/color/color_matching.dart`
- Modify: `lib/features/color_test/domain/matching_game.dart`
- Modify: `lib/features/color_test/application/matching_game_controller.dart`
- Expand: `test/core/color/color_matching_test.dart`
- Expand: `test/features/color_test/domain/matching_game_test.dart`
- Expand: `test/features/color_test/application/matching_game_controller_test.dart`
- Create: `test/features/color_test/domain/color_match_level_adapter_test.dart`

**Interfaces:**
- Produces: `MatchingRules(roundCount, winningAverage)`, `ColorMatchLevelLayout`, `ColorMatchOutcome`, and `ColorMatchLevelAdapter`. `MatchingGame.start` accepts explicit rules; existing practice helpers translate `GameDifficulty` to the same old 3/5/8 and 55/65/75 values.

- [ ] Write failing adapter fixtures for every boundary level, target uniqueness/ranges/minimum hue separation, identical regeneration, version rejection, and average-score normalization.
- [ ] Add regression tests proving the default retained Lab game still has five rounds/65 threshold and all existing practice restart/start behavior remains unchanged.
- [ ] Run the four focused test files; expect RED only for the new contract.
- [ ] Implement rules decoupling and deterministic target generation; do not add profile persistence or alter `MatchingScreen` yet.
- [ ] Re-run focused tests; expect PASS. Format and inspect the shared Color Match diff carefully.

### Task 8: Profile, progress, attempt, badge, and root-state models

**Files:**
- Modify: `pubspec.yaml`
- Modify: `pubspec.lock`
- Create: `lib/features/games/domain/game_launch.dart`
- Create: `lib/features/games/domain/game_badge.dart`
- Create: `lib/features/games/domain/player_profile.dart`
- Create: `lib/features/games/domain/game_profiles_state.dart`
- Create: `test/features/games/domain/player_profile_test.dart`
- Create: `test/features/games/domain/game_profiles_state_test.dart`

**Interfaces:**
- Produces: `GamePlayKind`, `ActiveGameAttempt`, immutable `GameLaunch`, persisted `LevelCompletionReceipt`, `GameBadge`, `PlayerGameProgress`, `PlayerProfile`, `LegacyGameProgressSnapshot`, and schema-v2 `GameProfilesState`.

- [ ] Add direct `characters: 1.4.1` dependency, then write failing model tests for `A👩🏽‍🎨` as two graphemes, trimmed names, 1/21-character rejection, control-character rejection, and case-insensitive uniqueness keys.
- [ ] Test immutable collections, strict nested map round trips, UTC timestamps, unknown IDs/versions, duplicate descriptor levels/fingerprints, invalid score/range combinations, and active-profile referential integrity.
- [ ] Pin legacy decoding of the exact existing schema-v1 map, including global best score as profile-wide only.
- [ ] Run model tests; expect RED.
- [ ] Implement models and validators, run `flutter pub get` only if the lockfile cannot resolve the already-cached package, then re-run tests. Expect PASS; format and inspect dependency/model diffs.

### Task 9: Pure progression engine and leaderboard

**Files:**
- Create: `lib/features/games/domain/game_progression_engine.dart`
- Create: `lib/features/games/domain/game_leaderboard.dart`
- Create: `test/features/games/domain/game_progression_engine_test.dart`
- Create: `test/features/games/domain/game_leaderboard_test.dart`

**Interfaces:**
- Consumes: Tasks 2–8.
- Produces: `ProgressionChange<T>`, typed `GameProgressionException`, pure profile CRUD/switch/prepare/begin/complete transitions, `LeaderboardEntry`, `overallLeaderboard(...)`, and `gameLeaderboard(...)`.

- [ ] Write failing profile tests for create/rename/delete/switch, first-profile legacy import exactly once, independent per-profile/per-game state, and active-profile deletion selecting the earliest-created remaining profile.
- [ ] Write catalog tests proving lazy 1–15 preparation, first-clear Level 5 advances to 6 and requests append through 30, repeated preparation is idempotent, and a failed refill leaves completion/reward/current descriptor intact and retryable from the derived threshold.
- [ ] Write attempt/reward tests: begin increments plays once; replacement abandons the old attempt; fail/exit never advances; duplicate completion returns the stored receipt with `alreadyApplied`; newer-attempt callbacks are stale; replay gets a new ID, can improve score, and earns zero rewards; Levels 20/40/60 award stable per-game badges once.
- [ ] Add concurrent-transition order fixtures and leaderboard tests for overall first-clears then coins then normalized name, per-game highest completed then coins then name, zero-score profiles, and active highlight identity.
- [ ] Run both tests; expect RED. Implement pure transitions and ranking, then re-run; expect PASS. Format and inspect owned files.

### Task 10: Atomic repository contract and in-memory test store

**Files:**
- Create: `lib/features/games/domain/game_profiles_repository.dart`
- Create: `test/support/in_memory_game_profiles_repository.dart`
- Create: `test/features/games/domain/game_profiles_repository_contract_test.dart`

**Interfaces:**
- Produces: `GameProfilesRepository.loadState()`, generic serialized `transact<T>(ProgressionChange<T> Function(GameProfilesState))`, `close()`, and reusable contract tests. The in-memory implementation exposes gates/failures for provider tests.

- [ ] Write the repository contract test for re-reading current durable state on every transaction, no write after a thrown transition, serialized overlapping transactions, rejected work after close, and publishing result only with its new state.
- [ ] Run the contract test; expect RED.
- [ ] Implement the interface and in-memory store only; do not write Hive yet.
- [ ] Re-run; expect PASS. Format and inspect owned files.

### Task 11: Hive schema-v2 durability and schema-v1 migration

**Files:**
- Create: `lib/data/db/hive_game_profiles_repository.dart`
- Create: `test/data/db/hive_game_profiles_repository_test.dart`
- Create: `test/data/db/hive_game_profiles_migration_test.dart`

**Interfaces:**
- Consumes: Tasks 8–10 and legacy `GameProgress.fromMap`.
- Produces: `HiveGameProfilesRepository.open(directory:, boxName: 'game_profiles_v2', legacyBoxName: 'game_progress_v1')` and `fromBoxes(...)` for boundary injection.

- [ ] Write real-temp-directory close/reopen tests for the full nested state, active attempt/latest receipt, all descriptors/fingerprints, badges, profile order, and a refill-threshold state.
- [ ] Write migration tests for absent legacy data, exact one-time import into the first profile, restart before/after import, retained legacy box, and global best not attached to a game.
- [ ] Add malformed v1/v2 and unsupported-version tests proving load and transact fail without overwriting bytes; add write/flush/close gates for serialization, failed flush recovery, and retryable close across both boxes.
- [ ] Run both Hive files; expect RED.
- [ ] Implement with a private `HiveImpl`, root key `state`, serialized operations, validation before mutation, and flush-before-success. Re-run; expect PASS. Format and inspect only new persistence files/tests.

### Task 12: Riverpod adapter registry and profile controller

**Files:**
- Create: `lib/features/games/application/game_adapter_registry.dart`
- Create: `lib/features/games/application/game_profiles_provider.dart`
- Create: `test/features/games/application/game_profiles_provider_test.dart`

**Interfaces:**
- Produces: production registry for all five IDs; directory/repository/clock/profile-ID providers; `gameProfilesProvider`; derived active-profile/per-game/leaderboard providers; controller methods `createProfile`, `renameProfile`, `deleteProfile`, `setActiveProfile`, `prepareGame`, `beginCurrentAttempt`, `beginReplayAttempt`, and `completeLevel(GameLaunch, GameLevelOutcome)`.

- [ ] Write provider tests for lifecycle/open/close, injected IDs/times, durable-before-publish behavior, queued mutations using the newest state, load/write failure retry, and disposal rejecting queued/late work.
- [ ] Add completion tests proving score normalization comes from the launch's registered adapter, wrong outcome/game pairs fail, refill is attempted after the committed receipt, refill failure does not erase the committed reward, and a current prepared launch still succeeds.
- [ ] Run the provider test; expect RED.
- [ ] Implement the registry/controller using repository transactions and pure engine transitions. Preserve last good `AsyncData`; surface command failures to callers rather than claiming success.
- [ ] Re-run; expect PASS. Format and inspect owned files.

### Task 13: Profile gate, management, and Games hub

**Files:**
- Create: `lib/features/games/presentation/game_ui_metadata.dart`
- Create: `lib/features/games/presentation/player_profile_dialog.dart`
- Create: `lib/features/games/presentation/profile_management_sheet.dart`
- Modify: `lib/features/games/presentation/games_screen.dart`
- Create: `test/features/games/presentation/games_screen_test.dart`
- Create: `test/features/games/presentation/profile_management_sheet_test.dart`

**Interfaces:**
- Consumes: Task 12 controller/providers.
- Produces: required first-profile UI, active-profile chip, create/switch/rename/delete flows, and five cards with current level/tier/completed count/next badge plus Play/Resume and Map callbacks.

- [ ] Write widget tests for loading/error/retry, no-profile gate, validation/duplicate names, remembered active profile, switching all visible stats, confirmed deletion, and deletion of the last profile returning to creation.
- [ ] Assert all difficulty bottom sheets and the Color Match `games-level-grid` are absent; Play awaits a durable `GameLaunch` before invoking navigation and shows recoverable errors without navigating.
- [ ] Cover 360 dp width, 2× text, light/dark themes, semantics, and profile-wide Coins/Wins/Best display.
- [ ] Run both presentation tests; expect RED.
- [ ] Implement the focused widgets and refactor the hub without changing routes yet. Re-run; expect PASS. Format and inspect `games_screen.dart` carefully.

### Task 14: Level map, badges, and local leaderboard UI

**Files:**
- Create: `lib/features/games/presentation/game_level_map_screen.dart`
- Create: `lib/features/games/presentation/badges_screen.dart`
- Create: `lib/features/games/presentation/leaderboard_screen.dart`
- Create: `test/features/games/presentation/game_level_map_screen_test.dart`
- Create: `test/features/games/presentation/badges_screen_test.dart`
- Create: `test/features/games/presentation/leaderboard_screen_test.dart`

**Interfaces:**
- Produces: shared map callbacks returning current/replay `GameLaunch`, milestone state, badge gallery, and Overall/per-game leaderboard filters.

- [ ] Write map tests for completed/check/score/replay, highlighted current Play, locked generated future levels, initial 1–15 display, appended through 30, milestone nodes, and no difficulty selection.
- [ ] Write badge tests for per-game 20/40/60 earned/locked labels and leaderboard tests for exact sorting, zero profiles, all six filters, ties, and active-profile highlighting.
- [ ] Add narrow/large-text/dark/semantics cases and command-failure UI that does not navigate.
- [ ] Run the three tests; expect RED.
- [ ] Implement screens using derived state only; do not persist ranking rows. Re-run; expect PASS. Format and inspect owned files.

### Task 15: Bubble Shooter and Fruit Pop launch integration

**Files:**
- Modify: `lib/features/games/presentation/bubble_shooter_screen.dart`
- Modify: `lib/features/games/presentation/fruit_pop_screen.dart`
- Create: `test/features/games/presentation/bubble_shooter_screen_test.dart`
- Create: `test/features/games/presentation/fruit_pop_screen_test.dart`

**Interfaces:**
- Consumes: `GameLaunch`, concrete adapters, and Task 12 commands.
- Produces: `BubbleShooterScreen({required GameLaunch launch})` and `FruitPopScreen({required GameLaunch launch})`.

- [ ] Write widget tests that both screens build the descriptor layout, show persisted level/tier, expose Map, and begin a new attempt for Retry/Restart rather than reusing the old attempt ID.
- [ ] Test loss leaves current level unchanged; win awaits durable completion before reward copy; duplicate receipts suppress coin/badge celebration; Next Level requests the newly persisted current launch; storage failure keeps retry available.
- [ ] Add a raw Bubble/Fruit score regression proving only adapter-normalized `0..100` reaches completion.
- [ ] Run focused screen/domain tests; expect RED.
- [ ] Refactor both screens while preserving gameplay/audio/swipe behavior. Re-run; expect PASS. Format and inspect owned files.

### Task 16: Water Sort and baseline Rainbow Rings launch integration

**Files:**
- Modify: `lib/features/games/presentation/water_sort_screen.dart`
- Modify: `lib/features/games/presentation/rainbow_rings_screen.dart`
- Create: `test/features/games/presentation/water_sort_screen_test.dart`
- Create: `test/features/games/presentation/rainbow_rings_progression_test.dart`

**Interfaces:**
- Produces: `WaterSortScreen({required GameLaunch launch})` and the baseline `RainbowRingsScreen({required GameLaunch launch})` consumed by the later animation plan.

- [ ] Write the same launch/restart/replay/persistence/Next Level assertions as Task 15, plus proof that an older replay win does not advance current level.
- [ ] For Water, retain visual pour duration and `GameAudio.playWaterPour(amount)`; for Rainbow, retain current immediate painter/actions until the animation plan.
- [ ] Run focused screens, domain tests, `water_pour_motion_test.dart`, and `game_audio_test.dart`; expect RED for launch integration only.
- [ ] Refactor both screens to adapter layouts and durable receipts; never locally increment `_game.level`.
- [ ] Re-run; expect PASS. Format and inspect the high-conflict Rainbow file before the next plan.

### Task 17: Color Match dual practice/profile sessions

**Files:**
- Modify: `lib/features/color_test/application/matching_game_controller.dart`
- Modify: `lib/features/color_test/presentation/matching_screen.dart`
- Expand: `test/features/color_test/application/matching_game_controller_test.dart`
- Expand: `test/features/color_test/presentation/matching_integration_test.dart`

**Interfaces:**
- Produces: retained Lab `matchingGameProvider`, auto-disposed profile-session family keyed by attempt ID, and `MatchingScreen({GameLaunch? launch})`; null launch always means practice.

- [ ] Write tests proving Lab reopens its retained practice state, a Games launch uses deterministic layout/rules in an isolated provider, and practice completion cannot call profile persistence.
- [ ] Test profile win/loss threshold, durable success/error/retry, duplicate receipt suppression, Replay/Next attempt replacement, and stale launch rejection.
- [ ] Run Color Match application/domain/presentation tests; expect RED.
- [ ] Implement explicit mode selection and remove `rewardDifficulty`; preserve current Lab copy, controls, and accessibility.
- [ ] Re-run all `test/features/color_test` tests plus the three provider-isolation regression files named in the spec mapping; expect PASS. Format and inspect shared files.

### Task 18: Typed routes and end-to-end Games flow

**Files:**
- Modify: `lib/routing/app_router.dart`
- Create: `lib/features/games/presentation/invalid_game_launch_screen.dart`
- Create: `test/features/games/presentation/games_integration_test.dart`
- Expand: `test/widget_test.dart`

**Interfaces:**
- Consumes: final constructors from Tasks 13–17.
- Produces: play routes accepting only matching `GameLaunch`; `/matching` without extra remains practice; `/games/:gameId/map`, `/games/badges`, and `/games/leaderboard`.

- [ ] Write router tests for every valid game launch, mismatched/missing/wrong-type extras, unknown map IDs, direct Lab practice, Map replay, Back behavior, and no silent Easy fallback.
- [ ] Add an end-to-end two-profile test: independent levels/catalogs, app/provider restart resumes each current level, replay has no reward, local overall/per-game rankings update, and switching profile makes an open old launch stale.
- [ ] Add migration UI coverage showing imported aggregate stats in the first named profile while every game begins at Level 1.
- [ ] Run the integration/widget tests; expect RED.
- [ ] Implement routes and navigation callbacks, then run all Games/Color Match tests; expect PASS. Format and inspect `app_router.dart` without disturbing unrelated user edits.

### Task 19: Full verification and handoff evidence

**Files:**
- Modify only if a failing verification exposes an in-scope defect.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: evidence that the progression feature is ready for the separate Rainbow animation plan.

- [ ] Run `dart format --output=none --set-exit-if-changed lib test`; expect exit 0.
- [ ] Run `flutter analyze --no-pub`; expect `No issues found!`.
- [ ] Run `flutter test --no-pub --reporter expanded`; expect all tests PASS. Diagnose any failure before changing code; do not weaken unrelated assertions.
- [ ] Run `flutter build apk --debug --no-pub` and `flutter build ios --simulator --debug --no-codesign --no-pub`; expect both builds to succeed.
- [ ] Manually smoke-test create/switch/rename/delete, close/reopen resume, Level 5 refill through 30, first-clear/replay/badge behavior, maps, both leaderboards, five game launches, Lab practice isolation, sound/haptics, and 360 dp/2× text. Record any device-only item not actually exercised.
- [ ] Inspect `git status --short` and narrow diffs. Confirm no unrelated user file was reset, no supplied HTML was modified, and no commit/push occurred.
