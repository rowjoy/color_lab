import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/presentation/room_layer_color_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows four selectable colors and accessible actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    RoomLayer? selected;
    var chooses = 0;
    var resets = 0;
    final colors = RoomLayerColors(
      wall: RgbColor.fromHex('#A7B5A0'),
      floor: RgbColor.fromHex('#D9BC9E'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RoomLayerColorControls(
              colors: colors,
              selectedLayer: RoomLayer.wall,
              enabled: true,
              onSelect: (layer) => selected = layer,
              onChoose: () => chooses++,
              onReset: () => resets++,
            ),
          ),
        ),
      ),
    );

    for (final layer in RoomLayer.values) {
      final finder = find.byKey(ValueKey('room-color-layer-${layer.name}'));
      expect(finder, findsOneWidget);
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
    }
    expect(find.text('#A7B5A0'), findsOneWidget);
    expect(find.text('#D9BC9E'), findsOneWidget);
    expect(find.text('Not set'), findsNWidgets(2));
    expect(
      tester
          .widget<ChoiceChip>(
            find.byKey(const ValueKey('room-color-layer-wall')),
          )
          .selected,
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('room-color-layer-floor')));
    await tester.tap(find.byKey(const ValueKey('room-color-choose')));
    await tester.tap(find.byKey(const ValueKey('room-color-reset')));
    expect(selected, RoomLayer.floor);
    expect(chooses, 1);
    expect(resets, 1);
    expect(
      tester.getSize(find.byKey(const ValueKey('room-color-choose'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('room-color-reset'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('reset is disabled when selected layer has no color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RoomLayerColorControls(
            colors: const RoomLayerColors(),
            selectedLayer: RoomLayer.ceiling,
            enabled: true,
            onSelect: (_) {},
            onChoose: () {},
            onReset: () {},
          ),
        ),
      ),
    );

    final reset = tester.widget<InkWell>(
      find.descendant(
        of: find.byKey(const ValueKey('room-color-reset')),
        matching: find.byType(InkWell),
      ),
    );
    expect(reset.onTap, isNull);
  });
}
