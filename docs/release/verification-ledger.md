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
| Independent-review concurrency/localization fixes | `0`, `+298` | Games plus localization passed after selective stale-attempt rollback, durable switch coordination, ambiguous-write reconciliation, and generated Games/Level Map copy; scoped re-review found all four findings addressed with no new Critical/Important breakage. |
| `flutter pub get` | `0` | Dependencies resolved from the pinned project constraints; no dependency or lockfile change was produced. |
| `flutter gen-l10n` | `0` | `l10n.yaml` drove generation; committed English localization output is current. |
| Exact `dart format --output=none --set-exit-if-changed lib test tool` | `1`, 388 scanned / 1 reported | Only protected user-owned `lib/main.dart` was reported. The command did not mutate it; its diff SHA-256 remained `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`. |
| Eligible-tree format check excluding protected `lib/main.dart` | `0`, 387 / 387 unchanged | `rg --files lib test tool -g '*.dart' -g '!lib/main.dart' \| xargs dart format --output=none --set-exit-if-changed`. The clean CI checkout runs the exact full-tree command because the protected local diff is not committed. |
| `flutter analyze --no-pub` | `0` | Post-fix run: `No issues found!` in 4.1 seconds. |
| `flutter test --no-pub --reporter expanded` | `0`, `+1654` | Post-fix full suite completed in 1 minute 6 seconds with `All tests passed!`; no skip or test deletion was added. |
| `flutter build apk --debug --no-pub` | `0` | Post-fix `build/app/outputs/flutter-apk/app-debug.apk`; 217,348,103 bytes; SHA-256 `1defd0e913a34a7534be429d15ce25af5ffc2ff5cdb5bef752452b747df264aa`. Debug-only build; no signing or release secrets. |
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
| BASE-06 repeatable clean verification | pass locally; remote run pending | All eligible Task 10 files pass generation, format, analyze, `+1654` tests, and debug APK build. CI is pinned and committed; only the protected uncommitted `lib/main.dart` diff prevents the literal full-tree format command from returning zero in this shared checkout. |
| BRAND-01 screen TintAtlas | blocked before asset/store lock | Exact-name adjacent web conflict; product owner/clearance reviewer must accept or rename. See `identity-decision.md`. |
| IDENTITY-01 confirm publication history | blocked | Store-account owner must attest history; `newListing` cannot be inferred. |
| SUPPORT-01 support contract | provisional | API 24/iOS 13 and architectures documented; physical device/archive gates remain blocked. See `support-matrix.md`. |

## Evidence rules for later tasks

- Each task records its RED test, GREEN command, exact commit, migration/rollback evidence, and any blocked external input here or in a linked dated record.
- A blocked field names its owner and required evidence; code does not manufacture store history, legal clearance, human mask annotations, device access, or publication approval.
- Product files remain untouched in Task 1. Later work must preserve schema names and routes or supply migrations/redirects.
- No public release, store upload, credential change, package-ID change, signing change, or ad activation follows from this ledger.

## Plan 02 Task 8 — durable real-room milestone (2026-10-28)

This evidence follows Tasks 1–7 at
`4d98b1604d6901086035dd8eb7af26b61ced824f` on `TintAtlas`. The four scenarios in
`test/features/room_studio/real_room_project_integration_test.dart` use the real
app/router, setup, photo preparation, session/autosave, disk repository,
variants, recoloring algorithm and export service. Native picker/segmentation,
worker scheduling and platform channels are controlled boundaries. The fresh
empty offline onboarding/Illustrated Rooms/Later flow is separate from the
verified synthetic model-cache flow; both forbid network construction. Tiny
`hello`/`world` cache files prove hash/cache protocol behavior, not TFLite
inference.

The durable flow asserts exact oriented photo pixels, zero-mask manual fallback,
completed versus cancelled edits, pointer failure with continued edits and one
Retry of the newest coherent draft, metadata-only asset reuse, rename recovery,
independent duplication, full-key comparison/lifecycle behavior, and a fresh
repository/container/router reopen of the last acknowledged state. It reads
actual Save/Share files at the terminal mocked channel before cleanup, then
checks project deletion preserves independently owned source/model/duplicate
and external export bytes. Existing controlled scheduler/session tests in the
focused gate additionally cover late completion/error, physical timeout
replacement and draining accepted work before deletion. No real recolor isolate
runs inside widget fake-async; separate existing real-isolate tests remain in the
gate.

A focused behavioral RED proved that successful acquisition-storage Retry left
`RoomMaskFailureKind.storage` visible (one failed test, exit 1, 9.57s). The small
controller/screen correction reconciles only the captured acquisition-owned
error and rejects its stale action, preserving the pending receipt and previous
failed project draft. The same test now proves a second old action cannot retry
that project's save. The frozen-fixture consumer first failed on the absent
inventory (one failed test, exit 1, 2.66s); immutable artifacts were then added.
Composed-flow harness failures and interrupted diagnostics are not product RED
or passing evidence. No other production change was needed.

Commands used Flutter
`/Users/jamirulislam/Applications/flutter/bin/flutter` (3.41.1) and Dart
`/Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart` (3.11.0),
with the existing dependency locks. Elapsed values include command startup.

| Command / gate | Exit and result | Elapsed / evidence |
| --- | --- | --- |
| `flutter test --no-pub test/features/room_studio/real_room_project_integration_test.dart --reporter expanded` | `0`, 4 passed | 63.90s; final exact byte and neutral Share-dismissal assertions. |
| `flutter test --no-pub test/features/room_studio/real_room_project_integration_test.dart test/features/room_studio/models/room_model_store_test.dart test/features/room_studio/data/room_project_codec_test.dart test/data/files/file_room_project_repository_test.dart test/features/games/game_profile_shared_library_isolation_test.dart --reporter expanded` | `0`, 131 passed | 62.09s; immutable fixtures, deferred I/O and shared-library isolation; the stricter final dismissal assertion is covered in the four-case run and final gates. |
| `flutter test --no-pub test/features/room_studio test/features/picker test/data/files --reporter expanded` | `0`, 1,036 passed | 76.77s; exact Plan 02 focused command, including the final Share assertion. |
| `dart format --output=none --set-exit-if-changed lib test tool` | `1`, 432 scanned / only `lib/main.dart` reported | 1.68s; protected user diff, no formatter output written. |
| `rg --files lib test tool -g '*.dart' -g '!lib/main.dart' \| xargs /Users/jamirulislam/Applications/flutter/bin/cache/dart-sdk/bin/dart format --output=none --set-exit-if-changed` | `0`, 431 unchanged | 1.72s; excludes exactly the protected file. |
| `flutter analyze --no-pub` | `0`, no issues | 4.26s. |
| `flutter test --no-pub --reporter expanded` | `0`, 2,108 passed | 118.51s; 18 cases added since Task 7's 2,090, no added skips or removed tests. |
| `flutter build apk --debug --no-pub` | `0`, debug APK built | 15.04s; Gradle `assembleDebug` 11.9s. Artifact details below. |
| `flutter build ios --debug --no-codesign --no-pub` | **Blocked preparation**, timeout; raw Flutter/wrapper `0` after SIGINT is not success | 480.35s at the 480s bound; CocoaPods TensorFlowLiteSwift 2.12.0 source clone, no Xcode compilation. |
| `flutter devices --machine`; `adb devices -l`; `xcrun xctrace list devices` | `0` each | 7.29s / 0.02s / 1.74s; emulator only, physical iPhone offline. |
| `git diff --check`; staged diff and protected-file audit | `0`; 26 explicit Task 8 paths | Main is excluded; its diff SHA-256 remains `c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`. |

Android artifact: `build/app/outputs/flutter-apk/app-debug.apk`, 217,598,646 bytes,
SHA-256 `737c3eeac3d6d55d65c501f06be6ebe525b02a722f76497510d08e70844cb1e6`.
Flutter's effective JDK was
`/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java`, OpenJDK
`17.0.9+0-17.0.9b1087.7-11185874`. This is debug assembly, not signing, release
size approval or native runtime evidence. The local artifact was built from the
authorized shared checkout including the existing protected main.dart diff.
That preexisting diff is excluded from the Task 8 commit.

The final iOS attempt was interrupted only in its owned process group after
480 seconds. CocoaPods reported `Cancelled` / `Interrupt` and Flutter reported
`Error running pod install`; `Running Xcode build` never occurred. Flutter and
the wrapper both returned raw exit 0 after SIGINT, so timeout/phase evidence
classifies the run as blocked, never a compile pass. Post-interrupt process
inspection found zero surviving owned processes, and `git diff HEAD --name-only
-- android ios pubspec.yaml pubspec.lock` was empty.

The independent schema-v1 freeze is `test/fixtures/room_projects/v1/`, with
inventory SHA-256
`365055822f7b29fbff9b09afdd242c8bd597f0ff9a0980b99d559e11fbca1013`.
It pins 13 repository files / 5,801 bytes, two projects, four acknowledged
manifests, checksummed ancestry pointers, 3×2 synthetic PNG photos, a 1×1
thumbnail, distinct AI/current masks, multiple variants/baseline and a null
thumbnail. README/inventory fix IDs, timestamps, colors, masks and each file's
size/hash. These static Python-assembled bytes are independent of the current
Dart encoder at runtime. Plan 03 must consume them unchanged. Consumers verify
hashes, reject unsupported versions/fields, recover acknowledged ancestry while
retaining the correct CAS token, and discard a newer valid orphan. Storage-v1
PNG compatibility remains broader than strict export PNG verification;
process-interruption evidence does not establish power-loss directory durability.

The milestone uses a 12×8 EXIF-oriented synthetic JPEG (765 bytes, SHA-256
`d2ca9966976c419b66d2ba6cf91dd74dc41ab32e2ca8e5647985d2398e5538b5`). Real preparation
produces exact rotated 12×8 pixels; prepared PNG is 210 bytes, SHA-256
`c8ebac7dc857ea7a537a876678bfaa6c5aa955555653a5c7f480827a0e9a890c`. Terminal mocked
Save and Share each read a strict 12×8 PNG, 250 bytes, SHA-256
`0eb7d2e1c3884b2dbc9b3a0ebd50634ad16915e888a2aa5b77098fc44bb626f0`. Assertions cover
the complete `(projectId, photoId, maskRevision, colorRevision, variantId)`, exact
active-side RGBA/PNG, safe filename, MIME/title/subject/anchor and absence of
comparison UI/overlay pixels. Permission denial/lifecycle interruption produce
no handoff; Share dismissal is neutral. Export leaves an unsaved project's save
status unchanged and external copies survive project deletion.

The deferred Task 1 async `addStream`/flush/close probes now distinguish capacity
from generic I/O, retain safe partials, reject incomplete promotion and retry
cleanly. Task 2 asset write/flush/pre/post-publication and temporary-pointer
write/flush probes preserve the old pointer/assets, clean staging/orphans on
fresh reopen and retry successfully. Neither required production I/O changes.
The shared-library test populates colors, palettes, illustrated designs and a
real Room project: profile switch/delete and all-game deletion preserve their
exact manifests; Room deletion preserves all other libraries.

| Remaining gate or constraint | State / owner / evidence needed |
| --- | --- |
| ROOM-03 explicit intent/history | **Partial**. Schema v1 cannot distinguish successful all-zero AI from manual fallback after reopen; both receive tested cause-neutral copy. Plan 03 owns schema v2 and migration from the frozen bytes. |
| Native Save/Share, permission/settings and external-file retention | **Unexecuted on physical devices**, Device QA. Run gallery/Share cancellation/retry, filename/MIME/metadata inspection and post-delete persistence on supported Android and iOS devices. Mocked channels prove only the host boundary contract. |
| Native picker/camera orientation, cached production inference, OS restart | **Unexecuted**, Device QA. Use actual camera/rotated fixtures, pinned production models offline, and process/OS restart on named devices. Synthetic cache and fresh host containers do not replace these checks. |
| iOS unsigned build/archive | **Blocked in source preparation**, iOS Release. Both the 180s diagnostic and final 480s attempt stopped at the locked TensorFlowLiteSwift 2.12.0 Git clone. Complete CocoaPods preparation, then obtain unsigned compile and separate archive/device evidence. No credentials or native configuration changed. |
| Available device checks | Android `emulator-5554` is booted, API 34 / `arm64-v8a` (`adb getprop`, exit 0, 0.13s). `xctrace` lists physical iPhone iOS 18.3.2 offline and installed simulators; Flutter wireless discovery reports code -27. Discovery is not a runtime pass. No web support claim. |
| Representative ten-project storage/performance | **Open**, Mobile Performance QA. The deterministic synthetic recipe and remaining realistic 1600-axis corpus/device owner are in `performance-budgets.md`; no device budget is inferred. |
| Known schema/UX constraints | Restore AI can add a no-op metadata revision within the 10,000-revision bound while reusing assets. Rename I/O recovery safely requires Cancel → Retry save → reopen Rename. Arbitrary callers must await maintenance erase; the production manager does. No additional controlled RED justified broadening these behaviors. |

No dependency, platform ID/configuration, signing, advertising or protected-main
change is included. No push, upload, release, remote CI or physical-device pass
is claimed by this milestone.

## Plan 02 Task 8 fix round 1 — request-owned photo recovery

Review of `2d0b9de2e442217a644ab906cc542f817111ceb9` found that Capture could
complete the shared photo-storage retry while Room retained its error. Pressing
Room's photo-recovery button then incorrectly saved an unrelated failed project.
The new real-router regression first failed on durable disk revision 2 where
revision 1 was required (exit 1, one failed test, 13.49s). It exercises Capture's
actual Retry photo request, cached Continue back to Room, the pending receipt and
previous unsaved draft, and the returning/stale photo action.

Recovery now carries an immutable transient storage-failure event with its
request/destination through the exact request or claim outcome. A successful
shared retry resolves that same event. Room reconciles only its captured error,
operation, receipt and session owner; newer events/errors/controller/session
state cannot clear or act on it. Photo recovery never dispatches project
`retrySave()`. Paused/disposed callbacks are inert and avoid disposed-context
localization reads. The legacy photo-returning `claim()` remains compatible;
Room uses the typed claim outcome. No persisted schema changes or automatic
picker reopening follow from this correction.

Final verification used the same absolute Flutter/Dart binaries and locked
`--no-pub` dependencies recorded above. All code/test/analyzer/format gates
finished before the single final Android and single bounded iOS build attempts;
code/test hashes remained unchanged afterward.

| Gate | Result | Elapsed |
| --- | --- | --- |
| Acquisition + Room controller tests | `0`, 109 passed | 3.77s |
| Focused cross-route regression | `0`, 1 passed | 12.08s |
| Milestone + Room controller/UI + all picker tests | `0`, 269 passed | 67.51s |
| `flutter test --no-pub test/features/room_studio test/features/picker test/data/files --reporter expanded` | `0`, 1,045 passed | 83.38s |
| `flutter test --no-pub --reporter expanded` | `0`, 2,117 passed | 117.19s |
| `flutter analyze --no-pub` | `0`, no issues | 3.21s |
| Eligible formatter excluding exactly `lib/main.dart` | `0`, 431 unchanged | 2.75s |
| `flutter build apk --debug --no-pub` | `0`, debug APK built | 13.75s; Gradle 11.4s |
| `flutter build ios --debug --no-codesign --no-pub` | **User-stopped / non-success**, before compilation; raw Flutter/wrapper `0` after SIGINT | 160.29s; planned 480s bound superseded by user instruction |

The nine additional cases cover cross-route durable ownership, exact/repeated
failure-event identity, old/lookalike event rejection, failed intent without a
receipt, shared retry retaining the previous draft, newer mask errors, session
replacement, closed editor, acquisition-provider replacement, and stale actions.
The milestone contains five scenarios. Prior coverage was retained.

Final-code APK: `build/app/outputs/flutter-apk/app-debug.apk`, 217,609,175 bytes,
SHA-256 `fce21500ed16c331216a1b83412e102f3d8cd2f82477cac2e2be4aa3252e9c95`.
Flutter's effective JDK remains Android Studio JBR at
`/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java`, OpenJDK
`17.0.9+0-17.0.9b1087.7-11185874`. This local debug artifact includes the
preexisting protected main.dart diff in the authorized shared checkout; that
diff is excluded from the fix commit.

At the user's request, the running iOS process group was stopped immediately
with SIGINT during CocoaPods' locked TensorFlowLiteSwift 2.12.0 source clone.
CocoaPods reported `Cancelled` / `Interrupt`, followed by `Error running pod
install`; Xcode compilation never started. Flutter and the wrapper returned raw
exit 0 and the automatic timeout flag was false because the stop was manual;
**userStopped=true** makes this a non-success, not a completed gate. The exact
owned process group had zero survivors after cleanup, and native/dependency
Git diffs were empty. No further build or test was run after the user changed
the workflow.

Frozen schema-v1 artifacts and their inventory hash remain unchanged. ROOM-03
intent/history stays partial for Plan 03; native runtime and representative
device performance gates remain open with the owners recorded above. Device
discovery still reports the API 34 Android emulator and wireless iPhone error
-27. No physical-device or web pass is claimed. Final whitespace/staging audits
pass; only the eight explicit fix/evidence paths are committed. Protected
`lib/main.dart` retains diff SHA-256
`c9bd56e83824d1dff5f750092e3d751bbb1841ad9377380c057bdffb4aacf437`; dependency/native
configuration/signing/advertising files are unchanged.

## Plan 03 Tasks 4–6 — manual review and precision coding batch

Baseline: `f2ab92e18eb58014aeda998574ce92d28d214653` on `TintAtlas`.
The user committed the previously protected `lib/main.dart` change in that
baseline; this batch does not edit it and leaves its work uncommitted.

Implemented guided all-surface review (including explicit Absent), literal
working-pixel coverage, original/recolored/overlay navigation, distinct pattern
and text identities, source-aligned cursor/outline/magnifier, keyboard/button
alternatives, and the 0.5–20% brush range. Review checks are transient and reset
on a pixel revision; switching surface/view changes no pixel/history data.
Small/large, RTL, high-contrast, 200% text, cancelled/two-pointer gestures and
resize cases have focused tests written. No test, analyzer, formatter or build
was executed during this coding batch, as explicitly requested. The parent
will record the one combined focused run under an overall 60-second bound;
no passing result is claimed here.

`tool/room_recolor/manual_mask_benchmark.dart` provides deterministic synthetic
commands/checksums, injected monotonic timing/device metadata, whole-command
history accounting, optional real acknowledgment/reopen callbacks and optional
UI feedback traces. Its default CLI is unverified host evidence only. Missing
UI feedback, autosave or reopen measurements are null, not synthetic zeroes.
A command microbenchmark is not pointer-to-visible-brush feedback. The harness
never marks the release gate satisfied or supplies an approved threshold.
Recovery tests cover an interrupted unacknowledged edit, Retry, corrupt newest
history with acknowledged fallback, healthy-project isolation, eviction and
fresh-controller AI refresh. Existing Task 3 durability coverage supplies
serialized action/save and failed-save process-reopen cases.

**OPEN external gates:** named minimum/representative Android physical-device
p50/p95 feedback, commit/ack/reopen timing, peak memory, thermal/background and
rotation QA; independent iPhone/iPad evidence when that platform gate is active;
TalkBack/VoiceOver/keyboard physical QA; product-owner approval of the measured
feedback threshold (under 100 ms remains a target, not an approved claim).
No smart-mask accuracy/proposal claim, native build, full-suite pass, device
performance result, signing, release or publishing claim is made.
