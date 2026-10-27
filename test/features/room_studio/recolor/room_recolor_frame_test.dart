import 'package:flutter_test/flutter_test.dart';
import '../../../support/controlled_room_recolor_worker.dart';

void main() {
  test(
    'final release clears private buffers exactly once while leases protect readers',
    () {
      final frame = recolorFrame(recolorInput(0));
      final borrowedBytes = frame.pngBytes;
      var releases = 0;
      final display = frame.lease(onReleased: () => releases++);
      frame.dispose();
      frame.dispose();
      expect(frame.isDisposed, isFalse);
      expect(frame.pngBytes, [1, 2, 3]);
      expect(frame.retainedByteCount, 7);
      display.dispose();
      display.dispose();
      expect(frame.isDisposed, isTrue);
      expect(frame.retainedByteCount, 0);
      expect(releases, 1);
      expect(borrowedBytes, [1, 2, 3]);
      expect(() => frame.pngBytes, throwsStateError);
      expect(() => frame.lease(), throwsStateError);
    },
  );
}
