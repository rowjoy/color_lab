import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_review_panel.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_surface_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual review distinguishes unchecked empty, absent, coverage and reviewed reversibly', () {
    final masks = MaskBitmap(width: 2, height: 2, labels: Uint8List.fromList([1, 1, 0, 3]));
    var review = RoomMaskReview();
    expect(review.status(RoomLayer.wall, masks), RoomMaskSurfaceStatus.hasCoverage);
    expect(review.status(RoomLayer.ceiling, masks), RoomMaskSurfaceStatus.notReviewed);
    review = review.markLayerChecked(RoomLayer.wall).markLayerChecked(RoomLayer.ceiling);
    expect(review.status(RoomLayer.wall, masks), RoomMaskSurfaceStatus.reviewed);
    expect(review.status(RoomLayer.ceiling, masks), RoomMaskSurfaceStatus.absent);
    expect(review.complete, isFalse);
    review = review.markLayerChecked(RoomLayer.floor).markLayerChecked(RoomLayer.furniture);
    expect(review.complete, isTrue); expect(review.reopen(RoomLayer.wall).complete, isFalse);
    expect(masks.labels, [1, 1, 0, 3]);
    expect(roomPixelCoverage(masks, RoomLayer.wall), '2 of 4 working-image pixels (50.0%)');
    expect(RoomLayer.values.map(roomSurfacePattern).toSet(), hasLength(4));
  });

  for (final size in [const Size(320, 568), const Size(568, 320), const Size(840, 600)]) {
    testWidgets('manual review is reachable in RTL high contrast 200 percent at $size', (tester) async {
      tester.view.physicalSize = size; tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      var layer = RoomLayer.wall; var view = RoomMaskReviewView.overlay; var completed = 0;
      final masks = MaskBitmap(width: 2, height: 2, labels: Uint8List.fromList([1, 0, 0, 0]));
      await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: StatefulBuilder(
        builder: (context, update) => MediaQuery(
          data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2), highContrast: true),
          child: Directionality(textDirection: TextDirection.rtl, child: Scaffold(
            body: SingleChildScrollView(child: RoomMaskReviewPanel(
              photoId: 'photo', maskRevision: 0, masks: masks, selectedLayer: layer,
              view: view, onSelect: (next) => update(() => layer = next),
              onViewChanged: (next) => update(() => view = next), onDone: () => completed++,
            )),
          )),
        ),
      )));
      for (final surface in RoomLayer.values) {
        final chip = find.byKey(ValueKey('mask-review-layer-${surface.name}'));
        await tester.ensureVisible(chip); await tester.tap(chip); await tester.pump();
        final check = find.byKey(const ValueKey('mask-review-check'));
        await tester.ensureVisible(check); await tester.tap(check); await tester.pump();
      }
      final done = find.byKey(const ValueKey('mask-review-done'));
      await tester.ensureVisible(done); await tester.tap(done); await tester.pump();
      expect(completed, 1); expect(tester.takeException(), isNull);
      final original = find.byKey(const ValueKey('mask-review-view-original'));
      await tester.ensureVisible(original); await tester.tap(original); await tester.pump();
      expect(view, RoomMaskReviewView.original); expect(masks.labels, [1, 0, 0, 0]);
    });
  }

  testWidgets('manual review leaves surface navigation and Cancel available while edits are busy', (tester) async {
    var selected = RoomLayer.wall; var cancelled = false;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: RoomMaskReviewPanel(
      photoId: 'p', maskRevision: 0,
      masks: MaskBitmap(width: 1, height: 1, labels: Uint8List(1)),
      selectedLayer: selected, busy: true,
      onSelect: (layer) => selected = layer, onViewChanged: (_) {},
      onCancel: () => cancelled = true,
    )))));
    await tester.tap(find.byKey(const ValueKey('mask-review-layer-furniture')));
    expect(selected, RoomLayer.furniture);
    final check = tester.widget<OutlinedButton>(find.byKey(const ValueKey('mask-review-check')));
    expect(check.onPressed, isNull);
    await tester.ensureVisible(find.text('Cancel review')); await tester.tap(find.text('Cancel review'));
    expect(cancelled, isTrue);
  });
}
