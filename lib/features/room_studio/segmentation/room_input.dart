import 'dart:typed_data';

/// Source means the already oriented working photo, not the encoded image.
final class RoomInputTransform {
  RoomInputTransform({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.inputWidth,
    required this.inputHeight,
    required this.contentWidth,
    required this.contentHeight,
    required this.paddingLeft,
    required this.paddingTop,
  }) {
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        inputWidth <= 0 ||
        inputHeight <= 0 ||
        contentWidth <= 0 ||
        contentHeight <= 0 ||
        paddingLeft < 0 ||
        paddingTop < 0 ||
        paddingLeft + contentWidth > inputWidth ||
        paddingTop + contentHeight > inputHeight) {
      throw ArgumentError('Positive sizes and contained content required');
    }
  }

  final int sourceWidth;
  final int sourceHeight;
  final int inputWidth;
  final int inputHeight;
  final int contentWidth;
  final int contentHeight;
  final int paddingLeft;
  final int paddingTop;
}

final class RoomInput {
  RoomInput({required Uint8List tensorBytes, required this.transform})
    : tensorBytes = Uint8List.fromList(tensorBytes).asUnmodifiableView();

  final Uint8List tensorBytes;
  final RoomInputTransform transform;
}
