# Vision Plates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Original offline procedural dot activity with six responses and an honest non-diagnostic summary, without building an APK.

**Architecture:** Pure immutable patterns/session, retained injected controller, cached CustomPainter and guarded presentation. Root owns diagnostic previews/docs/source delivery.

**Tech Stack:** Existing Dart/Flutter/Riverpod/go_router, dart:math only; no new packages.

**Spec:** `docs/superpowers/specs/2026-10-21-vision-plates-design.md`.

## Global Constraints

- User explicitly says NO APK BUILD. No APK/native build/install/clean/data clearing. Preserve existing APK and eight prior ZIPs.
- English UI, offline, existing Androidmin24/iOS-ready source; no new dependencies/native source/assets/storage schemas/network/account/timers.
- Original generated dot graphics only: no copyrighted/clinical plates, no calibrated screening/diagnosis/normal-deficient/pass-fail/severity claims. Summary describes recorded responses only; persistent non-diagnostic caveat.
- Six plates, one-digit0–9 or explicit Not sure; no expected digit/answer-coded semantics before results. Plate-ID guard rejects stale responses; immutable snapshots and retained draft/session, separate from matching/history/palettes/other drafts.
- Existing tokens/shared controls,48dp,360px2×light/dark/reduced motion; actual diagram RGB stable both themes. No medical color accuracy claim, no heavy async/native work.
- No Git repo; work in place, no init/commits/destructive operations. Review baseline `/private/tmp/color-lab-vision-baseline.ndglOZ` extracted from Matching ZIP. Immediate Next workflow continues without another approval prompt.

## Review Focus

- Shape must be conveyed only by colors, not answer-dependent geometry/dot sizes or text/semantics (Tasks1/2).
- Stale/double callbacks must not answer a later plate; typed0 is valid, blank not a typed answer, Not sure is explicitnull (Tasks1/3).
- Number/seed/palette or cached painter state must not leak expected digits before results or retain the previous plate afteradvance (Tasks2/3).
- Results/replay/new plate must open visibly at top while typing/theme/navigation preserve state/offset (Task3).
- Counts must not imply diagnosis or silently erase/modify matching, history, palettes or Lab drafts; restart cancellation and results limits remain visible (Tasks1/3).

### Task 1: Pure plate generation, response session and controller — delegate

**Files:** `lib/features/color_test/domain/{vision_plate,vision_dot_pattern,vision_session}.dart`, `lib/features/color_test/application/vision_controller.dart`; corresponding `test/features/color_test/{domain,application}/vision*_test.dart`.

**Exact interfaces:**

- `enum VisionPalette { roseOlive, tealRose, blueSand }` with immutable `List<RgbColor> get figureColors`, `fieldColors` (three each); opaque neutral `final RgbColor visionPlatePaper`. Palette values are original illustrative swatch colors, never clinical calibration. Define fixed color values once; no duplicated math.
- Immutable `VisionPlate({required int number,required int seed,VisionPalette palette=VisionPalette.roseOlive})`, validates number0..9/seed0..0x7fffffff, final number/seed/palette, `String get id => '$number-${palette.name}-$seed'`; value equality/hash. Immutable `VisionDot({required double x,y,radius,required RgbColor color})`, validate finite normalized coordinates, radius>0..1, final x/y/radius/color, value equality/hash. Drawing consumes these fields, no test-only public hooks.
- `List<VisionPlate> generateVisionPlates({Random? random})`: unmodifiable six numbers from[2,3,4,5,6,8], shuffled; palette byindexmod3, seednextInt(0x7fffffff), bounded work, no rejection loops.
- `List<VisionDot> generateVisionDots(VisionPlate plate)`: unmodifiable deterministic circular32×32 grid; center=(col+.5)/32+(rng.nextDouble()*2−1)*.002, same forrow; radius=.009+.004*rng.nextDouble; retain only distance(center,(.5,.5))+radius<=.48. Geometry stream Random(seed), independent shade stream Random(seed+1); each accepted dot chooses one of three figure/field shades from mask membership. Geometry cannot depend on digit/palette. Original compact5×7 digit table supports0..9; glyph boundsx[.29,.71),y[.18,.82). Fix digit2 rows `01110/10001/00001/00010/00100/01000/11111`, digit8 rows `01110/10001/10001/01110/10001/10001/01110`; other basic digits original simple masks. No font/image/Flutter imports.
- `enum VisionStage { introduction, active, complete }`. Immutable `VisionResponse({required VisionPlate plate,required int? answer})` validatesnullable0..9, final plate/answer; `bool get matches` equalitywithnumber.
- Immutable `VisionSession.initial(Iterable<VisionPlate> plates)` snapshots exactly6 uniqueIDs once, introduction/responsesempty/draftnull. Private full constructor, final plates/responses/stage/draft (nullableint); getters currentIndex=min(responses.length,5), currentPlate, plateNumber=currentIndex+1, matchedCount, notSureCount. `VisionSession start()` introduction→active only. `VisionSession withDraft(int? value)` validates0..9/null thenactiveonly update. `VisionSession respond({required String plateId,required int? answer})` validatesanswer thenactive/currentid only, otherwiseidentical; snapshotsoneVisionResponse,clearsdraft,advancesnextorcompleteat6; no intermediatecorrectnessphase. Listsimmutable, no duplicate/staleadvance.
- `typedef VisionPlateGenerator=List<VisionPlate> Function();`; `visionPlateGeneratorProvider: Provider<VisionPlateGenerator>` default generateVisionPlates; retained `visionSessionProvider: NotifierProvider<VisionController,VisionSession>`. build reads generatoronce; voidstart,setDraft(int?), boolrespond({requiredplateId,required int? answer}) returnsaccepted; voidrestart() validatesreplacementbeforepublishing andstartsnewactive6set. No IO/storage/async/timer or generatorwatchresets.

- [x] Tests first/observedRED. Independent literal glyphcenter fixture: central(.5,.5)cell is field fordigit2 andfigure fordigit8; same seed/palette geometry identical acrossboth, not a shape-density cue. Bounds/countreasonable/nonoverlap samples/finite colors; same seed stable, newseedchanges, every supportedglyph renderssomefigure/field, three palettes/paper immutable. Seeded6generation/no duplicates/boundedconstantRandom. Invalidmodels/IDs/single-use iterable, nullvs0 responses, pendingdraft/intro/frozencompleteguards, staleplateIDdoublecallback rejection,6responses/counts/restart snapshots, controllercontainerretention/generatorread vswatch/atomicinvalidrestart/independent matchingandotherdrafts.
- [x] Implement owned APIs only; focused tests/analyze/format, onefullsuite naming all transient sibling failures if any; NO APK BUILD. Report `docs/superpowers/plans/vision-task-1-report.md` exactRED/GREEN/exits/files/limits. No subagents/Git/packages/native/UI/painter edits. Announce APIreadyafterfocusedGREEN.

### Task 2: Cached procedural plate CustomPainter — delegate

**Files:** `lib/features/color_test/presentation/vision_plate_view.dart`; `test/features/color_test/presentation/vision_plate_view_test.dart`.

**Consumes:** Task1 VisionPlate/VisionDot/generateVisionDots/visionPlatePaper exactinterfaces from Task1brief. No duplicate pending types.

- [x] Tests first/observedRED. Rasterize actual CustomPaint in themes, assert actual dot-center fills and paper/outer transparency, hidden maskchanges colors notgeometry, changedseed/digit/palette changes output, sameinput/theme stableactualRGB, resize/clipping/non-squareconstraints, 360px2×reducedmotion, noanimation/gesture, image semantics with no digit/seed/id or action hints. Use independent literalpalettefixture or actualknowncandidatepoints, not mocked painter existence. Dispose explicitsemantics handles withinbodytry/finally.
- [x] Implement `VisionPlateView({super.key,required VisionPlate plate})`, cachedpervalueplate in widgetstate, neverrandom/generate inpaint/themebuild. Adaptive square AspectRatio, CustomPaintonlycircles/paper, neutraledgechrometokensifneeded, no numeraltext/font/glyphoutline/hover/drag/pointer. Image semantics exactly `Generated dot pattern. Enter the number you see, or choose Not sure.`; excludesduplicatecaptionsemantics, nohiddenanswer. ActualRGB andpaperstablelight/dark; noanimations, interactivecontrolstaysparentUI. No bitmapassets/imagegen/clinicalclaim.
- [x] Focused tests/analyze/format andonefullsuite (reporttransientsbyname), NO APKBUILD. Report `docs/superpowers/plans/vision-task-2-report.md`, actualpixel/semantics evidence/limits. No subagents/Git/dependencies/root/otherdelegateedits. AnnounceAPIreadyafterfocusedGREEN.

### Task 3: Guarded activity, honest results and full-app flows — delegate

**Files:** `lib/features/color_test/presentation/vision_screen.dart` (optional focused`vision_results.dart`ifneeded); modify Lab screen/router only; `test/features/color_test/presentation/vision_integration_test.dart`.

**Consumes:** exactTask1model/controller andTask2`VisionPlateView`. Read theirbriefsforcontracts; do notcreatestubswhenpending. FullColorLabApprealroutertests with existingmemoryrepositories +injected6platefixture, actualmodel/controller/painter.

- [x] Tests beforeproductcode/REDrealLabCTA. Verify intro/nonclinicalcaveat/explicitStart andguardedroute, activehiddenanswersinclsemantics, numericinput0/blank/Not sure,draftretainedBack/reentry/theme, capturedplateIDstalesubmit/NotSurecannotanswernext,6realresponses/counts/neutralwording, resultsexpectednumberrevealedonlyafter, noautostorage/otherdraftchanges, restartconfirm/cancel/systemBack, explicitTryagainnewsetactive, latestcurrentplateimagechangednotstale, keyboarddismissaccepted, smallphonevisibleNext/results/replayentry(noensureVisibledestination),360px2×bothThemesreducedmotion inclrestartmodal andresults. No realAPK/nativebuild.
- [x] Implement root`/vision`, LabCTA`Explore vision plates`key`open-vision`aftermatching. Replaceobsoletevisioncomingcopywithnonclinicalcolorstudiescopy, keepotherexistingkeys/routes/drafts. Scaffoldtitle`Vision plates`, scrollviewkey`screen-Vision`, introStartactivitykey`vision-start`; activecounterPlateNof6, actual`VisionPlateView`key`vision-plate`, originaldotonlygraphic, TextFieldkey`vision-answer`digitsOnly/maxLength1/numerickeyboard/semanticslabel`Number you see`. Pendingdraftsyncproviderwithoutcursorjank; `Record answer`key`vision-record`validatesnonemptywith`Enter one digit, or choose Not sure.`; `Not sure`key`vision-not-sure`recordsnull. CaptureplateID/draft atbuttonbuild, onlyclearfield/error/unfocuswhencontrolleraccepts. Stalecallbackmustnotconsumeorclearthenewdraft. Scrollowned/disposed, resetonlystart/newplate/complete/newset, nevertyping/theme; BackpopselseLabwithoutreset.
- [x] Resultskey`vision-results`, listall6recordedpairs, labels`Generated number`/`Your response`, nullable`Not sure`; summary`X of 6 pattern matches`andNot surecount. Neutralchrome/nocolor-codedhealthsignals; noNormal/deficient/pass-fail/medicalclassification. `Try again`key`vision-try-again`explicitrestartactive. Active`Restart activity`key`vision-restart`rootmodalsharedtoken48dpbuttons,cancelpreservesdraft, confirmkey`confirm-vision-restart`, reducedmotion. Persistentcaveatallstages exactly: `Generated patterns for exploration only. This is not a validated screening test or medical diagnosis and cannot rule out a condition.` Intro/resultsalso`If you have concerns about your color vision, talk to an eye care professional.` No externalruntimecalls or copyrightimages; no answerdetailsbeforecomplete.
- [x] Focused tests/analyze/format thenonefullsuite namingtransients; fullreport `docs/superpowers/plans/vision-task-3-report.md` with actualRED/GREEN/exits/selfreview. NO APKBUILD; no subagents/Git/native/packages/renderer/README/otherdelegateedits. AnnounceAPIreadyafterfocusedGREEN.

### Task 4: Previews, reviews and source-only delivery — root

**Files:** `tool/render_previews.dart`, README,currentmodule docs; `dist/color-lab-vision-2026-10-21.zip`.

- [x] Extend actualrenderer with visionfixtureoverride, preserve82existingcaptures, addintro/active(all6patterns)/results/restart and360px2×active/results bothThemes; inspect legibility, actualoriginaldots, noinvisibleoverlap/leaks/clinicalclaims. Rootorpreview-onlydelegate owns tool/report.
- [x] Fresh scopedreviews forTasks1–3 usingbrief/report/fullbaselinediff; fixthroughoriginalimplementers andscopedrereview, mostcapablewholemodulefinalreview. Freshfullsuite/analyzer/formatter/renderer, **NO APKBUILD**. Existing APKhash unchanged from`1986b60e39c94af8bbc2bacb71b14dc7cf427899f3476ff60bbb581d56b12b2c`.
- [x] READMEhowto/disclaimer/sourceattribution/copyrightoriginality/session/input/staleguards/noAPKverification, exactchecks/newtree/noadditions/runcommands. SourceZIPvalidation requiredsource/tests/docs/licenses, excludedlocalgeneratedfiles; preserveeightpriorZIPs anddata. Phase2complete, nextRoomStudio planning notimplementationhere. Do notlinkexistingAPK asnewdelivery.
