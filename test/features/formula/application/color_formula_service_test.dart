import 'dart:async';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/formula/application/color_formula_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = IsolateColorFormulaService();

  for (final (hex, id) in [
    ('#FF0000', 'red'),
    ('#FFFFFF', 'white'),
    ('#000000', 'black'),
  ]) {
    test('worker returns the exact $id endpoint', () async {
      final formula = await service.find(RgbColor.fromHex(hex));

      expect(formula.target.hex, hex);
      expect(formula.result.hex, hex);
      expect(formula.deltaE, 0);
      expect(formula.parts, hasLength(1));
      expect(formula.parts.single.base.id, id);
      expect(formula.parts.single.percent, 100);
    });
  }

  test(
    'worker finds the independently known half white/black LAB gray',
    () async {
      // Equal LAB contributions of black and white display as sRGB #777777.
      final formula = await service.find(RgbColor.fromHex('#777777'));

      expect(formula.target.hex, '#777777');
      expect(formula.result.hex, '#777777');
      expect(formula.deltaE, 0);
      expect(
        {for (final part in formula.parts) part.base.id: part.percent},
        {'white': 50, 'black': 50},
      );
    },
  );

  test(
    'full nonendpoint search leaves the caller event loop responsive',
    () async {
      var eventRan = false;
      Timer.run(() => eventRan = true);
      final pending = service.find(RgbColor.fromHex('#B2A4D4'));
      final formula = await pending;

      // A synchronous search wrapped in an already-completed Future starves this
      // event until after the result. The real VM compute worker yields to it.
      expect(eventRan, isTrue);
      expect(formula.target.hex, '#B2A4D4');
      expect(formula.parts.length, inInclusiveRange(1, 3));
      expect(formula.parts.fold(0, (sum, part) => sum + part.percent), 100);
      expect(
        formula.parts.map((part) => part.base.id).toSet().length,
        formula.parts.length,
      );
      for (final part in formula.parts) {
        expect(part.percent, inInclusiveRange(5, 100));
        expect(part.percent % 5, 0);
      }
      expect(formula.deltaE.isFinite, isTrue);
      expect(formula.deltaE, greaterThanOrEqualTo(0));
    },
  );
}
