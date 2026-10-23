import 'dart:typed_data';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/picker/presentation/photo_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../../support/in_memory_color_history_repository.dart';

PreparedPhoto fixture({int redColumns = 2}) {
  final image = img.Image(width: 4, height: 2);
  final bytes = <int>[];
  for (var y = 0; y < 2; y++) {
    for (var x = 0; x < 4; x++) {
      final red = x < redColumns;
      image.setPixelRgb(x, y, red ? 255 : 0, 0, red ? 0 : 255);
      bytes.addAll([red ? 255 : 0, 0, red ? 0 : 255, 255]);
    }
  }
  return PreparedPhoto(
    width: 4,
    height: 2,
    rgbaBytes: Uint8List.fromList(bytes),
    previewBytes: Uint8List.fromList(img.encodePng(image)),
    palette: [
      PaletteColor(RgbColor(255, 0, 0), redColumns / 4),
      PaletteColor(RgbColor(0, 0, 255), 1 - redColumns / 4),
    ],
  );
}

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    double scale = 1,
    PreparedPhoto? photo,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([
            NamedColor('Red', RgbColor(255, 0, 0)),
            NamedColor('Blue', RgbColor(0, 0, 255)),
          ]),
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => InMemoryColorHistoryRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 800),
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: PhotoPickerScreen(photo: photo ?? fixture()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'tap and drag sample actual pixels, ignore padding, and show image loupe',
    (tester) async {
      await launch(tester);
      final rect = tester.getRect(find.byKey(const ValueKey('photo-viewport')));
      await tester.tapAt(Offset(rect.left + rect.width * .2, rect.center.dy));
      await tester.pump();
      expect(find.byKey(const ValueKey('photo-selected-hex')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('photo-selected-hex')))
            .data,
        '#FF0000',
      );
      await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('photo-selected-hex')))
            .data,
        '#FF0000',
      );
      final drag = await tester.startGesture(
        Offset(rect.left + rect.width * .2, rect.center.dy),
      );
      await drag.moveTo(Offset(rect.left + rect.width * .8, rect.center.dy));
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('photo-selected-hex')))
            .data,
        '#0000FF',
      );
      expect(find.byKey(const ValueKey('photo-loupe')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('photo-loupe')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      await drag.up();
      await tester.pump();
      expect(find.byKey(const ValueKey('photo-loupe')), findsNothing);
    },
  );

  testWidgets(
    'pinch zoom and two-finger pan preserve transformed pixel sampling',
    (tester) async {
      await launch(tester);
      final rect = tester.getRect(find.byKey(const ValueKey('photo-viewport')));
      final first = await tester.startGesture(
        rect.center - const Offset(40, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        rect.center + const Offset(40, 0),
        pointer: 2,
      );
      await first.moveTo(rect.center - const Offset(80, 0));
      await second.moveTo(rect.center + const Offset(80, 0));
      await first.moveBy(const Offset(80, 0));
      await second.moveBy(const Offset(80, 0));
      await first.up();
      await second.up();
      await tester.pump();
      expect(find.text('2.0×'), findsOneWidget);
      // After 2x +80px pan, viewport center belongs to the red image half.
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('photo-selected-hex')))
            .data,
        '#FF0000',
      );
      await tester.tap(find.byTooltip('Reset photo zoom'));
      await tester.pump();
      await tester.tapAt(rect.center + Offset(rect.width * .1, 0));
      await tester.pump();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('photo-selected-hex')))
            .data,
        '#0000FF',
      );
    },
  );

  testWidgets('palette opens common gallery details and saves its source', (
    tester,
  ) async {
    final container = await launch(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('photo-palette-0')));
    await tester.tap(find.byKey(const ValueKey('photo-palette-0')));
    await tester.pumpAndSettle();
    final details = tester.widget<ColorDetails>(find.byType(ColorDetails));
    expect(details.color.hex, '#FF0000');
    expect(details.source, ColorSource.gallery);
    await tester.ensureVisible(find.text('Save color').last);
    await tester.tap(find.text('Save color').last);
    await tester.pumpAndSettle();
    expect(
      container.read(colorHistoryProvider).requireValue.single.source,
      ColorSource.gallery,
    );
    expect(
      container.read(colorHistoryProvider).requireValue.single.hex,
      '#FF0000',
    );
  });

  testWidgets(
    'palette bar displays actual populations and opens gallery color details',
    (tester) async {
      await launch(tester, photo: fixture(redColumns: 3));
      final bar = find.byKey(const ValueKey('photo-palette-bar'));
      expect(bar, findsOneWidget);
      await tester.ensureVisible(bar);
      final red = find.descendant(
        of: bar,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Material && widget.color == const Color(0xFFFF0000),
        ),
      );
      final blue = find.descendant(
        of: bar,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Material && widget.color == const Color(0xFF0000FF),
        ),
      );
      expect(
        tester.getSize(red).width / tester.getSize(blue).width,
        closeTo(3, .01),
      );
      await tester.ensureVisible(find.text('Color 2 · 25%'));
      await tester.tap(find.text('Color 2 · 25%'));
      await tester.pumpAndSettle();
      final details = tester.widget<ColorDetails>(find.byType(ColorDetails));
      expect(details.color.hex, '#0000FF');
      expect(details.source, ColorSource.gallery);
    },
  );

  testWidgets(
    '360px and 2x text scroll to all palette controls without overflow',
    (tester) async {
      await launch(tester, scale: 2);
      await tester.ensureVisible(find.byKey(const ValueKey('photo-palette-1')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final size = tester.getSize(
        find.byKey(const ValueKey('photo-palette-1')),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    },
  );
}
