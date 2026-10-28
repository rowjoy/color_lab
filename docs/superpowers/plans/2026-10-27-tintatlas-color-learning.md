# TintAtlas Color Learning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the existing color tools into an offline, accessible six-lesson learning path with durable progress, concept checks, and a typed Experiment Notebook that can reopen exact tool state.

**Architecture:** Keep lesson content as versioned in-app data, keep learner state in one installation-local Hive repository, and adapt the existing Lab, Mixer, Harmonies, Formula, and Matching providers through typed experiment snapshots. Learning owns education state; it may copy colors into other features but never owns game rewards or source palette records.

**Tech Stack:** Flutter Material 3, Riverpod, GoRouter, Hive, existing color-domain types/controllers, generated Flutter localization, Flutter unit/widget tests.

**Spec:** `docs/superpowers/specs/2026-10-27-tintatlas-full-product-design.md` (LEARN-01–08 and LEARN-11–13)

## Execution status — 2026-10-28

Plan 06 production coding for Tasks 1–8 is complete on branch `TintAtlas` and
remains unstaged/uncommitted for the user to commit. No new planning or release
document was created. The existing schema registry and verification ledger were
updated in place.

| Task | State | Implemented / focused evidence |
| --- | --- | --- |
| 1 — strict schemas | done | Immutable lesson/library and five typed experiment schemas; strict canonical decoding, future-version retention, immutable mixer lists, and equality/hash contracts have focused passing coverage. |
| 2 — repository | done | Independent `learning_library_v1` rows, isolated corruption, serialized flush/rollback, reopen/concurrency/double-close, local-data ownership and isolation; focused repository/schema/storage gate passed 21/21. |
| 3 — six lessons | done | Exact six-topic catalogue, six-stage loops, two checks per lesson, complete generated English copy, scientific boundaries and nonvisual instructions; focused catalogue/localization gate passed 8/8. |
| 4 — controllers | done | Durable/visible/saving/error state, legal progress, free retry, revision archive, reset, notebook save/delete and failed-write retry; focused controller failures were fixed and retried only at failure scope. |
| 5 — UI | done; full matrix deferred | Learn/Experiment/My Work, lessons, concept checks, glossary, notebook, real-tool detour, confirmed reset, save/delete error Retry and responsive scrolling. Focused widget cases pass; the full device/RTL/200% matrix remains a final verification gate. |
| 6 — adapters | done | Lab/Mixer/Harmonies/Formula/Matching exact capture and restore, canonical routes, unknown-version rejection and no game reward mutation; original restore/controller gate passed 42/42 and the new five-tool capture case passes. |
| 7 — routes/bridges | done | Canonical/deep-link routes, loop-free legacy Lab redirect, safe invalid IDs, stale-route guard, My Work integration, source-independent palette copy, Illustrated dirty-draft guard and Coloring unavailable contract; focused route/bridge/shell cases pass. |
| 8 — boundaries/close | code done; repository-wide gates deferred | Vision is optional/non-diagnostic and exposes no match score; all 36 lesson stages retain non-color alternatives. Focused accessibility/Vision cases pass and fresh review findings were resolved. |

Per the user's verification budget, repository-wide analyze/full test,
Android/iOS builds and native/manual device gates remain deferred until Plans
01–08 are all complete. Commit steps remain unchecked because the user owns
commits.

## Global Constraints

- Read the master and Foundation plans first; do not begin until route, localization, schema, ownership, and adaptive-layout contracts are frozen.
- Learning progress, answers, notebook entries, and practice explanations are installation-local shared-library data; a game profile may neither own nor delete them.
- Six launch lessons are fixed: color coordinates, hue, saturation, lightness/value, digital mixing, and palette relationships.
- Every lesson follows Predict → Manipulate → Observe → Explain → Apply → Check; free retry never locks completion.
- Scientific copy must distinguish digital interpolation from pigment mixing, formulas from paint recipes, harmony from universal beauty, and delta-E points from diagnostic accuracy.
- Vision plates remain optional, non-diagnostic, and irrelevant to curriculum completion.
- Core completion cannot depend only on subtle color discrimination; every activity has names, numbers, shapes, text, or controls that communicate the same state.
- LEARN-09 and LEARN-10 are post-launch; do not silently add advanced tracks or Contrast and Context to this launch plan.

## Review Focus

- An app restart, repository reopen, write failure, or content revision cannot silently lose acknowledged progress or notebook records.
- Reopening each experiment recreates its exact tool state without mutating a saved color or palette source.
- Lesson copy and answer explanations stay truthful about color models and the limits of the tools.
- Room models, camera, account, consent, and network are never prerequisites for Learn.
- Compact landscape, 200% text, RTL, keyboard navigation, reduced motion, and screen readers can complete every core step.

---

### Task 1: Define strict learning, progress, and experiment schemas

**Files:**
- Create: `lib/features/learning/domain/learning_content.dart`
- Create: `lib/features/learning/domain/learning_library.dart`
- Create: `lib/features/learning/domain/experiment_snapshot.dart`
- Create: `test/features/learning/domain/learning_content_test.dart`
- Create: `test/features/learning/domain/learning_library_test.dart`
- Create: `test/features/learning/domain/experiment_snapshot_test.dart`

**Interfaces:**

```dart
enum LearningTopic { colorCoordinates, hue, saturation, lightnessValue, digitalMixing, paletteRelationships }
enum LearningStepKind { predict, manipulate, observe, explain, apply, check }
enum ExperimentTool { lab, mixer, harmonies, formula, matching }

final class LearningLesson {
  final String id;
  final int revision;
  final LearningTopic topic;
  final String titleKey;
  final String summaryKey;
  final List<LearningStep> steps;
  final List<ConceptQuestion> questions;
}

final class LessonProgress {
  final String lessonId;
  final int lessonRevision;
  final int currentStepIndex;
  final Set<String> completedStepIds;
  final Map<String, QuestionResponse> answers;
  final bool completed;
  final DateTime updatedAt;
}

final class PracticeAttempt {
  final String id;
  final String lessonId;
  final String activityId;
  final String answerId;
  final bool correct;
  final String explanationKey;
  final DateTime attemptedAt;
}

final class LearningLibrary {
  final int schemaVersion;
  final Map<String, LessonProgress> progressByLesson;
  final List<PracticeAttempt> practiceHistory;
  final Set<LearningTopic> topicsToRevisit;
  final List<ExperimentRecord> experiments;
}

sealed class ExperimentSnapshot {
  ExperimentTool get tool;
  Map<String, Object?> toMap();
}
```

Add strictly decoded `LabExperimentSnapshot`, `MixerExperimentSnapshot`, `HarmonyExperimentSnapshot`, `FormulaExperimentSnapshot`, and `MatchingExperimentSnapshot`; `ExperimentRecord` stores title, optional lesson ID, input/result HEX snapshots, typed payload, observation, and timestamps.

- [x] **Step 1: Write RED schema tests.** Cover exact schema/version keys, duplicate IDs, invalid step order, two-or-three-question rule, malformed HEX/model payloads, UTC timestamp round trips, and unknown-version preservation.
- [ ] **Step 2: Run `flutter test --no-pub test/features/learning/domain --reporter expanded`.** Expected: FAIL because the domain does not exist.
- [x] **Step 3: Implement immutable value types and strict `toMap`/`fromMap` decoders.** Reject malformed records explicitly; never coerce a different experiment tool's payload.
- [x] **Step 4: Re-run the focused domain suite and `dart format --output=none --set-exit-if-changed lib/features/learning test/features/learning`.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: define color learning domain"`.

### Task 2: Add the durable learning repository and migration boundary

**Files:**
- Create: `lib/features/learning/domain/learning_repository.dart`
- Create: `lib/data/db/hive_learning_repository.dart`
- Create: `test/support/in_memory_learning_repository.dart`
- Create: `test/data/db/hive_learning_repository_test.dart`
- Modify: `lib/data/schema/schema_registry.dart`
- Modify: `docs/release/schema-registry.md`
- Modify: `lib/data/storage/local_data_manager.dart`
- Modify: `test/data/storage/local_data_manager_test.dart`

**Interfaces:**

```dart
final class LearningChange<T> {
  final LearningLibrary state;
  final T value;
}

final class LearningLoadResult {
  final LearningLibrary library;
  final List<CorruptRecord> corruptRecords;
}

abstract interface class LearningRepository {
  Future<LearningLoadResult> load();
  Future<LearningChange<T>> transact<T>(
    LearningChange<T> Function(LearningLibrary current) transition,
  );
  Future<void> close();
}
```

Register a new independent `learning_library_v1` schema under `LocalDataScope.sharedLibrary`; writes are serialized and flushed before success, and a corrupt entry is returned in `LearningLoadResult.corruptRecords` without erasing or hiding healthy entries.

Register `LocalDataCategory.learningProgress` preview/delete for progress, answers, practice explanations, and notebook entries only; other shared libraries and every game profile remain byte-identical.

- [x] **Step 1: Write RED durability tests.** Cover reopen, concurrent transitions, flush failure, last-acknowledged-state retention, one corrupt notebook/progress record, unknown versions, and double close.
- [ ] **Step 2: Run `flutter test --no-pub test/data/db/hive_learning_repository_test.dart --reporter expanded`.** Expected: FAIL.
- [x] **Step 3: Implement the repository, in-memory fake, registry entry, and explicit decoder/migration path.** Keep visible draft state outside the repository until a transaction is acknowledged.
- [x] **Step 4: Prove ownership isolation.** Snapshot all non-learning boxes before a learning reset/delete and assert byte-for-byte equality afterward.
- [x] **Step 5: Re-run repository and schema tests.** Expected: PASS with no leaked Hive handles.
- [ ] **Step 6: Commit.** `git commit -m "feat: persist learning progress and notebooks"`.

### Task 3: Author and validate the six Color Foundations lessons

**Files:**
- Create: `lib/features/learning/data/color_foundations_catalog.dart`
- Create: `test/features/learning/data/color_foundations_catalog_test.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/l10n/localization_contract_test.dart`

**Interfaces:**

```dart
abstract final class ColorFoundationsCatalog {
  static List<LearningLesson> get lessons;
  static LearningLesson byId(String lessonId);
}
```

Each lesson has stable ID/revision, all six ordered step kinds, two or three concept questions with explanations for every option, glossary links, a nonvisual route through manipulations, and explicit scientific-boundary copy where relevant.

- [x] **Step 1: Write a RED catalogue validator.** Assert the exact six topics, globally unique lesson/step/question/answer IDs, required sequence, complete localization keys, free-retry explanations, nonvisual instructions, and no vision-plate dependency.
- [ ] **Step 2: Run the catalogue and localization tests.** Expected: FAIL for absent content/keys.
- [x] **Step 3: Author concise English lesson data and ARB strings.** Cover HSL, RGB/HEX, LAB, CMYK, harmony, mixing, formula, and delta-E context without overclaiming.
- [x] **Step 4: Generate localizations and rerun validation.** Run `flutter gen-l10n` followed by the focused tests; expected PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: add Color Foundations curriculum"`.

### Task 4: Implement lesson and library controllers

**Files:**
- Create: `lib/features/learning/application/learning_providers.dart`
- Create: `lib/features/learning/application/lesson_session_controller.dart`
- Create: `test/features/learning/application/lesson_session_controller_test.dart`
- Create: `test/features/learning/application/learning_providers_test.dart`

**Interfaces:**

```dart
Future<LessonProgress> openLesson(String lessonId);
Future<LessonProgress> setCurrentStep(String lessonId, String stepId);
Future<QuestionResponse> answerQuestion({required String lessonId, required String questionId, required String answerId});
Future<LessonProgress> completeLesson(String lessonId);
Future<void> resetLesson(String lessonId);
Future<ExperimentRecord> saveExperiment({required String title, required String? lessonId, required ExperimentSnapshot snapshot, required List<RgbColor> results, required String observation});
Future<void> deleteExperiment(String experimentId);
```

Controller state distinguishes `durable`, `visible`, `saving`, and `saveError`; a lesson revision mismatch preserves the prior attempt as history and explicitly starts the revised content.

- [x] **Step 1: Write RED controller tests.** Cover the legal step sequence, navigation back without loss, answer history/free retry, completion despite wrong answers, intentional reset confirmation, stale async writes, content revisions, save failure, retry, and provider disposal.
- [ ] **Step 2: Run `flutter test --no-pub test/features/learning/application --reporter expanded`.** Expected: FAIL.
- [x] **Step 3: Implement serialized controller transitions and Riverpod overrides.** Never infer mastery from game coins or erase durable state after a failed write.
- [x] **Step 4: Rerun controller plus repository tests.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: manage durable learning sessions"`.

### Task 5: Build Learn, lesson, concept-check, glossary, and My Work UI

**Files:**
- Modify: `lib/features/learning/presentation/learn_screen.dart` (replace the Foundation tool hub with the full learning hub)
- Create: `lib/features/learning/presentation/lesson_screen.dart`
- Create: `lib/features/learning/presentation/lesson_step_view.dart`
- Create: `lib/features/learning/presentation/concept_question_view.dart`
- Create: `lib/features/learning/presentation/learning_glossary_sheet.dart`
- Create: `lib/features/learning/presentation/experiment_notebook_screen.dart`
- Create: `lib/features/learning/presentation/learning_work_section.dart`
- Create: `test/features/learning/presentation/learn_screen_test.dart`
- Create: `test/features/learning/presentation/lesson_screen_test.dart`
- Create: `test/features/learning/presentation/experiment_notebook_screen_test.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Learn sections are exactly Learn, Experiment, and My Work.
- `LearningWorkSection` exposes read/open/delete callbacks for the shell-owned My Work screen.
- Manipulation widgets expose the same value as labeled text/numbers and keyboard-adjustable controls.

- [x] **Step 1: Write RED widget tests.** Assert resume state, all six lessons, each loop stage, explanation after every answer, unlimited retry, notebook empty/error/retry states, visible save failure, semantics/focus order, and no model/camera/network gate.
- [ ] **Step 2: Run the three focused presentation test files.** Expected: FAIL.
- [x] **Step 3: Implement adaptive screens with generated copy.** Use scrolling content and reachable overflow controls at compact landscape/keyboard inset; honor reduced motion.
- [ ] **Step 4: Run the responsive matrix at 320×568, 568×320, 600×960, and 1280×800 with default and 200% text, RTL, dark/high-contrast, and keyboard navigation.** Expected: PASS without overflow or clipped explanations.
- [ ] **Step 5: Commit.** `git commit -m "feat: add accessible Color Learning flow"`.

### Task 6: Convert Lab state and implement typed experiment restore adapters

**Files:**
- Create: `lib/features/lab/domain/lab_draft.dart`
- Create: `lib/features/lab/application/lab_controller.dart`
- Create: `lib/features/learning/application/experiment_restore_service.dart`
- Create: `test/features/learning/application/experiment_restore_service_test.dart`
- Modify: `lib/features/lab/presentation/lab_screen.dart`
- Modify: `lib/features/mixer/domain/mixer_state.dart`
- Modify: `lib/features/mixer/application/mixer_controller.dart`
- Modify: `lib/features/harmonies/application/harmony_controller.dart`
- Modify: `lib/features/formula/application/formula_providers.dart`
- Modify: `lib/features/color_test/application/matching_game_controller.dart`

**Interfaces:**

```dart
abstract interface class ExperimentRestoreService {
  Future<String> restore(ExperimentRecord record);
}
```

`restore` validates the typed payload, sets the matching existing provider, and returns one canonical experiment route. Mixer state gains a strict typed snapshot/restore path; harmonies reuse `setSelection`, Formula reuses `setColor`, and Matching restores a practice draft without awarding profile progress.

- [x] **Step 1: Write RED adapter tests for all five tools.** Assert exact HSL/mixer stops/harmony mode/formula target/matching target-guess-delta state, canonical route, unknown-version rejection, and no mutation of source saved colors/palettes.
- [x] **Step 2: Run the restore tests plus existing Lab/Mixer/Harmony/Formula/Matching controller suites.** Expected: new tests FAIL; record any genuine pre-existing failure in the ledger.
- [x] **Step 3: Move Lab's widget-local state into `LabController` and add the five snapshot adapters.** Keep existing tool behavior and semantics stable.
- [x] **Step 4: Rerun all focused suites and a repository reopen→restore integration test.** Expected: PASS.
- [ ] **Step 5: Commit.** `git commit -m "feat: restore typed color experiments"`.

### Task 7: Wire routes and cross-feature palette-copy bridges

**Files:**
- Modify: `lib/routing/app_router.dart`
- Modify: `lib/features/my_work/presentation/my_work_screen.dart`
- Modify: `lib/features/room_studio/application/illustrated_room_controller.dart`
- Future consumer, no edit in this plan: `lib/features/coloring/application/coloring_session_controller.dart` (Coloring Task 10 binds the frozen payload after that file exists)
- Create: `test/features/learning/learning_navigation_integration_test.dart`
- Create: `test/features/learning/learning_bridge_integration_test.dart`
- Modify: `test/routing/app_router_test.dart`

**Interfaces:**
- Canonical paths: `/learn`, `/learn/lesson/:lessonId`, `/learn/notebook`, `/learn/experiment/:experimentId`.
- Legacy `/lab` redirects to `/learn/experiment/lab` without a redirect loop.
- Bridge payload is `List<RgbColor>` copied by value plus a return location; it never contains a source record ID as the durable dependency.

- [x] **Step 1: Write RED route/deep-link/bridge tests.** Cover invalid IDs, Back restoration, lesson state retained across an Illustrated Room or Coloring detour, source deletion after copy, and My Work open/delete.
- [x] **Step 2: Run route and bridge tests.** Expected: FAIL.
- [x] **Step 3: Add routes, the Illustrated value-copy bridge, and the frozen payload contract.** Keep the Coloring destination adapter disabled behind feature availability until Coloring Task 10 consumes this contract; do not create a placeholder Coloring controller or a second payload type.
- [x] **Step 4: Run route, Learning, and Illustrated regressions plus a missing-Coloring availability test.** Expected: PASS; Coloring Task 10 later reruns and closes the cross-feature bridge test.
- [ ] **Step 5: Commit.** `git commit -m "feat: connect learning experiments to projects"`.

### Task 8: Enforce optional vision boundaries and close the milestone

**Files:**
- Modify: `lib/features/color_test/presentation/vision_screen.dart`
- Modify: `lib/features/color_test/application/vision_controller.dart` only if needed for non-diagnostic state
- Create: `test/features/learning/learning_accessibility_contract_test.dart`
- Modify: `docs/release/verification-ledger.md`

**Interfaces:**
- Vision routes are optional tools; their result exposes no diagnosis, accessibility score, curriculum credit, or completion prerequisite.

- [x] **Step 1: Write RED contract tests.** Assert vision activity cannot alter `LessonProgress.completed`, no result contains diagnostic/capability language, and every six-lesson core interaction has a non-color-only alternative.
- [x] **Step 2: Implement the minimum copy/navigation changes needed for the contract.** Do not redesign the plate generator in this milestone.
- [ ] **Step 3: Run `flutter test --no-pub test/features/learning test/data/db/hive_learning_repository_test.dart test/features/color_test --reporter expanded`.** Expected: PASS.
- [ ] **Step 4: Run `flutter gen-l10n`, format, scoped analyze, then the full repository test suite; record exact commands/counts and offline/manual accessibility evidence in the ledger.** No unexplained failure remains.
- [ ] **Step 5: Obtain a fresh read-only review against LEARN-01–08 and LEARN-11–13, resolve findings, and commit.** `git commit -m "test: verify TintAtlas Color Learning"`.

## Exit Gate

A fresh offline install can complete all six Foundation lessons, answer every concept check with free retry, save/reopen/delete typed experiments, restore all five tool states, copy a result into supported projects without losing lesson state, and complete the same core path with nonvisual alternatives. Learning works without Room models, camera, account, consent, ads, or network; repository reopen and failure tests are clean; LEARN-09/10 remain explicitly post-launch.
