import 'package:color_lab/features/games/presentation/water_sort_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('water sound starts when the source tube begins pouring', () {
    const motion = WaterPourMotion(
      source: 0,
      target: 1,
      color: 0,
      amount: 2,
      direction: 1,
      pourMillis: 970,
    );

    expect(
      motion.isPouringAt(
        (WaterPourMotion.waterStartMillis - 1) / motion.totalMillis,
      ),
      isFalse,
    );
    expect(
      motion.isPouringAt(WaterPourMotion.waterStartMillis / motion.totalMillis),
      isTrue,
    );
  });
}
