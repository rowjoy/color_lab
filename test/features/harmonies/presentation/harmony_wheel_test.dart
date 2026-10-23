import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/harmonies/presentation/harmony_wheel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _diagram = ValueKey('harmony-wheel-diagram');

final _fixtures = <HarmonyMode, List<String>>{
  HarmonyMode.complementary: ['#FF0000', '#00FFFF'],
  HarmonyMode.analogous: ['#FF0000', '#FF0080', '#FF8000'],
  HarmonyMode.triadic: ['#FF0000', '#00FF00', '#0000FF'],
  HarmonyMode.tetradic: ['#FF0000', '#80FF00', '#00FFFF', '#8000FF'],
  HarmonyMode.splitComplementary: ['#FF0000', '#00FF80', '#0080FF'],
  HarmonyMode.monochromatic: [
    '#FF0000',
    '#660000',
    '#B30000',
    '#FF4D4D',
    '#FF9999',
  ],
};

// Hand-checked centers on a 320px diagram, in input order. These assertions
// distinguish real relationship markers from the hue colors in the ring.
final _markerCenters = <HarmonyMode, List<(int, int)>>{
  HarmonyMode.complementary: [(160, 64), (160, 256)],
  HarmonyMode.analogous: [(160, 64), (112, 77), (208, 77)],
  HarmonyMode.triadic: [(160, 64), (243, 208), (77, 208)],
  HarmonyMode.tetradic: [(160, 64), (256, 160), (160, 256), (64, 160)],
  HarmonyMode.splitComplementary: [(160, 64), (208, 243), (112, 243)],
  HarmonyMode.monochromatic: [
    (160, 160),
    (64, 160),
    (112, 160),
    (208, 160),
    (256, 160),
  ],
};

Future<void> _pump(
  WidgetTester tester, {
  HarmonyMode mode = HarmonyMode.complementary,
  List<String> shades = const ['#FF0000', '#00FFFF'],
  String base = '#FF0000',
  bool dark = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SizedBox(
            width: 320,
            child: HarmonyWheel(
              base: RgbColor.fromHex(base),
              mode: mode,
              colors: shades.map(RgbColor.fromHex).toList(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

CustomPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(_diagram)).painter!;

// Rasterize the actual painter installed by the real widget, without goldens
// or mocks. Literal sample points below are independent design expectations.
Future<Uint8List> _pixels(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      _painter(tester).paint(Canvas(recorder), const Size(320, 320));
      final picture = recorder.endRecording();
      final image = await picture.toImage(320, 320);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = Uint8List.fromList(data!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
      return bytes;
    }))!;

List<int> _rgb(Uint8List pixels, int x, int y) =>
    pixels.sublist((y * 320 + x) * 4, (y * 320 + x) * 4 + 3);

void _expectRgb(Uint8List pixels, int x, int y, List<int> expected) {
  final actual = _rgb(pixels, x, y);
  for (var channel = 0; channel < 3; channel++) {
    expect(actual[channel], closeTo(expected[channel], 3));
  }
}

void main() {
  for (final dark in [false, true]) {
    for (final fixture in _fixtures.entries) {
      // Catches omitted shades, wrong mode/base labels, or pretending this
      // read-only visualization is a tappable control.
      testWidgets(
        '${fixture.key.label} actual shades are an image, dark=$dark',
        (tester) async {
          final handle = tester.ensureSemantics();
          await _pump(
            tester,
            mode: fixture.key,
            shades: fixture.value,
            dark: dark,
          );
          final node = tester.getSemantics(
            find.bySemanticsLabel(RegExp('^${fixture.key.label} harmony')),
          );
          expect(
            node,
            matchesSemantics(
              isImage: true,
              label: node.label,
              textDirection: TextDirection.ltr,
            ),
          );
          expect(node.label, contains('Base #FF0000'));
          expect(node.label, contains(fixture.value.join(', ')));
          expect(
            node.getSemanticsData().hasAction(ui.SemanticsAction.tap),
            isFalse,
          );
          final pixels = await _pixels(tester);
          final centers = _markerCenters[fixture.key]!;
          for (var i = 0; i < centers.length; i++) {
            final value = int.parse(fixture.value[i].substring(1), radix: 16);
            _expectRgb(pixels, centers[i].$1, centers[i].$2, [
              value >> 16,
              (value >> 8) & 255,
              value & 255,
            ]);
          }
          _expectRgb(pixels, 160, 16, dark ? [30, 33, 40] : [240, 241, 244]);
          // Every exact supplied RGB must occur in the diagram, even when hue
          // geometry alone would otherwise overpaint monochromatic shades.
          final painted = <int>{
            for (var i = 0; i < pixels.length; i += 4)
              (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2],
          };
          for (final shade in fixture.value) {
            expect(painted, contains(int.parse(shade.substring(1), radix: 16)));
          }
          expect(tester.takeException(), isNull);
          handle.dispose();
        },
      );
    }
  }

  testWidgets('hue ring starts red at top and progresses clockwise', (
    tester,
  ) async {
    await _pump(tester);
    final pixels = await _pixels(tester);
    _expectRgb(pixels, 160, 29, [255, 0, 0]);
    _expectRgb(pixels, 291, 160, [128, 255, 0]);
    _expectRgb(pixels, 160, 291, [0, 255, 255]);
    _expectRgb(pixels, 29, 160, [128, 0, 255]);
    // Marker centers reflect the actual supplied RGB, not ring saturation.
    _expectRgb(pixels, 160, 64, [255, 0, 0]);
    _expectRgb(pixels, 160, 256, [0, 255, 255]);
    // A complementary relationship joins the two actual marker positions.
    expect(_rgb(pixels, 160, 190), isNot(_rgb(pixels, 190, 190)));
  });

  testWidgets('base and supplied RGB changes repaint actual markers', (
    tester,
  ) async {
    await _pump(tester);
    final first = _painter(tester);
    await _pump(tester, base: '#008000', shades: ['#008000', '#800080']);
    expect(_painter(tester).shouldRepaint(first), isTrue);
    final pixels = await _pixels(tester);
    // Green hue 120 degrees: x=243, y=208 on the 96px marker radius.
    _expectRgb(pixels, 243, 208, [0, 128, 0]);
    _expectRgb(pixels, 77, 112, [128, 0, 128]);
    final old = _painter(tester);
    await _pump(tester, base: '#008000', shades: ['#008000', '#FF8000']);
    expect(_painter(tester).shouldRepaint(old), isTrue);
    _expectRgb(await _pixels(tester), 77, 112, [240, 241, 244]);
  });

  testWidgets(
    'monochromatic shades occupy separate darker-to-lighter positions',
    (tester) async {
      await _pump(tester);
      final old = _painter(tester);
      await _pump(
        tester,
        mode: HarmonyMode.monochromatic,
        shades: _fixtures[HarmonyMode.monochromatic]!,
      );
      expect(_painter(tester).shouldRepaint(old), isTrue);
      final pixels = await _pixels(tester);
      _expectRgb(pixels, 64, 160, [102, 0, 0]);
      _expectRgb(pixels, 112, 160, [179, 0, 0]);
      _expectRgb(pixels, 160, 160, [255, 0, 0]);
      _expectRgb(pixels, 208, 160, [255, 77, 77]);
      _expectRgb(pixels, 256, 160, [255, 153, 153]);
      expect(find.textContaining('darker to lighter'), findsOneWidget);
    },
  );

  testWidgets('changing only the base moves its identifying double outline', (
    tester,
  ) async {
    await _pump(tester);
    final first = _painter(tester);
    _expectRgb(await _pixels(tester), 160, 49, [15, 17, 21]);
    await _pump(tester, base: '#00FFFF');
    expect(_painter(tester).shouldRepaint(first), isTrue);
    final pixels = await _pixels(tester);
    _expectRgb(pixels, 160, 49, [240, 241, 244]);
    _expectRgb(pixels, 160, 241, [15, 17, 21]);
  });

  for (final neutral in ['#000000', '#808080', '#FFFFFF']) {
    testWidgets('neutral $neutral has no invented hue marker', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, base: neutral, shades: [neutral]);
      expect(find.textContaining('no hue'), findsOneWidget);
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Complementary harmony')),
      );
      expect(node.label, contains('no hue'));
      expect(node.label, contains(neutral));
      final pixels = await _pixels(tester);
      final value = int.parse(neutral.substring(1, 3), radix: 16);
      _expectRgb(pixels, 160, 160, [value, value, value]);
      // The RGB model's canonical neutral hue is 0; it must not be painted
      // as a misleading red-angle marker at the top of the inner wheel.
      _expectRgb(pixels, 160, 64, [240, 241, 244]);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  }

  testWidgets(
    'neutral monochromatic shades retain distinct lightness and HEX',
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        base: '#808080',
        mode: HarmonyMode.monochromatic,
        shades: ['#808080', '#343434', '#5A5A5A', '#A6A6A6', '#CDCDCD'],
      );
      final pixels = await _pixels(tester);
      _expectRgb(pixels, 64, 160, [52, 52, 52]);
      _expectRgb(pixels, 112, 160, [90, 90, 90]);
      _expectRgb(pixels, 160, 160, [128, 128, 128]);
      _expectRgb(pixels, 208, 160, [166, 166, 166]);
      _expectRgb(pixels, 256, 160, [205, 205, 205]);
      expect(
        tester
            .getSemantics(
              find.bySemanticsLabel(RegExp('^Monochromatic harmony')),
            )
            .label,
        contains('#808080, #343434, #5A5A5A, #A6A6A6, #CDCDCD'),
      );
      handle.dispose();
    },
  );

  for (final dark in [false, true]) {
    testWidgets('360px 2x text reduced motion remains readable, dark=$dark', (
      tester,
    ) async {
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
      for (final fixture in _fixtures.entries) {
        await _pump(
          tester,
          mode: fixture.key,
          shades: fixture.value,
          dark: dark,
        );
        expect(tester.getSize(find.byKey(_diagram)), const Size(320, 320));
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      }
      await _pump(tester, base: '#808080', shades: ['#808080'], dark: dark);
      expect(find.textContaining('no hue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
