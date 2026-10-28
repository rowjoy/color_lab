import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../../../core/color/color_models.dart';
import '../../../core/vector_regions/data/vector_region_json_codec.dart';
import '../domain/drawing_definition.dart';

abstract interface class DrawingCatalogLoader {
  Future<List<DrawingDefinition>> load();
  Future<DrawingDefinition> loadById(String drawingId);
}

typedef DrawingAssetReader = Future<String> Function(String assetPath);

final class AssetDrawingCatalogLoader implements DrawingCatalogLoader {
  AssetDrawingCatalogLoader({
    DrawingAssetReader? readAsset,
    this.manifestPath = 'assets/coloring/manifest.json',
  }) : _readAsset = readAsset ?? ((path) => rootBundle.loadString(path));

  final DrawingAssetReader _readAsset;
  final String manifestPath;
  Future<List<DrawingDefinition>>? _cached;

  @override
  Future<List<DrawingDefinition>> load() => _cached ??= _load();

  @override
  Future<DrawingDefinition> loadById(String drawingId) async {
    final definitions = await load();
    return definitions.firstWhere(
      (drawing) => drawing.id == drawingId,
      orElse: () => throw const FormatException('Unknown drawing ID.'),
    );
  }

  Future<List<DrawingDefinition>> _load() async {
    final manifestSource = await _readAsset(manifestPath);
    final root = _strictMap(jsonDecode(manifestSource), {
      'schemaVersion',
      'drawings',
    });
    if (root['schemaVersion'] != 1 || root['drawings'] is! List) {
      throw const FormatException('Unsupported coloring manifest.');
    }
    final definitions = <DrawingDefinition>[];
    final ids = <String>{};
    for (final rawEntry in root['drawings'] as List) {
      final entry = _CatalogEntry.fromJson(rawEntry);
      if (!ids.add(entry.id)) {
        throw const FormatException('Duplicate drawing ID.');
      }
      final artworkSource = await _readAsset(entry.assetPath);
      final digest = sha256.convert(utf8.encode(artworkSource)).toString();
      if (digest != entry.contentHash) {
        throw FormatException('Content hash mismatch for ${entry.id}.');
      }
      final artwork = VectorRegionJsonCodec(
        allowedLabelsByGroup: _metadataPolicy(artworkSource),
      ).decode(artworkSource);
      definitions.add(
        DrawingDefinition(
          id: entry.id,
          revision: entry.revision,
          title: entry.title,
          description: entry.description,
          category: entry.category,
          difficulty: entry.difficulty,
          artwork: artwork,
          slots: entry.slots,
          regionRules: entry.regionRules,
        ),
      );
    }
    if (definitions.length != 12) {
      throw const FormatException(
        'The launch catalog must contain 12 drawings.',
      );
    }
    for (final category in DrawingCategory.values) {
      if (definitions.where((item) => item.category == category).length != 3) {
        throw const FormatException(
          'Each category must contain three drawings.',
        );
      }
    }
    return List.unmodifiable(definitions);
  }
}

Map<String, Set<String>> _metadataPolicy(String artworkSource) {
  final root = jsonDecode(artworkSource);
  if (root is! Map<String, dynamic> || root['regions'] is! List) {
    throw const FormatException('Invalid coloring artwork.');
  }
  final policy = <String, Set<String>>{};
  for (final raw in root['regions'] as List) {
    if (raw is! Map<String, dynamic> ||
        raw['groupId'] is! String ||
        raw['labelKey'] is! String) {
      throw const FormatException('Invalid coloring region metadata.');
    }
    policy
        .putIfAbsent(raw['groupId'] as String, () => <String>{})
        .add(raw['labelKey'] as String);
  }
  return policy;
}

final class _CatalogEntry {
  _CatalogEntry({
    required this.id,
    required this.revision,
    required this.assetPath,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.contentHash,
    required this.slots,
    required this.regionRules,
  });

  factory _CatalogEntry.fromJson(Object? value) {
    final map = _strictMap(value, {
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
    final id = _stableId(map['id']);
    final revision = map['revision'];
    final asset = map['asset'];
    final title = map['title'];
    final description = map['description'];
    final sourceNote = map['sourceNote'];
    final hash = map['contentHash'];
    if (revision is! int ||
        revision < 1 ||
        asset is! String ||
        asset != 'assets/coloring/$id.json' ||
        title is! String ||
        title.trim().isEmpty ||
        description is! String ||
        description.trim().isEmpty ||
        sourceNote is! String ||
        sourceNote.trim().isEmpty ||
        hash is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid catalog entry metadata.');
    }
    final slotsRaw = map['slots'];
    final rulesRaw = map['regionRules'];
    if (slotsRaw is! List || rulesRaw is! List) {
      throw const FormatException('Invalid drawing slots or rules.');
    }
    final slots = slotsRaw
        .map((raw) {
          final slot = _strictMap(raw, {'id', 'label', 'hex'});
          if (slot['label'] is! String ||
              (slot['label'] as String).trim().isEmpty) {
            throw const FormatException('Invalid slot label.');
          }
          return DrawingColorSlot(
            id: _stableId(slot['id']),
            label: slot['label'] as String,
            color: RgbColor.fromHex(slot['hex'] as String),
          );
        })
        .toList(growable: false);
    final rules = <String, DrawingRegionRule>{};
    for (final raw in rulesRaw) {
      final rule = _strictMap(raw, {'regionId', 'targetSlotId', 'required'});
      final regionId = _stableId(rule['regionId']);
      final target = rule['targetSlotId'];
      if (target != null && target is! String || rule['required'] is! bool) {
        throw const FormatException('Invalid region rule.');
      }
      if (rules.containsKey(regionId)) {
        throw const FormatException('Duplicate region rule.');
      }
      rules[regionId] = DrawingRegionRule(
        regionId: regionId,
        targetSlotId: target == null ? null : _stableId(target),
        required: rule['required'] as bool,
      );
    }
    return _CatalogEntry(
      id: id,
      revision: revision,
      assetPath: asset,
      title: title,
      description: description,
      category: _enumValue(DrawingCategory.values, map['category']),
      difficulty: _enumValue(DrawingDifficulty.values, map['difficulty']),
      contentHash: hash,
      slots: slots,
      regionRules: rules,
    );
  }

  final String id;
  final int revision;
  final String assetPath;
  final String title;
  final String description;
  final DrawingCategory category;
  final DrawingDifficulty difficulty;
  final String contentHash;
  final List<DrawingColorSlot> slots;
  final Map<String, DrawingRegionRule> regionRules;
}

Map<String, dynamic> _strictMap(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !keys.every(value.containsKey)) {
    throw const FormatException('Unknown or missing field.');
  }
  return value;
}

String _stableId(Object? value) {
  if (value is! String ||
      !RegExp(r'^[a-z][a-z0-9]*(?:[-_][a-z0-9]+)*$').hasMatch(value)) {
    throw const FormatException('Invalid stable ID.');
  }
  return value;
}

T _enumValue<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) throw const FormatException('Invalid enum value.');
  return values.firstWhere(
    (value) => value.name == raw,
    orElse: () => throw const FormatException('Unknown enum value.'),
  );
}
