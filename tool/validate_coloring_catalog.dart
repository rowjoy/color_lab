import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:color_lab/core/vector_regions/data/vector_path_json_validator.dart';

const _expectedIds = {
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
};

void main() {
  final manifestFile = File('assets/coloring/manifest.json');
  final manifest = _map(jsonDecode(manifestFile.readAsStringSync()));
  _validateMetadata(manifest, 'manifest');
  _fields(manifest, {'schemaVersion', 'drawings'});
  _expect(manifest['schemaVersion'] == 1, 'Unsupported manifest schema.');
  final drawings = _list(manifest['drawings']);
  _expect(drawings.length == 12, 'Expected exactly 12 drawings.');
  final expectedFiles = {
    manifestFile.path,
    for (final raw in drawings) _map(raw)['asset'],
  };
  final actualFiles = Directory('assets/coloring')
      .listSync(recursive: true, followLinks: false)
      .where((entity) => entity is! Directory)
      .map((entity) {
        _expect(entity is File, 'Catalog assets must be regular files.');
        return entity.path;
      })
      .toSet();
  _expect(
    actualFiles.length == expectedFiles.length &&
        actualFiles.containsAll(expectedFiles),
    'Manifest/file set mismatch.',
  );
  final seen = <String>{};
  final categories = <String, int>{};
  for (final raw in drawings) {
    final entry = _map(raw);
    _fields(entry, {
      'id',
      'revision',
      'asset',
      'title',
      'description',
      'category',
      'difficulty',
      'sourceNote',
      'contentHash',
      'slots',
      'regionRules',
    });
    _expect(entry['revision'] == 1, 'Invalid revision.');
    for (final field in ['title', 'description', 'sourceNote']) {
      _text(entry[field]);
    }
    _expect(
      const {'easy', 'medium', 'hard'}.contains(entry['difficulty']),
      'Invalid difficulty.',
    );
    final id = entry['id'];
    final assetPath = entry['asset'];
    _expect(id is String && _expectedIds.contains(id), 'Unknown drawing ID.');
    _expect(seen.add(id as String), 'Duplicate drawing ID: $id.');
    _expect(
      assetPath == 'assets/coloring/$id.json',
      'Asset path mismatch for $id.',
    );
    final category = entry['category'];
    _expect(
      const {'fruit', 'animals', 'treesNature', 'rooms'}.contains(category),
      'Unknown category for $id.',
    );
    categories.update(
      category as String,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    final slots = _list(entry['slots']);
    _expect(
      slots.length >= 3 && slots.length <= 5,
      'Invalid slot count for $id.',
    );
    final slotIds = <String>{};
    for (final rawSlot in slots) {
      final slot = _map(rawSlot);
      _fields(slot, {'id', 'label', 'hex'});
      _text(slot['label']);
      _stableId(slot['id']);
      _expect(slotIds.add(slot['id'] as String), 'Duplicate slot for $id.');
      _expect(
        RegExp(r'^#[0-9A-F]{6}$').hasMatch(slot['hex'] as String),
        'Invalid HEX for $id.',
      );
    }
    final file = File(assetPath as String);
    _expect(file.existsSync(), 'Missing asset for $id.');
    final source = file.readAsStringSync();
    _expect(
      sha256.convert(utf8.encode(source)).toString() == entry['contentHash'],
      'Content hash mismatch for $id.',
    );
    final artwork = _map(jsonDecode(source));
    _validateArtwork(artwork, id, slotIds, _list(entry['regionRules']));
  }
  _expect(seen.containsAll(_expectedIds), 'Launch drawing IDs are incomplete.');
  for (final category in const ['fruit', 'animals', 'treesNature', 'rooms']) {
    _expect(
      categories[category] == 3,
      '$category must contain three drawings.',
    );
  }
  stdout.writeln(
    'Coloring catalog valid: 12 original drawings, 4 balanced categories.',
  );
}

void _validateArtwork(
  Map<String, dynamic> artwork,
  String id,
  Set<String> slotIds,
  List<dynamic> rawRules,
) {
  _validateMetadata(artwork, id);
  _fields(artwork, {
    'schemaVersion',
    'id',
    'revision',
    'width',
    'height',
    'regions',
  });
  _expect(artwork['schemaVersion'] == 1, 'Invalid artwork schema for $id.');
  _expect(
    artwork['id'] == id && artwork['revision'] == 1,
    'Identity mismatch for $id.',
  );
  final width = artwork['width'];
  final height = artwork['height'];
  _expect(
    width is num && width.isFinite && width > 0 && width <= 1200,
    'Invalid width for $id.',
  );
  _expect(
    height is num && height.isFinite && height > 0 && height <= 800,
    'Invalid height for $id.',
  );
  final regions = _list(artwork['regions']);
  _expect(regions.isNotEmpty, 'Empty artwork in $id.');
  final rules = {
    for (final raw in rawRules) (_map(raw)['regionId'] as String): _map(raw),
  };
  _expect(rules.length == rawRules.length, 'Duplicate rule in $id.');
  for (final raw in rawRules) {
    _fields(_map(raw), {'regionId', 'targetSlotId', 'required'});
  }
  _expect(rules.length == regions.length, 'Rule count mismatch for $id.');
  final ids = <String>{};
  final orders = <int>{};
  final paintSlots = <int>{};
  final orderBySlot = <int, int>{};
  for (final raw in regions) {
    final region = _map(raw);
    _fields(region, {
      'id',
      'labelKey',
      'groupId',
      'fillable',
      'paintOrder',
      'geometry',
    });
    _stableId(region['id']);
    for (final key in ['labelKey', 'groupId']) {
      _expect(
        region[key] is String &&
            RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(region[key] as String),
        'Invalid region metadata in $id.',
      );
    }
    _expect(
      region['paintOrder'] is int && (region['paintOrder'] as int) >= 0,
      'Invalid paint order in $id.',
    );
    final regionId = region['id'];
    _expect(
      regionId is String && ids.add(regionId),
      'Duplicate region in $id.',
    );
    _expect(
      region['fillable'] == true,
      'Launch region must be fillable in $id.',
    );
    _expect(
      orders.add(region['paintOrder'] as int),
      'Duplicate paint order in $id.',
    );
    final rule = rules[regionId];
    _expect(
      rule != null && rule['required'] == true,
      'Missing required rule in $id.',
    );
    _expect(
      slotIds.contains(rule!['targetSlotId']),
      'Unknown rule slot in $id.',
    );
    final geometry = _map(region['geometry']);
    _fields(geometry, {'parts'});
    final parts = _list(geometry['parts']);
    _expect(parts.isNotEmpty, 'Empty region geometry in $id.');
    for (final rawPart in parts) {
      final part = _map(rawPart);
      _fields(
        part,
        {'slot', 'commands'},
        optional: {'whiteOverlayOpacity', 'blackOverlayOpacity'},
      );
      _expect(
        part['slot'] is int && (part['slot'] as int) >= 0,
        'Invalid paint slot in $id.',
      );
      for (final key in ['whiteOverlayOpacity', 'blackOverlayOpacity']) {
        if (part.containsKey(key)) {
          final opacity = part[key];
          _expect(
            opacity is num && opacity.isFinite && opacity >= 0 && opacity <= 1,
            'Invalid opacity in $id.',
          );
        }
      }
      _expect(
        paintSlots.add(part['slot'] as int),
        'Duplicate paint slot in $id.',
      );
      orderBySlot[part['slot'] as int] = region['paintOrder'] as int;
      validateVectorPathCommands(
        part['commands'],
        width: (width as num).toDouble(),
        height: (height as num).toDouble(),
        fillable: true,
      );
    }
  }
  var previousOrder = -1;
  for (final slot in orderBySlot.keys.toList()..sort()) {
    final order = orderBySlot[slot]!;
    _expect(
      order >= previousOrder,
      'Part slots contradict region paint order in $id.',
    );
    previousOrder = order;
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) _fail('Expected an object.');
  return value;
}

List<dynamic> _list(Object? value) {
  if (value is! List) _fail('Expected a list.');
  return value;
}

void _expect(bool condition, String message) {
  if (!condition) _fail(message);
}

Never _fail(String message) => throw FormatException(message);

void _fields(
  Map<String, dynamic> value,
  Set<String> required, {
  Set<String> optional = const {},
}) {
  _expect(
    required.every(value.containsKey) &&
        value.keys.every({...required, ...optional}.contains),
    'Unknown/missing field.',
  );
}

void _text(Object? value) => _expect(
  value is String && value.trim().isNotEmpty,
  'Missing metadata text.',
);

void _stableId(Object? value) => _expect(
  value is String &&
      RegExp(r'^[a-z][a-z0-9]*(?:[-_][a-z0-9]+)*$').hasMatch(value),
  'Invalid stable ID.',
);

void _validateMetadata(Object? value, String context) {
  // Identifying manufacturer/shade phrases, never generic color words/digits.
  final forbidden = RegExp(
    [
      r'asian[\s._-]*paints?',
      r'dulux',
      r'sherwin',
      r'benjamin[\s._-]*moore',
      r'milkshake[\s._-]*8012',
      r'white[\s._-]*clay[\s._-]*8620',
      r'gossamer[\s._-]*8052',
      r'white[\s._-]*cameo[\s._-]*l145',
      r'timber[\s._-]*glaze',
    ].join('|'),
    caseSensitive: false,
  );
  void visit(Object? item) {
    if (item is String) {
      _expect(
        !forbidden.hasMatch(item),
        'Forbidden manufacturer/shade metadata in $context.',
      );
    } else if (item is Map) {
      for (final entry in item.entries) {
        visit(entry.key);
        visit(entry.value);
      }
    } else if (item is List) {
      for (final child in item) {
        visit(child);
      }
    }
  }

  visit(value);
}
