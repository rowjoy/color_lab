# Color Mixer design

User “next” continues the previously proposed Color Lab mixer, the first module of Phase2 in the supplied build document. Implement the mixer only: pigment recipes, six-mode harmony wheel/palette persistence, color games and real room-photo editing remain later modules. The existing HSL study and all Phase1 flows remain usable.

## Experience

Lab gains an Open color mixer entry without replacing its HSL sliders. A full-screen `/mixer` route presents a live result, LAB(default)/RGB selection, side-by-side LAB/RGB comparison, weighted contribution bar and editable ingredient cards. Start with Lilac#B2A4D4 and Butter#E8DAA9,50 parts each. Users can add colors, replace any input by manual HEX or their saved library, adjust0–100 parts per input, and remove inputs while keeping at least two. There is no arbitrary color-count cap. Percentages normalize the parts; zero-weight colors contribute nothing and are omitted from the bar.

Show both blend results with explicit mode labels. Toggling chooses the primary swatch/details/save target without changing inputs or weights. The digital blending caveat is visible: RGB averages encoded sRGB display channels, LAB averages D65 L*a*b*; neither simulates physical pigment mixing. CIE76 distance between the two displayed results is an optional compact explanation, not a required new tool.

The selected result opens the existing details sheet for copy/share/favorite/Use in Room and can be saved directly. Use the existing ColorSource.lab so no history schema or source migration is needed. Existing same-HEX deduplication rules apply. A confirmed Reset restores the starting mix. The draft is retained while navigating during this app session, but is not a persisted recipe/project; saving the result keeps its color only.

All-zero weights are a deliberate invalid state: display a friendly instruction, no color/name/comparison values, and no details/save action until a part becomes positive. Canceling or failing to choose a color never mutates the draft. A saved-library read failure leaves manual entry available and offers retry. Color-picker state is local and must not alter Palette's global search/filter.

The selected HEX and a compact swatch stay pinned below the scrolling ingredients, so ratio adjustments have a genuinely visible live result even with many inputs. The pinned details action uses the selected output; it disappears for an all-zero mix.

## Boundaries

Pure Dart `color_mixer.dart` owns finite nonnegative weight validation, overflow-safe normalization and weighted LAB/RGB math. Scale weights by the largest positive value before summing, preserving ratios for very large or tiny finite inputs. Empty and all-zero mixes reject clearly; a single effective color returns its exact RGB identity. Reuse current D65 conversions and clamp final LAB output to display gamut through the existing conversion.

Immutable ingredient/draft models and a non-autoDispose Riverpod notifier own ratio edits, stable IDs, add/remove/reset and selected mode. UI owns async color selection and confirmation dialogs; persistence stays with the existing history controller. No new packages, permission changes, models or native services are needed.

## Verification

Hand-checked RGB fixtures, independent D65 LAB reference fixtures, zero/invalid/nonfinite/large/tiny weights, order/scale invariance, endpoints and snapshots cover math. State tests cover input identity, minimum count, normalization, mode switching, reset and navigation-session retention. Widget tests exercise actual HEX/library picking, cancel/failure recovery, sliders/mode comparison, zero-total suppression, save with Lab source, details/Room behavior, retained HSL/draft state, large text/reduced motion and both themes. Full suite/analyzer/format/APK/previews and independent task/final review precede a cumulative ZIP.
