import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';

import '../../../support/room_project_fixtures.dart';

void main() {
  test(
    'new snapshots own aligned immutable untouched intent rather than inferred edits',
    () {
      final snapshot = roomProjectFixture();
      expect(snapshot.schemaVersion, 2);
      final intent = snapshot.intent;
      expect((intent.width, intent.height), (2, 2));
      expect(intent.bytes, [0, 0, 0, 0]);
      expect(() => intent.bytes[0] = 1, throwsUnsupportedError);
      final edited = intent.apply(
        Uint32List.fromList([0, 1, 3]),
        Uint8List.fromList([1, 5, 2]),
      );
      expect(edited.bytes, [1, 5, 0, 2]);
      expect(intent.bytes, [0, 0, 0, 0]);
      final copied = snapshot.copyWith(name: 'Copy');
      expect(copied.intent.bytes, [0, 0, 0, 0]);
    },
  );
  test(
    'factories validate bounded positive dimensions, exact length and 0 through 5 before allocating',
    () {
      for (final size in [
        (0, 1),
        (1, 0),
        (-1, 2),
        (4097, 1),
        (1, 4097),
        (9223372036854775807, 2),
        (4294967296, 4294967296),
      ]) {
        expect(
          () => MaskIntentBitmap.untouched(width: size.$1, height: size.$2),
          throwsArgumentError,
        );
        expect(
          () => MaskIntentBitmap.fromBytes(
            width: size.$1,
            height: size.$2,
            bytes: Uint8List(0),
          ),
          throwsArgumentError,
        );
      }
      for (final bytes in [
        Uint8List(0),
        Uint8List(1),
        Uint8List(3),
        Uint8List.fromList([0, 6]),
        Uint8List.fromList([255, 0]),
      ]) {
        expect(
          () => MaskIntentBitmap.fromBytes(width: 2, height: 1, bytes: bytes),
          throwsArgumentError,
        );
      }
      final input = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
      final intent = MaskIntentBitmap.fromBytes(
        width: 3,
        height: 2,
        bytes: input,
      );
      input.fillRange(0, 6, 0);
      expect(intent.bytes, [0, 1, 2, 3, 4, 5]);
      expect(
        [for (var i = 0; i < 6; i++) intent.intentAt(i)],
        [0, 1, 2, 3, 4, 5],
      );
      expect(() => intent.intentAt(-1), throwsRangeError);
      expect(() => intent.intentAt(6), throwsRangeError);
      expect(() => intent.bytes[0] = 1, throwsUnsupportedError);
      expect(
        () => intent.bytes.buffer.asUint8List()[0] = 1,
        throwsUnsupportedError,
      );
    },
  );

  test(
    'apply copies updates and rejects unequal, unsorted, duplicate, out-of-bounds or invalid updates',
    () {
      final original = MaskIntentBitmap.fromBytes(
        width: 3,
        height: 2,
        bytes: Uint8List.fromList([0, 1, 2, 3, 4, 5]),
      );
      for (final update in [
        ([0], <int>[]),
        ([1, 0], [2, 3]),
        ([1, 1], [2, 3]),
        ([6], [1]),
        ([4294967295], [1]),
        ([1], [6]),
        ([1], [255]),
      ]) {
        expect(
          () => original.apply(
            Uint32List.fromList(update.$1),
            Uint8List.fromList(update.$2),
          ),
          throwsArgumentError,
        );
      }
      final indices = Uint32List.fromList([0, 1, 2, 3, 4, 5]);
      final values = Uint8List.fromList([5, 4, 3, 2, 1, 0]);
      final changed = original.apply(indices, values);
      expect(indices, [0, 1, 2, 3, 4, 5]);
      expect(values, [5, 4, 3, 2, 1, 0]);
      indices[0] = 5;
      values[0] = 0;
      expect(changed.bytes, [5, 4, 3, 2, 1, 0]);
      expect(original.bytes, [0, 1, 2, 3, 4, 5]);
      expect(original.apply(Uint32List(0), Uint8List(0)).bytes, [
        0,
        1,
        2,
        3,
        4,
        5,
      ]);
    },
  );

  test(
    'merge gives refreshed AI only untouched pixels and every explicit intent wins',
    () {
      final intent = MaskIntentBitmap.fromBytes(
        width: 3,
        height: 2,
        bytes: Uint8List.fromList([0, 1, 2, 3, 4, 5]),
      );
      // Explicit values encode the previous AI exactly; equality must not erase intent.
      final old = MaskBitmap(
        width: 3,
        height: 2,
        labels: Uint8List.fromList([0, 0, 1, 2, 3, 4]),
      );
      expect(mergeAiWithIntent(refreshedAi: old, intent: intent).labels, [
        0,
        0,
        1,
        2,
        3,
        4,
      ]);
      final fresh = MaskBitmap(
        width: 3,
        height: 2,
        labels: Uint8List.fromList([4, 4, 4, 4, 4, 0]),
      );
      final merged = mergeAiWithIntent(refreshedAi: fresh, intent: intent);
      expect(merged.labels, [4, 0, 1, 2, 3, 4]);
      expect(identical(merged.labels, fresh.labels), isFalse);
      expect(fresh.labels, [4, 4, 4, 4, 4, 0]);
      expect(intent.bytes, [0, 1, 2, 3, 4, 5]);
      expect(
        () => mergeAiWithIntent(
          refreshedAi: MaskBitmap(width: 2, height: 3, labels: Uint8List(6)),
          intent: intent,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'snapshot copy retains explicit intent and rejects mismatched dimensions',
    () {
      final source = Uint8List.fromList([1, 2, 3, 5]);
      final intent = MaskIntentBitmap.fromBytes(
        width: 2,
        height: 2,
        bytes: source,
      );
      final snapshot = roomProjectFixture().copyWith(intent: intent);
      source.fillRange(0, 4, 0);
      expect(snapshot.copyWith(name: 'Renamed').intent.bytes, [1, 2, 3, 5]);
      expect(snapshot.copyWith(projectId: 'duplicate').intent.bytes, [
        1,
        2,
        3,
        5,
      ]);
      expect(
        () => snapshot.copyWith(
          intent: MaskIntentBitmap.untouched(width: 1, height: 4),
        ),
        throwsArgumentError,
      );
    },
  );
}
