import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:flutter_test/flutter_test.dart';

RoomVariantSet variants() => RoomVariantSet(
  variants: [
    RoomColorVariant(id: 'a', name: 'A', colors: const RoomLayerColors()),
    RoomColorVariant(
      id: 'b',
      name: 'B',
      colors: RoomLayerColors(wall: RgbColor(1, 2, 3)),
    ),
    RoomColorVariant(id: 'c', name: 'C', colors: const RoomLayerColors()),
  ],
  activeVariantId: 'b',
  comparisonBaselineVariantId: 'a',
);

Matcher failure(RoomVariantFailure code) => throwsA(
  isA<RoomVariantException>().having((e) => e.failure, 'failure', code),
);

void main() {
  test('create copies only active colors, trims its name, selects new ID', () {
    final before = variants();
    final after = before.create('d', '  Evening  ');
    expect(after.activeVariantId, 'd');
    expect(after.variants.last.name, 'Evening');
    expect(identical(after.variants.last.colors, before.active.colors), isTrue);
    expect(before.variants, hasLength(3));
    expect(after.comparisonBaselineVariantId, 'a');
    expect(() => after.variants.clear(), throwsUnsupportedError);
  });
  for (final name in ['', '   ', 'x' * 81, '😀' * 41, 'bad\nname']) {
    test('rejects invalid UTF-16 name ${name.length}', () {
      expect(
        () => variants().create('d', name),
        failure(RoomVariantFailure.invalidName),
      );
      expect(
        () => variants().rename('b', name),
        failure(RoomVariantFailure.invalidName),
      );
    });
  }
  test('80 UTF-16 units accepted and names unique ignoring case', () {
    expect(variants().create('d', '😀' * 40).active.name.length, 80);
    expect(
      () => variants().create('d', ' a '),
      failure(RoomVariantFailure.duplicateName),
    );
    expect(
      () => variants().rename('b', 'a'),
      failure(RoomVariantFailure.duplicateName),
    );
    expect(variants().rename('a', ' a ').variants.first.name, 'a');
  });
  test(
    'safe unique IDs, bounded count and all missing-ID commands fail safely',
    () {
      expect(
        () => variants().create('../escape', 'D'),
        failure(RoomVariantFailure.invalidId),
      );
      expect(
        () => variants().create('a', 'D'),
        failure(RoomVariantFailure.invalidId),
      );
      var all = variants();
      for (var i = 3; i < 32; i++) {
        all = all.create('v$i', 'Name $i');
      }
      expect(
        () => all.create('last', 'Last'),
        failure(RoomVariantFailure.limit),
      );
      for (final call in [
        () => variants().select('missing'),
        () => variants().rename('missing', 'X'),
        () => variants().delete('missing'),
        () => variants().pin('missing'),
      ]) {
        expect(call, failure(RoomVariantFailure.missing));
      }
    },
  );
  test(
    'delete active selects first persisted survivor, baseline deletion clears',
    () {
      final before = variants();
      final activeDeleted = before.delete('b');
      expect(activeDeleted.activeVariantId, 'a');
      expect(activeDeleted.comparisonBaselineVariantId, 'a');
      final baselineDeleted = before.delete('a');
      expect(baselineDeleted.activeVariantId, 'b');
      expect(baselineDeleted.comparisonBaselineVariantId, isNull);
      final unrelated = before.delete('c');
      expect(unrelated.activeVariantId, 'b');
      expect(unrelated.comparisonBaselineVariantId, 'a');
      final last = unrelated.delete('a');
      expect(() => last.delete('b'), failure(RoomVariantFailure.finalVariant));
      expect(last.active.colors, before.active.colors);
    },
  );
  test('selection pin and clear never change either color snapshot', () {
    final before = variants();
    final after = before.select('c').pin('b').clearComparison();
    expect(after.activeVariantId, 'c');
    expect(after.comparisonBaselineVariantId, isNull);
    expect(
      after.variants.map((v) => v.colors),
      before.variants.map((v) => v.colors),
    );
    final edited = before.updateColors(
      RoomLayerColors(floor: RgbColor(4, 5, 6)),
    );
    expect(edited.variants.first.colors, before.variants.first.colors);
    expect(edited.variants.last.colors, before.variants.last.colors);
    expect(edited.active.colors.floor, RgbColor(4, 5, 6));
  });
}
