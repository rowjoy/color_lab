import 'dart:math' as math;
import 'dart:typed_data';

import '../domain/mask_bitmap.dart';
import '../domain/mask_stroke.dart';
import '../domain/mask_undo.dart';

final class MaskEditResult {
  const MaskEditResult({
    required this.masks,
    required this.undo,
    required this.changedFromAiCount,
  });

  final MaskBitmap masks;
  final MaskUndoCommand? undo;
  final int changedFromAiCount;
}

/// Pure worker operation. The service runs rasterization and scans off the UI.
MaskEditResult applyMaskStroke({
  required MaskBitmap current,
  required MaskBitmap ai,
  required MaskStroke stroke,
}) {
  _requireSameDimensions(current, ai);
  final labels = Uint8List.fromList(current.labels);
  final radius =
      stroke.diameterFraction * math.min(current.width, current.height) / 2;
  for (final segment in stroke.segments) {
    for (var i = 0; i < math.max(1, segment.length - 1); i++) {
      final start = segment[i];
      final end = segment.length == 1 ? start : segment[i + 1];
      _paintSegment(
        labels: labels,
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
    if (labels[i] != current.labels[i]) changedCount++;
    if (labels[i] != ai.labels[i]) changedFromAiCount++;
  }
  MaskUndoCommand? undo;
  if (changedCount > 0) {
    final indices = Uint32List(changedCount);
    final previousLabels = Uint8List(changedCount);
    var position = 0;
    for (var i = 0; i < labels.length; i++) {
      if (labels[i] == current.labels[i]) continue;
      indices[position] = i;
      previousLabels[position++] = current.labels[i];
    }
    undo = MaskUndoCommand(
      width: current.width,
      height: current.height,
      indices: indices,
      previousLabels: previousLabels,
    );
  }
  return MaskEditResult(
    masks: MaskBitmap(
      width: current.width,
      height: current.height,
      labels: labels,
    ),
    undo: undo,
    changedFromAiCount: changedFromAiCount,
  );
}

MaskEditResult undoMaskStroke({
  required MaskBitmap current,
  required MaskBitmap ai,
  required MaskUndoCommand command,
}) {
  _requireSameDimensions(current, ai);
  if (command.width != current.width || command.height != current.height) {
    throw ArgumentError('Undo dimensions must match the ownership map');
  }
  final labels = Uint8List.fromList(current.labels);
  for (var i = 0; i < command.indices.length; i++) {
    labels[command.indices[i]] = command.previousLabels[i];
  }
  var changedFromAiCount = 0;
  for (var i = 0; i < labels.length; i++) {
    if (labels[i] != ai.labels[i]) changedFromAiCount++;
  }
  return MaskEditResult(
    masks: MaskBitmap(
      width: current.width,
      height: current.height,
      labels: labels,
    ),
    undo: null,
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
      } else if (labels[index] == stroke.layer.label) {
        labels[index] = 0;
      }
    }
  }
}
