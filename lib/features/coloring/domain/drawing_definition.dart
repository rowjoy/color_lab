import '../../../core/color/color_models.dart';
import '../../../core/vector_regions/domain/vector_region_geometry.dart';

enum DrawingCategory { fruit, animals, treesNature, rooms }

enum DrawingDifficulty { easy, medium, hard }

enum ColoringMode { guided, free }

final class DrawingColorSlot {
  const DrawingColorSlot({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;

  /// Stable localization key for the authored swatch label.
  final String label;
  final RgbColor color;
}

final class DrawingRegionRule {
  const DrawingRegionRule({
    required this.regionId,
    required this.targetSlotId,
    required this.required,
  });

  final String regionId;
  final String? targetSlotId;
  final bool required;
}

/// Catalog metadata and the one shared vector artwork used by every surface.
final class DrawingDefinition {
  DrawingDefinition({
    required this.id,
    required this.revision,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.artwork,
    required Iterable<DrawingColorSlot> slots,
    required Map<String, DrawingRegionRule> regionRules,
  }) : slots = List.unmodifiable(slots),
       regionRules = Map.unmodifiable(regionRules) {
    if (id != artwork.id || revision != artwork.revision) {
      throw const FormatException('Catalog and artwork identity mismatch.');
    }
    if (title.trim().isEmpty || description.trim().isEmpty) {
      throw const FormatException('Drawing copy must not be empty.');
    }
    if (this.slots.length < 3 || this.slots.length > 5) {
      throw const FormatException('A drawing needs three to five color slots.');
    }
    final slotIds = <String>{};
    for (final slot in this.slots) {
      if (!_stableId.hasMatch(slot.id) ||
          !slotIds.add(slot.id) ||
          slot.label.trim().isEmpty) {
        throw const FormatException('Invalid or duplicate color slot.');
      }
    }
    final regionIds = artwork.regions.map((region) => region.id).toSet();
    if (regionIds.length != artwork.regions.length ||
        this.regionRules.length != artwork.regions.length ||
        !this.regionRules.keys.toSet().containsAll(regionIds)) {
      throw const FormatException('Every artwork region needs one rule.');
    }
    for (final entry in this.regionRules.entries) {
      final rule = entry.value;
      if (entry.key != rule.regionId ||
          !regionIds.contains(rule.regionId) ||
          (rule.required && rule.targetSlotId == null) ||
          (rule.targetSlotId != null && !slotIds.contains(rule.targetSlotId))) {
        throw const FormatException('Invalid drawing region rule.');
      }
    }
  }

  static final _stableId = RegExp(r'^[a-z][a-z0-9]*(?:[-_][a-z0-9]+)*$');

  final String id;
  final int revision;

  /// Stable localization key, resolved at the presentation boundary.
  final String title;

  /// Stable localization key, resolved at the presentation boundary.
  final String description;
  final DrawingCategory category;
  final DrawingDifficulty difficulty;
  final VectorArtworkDefinition artwork;
  final List<DrawingColorSlot> slots;
  final Map<String, DrawingRegionRule> regionRules;

  DrawingColorSlot slotById(String id) =>
      slots.firstWhere((slot) => slot.id == id);
}
