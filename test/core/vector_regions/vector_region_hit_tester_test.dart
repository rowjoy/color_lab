import 'dart:ui';
import 'package:color_lab/core/vector_regions/application/vector_region_hit_tester.dart';
import 'package:color_lab/core/vector_regions/application/vector_region_transform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'fixtures.dart';

// Mutation: forward paint order, bounds-only hits, hittable decoration or screen epsilon drift.
void main() {
  test('reverse order, holes, boundary epsilon and decoration', () {
    final json = artworkJson();
    json['regions'] = [
      regionJson('back', 0),
      regionJson(
        'front',
        1,
        commands: [...rectangle(10, 20, 100, 80), ...rectangle(30, 40, 20, 20)],
      ),
      regionJson('decoration', 2, fillable: false),
    ];
    final art = codec.decode(encodeFixture(json));
    final transform = VectorRegionTransform.fit(
      intrinsicSize: art.intrinsicSize,
      viewport: const Size(600, 600),
    );
    String? hit(Offset point, {double epsilon = .5}) => hitTestVectorRegion(
      art,
      transform.artworkToScreen(point),
      transform,
      epsilon: epsilon,
    )?.id;
    expect(hit(const Offset(20, 30)), 'front');
    expect(hit(const Offset(40, 50)), 'back');
    expect(hit(const Offset(9.5, 30)), 'front');
    expect(hit(const Offset(8, 30)), isNull);
    expect(hitTestVectorRegion(art, const Offset(100, 20), transform), isNull);
    expect(hit(const Offset(110, 50), epsilon: 0), 'front');
  });
}
