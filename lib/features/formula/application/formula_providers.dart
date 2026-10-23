import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import 'color_formula_service.dart';

final colorFormulaServiceProvider = Provider<ColorFormulaService>(
  (ref) => const IsolateColorFormulaService(),
);

// Keep only the current selection for this session when leaving the screen.
final formulaTargetProvider =
    NotifierProvider<FormulaTargetController, RgbColor>(
      FormulaTargetController.new,
    );

class FormulaTargetController extends Notifier<RgbColor> {
  @override
  RgbColor build() => RgbColor.fromHex('#B2A4D4');

  void setColor(RgbColor color) => state = color;
}

// A different target owns a separate async state; detached results expire.
// Invalidate this target's key to retry a failed search.
final formulaResultProvider = FutureProvider.autoDispose
    .family<ColorFormula, RgbColor>(
      (ref, target) => ref.watch(colorFormulaServiceProvider).find(target),
    );
