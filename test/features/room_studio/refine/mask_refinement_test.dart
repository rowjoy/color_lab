import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_stroke.dart';
import 'package:color_lab/features/room_studio/domain/mask_undo.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/refine/mask_refinement.dart';
import 'package:color_lab/features/room_studio/refine/mask_refinement_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

MaskBitmap bitmap(int width, int height, List<int> labels) => MaskBitmap(
  width: width,
  height: height,
  labels: Uint8List.fromList(labels),
);

MaskStroke stroke(
  List<List<MaskPoint>> segments, {
  RoomLayer layer = RoomLayer.floor,
  MaskEditMode mode = MaskEditMode.add,
  double diameter = .01,
}) => MaskStroke(
  layer: layer,
  mode: mode,
  segments: segments,
  diameterFraction: diameter,
);

void main() {
  group('stroke inputs', () {
    test('rejects nonfinite and out-of-image coordinates', () {
      for (final invalid in [double.nan, double.infinity, -.01, 1.01]) {
        expect(() => MaskPoint(invalid, .5), throwsArgumentError);
        expect(() => MaskPoint(.5, invalid), throwsArgumentError);
      }
      expect(MaskPoint(0, 1).x, 0);
    });

    test('rejects empty strokes and invalid diameter fractions', () {
      expect(() => stroke([]), throwsArgumentError);
      expect(() => stroke([[]]), throwsArgumentError);
      for (final invalid in <double>[
        double.nan,
        double.infinity,
        0,
        .009,
        .201,
      ]) {
        expect(
          () => stroke([
            [MaskPoint(.5, .5)],
          ], diameter: invalid),
          throwsArgumentError,
        );
      }
    });

    test('snapshots nested segments and defaults to five percent', () {
      final points = [MaskPoint(.25, .25)];
      final segments = [points];
      final input = MaskStroke(
        layer: RoomLayer.wall,
        mode: MaskEditMode.add,
        segments: segments,
      );
      points.clear();
      segments.clear();
      expect(input.diameterFraction, .05);
      expect(input.segments.single.single.x, .25);
      expect(() => input.segments.clear(), throwsUnsupportedError);
      expect(() => input.segments.single.clear(), throwsUnsupportedError);
    });
  });

  test('point transfers ownership and undo restores the literal original', () {
    final ai = bitmap(2, 2, [1, 2, 0, 4]);
    final edit = applyMaskStroke(
      current: ai,
      ai: ai,
      stroke: stroke([
        [MaskPoint(.25, .25)],
      ]),
    );
    expect(edit.masks.labels, [3, 2, 0, 4]);
    expect(ai.labels, [1, 2, 0, 4]);
    expect(edit.changedFromAiCount, 1);
    expect(edit.undo!.indices, [0]);
    expect(edit.undo!.previousLabels, [1]);
    final restored = undoMaskStroke(
      current: edit.masks,
      ai: ai,
      command: edit.undo!,
    );
    expect(restored.masks.labels, [1, 2, 0, 4]);
    expect(restored.changedFromAiCount, 0);
    expect(restored.undo, isNull);
  });

  test('erase affects only selected ownership and no-op has no command', () {
    final ai = bitmap(3, 1, [3, 1, 2]);
    final noOp = applyMaskStroke(
      current: ai,
      ai: ai,
      stroke: stroke(
        [
          [MaskPoint(1 / 6, .5)],
        ],
        layer: RoomLayer.wall,
        mode: MaskEditMode.erase,
      ),
    );
    expect(noOp.masks.labels, [3, 1, 2]);
    expect(noOp.undo, isNull);
    final edit = applyMaskStroke(
      current: ai,
      ai: ai,
      stroke: stroke(
        [
          [MaskPoint(0, .5), MaskPoint(1, .5)],
        ],
        layer: RoomLayer.wall,
        mode: MaskEditMode.erase,
      ),
    );
    expect(edit.masks.labels, [3, 0, 2]);
    expect(edit.undo!.indices, [1]);
    expect(edit.undo!.previousLabels, [1]);
    expect(edit.changedFromAiCount, 1);
  });

  test('adding existing ownership omits unchanged pixels from the delta', () {
    final ai = bitmap(3, 1, [3, 1, 3]);
    final edit = applyMaskStroke(
      current: ai,
      ai: ai,
      stroke: stroke([
        [MaskPoint(0, .5), MaskPoint(1, .5)],
      ]),
    );
    expect(edit.masks.labels, [3, 3, 3]);
    expect(edit.undo!.indices, [1]);
    expect(edit.undo!.previousLabels, [1]);
    final noOp = applyMaskStroke(
      current: edit.masks,
      ai: ai,
      stroke: stroke([
        [MaskPoint(.5, .5)],
      ]),
    );
    expect(noOp.undo, isNull);
    expect(noOp.changedFromAiCount, 1);
  });

  test(
    'interpolates a diagonal by pixel-center distance without smoothing',
    () {
      final ai = bitmap(5, 5, List.filled(25, 0));
      final edit = applyMaskStroke(
        current: ai,
        ai: ai,
        stroke: stroke([
          [MaskPoint(.1, .1), MaskPoint(.9, .9)],
        ], diameter: .2),
      );
      expect(edit.masks.labels, [
        3,
        0,
        0,
        0,
        0,
        0,
        3,
        0,
        0,
        0,
        0,
        0,
        3,
        0,
        0,
        0,
        0,
        0,
        3,
        0,
        0,
        0,
        0,
        0,
        3,
      ]);
      expect(edit.undo!.indices, [0, 6, 12, 18, 24]);
    },
  );

  test('separate segments never bridge an excursion outside the image', () {
    final ai = bitmap(5, 1, [0, 0, 0, 0, 0]);
    final edit = applyMaskStroke(
      current: ai,
      ai: ai,
      stroke: stroke([
        [MaskPoint(.1, .5)],
        [MaskPoint(.9, .5)],
      ]),
    );
    expect(edit.masks.labels, [3, 0, 0, 0, 3]);
  });

  test('radius uses the shorter image side', () {
    final ai = bitmap(10, 2, List.filled(20, 0));
    final edit = applyMaskStroke(
      current: ai,
      ai: ai,
      stroke: stroke([
        [MaskPoint(.25, .25)],
      ], diameter: .2),
    );
    expect(edit.masks.labels, [
      0,
      0,
      3,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);
  });

  test('includes the exact radius boundary and clips at the image border', () {
    final ai = bitmap(5, 5, List.filled(25, 0));
    final edge = applyMaskStroke(
      current: ai,
      ai: ai,
      stroke: stroke([
        [MaskPoint(0, 0), MaskPoint(0, 1)],
      ], diameter: .2),
    );
    expect(edge.masks.labels, [
      3,
      0,
      0,
      0,
      0,
      3,
      0,
      0,
      0,
      0,
      3,
      0,
      0,
      0,
      0,
      3,
      0,
      0,
      0,
      0,
      3,
      0,
      0,
      0,
      0,
    ]);
    final point = applyMaskStroke(
      current: ai,
      ai: ai,
      stroke: stroke([
        [MaskPoint(.2, .1)],
      ], diameter: .2),
    );
    expect(point.undo!.indices, [0, 1]);
  });

  test(
    'repeated points and overlapping segments record each old label once',
    () {
      final ai = bitmap(3, 1, [4, 2, 1]);
      final edit = applyMaskStroke(
        current: ai,
        ai: ai,
        stroke: stroke([
          [
            MaskPoint(1, .5),
            MaskPoint(0, .5),
            MaskPoint(0, .5),
            MaskPoint(1, .5),
          ],
        ]),
      );
      expect(edit.masks.labels, [3, 3, 3]);
      expect(edit.undo!.indices, [0, 1, 2]);
      expect(edit.undo!.previousLabels, [4, 2, 1]);
    },
  );

  test('rejects mismatched AI and undo dimensions before editing', () {
    final current = bitmap(2, 1, [0, 0]);
    final ai = bitmap(1, 2, [0, 0]);
    final command = MaskUndoCommand(
      width: 1,
      height: 2,
      indices: Uint32List.fromList([0]),
      previousLabels: Uint8List.fromList([1]),
    );
    expect(
      () => applyMaskStroke(
        current: current,
        ai: ai,
        stroke: stroke([
          [MaskPoint(.5, .5)],
        ]),
      ),
      throwsArgumentError,
    );
    expect(
      () => undoMaskStroke(current: current, ai: current, command: command),
      throwsArgumentError,
    );
    expect(
      () => undoMaskStroke(current: current, ai: ai, command: command),
      throwsArgumentError,
    );
  });

  test('dirty count survives eviction and undo of every retained command', () {
    final ai = bitmap(30, 1, List.filled(30, 0));
    var current = ai;
    var history = MaskUndoHistory();
    for (var i = 0; i < 21; i++) {
      final edit = applyMaskStroke(
        current: current,
        ai: ai,
        stroke: stroke([
          [MaskPoint((i + .5) / 30, .5)],
        ]),
      );
      current = edit.masks;
      history = history.push(edit.undo!);
    }
    expect(history.commands.length, 20);
    MaskEditResult? restored;
    while (history.canUndo) {
      restored = undoMaskStroke(
        current: current,
        ai: ai,
        command: history.last!,
      );
      current = restored.masks;
      history = history.withoutLast();
    }
    expect(current.labels, [
      3,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
    ]);
    expect(restored!.changedFromAiCount, 1);
  });

  test(
    'real compute service round trip returns exact bytes and immutable delta',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final service = container.read(maskRefinementServiceProvider);
      expect(service, isA<IsolateMaskRefinementService>());
      final ai = bitmap(2, 2, [1, 2, 0, 4]);
      final edit = await service.apply(
        current: ai,
        ai: ai,
        stroke: stroke([
          [MaskPoint(.25, .25)],
        ]),
      );
      expect(edit.masks.labels, [3, 2, 0, 4]);
      expect(edit.changedFromAiCount, 1);
      expect(edit.undo!.previousLabels, [1]);
      expect(() => edit.undo!.indices[0] = 1, throwsUnsupportedError);
      final restored = await service.undo(
        current: edit.masks,
        ai: ai,
        command: edit.undo!,
      );
      expect(restored.masks.labels, [1, 2, 0, 4]);
      expect(restored.changedFromAiCount, 0);
      expect(restored.undo, isNull);
    },
  );
}
