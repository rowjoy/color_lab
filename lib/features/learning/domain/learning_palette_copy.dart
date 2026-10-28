import '../../../core/color/color_models.dart';

enum LearningPaletteDestination { illustratedRoom, coloring }

/// A source-independent value copy that another feature can safely retain.
final class LearningPaletteCopy {
  LearningPaletteCopy({
    required Iterable<RgbColor> colors,
    required this.returnLocation,
  }) : colors = List.unmodifiable(
         colors.map((color) => RgbColor(color.red, color.green, color.blue)),
       ) {
    if (this.colors.isEmpty) {
      throw ArgumentError.value(
        colors,
        'colors',
        'Cannot copy an empty palette',
      );
    }
    final location = Uri.tryParse(returnLocation);
    if (location == null ||
        !location.hasAbsolutePath ||
        location.hasScheme ||
        location.hasAuthority) {
      throw ArgumentError.value(
        returnLocation,
        'returnLocation',
        'Must be an internal absolute app path',
      );
    }
  }

  final List<RgbColor> colors;
  final String returnLocation;
}

bool isLearningPaletteDestinationAvailable(
  LearningPaletteDestination destination,
) => switch (destination) {
  LearningPaletteDestination.illustratedRoom => true,
  LearningPaletteDestination.coloring => true,
};
