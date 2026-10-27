import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/room_project_fixtures.dart';

void main() {
  test(
    'snapshots detach bytes and variants and preserve render identities',
    () {
      final source = Uint8List.fromList([4, 3, 2, 1]);
      final variants = [...roomProjectFixture().variants];
      final snapshot = roomProjectFixture().copyWith(
        maskBytes: source,
        variants: variants,
      );
      source[0] = 0;
      variants.clear();
      expect(snapshot.maskBytes, [4, 3, 2, 1]);
      expect(snapshot.variants, hasLength(2));
      expect(() => snapshot.maskBytes[0] = 0, throwsUnsupportedError);
      expect(() => snapshot.variants.clear(), throwsUnsupportedError);
      expect(snapshot.colors.wall!.hex, '#ABCDEF');
      expect(snapshot.maskRevision, 2);
      expect(snapshot.colorRevision, 3);
      expect(snapshot.schemaVersion, 1);
      expect(snapshot.comparisonBaselineVariantId, 'variant-b');
      expect(
        snapshot
            .copyWith(comparisonBaselineVariantId: null)
            .comparisonBaselineVariantId,
        isNull,
      );
    },
  );

  test('domain rejects unsafe identifiers and invalid bounded metadata', () {
    final valid = roomProjectFixture();
    for (final id in ['', '..', '../x', '/tmp/x', 'a/b', r'a\b', 'a%2fb']) {
      expect(() => valid.copyWith(projectId: id), throwsArgumentError);
      expect(() => valid.copyWith(photoId: id), throwsArgumentError);
      expect(
        () => RoomColorVariant(
          id: id,
          name: 'A',
          colors: const RoomLayerColors(),
        ),
        throwsArgumentError,
      );
    }
    for (final revision in [-1, 2147483648]) {
      expect(() => valid.copyWith(revision: revision), throwsArgumentError);
      expect(() => valid.copyWith(maskRevision: revision), throwsArgumentError);
      expect(
        () => valid.copyWith(colorRevision: revision),
        throwsArgumentError,
      );
    }
    expect(() => valid.copyWith(name: ''), throwsArgumentError);
    expect(() => valid.copyWith(name: 'x' * 81), throwsArgumentError);
    expect(() => valid.copyWith(width: 0), throwsArgumentError);
    expect(() => valid.copyWith(width: 100000), throwsArgumentError);
    expect(() => valid.copyWith(maskBytes: Uint8List(3)), throwsArgumentError);
    expect(
      () => valid.copyWith(aiMaskBytes: Uint8List.fromList([0, 0, 0, 5])),
      throwsArgumentError,
    );
    expect(
      () => valid.copyWith(updatedAt: DateTime.utc(2025)),
      throwsArgumentError,
    );
  });

  test('variants require unique IDs/names and valid active/comparison IDs', () {
    final valid = roomProjectFixture();
    expect(() => valid.copyWith(variants: []), throwsArgumentError);
    expect(
      () => valid.copyWith(
        variants: [valid.variants.first, valid.variants.first],
      ),
      throwsArgumentError,
    );
    expect(
      () => valid.copyWith(
        variants: [
          valid.variants.first,
          RoomColorVariant(
            id: 'variant-b',
            name: 'a',
            colors: const RoomLayerColors(),
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => valid.copyWith(activeVariantId: 'missing'),
      throwsArgumentError,
    );
    expect(
      () => valid.copyWith(comparisonBaselineVariantId: 'missing'),
      throwsArgumentError,
    );
    expect(
      () => valid.copyWith(
        variants: [
          for (var i = 0; i < 33; i++)
            RoomColorVariant(
              id: 'v-$i',
              name: '$i',
              colors: const RoomLayerColors(),
            ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
