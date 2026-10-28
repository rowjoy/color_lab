import 'package:color_lab/l10n/l10n.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/presentation/coloring_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('second pointer cancels fill and a fresh tap works after pinch', (
    tester,
  ) async {
    final drawing = await AssetDrawingCatalogLoader().loadById(
      'fruit_red_apple',
    );
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 400,
              child: ColoringCanvas(
                definition: drawing,
                assignments: const {},
                onRegionTap: tapped.add,
              ),
            ),
          ),
        ),
      ),
    );
    final origin = tester.getTopLeft(find.byType(ColoringCanvas));
    final appleCenter = origin + const Offset(300, 250);

    final first = await tester.createGesture(pointer: 1);
    final second = await tester.createGesture(pointer: 2);
    await first.down(appleCenter);
    await second.down(appleCenter + const Offset(12, 0));
    await second.up();
    await first.up();
    await tester.pump();
    expect(tapped, isEmpty);

    final pinchA = await tester.createGesture(pointer: 3);
    final pinchB = await tester.createGesture(pointer: 4);
    await pinchA.down(appleCenter - const Offset(20, 0));
    await pinchB.down(appleCenter + const Offset(20, 0));
    await pinchA.moveTo(appleCenter - const Offset(60, 0));
    await pinchB.moveTo(appleCenter + const Offset(60, 0));
    await pinchB.up();
    await pinchA.up();
    await tester.pump();
    expect(tapped, isEmpty);

    await tester.tapAt(appleCenter);
    await tester.pump();
    expect(tapped, ['apple-body']);
  });
}
