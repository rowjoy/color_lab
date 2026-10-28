import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final snapshots = <ExperimentSnapshot>[
    const LabExperimentSnapshot(hue: 275, saturation: .25, lightness: .74),
    MixerExperimentSnapshot(
      space: MixerExperimentSpace.lab,
      stops: [
        MixerExperimentStop(id: 'a', hex: '#112233', weight: 40),
        MixerExperimentStop(id: 'b', hex: '#AABBCC', weight: 60),
      ],
    ),
    const HarmonyExperimentSnapshot(
      baseHex: '#112233',
      mode: HarmonyExperimentMode.triadic,
    ),
    const FormulaExperimentSnapshot(targetHex: '#ABCDEF'),
    const MatchingExperimentSnapshot(
      targetHex: '#112233',
      guessHex: '#445566',
      hue: 210,
      saturation: .2,
      lightness: .33,
      deltaE: 19.25,
    ),
  ];

  test('all typed snapshots have exact v1 keys and round trip by tool', () {
    final expectedKeys = <ExperimentTool, Set<String>>{
      ExperimentTool.lab: {
        'schemaVersion',
        'tool',
        'hue',
        'saturation',
        'lightness',
      },
      ExperimentTool.mixer: {'schemaVersion', 'tool', 'space', 'stops'},
      ExperimentTool.harmonies: {'schemaVersion', 'tool', 'baseHex', 'mode'},
      ExperimentTool.formula: {'schemaVersion', 'tool', 'targetHex'},
      ExperimentTool.matching: {
        'schemaVersion',
        'tool',
        'targetHex',
        'guessHex',
        'hue',
        'saturation',
        'lightness',
        'deltaE',
      },
    };
    for (final snapshot in snapshots) {
      final map = snapshot.toMap();
      expect(map.keys.toSet(), expectedKeys[snapshot.tool]);
      expect(ExperimentSnapshot.fromMap(map), snapshot);
    }
  });

  test(
    'strict decoders reject malformed HEX, model values, and cross-tool payloads',
    () {
      final formula = const FormulaExperimentSnapshot(
        targetHex: '#ABCDEF',
      ).toMap();
      for (final hex in ['ABCDEF', '#ABC', '#ABCDEG']) {
        expect(
          () => ExperimentSnapshot.fromMap({...formula, 'targetHex': hex}),
          throwsFormatException,
        );
      }
      final mixer = snapshots[1].toMap();
      expect(
        () => ExperimentSnapshot.fromMap({...mixer, 'space': 'pigment'}),
        throwsFormatException,
      );
      expect(
        () => ExperimentSnapshot.fromMap({...formula, 'tool': 'mixer'}),
        throwsFormatException,
      );
      expect(
        () => ExperimentSnapshot.fromMap({...formula, 'extra': true}),
        throwsFormatException,
      );
    },
  );

  test('unknown known-tool versions preserve their exact payload', () {
    final raw = <String, Object?>{
      'schemaVersion': 7,
      'tool': 'lab',
      'futureModel': 'oklch',
      'coordinates': [0.7, 0.1, 240],
    };
    final decoded = ExperimentSnapshot.fromMap(raw);
    expect(decoded, isA<UnknownExperimentSnapshot>());
    expect(decoded.tool, ExperimentTool.lab);
    expect(decoded.toMap(), raw);
    expect(
      () => ExperimentSnapshot.fromMap({...raw, 'tool': 'future-tool'}),
      throwsFormatException,
    );
  });

  test('mixer snapshot owns an immutable stop-list copy', () {
    final source = [
      const MixerExperimentStop(id: 'a', hex: '#112233', weight: 40),
      const MixerExperimentStop(id: 'b', hex: '#AABBCC', weight: 60),
    ];
    final snapshot = MixerExperimentSnapshot(
      space: MixerExperimentSpace.lab,
      stops: source,
    );
    source.clear();
    expect(snapshot.stops, hasLength(2));
    expect(() => snapshot.stops.clear(), throwsUnsupportedError);
  });

  test('experiment record validates canonical HEX and UTC timestamps', () {
    final created = DateTime.utc(2026, 10, 28, 1, 2, 3, 4, 5);
    final record = ExperimentRecord(
      id: 'record-1',
      title: 'Lab note',
      lessonId: null,
      inputHexes: const ['#112233'],
      resultHexes: const ['#AABBCC', '#DDEEFF'],
      snapshot: snapshots.first,
      observation: 'A labeled observation.',
      createdAt: created,
      updatedAt: created.add(const Duration(minutes: 1)),
    );
    expect(ExperimentRecord.fromMap(record.toMap()), record);
    expect(record.toMap()['createdAt'], '2026-10-28T01:02:03.004005Z');
    expect(
      () => ExperimentRecord(
        id: 'record-1',
        title: 'Bad',
        lessonId: null,
        inputHexes: const ['112233'],
        resultHexes: const ['#AABBCC'],
        snapshot: snapshots.first,
        observation: '',
        createdAt: created,
        updatedAt: created,
      ),
      throwsFormatException,
    );
  });
}
