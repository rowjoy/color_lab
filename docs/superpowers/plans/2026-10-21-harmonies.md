# Harmonies and Saved Palettes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add six-mode HSL harmonies and durable whole-palette collections without disturbing prior modules.

**Architecture:** Pure generation/session controller, separate Hive palette repository/controller, independent procedural wheel and integrated route/library presentation. Reuse manual/saved picker, common details and design controls.

**Tech Stack:** Current Dart/Flutter/Riverpod/go_router/Hive/path_provider only.

**Spec:** `docs/superpowers/specs/2026-10-21-harmonies-design.md`; supplied build document Phase2 Harmonies and6.6.

## Global Constraints

- English-only offline app chrome; Android minimum SDK24/iOS-ready code. No packages, native permissions, network calls or changes to existing history/preferences schemas.
- Six exact HSL relationships, base first/exact, duplicate RGBs collapsed; neutrals have no fabricated hue/distinct rotations. Monochromatic uses L offsets−.30,−.15,+.15,+.30 plus exact anchor, clamped0..1.
- Default Lilac#B2A4D4/Complementary, session base/mode retained; saved palettes persist exact ordered RGB snapshots, base/mode/name/UTC date. Duplicate base/mode preserves original snapshot/name/date.
- Existing tokens/shared controls,48dp interactive targets,360px/2x/light-dark/reduced motion. The wheel is a semantic read-only diagram; real swatches open details.
- Preserve camera awaited workflow, Formula/Mixer/HSL/Room/history/onboarding/settings. No games/vision tests, physical-pigment claims or room-photo work.
- No Git repo: work in current authorized project, keep user changes/all earlier ZIPs. Baseline source ZIP substitutes for commit diffs. Existing “Next” workflow authorizes scoped implementation without another approval prompt.

## Review Focus

- Achromatic/clamped colors must not produce fake duplicate palettes or pretend hue markers (Tasks1/3 neutral fixtures/semantics).
- Failed flushes must not publish Hive cache as durable success, even for duplicate/no-op branches or close retries (Task2 injected real-box flush tests).
- A save finishing after the user changes base/mode must persist the captured original recipe only, not label the new draft saved (Task4 delayed-write test).
- Common-details entry must preserve camera pause ownership and exact selected shade without same-route stacking (Task4 real-router/fake-camera and nested-entry tests).
- Palette retry/delete/open must not reset individual color filters/history or mutate stored snapshots, including after app-container restart (Tasks2/4 isolation and restart tests).

### Task 1: HSL harmony engine and session draft — delegate

**Files:** `lib/core/color/color_harmonies.dart`, export in color_engine.dart; `lib/features/harmonies/application/harmony_controller.dart`; tests `test/core/color/color_harmonies_test.dart`, `test/features/harmonies/application/harmony_controller_test.dart`.

**Exact APIs:**

- Enhanced `enum HarmonyMode { complementary('Complementary'), analogous('Analogous'), triadic('Triadic'), tetradic('Tetradic'), splitComplementary('Split complementary'), monochromatic('Monochromatic'); const HarmonyMode(this.label); final String label; }`.
- `List<RgbColor> generateHarmony(RgbColor base, {HarmonyMode mode = HarmonyMode.complementary})`. Unmodifiable, exact base object first, duplicates removed preserving order. HSL rotations after base: complementary[180],analogous[-30,30],triadic[120,240],tetradic[90,180,270],splitComplementary[150,210]. Mono after base L offsets[-.30,-.15,.15,.30], clamp0..1 with same hue/saturation. Reuse existing conversions, no duplicate math. Gray rotations collapse; colors remain opaque/display valid.
- `typedef HarmonyDraft = ({RgbColor base, HarmonyMode mode});` and `harmonyDraftProvider: NotifierProvider<HarmonyController,HarmonyDraft>` in harmony_controller.dart. Build base#B2A4D4/mode complementary. `void setBase(RgbColor)`, `void setMode(HarmonyMode)`, `void setSelection({required RgbColor base, required HarmonyMode mode})`; retain until container disposal, no storage writes or dependencies on palette models.

- [x] Write tests before implementation, observe RED. Literal pure-red fixtures: complement[#FF0000,#00FFFF],analogous[#FF0000,#FF0080,#FF8000],triadic[#FF0000,#00FF00,#0000FF],tetradic[#FF0000,#80FF00,#00FFFF,#8000FF],split[#FF0000,#00FF80,#0080FF]. Check independent mono lightness fixture and endpoints/clamps, hue wrap near360, neutral rotations singleton, immutable/dedup/exact anchor. Controller mode/base independence, combined selection, retained draft across listener removal/container isolation.
- [x] Implement exact owned APIs; focused tests/analyze/format then one full suite, reporting transient sibling failures without edits. Report RED/GREEN command/output, fixtures and files in `docs/superpowers/plans/harmonies-task-1-report.md`. No Git operations/packages/native/UI/storage edits or subagents.

### Task 2: Durable saved palette repository and providers — delegate

**Files:** `lib/features/palette/domain/{saved_palette,saved_palette_repository}.dart`, `lib/data/db/hive_palette_repository.dart`, `lib/features/palette/application/saved_palettes_providers.dart`; corresponding domain/repository/provider tests and `test/support/in_memory_saved_palette_repository.dart`.

**Exact APIs:** Consume Task1 HarmonyMode/generateHarmony and existing RgbColor through core export; do not create production stubs while pending.

- `SavedPalette({required String name, required RgbColor base, required HarmonyMode mode, required Iterable<RgbColor> colors, required DateTime createdAt})`. Fields id/name/base/mode/colors/createdAt; id derived by `static String idFor(RgbColor base,HarmonyMode mode) => '${mode.name}-${base.hex.substring(1)}'`; trim/reject blank name, UTC normalize, snapshot once to unmodifiable1..5 distinct colors with base first. Validate snapshot shape, do not regenerate stored colors in constructor/load. Value equality. `Map<String,Object> toMap()` and `factory SavedPalette.fromMap(Map<dynamic,dynamic>)` version1 keys version,id,name,base,mode,colors,createdAt; HEX strings canonical, known mode, strict UTC ISO date, id matches derived identity; reject unknown/malformed schema via FormatException.
- `abstract interface class SavedPaletteRepository { Future<List<SavedPalette>> load(); Future<SavedPalette> save({required String name,required RgbColor base,required HarmonyMode mode,required Iterable<RgbColor> colors}); Future<void> delete(String id); Future<void> close(); }`; `final class PaletteStorageException implements Exception` safe generic message with no raw path/data.
- `final class HivePaletteRepository implements SavedPaletteRepository`: static `open({required String directory,String boxName='color_palettes_v1',DateTime Function()? clock})` and `.fromBox({required Box<dynamic> box,DateTime Function()? clock})` taking ownership. Independent Hive registry like existing repositories, crashRecovery:false, avoid unhandled failed-open future; validate all records/key consistency, newest-first thenid sort, unmodifiable load. Serialize reads/writes/close; successful mutation includes flush. Failed-flush barrier must block reads/duplicate/no-op operations until durable. Preserve duplicate base/mode record exactly. Missing delete no-op. Closing/retry semantics same durable guarantees as existing history; no corruption clear/truncation or edits to working repositories.
- `paletteStorageDirectoryProvider: FutureProvider<Directory>` independent app-documents lookup; `savedPaletteRepositoryProvider: FutureProvider<SavedPaletteRepository>` opens `${documents.path}/color_lab`, closes on disposal and handles late initialization/disposal safely.
- `savedPalettesProvider: AsyncNotifierProvider<SavedPalettesController,List<SavedPalette>>`; `Future<SavedPalette> savePalette({required String name,required RgbColor base,required HarmonyMode mode,required Iterable<RgbColor> colors})`, `Future<void> deletePalette(String id)`, `void retry()`. Serialize mutations, reload/publish only after durable success, preserve last good list on mutation error, initial-load failure blocks edits, retry only invalidates failed directory/factory versus healthy repository load.
- Test-local `InMemorySavedPaletteRepository({Iterable<SavedPalette> palettes=const[]})` implements actual semantics, fields failLoad/failWrites, writeGate:Completer<void>?,closeCount/maxConcurrentWrites for UI tests; validated/deduped immutable entries, deterministic newest-first. This belongs in test/support only.

- [x] Write/observe RED for canonical serialization/invalid records/snapshot identity, disk reopen across fresh repo and two equal-named boxes in distinct directories, idempotent save, ordering, concurrent save/delete, failed save/delete flush blocks reads/duplicate/no-op until recovery, corrupt/unsupported data preserved, close retry; provider initial/factory/directory retry, serialized edits, failed writes keep committed state and disposal/late factory cleanup. Include fresh-container real-file reload of whole snapshot. Do not claim durability from a fake alone.
- [x] Implement owned files using existing Hive/path_provider; scoped tests/analyze/format and one full suite; report all failures rather than editing siblings. Full report `docs/superpowers/plans/harmonies-task-2-report.md`, exact RED/GREEN/evidence/files/limits. No Git/packages/native/UI/history/preferences edits or subagents.

### Task 3: Procedural harmony wheel — delegate

**Files:** `lib/features/harmonies/presentation/harmony_wheel.dart`, `test/features/harmonies/presentation/harmony_wheel_test.dart`.

**Interface:** `HarmonyWheel({super.key,required RgbColor base,required HarmonyMode mode,required List<RgbColor> colors})` stateless read-only diagram using code-native CustomPaint. Core types from Task1, existing theme tokens. No picker/controller/storage/root edits.

- Show a circular HSL hue ring (red at top0°, clockwise), markers filled with actual generated RGB colors and connecting hue relationships. Base remains identifiable. Monochromatic marker layout must distinguish its lightness shades rather than overpaint coincident same-hue dots. Neutrals have no fake hue angle: use a neutral/lightness indication instead and explain in readable text. Renderer may define focused geometry helpers if tested/needed, but no package/assets/global infrastructure.
- Layout adaptively within parent width (root max640); use theme neutral chrome and existing tokens. Base/mode/colors semantic description exposes actual HEX colors and neutral explanation, image not button; wheel has no interactive hit targets or fake drag affordance. Do not suppress text scaling or animate under reduced motion. Parent screen owns mode chips and tappable swatches.
- [x] Tests first/RED then meaningful render/semantic tests across six modes and both themes, achromatic and mono inputs,360px/2x/reducedmotion and no canvas/layout exceptions. Verify actual painter output changes with base/mode/colors and semantics list exact given shades; do not merely assert mocked widget existence. Scoped tests/analyze/format and one full suite with transient integration failures reported. Report `docs/superpowers/plans/harmonies-task-3-report.md`. No subagents/Git/root/shared-state edits.

### Task 4: Routes, harmony editor and saved library — root

**Files:** `lib/features/harmonies/presentation/{harmonies_screen,save_palette_dialog}.dart`, `lib/features/palette/presentation/{saved_palettes_section,saved_palettes_screen}.dart`; existing Lab/Palette screens, common color_explorer, router; integration tests `test/features/harmonies/presentation/harmonies_integration_test.dart`, previews/README/ledger.

- [x] Widget tests before implementation/RED: Lab/common-details exact selection, all-mode actual swatches, manual/saved base change/cancel and retained other drafts, neutral guidance, saving named palette/duplicate/cancel/write error, draft edit during gated save; collections load/retry/cards/detail/open/delete confirm/cancel; fresh real-file app restart restores saved whole snapshot; first-run routes; camera→details→harmonies→Back paused stream and fresh resample; same-route base update no stacking; correct swatch→details→Room;360px/2x/light-dark/reducedmotion.
- [x] Implement guarded `/harmonies` and `/palettes`, mode chips/wheel/swatches using exact Task1/3 APIs. Reuse existing return-only manual/saved picker. Save dialog captures current draft and validates nonblank name with80-grapheme UI limit, friendly durable errors/retry; no saved claim on failure or a different current draft. Individual swatches use common details/sourceLab; saved state derives from matching persisted id and snapshot, not an async stale boolean.
- [x] Common detail destination becomes private enum (neighbor replacement/Room/formula/harmonies), closes sheet first, sets current base, awaits typed harmony route unless already there. Retain awaited Formula route fix. Add Lab CTA and Palette third Palettes chip while keeping Saved/Studio keys and default behavior. Saved section uses stored snapshot, per-card swatch details, Open harmony (sets base/mode then pushes) and confirmed Delete palette; show load/error/empty/safe retries. Reuse section in full saved-palettes route; keep color history/filter state independent.
- [x] Independent task reviews and final whole-module review, resolve findings through tested fix waves. Verify full suite/analyzer/format/APK plus real-font harmony/wheel/library/narrow/picker/save-dialog previews both themes. README includes new tree, separate version1 box, idempotent save/snapshot/digital/session limitations, no package/platform additions and run commands.
- [x] Validate cumulative `dist/color-lab-harmonies-2026-10-21.zip`, preserve six earlier ZIPs and all user/device data; record exact results. Next module is Color matching game; do not start it here.
