import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_region_navigator.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_viewport.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manual region controls expose Add Erase Undo Redo and keyboard surface access', (tester) async {
    final view = RoomMaskViewportController(); addTearDown(view.dispose);
    var added = 0; var erased = 0; var undone = 0; var redone = 0; var layer = RoomLayer.wall;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: RoomMaskRegionNavigator(
      view: view, layer: layer, autofocus: true, onLayerSelected: (next) => layer = next,
      onAdd: () => added++, onErase: () => erased++, onUndo: () => undone++, onRedo: () => redone++,
    )))));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    expect(added, 1); expect(erased, 1); expect(layer, RoomLayer.ceiling);
    await tester.ensureVisible(find.text('Undo')); await tester.tap(find.text('Undo'));
    await tester.ensureVisible(find.text('Redo')); await tester.tap(find.text('Redo'));
    expect(undone, 1); expect(redone, 1);
    expect(find.byKey(const ValueKey('mask-region-2-2')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
