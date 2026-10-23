import 'dart:typed_data';

/// Detached immutable snapshot of the model's original ADE IDs (0–31).
final class RawSegmentation {
  RawSegmentation({
    required this.width,
    required this.height,
    required Uint16List classIds,
  }) : classIds = Uint16List.fromList(classIds).asUnmodifiableView() {
    if (width <= 0 || height <= 0 || classIds.length != width * height) {
      throw ArgumentError(
        'Class map must have positive dimensions and width × height entries',
      );
    }
    if (classIds.any((id) => id > 31)) {
      throw ArgumentError('Class map IDs must be in 0–31');
    }
  }

  final int width;
  final int height;
  final Uint16List classIds;
}
