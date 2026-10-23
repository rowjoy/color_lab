# Mixer ingredient picker — delegated Task3 presentation subtask

Implement only `lib/features/mixer/presentation/mixer_color_picker.dart` and scoped tests `test/features/mixer/presentation/mixer_color_picker_test.dart`, plus `docs/superpowers/plans/mixer-picker-report.md`. Root owns MixerScreen/Lab/router and integration tests; other agents own math/state. Read `docs/superpowers/specs/2026-10-21-color-mixer-design.md` for overall intent; no need to read the entire implementation plan.

## Exact API

- `Future<RgbColor?> showMixerColorPicker(BuildContext context, {RgbColor? initialColor})`, presenting a root-navigator modal bottom sheet with existing AppMotion, safe area, scroll/keyboard insets and bounded height. Cancel returns null, selection returns the actual chosen RGB. No navigation after disposal or draft/state mutations.
- Public `MixerColorPicker({super.key, RgbColor? initialColor})` presentation widget; root wrapper supplies/uses it. Watch raw `colorHistoryProvider`, not the global filteredColorsProvider. Do not change historyFilterProvider or history data.
- Manual field key `mixer-hex-input`; initial value initialColor.hex or#6C5CE7; button `Use this color`, validating existing RgbColor.fromHex with trim and safe inline invalid-HEX feedback. Close tooltip `Close color picker` returns null.
- A separate saved-library local search field key `mixer-library-search`, case-insensitive name/HEX filtering. Saved tiles keyed `mixer-saved-${saved.hex}`, tap returns its parsedRGB directly. Saved list must scroll/bound height rather than rendering unbounded sheet. Empty library/no matches get friendly text and manual entry stays enabled.
- Failed library load shows safe message + `Retry library` calling the existing controller retry; manual input remains usable. Do not expose raw exceptions or block picker on history availability.

## Quality/tests

English/offline, existing theme/tokens/sharedbuttons and48dp targets, readable contrast in both themes,360px at2x text and short landscape/keyboard usable. No platform/native permission calls/new dependencies/coreexports. Tests use real widget and repository boundary from test/support/in_memory_color_history_repository.dart; override directory/provider boundaries where needed to avoidnativeIO. Observe missing-file or behavior RED, then GREEN. Cover manualinvalid/shortHEX/initialedit, actualsavedcolor selection/localname+HEXsearch, globalfilterunchanged,cancel,loading/error+retry+manualfallback,empty/no-match,large-text/lightdark. Do not add root route or mixerprovider dependencies. No subagents/Git. Report exactcommands/redgreen/results/files/concerns to report path, final<=15lines.
