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

RoomRecolorKey _key(String photo, int mask, int color) =>
    RoomRecolorKey(photoId: photo, maskRevision: mask, colorRevision: color);

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
