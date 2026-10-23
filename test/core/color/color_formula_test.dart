import 'dart:math' as math;

import 'package:color_lab/core/color/color_engine.dart';
import 'package:flutter_test/flutter_test.dart';

FormulaBase _base(String id, String hex) =>
    FormulaBase(id: id, name: id, color: RgbColor.fromHex(hex));

void main() {
  final black = _base('black', '#000000');
  final white = _base('white', '#FFFFFF');
  final red = _base('red', '#FF0000');
  final green = _base('green', '#00FF00');
  final blue = _base('blue', '#0000FF');

  group('FormulaBase and FormulaPart', () {
    test('normalizes base labels and compares complete values', () {
      final base = FormulaBase(id: ' red ', name: ' Red ', color: red.color);
      final equivalent = FormulaBase(id: 'red', name: 'Red', color: red.color);
      expect(base.id, 'red');
      expect(base.name, 'Red');
      expect(base, equivalent);
      expect({base}.contains(equivalent), isTrue);
      expect(base, isNot(FormulaBase(id: 'r', name: 'Red', color: red.color)));
      expect(base, isNot(FormulaBase(id: 'red', name: 'R', color: red.color)));
      expect(
        base,
        isNot(FormulaBase(id: 'red', name: 'Red', color: blue.color)),
      );
      final part = FormulaPart(base: base, percent: 50);
      expect(part, FormulaPart(base: equivalent, percent: 50));
      expect(
        {part}.contains(FormulaPart(base: equivalent, percent: 50)),
        isTrue,
      );
      expect(part, isNot(FormulaPart(base: base, percent: 55)));
      expect(part, isNot(FormulaPart(base: blue, percent: 50)));
    });

    test('rejects blank base identifiers or names', () {
      for (final value in ['', '  ', '\n\t']) {
        expect(
          () => FormulaBase(id: value, name: 'Red', color: red.color),
          throwsArgumentError,
        );
        expect(
          () => FormulaBase(id: 'red', name: value, color: red.color),
          throwsArgumentError,
        );
      }
    });

    test('accepts exactly positive five-percent steps through 100', () {
      for (var percent = 5; percent <= 100; percent += 5) {
        expect(FormulaPart(base: red, percent: percent).percent, percent);
      }
      for (final percent in [-5, 0, 1, 6, 99, 101, 105]) {
        expect(
          () => FormulaPart(base: red, percent: percent),
          throwsArgumentError,
        );
      }
    });
  });

  group('ColorFormula', () {
    test('LAB black-white midpoint has the known displayed result', () {
      final formula = ColorFormula(
        target: RgbColor.fromHex('#777777'),
        parts: [
          FormulaPart(base: black, percent: 50),
          FormulaPart(base: white, percent: 50),
        ],
      );
      expect(formula.result.hex, '#777777');
      expect(formula.deltaE, 0);
    });

    test('uses independently evaluated three-color LAB fixture', () {
      // Independently evaluated W3C CSS Color 4 rational sRGB matrices and
      // D65 CIELAB, omitting the CSS D50 adaptation. RGB 20:30:50 produces
      // LAB [53.1185153040, 29.7611787856, -15.5310939838], encoded RGB
      // [164.9431396358, 108.4762654091, 154.0563183119], hence #A56C9A.
      final formula = ColorFormula(
        target: RgbColor.fromHex('#A56C9A'),
        parts: [
          FormulaPart(base: red, percent: 20),
          FormulaPart(base: green, percent: 30),
          FormulaPart(base: blue, percent: 50),
        ],
      );
      expect(formula.result.hex, '#A56C9A');
      expect(formula.deltaE, 0);
    });

    test('scores displayed RGB rather than unrounded LAB coordinates', () {
      final formula = ColorFormula(
        target: RgbColor.fromHex('#808080'),
        parts: [
          FormulaPart(base: black, percent: 50),
          FormulaPart(base: white, percent: 50),
        ],
      );
      // Neutral-axis D65 calculation: L*(128)-L*(119)=3.5505746596.
      expect(formula.result.hex, '#777777');
      expect(formula.deltaE, closeTo(3.5505746596, .00001));
    });

    test('owns an unmodifiable snapshot and consumes parts once', () {
      final source = [FormulaPart(base: black, percent: 100)];
      var reads = 0;
      final once = Iterable<FormulaPart>.generate(source.length, (index) {
        if (++reads > 1) throw StateError('Consumed twice');
        return source[index];
      });
      final formula = ColorFormula(target: black.color, parts: once);
      source[0] = FormulaPart(base: white, percent: 100);
      expect(formula.parts.single.base, black);
      expect(formula.result, black.color);
      expect(reads, 1);
      expect(() => formula.parts.clear(), throwsUnsupportedError);
      expect(() => formula.parts[0] = source[0], throwsUnsupportedError);
    });

    test('rejects empty, oversized, duplicate-ID and non-total recipes', () {
      final alias = FormulaBase(id: 'black', name: 'Alias', color: white.color);
      for (final parts in <List<FormulaPart>>[
        [],
        [FormulaPart(base: black, percent: 95)],
        [
          FormulaPart(base: black, percent: 50),
          FormulaPart(base: white, percent: 55),
        ],
        [
          FormulaPart(base: black, percent: 50),
          FormulaPart(base: alias, percent: 50),
        ],
        [
          FormulaPart(base: black, percent: 25),
          FormulaPart(base: white, percent: 25),
          FormulaPart(base: red, percent: 25),
          FormulaPart(base: blue, percent: 25),
        ],
      ]) {
        expect(
          () => ColorFormula(target: red.color, parts: parts),
          throwsArgumentError,
        );
      }
    });
  });

  group('findColorFormula', () {
    const defaults = [
      ('red', 'Red', '#FF0000'),
      ('orange', 'Orange', '#FF8000'),
      ('yellow', 'Yellow', '#FFFF00'),
      ('green', 'Green', '#008000'),
      ('blue', 'Blue', '#0000FF'),
      ('violet', 'Violet', '#8000FF'),
      ('white', 'White', '#FFFFFF'),
      ('black', 'Black', '#000000'),
      ('yellow-ochre', 'Yellow ochre', '#C99700'),
      ('burnt-sienna', 'Burnt sienna', '#A0522D'),
      ('raw-umber', 'Raw umber', '#826644'),
      ('paynes-gray', "Payne's gray", '#536878'),
    ];

    for (final (id, name, hex) in defaults) {
      test('finds pure default $name as one exact 100-percent part', () {
        final target = RgbColor.fromHex(hex);
        final formula = findColorFormula(target);
        expect(formula.target, target);
        expect(formula.result.hex, hex);
        expect(formula.deltaE, 0);
        expect(formula.parts, [
          FormulaPart(
            base: FormulaBase(id: id, name: name, color: target),
            percent: 100,
          ),
        ]);
      });
    }

    test('keeps default palette ordered and unmodifiable', () {
      expect(
        formulaBases.map((base) => base.id),
        defaults.map((row) => row.$1),
      );
      expect(() => formulaBases.clear(), throwsUnsupportedError);
    });

    test('finds known two-color midpoint', () {
      final formula = findColorFormula(
        RgbColor.fromHex('#777777'),
        bases: [black, white],
      );
      expect(formula.deltaE, 0);
      expect(formula.result.hex, '#777777');
      expect(formula.parts, [
        FormulaPart(base: black, percent: 50),
        FormulaPart(base: white, percent: 50),
      ]);
    });

    test(
      'finds independent triple fixture requiring three distinct colors',
      () {
        final formula = findColorFormula(
          RgbColor.fromHex('#A56C9A'),
          bases: [red, green, blue],
        );
        expect(formula.result.hex, '#A56C9A');
        expect(formula.deltaE, 0);
        expect(formula.parts, [
          FormulaPart(base: red, percent: 20),
          FormulaPart(base: green, percent: 30),
          FormulaPart(base: blue, percent: 50),
        ]);
      },
    );

    test('matches a separate exhaustive allocation oracle globally', () {
      final palette = [black, red, green, blue];
      for (final hex in ['#747A92', '#F1D77E', '#123456', '#3C8A57']) {
        final target = RgbColor.fromHex(hex);
        final formula = findColorFormula(target, bases: palette);
        expect(formula.deltaE, closeTo(_oracleMinimum(target, palette), 1e-10));
        expect(
          formula.deltaE,
          closeTo(_displayDistance(target, formula.result), 1e-10),
        );
        expect(formula.parts.length, inInclusiveRange(1, 3));
        expect(
          formula.parts.map((part) => part.base.id).toSet().length,
          formula.parts.length,
        );
        expect(formula.parts.fold(0, (sum, part) => sum + part.percent), 100);
        for (final part in formula.parts) {
          expect(part.percent, inInclusiveRange(5, 100));
          expect(part.percent % 5, 0);
        }
      }
    });

    test('exact ties retain first singleton and prefer fewer parts', () {
      final alias = _base('other-black', '#000000');
      final formula = findColorFormula(
        RgbColor.fromHex('#010101'),
        bases: [black, alias],
      );
      expect(formula.parts, [FormulaPart(base: black, percent: 100)]);
    });

    test('tied pairs retain palette order before equivalent triples', () {
      final alias = _base('other-white', '#FFFFFF');
      for (var attempt = 0; attempt < 3; attempt++) {
        final formula = findColorFormula(
          RgbColor.fromHex('#777777'),
          bases: [black, white, alias],
        );
        expect(formula.parts, [
          FormulaPart(base: black, percent: 50),
          FormulaPart(base: white, percent: 50),
        ]);
      }
    });

    test('consumes palette once and handles one available base', () {
      var reads = 0;
      final source = Iterable<FormulaBase>.generate(1, (_) {
        if (++reads > 1) throw StateError('Consumed twice');
        return black;
      });
      final formula = findColorFormula(white.color, bases: source);
      expect(formula.parts, [FormulaPart(base: black, percent: 100)]);
      expect(formula.result, black.color);
      expect(reads, 1);
    });

    test('validates entire palette before accepting an exact endpoint', () {
      expect(
        () => findColorFormula(black.color, bases: []),
        throwsArgumentError,
      );
      final alias = FormulaBase(
        id: ' black ',
        name: 'Alias',
        color: white.color,
      );
      expect(
        () => findColorFormula(black.color, bases: [black, alias]),
        throwsArgumentError,
      );
    });

    test('searches the full default palette for an arbitrary target', () {
      final watch = Stopwatch()..start();
      final formula = findColorFormula(RgbColor.fromHex('#71839B'));
      watch.stop();
      expect(formula.parts, isNotEmpty);
      expect(formula.deltaE.isFinite, isTrue);
      // Nonbinding local timing, intentionally no performance threshold.
      // ignore: avoid_print
      print(
        'Default formula search: ${watch.elapsedMilliseconds} ms; ${formula.result.hex}; deltaE=${formula.deltaE}',
      );
    });
  });
}

double _displayDistance(RgbColor first, RgbColor second) {
  final a = first.toLab();
  final b = second.toLab();
  return math.sqrt(
    math.pow(a.lightness - b.lightness, 2) +
        math.pow(a.a - b.a, 2) +
        math.pow(a.b - b.b, 2),
  );
}

// Independent enumeration: distribute 20 units across every palette slot,
// allowing zero shares, then retain recipes with at most three active slots.
// This differs from production's ordered singleton/pair/triple loops. Existing
// mixing is the established boundary; literal fixtures above check its use.
double _oracleMinimum(RgbColor target, List<FormulaBase> palette) {
  var minimum = double.infinity;
  final allocations = List<int>.filled(palette.length, 0);
  void visit(int index, int remaining) {
    if (index == palette.length - 1) {
      allocations[index] = remaining;
      if (allocations.where((value) => value > 0).length > 3) return;
      final result = mixColors([
        for (var slot = 0; slot < palette.length; slot++)
          if (allocations[slot] > 0)
            WeightedColor(
              color: palette[slot].color,
              weight: allocations[slot].toDouble(),
            ),
      ], space: MixingSpace.lab);
      minimum = math.min(minimum, _displayDistance(target, result));
      return;
    }
    for (var units = 0; units <= remaining; units++) {
      allocations[index] = units;
      visit(index + 1, remaining - units);
    }
  }

  visit(0, 20);
  return minimum;
}
