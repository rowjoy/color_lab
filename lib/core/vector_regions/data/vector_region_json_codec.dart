import 'dart:convert';
import 'dart:ui';
import '../domain/vector_region_geometry.dart';

/// Schema 1 is data, never an SVG/HTML/script language. Unknown fields fail closed.
final class VectorRegionJsonCodec {
  static const _groups = {'walls', 'ceiling', 'floor', 'furniture'};
  static const _labels = {
    'roomSurfaceWall',
    'roomSurfaceCeiling',
    'roomSurfaceFloor',
    'roomSurfaceFurniture',
  };
  static final _id = RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$');

  VectorArtworkDefinition decode(String source) {
    try {
      final root = _map(jsonDecode(source), {
        'schemaVersion',
        'id',
        'revision',
        'width',
        'height',
        'regions',
      });
      if (root['schemaVersion'] != 1) _fail('Unsupported schema');
      final width = _number(root['width'], 1200);
      final height = _number(root['height'], 800);
      if (width <= 0 || height <= 0) _fail('Invalid intrinsic size');
      final regions = <VectorRegionDefinition>[];
      final ids = <String>{};
      final orders = <int>{};
      final slots = <int>{};
      for (final raw in _list(root['regions'])) {
        final r = _map(raw, {
          'id',
          'labelKey',
          'groupId',
          'fillable',
          'paintOrder',
          'geometry',
        });
        final id = _stableId(r['id']);
        final order = _integer(r['paintOrder'], allowZero: true);
        if (!ids.add(id) || !orders.add(order)) {
          _fail('Duplicate identity/order');
        }
        if (!_groups.contains(r['groupId']) ||
            !_labels.contains(r['labelKey'])) {
          _fail('Unknown group/label');
        }
        final expectedLabel = switch (r['groupId']) {
          'walls' => 'roomSurfaceWall',
          'ceiling' => 'roomSurfaceCeiling',
          'floor' => 'roomSurfaceFloor',
          _ => 'roomSurfaceFurniture',
        };
        if (r['labelKey'] != expectedLabel || r['fillable'] is! bool) {
          _fail('Invalid region metadata');
        }
        final fillable = r['fillable'] as bool;
        final g = _map(r['geometry'], {'parts'});
        final parts = <VectorRegionPart>[];
        for (final rawPart in _list(g['parts'])) {
          final part = _map(
            rawPart,
            {'slot', 'commands'},
            optional: {'whiteOverlayOpacity', 'blackOverlayOpacity'},
          );
          final slot = _integer(part['slot'], allowZero: true);
          if (!slots.add(slot)) _fail('Duplicate paint slot');
          final commands = <List<Object>>[];
          var started = false;
          var closed = true;
          for (final rawCommand in _list(part['commands'])) {
            if (rawCommand is! List || rawCommand.isEmpty) {
              _fail('Invalid command');
            }
            final arity = const {
              'M': 2,
              'L': 2,
              'Q': 4,
              'C': 6,
              'Z': 0,
            }[rawCommand[0]];
            if (arity == null || rawCommand.length != arity + 1) {
              _fail('Unsupported command/arity');
            }
            final op = rawCommand[0] as String;
            if (!started && op != 'M') _fail('Path must start with M');
            if (op == 'M') {
              if (fillable && !closed) _fail('Unclosed contour');
              started = true;
              closed = false;
            } else if (closed) {
              _fail('Command after Z needs M');
            }
            final command = <Object>[op];
            for (var i = 1; i < rawCommand.length; i++) {
              command.add(_number(rawCommand[i], i.isOdd ? width : height));
            }
            if (op == 'Z') closed = true;
            commands.add(command);
          }
          if (!started || (fillable && !closed)) _fail('Empty/unclosed fill');
          parts.add(
            VectorRegionPart(
              slot: slot,
              commands: commands,
              whiteOverlayOpacity: rawPart.containsKey('whiteOverlayOpacity')
                  ? _number(rawPart['whiteOverlayOpacity'], 1)
                  : 0,
              blackOverlayOpacity: rawPart.containsKey('blackOverlayOpacity')
                  ? _number(rawPart['blackOverlayOpacity'], 1)
                  : 0,
            ),
          );
        }
        if (parts.isEmpty) _fail('Empty geometry');
        regions.add(
          VectorRegionDefinition(
            id: id,
            labelKey: r['labelKey'] as String,
            groupId: r['groupId'] as String,
            fillable: fillable,
            paintOrder: order,
            geometry: VectorRegionGeometry(parts: parts),
          ),
        );
      }
      if (regions.isEmpty) _fail('Empty artwork');
      return VectorArtworkDefinition(
        id: _stableId(root['id']),
        revision: _integer(root['revision']),
        intrinsicSize: Size(width, height),
        regions: regions,
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      _fail('Malformed region data');
    }
  }

  static Never _fail(String message) => throw FormatException(message);
  static Map<String, dynamic> _map(
    dynamic value,
    Set<String> keys, {
    Set<String> optional = const {},
  }) {
    if (value is! Map<String, dynamic> ||
        !keys.every(value.containsKey) ||
        !value.keys.every({...keys, ...optional}.contains)) {
      _fail('Unknown/missing field');
    }
    return value;
  }

  static List<dynamic> _list(dynamic value) {
    if (value is! List) _fail('Expected list');
    return value;
  }

  static String _stableId(dynamic value) {
    if (value is! String || !_id.hasMatch(value)) _fail('Invalid stable ID');
    return value;
  }

  static int _integer(dynamic value, {bool allowZero = false}) {
    if (value is! int || value < (allowZero ? 0 : 1)) _fail('Invalid integer');
    return value;
  }

  static double _number(dynamic value, double max) {
    if (value is! num || !value.isFinite || value < 0 || value > max) {
      _fail('Coordinate/dimension out of bounds');
    }
    return value.toDouble();
  }
}
