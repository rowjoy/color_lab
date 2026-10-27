import 'dart:typed_data';

import 'mask_bitmap.dart';
import 'mask_intent_bitmap.dart';
import 'room_project.dart' show RoomProjectLimits;

final class MaskEditResult {
  MaskEditResult({required this.masks, required this.intent}) {
    if (masks.width != intent.width || masks.height != intent.height) {
      throw ArgumentError('Ownership and intent must be aligned.');
    }
  }
  final MaskBitmap masks;
  final MaskIntentBitmap intent;
}

/// Exact before/after bytes for one complete committed edit.
final class MaskEditCommand {
  factory MaskEditCommand({
    required int width,
    required int height,
    required Uint32List indices,
    required Uint8List beforeLabels,
    required Uint8List afterLabels,
    required Uint8List beforeIntent,
    required Uint8List afterIntent,
  }) {
    if (width < 1 ||
        height < 1 ||
        width > RoomProjectLimits.maxDimension ||
        height > RoomProjectLimits.maxDimension ||
        width * height > RoomProjectLimits.maxPixels ||
        indices.isEmpty ||
        [
          beforeLabels,
          afterLabels,
          beforeIntent,
          afterIntent,
        ].any((values) => values.length != indices.length)) {
      throw ArgumentError(
        'Bounded dimensions and matching nonempty deltas required.',
      );
    }
    var previous = -1;
    var changed = false;
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] <= previous ||
          indices[i] >= width * height ||
          beforeLabels[i] > 4 ||
          afterLabels[i] > 4 ||
          beforeIntent[i] > 5 ||
          afterIntent[i] > 5) {
        throw ArgumentError(
          'Sorted unique in-bounds indices and valid bytes required.',
        );
      }
      previous = indices[i];
      changed |=
          beforeLabels[i] != afterLabels[i] ||
          beforeIntent[i] != afterIntent[i];
    }
    if (!changed) {
      throw ArgumentError('A command must change ownership or intent.');
    }
    return MaskEditCommand._(
      width,
      height,
      Uint32List.fromList(indices).asUnmodifiableView(),
      Uint8List.fromList(beforeLabels).asUnmodifiableView(),
      Uint8List.fromList(afterLabels).asUnmodifiableView(),
      Uint8List.fromList(beforeIntent).asUnmodifiableView(),
      Uint8List.fromList(afterIntent).asUnmodifiableView(),
    );
  }

  const MaskEditCommand._(
    this.width,
    this.height,
    this.indices,
    this.beforeLabels,
    this.afterLabels,
    this.beforeIntent,
    this.afterIntent,
  );
  final int width;
  final int height;
  final Uint32List indices;
  final Uint8List beforeLabels;
  final Uint8List afterLabels;
  final Uint8List beforeIntent;
  final Uint8List afterIntent;
  int get byteLength =>
      indices.lengthInBytes +
      beforeLabels.lengthInBytes +
      afterLabels.lengthInBytes +
      beforeIntent.lengthInBytes +
      afterIntent.lengthInBytes;

  MaskEditResult applyForward({
    required MaskBitmap masks,
    required MaskIntentBitmap intent,
  }) => _apply(
    masks,
    intent,
    beforeLabels,
    beforeIntent,
    afterLabels,
    afterIntent,
  );
  MaskEditResult applyBackward({
    required MaskBitmap masks,
    required MaskIntentBitmap intent,
  }) => _apply(
    masks,
    intent,
    afterLabels,
    afterIntent,
    beforeLabels,
    beforeIntent,
  );

  MaskEditResult _apply(
    MaskBitmap masks,
    MaskIntentBitmap intent,
    Uint8List expectedLabels,
    Uint8List expectedIntent,
    Uint8List nextLabels,
    Uint8List nextIntent,
  ) {
    if (masks.width != width ||
        masks.height != height ||
        intent.width != width ||
        intent.height != height) {
      throw ArgumentError(
        'Command, ownership and intent dimensions must match.',
      );
    }
    for (var i = 0; i < indices.length; i++) {
      if (masks.labels[indices[i]] != expectedLabels[i] ||
          intent.intentAt(indices[i]) != expectedIntent[i]) {
        throw StateError(
          'The command does not match the current indexed state.',
        );
      }
    }
    final labels = Uint8List.fromList(masks.labels);
    for (var i = 0; i < indices.length; i++) {
      labels[indices[i]] = nextLabels[i];
    }
    return MaskEditResult(
      masks: MaskBitmap(width: width, height: height, labels: labels),
      intent: intent.apply(indices, nextIntent),
    );
  }
}
