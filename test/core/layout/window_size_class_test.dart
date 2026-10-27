import 'package:color_lab/core/layout/window_size_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies every responsive boundary exactly', () {
    expect(windowSizeClassFor(599), WindowSizeClass.compact);
    expect(windowSizeClassFor(600), WindowSizeClass.medium);
    expect(windowSizeClassFor(839), WindowSizeClass.medium);
    expect(windowSizeClassFor(840), WindowSizeClass.expanded);
    expect(windowSizeClassFor(1199), WindowSizeClass.expanded);
    expect(windowSizeClassFor(1200), WindowSizeClass.large);
  });

  test('rejects widths that cannot describe layout constraints', () {
    for (final width in [-1.0, double.nan, double.infinity]) {
      expect(
        () => windowSizeClassFor(width),
        throwsArgumentError,
        reason: '$width',
      );
    }
  });
}
