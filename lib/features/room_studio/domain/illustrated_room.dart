import 'dart:collection';

import '../../../core/color/color_models.dart';

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
    String? provenance,
  }) : id = _requiredId(id, 'id'),
       name = _requiredText(name, 'name'),
       guidance = _requiredText(guidance, 'guidance'),
       provenance = provenance == null
           ? null
           : _requiredText(provenance, 'provenance');

  final String id;
  final String name;
  final String guidance;
  final IllustratedRoomColors colors;
  final String? provenance;

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomPalette &&
      id == other.id &&
      name == other.name &&
      guidance == other.guidance &&
      colors == other.colors &&
      provenance == other.provenance;

  @override
  int get hashCode => Object.hash(id, name, guidance, colors, provenance);
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
    required String paletteReviewLabel,
    required String paletteSourceNote,
  }) : id = _requiredId(id, 'id'),
       title = _requiredText(title, 'title'),
       summary = _requiredText(summary, 'summary'),
       assetPath = _requiredText(assetPath, 'assetPath'),
       defaultPaletteId = _requiredId(defaultPaletteId, 'defaultPaletteId'),
       palettes = UnmodifiableListView(palettes.toList(growable: false)),
       paletteReviewLabel = _requiredText(
         paletteReviewLabel,
         'paletteReviewLabel',
       ),
       paletteSourceNote = _requiredText(
         paletteSourceNote,
         'paletteSourceNote',
       ) {
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
  final String defaultPaletteId;
  final List<IllustratedRoomPalette> palettes;
  final IllustratedRoomSurfaceLabels surfaceLabels;
  final IllustratedRoomFocalPoint focalPoint;
  final int artboardWidth;
  final int artboardHeight;
  final String paletteReviewLabel;
  final String paletteSourceNote;

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
  static const _reviewLabel = 'Market guide - reviewed October 2026';
  static const _sourceNote =
      'Display preview inspired by current Bangladesh paint guidance. Colors '
      'vary by screen, light, surface and finish; compare a physical swatch '
      'in daylight and evening before purchase.';

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
    defaultPaletteId: 'warm-natural',
    focalPoint: const IllustratedRoomFocalPoint(x: 0, y: .08),
    labels: _standardLabels,
    values: const {
      'warm-natural': ['#E6D8C3', '#F8F4EB', '#C5AD8A', '#7B5944'],
      'soft-botanical': ['#C4D3C1', '#F8F4EB', '#BEB2A2', '#9A7557'],
      'cool-airy': ['#D3E0E4', '#F7F5EF', '#B5BEC1', '#5F493F'],
    },
  );

  static final IllustratedRoomTemplate bedroom = _room(
    id: 'bedroom',
    title: 'Bedroom',
    summary: 'A restful bedroom with layered textiles and warm timber.',
    assetPath: 'assets/rooms/bedroom_room.svg',
    defaultPaletteId: 'warm-natural',
    focalPoint: const IllustratedRoomFocalPoint(x: .05, y: .05),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Bed & furniture',
    ),
    values: const {
      'warm-natural': ['#DED5C7', '#FAF6EE', '#C2A483', '#785747'],
      'soft-botanical': ['#C8D3C2', '#F8F4EC', '#BCA58A', '#80614E'],
      'cool-airy': ['#D4DFE4', '#F8F6F0', '#B7BEC1', '#67514B'],
    },
  );

  static final IllustratedRoomTemplate study = _room(
    id: 'study',
    title: 'Study room',
    summary: 'A focused workspace with ergonomic seating and task lighting.',
    assetPath: 'assets/rooms/study_room.svg',
    defaultPaletteId: 'soft-botanical',
    focalPoint: const IllustratedRoomFocalPoint(x: 0, y: 0),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Desk & furniture',
    ),
    values: const {
      'warm-natural': ['#E2D5BF', '#F8F4EB', '#C5AA84', '#72513D'],
      'soft-botanical': ['#B7C5B3', '#F8F4EB', '#C6AC84', '#654A39'],
      'cool-airy': ['#C7D6DF', '#F6F5F0', '#B7A083', '#465967'],
    },
  );

  static final IllustratedRoomTemplate dining = _room(
    id: 'dining',
    title: 'Dining room',
    summary: 'A sociable dining space with a central table and pendant light.',
    assetPath: 'assets/rooms/dining_room.svg',
    defaultPaletteId: 'warm-natural',
    focalPoint: const IllustratedRoomFocalPoint(x: 0, y: .08),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Table & furniture',
    ),
    values: const {
      'warm-natural': ['#D5BCAA', '#FAF5EC', '#A98464', '#704C3B'],
      'soft-botanical': ['#C3D0BB', '#F8F4EA', '#AC9274', '#6E5242'],
      'cool-airy': ['#CFDCE0', '#F8F5EE', '#AA927D', '#5C4740'],
    },
  );

  static final IllustratedRoomTemplate kitchen = _room(
    id: 'kitchen',
    title: 'Kitchen',
    summary: 'A practical kitchen with cabinetry, counters and a broad island.',
    assetPath: 'assets/rooms/kitchen_room.svg',
    defaultPaletteId: 'soft-botanical',
    focalPoint: const IllustratedRoomFocalPoint(x: .05, y: 0),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Cabinets',
    ),
    values: const {
      'warm-natural': ['#E3D7C6', '#FAF8F2', '#BBAF9E', '#987454'],
      'soft-botanical': ['#D8E1D3', '#FAF8F2', '#B8B0A3', '#A7B39B'],
      'cool-airy': ['#D8E4E6', '#FBF9F4', '#B7C0C2', '#718184'],
    },
  );

  static final IllustratedRoomTemplate bathroom = _room(
    id: 'bathroom',
    title: 'Bathroom',
    summary: 'A bright bathroom with a vanity, storage and calm hard finishes.',
    assetPath: 'assets/rooms/bathroom_room.svg',
    defaultPaletteId: 'cool-airy',
    focalPoint: const IllustratedRoomFocalPoint(x: -.05, y: .02),
    labels: const IllustratedRoomSurfaceLabels(
      wall: 'Wall',
      ceiling: 'Ceiling',
      floor: 'Floor',
      furniture: 'Vanity & storage',
    ),
    values: const {
      'warm-natural': ['#E6DDD1', '#FBF9F4', '#C4B8AA', '#92745F'],
      'soft-botanical': ['#D4E0D7', '#FAFBF7', '#B8C2BA', '#789080'],
      'cool-airy': ['#D8E5E7', '#FBFBF8', '#B9C2C4', '#8A725F'],
    },
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
    required Map<String, List<String>> values,
  }) => IllustratedRoomTemplate(
    id: id,
    title: title,
    summary: summary,
    assetPath: assetPath,
    defaultPaletteId: defaultPaletteId,
    surfaceLabels: labels,
    focalPoint: focalPoint,
    paletteReviewLabel: _reviewLabel,
    paletteSourceNote: _sourceNote,
    palettes: values.entries.map(
      (entry) => IllustratedRoomPalette(
        id: entry.key,
        name: _lookName(entry.key),
        guidance: _lookGuidance(entry.key),
        provenance: _lookProvenance(entry.key),
        colors: _colors(entry.value),
      ),
    ),
  );

  static IllustratedRoomColors _colors(List<String> values) =>
      IllustratedRoomColors(
        wall: RgbColor.fromHex(values[0]),
        ceiling: RgbColor.fromHex(values[1]),
        floor: RgbColor.fromHex(values[2]),
        furniture: RgbColor.fromHex(values[3]),
      );

  static String _lookName(String id) => switch (id) {
    'warm-natural' => 'Warm Natural',
    'soft-botanical' => 'Soft Botanical',
    'cool-airy' => 'Cool Airy',
    _ => throw ArgumentError.value(id, 'id', 'Unknown market-guided look'),
  };

  static String _lookGuidance(String id) => switch (id) {
    'warm-natural' =>
      'Warm neutrals and timber tones create a grounded, welcoming room.',
    'soft-botanical' =>
      'Muted botanical color supports a calm room with gentle contrast.',
    'cool-airy' =>
      'Cool light tones keep the room open while deeper furniture adds focus.',
    _ => throw ArgumentError.value(id, 'id', 'Unknown market-guided look'),
  };

  static String _lookProvenance(String id) => switch (id) {
    'warm-natural' =>
      'Inspired by Milkshake 8012, White Clay 8620 and Timber Glaze families.',
    'soft-botanical' =>
      'Inspired by restrained pastel greens suited to local light and climate.',
    'cool-airy' =>
      'Inspired by Gossamer 8052 and soft off-white ceiling combinations.',
    _ => throw ArgumentError.value(id, 'id', 'Unknown market-guided look'),
  };
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
