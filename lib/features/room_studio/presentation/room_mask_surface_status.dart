import '../domain/mask_bitmap.dart';
import '../domain/room_layer.dart';

enum RoomMaskSurfaceStatus { notReviewed, absent, hasCoverage, reviewed }
enum RoomMaskReviewView { original, recolored, overlay }

/// Review is transient presentation state; it never changes pixel ownership.
final class RoomMaskReview {
  RoomMaskReview({
    this.selectedLayer = RoomLayer.wall,
    Set<RoomLayer> checked = const {},
  }) : checked = Set.unmodifiable(checked);

  final RoomLayer selectedLayer;
  final Set<RoomLayer> checked;
  bool get complete => RoomLayer.values.every(checked.contains);

  RoomMaskReview selectReviewLayer(RoomLayer layer) =>
      RoomMaskReview(selectedLayer: layer, checked: checked);

  RoomMaskReview markLayerChecked(RoomLayer layer) =>
      RoomMaskReview(selectedLayer: layer, checked: {...checked, layer});

  RoomMaskReview reopen(RoomLayer layer) => RoomMaskReview(
    selectedLayer: layer,
    checked: checked.where((entry) => entry != layer).toSet(),
  );

  RoomMaskSurfaceStatus status(RoomLayer layer, MaskBitmap masks) {
    if (checked.contains(layer)) {
      return masks.count(layer) == 0
          ? RoomMaskSurfaceStatus.absent
          : RoomMaskSurfaceStatus.reviewed;
    }
    return masks.count(layer) == 0
        ? RoomMaskSurfaceStatus.notReviewed
        : RoomMaskSurfaceStatus.hasCoverage;
  }
}

String roomSurfaceTitle(RoomLayer layer) =>
    '${layer.name[0].toUpperCase()}${layer.name.substring(1)}';

String roomSurfacePattern(RoomLayer layer) => switch (layer) {
  RoomLayer.wall => 'diagonal lines',
  RoomLayer.ceiling => 'dots',
  RoomLayer.floor => 'horizontal lines',
  RoomLayer.furniture => 'crosshatch',
};

String roomPixelCoverage(MaskBitmap masks, RoomLayer layer) =>
    '${masks.count(layer)} of ${masks.pixelCount} working-image pixels '
    '(${(100 * masks.count(layer) / masks.pixelCount).toStringAsFixed(1)}%)';
