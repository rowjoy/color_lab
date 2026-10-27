import 'dart:typed_data';

import 'package:color_lab/features/room_studio/presentation/room_recolor_viewport.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _png(int red, int green, int blue) {
  final image = img.Image(width: 4, height: 2, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(red, green, blue, 255));
  return Uint8List.fromList(img.encodePng(image));
}

RoomRecolorKey _key(String photo, int mask, int color) => RoomRecolorKey(
  projectId: 'project',
  variantId: 'a',
  photoId: photo,
  maskRevision: mask,
  colorRevision: color,
);

RoomRecolorFrame _frame(RoomRecolorKey key, Uint8List png) => RoomRecolorFrame(
  key: key,
  width: 4,
  height: 2,
  rgbaBytes: Uint8List(4 * 2 * 4),
  pngBytes: png,
);

Future<void> _mount(
  WidgetTester tester, {
  required Uint8List source,
  required RoomRecolorKey currentKey,
  RoomRecolorFrame? frame,
  bool showAfter = true,
  bool updating = false,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 320,
        child: RoomRecolorViewport(
          sourcePngBytes: source,
          width: 4,
          height: 2,
          currentKey: currentKey,
          frame: frame,
          showAfter: showAfter,
          updating: updating,
        ),
      ),
    ),
  ),
);

Uint8List _shownBytes(WidgetTester tester, String key) {
  final image = tester.widget<Image>(find.byKey(ValueKey(key)));
  return (image.image as MemoryImage).bytes;
}

void main() {
  testWidgets(
    'display leases protect pixels until replacement and evict only their image',
    (tester) async {
      final source = _png(1, 2, 3);
      final frame = _frame(_key('photo', 0, 0), _png(4, 5, 6));
      await _mount(tester, source: source, currentKey: frame.key, frame: frame);
      final unrelated = MemoryImage(source);
      await tester.runAsync(
        () => precacheImage(
          unrelated,
          tester.element(find.byType(RoomRecolorViewport)),
        ),
      );
      expect(
        PaintingBinding.instance.imageCache.containsKey(unrelated),
        isTrue,
      );
      final obsolete = MemoryImage(frame.pngBytes);
      frame.dispose();
      expect(frame.isDisposed, isFalse);
      expect(_shownBytes(tester, 'room-recolor-after-image'), frame.pngBytes);
      await _mount(tester, source: source, currentKey: _key('other', 0, 0));
      expect(frame.isDisposed, isTrue);
      expect(frame.retainedByteCount, 0);
      expect(
        PaintingBinding.instance.imageCache.containsKey(obsolete),
        isFalse,
      );
      expect(
        PaintingBinding.instance.imageCache.containsKey(unrelated),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'new current variant clears decoded pixels of the previous variant',
    (tester) async {
      final source = _png(5, 6, 7);
      final first = _key('photo', 2, 3);
      await _mount(
        tester,
        source: source,
        currentKey: first,
        frame: _frame(first, _png(70, 80, 90)),
      );
      for (
        var i = 0;
        i < 30 && tester.widget<RawImage>(find.byType(RawImage)).image == null;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      final next = RoomRecolorKey(
        projectId: 'project',
        photoId: 'photo',
        variantId: 'b',
        maskRevision: 2,
        colorRevision: 3,
      );
      await _mount(
        tester,
        source: source,
        currentKey: next,
        frame: _frame(next, _png(20, 30, 40)),
      );
      expect(
        tester.widget<RawImage>(find.byType(RawImage)).image,
        isNull,
        reason:
            'Old variant pixels must be dropped while the next variant decodes',
      );
    },
  );
  for (final projectChange in [true, false]) {
    testWidgets(
      'previous frame cannot cross ${projectChange ? 'project' : 'variant'} even with same photo',
      (tester) async {
        final source = _png(10, 20, 30);
        await _mount(
          tester,
          source: source,
          currentKey: _key('photo', 2, 3),
          frame: _frame(
            RoomRecolorKey(
              projectId: projectChange ? 'other' : 'project',
              variantId: projectChange ? 'a' : 'b',
              photoId: 'photo',
              maskRevision: 1,
              colorRevision: 2,
            ),
            _png(200, 1, 1),
          ),
          updating: true,
        );
        expect(_shownBytes(tester, 'room-recolor-before-image'), source);
        expect(
          find.byKey(const ValueKey('room-recolor-previous-image')),
          findsNothing,
        );
      },
    );
  }
  testWidgets('Before shows source and current After shows result', (
    tester,
  ) async {
    final source = _png(10, 20, 30);
    final result = _png(120, 80, 40);
    final key = _key('photo', 1, 2);

    await _mount(
      tester,
      source: source,
      currentKey: key,
      frame: _frame(key, result),
      showAfter: false,
    );
    expect(_shownBytes(tester, 'room-recolor-before-image'), source);

    await _mount(
      tester,
      source: source,
      currentKey: key,
      frame: _frame(key, result),
    );
    expect(_shownBytes(tester, 'room-recolor-after-image'), result);
  });

  testWidgets('same-photo previous frame is labeled while update runs', (
    tester,
  ) async {
    final source = _png(10, 20, 30);
    final previous = _png(100, 80, 60);

    await _mount(
      tester,
      source: source,
      currentKey: _key('photo', 2, 3),
      frame: _frame(_key('photo', 1, 2), previous),
      updating: true,
    );

    expect(_shownBytes(tester, 'room-recolor-previous-image'), previous);
    expect(find.text('Updating preview...'), findsOneWidget);
  });

  testWidgets('old-photo frame never appears over a new source', (
    tester,
  ) async {
    final source = _png(10, 20, 30);

    await _mount(
      tester,
      source: source,
      currentKey: _key('new-photo', 0, 0),
      frame: _frame(_key('old-photo', 4, 5), _png(200, 1, 1)),
      updating: true,
    );

    expect(_shownBytes(tester, 'room-recolor-before-image'), source);
    expect(
      find.byKey(const ValueKey('room-recolor-previous-image')),
      findsNothing,
    );
  });
}
