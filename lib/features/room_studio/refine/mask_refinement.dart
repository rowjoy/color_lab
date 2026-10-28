import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/mask_bitmap.dart';
import '../domain/mask_stroke.dart';
import '../domain/mask_edit_command.dart';
import '../domain/mask_intent_bitmap.dart';

final class MaskRefinementResult {
  const MaskRefinementResult({
    required this.masks,
    required this.intent,
    required this.command,
    required this.changedFromAiCount,
  });
  final MaskBitmap masks;
  final MaskIntentBitmap intent;
  final MaskEditCommand? command;
  final int changedFromAiCount;
}

int countMaskDifferences(MaskBitmap current, MaskBitmap ai) {
  _requireSameDimensions(current, ai);
  var count = 0;
  for (var i = 0; i < current.pixelCount; i++) {
    if (current.labels[i] != ai.labels[i]) count++;
  }
  return count;
}

/// Pure worker operation. The service runs rasterization and scans off the UI.
MaskRefinementResult applyMaskStroke({
  required MaskBitmap current,
  required MaskBitmap ai,
  required MaskIntentBitmap intent,
  required MaskStroke stroke,
}) {
  _requireSameDimensions(current, ai);
  if (intent.width != current.width || intent.height != current.height) {
    throw ArgumentError('Intent must match current ownership.');
  }
  final intents = Uint8List.fromList(intent.bytes);
  final labels = Uint8List.fromList(current.labels);
  final radius =
      stroke.diameterFraction * math.min(current.width, current.height) / 2;
  for (final segment in stroke.segments) {
    for (var i = 0; i < math.max(1, segment.length - 1); i++) {
      final start = segment[i];
      final end = segment.length == 1 ? start : segment[i + 1];
      _paintSegment(
        labels: labels,
        intents: intents,
        width: current.width,
        height: current.height,
        start: start,
        end: end,
        radius: radius,
        stroke: stroke,
      );
    }
  }

  var changedCount = 0;
  var changedFromAiCount = 0;
  for (var i = 0; i < labels.length; i++) {
    if (labels[i] != current.labels[i] || intents[i] != intent.intentAt(i)) {
      changedCount++;
    }
    if (labels[i] != ai.labels[i]) changedFromAiCount++;
  }
  MaskEditCommand? command;
  if (changedCount > 0) {
    final indices = Uint32List(changedCount);
    final beforeLabels = Uint8List(changedCount);
    final afterLabels = Uint8List(changedCount);
    final beforeIntent = Uint8List(changedCount);
    final afterIntent = Uint8List(changedCount);
    var position = 0;
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] == current.labels[i] && intents[i] == intent.intentAt(i)) {
        continue;
      }
      indices[position] = i;
      beforeLabels[position] = current.labels[i];
      afterLabels[position] = labels[i];
      beforeIntent[position] = intent.intentAt(i);
      afterIntent[position++] = intents[i];
    }
    command = MaskEditCommand(
      width: current.width,
      height: current.height,
      indices: indices,
      beforeLabels: beforeLabels,
      afterLabels: afterLabels,
      beforeIntent: beforeIntent,
      afterIntent: afterIntent,
    );
  }
  return MaskRefinementResult(
    masks: MaskBitmap(
      width: current.width,
      height: current.height,
      labels: labels,
    ),
    intent: MaskIntentBitmap.fromBytes(
      width: current.width,
      height: current.height,
      bytes: intents,
    ),
    command: command,
    changedFromAiCount: changedFromAiCount,
  );
}

void _requireSameDimensions(MaskBitmap current, MaskBitmap ai) {
  if (current.width != ai.width || current.height != ai.height) {
    throw ArgumentError('Current and AI ownership dimensions must match');
  }
}

void _paintSegment({
  required Uint8List labels,
  required Uint8List intents,
  required int width,
  required int height,
  required MaskPoint start,
  required MaskPoint end,
  required double radius,
  required MaskStroke stroke,
}) {
  final ax = start.x * width;
  final ay = start.y * height;
  final bx = end.x * width;
  final by = end.y * height;
  final minX = math.max(0, (math.min(ax, bx) - radius - .5).ceil());
  final maxX = math.min(width - 1, (math.max(ax, bx) + radius - .5).floor());
  final minY = math.max(0, (math.min(ay, by) - radius - .5).ceil());
  final maxY = math.min(height - 1, (math.max(ay, by) + radius - .5).floor());
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  final radiusSquared = radius * radius;
  for (var y = minY; y <= maxY; y++) {
    for (var x = minX; x <= maxX; x++) {
      final px = x + .5 - ax;
      final py = y + .5 - ay;
      final t = lengthSquared == 0
          ? 0.0
          : ((px * dx + py * dy) / lengthSquared).clamp(0.0, 1.0);
      final distanceX = px - t * dx;
      final distanceY = py - t * dy;
      if (distanceX * distanceX + distanceY * distanceY > radiusSquared) {
        continue;
      }
      final index = y * width + x;
      if (stroke.mode == MaskEditMode.add) {
        labels[index] = stroke.layer.label;
        intents[index] = stroke.layer.index + 2;
      } else if (labels[index] == stroke.layer.label) {
        labels[index] = 0;
        intents[index] = 1;
      }
    }
  }
}
