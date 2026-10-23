import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final instant = DateTime.utc(2026, 10, 21, 9);
  SavedColor color() => SavedColor(
    id: '#abc',
    hex: 'aabbcc',
    name: '  Mist  ',
    isFavorite: false,
    createdAt: instant,
    source: ColorSource.manual,
  );

  test('normalizes RGB identity and name with a UTC creation time', () {
    final saved = color();
    expect(saved.id, '#AABBCC');
    expect(saved.hex, '#AABBCC');
    expect(saved.name, 'Mist');
    expect(saved.createdAt.isUtc, isTrue);
    expect(saved.createdAt, instant);
  });

  test('copies preserve original values and implement value equality', () {
    final saved = color();
    final favorite = saved.copyWith(isFavorite: true);
    expect(saved.isFavorite, isFalse);
    expect(favorite.isFavorite, isTrue);
    expect(favorite.copyWith(isFavorite: false), saved);
    expect({saved}.contains(color()), isTrue);
    expect(saved.copyWith(), saved);
  });

  test('round trips every source through an immutable versioned map', () {
    for (final source in ColorSource.values) {
      final saved = color().copyWith(source: source);
      final map = saved.toMap();
      expect(map['version'], 1);
      expect(map['id'], '#AABBCC');
      expect(map['createdAt'], '2026-10-21T09:00:00.000Z');
      expect(map['source'], source.name);
      expect(SavedColor.fromMap(map), saved);
      expect(() => map['name'] = 'Changed', throwsUnsupportedError);
    }
  });

  test('rejects blank names, invalid RGB and identity mismatches', () {
    expect(() => color().copyWith(name: '  '), throwsArgumentError);
    expect(() => color().copyWith(hex: '#AABBCCDD'), throwsFormatException);
    expect(() => color().copyWith(id: '#112233'), throwsArgumentError);
  });

  test(
    'rejects unsupported versions, sources, types and invalid timestamps',
    () {
      final map = color().toMap();
      for (final override in <Map<String, Object?>>[
        {'version': 2},
        {'version': '1'},
        {'source': 'future-source'},
        {'isFavorite': 1},
        {'name': ''},
        {'id': '#112233'},
        {'createdAt': 'not-a-date'},
        {'createdAt': '2026-99-21T09:00:00.000Z'},
        {'createdAt': '2026-10-21T09:00:00.000'},
      ]) {
        expect(
          () => SavedColor.fromMap({...map, ...override}),
          throwsFormatException,
        );
      }
      final missingName = {...map}..remove('name');
      expect(() => SavedColor.fromMap(missingName), throwsFormatException);
    },
  );
}
