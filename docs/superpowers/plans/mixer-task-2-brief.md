### Task 2: Immutable draft/controller — delegated

**Files:** Create `lib/features/mixer/domain/mixer_state.dart`, `lib/features/mixer/application/mixer_controller.dart`; tests `test/features/mixer/{domain,application}/`.

**Interfaces:**

- `MixerIngredient({required String id, required RgbColor color, double weight = 50})`, final fields, copyWith/value equality; nonblank id, finite weight0–100.
- `MixerState({required Iterable<MixerIngredient> ingredients, MixingSpace space = MixingSpace.lab})`, immutable snapshot of at least two entries with distinct IDs. `factory MixerState.initial()` returns ids `color-0`,`color-1`, Lilac#B2A4D4/Butter#E8DAA9 at50. `copyWith({Iterable<MixerIngredient>? ingredients, MixingSpace? space})`, equality.
- Public getters `ingredients`, `space`, `hasActiveColors`, `fractions:List<double>`, `labResult:RgbColor?`, `rgbResult:RgbColor?`, `selectedResult:RgbColor?`. All-zero ->zero fractions and null results; otherwise consume Task1 normalization/math APIs. Derived caching is allowed only within immutable state.
- `mixerProvider: NotifierProvider<MixerController,MixerState>`; `void addColor(RgbColor color)`, `void setColor(String id,RgbColor color)`, `void setWeight(String id,double weight)`, `void removeColor(String id)`, `void setSpace(MixingSpace space)`, `void reset()`. Minimum-two removal is a no-op; unknown/stale IDs are no-ops. Known invalid weights throw ArgumentError. New IDs monotonically unique; reset restores initial values/space without reusing previously added IDs. Retain draft until ProviderContainer ends, not across process restart.

- [ ] Write and observe RED for immutable snapshots/unique/minimum count; normalization/allzero; mode comparisons selecting correct output; add/remove/edit-by-ID after reorder/removal; zero/minimum endpoints; invalidweight rejection; reset and retained state across listeners.
- [ ] Implement using Task1's exact APIs (do not duplicate math); scoped tests/analyzer/report `docs/superpowers/plans/mixer-state-report.md`. No UI/root/routing/history edits or subagents.

