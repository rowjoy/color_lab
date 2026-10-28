import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads the frozen balanced launch catalog through shared geometry',
    () async {
      final drawings = await AssetDrawingCatalogLoader().load();
      expect(drawings, hasLength(12));
      expect(drawings.map((item) => item.id).toSet(), {
        'fruit_red_apple',
        'fruit_orange_slice',
        'fruit_berry_bowl',
        'animal_butterfly',
        'animal_tropical_fish',
        'animal_parrot',
        'nature_leafy_tree',
        'nature_sunflower',
        'nature_mountain_grove',
        'room_cozy_living',
        'room_calm_bedroom',
        'room_reading_corner',
      });
      for (final category in DrawingCategory.values) {
        expect(
          drawings.where((item) => item.category == category),
          hasLength(3),
        );
      }
      for (final drawing in drawings) {
        expect(drawing.slots.length, inInclusiveRange(3, 5));
        expect(drawing.artwork.regions, isNotEmpty);
        for (final region in drawing.artwork.regions) {
          expect(region.geometry.toPath().getBounds().isEmpty, isFalse);
          expect(drawing.regionRules[region.id]?.required, isTrue);
        }
      }
    },
  );
}
