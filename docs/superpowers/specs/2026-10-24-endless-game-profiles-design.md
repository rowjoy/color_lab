# Endless Game Profiles and Progression Design

## Intent

Replace manual Easy/Medium/Hard selection with one consistent, endless level-progression system across every game in the Games section. Each named local player profile owns independent progress, resumes at its current level, earns first-clear coins and per-game milestone badges, and appears in an offline leaderboard. Rainbow Rings also receives the separately approved full animation system in `docs/superpowers/specs/2026-10-24-rainbow-rings-animation-design.md`.

## Confirmed Product Decisions

- The system is fully local and offline; no account, cloud sync, network leaderboard, or backend.
- The device supports multiple named player profiles.
- The last active profile is remembered and opens automatically; Games provides create/switch/manage controls.
- Every game uses the same progression method but keeps its own independent current level.
- Levels start at 1 and never end: 1, 2, 3, 4, and onward without a final level.
- A failed or abandoned level remains current. Only a win unlocks the next level.
- Completed levels are replayable from a level map.
- Coins and badges are granted only on a level's first clear. Replays may improve the score but cannot duplicate rewards.
- Each game grants its own badges at Level 20, 40, 60, and every further multiple of 20.
- Per-game leaderboard rank is highest completed level, then total coins. Overall rank is total first-cleared levels across all games, then total coins.
- Difficulty is derived from level and increases automatically; users never choose Easy, Medium, or Hard.
- Each game starts with 15 generated level descriptors. When only 10 unplayed generated levels remain, append 15 more. Thus the first extension grows the catalog through Level 30, and the process repeats forever.

## Scope

The shared system applies to:

- Bubble Shooter;
- Fruit & Veggie Pop;
- Water Sort;
- Rainbow Rings;
- Color Match when launched from Games.

The Lab's existing ad-hoc Color Match entry remains available without changing Lab workflow. Its play may use the same game mechanics but does not mutate profile progression unless it was launched as a Games level.

## Goals

- One transactional source of truth for profiles, generated levels, rewards, scores, badges, and leaderboard standings.
- Exact, deterministic regeneration of any current or completed level after app restart.
- No repeated generated layout for the same profile and game.
- Idempotent first-clear recording so rapid callbacks, dialog retries, or restarts cannot double-award coins or badges.
- A reusable level-map experience shared by all games.
- Preserve existing game progress where the old schema contains enough information.
- Keep all persistence durable before success is shown to the player.

## Non-goals

- No online usernames, login, password/PIN, remote identity, multiplayer, sharing, or anti-cheat service.
- No resume of an exact partially played board. Leaving mid-level regenerates that level's original starting board from its stored descriptor.
- No manually selectable difficulty sheet or difficulty grid.
- No finite campaign ending.
- No purchase/store economy in this phase; coins are earned and displayed only.

## Anti-goals

- A level completion callback must never advance the wrong profile, wrong game, or wrong level.
- A replay must never grant first-clear coins or the same badge again.
- Renaming or switching profiles must never merge progress implicitly.
- A generator update must not silently change a previously generated level.
- Queue replenishment must not block entering an already prepared current level.
- Invalid/corrupt storage must not partially overwrite otherwise valid profiles.

## Approaches Considered

### Selected: Shared profile and progression engine with game adapters

A common engine owns all profile/progression/reward rules. Each game supplies an adapter that deterministically builds and fingerprints a level descriptor and maps the shared level pressure into game-specific parameters. This centralizes invariants and lets every game share the same resume, map, reward, duplicate, badge, and leaderboard behavior.

### Rejected: Independent progression inside each game screen

This would duplicate persistence, reward idempotency, queue refill, profile switching, and level-map logic five times. The implementations would drift and make migration or leaderboard aggregation unreliable.

### Rejected: Persist every entire board forever

Full board snapshots simplify regeneration but grow storage unnecessarily and tightly couple persistence to each game's internal model. Versioned deterministic descriptors preserve replay while remaining compact.

## Core Domain Model

### Game identity

Introduce a stable `GameId` enum with serialized IDs for `bubbleShooter`, `fruitPop`, `waterSort`, `rainbowRings`, and `colorMatch`. Serialized values are permanent storage contracts.

### Player profile

Each `PlayerProfile` contains:

- a locally generated immutable ID;
- a trimmed display name;
- normalized name used for case-insensitive uniqueness;
- created/updated timestamps;
- total coins;
- lifetime games played and won;
- best normalized score across all profile games, retained separately from per-level scores;
- a map of `GameId` to `PlayerGameProgress`;
- earned milestone badge IDs.

Names are required, trimmed, 2–20 visible characters, and unique on the device ignoring case and surrounding whitespace. Profiles have no PIN. Rename and delete require explicit UI actions; deleting a profile requires confirmation. If the active profile is deleted, select another existing profile or request creation when none remain.

### Per-game progress

`PlayerGameProgress` contains:

- `currentLevel`, initially 1;
- `generatedThrough`, initially 15 after preparation;
- versioned descriptors for generated levels;
- compact fingerprints for every generated layout to prevent duplicates;
- the set of first-cleared level numbers;
- best normalized score per cleared/replayed level;
- attempts and wins;
- a monotonic attempt sequence plus the active attempt and most recent settled receipt;
- highest completed level;
- earned badge milestones for that game.

The current level is the lowest unlocked level not yet first-cleared. A player may replay an older completed level without changing `currentLevel`.

### Level descriptor

Each descriptor stores:

- game ID and level number;
- stable seed;
- generator version;
- retry salt used if a candidate duplicated an earlier layout;
- compact layout fingerprint;
- derived difficulty tier and level-pressure value.

The descriptor, not `Random.secure()`, is passed into the game. Each generator uses a stable project-owned deterministic PRNG whose output is covered by fixtures. Generator versions remain available for existing descriptors so app updates do not change old levels.

## Endless Catalog and Duplicate Prevention

On first preparation of a game for a profile, generate Levels 1–15 in order. The engine builds each candidate with the game's adapter, hashes its canonical layout signature, and compares it with every fingerprint already stored for that profile/game. On collision, increment the retry salt and derive another seed until unique.

After a first clear advances `currentLevel`, calculate:

`remainingPrepared = generatedThrough - currentLevel + 1`

When `remainingPrepared <= 10`, append exactly 15 descriptors in the same durable transaction as the completion when practical. If descriptor generation cannot finish immediately, completion and reward state are committed first, and refill continues asynchronously; the already prepared current level remains playable. Refill is idempotent by `(profileId, gameId, levelNumber)`.

Fingerprints remain stored for all generated levels. They are compact hashes rather than full boards, providing exact duplicate tracking with modest linear storage growth.

## Dynamic Difficulty

Difficulty labels remain internal/display metadata, never a user choice:

- Levels 1–9: Easy;
- Levels 10–19: Medium;
- Level 20 onward: Hard.

Difficulty does not stop increasing at Level 20. A monotonic `levelPressure` continues to rise with a diminishing curve so later levels become harder without rapidly becoming impossible. Each adapter converts that pressure into bounded, solvable parameters:

- **Water Sort:** increase colors and scramble depth, then vary reversible scramble patterns and par pressure after tube/color counts reach safe caps. Generate from a solved board through reversible moves so the level remains solvable.
- **Rainbow Rings:** increase colors, ring capacity, reversible scramble depth, and puzzle topology within responsive-layout caps. Generate from solved stacks through reversible moves. Completion stars always use the animation design's fixed `parMoves = round(colorCount * capacity * 0.9 + colorCount)` formula; level pressure never changes that formula.
- **Bubble Shooter:** increase color variety, starting rows, target/clear pressure, and reduce forgiving shots within tested bounds.
- **Fruit Pop:** increase score target and obstacle/board pressure while deriving a sufficient move budget from bounded simulations rather than unbounded linear targets.
- **Color Match:** increase round count, reduce tolerance, and increase target-color separation/precision within accessibility-safe bounds.

Game adapters own exact formulas and solvability checks. The shared engine owns only the monotonic level pressure and tier labels. Each formula has boundary fixtures at Levels 1, 9, 10, 19, 20, 30, 100, and a large level to prove it stays valid.

## Completion, Coins, Scores, and Badges

Every game reports a normalized score from 0–100. The adapter defines how raw game results map to that score so the repository never receives unbounded raw values.

Starting current play or a replay calls `beginAttempt(...)`. The repository durably allocates the next per-profile/per-game attempt sequence, increments attempts once, and returns a `GameLaunch` containing the immutable attempt ID. Starting another attempt for that game abandons any earlier open attempt. Abandoned attempts count as plays but not wins; merely opening a map or game card does not count. Reopening after leaving mid-level starts a new attempt on the same deterministic descriptor and original board.

Completion carries that attempt ID. Only the currently open matching attempt may settle. The repository persists its terminal receipt, increments wins once, and clears the open attempt. Repeating the same submission returns the stored receipt marked `alreadyApplied` without changing attempts, wins, scores, coins, badges, or progress. A later genuine retry or replay receives a new attempt ID, so it remains distinguishable from a duplicated callback. Once a newer attempt begins, callbacks from older attempts are stale and rejected.

First-clear coin rewards use the automatic tier:

- Easy: 10 coins;
- Medium: 25 coins;
- Hard: 50 coins.

`completeLevel(profileId, gameId, attemptId, descriptor, normalizedScore)` is atomic and idempotent:

1. Confirm the result belongs to the active profile, open attempt, and generated descriptor.
2. Settle that attempt once and update the per-level best score.
3. If already cleared, return a replay result with zero coins and no badge.
4. Otherwise mark first clear, add tier coins, advance `currentLevel` only when the cleared level was current, and award a badge if the level is a new multiple of 20.
5. Trigger queue refill when needed.
6. Flush durable state before returning the reward result shown by the UI.

Completing an older replay never skips or advances the current level. Duplicate completion callbacks return the persisted receipt with `alreadyApplied: true`; presentation must not replay coin/badge celebration for that duplicate response.

Badge IDs are stable strings containing game ID and milestone, for example `waterSort:40`. Badge metadata supplies a game icon, milestone number, earned timestamp, and accessible label.

## Local Leaderboard

The leaderboard reads all local profiles; it does not maintain a separate mutable ranking table.

- **Overall:** descending total first-cleared levels across all five games, then descending total coins, then case-insensitive username.
- **Per game:** descending highest completed level, then descending total coins, then case-insensitive username.

The UI offers Overall plus one tab/filter per game. The active profile is highlighted. Empty/new profiles remain visible at zero rather than disappearing. Rankings recompute from persisted profile data, avoiding stale duplicate entries.

## Level Map

A reusable `GameLevelMapScreen` receives a `GameId` and active profile:

- completed levels show a check and best score and are replayable;
- current level is highlighted with the Play/Resume action;
- generated future levels are visible but locked;
- the map initially exposes the generated catalog and extends after refill;
- Level 20/40/60 milestone nodes show their badge state;
- difficulty tier/pressure is descriptive only, not selectable.

Each game card on the Games hub shows the active profile's current level, automatic tier, completed count, next badge milestone, Play/Resume, and Map actions. Game screens also expose a map button without allowing profile switching mid-session.

## Profile and Games Hub Flow

On first Games entry with no profile, show required Create Player UI. After creation, prepare Level 1–15 for each game without blocking the entire hub: the chosen game prepares first on demand, while others can prepare lazily.

The Games header shows an active-profile chip. Tapping it opens profile management: switch, create, rename, or delete. The last active profile ID is persisted and restored automatically.

Remove:

- Rainbow Rings, Water Sort, and Bubble Shooter difficulty bottom sheets;
- Color Match Easy/Medium/Hard grid;
- route extras that carry a selected `GameDifficulty`.

All game Play actions begin an attempt for the active profile's current descriptor and navigate with an immutable `GameLaunch` containing profile ID, game ID, descriptor, attempt ID, and whether this is current play or replay. Game screens reject stale launch completions if the active profile, attempt, or descriptor changed.

The hub adds Badges and Leaderboard entry points and keeps aggregate Coins/Wins/Best information scoped to the active profile.

## Color Match Compatibility

Games-launched Color Match uses the shared descriptor, level rules, normalized result, rewards, and resume behavior. Lab-launched Color Match remains a non-profile practice session. Route/API design must distinguish these modes explicitly; absence of a `GameLaunch` means practice and cannot award progression.

## Persistence and Migration

Introduce a new versioned profile store rather than mutating the old single-map contract in place. Persist one validated root state containing schema version, active profile ID, profiles, per-game progress, descriptors, fingerprints, scores, badges, and a legacy-migration marker. Repository operations remain serialized and flush before success, following the existing Hive durability pattern.

On first schema-v2 open:

- read legacy schema-v1 progress if present;
- preserve its coins, games played/won, and best score in a pending legacy snapshot;
- after the first named profile is created, import those aggregate values once;
- start every per-game current level at 1 because the old schema contains no reliable per-game level;
- retain or archive the old box until the v2 flush succeeds;
- mark migration complete so restart cannot import twice.

Malformed individual profiles/descriptors fail validation without partially applying an update. Storage errors leave the last durable state and surface retry UI. Profile/reward operations use serialized repository mutations so concurrent game callbacks cannot race.

## Application APIs

Replace difficulty-oriented progress methods with profile/progression methods conceptually equivalent to:

- `loadState()`;
- `createProfile(name)` / `renameProfile` / `deleteProfile` / `setActiveProfile`;
- `prepareGame(profileId, gameId)`;
- `beginCurrentAttempt(profileId, gameId)` returning `GameLaunch`;
- `beginReplayAttempt(profileId, gameId, level)` returning `GameLaunch`;
- `completeLevel(...)` returning coins, badge, current-level change, and refill information.

Riverpod exposes the root profile state, active profile, per-game progress, leaderboard derivations, and serialized mutations. UI must await durable completion before claiming coins, badges, or progression.

## Integration with Rainbow Rings Animation

The full Rainbow Rings animation design remains authoritative for rendering and interaction timing. Its screen accepts a `GameLaunch`, generates the specified deterministic descriptor, and records completion through the shared engine. The animated Next Level action requests the newly persisted current descriptor rather than incrementing an in-memory level. Restart and replay always reuse the same descriptor; animation resets cannot award progress.

## Testing

### Profile and model tests

- Username trim, bounds, case-insensitive uniqueness, rename/delete, and last-active behavior.
- Independent progress for multiple profiles and all five games.
- Map serialization round trips, immutability, invalid values, and schema-version validation.

### Generator/catalog tests

- Stable PRNG fixtures and descriptor regeneration across process restarts.
- Initial catalog is exactly 1–15.
- Refill at 10 remaining appends exactly 15 and is restart/idempotency safe.
- Collision retry produces a unique fingerprint and persists its retry salt.
- Replay regenerates the original canonical signature.
- Difficulty adapters remain valid/solvable at specified boundary levels.

### Reward tests

- Fail/exit does not advance.
- A begun then abandoned launch counts as one attempt/play and zero wins; opening the map does not count.
- A duplicate completion with the same attempt ID returns `alreadyApplied` and cannot increment attempts or wins again.
- A genuine replay gets a new attempt ID and may improve the score.
- First clear advances current level and grants tier coins once.
- Duplicate callback and replay grant zero additional rewards.
- Level 20/40/60 badge is per game, once only.
- Clearing an older replay does not skip current level.
- Raw scores normalize to 0–100.

### Repository durability and migration tests

- Real Hive close/reopen preserves profiles, catalogs, scores, fingerprints, badges, active profile, and pending refill state.
- Concurrent completions serialize without duplicate rewards.
- Flush failure never reports success.
- Legacy v1 imports aggregate values exactly once after named-profile creation.
- Corrupt/unsupported data produces recoverable error UI without overwriting the box.

### UI and routing tests

- First Games entry requires a username; last active profile reopens.
- Profile switch changes every card/stat/map and leaderboard highlight.
- Difficulty sheets/grid are absent.
- Every game Play resumes its own current level; map replay passes the older descriptor.
- Completed/current/locked/milestone map states and narrow/large-text semantics.
- Overall/per-game leaderboard ordering and ties.
- Color Match practice cannot award profile progress.

### Game integration tests

- All five screens accept deterministic launches, report normalized results, and request the persisted next descriptor after a win.
- Exit/reopen restarts the same level from its original layout.
- Rainbow Rings full animation tests from its separate design remain required.

### Final verification

- Focused TDD suites per task.
- Full `flutter analyze` and `flutter test`.
- Android debug APK and iOS simulator builds.
- Manual device smoke test for profile switching, restart/resume, audio/haptics, and long animated gameplay.

## Expected File Areas

- New profile/progression/catalog domain files under `lib/features/games/domain/`.
- New repository/provider implementation and schema-v2 Hive store.
- Shared level-map, profile-management, badges, and leaderboard presentation files.
- `games_screen.dart`, `app_router.dart`, all five game screens/controllers, and generators.
- Rainbow Rings files listed by its animation design.
- Comprehensive new domain, repository, application, routing, presentation, and integration tests.

## Builder Calls

- Profile names use 2–20 trimmed visible characters and are case-insensitively unique.
- Mid-level state is not snapshotted; the same deterministic level restarts from its initial board.
- Coin rewards retain the existing 10/25/50 tier values.
- Old aggregate progress imports into the first named profile, while per-game levels begin at 1.
- The legacy aggregate best score imports into the profile-wide best-score field and is never attributed to a particular game or level.
- Stable generator versions and a project-owned PRNG protect old maps across app upgrades.
- Each begun play has a durable attempt ID; abandoned launches count as attempts, and duplicate completion callbacks settle only once.
- Rainbow Rings stars retain the animation design's literal `parMoves` formula; endless difficulty changes the puzzle, not that formula.
