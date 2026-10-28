import 'dart:convert';
import 'package:color_lab/core/vector_regions/data/vector_region_json_codec.dart';

Map<String, Object?> artworkJson({
  List<Object?>? commands,
  bool fillable = true,
}) => {
  'schemaVersion': 1,
  'id': 'fixture',
  'revision': 1,
  'width': 1200,
  'height': 800,
  'regions': [regionJson('back', 0, commands: commands, fillable: fillable)],
};
Map<String, Object?> regionJson(
  String id,
  int order, {
  List<Object?>? commands,
  bool fillable = true,
}) => {
  'id': id,
  'labelKey': 'roomSurfaceWall',
  'groupId': 'walls',
  'fillable': fillable,
  'paintOrder': order,
  'geometry': {
    'parts': [
      {'slot': order, 'commands': commands ?? rectangle(10, 20, 100, 80)},
    ],
  },
};
List<Object?> rectangle(num x, num y, num w, num h) => [
  ['M', x, y],
  ['L', x + w, y],
  ['L', x + w, y + h],
  ['L', x, y + h],
  ['Z'],
];
String encodeFixture(Map<String, Object?> value) => jsonEncode(value);
final codec = VectorRegionJsonCodec();
