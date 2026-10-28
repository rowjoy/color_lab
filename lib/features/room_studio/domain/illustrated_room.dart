import 'dart:collection';

import '../../../core/color/color_models.dart';
import '../../../l10n/l10n.dart';
import '../data/illustrated_room_palette_catalog.dart';

enum IllustratedRoomSurface { wall, ceiling, floor, furniture }

final class IllustratedRoomColors {
  const IllustratedRoomColors({
    required this.wall,
    required this.ceiling,
    required this.floor,
    required this.furniture,
  });

  final RgbColor wall;
  final RgbColor ceiling;
  final RgbColor floor;
  final RgbColor furniture;

  RgbColor colorFor(IllustratedRoomSurface surface) => switch (surface) {
    IllustratedRoomSurface.wall => wall,
    IllustratedRoomSurface.ceiling => ceiling,
    IllustratedRoomSurface.floor => floor,
    IllustratedRoomSurface.furniture => furniture,
  };

  IllustratedRoomColors withColor(
    IllustratedRoomSurface surface,
    RgbColor color,
  ) => switch (surface) {
    IllustratedRoomSurface.wall => IllustratedRoomColors(
      wall: color,
      ceiling: ceiling,
      floor: floor,
      furniture: furniture,
    ),
    IllustratedRoomSurface.ceiling => IllustratedRoomColors(
      wall: wall,
      ceiling: color,
      floor: floor,
      furniture: furniture,
    ),
    IllustratedRoomSurface.floor => IllustratedRoomColors(
      wall: wall,
      ceiling: ceiling,
      floor: color,
      furniture: furniture,
    ),
    IllustratedRoomSurface.furniture => IllustratedRoomColors(
      wall: wall,
      ceiling: ceiling,
      floor: floor,
      furniture: color,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomColors &&
      wall == other.wall &&
      ceiling == other.ceiling &&
      floor == other.floor &&
      furniture == other.furniture;

  @override
  int get hashCode => Object.hash(wall, ceiling, floor, furniture);
}

final class IllustratedRoomFocalPoint {
  const IllustratedRoomFocalPoint({required this.x, required this.y})
    : assert(x >= -1 && x <= 1, 'x must be between -1 and 1'),
      assert(y >= -1 && y <= 1, 'y must be between -1 and 1');

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomFocalPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

final class IllustratedRoomSurfaceLabels {
  const IllustratedRoomSurfaceLabels({
    required this.wall,
    required this.ceiling,
    required this.floor,
    required this.furniture,
  });

  final String wall;
  final String ceiling;
  final String floor;
  final String furniture;

  String labelFor(IllustratedRoomSurface surface) => switch (surface) {
    IllustratedRoomSurface.wall => wall,
    IllustratedRoomSurface.ceiling => ceiling,
    IllustratedRoomSurface.floor => floor,
    IllustratedRoomSurface.furniture => furniture,
  };
}

final class IllustratedRoomPalette {
  IllustratedRoomPalette({
    required String id,
    required String name,
    required String guidance,
    required this.colors,
  }) : id = _requiredId(id, 'id'),
       _name = _requiredText(name, 'name'),
       _guidance = _requiredText(guidance, 'guidance'),
       catalogueRecord = null;

  IllustratedRoomPalette.snapshot(IllustratedRoomPaletteRecord record)
    : id = record.id,
      _name = '',
      _guidance = '',
      catalogueRecord = record,
      colors = IllustratedRoomColors(
        wall: RgbColor.fromHex(record.colors[0]),
        ceiling: RgbColor.fromHex(record.colors[1]),
        floor: RgbColor.fromHex(record.colors[2]),
        furniture: RgbColor.fromHex(record.colors[3]),
      );

  final String id;
  final String _name;
  final String _guidance;
  final IllustratedRoomColors colors;
  final IllustratedRoomPaletteRecord? catalogueRecord;

  String get name =>
      localizedName(IllustratedRoomPaletteCatalog.fallbackLocalizations);
  String get guidance =>
      localizedGuidance(IllustratedRoomPaletteCatalog.fallbackLocalizations);
  String localizedName(AppLocalizations l10n) =>
      catalogueRecord?.localizedName(l10n) ?? _name;
  String localizedGuidance(AppLocalizations l10n) =>
      catalogueRecord?.localizedDescription(l10n) ?? _guidance;

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomPalette &&
      id == other.id &&
      name == other.name &&
      guidance == other.guidance &&
      colors == other.colors;
  @override
  int get hashCode => Object.hash(id, name, guidance, colors);
}

final class IllustratedRoomTemplate {
  IllustratedRoomTemplate({
    required String id,
    required String title,
    required String summary,
    required String assetPath,
    required String defaultPaletteId,
    required Iterable<IllustratedRoomPalette> palettes,
    required this.surfaceLabels,
    required this.focalPoint,
    this.artboardWidth = 1200,
    this.artboardHeight = 800,
    this.regionAssetPath,
  }) : id = _requiredId(id, 'id'),
       title = _requiredText(title, 'title'),
       summary = _requiredText(summary, 'summary'),
       assetPath = _requiredText(assetPath, 'assetPath'),
       defaultPaletteId = _requiredId(defaultPaletteId, 'defaultPaletteId'),
       palettes = UnmodifiableListView(palettes.toList(growable: false)) {
    if (this.palettes.isEmpty) {
      throw ArgumentError.value(palettes, 'palettes', 'Must not be empty');
    }
    if (artboardWidth <= 0) {
      throw ArgumentError.value(
        artboardWidth,
        'artboardWidth',
        'Must be greater than zero',
      );
    }
    if (artboardHeight <= 0) {
      throw ArgumentError.value(
        artboardHeight,
        'artboardHeight',
        'Must be greater than zero',
      );
    }
    for (final surface in IllustratedRoomSurface.values) {
      _requiredText(surfaceLabels.labelFor(surface), '${surface.name}Label');
    }
    final ids = <String>{};
    for (final palette in this.palettes) {
      if (!ids.add(palette.id)) {
        throw ArgumentError.value(
          palette.id,
          'palettes',
          'Palette IDs must be unique',
        );
      }
    }
    if (!ids.contains(this.defaultPaletteId)) {
      throw ArgumentError.value(
        defaultPaletteId,
        'defaultPaletteId',
        'Must identify one of the template palettes',
      );
    }
  }

  final String id;
  final String title;
  final String summary;
  final String assetPath;
  final String? regionAssetPath;
  final String defaultPaletteId;
  final List<IllustratedRoomPalette> palettes;
  final IllustratedRoomSurfaceLabels surfaceLabels;
  final IllustratedRoomFocalPoint focalPoint;
  final int artboardWidth;
  final int artboardHeight;

  double get aspectRatio => artboardWidth / artboardHeight;

  IllustratedRoomPalette palette(String id) {
    for (final palette in palettes) {
      if (palette.id == id) return palette;
    }
    throw ArgumentError.value(id, 'id', 'Unknown palette for room ${this.id}');
  }

  IllustratedRoomPalette get defaultPalette => palette(defaultPaletteId);

  IllustratedRoomPalette? matchingPalette(IllustratedRoomColors colors) {
    for (final palette in palettes) {
      if (palette.colors == colors) return palette;
    }
    return null;
  }

  List<RgbColor> suggestedColors(IllustratedRoomSurface surface) {
    final seen = <String>{};
    return List<RgbColor>.unmodifiable(
      palettes
          .map((palette) => palette.colors.colorFor(surface))
          .where((color) => seen.add(color.hex)),
    );
  }
}

abstract final class IllustratedRoomCatalog {
  static const _standardLabels = IllustratedRoomSurfaceLabels(
    wall: 'Wall',
    ceiling: 'Ceiling',
    floor: 'Floor',
    furniture: 'Furniture',
  );

  static final IllustratedRoomTemplate living = _room(
    id: 'living',
    title: 'Living room',
    summary: 'A welcoming lounge with layered seating and natural light.',
    assetPath: 'assets/rooms/living_room.svg',
    defaultPaletteId: 'soft-linen',
    focalPoint: const IllustratedRoomFocalPoint(x: 0, y: .08),
    labels: _standardLabels,
  );

  static final IllustratedRoomTemplate bedroom = _room(
    id: 'bedroom',
    title: 'Bedroom',
    summary: 'A restful bedroom with layered textiles and warm timber.',
    assetPath: 'assets/rooms/bedroom_room.svg',
    defaultPaletteId: 'soft-linen',
    focalPoint: const IllustratedRoomFocalPoint(x: .05, y: .05),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Bed & furniture',
    ),
  );

  static final IllustratedRoomTemplate study = _room(
    id: 'study',
    title: 'Study room',
    summary: 'A focused workspace with ergonomic seating and task lighting.',
    assetPath: 'assets/rooms/study_room.svg',
    defaultPaletteId: 'quiet-sage',
    focalPoint: const IllustratedRoomFocalPoint(x: 0, y: 0),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Desk & furniture',
    ),
  );

  static final IllustratedRoomTemplate dining = _room(
    id: 'dining',
    title: 'Dining room',
    summary: 'A sociable dining space with a central table and pendant light.',
    assetPath: 'assets/rooms/dining_room.svg',
    defaultPaletteId: 'soft-linen',
    focalPoint: const IllustratedRoomFocalPoint(x: 0, y: .08),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Table & furniture',
    ),
  );

  static final IllustratedRoomTemplate kitchen = _room(
    id: 'kitchen',
    title: 'Kitchen',
    summary: 'A practical kitchen with cabinetry, counters and a broad island.',
    assetPath: 'assets/rooms/kitchen_room.svg',
    defaultPaletteId: 'quiet-sage',
    focalPoint: const IllustratedRoomFocalPoint(x: .05, y: 0),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Cabinets',
    ),
  );

  static final IllustratedRoomTemplate bathroom = _room(
    id: 'bathroom',
    title: 'Bathroom',
    summary: 'A bright bathroom with a vanity, storage and calm hard finishes.',
    assetPath: 'assets/rooms/bathroom_room.svg',
    defaultPaletteId: 'airy-slate',
    focalPoint: const IllustratedRoomFocalPoint(x: -.05, y: .02),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Vanity & storage',
    ),
  );

  static final List<IllustratedRoomTemplate> all = List.unmodifiable([
    living,
    bedroom,
    study,
    dining,
    kitchen,
    bathroom,
  ]);

  static IllustratedRoomTemplate? maybeById(String id) {
    for (final template in all) {
      if (template.id == id) return template;
    }
    return null;
  }

  static IllustratedRoomTemplate _room({
    required String id,
    required String title,
    required String summary,
    required String assetPath,
    required String defaultPaletteId,
    required IllustratedRoomFocalPoint focalPoint,
    required IllustratedRoomSurfaceLabels labels,
  }) => IllustratedRoomTemplate(
    id: id,
    title: title,
    summary: summary,
    assetPath: assetPath,
    defaultPaletteId: defaultPaletteId,
    surfaceLabels: labels,
    focalPoint: focalPoint,
    regionAssetPath: 'assets/rooms/regions/${id}_room.v1.json',
    palettes: IllustratedRoomPaletteCatalog.all.map(
      IllustratedRoomPalette.snapshot,
    ),
  );
}

String _requiredId(String value, String name) {
  final id = _requiredText(value, name);
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(id)) {
    throw ArgumentError.value(
      value,
      name,
      'Must contain only lowercase letters, digits and hyphens',
    );
  }
  return id;
}

String _requiredText(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty');
  }
  return trimmed;
}

/// The v1 region contract preserves the existing saved four-surface color model.
IllustratedRoomSurface illustratedRoomSurfaceForGroup(String group) =>
    switch (group) {
      'walls' => IllustratedRoomSurface.wall,
      'ceiling' => IllustratedRoomSurface.ceiling,
      'floor' => IllustratedRoomSurface.floor,
      'furniture' => IllustratedRoomSurface.furniture,
      _ => throw ArgumentError.value(group, 'group'),
    };
