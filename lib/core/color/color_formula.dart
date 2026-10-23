import 'color_mixer.dart';
import 'color_models.dart';

/// An immutable named input to the digital LAB formula search.
final class FormulaBase {
  FormulaBase({required String id, required String name, required this.color})
    : id = id.trim(),
      name = name.trim() {
    if (this.id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be blank');
    }
    if (this.name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be blank');
    }
  }

  final String id;
  final String name;
  final RgbColor color;

  @override
  bool operator ==(Object other) =>
      other is FormulaBase &&
      id == other.id &&
      name == other.name &&
      color == other.color;

  @override
  int get hashCode => Object.hash(id, name, color);
}

/// A positive contribution on the formula search's five-percent grid.
final class FormulaPart {
  FormulaPart({required this.base, required this.percent}) {
    if (percent < 5 || percent > 100 || percent % 5 != 0) {
      throw ArgumentError.value(
        percent,
        'percent',
        'Must be in [5, 100] and divisible by 5',
      );
    }
  }

  final FormulaBase base;
  final int percent;

  @override
  bool operator ==(Object other) =>
      other is FormulaPart && base == other.base && percent == other.percent;

  @override
  int get hashCode => Object.hash(base, percent);
}

/// A digital LAB approximation, not a prediction of physical paint mixing.
///
/// Error is CIE76 measured from the rounded, clamped [result] shown on screen.
final class ColorFormula {
  ColorFormula({required this.target, required Iterable<FormulaPart> parts})
    : parts = List<FormulaPart>.unmodifiable(parts) {
    if (this.parts.isEmpty || this.parts.length > 3) {
      throw ArgumentError.value(parts, 'parts', 'Must contain 1 to 3 bases');
    }
    final ids = <String>{};
    var total = 0;
    for (final part in this.parts) {
      if (!ids.add(part.base.id)) {
        throw ArgumentError.value(parts, 'parts', 'Base IDs must be distinct');
      }
      total += part.percent;
    }
    if (total != 100) {
      throw ArgumentError.value(parts, 'parts', 'Percentages must total 100');
    }
    result = mixColors([
      for (final part in this.parts)
        WeightedColor(color: part.base.color, weight: part.percent.toDouble()),
    ], space: MixingSpace.lab);
    deltaE = deltaE76(target.toLab(), result.toLab());
  }

  final RgbColor target;
  final List<FormulaPart> parts;
  late final RgbColor result;
  late final double deltaE;
}

/// Ordered digital reference colors, independent of any physical pigment brand.
final List<FormulaBase> formulaBases = List<FormulaBase>.unmodifiable([
  FormulaBase(id: 'red', name: 'Red', color: RgbColor.fromHex('#FF0000')),
  FormulaBase(id: 'orange', name: 'Orange', color: RgbColor.fromHex('#FF8000')),
  FormulaBase(id: 'yellow', name: 'Yellow', color: RgbColor.fromHex('#FFFF00')),
  FormulaBase(id: 'green', name: 'Green', color: RgbColor.fromHex('#008000')),
  FormulaBase(id: 'blue', name: 'Blue', color: RgbColor.fromHex('#0000FF')),
  FormulaBase(id: 'violet', name: 'Violet', color: RgbColor.fromHex('#8000FF')),
  FormulaBase(id: 'white', name: 'White', color: RgbColor.fromHex('#FFFFFF')),
  FormulaBase(id: 'black', name: 'Black', color: RgbColor.fromHex('#000000')),
  FormulaBase(
    id: 'yellow-ochre',
    name: 'Yellow ochre',
    color: RgbColor.fromHex('#C99700'),
  ),
  FormulaBase(
    id: 'burnt-sienna',
    name: 'Burnt sienna',
    color: RgbColor.fromHex('#A0522D'),
  ),
  FormulaBase(
    id: 'raw-umber',
    name: 'Raw umber',
    color: RgbColor.fromHex('#826644'),
  ),
  FormulaBase(
    id: 'paynes-gray',
    name: "Payne's gray",
    color: RgbColor.fromHex('#536878'),
  ),
]);

/// Finds the strict global CIE76 minimum on the positive five-percent grid.
///
/// Visits singles, ordered pairs, then ordered triples. Exact ties retain the
/// first recipe, so fewer parts and earlier palette entries take precedence.
/// The palette is consumed once and fully validated before searching.
ColorFormula findColorFormula(RgbColor target, {Iterable<FormulaBase>? bases}) {
  final palette = List<FormulaBase>.of(bases ?? formulaBases, growable: false);
  final ids = <String>{};
  if (palette.isEmpty) {
    throw ArgumentError.value(bases, 'bases', 'Must not be empty');
  }
  for (final base in palette) {
    if (!ids.add(base.id)) {
      throw ArgumentError.value(bases, 'bases', 'Base IDs must be distinct');
    }
  }

  ColorFormula? best;
  void consider(List<FormulaPart> parts) {
    final candidate = ColorFormula(target: target, parts: parts);
    if (best == null || candidate.deltaE < best!.deltaE) best = candidate;
  }

  for (final base in palette) {
    consider([FormulaPart(base: base, percent: 100)]);
    if (best!.deltaE == 0) return best!;
  }
  for (var i = 0; i < palette.length; i++) {
    for (var j = i + 1; j < palette.length; j++) {
      for (var first = 5; first <= 95; first += 5) {
        consider([
          FormulaPart(base: palette[i], percent: first),
          FormulaPart(base: palette[j], percent: 100 - first),
        ]);
        if (best!.deltaE == 0) return best!;
      }
    }
  }
  for (var i = 0; i < palette.length; i++) {
    for (var j = i + 1; j < palette.length; j++) {
      for (var k = j + 1; k < palette.length; k++) {
        for (var first = 5; first <= 90; first += 5) {
          for (var second = 5; second <= 95 - first; second += 5) {
            consider([
              FormulaPart(base: palette[i], percent: first),
              FormulaPart(base: palette[j], percent: second),
              FormulaPart(base: palette[k], percent: 100 - first - second),
            ]);
            if (best!.deltaE == 0) return best!;
          }
        }
      }
    }
  }
  return best!;
}
