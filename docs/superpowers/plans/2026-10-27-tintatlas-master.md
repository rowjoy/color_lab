# TintAtlas Master Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the approved TintAtlas v1 as a room-first, offline-capable, responsive Flutter app with durable local work, Color Learning, original Coloring Studio content, preserved games, and policy-safe banner-only monetization.

**Architecture:** Keep the current Riverpod/GoRouter/Hive feature boundaries, add shared storage/layout/region contracts, and migrate one independently testable subsystem at a time. This file is the execution index; each linked subsystem plan owns exact production files, tests, interfaces, commits, and verification gates.

**Tech Stack:** Flutter/Dart 3.11, Material 3, Riverpod 3.3, GoRouter 17.5, Hive 2.2, `image` 4.12, `flutter_svg` 2.3, TFLite, platform photo/camera/share/gallery plugins, generated Flutter localization, and Google Mobile Ads only in the final plan.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md`

## Global Constraints

- Work on branch `TintAtlas`; preserve unrelated changes, especially the user-owned edit in `lib/main.dart`, and never stage it accidentally.
- Store title is `TintAtlas: Room Visualizer`; proposed new-install Android/iOS ID is `com.roomvisualizer.tintatlas`, but identity changes stop if publication-history evidence says an immutable ID already exists.
- Retain the internal Dart package name `color_lab`, private data directory literal `color_lab`, existing Hive box names, model URLs/hashes, and all five `GameId` storage IDs for compatibility.
- Root destinations are exactly Home, Rooms, Learn, and Games; My Work is not a fifth compact tab.
- Width classes are Compact `<600`, Medium `600–839`, Expanded `840–1199`, and Large `>=1200` logical pixels.
- Launch floor remains Android API 24 and iOS 13 unless measured dependency/device evidence is approved before a deliberate change.
- V1 is a native Flutter mobile product for Android and iOS: use platform photo/camera/share/back/permission conventions; web/desktop parity remains deferred.
- Android and iOS release gates are independent; shared Dart/schema requirements apply to both.
- Room, illustrated, coloring, learning, color, and palette records are installation-local; game profiles own only game progress/rewards/settings.
- No mandatory account, cloud sync, proprietary paint catalogue, Asian Paints shade names/codes/images/article wording, diagnostic vision claim, or calibrated purchase-match claim.
- Every launch feature is free: no paywall, subscription, in-app purchase, energy/lives purchase, paid hint, or click-to-unlock path; banner ads are the only planned income format.
- Core functions work without ads, account, consent, or network; active editors, camera/picker flows, loading/errors, and gameplay remain ad-free.
- Every new behavior follows RED → GREEN → focused regression → format/analyze → review → task-scoped commit.
- Do not push, publish, upload, alter store state, add production ad IDs, or use signing credentials without explicit user authorization.

## Review Focus

- **Existing data and IDs:** an upgrade must reveal all current colors, palettes, illustrated designs, profiles, attempts, rewards, and model files without silently treating them as new or corrupt.
- **Interrupted durable work:** disk full, killed write, stale async result, provider disposal, and process death retain the last acknowledged Room/Learning/Coloring/Game state and expose Retry.
- **Adaptive interaction:** 320×568, short landscape, tablet split view, fold/window resize, 200% text, keyboard inset, RTL, TalkBack/VoiceOver, and non-color cues keep every primary action reachable.
- **Privacy boundaries:** selected photos stay local, broad media permission remains absent, exported images leak no source EXIF/location data, and ad requests never receive user content.
- **Release truthfulness:** disabled/unmeasured smart proposals, no-fill ads, unsupported platforms, preview limitations, audience declarations, and store screenshots must match the actual candidate.

---

## Observed baseline on 2026-10-27

- `flutter analyze`: non-zero with one existing info at `lib/features/games/presentation/fruit_pop_screen.dart:1048` (`unnecessary_brace_in_string_interps`).
- `flutter test --reporter compact`: non-zero, ending at `+1527 -38`; failures are concentrated in current game/profile UI expectations and are not caused by these planning documents.
- No `integration_test/`, localization generation, CI workflow, AdMob integration, durable real-room repository, Learning repository, or Coloring repository exists.
- The app globally blocks startup on approximately 65.2 MiB of Room models in `lib/bootstrap.dart:23-54`.

The first implementation task records the full failing-test inventory in the evidence ledger. No later milestone may relabel a pre-existing failure as fixed without a focused reproducer and passing output.

## Plan set and ownership

| Order | Plan | Owns | Primary spec IDs |
|---|---|---|---|
| 1 | [Foundation, shell, and data](2026-10-27-tintatlas-foundation-shell-data.md) | Baseline, identity gate, storage registry, localization, four-root shell, Home/My Work, responsive primitives | BASE, BRAND, IDENTITY, SUPPORT, SHELL, DATA |
| 2 | [Real-room projects](2026-10-27-tintatlas-real-room-projects.md) | On-demand models, project files/repository/library/autosave, fallback, variants, queued recolor, export/privacy | ROOM |
| 3 | [Manual mask correction](2026-10-27-tintatlas-manual-mask-correction.md) | Intent bitmap, undo/redo, review flow, precision/magnifier, durable edits | MASK-01, MASK-05, MASK-06, MASK-08, MASK-11 |
| 4 | [Illustrated Rooms v2](2026-10-27-tintatlas-illustrated-rooms-v2.md) | Brand-neutral palettes, region contract pilot, v1→v2 design migration, predictable edits, compare/export | ILL-01–13 |
| 5 | [Color Learning](2026-10-27-tintatlas-color-learning.md) | Six foundations, progress, concept checks, notebook, tool restore, My Work section | LEARN-01–08, LEARN-11–13 |
| 6 | [Coloring Studio](2026-10-27-tintatlas-coloring-studio.md) | Shared region renderer, 12 original drawings, Guided/Free projects, export/accessibility | COLOR-01–12 |
| 7 | [Games preservation and polish](2026-10-27-tintatlas-games-preservation-polish.md) | Baseline repair, five IDs/migrations, lifecycle sessions, tutorials/preferences, per-game polish | GAME-01–13 |
| 8 | [Quality and release preparation](2026-10-27-tintatlas-quality-release.md) | Accessibility/localization/device matrix, privacy/security/performance, store/signing drafts, core candidate | A11Y, L10N, DEVICE, UXQA, QUALITY, REL |
| 9a | [Conditional smart masks](2026-10-27-tintatlas-smart-mask-conditional.md) | Evidence gate and disabled-by-default proposal framework; enabled candidate only after valid human corpus | Conditional MASK, EXTMASK |
| 9b | [AdMob and final release](2026-10-27-tintatlas-admob-final-release.md) | UMP, adaptive banners, approved placements, no-fill behavior, post-ad final verification | ADS, FINAL |

Post-launch ILL-14/15, LEARN-09/10, COLOR-13/14, Phase 14, and Deferred COLOR-15 are not hidden inside these launch plans. They require later plans after v1 evidence.

## Requirement coverage ledger

This table is the mechanical no-omission index. An implementation worker must keep the referenced requirement IDs in the linked plan and record acceptance evidence against the same IDs in `docs/release/verification-ledger.md`.

| Requirement IDs | Disposition | Owning plan |
|---|---|---|
| BASE-01, BASE-02, BASE-03, BASE-04, BASE-05, BASE-06, BRAND-01, IDENTITY-01, SUPPORT-01 | Launch | Foundation, shell, and data |
| SHELL-01, SHELL-02, SHELL-03, SHELL-04, SHELL-05, SHELL-06, SHELL-07, SHELL-08, SHELL-09, SHELL-10, SHELL-11, SHELL-12, SHELL-13 | Launch | Foundation, shell, and data; route-wide completion closes in Quality |
| DATA-01, DATA-02, DATA-03, DATA-04, DATA-05, DATA-06, DATA-07 | Launch | Foundation, shell, and data plus each durable feature plan |
| ROOM-01, ROOM-02, ROOM-03, ROOM-04, ROOM-05, ROOM-06, ROOM-07, ROOM-08, ROOM-09, ROOM-10, ROOM-11, ROOM-12 | Launch | Real-room projects |
| MASK-01, MASK-05, MASK-06, MASK-08, MASK-11 | Launch | Manual mask correction |
| MASK-02, MASK-03, MASK-04, MASK-07, MASK-09, MASK-10, MASK-12, EXTMASK-01 | Conditional v1 | Conditional smart masks; controls remain absent if its evidence gate fails |
| ILL-01, ILL-02, ILL-03, ILL-04, ILL-05, ILL-06, ILL-07, ILL-08, ILL-09, ILL-10, ILL-11, ILL-12, ILL-13 | Launch | Illustrated Rooms v2 |
| LEARN-01, LEARN-02, LEARN-03, LEARN-04, LEARN-05, LEARN-06, LEARN-07, LEARN-08, LEARN-11, LEARN-12, LEARN-13 | Launch | Color Learning |
| COLOR-01, COLOR-02, COLOR-03, COLOR-04, COLOR-05, COLOR-06, COLOR-07, COLOR-08, COLOR-09, COLOR-10, COLOR-11, COLOR-12 | Launch | Coloring Studio |
| GAME-01, GAME-02, GAME-03, GAME-04, GAME-05, GAME-06, GAME-07, GAME-08, GAME-09, GAME-10, GAME-11, GAME-12, GAME-13 | Launch | Games preservation and polish |
| A11Y-01, A11Y-02, A11Y-03, A11Y-04, A11Y-05, L10N-01, L10N-02, L10N-03, DEVICE-01, DEVICE-02, DEVICE-03, DEVICE-04, UXQA-01 | Launch | Quality and release preparation |
| QUALITY-01, QUALITY-02, QUALITY-03, QUALITY-04, QUALITY-05, QUALITY-06, QUALITY-07, REL-01, REL-02, REL-03, REL-04, REL-05, REL-06, REL-07, REL-08, REL-09 | Launch | Quality and release preparation |
| ADS-01, ADS-02, ADS-03, ADS-04, ADS-05, ADS-06, ADS-07, ADS-08, ADS-09, ADS-10, ADS-11, FINAL-01, FINAL-02, FINAL-03, FINAL-04, FINAL-05 | Launch after core freeze | AdMob and final release |
| MASK-13, ILL-14, ILL-15, LEARN-09, LEARN-10, COLOR-13, COLOR-14, POST-01, POST-02, POST-03, POST-04, POST-05 | Post-launch | Explicitly excluded from v1 execution; write a later evidence-led plan |
| COLOR-15 | Deferred | Requires a new approved design; no freehand implementation in this plan set |

Coverage audit command after any plan edit:

```bash
dart run tool/check_plan_coverage.dart \
  docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md \
  docs/superpowers/plans/2026-10-27-tintatlas-*.md
```

Plan 01 creates `tool/check_plan_coverage.dart`; until then, use `rg` to compare the 161 unique requirement IDs in the approved spec against this plan set. A launch requirement may not disappear merely because its implementation is blocked; its plan must state the owner, gate, and safe fallback.

## Dependency graph

```text
01 Foundation/Shell/Data
 ├── 02 Real-room Projects ── 03 Manual Masks ── 09a Smart Masks (conditional)
 ├── 04 Illustrated Rooms v2 ───────────────┐
 ├── 05 Color Learning ─────────────────────┼── 08 Quality/Release Prep ── 09b Ads/Final
 ├── 06 Coloring Studio (uses region contract from 04)
 └── 07 Games Preservation/Polish
```

- Plans 02, 04, 05, and 07 may run in parallel only after Plan 01 freezes route, localization, storage, and ownership interfaces.
- Plan 03 consumes the Room project schema from Plan 02.
- Plan 06 consumes the shared region geometry/transform contract frozen by the pilot in Plan 04.
- Plan 08 starts route-by-route audits early but cannot close until Plans 02–07 finish.
- Plan 09a is optional for v1 exposure and may start only after the external freeze gate; failed evidence keeps controls absent.
- Plan 09b is always last for the planned monetized release, and all final checks rerun after the exact ad SDK/configuration.

## Execution checklist

- [ ] **M0: Create an isolated execution worktree and evidence ledger.** Invoke `superpowers:using-git-worktrees` at execution time; preserve the current dirty `lib/main.dart` in the original workspace and record branch/HEAD/status plus the observed baseline.
- [ ] **M1: Execute Plan 01 and freeze shared contracts.** Do not open feature milestones until four-root navigation, storage-root compatibility, schema ownership, l10n infrastructure, and adaptive breakpoints pass.
- [ ] **M2: Execute Plan 02, then Plan 03.** A real-room project must survive reopen before adding durable manual edit history.
- [ ] **M3: Execute Plans 04–07 at their dependency-safe boundaries.** Each plan has its own focused suite and commit sequence; never combine migrations from two repositories in one review task.
- [ ] **M4: Decide conditional smart-mask inclusion.** Run the exact external evidence gate; either execute the enabled path in Plan 09a or record the disabled-feature fallback.
- [ ] **M5: Execute Plan 08 and freeze the ad-free core candidate.** Resolve every P0/P1 issue, all launch-route overflow/semantics findings, and store/privacy mismatches.
- [ ] **M6: Execute Plan 09b with test IDs.** Integrate only banner placements in its allowlist, then rerun all shared and platform-specific gates.
- [ ] **M7: Present release evidence.** Report artifact IDs, version/build, tests/builds/devices, migrations, disclosures, known limits, rollout/rollback; wait for explicit publication authorization.

## Milestone completion record

For every milestone, append to `docs/release/verification-ledger.md`:

- task/commit identifiers and exact paths;
- schema version and migration fixture results;
- focused/full command plus exit code and test count;
- responsive/accessibility/device evidence required by that risk;
- remaining known limitations and whether they block the next plan;
- independent reviewer findings and their resolution.

No checkbox in this index is complete merely because its code was written; the linked plan exit gate and current verification evidence are mandatory.
