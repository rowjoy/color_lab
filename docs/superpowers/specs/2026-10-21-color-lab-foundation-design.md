# Color Lab Foundation Design

## Goal

Build the first runnable, tested milestone of Color Lab from the existing Flutter counter template. The milestone establishes the application shell, reusable visual system, and pure-Dart color engine required by later camera, palette, history, lab, and room-studio features.

Color Lab remains an English-only, Android-first, iOS-ready, fully offline application. All dependencies and bundled assets must be free to redistribute. The interface must support polished light and dark themes, small phones from 360 logical pixels wide, text scaling, reduced motion, semantic labels, and 48-pixel minimum touch targets.

## Foundation Scope

This milestone includes:

- A Riverpod application root and `MaterialApp.router` configuration.
- A `go_router` four-tab shell for Capture, Palette, Lab, and Room.
- Centralized colors, typography, spacing, radii, elevation, gradients, and motion tokens.
- Complete light and dark Material 3 themes using bundled Plus Jakarta Sans and JetBrains Mono assets.
- The shared widgets named in the product requirements.
- Pure-Dart color value types, conversions, distance calculation, color naming, and LAB-space k-means palette extraction.
- A bundled local color-name dataset and a Flutter asset loader kept outside the pure color engine.
- Unit and widget tests for the public Foundation behavior.

This milestone does not include camera access, gallery picking, persistence, onboarding, theme-mode persistence, image decoding, sharing, permissions, or room segmentation. Those enter in their owning phases so Foundation does not add unused dependencies or empty subsystems.

## Chosen Approach

Use a lean, feature-first Foundation instead of scaffolding all later features now. Each tab receives a polished, accessible placeholder screen so routing, themes, navigation, and shared components are exercised in a working application. Later phases replace those screens through stable route boundaries.

Use plain Riverpod providers rather than generated providers. This avoids code generation before it provides meaningful value. Use `go_router` with an indexed stateful shell so each tab retains its navigation state. Do not introduce a persistence package until the history module, where its actual query and migration requirements can determine the choice.

Only `flutter_riverpod` and `go_router` are required as new runtime packages in Foundation. Font files and the MIT-licensed color-name data are vendored assets, so the app never fetches visual or naming resources at runtime.

## Structure and Responsibilities

```text
lib/
  main.dart                         # Flutter entry point and ProviderScope
  app.dart                          # ColorLabApp and MaterialApp.router
  core/
    theme/                          # Tokens, ThemeData, Theme extensions
    widgets/                        # Reusable application widgets
    color/                          # Pure-Dart value types and algorithms
  data/
    assets/                         # Flutter-specific color-name asset loading
  features/
    shell/presentation/             # Indexed four-tab navigation shell
    picker/presentation/            # Capture placeholder route
    palette/presentation/           # Palette placeholder route
    lab/presentation/               # Lab placeholder route
    room_studio/presentation/       # Room placeholder route
  routing/                          # Route paths and router provider
assets/
  data/color_names.json
  fonts/
test/
  core/color/                       # Color math and palette tests
  core/theme/                       # Theme/token tests
  core/widgets/                     # Shared-widget behavior tests
  routing/                          # Shell navigation tests
```

Each file has one primary responsibility. Screen code consumes tokens and shared widgets rather than embedding visual constants. Pure color code imports Dart libraries only; Flutter asset loading is an adapter in `data/assets`.

## Application Shell

`main()` runs `ColorLabApp` inside `ProviderScope`. `ColorLabApp` watches a Foundation `ThemeMode` provider whose initial value is `ThemeMode.system`, supplies both custom themes, and uses the router provider.

The router uses `StatefulShellRoute.indexedStack` with one branch per tab:

- `/capture`
- `/palette`
- `/lab`
- `/room`

The shell owns the floating pill navigation and changes branches without discarding branch state. Each destination has a semantic label and a minimum 48-pixel target. The active item uses the brand gradient indicator. The initial route is Capture.

Foundation placeholder screens communicate what each module will do and use the actual design system; they do not simulate unavailable camera, database, or segmentation behavior.

## Design System

Theme tokens reproduce the supplied dark, light, and brand colors exactly. Spacing uses 4, 8, 12, 16, 20, 24, 32, and 48. Radii are 12, 20, 28, 24 for swatches, and 999 for pills. Screen padding is 20. Light mode uses the specified subtle shadow; dark mode uses stepped surfaces without shadows.

Typography uses bundled Plus Jakarta Sans at the supplied display, title, subtitle, body, and caption sizes and line heights. HEX and other fixed-width values use bundled JetBrains Mono. Text styles derive their foreground colors from the active theme.

Motion constants are 150, 250, and 400 milliseconds with the supplied cubic curves. Widgets skip nonessential animation when `MediaQuery.disableAnimations` is true. Glass blur is restricted to floating chrome over visual content.

Foundation implements these reusable APIs:

- `AppScaffold`
- `PrimaryButton`
- `SecondaryButton`
- `IconCircleButton`
- `ColorSwatchTile`
- `ColorChip`
- `PaletteBar`
- `GlassBar`
- `SectionHeader`
- `EmptyState`
- `AppBottomSheet`
- `LabeledSlider`
- `ValueRow`
- `LoadingShimmer`

Interactive widgets expose disabled and loading states where applicable, use semantic descriptions, and provide visual or haptic feedback without embedding feature logic.

## Color Engine

The color engine uses immutable value objects with value equality and `copyWith` only where partial mutation is meaningful:

- `RgbColor`: integer channels from 0 through 255.
- `HslColor`: hue in degrees `[0, 360)`, saturation and lightness in `[0, 1]`.
- `HsvColor`: hue in degrees `[0, 360)`, saturation and value in `[0, 1]`.
- `CmykColor`: cyan, magenta, yellow, and key in `[0, 1]`.
- `LabColor`: CIE L*a*b* using the D65, 2-degree reference white.
- `NamedColor`: display name, normalized RGB value, and precomputed LAB value.
- `PaletteColor`: normalized RGB value and population fraction.

HEX parsing accepts `RGB`, `#RGB`, `RRGGBB`, and `#RRGGBB`, normalizes output to uppercase `#RRGGBB`, and rejects alpha or malformed values with `FormatException`. Foundation colors are opaque.

sRGB conversion linearizes and compands channels correctly. LAB conversion uses the D65 reference white and clamps only when converting an out-of-gamut LAB result back to RGB. Delta-E uses CIE76. Round trips are compared using tolerances rather than exact floating-point equality.

`ColorNamer` is constructed from decoded local entries, precomputes LAB values, finds the nearest entry by CIE76, and caches results by 24-bit RGB value. Asset loading accepts the selected upstream dataset schema and converts failures into a small built-in fallback set; raw asset exceptions never reach a screen.

Palette extraction accepts sampled RGB pixels, uses seeded k-means++ initialization in LAB, defaults to eight clusters, merges clusters whose centers are less than delta-E 8 apart, sorts by population, and returns population fractions summing to approximately one. A caller-supplied seed makes tests deterministic. Empty input and invalid `k` values raise documented argument errors. Image resize, sampling, and isolate dispatch belong to the later photo-palette feature; the Foundation algorithm remains isolate-safe.

## Data and Control Flow

At startup, Riverpod creates theme and router state, after which the shell renders the active branch. Theme values flow from `ThemeData` and custom theme extensions into all shared widgets.

For color naming, a Flutter adapter reads the bundled JSON string and passes it to the pure-Dart parser. Feature controllers later pass RGB samples into conversion, naming, and palette APIs. No core color type depends on widget state, platform channels, or asset bundles.

## Errors and Edge Cases

- Invalid public color values fail immediately with `ArgumentError` or `FormatException` containing actionable messages.
- Achromatic HSL and HSV conversions normalize hue to zero.
- Pure black converts to CMYK with key equal to one and the other components equal to zero.
- RGB conversion clamps only final display channels, avoiding invalid channel values from floating-point drift.
- K-means handles repeated colors, fewer unique colors than requested clusters, empty clusters, and cluster merging without producing NaN percentages.
- Color-name asset failure activates a bundled fallback list and remains nonfatal.
- Layouts avoid fixed heights for text-bearing controls and remain usable at 360-pixel width and increased text scale.

## Testing Strategy

Implementation follows red-green-refactor. Tests are written and observed failing before production code is added.

Pure-Dart tests cover:

- Known HEX and color-space reference values.
- RGB-to-space-to-RGB round trips within explicit tolerances.
- D65 LAB reference colors and CIE76 symmetry/identity.
- Invalid input boundaries and achromatic/black special cases.
- Nearest-name selection and cache-stable results.
- Deterministic k-means, population ordering, delta-E merging, repeated colors, and invalid input.

Widget tests cover:

- Exact light and dark token mapping.
- App startup and the four navigation destinations.
- Navigation branch selection and accessible destination labels.
- Shared-widget primary behavior, disabled/loading states, semantics, and narrow-screen layout.
- Reduced-motion behavior for animated shared widgets.

Before completion, run formatting, the full test suite, and static analysis. A debug Android build is the compile check if the environment permits Flutter SDK cache writes.

## Acceptance Criteria

- The counter template is fully replaced by the Color Lab Foundation.
- The application launches into the Capture tab and all four branches are reachable.
- Both supplied themes and all required shared widgets are implemented from centralized tokens.
- Font and color-name assets work offline and have redistributable licenses recorded alongside them.
- Public color conversions, delta-E, naming, and k-means behavior are covered by deterministic tests.
- No heavy algorithm is tied to the UI thread; the palette function can be invoked in an isolate by the later feature.
- The app is usable at 360 logical pixels, honors system text scaling and reduced motion, and provides semantic labels and 48-pixel targets.
- Formatting, tests, analysis, and a compile check complete without unreported failures.

