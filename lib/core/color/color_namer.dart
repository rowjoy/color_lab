import 'dart:convert';

import 'color_models.dart';

/// Offline nearest-name lookup. Dataset order breaks equal-distance ties.
final class ColorNamer {
  ColorNamer(Iterable<NamedColor> entries)
    : colors = List.unmodifiable(entries) {
    if (colors.isEmpty) throw ArgumentError('Color names must not be empty');
  }

  factory ColorNamer.fromJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      throw const FormatException('Expected a list of color-name entries');
    }
    return ColorNamer.fromEntries(decoded);
  }

  /// Accepts upstream color-name-list entries: {"name": ..., "hex": ...}.
  factory ColorNamer.fromEntries(List<dynamic> entries) {
    if (entries.isEmpty) {
      throw const FormatException('Color-name list is empty');
    }
    final colors = <NamedColor>[];
    for (final entry in entries) {
      if (entry is! Map ||
          entry['name'] is! String ||
          entry['hex'] is! String ||
          (entry['name'] as String).trim().isEmpty) {
        throw const FormatException(
          'Each color needs a nonempty name and an RGB hex string',
        );
      }
      colors.add(
        NamedColor(
          entry['name'] as String,
          RgbColor.fromHex(entry['hex'] as String),
        ),
      );
    }
    return ColorNamer(colors);
  }

  final List<NamedColor> colors;
  final Map<int, NamedColor> _cache = {};

  NamedColor nearest(RgbColor color) => _cache.putIfAbsent(color.value, () {
    final lab = color.toLab();
    var nearest = colors.first;
    var distance = double.infinity;
    for (final candidate in colors) {
      final current = deltaE76(lab, candidate.lab);
      if (current < distance) {
        nearest = candidate;
        distance = current;
        if (current == 0) break;
      }
    }
    return nearest;
  });
}
