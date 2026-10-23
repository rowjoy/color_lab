import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = RgbColor(170, 187, 204);
  SavedPalette palette({
    Iterable<RgbColor>? colors,
    String name = '  Mist  ',
  }) => SavedPalette(
    name: name,
    base: base,
    mode: HarmonyMode.complementary,
    colors: colors ?? [base, RgbColor(1, 2, 3)],
    createdAt: DateTime.parse('2026-10-21T15:00:00+06:00'),
  );
  final canonical = <String, Object>{
    'version': 1,
    'id': 'complementary-AABBCC',
    'name': 'Mist',
    'base': '#AABBCC',
    'mode': 'complementary',
    'colors': ['#AABBCC', '#010203'],
    'createdAt': '2026-10-21T09:00:00.000Z',
  };

  test('canonical map preserves a stored snapshot without regenerating it', () {
    final saved = palette();
    expect(saved.toMap(), canonical);
    expect(SavedPalette.fromMap(canonical), saved);
    expect(SavedPalette.fromMap(canonical).hashCode, saved.hashCode);
    expect(saved.createdAt.isUtc, isTrue);
    expect(SavedPalette.idFor(base, HarmonyMode.triadic), 'triadic-AABBCC');
    expect(() => saved.toMap()['name'] = 'Changed', throwsUnsupportedError);
    expect(
      () => (saved.toMap()['colors'] as List).clear(),
      throwsUnsupportedError,
    );
  });

  test('snapshots input exactly once and detaches from its mutable source', () {
    final source = [base, RgbColor(1, 2, 3)];
    var traversals = 0;
    Iterable<RgbColor> once() sync* {
      if (++traversals > 1) throw StateError('enumerated twice');
      yield* source;
    }

    final saved = palette(colors: once());
    source.clear();
    expect(saved.colors.map((color) => color.hex), ['#AABBCC', '#010203']);
    expect(() => saved.colors.clear(), throwsUnsupportedError);
    expect(traversals, 1);
  });

  test('rejects blank names and invalid snapshot shapes', () {
    expect(() => palette(name: '  '), throwsArgumentError);
    for (final colors in <List<RgbColor>>[
      [],
      [RgbColor(1, 2, 3), base],
      [base, base],
      [base, for (var i = 0; i < 5; i++) RgbColor(i, 0, 0)],
    ]) {
      expect(() => palette(colors: colors), throwsArgumentError);
    }
    expect(palette(colors: [base]).colors, [base]);
  });

  test('rejects unsupported malformed and noncanonical persisted metadata', () {
    final invalid = <Map<String, Object?>>[
      {...canonical, 'version': 2},
      {...canonical, 'version': 1.0},
      {...canonical, 'id': 'complementary-010203'},
      {...canonical, 'base': '#aabbcc'},
      {...canonical, 'base': 'AABBCC'},
      {...canonical, 'mode': 'future'},
      {...canonical, 'name': '   '},
      {...canonical, 'name': 12},
      {
        ...canonical,
        'colors': ['#AABBCC', '#010203', '#010203'],
      },
      {
        ...canonical,
        'colors': ['#aabbcc'],
      },
      {
        ...canonical,
        'colors': ['#010203'],
      },
      {...canonical, 'colors': []},
      {
        ...canonical,
        'colors': ['#AABBCC', null],
      },
      {...canonical, 'createdAt': '2026-10-21T09:00:00.000'},
      {...canonical, 'createdAt': '2026-10-21T15:00:00.000+06:00'},
      {...canonical, 'createdAt': '2026-02-30T09:00:00.000Z'},
      {...canonical, 'createdAt': null},
      {...canonical, 'extra': true},
    ];
    for (final record in invalid) {
      expect(
        () => SavedPalette.fromMap(record),
        throwsFormatException,
        reason: '$record',
      );
    }
    expect(
      () => SavedPalette.fromMap({...canonical}..remove('name')),
      throwsFormatException,
    );
  });

  test('value identity includes the complete ordered persisted snapshot', () {
    final saved = palette();
    expect(saved, palette());
    expect(saved, isNot(palette(name: 'Other')));
    expect(saved, isNot(palette(colors: [base])));
    expect(
      saved,
      isNot(
        SavedPalette(
          name: 'Mist',
          base: base,
          mode: HarmonyMode.triadic,
          colors: saved.colors,
          createdAt: saved.createdAt,
        ),
      ),
    );
  });
}
