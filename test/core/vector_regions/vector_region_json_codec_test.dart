import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures.dart';

// Mutation: accepting unsupported schema/commands or malformed metadata and paths.
void main() {
  // Mutation: accepting paint-slot order that disagrees with region paintOrder
  // makes the visible overlap and region selected by hit testing disagree.
  test('rejects contradictory paint slot and region ordering', () {
    final back = regionJson('back', 0);
    final front = regionJson('front', 1);
    (((back['geometry'] as Map)['parts'] as List).single as Map)['slot'] = 2;
    (((front['geometry'] as Map)['parts'] as List).single as Map)['slot'] = 0;
    final json = artworkJson()..['regions'] = [front, back];
    // Both independently authored parts cover (20,30). Slot 2 would paint back
    // above front, while the original region-order hit tester selected front.
    expect(() => codec.decode(encodeFixture(json)), throwsFormatException);
  });

  test('builds cached paths, Q/C curves and exact path-derived bounds', () {
    final art = codec.decode(
      encodeFixture(
        artworkJson(
          commands: [
            ['M', 10, 20],
            ['Q', 20, 20, 30, 30],
            ['C', 40, 40, 80, 80, 100, 100],
            ['L', 10, 100],
            ['Z'],
          ],
        ),
      ),
    );
    final geometry = art.regions.single.geometry;
    expect(art.intrinsicSize, const Size(1200, 800));
    expect(geometry.toPath(), same(geometry.toPath()));
    expect(geometry.bounds, const Rect.fromLTRB(10, 20, 100, 100));
    expect(geometry.bounds, geometry.toPath().getBounds());
  });
  for (final entry in <String, void Function(Map<String, Object?>)>{
    'schema': (v) => v['schemaVersion'] = 2,
    'zero width': (v) => v['width'] = 0,
    'oversized artboard': (v) => v['width'] = 1201,
    'fractional revision': (v) => v['revision'] = 1.5,
    'unknown root key': (v) => v['script'] = 'alert(1)',
    'unstable id': (v) => v['id'] = 'Bad ID',
    'duplicate id': (v) => (v['regions'] as List).add(regionJson('back', 1)),
    'duplicate order': (v) =>
        (v['regions'] as List).add(regionJson('front', 0)),
    'bad group': (v) =>
        ((v['regions'] as List).first as Map)['groupId'] = 'script',
    'bad label': (v) =>
        ((v['regions'] as List).first as Map)['labelKey'] = 'unknownLabel',
  }.entries) {
    test('rejects ${entry.key}', () {
      final value = artworkJson();
      entry.value(value);
      expect(() => codec.decode(encodeFixture(value)), throwsFormatException);
    });
  }
  for (final commands in <List<Object?>>[
    [
      ['L', 1, 2],
      ['Z'],
    ],
    [
      ['M', 1, 2],
      ['H', 5],
      ['Z'],
    ],
    [
      ['m', 1, 2],
      ['Z'],
    ],
    [
      ['M', 1, 2],
      ['A', 2, 2, 0, 0, 0, 4, 4],
      ['Z'],
    ],
    [
      ['M', 1, 2],
      ['L', 4, 4],
    ],
    [
      ['M', -1, 2],
      ['Z'],
    ],
    [
      ['M', 1201, 2],
      ['Z'],
    ],
    [
      ['M', 1, 801],
      ['Z'],
    ],
    [
      ['M', 'NaN', 2],
      ['Z'],
    ],
    [
      ['M', 1, 2, 3],
      ['Z'],
    ],
    [
      ['M', 1, 2],
      ['Z'],
      ['L', 3, 4],
    ],
    [
      ['M', 1, 2],
      ['M', 3, 4],
      ['Z'],
    ],
    [],
  ]) {
    test('rejects invalid commands $commands', () {
      expect(
        () => codec.decode(encodeFixture(artworkJson(commands: commands))),
        throwsFormatException,
      );
    });
  }
  test('rejects nonfinite numeric coordinates from JSON exponent overflow', () {
    final source = encodeFixture(
      artworkJson(),
    ).replaceFirst('["M",10,20]', '["M",1e999,20]');
    expect(() => codec.decode(source), throwsFormatException);
  });
  test('allows open decoration but never marks it fillable', () {
    final art = codec.decode(
      encodeFixture(
        artworkJson(
          fillable: false,
          commands: [
            ['M', 1, 2],
            ['L', 3, 4],
          ],
        ),
      ),
    );
    expect(art.regions.single.fillable, isFalse);
  });
}
