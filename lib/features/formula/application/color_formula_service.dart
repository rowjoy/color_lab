import 'package:flutter/foundation.dart';

import '../../../core/color/color_engine.dart';

abstract class ColorFormulaService {
  Future<ColorFormula> find(RgbColor target);
}

class IsolateColorFormulaService implements ColorFormulaService {
  const IsolateColorFormulaService();

  @override
  Future<ColorFormula> find(RgbColor target) =>
      compute(_findColorFormula, target, debugLabel: 'color-formula-search');
}

ColorFormula _findColorFormula(RgbColor target) => findColorFormula(target);
