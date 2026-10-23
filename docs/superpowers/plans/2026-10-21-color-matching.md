# Color Matching Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an offline five-round HSL color-matching game scored by CIE76 delta-E.

**Architecture:** Pure scoring/target generation, immutable transition model and retained injectable Riverpod controller; independent guarded screen with existing design controls. Diagnostic previews and cumulative delivery complete this module.

**Tech Stack:** Existing Flutter/Dart/Riverpod/go_router and dart:math; no new packages.

**Spec:** `docs/superpowers/specs/2026-10-21-color-matching-design.md`.

## Global Constraints

- English UI, offline, Android minimumSDK24/iOS-ready. No new dependencies, native changes, storage schemas, timers, account or network services.
- Exactly five distinct targets, HSL saturation .35–.90/lightness .25–.75. Score is round(clamp(100−CIE76 delta-E of displayed RGB,0,100)). Exact-match wording requires RGB equality, not rounded score/error.
- Hide target values until Submit. Preserve hue/saturation coordinates through neutral/endpoints. Editing→feedback→next round/complete is guarded; submitted attempts never mutate or duplicate.
- Retain session only; in-progress restart confirmed, completed Play again creates new game. Other drafts/history/palettes and all seven earlier ZIPs remain untouched.
- Existing tokens/shared controls,48dp targets,360px/2× text, light/dark and reduced motion. No medical/vision diagnosis claims; vision plates are next module.
- No Git repo: work in place, no init/commits/destructive operations. Baseline `/private/tmp/color-lab-matching-baseline.eVdpa3` comes from Harmonies archive. Immediate Next workflow continues without another approval prompt.

## Review Focus

- A rounded100 score or0.00 displayed error must not falsely announce exact match; literal near-match score/label tests (Tasks1/2).
- Hue changes at S=0/L endpoints must survive when chroma returns, not reset from RGB/HSL canonicalization (Tasks1/2).
- Repeated submit/advance, slider callbacks after submit and stale restarts must not add attempts or skip an unsubmitted round (Tasks1/2).
- Target values must not leak via visible/semantic HEX or tappable details before Submit (Task2).
- Navigation/theme changes and history failures must not reset the game or other retained drafts (Task2); no storage/plugin dependency in core/controller (Task1).

### Task 1: Pure scoring, target generation and retained game — delegate

**Files:** create `lib/core/color/color_matching.dart`, export in `color_engine.dart`; `lib/features/color_test/domain/matching_game.dart`; `lib/features/color_test/application/matching_game_controller.dart`; tests at matching core path and `test/features/color_test/{domain,application}/`.

**Exact interfaces:**

- `int matchingScore(double deltaE)` rejects negative/nonfinite; rounds clamped100−deltaE.
- `List<RgbColor> generateMatchingTargets({Random? random})`: always five unique display RGBs, unmodifiable. Hue uses randomoffset and bins72° apart, each plusrandom0..<36°, wraps360. S=.35+.55*randomDouble, L=.25+.50*randomDouble; shuffle with sameRandom. No unbounded retries. Existing HslColor/RgbColor math, no copies of conversion functions.
- `enum MatchingPhase { editing, feedback, complete }`.
- Immutable `MatchingAttempt({required RgbColor target,required RgbColor guess})`, final target/guess/deltaE/score, `bool get isExact` RGB equality. No floating-point threshold claims.
- Immutable `MatchingGame.start(Iterable<RgbColor> targets)` validates exactly five unique colors, snapshots once unmodifiable. Private full constructor; final targets, roundIndex, hue, saturation, lightness, attempts, phase. Public getters `RgbColor get target`, `RgbColor get guess` from retained coordinates, `int get roundNumber`, `MatchingAttempt? get currentAttempt` (feedback only), `int get totalScore`, `double get averageScore` (0 if no attempts).
- `MatchingGame setHue(double value)`, `setSaturation(double)`, `setLightness(double)` validate finite range hue[0,360), others[0,1], even if frozen; editing only returns updated state, other phases return identical state. Preserve independent raw coordinates, do not derive them from neutral RGB. `MatchingGame submit()` editing only creates one frozen attempt using actual target/guess then feedback; others identical. `MatchingGame advance()` feedback only; round1–4 advance/reset guess(0,0,.5), fifth feedback→complete retaining fifth guess; other phases identical. No auto-advance on submit.
- `typedef MatchingTargetGenerator = List<RgbColor> Function();`; `matchingTargetGeneratorProvider: Provider<MatchingTargetGenerator>` default closes over `generateMatchingTargets()`; retained `matchingGameProvider: NotifierProvider<MatchingGameController,MatchingGame>`. build calls read(generator) once. Methods `void setHue(double)`,setSaturation,setLightness,submit,nextRound,restart. Restart creates/validates replacement before state publication. No watch-triggered resets, storage, asynchronous work or custom public testing hooks.

- [x] Tests first/RED: literal scores0→100,.49→100,.51→99,20→80,100/150→0 and invalid values. Actual red/green ΔE≈170.565242 and score0, black/white≈100/score0; exact RGB score100, a very close nonidentical RGB may round100 but isExactfalse. Seeded generator reproducibility/bounds/uniqueness/immutable and constantRandom boundary generation terminates. Initialguess#808080, rawHue240 across S=0 and L=0/1 then restoredS/L produces#0000FF. Full five-round guards/attemptfreeze/count/total/average, invalid inputs, immutable snapshots and single-use iterable capture. Provider transitions, retained listener removal, independent containers, restart new targets without modifying other providers.
- [x] Implement exact interfaces; focused tests/analyze/format, then one fullsuite (report transient sibling import failures by name, never edit siblings). Report `docs/superpowers/plans/matching-task-1-report.md` with actual RED/GREEN, files/limits. No subagents/Git/native/package/UI edits.

### Task 2: Matching screen, routing and behavioral tests — delegate

**Files:** create `lib/features/color_test/presentation/matching_screen.dart`, optionally focused `matching_results.dart` if needed; modify existing Lab screen and `routing/app_router.dart`; create `test/features/color_test/presentation/matching_integration_test.dart`.

**Consumes:** all Task1 interfaces exactly. Missing core files are not permission to create temporary duplicate types. Task1 generator provider can be overridden with deterministic target lists in tests; use actual game/controller otherwise.

**Pinned comparison clarification:** Keep a compact two-swatch Target/Your match comparison visible while scrolling to Lightness at360px, including2× text. Use adaptive natural height and theme tokens, no hidden target values or separate state. Add a behavioral test that scrolls the real screen to Lightness and asserts both displayed colors remain visible before implementing the pin. Full shared tiles and after-submit detail actions remain unchanged; no API additions.

- [x] Write tests before implementation/observe missingfeatureRED. FullColorLabApp with realrouter, completedmemorypreferences/history. Literal targetfixtures red/green/blue/cyan/yellow. Verify LabCTA route/guard, submitgrey→red score/error compare knownliteral numeric fixture, hiddenHEX/semantics/no detailtap beforeSubmit, actualRGBguesswhenusing real sliders, frozen sliders/repeatedSubmit safeguards, target/match details onlyafter and correct sourceLab/save/Roomtarget, five-round summary total/average and Playagain, restartcancel/confirm, routeBack/reentry/theme preserve game+oldHSL/Mixer/Formula/Harmonydrafts, historyloadfailuredoesnotblockplay, light/dark360px2×reducedmotion nooverflow, exact-wordingnotrounded100.
- [x] Implement guarded `/matching`, LabCTA `Play color matching` (key`open-matching`) after Harmonies; replace obsolete gamecoming copy with visionplatescoming copy. Editor screen key`screen-Matching`, title`Color matching`, game`Round N of 5`, retained target/guess swatches no hints pre-submit. Reuse `ColorSwatchTile` with hex hint`Hidden until you submit` and onTapnull beforefeedback, no nearestnames. Keys`matching-target`,`matching-guess`; aftersubmit giveactualHEX and commondetailsLab onTap. Existing LabeledSliders keys`matching-hue`,`matching-saturation`,`matching-lightness`, Hue0..359.999; labelpercent. Editingbutton`Check my match`key`matching-submit`; feedback`Next round`or`See results`key`matching-next`; ΔE/scoresemanticsliveRegion true, digital/medicalgamecaveat, exactmatchonlyattempt.isExact. Disable sliders feedback; no programmaticreset fromswatchanimations.
- [x] Summary uses fixedattemptsnapshots actualRGBpairs+roundscore/error, total/500andaverage/100, `Play again`key`matching-play-again`. Optional focusedresultwidgetreceives MatchingGame withphasecomplete only. Completedresult nottimer/autotransient. `Restart game`key`matching-restart` editing/feedback with rootmodalconfirm, tokenforeground48dpbuttons/reducedmotion; `confirm-matching-restart`. Confirmation cancellation/systemBack keepsdraft. AppBarBack popselsegoLab andneverresets. Other features unchanged; no common-details refactor or storage dependency.
- [x] Focused tests/analyze/format then onefullsuite; self-review actualdiff and fullreport `docs/superpowers/plans/matching-task-2-report.md`. No subagents/Git/packages/native/renderer/README/otherdelegateedits. AnnounceAPIreadybeforefinalfullsuite.

### Task 3: Previews, reviews, docs and cumulative delivery — root

**Files:** `tool/render_previews.dart`, README, currentmodule design/plan/progress/review reports; cumulativeZIP`dist/color-lab-matching-2026-10-21.zip`.

- [x] Extend diagnostic renderer using actual matching controller/screen with deterministictargetgenerator fixture. Preserve68existingcaptures. Add editing/feedback/summary/restartmodal both themes and360px2×reducedmotion editing/feedback/results. Inspectactualimages, no overflow/hit-test warnings.
- [x] Independent task reviews consume brief/report/fullscopebaseline diff, fixes via originalimplementers +scopedrereview; finalwholemodulemostcapablereview. Freshfullsuite, analyzer,format,APK andrenderer proof. No user/device data clearing or installations.
- [x] README howtoplay/scoreformula/exactvsrounded, boundedtargets/sessionreplay/medicalcaveat, sourcetree, nonewpkg/native/schema, actualtestcount/previewcount, sourcehandoff. Preserve sevenpriorZIPs. Validatearchiveintegrity/requiredsources/licensenotices/excludedlocalgeneratedfiles. Nextmodule Colorvisionplates, do notstartnow.
