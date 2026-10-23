import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/color/color_engine.dart';

/// Loads the bundled upstream color-name-list once, with a nonfatal fallback.
final class ColorNameAssetLoader {
  ColorNameAssetLoader({
    AssetBundle? bundle,
    this.assetPath = 'assets/data/color_names.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;
  Future<ColorNamer>? _loaded;

  Future<ColorNamer> load() => _loaded ??= _load();

  Future<ColorNamer> _load() async {
    try {
      final json = await _bundle.loadString(assetPath);
      // Decode and precompute thousands of LAB values away from native UI.
      return await compute(_parseColorNames, json);
    } catch (_) {
      return ColorNamer([
        NamedColor('Black', RgbColor(0, 0, 0)),
        NamedColor('White', RgbColor(255, 255, 255)),
        NamedColor('Red', RgbColor(255, 0, 0)),
        NamedColor('Green', RgbColor(0, 255, 0)),
        NamedColor('Blue', RgbColor(0, 0, 255)),
        NamedColor('Yellow', RgbColor(255, 255, 0)),
        NamedColor('Cyan', RgbColor(0, 255, 255)),
        NamedColor('Magenta', RgbColor(255, 0, 255)),
        NamedColor('Gray', RgbColor(128, 128, 128)),
      ]);
    }
  }
}

ColorNamer _parseColorNames(String json) => ColorNamer.fromJson(json);
