import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/color_test/domain/vision_dot_pattern.dart';
import 'package:color_lab/features/color_test/domain/vision_plate.dart';
import 'package:color_lab/features/color_test/presentation/vision_plate_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _description =
    'Generated dot pattern. Enter the number you see, or choose Not sure.';

// Independent literal swatch fixtures; these are illustrative RGB values, not
// medical calibration. They catch palette substitution and theme-based tinting.
const _paletteRgb = {
  VisionPalette.roseOlive: [
    0xca766f,
    0xd7857b,
    0xb96b67,
    0x8c9563,
    0x9ea773,
    0x7e8859,
  ],
  VisionPalette.tealRose: [
    0x55988d,
    0x6aa99b,
    0x49887f,
    0xbd827f,
    0xce9490,
    0xab7374,
  ],
  VisionPalette.blueSand: [
    0x6f8fbe,
    0x819fc9,
    0x627faa,
    0xc1a878,
    0xd0b98b,
    0xaf986b,
  ],
};
const _paperRgb = 0xf4efe5;

Future<void> _pump(
  WidgetTester tester, {
  required VisionPlate plate,
  bool dark = false,
  Size bounds = const Size(256, 256),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: Center(
        child: SizedBox(
          width: bounds.width,
          height: bounds.height,
          child: VisionPlateView(plate: plate),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get _paint => find.descendant(
  of: find.byType(VisionPlateView),
  matching: find.byType(CustomPaint),
);

CustomPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(_paint).painter!;

// Rasterize the actual widget-installed painter. No golden, fake canvas, or
// painter replacement can satisfy the RGB/alpha assertions below.
Future<Uint8List> _pixels(
  WidgetTester tester, {
  Size size = const Size(256, 256),
}) async => (await tester.runAsync(() async {
  final recorder = ui.PictureRecorder();
  _painter(tester).paint(Canvas(recorder), size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.ceil(), size.height.ceil());
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return Uint8List.fromList(data!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}))!;

int _rgba(Uint8List pixels, int x, int y, {int width = 256}) {
  final offset = (y * width + x) * 4;
  return (pixels[offset] << 24) |
      (pixels[offset + 1] << 16) |
      (pixels[offset + 2] << 8) |
      pixels[offset + 3];
}

int _opaque(int rgb) => (rgb << 8) | 0xff;

// A dot's color may change with mask membership, but its occupied pixels must
// not. Paper and transparent pixels distinguish actual geometry from shading.
List<bool> _dotFootprint(Uint8List pixels) => [
  for (var i = 0; i < pixels.length; i += 4)
    pixels[i + 3] != 0 &&
        ((pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2]) != _paperRgb,
];

void _expectSameDotFootprint(Uint8List first, Uint8List second) {
  final firstFootprint = _dotFootprint(first);
  final secondFootprint = _dotFootprint(second);
  final paper = [_paperRgb >> 16, (_paperRgb >> 8) & 255, _paperRgb & 255];
  for (var pixel = 0; pixel < firstFootprint.length; pixel++) {
    if (firstFootprint[pixel] == secondFootprint[pixel]) continue;
    // Subpixel circle edges blend against paper. A color change can round an
    // almost-clear edge to paper in one image and one RGB level away in the
    // other. Permit only that quantization; moved/omitted dots remain failures.
    for (var channel = 0; channel < 3; channel++) {
      expect(
        (first[pixel * 4 + channel] - paper[channel]).abs(),
        lessThanOrEqualTo(1),
        reason: 'First footprint at (${pixel % 256}, ${pixel ~/ 256}).',
      );
      expect(
        (second[pixel * 4 + channel] - paper[channel]).abs(),
        lessThanOrEqualTo(1),
        reason: 'Second footprint at (${pixel % 256}, ${pixel ~/ 256}).',
      );
    }
  }
}

void main() {
  // Catches omitted dots, incorrect normalized coordinates, wrong RGB mapping,
  // paper covering the dots, or painting the outer square instead of a circle.
  testWidgets('real dot centers preserve RGB with paper and clear corners', (
    tester,
  ) async {
    for (final fixture in _paletteRgb.entries) {
      final plate = VisionPlate(number: 2, seed: 1729, palette: fixture.key);
      await _pump(tester, plate: plate);
      final pixels = await _pixels(tester);
      for (final dot in generateVisionDots(plate)) {
        expect(
          _rgba(pixels, (dot.x * 256).floor(), (dot.y * 256).floor()),
          _opaque(dot.color.value),
          reason:
              'The center of each generated dot must retain its actual RGB.',
        );
      }
      final paintedRgb = <int>{
        for (var i = 0; i < pixels.length; i += 4)
          if (pixels[i + 3] == 255)
            (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2],
      };
      expect(paintedRgb, containsAll(fixture.value));
      // At this grid intersection even maximum jitter/radius leaves a gap.
      expect(_rgba(pixels, 128, 128), _opaque(_paperRgb));
      expect(_rgba(pixels, 128, 2), _opaque(_paperRgb));
      expect(_rgba(pixels, 0, 0), 0);
      expect(_rgba(pixels, 255, 255), 0);
    }
  });

  // A hard-coded, hand-checked mask point: (.515625, .515625) is field for
  // original digit 2 and figure for 8. It catches inverted/missing mask colors
  // without duplicating the mask implementation in the expectation.
  testWidgets('hidden digit changes color at known point but no dot geometry', (
    tester,
  ) async {
    final two = VisionPlate(number: 2, seed: 1729);
    await _pump(tester, plate: two);
    final firstPainter = _painter(tester);
    final first = await _pixels(tester);
    expect([
      0x8c9563ff,
      0x9ea773ff,
      0x7e8859ff,
    ], contains(_rgba(first, 132, 132)));
    await _pump(tester, plate: VisionPlate(number: 8, seed: 1729));
    final second = await _pixels(tester);
    expect([
      0xca766fff,
      0xd7857bff,
      0xb96b67ff,
    ], contains(_rgba(second, 132, 132)));
    expect(second, isNot(orderedEquals(first)));
    _expectSameDotFootprint(first, second);
    expect(_painter(tester).shouldRepaint(firstPainter), isTrue);
  });

  // Catches stale state caches, theme tinting, and recomputing a painter for an
  // equal value. Identity verifies the cache's public rendering boundary.
  testWidgets(
    'equal plate and theme rebuild retain cached painter and pixels',
    (tester) async {
      for (final palette in VisionPalette.values) {
        await _pump(
          tester,
          plate: VisionPlate(number: 8, seed: 1729, palette: palette),
        );
        final painter = _painter(tester);
        final first = await _pixels(tester);
        await _pump(
          tester,
          plate: VisionPlate(number: 8, seed: 1729, palette: palette),
          dark: true,
        );
        expect(identical(_painter(tester), painter), isTrue);
        expect(_painter(tester).shouldRepaint(painter), isFalse);
        expect(await _pixels(tester), orderedEquals(first));
        await tester.pump(const Duration(seconds: 10));
        expect(await _pixels(tester), orderedEquals(first));
        expect(tester.binding.transientCallbackCount, 0);
      }
    },
  );

  testWidgets('palette changes actual RGB and seed changes actual geometry', (
    tester,
  ) async {
    await _pump(tester, plate: VisionPlate(number: 8, seed: 1729));
    final first = await _pixels(tester);
    var previous = _painter(tester);
    await _pump(
      tester,
      plate: VisionPlate(
        number: 8,
        seed: 1729,
        palette: VisionPalette.blueSand,
      ),
    );
    final newPalette = await _pixels(tester);
    expect(newPalette, isNot(orderedEquals(first)));
    _expectSameDotFootprint(first, newPalette);
    expect(_painter(tester).shouldRepaint(previous), isTrue);
    previous = _painter(tester);
    await _pump(
      tester,
      plate: VisionPlate(
        number: 8,
        seed: 1730,
        palette: VisionPalette.blueSand,
      ),
    );
    final newSeed = await _pixels(tester);
    expect(newSeed, isNot(orderedEquals(newPalette)));
    expect(
      _dotFootprint(newSeed),
      isNot(orderedEquals(_dotFootprint(newPalette))),
    );
    expect(_painter(tester).shouldRepaint(previous), isTrue);
  });

  // Catches stretching and coordinates tied to a former canvas size. Direct
  // rectangular rasterization also checks the painter's safe centered behavior.
  testWidgets('square adapts to tight wide and tall bounds without clipping', (
    tester,
  ) async {
    final plate = VisionPlate(number: 8, seed: 1729);
    for (final bounds in [const Size(320, 180), const Size(180, 320)]) {
      await _pump(tester, plate: plate, bounds: bounds);
      expect(tester.getSize(_paint), const Size(180, 180));
      expect(tester.takeException(), isNull);
    }
    final pixels = await _pixels(tester, size: const Size(320, 180));
    expect(_rgba(pixels, 0, 90, width: 320), 0);
    expect(_rgba(pixels, 319, 90, width: 320), 0);
    expect(_rgba(pixels, 160, 2, width: 320), _opaque(_paperRgb));
    final dot = generateVisionDots(plate).first;
    expect(
      _rgba(
        pixels,
        (70 + dot.x * 180).floor(),
        (dot.y * 180).floor(),
        width: 320,
      ),
      _opaque(dot.color.value),
    );
  });

  for (final dark in [false, true]) {
    // Catches answer-bearing labels/hints, duplicate captions, interactive image
    // semantics, and motion/layout regressions under the narrow accessibility
    // setting used by the containing activity.
    testWidgets(
      '360px 2x reduced motion exposes one answer-free image, $dark',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final semantics = tester.ensureSemantics();
        try {
          await _pump(
            tester,
            plate: VisionPlate(number: 8, seed: 1729),
            dark: dark,
            bounds: const Size(360, 360),
          );
          expect(tester.getSize(_paint), const Size(360, 360));
          expect(find.bySemanticsLabel(_description), findsOneWidget);
          final node = tester.getSemantics(find.bySemanticsLabel(_description));
          expect(
            node,
            matchesSemantics(
              isImage: true,
              label: _description,
              textDirection: TextDirection.ltr,
            ),
          );
          expect(node.getSemanticsData().actions, 0);
          expect(node.childrenCount, 0);
          expect(node.label, isNot(contains(RegExp(r'[0-9]'))));
          expect(
            find.descendant(
              of: find.byType(VisionPlateView),
              matching: find.byType(GestureDetector),
            ),
            findsNothing,
          );
          final first = await _pixels(tester);
          await tester.pump(const Duration(seconds: 10));
          expect(await _pixels(tester), orderedEquals(first));
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
