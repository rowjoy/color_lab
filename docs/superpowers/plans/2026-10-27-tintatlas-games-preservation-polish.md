# TintAtlas Games Preservation and Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve every current game identity and reward while repairing the baseline, adding durable interrupted-level recovery, accessible first-play guidance and preferences, and focused polish for Bubble Shooter, Fruit & Veggie Pop, Water Sort, Rainbow Rings, and Color Match.

**Architecture:** Keep the existing game-profile repository and progression engine as the only writers of profile-owned state. Extend `PlayerProfile` and `ActiveGameAttempt` through explicit migrations, use strict versioned per-game session codecs, and have each screen persist only at committed-action boundaries. Shared Learning/Coloring/Room libraries remain outside profiles.

**Tech Stack:** Flutter Material 3/CustomPainter, Riverpod, GoRouter, Hive, existing deterministic game engines/adapters/audio, generated Flutter localization, Flutter unit/widget/integration tests.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md` (GAME-01–13)

## Global Constraints

- Read the master and Foundation plans first; do not begin feature changes until current game failures are reproduced and classified.
- Preserve exactly these storage IDs: `bubbleShooter`, `fruitPop`, `waterSort`, `rainbowRings`, and `colorMatch`. Preserve descriptor fingerprints, generator versions, generated/cleared levels, receipts, badges, coins, leaderboards, and first-clear rules.
- Coloring Studio is a creative hub card, not a sixth `GameId`; Match the Picture is not part of v1.
- Game profiles own only game attempts, levels, rewards, leaderboard values, tutorials, and game preferences. Profile switching/deletion cannot hide or delete Rooms, Learning, Coloring, saved colors, or palettes.
- Active gameplay is ad-free. The later ads plan may use only the Games hub or a fully settled result.
- Non-color cues, semantics, keyboard alternatives, reduced motion, and lifecycle recovery are functional requirements, not optional decoration.
- A failed session save leaves the current game playable, announces that progress is not saved, and offers Retry; stale writes never replace newer profile state.

## Review Focus

- v1 profile/attempt fixtures migrate exactly once and retain every ID, fingerprint, reward, statistic, badge, and leaderboard entry.
- Session restore recreates a stable logical turn without replaying an animation, sound, celebration, reward, or completed receipt.
- Bubble/Water/Rainbow state is understandable without hue alone; canvas-heavy games expose a practical semantic/keyboard path.
- Determinism, bounded hint search, lifecycle transitions, and concurrent profile changes cannot award twice or corrupt another profile.
- Baseline test repairs reflect accepted behavior and are not blanket snapshot updates that conceal a regression.

---

### Task 1: Verify and freeze the repaired game baseline

**Files:**
- Consume unchanged after the Foundation gate: current product/test paths listed under `baselineFailureFiles` in `docs/release/verification-ledger.md`
- Modify only if the Foundation evidence is invalidated by a reproduced GAME-05 defect: the exact owning path added to a reviewed ledger amendment before editing
- Modify: `docs/release/verification-ledger.md`

**Interfaces:**
- Produces a per-failure record containing test name, expected/observed behavior, root cause, accepted contract, changed file, and passing focused command.
- Freezes the five enum names/storage IDs and current level-adapter fingerprints before any schema change.

- [ ] **Step 1: Run every failing game/profile file from the recorded `+1527 -38` baseline separately with expanded output.** Record pump timeouts, selector mismatches, progression mismatches, and product defects independently.
- [ ] **Step 2: Add the five storage IDs, representative existing profile fixtures, descriptor fingerprints, and reward receipts to immutable regression tests before fixes.** Expected: current compatibility tests PASS.
- [ ] **Step 3: Confirm each Foundation repair against the accepted contract.** If a GAME-05 defect remains, amend the ledger and fix one reproduced root cause at a time; change a test only when the approved spec intentionally replaces its old expectation, documenting why.
- [ ] **Step 4: Run `flutter test --no-pub test/features/games test/features/color_test test/data/db/hive_game_profiles_repository_test.dart --reporter expanded`.** Expected: PASS before new schema/features begin.
- [ ] **Step 5: Confirm the Foundation fix for `lib/features/games/presentation/fruit_pop_screen.dart:1048` and run scoped analyze/format.** Expected: clean; do not re-edit a passing path.
- [ ] **Step 6: Commit.** `git commit -m "fix: stabilize existing game baseline"`.

### Task 2: Add game preferences with lossless profile migration

**Files:**
- Create: `lib/features/games/domain/game_preferences.dart`
- Create: `test/features/games/domain/game_preferences_test.dart`
- Modify: `lib/features/games/domain/player_profile.dart`
- Modify: `lib/features/games/domain/game_profiles_state.dart`
- Modify: `lib/data/db/hive_game_profiles_repository.dart`
- Modify: `lib/data/schema/schema_registry.dart`
- Modify: `docs/release/schema-registry.md`
- Modify: `test/features/games/domain/player_profile_test.dart`
- Modify: `test/features/games/domain/game_profiles_state_test.dart`
- Modify: `test/data/db/hive_game_profiles_migration_test.dart`

**Interfaces:**

```dart
final class GamePreferences {
  final bool soundEnabled;
  final bool musicEnabled;
  final bool hapticsEnabled;
  final Set<GameId> completedTutorials;
}
```

Add `GamePreferences preferences` to `PlayerProfile` and migrate nested profile schema v1→v2. `GameProfilesState` may remain schema v2 only if its strict decoder migrates each nested profile and the repository durably rewrites the migrated state before declaring success.

Keep the `game_profiles_v2` Hive storage name and root schema version fixed unless the root wire shape changes; record nested `PlayerProfile` version 2 explicitly in the schema registry notes.

- [ ] **Step 1: Write RED v1 fixture tests.** Assert all old fields, descriptors, fingerprints, attempts, receipts, coins, badges, leaderboard rows, and active profile survive; new preferences take safe defaults.
- [ ] **Step 2: Write RED strict v2 tests.** Reject invalid booleans, unknown tutorial IDs/keys, duplicate IDs, and future versions without deleting the raw record.
- [ ] **Step 3: Run the three migration/domain test files.** Expected: FAIL only for the new schema cases.
- [ ] **Step 4: Implement v2 serialization/copy/equality and durable load-time rewrite with flush.** Failed rewrite exposes a recoverable error and leaves the v1 bytes intact.
- [ ] **Step 5: Rerun migration/repository/domain suites and compare every legacy field.** Expected: PASS.
- [ ] **Step 6: Commit.** `git commit -m "feat: migrate durable game preferences"`.

### Task 3: Add shared tutorials, controls, and lifecycle UI

**Files:**
- Create: `lib/features/games/presentation/game_tutorial_sheet.dart`
- Create: `lib/features/games/presentation/game_lifecycle_scope.dart`
- Create: `test/features/games/presentation/game_tutorial_sheet_test.dart`
- Create: `test/features/games/presentation/game_lifecycle_scope_test.dart`
- Modify: `lib/features/games/application/game_profiles_provider.dart`
- Modify: `lib/features/games/application/game_audio.dart`
- Modify: `lib/features/settings/presentation/settings_sheet.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**

```dart
Future<PlayerProfile> updateGamePreferences(GamePreferences preferences);
Future<PlayerProfile> markTutorialCompleted(GameId gameId);
```

`GameLifecycleScope` reports background/resume, requests a committed-state save, pauses clocks/audio, and exposes restart confirmation; it does not serialize an in-flight gesture/animation frame.

- [ ] **Step 1: Write RED tests.** Cover first launch, Skip, completion, replay from settings/help, profile independence, sound/music/haptic persistence, reduced-motion override, tooltip/semantics copy, restart confirmation, and app background/resume.
- [ ] **Step 2: Run focused tutorial/lifecycle/provider/audio tests.** Expected: FAIL.
- [ ] **Step 3: Implement the shared components and profile-controller methods.** A tutorial acknowledgement is persisted before dismissal; controls affect only the active profile except app-level reduced motion.
- [ ] **Step 4: Run at 320×568, 568×320, 200% text, RTL, keyboard, screen-reader semantics, and dark/high contrast.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: standardize game guidance and controls"`.

### Task 4: Add a strict persisted-session contract

**Files:**
- Create: `lib/features/games/domain/persisted_game_session.dart`
- Create: `lib/features/games/application/game_session_registry.dart`
- Create: `test/features/games/domain/persisted_game_session_test.dart`
- Create: `test/features/games/application/game_session_registry_test.dart`
- Modify: `lib/features/games/domain/game_launch.dart`
- Modify: `lib/features/games/domain/game_progression_engine.dart`
- Modify: `lib/features/games/application/game_profiles_provider.dart`
- Modify: `lib/features/games/domain/deterministic_random.dart`
- Modify: `test/features/games/domain/game_progression_engine_test.dart`
- Modify: `test/features/games/application/game_profiles_provider_test.dart`
- Modify: `test/features/games/domain/deterministic_random_test.dart`
- Modify: `test/data/db/hive_game_profiles_migration_test.dart`

**Interfaces:**

```dart
final class PersistedGameSession {
  final GameId gameId;
  final int codecVersion;
  final Map<String, Object?> payload;
  final DateTime updatedAt;
}

ProgressionChange<ActiveGameAttempt> saveSession({required GameProfilesState state, required GameLaunch launch, required PersistedGameSession session, required DateTime updatedAt});
Future<void> saveSession({required GameLaunch launch, required PersistedGameSession session});
```

Add `PersistedGameSession? session` to `ActiveGameAttempt` with explicit v1→v2 migration. `StableRandom` exposes validated `int get state` and `StableRandom.fromState(int state)` so resumed games continue the same stream.

- [ ] **Step 1: Write RED schema/engine tests.** Cover exact keys, v1 attempt migration, game/attempt/profile/fingerprint mismatch, stale launch/write rejection, future codec version, PRNG sequence restoration, concurrent profiles, and flush failure.
- [ ] **Step 2: Run launch/progression/provider/repository/random tests.** Expected: FAIL for new behavior.
- [ ] **Step 3: Implement the generic container, registry interface, engine/controller transaction, and deterministic random state.** Do not decode a per-game payload in the generic model.
- [ ] **Step 4: Rerun tests and prove an invalid session cannot mutate profile state or award rewards.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: persist interrupted game sessions"`.

### Task 5: Persist and polish Bubble Shooter

**Files:**
- Create: `lib/features/games/domain/sessions/bubble_shooter_session_codec.dart`
- Create: `lib/features/games/domain/game_color_cue.dart`
- Create: `test/features/games/domain/sessions/bubble_shooter_session_codec_test.dart`
- Modify: `lib/features/games/domain/bubble_shooter_game.dart`
- Modify: `lib/features/games/presentation/bubble_shooter_painter.dart`
- Modify: `lib/features/games/presentation/bubble_shooter_screen.dart`
- Modify: `test/features/games/domain/bubble_shooter_game_test.dart`
- Modify: `test/features/games/presentation/bubble_shooter_screen_test.dart`
- Create: `test/features/games/presentation/bubble_shooter_painter_test.dart`

**Interfaces:**
- Codec v1 stores board, current/next bubble, score, shot/drop counters, and PRNG state only after a shot settles.
- `GameColorCue` maps each logical color to a stable symbol/pattern plus localized label across Bubble, Water, and Rainbow.

- [ ] **Step 1: Write RED codec/reopen tests.** Round-trip before/after bank bounce, reject malformed grids/colors, restore exact next random sequence, and never restore a half-flight animation.
- [ ] **Step 2: Write RED fairness/accessibility tests.** Next bubble must come from active board colors when possible; trajectory/bounce preview stays clear; symbols/patterns and aim/fire/swap semantic controls identify state without hue.
- [ ] **Step 3: Implement codec, settled-action save/retry, lifecycle restore, cues, and accessible alternative while preserving existing trajectory and next-bubble behavior.**
- [ ] **Step 4: Run all Bubble tests, painter image checks, reduced-motion and background/resume cases.** Expected: PASS with no duplicate reward/sound.
- [ ] **Step 5: Commit.** `git commit -m "feat: preserve and polish Bubble Shooter"`.

### Task 6: Persist and polish Fruit & Veggie Pop

**Files:**
- Create: `lib/features/games/domain/sessions/fruit_pop_session_codec.dart`
- Create: `test/features/games/domain/sessions/fruit_pop_session_codec_test.dart`
- Modify: `lib/features/games/domain/fruit_pop_game.dart`
- Modify: `lib/features/games/presentation/fruit_pop_screen.dart`
- Modify: `lib/features/games/presentation/fruit_pop_swipe.dart`
- Modify: `test/features/games/domain/fruit_pop_game_test.dart`
- Modify: `test/features/games/presentation/fruit_pop_screen_test.dart`
- Modify: `test/features/games/presentation/fruit_pop_swipe_test.dart`

**Interfaces:**
- Codec v1 stores board, score, moves remaining, stable random state, and objective progress after a cascade/shuffle settles; transient swipe/cascade frames are omitted.

- [ ] **Step 1: Write RED round-trip/determinism tests.** Cover move, cascade, no-move auto-shuffle, reward result, corrupt board, restart, and identical continuation after reopen.
- [ ] **Step 2: Write RED interaction tests.** Goals/moves/board status are explicit; swipe and tap commit equivalent moves; keyboard cell selection works; unreliable diagonal swipe is a no-op with feedback.
- [ ] **Step 3: Implement codec, committed-action save/retry, lifecycle restore, and accessible board status while preserving current move detection/auto-shuffle.**
- [ ] **Step 4: Run all Fruit tests at reduced motion, background/resume, compact landscape, and 200% text.** Expected: PASS with one deterministic reward.
- [ ] **Step 5: Commit.** `git commit -m "feat: preserve and polish Fruit Pop"`.

### Task 7: Persist and polish Water Sort with a bounded free hint

**Files:**
- Create: `lib/features/games/domain/sessions/water_sort_session_codec.dart`
- Create: `lib/features/games/domain/water_sort_hint_solver.dart`
- Create: `test/features/games/domain/sessions/water_sort_session_codec_test.dart`
- Create: `test/features/games/domain/water_sort_hint_solver_test.dart`
- Modify: `lib/features/games/domain/water_sort_game.dart`
- Modify: `lib/features/games/presentation/water_sort_painter.dart`
- Modify: `lib/features/games/presentation/water_sort_screen.dart`
- Modify: `test/features/games/domain/water_sort_game_test.dart`
- Modify: `test/features/games/presentation/water_sort_screen_test.dart`
- Modify: `test/features/games/presentation/water_pour_motion_test.dart`

**Interfaces:**

```dart
Iterable<WaterSortMove> get legalMoves;
WaterSortGame copyForSimulation();
WaterSortMove? suggestWaterSortMove(WaterSortGame game, {int maxVisitedStates = 25000});
```

Codec v1 stores tubes, multi-step move history, move count, and stable generator identity after a pour settles; selection/animation is omitted.

- [ ] **Step 1: Write RED solver tests.** Prove returned moves are legal and lie on a solution path for fixed fixtures; enforce the visit bound; return null rather than claim certainty when no proof is found; never mutate the live game.
- [ ] **Step 2: Write RED session/interaction tests.** Cover multi-step Undo, restart confirmation, impossible-state defense, patterns/labels, semantic tube selection/pour, stable animation, save failure/retry, and reopen.
- [ ] **Step 3: Implement simulation copy/legal moves/bounded solver, codec, cues, semantic controls, and lifecycle restore.** Hint is free and never described as guaranteed unless the bounded search proved a path.
- [ ] **Step 4: Run all Water tests including background mid-animation, reduced motion, and deterministic progression.** Expected: PASS without duplicate pours/rewards.
- [ ] **Step 5: Commit.** `git commit -m "feat: preserve and polish Water Sort"`.

### Task 8: Persist and polish Rainbow Rings

**Files:**
- Create: `lib/features/games/domain/sessions/rainbow_rings_session_codec.dart`
- Create: `test/features/games/domain/sessions/rainbow_rings_session_codec_test.dart`
- Modify: `lib/features/games/domain/rainbow_rings_game.dart`
- Modify: `lib/features/games/presentation/rainbow_rings_painter.dart`
- Modify: `lib/features/games/presentation/rainbow_rings_screen.dart`
- Modify: `lib/features/games/presentation/rainbow_rings_animation.dart`
- Modify: `test/features/games/domain/rainbow_rings_game_test.dart`
- Modify: `test/features/games/presentation/rainbow_rings_painter_test.dart`
- Modify: `test/features/games/presentation/rainbow_rings_screen_test.dart`
- Modify: `test/features/games/presentation/rainbow_rings_animation_test.dart`
- Modify: `test/features/games/presentation/rainbow_rings_progression_test.dart`

**Interfaces:**
- Codec v1 stores stacks, move history, move count, descriptor identity, and stable generation state after a move settles; selection, animation clock, audio, and celebration are omitted.

- [ ] **Step 1: Write RED round-trip/lifecycle tests.** Cover exact stacks/history, stable next move, pause/background/resize, corrupt payload, settled win, and restore without stale celebration/audio.
- [ ] **Step 2: Write RED non-color tests.** Pattern/symbol identity appears on rings, selection preview, semantic labels, and high-contrast focus while preserving existing Hint/Undo/keyboard flow.
- [ ] **Step 3: Implement codec/save/retry/restore and shared cues without replacing the existing animation clock or progression system.**
- [ ] **Step 4: Run all Rainbow tests, especially current resize/lifecycle/animation regressions.** Expected: PASS with deterministic progression and one result receipt.
- [ ] **Step 5: Commit.** `git commit -m "feat: preserve and polish Rainbow Rings"`.

### Task 9: Persist Color Match and connect optional Learning practice

**Files:**
- Create: `lib/features/games/domain/sessions/color_match_session_codec.dart`
- Create: `lib/features/color_test/domain/color_difference_feedback.dart`
- Create: `test/features/games/domain/sessions/color_match_session_codec_test.dart`
- Create: `test/features/color_test/domain/color_difference_feedback_test.dart`
- Modify: `lib/features/color_test/application/matching_game_controller.dart`
- Modify: `lib/features/color_test/presentation/matching_screen.dart`
- Modify: `lib/features/learning/application/learning_providers.dart`
- Modify: `test/features/color_test/domain/matching_game_test.dart`
- Modify: `test/features/color_test/domain/color_match_level_adapter_test.dart`
- Modify: `test/features/color_test/application/matching_game_controller_test.dart`
- Modify: `test/features/color_test/presentation/matching_integration_test.dart`

**Interfaces:**

```dart
final class ColorDifferenceFeedback {
  final String hueDirection;
  final String saturationDirection;
  final String lightnessDirection;
}

ColorDifferenceFeedback describeColorDifference(RgbColor target, RgbColor guess);
```

Codec v1 stores round index, target descriptor identity, HSL draft, attempts, and settled phase. Learning practice stores its attempt/explanation in `LearningRepository`, never game coins/profile mastery.

- [ ] **Step 1: Write RED codec/feedback tests.** Assert exact round continuation, mismatch rejection, deterministic directional feedback at hue wrap/neutral edges, localized nonvisual wording, and no diagnostic or accuracy-percentage claim.
- [ ] **Step 2: Write RED integration tests for Games and Learn entry.** Games uses profile progression; Learn stores a practice explanation but does not award/update profile state; both survive reopen.
- [ ] **Step 3: Implement codec/save/retry, hue/saturation/lightness feedback, and the optional Learning adapter.** Label perceptual comparison as points when shown.
- [ ] **Step 4: Run all Color Match, Learning repository, lifecycle, and profile tests.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: connect Color Match practice and recovery"`.

### Task 10: Reorganize the Games hub without changing game identity

**Files:**
- Modify: `lib/features/games/presentation/games_screen.dart`
- Modify: `lib/features/games/presentation/game_ui_metadata.dart`
- Modify: `lib/routing/app_router.dart`
- Modify: `test/features/games/presentation/games_screen_test.dart`
- Modify: `test/features/games/presentation/games_integration_test.dart`
- Modify: `test/routing/app_router_test.dart`

**Interfaces:**
- Sections are Learn with Color (`colorMatch`), Color Logic (`waterSort`, `rainbowRings`), Play and Relax (`bubbleShooter`, `fruitPop`), and a prominent Coloring Studio route card with no `GameId`.
- Existing typed game routes/deep links remain valid.

- [ ] **Step 1: Write RED hub tests.** Assert exact five IDs appear once in their categories, Coloring opens `/coloring` without profile requirement, Continue resumes an exact session, invalid launches stay safe, and active gameplay has no banner slot.
- [ ] **Step 2: Run hub/router tests.** Expected: FAIL.
- [ ] **Step 3: Implement the localized adaptive sections, tutorial/help entry, preference controls, resume/restart affordances, and creative card.** Do not alter storage IDs or level routes.
- [ ] **Step 4: Run navigation restoration at all width classes, 200% text, RTL, keyboard, reduced motion, and profile switching.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: organize TintAtlas color games"`.

### Task 11: Prove profile deletion isolation and close the milestone

**Files:**
- Modify: `lib/features/games/presentation/profile_management_sheet.dart`
- Modify: `test/features/games/game_profile_shared_library_isolation_test.dart`
- Modify: `test/features/games/presentation/profile_management_sheet_test.dart`
- Modify: `test/features/games/application/game_profiles_provider_test.dart`
- Modify: `test/features/games/domain/game_profiles_repository_contract_test.dart`
- Modify: `test/data/db/hive_game_profiles_repository_test.dart`
- Modify: `docs/release/verification-ledger.md`

**Interfaces:**
- Deletion preview names only the selected player's game attempts, levels, scores, coins, badges, leaderboard entries, tutorials, and game preferences.
- Only `GameProfilesRepository` may be written during profile deletion; switching profiles changes Games views only.

- [ ] **Step 1: Write RED raw-storage isolation tests.** Seed Room, illustrated, Learning, Coloring, color, and palette records; delete and switch game profiles; assert all shared boxes and My Work results remain byte-for-byte/record-for-record unchanged.
- [ ] **Step 2: Write deletion-copy and confirmation tests.** Exact scope is visible, destructive action requires confirmation, last-profile rules remain explicit, and write failure leaves profile/data visible with Retry.
- [ ] **Step 3: Implement the minimum engine/controller/UI changes needed for isolation and accurate copy.** Never route profile deletion through the all-app data manager.
- [ ] **Step 4: Run `flutter test --no-pub test/features/games test/features/color_test test/features/learning test/features/games/game_profile_shared_library_isolation_test.dart test/data/db/hive_game_profiles_migration_test.dart --reporter expanded`.** Expected: PASS.
- [ ] **Step 5: Run format, scoped analyze, then full tests; exercise process death/background/resume on each game and record exact evidence.** No unexplained failure remains.
- [ ] **Step 6: Obtain a fresh read-only review against GAME-01–13, resolve findings, and commit.** `git commit -m "test: verify preserved TintAtlas games"`.

## Exit Gate

All five original storage IDs and every legacy profile/reward migrate without loss; each game resumes its last acknowledged logical turn after lifecycle/process interruption; failures remain playable and retryable; tutorials/preferences persist per profile; all games are usable without hue alone; Learning practice is non-diagnostic; profile deletion cannot alter shared My Work; and active gameplay remains ad-free. All focused and full regressions are clean.
