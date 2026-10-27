import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_edit_command.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';
import 'package:flutter_test/flutter_test.dart';

MaskBitmap labels(List<int> values, {int width = 3, int height = 2}) =>
    MaskBitmap(
      width: width,
      height: height,
      labels: Uint8List.fromList(values),
    );
MaskIntentBitmap intents(List<int> values, {int width = 3, int height = 2}) =>
    MaskIntentBitmap.fromBytes(
      width: width,
      height: height,
      bytes: Uint8List.fromList(values),
    );

MaskEditCommand command({
  int width = 3,
  int height = 2,
  List<int> indices = const [0, 2, 5],
  List<int> before = const [1, 3, 4],
  List<int> after = const [0, 2, 4],
  List<int> beforeIntent = const [0, 3, 0],
  List<int> afterIntent = const [1, 3, 5],
}) => MaskEditCommand(
  width: width,
  height: height,
  indices: Uint32List.fromList(indices),
  beforeLabels: Uint8List.fromList(before),
  afterLabels: Uint8List.fromList(after),
  beforeIntent: Uint8List.fromList(beforeIntent),
  afterIntent: Uint8List.fromList(afterIntent),
);

void main() {
  test(
    'command detaches every payload and exposes immutable typed-array and buffer views',
    () {
      final indices = Uint32List.fromList([0, 2]);
      final arrays = [
        Uint8List.fromList([1, 3]),
        Uint8List.fromList([0, 2]),
        Uint8List.fromList([0, 4]),
        Uint8List.fromList([1, 3]),
      ];
      final edit = MaskEditCommand(
        width: 3,
        height: 2,
        indices: indices,
        beforeLabels: arrays[0],
        afterLabels: arrays[1],
        beforeIntent: arrays[2],
        afterIntent: arrays[3],
      );
      indices[0] = 1;
      for (final input in arrays) {
        input[0] = 5;
      }
      expect(edit.indices, [0, 2]);
      expect(edit.beforeLabels, [1, 3]);
      expect(edit.afterLabels, [0, 2]);
      expect(edit.beforeIntent, [0, 4]);
      expect(edit.afterIntent, [1, 3]);
      expect(edit.byteLength, 16);
      expect(() => edit.indices[0] = 1, throwsUnsupportedError);
      expect(
        () => edit.indices.buffer.asUint32List()[0] = 1,
        throwsUnsupportedError,
      );
      for (final output in [
        edit.beforeLabels,
        edit.afterLabels,
        edit.beforeIntent,
        edit.afterIntent,
      ]) {
        expect(() => output[0] = 0, throwsUnsupportedError);
        expect(
          () => output.buffer.asUint8List()[0] = 0,
          throwsUnsupportedError,
        );
      }
    },
  );

  test(
    'command rejects invalid dimensions, lengths, order, values and complete no-ops',
    () {
      for (final size in [
        (0, 1),
        (1, 0),
        (-1, 1),
        (4097, 1),
        (9223372036854775807, 2),
      ]) {
        expect(
          () => command(width: size.$1, height: size.$2),
          throwsArgumentError,
        );
      }
      for (final indices in [
        <int>[],
        [0],
        [2, 0, 5],
        [0, 0, 5],
        [0, 2, 6],
        [0, 2, 4294967295],
      ]) {
        expect(() => command(indices: indices), throwsArgumentError);
      }
      for (final values in [
        <int>[],
        [0],
        [0, 2, 3, 4],
        [5, 2, 3],
        [255, 2, 3],
      ]) {
        expect(() => command(before: values), throwsArgumentError);
        expect(() => command(after: values), throwsArgumentError);
      }
      for (final values in [
        <int>[],
        [0],
        [0, 2, 3, 4],
        [6, 2, 3],
        [255, 2, 3],
      ]) {
        expect(() => command(beforeIntent: values), throwsArgumentError);
        expect(() => command(afterIntent: values), throwsArgumentError);
      }
      expect(
        () => command(after: [1, 3, 4], afterIntent: [0, 3, 0]),
        throwsArgumentError,
      );
      // An intent-only choice is an actual edit even when ownership does not change.
      expect(command(after: [1, 3, 4]).byteLength, 24);
    },
  );

  test(
    'forward and backward restore exact ownership and intent without touching unrelated pixels',
    () {
      final beforeMasks = labels([1, 2, 3, 0, 1, 4]);
      final beforeIntent = intents([0, 2, 3, 0, 5, 0]);
      final edit = command();
      final next = edit.applyForward(masks: beforeMasks, intent: beforeIntent);
      expect(next.masks.labels, [0, 2, 2, 0, 1, 4]);
      expect(next.intent.bytes, [1, 2, 3, 0, 5, 5]);
      expect(beforeMasks.labels, [1, 2, 3, 0, 1, 4]);
      expect(beforeIntent.bytes, [0, 2, 3, 0, 5, 0]);
      final restored = edit.applyBackward(
        masks: next.masks,
        intent: next.intent,
      );
      expect(restored.masks.labels, [1, 2, 3, 0, 1, 4]);
      expect(restored.intent.bytes, [0, 2, 3, 0, 5, 0]);
      expect(identical(restored.masks.labels, beforeMasks.labels), isFalse);
      expect(identical(restored.intent.bytes, beforeIntent.bytes), isFalse);
    },
  );

  test(
    'application rejects stale indexed label or intent and mismatched axes atomically',
    () {
      final edit = command();
      final masks = labels([1, 2, 3, 0, 1, 4]);
      final intent = intents([0, 2, 3, 0, 5, 0]);
      expect(
        () => edit.applyForward(
          masks: labels([1, 2, 3, 0, 1, 0]),
          intent: intent,
        ),
        throwsStateError,
      );
      expect(
        () => edit.applyForward(
          masks: masks,
          intent: intents([0, 2, 3, 0, 5, 1]),
        ),
        throwsStateError,
      );
      expect(
        () => edit.applyBackward(masks: masks, intent: intent),
        throwsStateError,
      );
      expect(
        () => edit.applyForward(
          masks: labels([1, 2, 3, 0, 1, 4], width: 2, height: 3),
          intent: intent,
        ),
        throwsArgumentError,
      );
      expect(
        () => edit.applyForward(
          masks: masks,
          intent: intents([0, 2, 3, 0, 5, 0], width: 2, height: 3),
        ),
        throwsArgumentError,
      );
      expect(masks.labels, [1, 2, 3, 0, 1, 4]);
      expect(intent.bytes, [0, 2, 3, 0, 5, 0]);
    },
  );
}
