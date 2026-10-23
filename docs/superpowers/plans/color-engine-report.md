# Foundation color engine report

Implemented Task 1 in `lib/core/color/`, `lib/data/assets/`, `test/core/color/`, and `test/data/`. No dependency, asset, root application, or platform files were changed.

## Public interfaces

- `lib/core/color/color_engine.dart` exports all pure Dart APIs.
- `RgbColor(int red, int green, int blue)`: immutable integer channels; `value` is the 24-bit RGB integer; `hex` is uppercase `#RRGGBB`; `RgbColor.fromHex` accepts optional `#` and exactly three or six hexadecimal digits; `copyWith` validates its resulting channels.
- `RgbColor.toHsl()`, `.toHsv()`, `.toCmyk()`, `.toLab()` and each returned space's `.toRgb()` provide opaque sRGB conversions.
- Positional `HslColor(hue, saturation, lightness)`, `HsvColor(hue, saturation, value)`, `CmykColor(cyan, magenta, yellow, key)`, and `LabColor(lightness, a, b)` constructors validate finite coordinates and documented ranges. Hue is `[0,360)`, fractional components `[0,1]`, LAB L* `[0,100]`; a*/b* may be any finite values. Achromatic hue normalizes to zero. All models use value equality and hashes.
- `deltaE76(LabColor first, LabColor second)` uses a scaled Euclidean norm to avoid overflow when the resulting distance is representable.
- `NamedColor(String name, RgbColor color)` exposes trimmed `name`, `color`, and precomputed `lab`.
- `ColorNamer(Iterable<NamedColor>)`, `ColorNamer.fromJson(String)`, and `ColorNamer.fromEntries(List<dynamic>)` support upstream `[{"name":"Red","hex":"#ff0000"}]` data. `colors` is immutable; `.nearest(RgbColor)` uses CIE76 and caches by the RGB integer. Dataset order breaks ties. Empty/malformed decoded datasets raise `FormatException`.
- `PaletteColor(RgbColor color, double population)` is immutable, validates population `[0,1]`, and supports value equality.
- `extractPalette(List<RgbColor> pixels, {int k = 8, int seed = 42, double mergeThreshold = 8})` returns an immutable descending-population list, with RGB integer breaking population ties. It aggregates repeated input pixels, uses population-weighted seeded k-means++ and up to 100 Lloyd iterations, removes empty clusters, and repeatedly merges closest centers strictly below the threshold using weighted LAB centroids. Input pixels are never mutated. Empty pixels, nonpositive k, and negative/nonfinite thresholds raise `ArgumentError`.
- `lib/data/assets/color_name_asset_loader.dart`: `ColorNameAssetLoader({AssetBundle? bundle, String assetPath = 'assets/data/color_names.json'})`; `.load()` caches its `Future<ColorNamer>`, including concurrent requests. JSON decoding/LAB precomputation uses Flutter `compute` on native platforms. Missing, empty, or malformed data returns a nine-name built-in fallback. Asset exceptions do not escape.

## Verification

Tests were added before production files. The initial `flutter test test/core/color test/data` exited 1 because the requested production APIs did not exist. Two additional numerical regression tests were observed failing before their fixes: achromatic endpoint hue and overflow-safe CIE76. A weighted-merge test initially assumed a nonlinear LAB centroid rounded to 255; its correct expectation accepts the adjacent display integers around 254.5.

Final commands:

```text
dart format lib/core/color lib/data/assets test/core/color test/data
Formatted 7 files (0 changed).

flutter test test/core/color test/data
26 tests passed; exit 0.

flutter analyze lib/core/color lib/data/assets test/core/color test/data
No issues found; exit 0.
```

Flutter/Dart commands required authorized escalation because the installed SDK writes outside the workspace cache. The first unelevated SDK probe failed with `engine.stamp: Operation not permitted`; escalated verification completed. Initial analyzer findings (four block-style lints and one redundant import) were corrected. The root integration task owns full-suite and Android-build verification.

Coverage includes HEX rejection/normalization, six hue sectors, CMYK references, D65 LAB references, 227 RGB round-trip samples per space, out-of-gamut display clamping, finite/range checks, equality/copy behavior, CIE76 reference distance/symmetry/large values, LAB rather than RGB nearest naming, malformed datasets, immutable collections, deterministic palette output, population conservation, repeated pixels, weighted merging, LAB centroid behavior, and injected-bundle fallback/caching.

After root registered the production assets, an additional real-bundle integration test verified that the default loader reads all 31,943 vendored entries and returns an RGB-exact, zero-CIE76 match for pure red without assuming a dataset-specific display name. This protects the asset registration, upstream schema, and complete offline dataset path from silently activating the fallback. The rerun passed all 26 scoped tests and scoped analysis remained clean. No production changes were needed for this integration test.
