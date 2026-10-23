# Harmonies preview report

Date: 2026-10-21

## Scope

Changed only `tool/render_previews.dart` and this report. The renderer continues
to use the actual application, harmony controller, harmony generator, wheel,
save dialog, and saved-palette library. A `savedPaletteRepositoryProvider`
override uses the existing `InMemorySavedPaletteRepository` so previews never
open native Hive palette storage.

The fixture is an actual `SavedPalette` named **Red complement**, with red
`#FF0000`, complementary mode, and the stored colors `#FF0000` / `#00FFFF`.
Save dialogs use unsaved lilac recipes so the actual editor save action is
enabled. No new raster assets, dependencies, native changes, or production
behavior changes were introduced.

## Verification

Command: `flutter test tool/render_previews.dart --no-pub`

Result: **GREEN**, exit code 0, **2 tests passed**, one complete preview pass
per theme. The run generated **68 PNG captures** in `build/previews`: all
**42 existing captures**, plus **26 Harmonies / Saved palettes captures**.
No Flutter layout, RenderFlex overflow, or hit-test warnings were emitted.
The full application suite, analyzer, and builds were intentionally left to
the parent agent's verification task.

## Exact capture names

Every stem below produces exactly two files: `<stem>-light.png` and
`<stem>-dark.png`.

Preserved 21 stems / 42 captures:

```text
onboarding-1
onboarding-2
onboarding-3
capture
palette
lab
room
settings
photo
photo-palette
camera-synthetic
mixer
mixer-ingredients
mixer-picker
mixer-360-text2x
mixer-picker-360-text2x
formula
formula-recipe-error
formula-picker
formula-recipe-360-text2x
formula-error-360-text2x
```

Added 13 stems / 26 captures:

```text
harmonies-complementary
harmonies-analogous
harmonies-triadic
harmonies-tetradic
harmonies-splitComplementary
harmonies-monochromatic
harmonies-monochromatic-neutral
harmonies-shades
harmonies-save-dialog
saved-palettes
harmonies-360-text2x-reduced-motion
harmonies-save-dialog-360-text2x-reduced-motion
saved-palettes-360-text2x-reduced-motion
```

## Visual inspection and limits

Inspected representative light and dark outputs: the mode controls and wheel
are visible together in ordinary mode captures; the neutral monochromatic
capture shows the lightness markers and no-hue explanation; the shades capture
shows the rail, exact swatch labels, and save/library actions. The library shows
the named red/cyan card and its actions.

The compact captures use a 360 × 800 logical viewport, 2× system text scaling,
and `FakeAccessibilityFeatures(disableAnimations: true)`. The editor is scrolled
to its selected monochromatic chip and wheel. The library is scrolled enough
to show the complete palette card; part of the preceding section heading is
above the viewport. The save dialog keeps Save and Cancel visible, and its
single-line palette-name field can scroll horizontally for the longer name.
These are scroll positions and normal input behavior, not overflow warnings.

These are diagnostic widget-test captures, not device/native-storage evidence.
