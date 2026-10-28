enum ExperimentTool { lab, mixer, harmonies, formula, matching }

enum MixerExperimentSpace { lab, rgb }

enum HarmonyExperimentMode {
  complementary,
  analogous,
  triadic,
  tetradic,
  splitComplementary,
  monochromatic,
}

sealed class ExperimentSnapshot {
  const ExperimentSnapshot();

  factory ExperimentSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final normalized = _stringMap(map, 'experiment snapshot');
    final version = normalized['schemaVersion'];
    final tool = _enumValue(
      ExperimentTool.values,
      normalized['tool'],
      'experiment tool',
    );
    if (version is! int || version < 1) {
      throw const FormatException('Invalid experiment snapshot version.');
    }
    if (version != 1) {
      return UnknownExperimentSnapshot(
        tool: tool,
        schemaVersion: version,
        payload: normalized,
      );
    }
    return switch (tool) {
      ExperimentTool.lab => LabExperimentSnapshot.fromMap(normalized),
      ExperimentTool.mixer => MixerExperimentSnapshot.fromMap(normalized),
      ExperimentTool.harmonies => HarmonyExperimentSnapshot.fromMap(normalized),
      ExperimentTool.formula => FormulaExperimentSnapshot.fromMap(normalized),
      ExperimentTool.matching => MatchingExperimentSnapshot.fromMap(normalized),
    };
  }

  ExperimentTool get tool;
  Map<String, Object?> toMap();
}

final class LabExperimentSnapshot extends ExperimentSnapshot {
  const LabExperimentSnapshot({
    required this.hue,
    required this.saturation,
    required this.lightness,
  });

  factory LabExperimentSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final value = _stringMap(map, 'lab snapshot');
    _exactKeys(value, const {
      'schemaVersion',
      'tool',
      'hue',
      'saturation',
      'lightness',
    });
    _v1Tool(value, ExperimentTool.lab);
    return LabExperimentSnapshot(
      hue: _numberIn(value['hue'], 0, 360, 'hue', upperExclusive: true),
      saturation: _numberIn(value['saturation'], 0, 1, 'saturation'),
      lightness: _numberIn(value['lightness'], 0, 1, 'lightness'),
    );
  }

  final double hue;
  final double saturation;
  final double lightness;

  @override
  ExperimentTool get tool => ExperimentTool.lab;

  @override
  Map<String, Object?> toMap() {
    _numberIn(hue, 0, 360, 'hue', upperExclusive: true);
    _numberIn(saturation, 0, 1, 'saturation');
    _numberIn(lightness, 0, 1, 'lightness');
    return Map.unmodifiable({
      'schemaVersion': 1,
      'tool': tool.name,
      'hue': hue,
      'saturation': saturation,
      'lightness': lightness,
    });
  }

  @override
  bool operator ==(Object other) =>
      other is LabExperimentSnapshot &&
      other.hue == hue &&
      other.saturation == saturation &&
      other.lightness == lightness;
  @override
  int get hashCode => Object.hash(hue, saturation, lightness);
}

final class MixerExperimentStop {
  const MixerExperimentStop({
    required this.id,
    required this.hex,
    required this.weight,
  });

  factory MixerExperimentStop.fromMap(Map<dynamic, dynamic> map) {
    final value = _stringMap(map, 'mixer stop');
    _exactKeys(value, const {'id', 'hex', 'weight'});
    return MixerExperimentStop(
      id: _id(value['id'], 'mixer stop id'),
      hex: _hex(value['hex'], 'mixer stop color'),
      weight: _numberIn(value['weight'], 0, 100, 'mixer stop weight'),
    );
  }

  final String id;
  final String hex;
  final double weight;

  Map<String, Object?> toMap() => Map.unmodifiable({
    'id': _id(id, 'mixer stop id'),
    'hex': _hex(hex, 'mixer stop color'),
    'weight': _numberIn(weight, 0, 100, 'mixer stop weight'),
  });

  @override
  bool operator ==(Object other) =>
      other is MixerExperimentStop &&
      other.id == id &&
      other.hex == hex &&
      other.weight == weight;
  @override
  int get hashCode => Object.hash(id, hex, weight);
}

final class MixerExperimentSnapshot extends ExperimentSnapshot {
  MixerExperimentSnapshot({
    required this.space,
    required Iterable<MixerExperimentStop> stops,
  }) : stops = List.unmodifiable(stops) {
    _validateStops(this.stops);
  }

  factory MixerExperimentSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final value = _stringMap(map, 'mixer snapshot');
    _exactKeys(value, const {'schemaVersion', 'tool', 'space', 'stops'});
    _v1Tool(value, ExperimentTool.mixer);
    final rawStops = value['stops'];
    if (rawStops is! List) {
      throw const FormatException('Invalid mixer stops.');
    }
    final stops = rawStops
        .map((item) {
          if (item is! Map) throw const FormatException('Invalid mixer stop.');
          return MixerExperimentStop.fromMap(item);
        })
        .toList(growable: false);
    _validateStops(stops);
    return MixerExperimentSnapshot(
      space: _enumValue(
        MixerExperimentSpace.values,
        value['space'],
        'mixer space',
      ),
      stops: stops,
    );
  }

  final MixerExperimentSpace space;
  final List<MixerExperimentStop> stops;

  @override
  ExperimentTool get tool => ExperimentTool.mixer;

  @override
  Map<String, Object?> toMap() {
    _validateStops(stops);
    return Map.unmodifiable({
      'schemaVersion': 1,
      'tool': tool.name,
      'space': space.name,
      'stops': List.unmodifiable(stops.map((stop) => stop.toMap())),
    });
  }

  @override
  bool operator ==(Object other) =>
      other is MixerExperimentSnapshot &&
      other.space == space &&
      _listEqual(other.stops, stops);
  @override
  int get hashCode => Object.hash(space, Object.hashAll(stops));
}

final class HarmonyExperimentSnapshot extends ExperimentSnapshot {
  const HarmonyExperimentSnapshot({required this.baseHex, required this.mode});

  factory HarmonyExperimentSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final value = _stringMap(map, 'harmony snapshot');
    _exactKeys(value, const {'schemaVersion', 'tool', 'baseHex', 'mode'});
    _v1Tool(value, ExperimentTool.harmonies);
    return HarmonyExperimentSnapshot(
      baseHex: _hex(value['baseHex'], 'harmony base'),
      mode: _enumValue(
        HarmonyExperimentMode.values,
        value['mode'],
        'harmony mode',
      ),
    );
  }

  final String baseHex;
  final HarmonyExperimentMode mode;
  @override
  ExperimentTool get tool => ExperimentTool.harmonies;
  @override
  Map<String, Object?> toMap() => Map.unmodifiable({
    'schemaVersion': 1,
    'tool': tool.name,
    'baseHex': _hex(baseHex, 'harmony base'),
    'mode': mode.name,
  });

  @override
  bool operator ==(Object other) =>
      other is HarmonyExperimentSnapshot &&
      other.baseHex == baseHex &&
      other.mode == mode;
  @override
  int get hashCode => Object.hash(baseHex, mode);
}

final class FormulaExperimentSnapshot extends ExperimentSnapshot {
  const FormulaExperimentSnapshot({required this.targetHex});

  factory FormulaExperimentSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final value = _stringMap(map, 'formula snapshot');
    _exactKeys(value, const {'schemaVersion', 'tool', 'targetHex'});
    _v1Tool(value, ExperimentTool.formula);
    return FormulaExperimentSnapshot(
      targetHex: _hex(value['targetHex'], 'formula target'),
    );
  }

  final String targetHex;
  @override
  ExperimentTool get tool => ExperimentTool.formula;
  @override
  Map<String, Object?> toMap() => Map.unmodifiable({
    'schemaVersion': 1,
    'tool': tool.name,
    'targetHex': _hex(targetHex, 'formula target'),
  });

  @override
  bool operator ==(Object other) =>
      other is FormulaExperimentSnapshot && other.targetHex == targetHex;
  @override
  int get hashCode => targetHex.hashCode;
}

final class MatchingExperimentSnapshot extends ExperimentSnapshot {
  const MatchingExperimentSnapshot({
    required this.targetHex,
    required this.guessHex,
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.deltaE,
  });

  factory MatchingExperimentSnapshot.fromMap(Map<dynamic, dynamic> map) {
    final value = _stringMap(map, 'matching snapshot');
    _exactKeys(value, const {
      'schemaVersion',
      'tool',
      'targetHex',
      'guessHex',
      'hue',
      'saturation',
      'lightness',
      'deltaE',
    });
    _v1Tool(value, ExperimentTool.matching);
    return MatchingExperimentSnapshot(
      targetHex: _hex(value['targetHex'], 'matching target'),
      guessHex: _hex(value['guessHex'], 'matching guess'),
      hue: _numberIn(value['hue'], 0, 360, 'hue', upperExclusive: true),
      saturation: _numberIn(value['saturation'], 0, 1, 'saturation'),
      lightness: _numberIn(value['lightness'], 0, 1, 'lightness'),
      deltaE: _numberIn(value['deltaE'], 0, double.infinity, 'delta E'),
    );
  }

  final String targetHex;
  final String guessHex;
  final double hue;
  final double saturation;
  final double lightness;
  final double deltaE;
  @override
  ExperimentTool get tool => ExperimentTool.matching;
  @override
  Map<String, Object?> toMap() => Map.unmodifiable({
    'schemaVersion': 1,
    'tool': tool.name,
    'targetHex': _hex(targetHex, 'matching target'),
    'guessHex': _hex(guessHex, 'matching guess'),
    'hue': _numberIn(hue, 0, 360, 'hue', upperExclusive: true),
    'saturation': _numberIn(saturation, 0, 1, 'saturation'),
    'lightness': _numberIn(lightness, 0, 1, 'lightness'),
    'deltaE': _numberIn(deltaE, 0, double.infinity, 'delta E'),
  });

  @override
  bool operator ==(Object other) =>
      other is MatchingExperimentSnapshot &&
      other.targetHex == targetHex &&
      other.guessHex == guessHex &&
      other.hue == hue &&
      other.saturation == saturation &&
      other.lightness == lightness &&
      other.deltaE == deltaE;
  @override
  int get hashCode =>
      Object.hash(targetHex, guessHex, hue, saturation, lightness, deltaE);
}

final class UnknownExperimentSnapshot extends ExperimentSnapshot {
  UnknownExperimentSnapshot({
    required this.tool,
    required this.schemaVersion,
    required Map<String, Object?> payload,
  }) : payload = Map.unmodifiable(payload) {
    if (schemaVersion == 1 ||
        payload['schemaVersion'] != schemaVersion ||
        payload['tool'] != tool.name) {
      throw const FormatException('Invalid unknown experiment snapshot.');
    }
  }

  @override
  final ExperimentTool tool;
  final int schemaVersion;
  final Map<String, Object?> payload;
  @override
  Map<String, Object?> toMap() => payload;

  @override
  bool operator ==(Object other) =>
      other is UnknownExperimentSnapshot &&
      other.tool == tool &&
      other.schemaVersion == schemaVersion &&
      _mapEqual(other.payload, payload);
  @override
  int get hashCode => Object.hash(tool, schemaVersion, _mapHash(payload));
}

final class ExperimentRecord {
  ExperimentRecord({
    required this.id,
    required String title,
    required this.lessonId,
    required Iterable<String> inputHexes,
    required Iterable<String> resultHexes,
    required this.snapshot,
    required String observation,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : title = title.trim(),
       inputHexes = List.unmodifiable(inputHexes),
       resultHexes = List.unmodifiable(resultHexes),
       observation = observation.trim(),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    _id(id, 'experiment id');
    if (this.title.isEmpty || this.title.length > 120) {
      throw const FormatException('Invalid experiment title.');
    }
    if (lessonId != null) _id(lessonId, 'lesson id');
    if (this.inputHexes.isEmpty || this.resultHexes.isEmpty) {
      throw const FormatException('Experiment colors cannot be empty.');
    }
    for (final value in [...this.inputHexes, ...this.resultHexes]) {
      _hex(value, 'experiment color');
    }
    if (this.observation.length > 2000 ||
        this.updatedAt.isBefore(this.createdAt)) {
      throw const FormatException('Invalid experiment observation or dates.');
    }
  }

  factory ExperimentRecord.fromMap(Map<dynamic, dynamic> map) {
    final value = _stringMap(map, 'experiment record');
    _exactKeys(value, const {
      'schemaVersion',
      'id',
      'title',
      'lessonId',
      'inputHexes',
      'resultHexes',
      'snapshot',
      'observation',
      'createdAt',
      'updatedAt',
    });
    if (value['schemaVersion'] != 1 ||
        value['title'] is! String ||
        value['observation'] is! String ||
        (value['lessonId'] != null && value['lessonId'] is! String)) {
      throw const FormatException('Invalid experiment record schema.');
    }
    final snapshot = value['snapshot'];
    if (snapshot is! Map) {
      throw const FormatException('Invalid experiment payload.');
    }
    return ExperimentRecord(
      id: _id(value['id'], 'experiment id'),
      title: value['title']! as String,
      lessonId: value['lessonId'] as String?,
      inputHexes: _hexList(value['inputHexes'], 'experiment inputs'),
      resultHexes: _hexList(value['resultHexes'], 'experiment results'),
      snapshot: ExperimentSnapshot.fromMap(snapshot),
      observation: value['observation']! as String,
      createdAt: _utc(value['createdAt'], 'createdAt'),
      updatedAt: _utc(value['updatedAt'], 'updatedAt'),
    );
  }

  final String id;
  final String title;
  final String? lessonId;
  final List<String> inputHexes;
  final List<String> resultHexes;
  final ExperimentSnapshot snapshot;
  final String observation;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() => Map.unmodifiable({
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'lessonId': lessonId,
    'inputHexes': inputHexes,
    'resultHexes': resultHexes,
    'snapshot': snapshot.toMap(),
    'observation': observation,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  });

  @override
  bool operator ==(Object other) =>
      other is ExperimentRecord &&
      other.id == id &&
      other.title == title &&
      other.lessonId == lessonId &&
      _listEqual(other.inputHexes, inputHexes) &&
      _listEqual(other.resultHexes, resultHexes) &&
      other.snapshot == snapshot &&
      other.observation == observation &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;
  @override
  int get hashCode => Object.hash(
    id,
    title,
    lessonId,
    Object.hashAll(inputHexes),
    Object.hashAll(resultHexes),
    snapshot,
    observation,
    createdAt,
    updatedAt,
  );
}

void _v1Tool(Map<String, Object?> map, ExperimentTool tool) {
  if (map['schemaVersion'] != 1 || map['tool'] != tool.name) {
    throw FormatException('Invalid ${tool.name} snapshot schema.');
  }
}

void _validateStops(List<MixerExperimentStop> stops) {
  if (stops.length < 2 || stops.length > 12) {
    throw const FormatException('A mixer snapshot needs 2–12 stops.');
  }
  final ids = <String>{};
  for (final stop in stops) {
    stop.toMap();
    if (!ids.add(stop.id)) throw const FormatException('Duplicate mixer stop.');
  }
}

Map<String, Object?> _stringMap(Map<dynamic, dynamic> map, String field) {
  if (map.keys.any((key) => key is! String)) {
    throw FormatException('Invalid $field keys.');
  }
  return Map<String, Object?>.from(map);
}

void _exactKeys(Map<String, Object?> map, Set<String> keys) {
  if (map.length != keys.length || !map.keys.every(keys.contains)) {
    throw const FormatException('Unexpected schema keys.');
  }
}

String _id(Object? value, String field) {
  if (value is! String ||
      !RegExp(r'^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$').hasMatch(value)) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

String _hex(Object? value, String field) {
  if (value is! String || !RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
    throw FormatException('Invalid $field HEX.');
  }
  return value;
}

double _numberIn(
  Object? value,
  double lower,
  double upper,
  String field, {
  bool upperExclusive = false,
}) {
  if (value is! num) throw FormatException('Invalid $field.');
  final number = value.toDouble();
  if (!number.isFinite ||
      number < lower ||
      (upperExclusive ? number >= upper : number > upper)) {
    throw FormatException('Invalid $field range.');
  }
  return number;
}

T _enumValue<T extends Enum>(List<T> values, Object? raw, String field) {
  if (raw is! String) throw FormatException('Invalid $field.');
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Invalid $field.');
}

DateTime _utc(Object? value, String field) {
  if (value is! String || !value.endsWith('Z')) {
    throw FormatException('Invalid UTC $field.');
  }
  final result = DateTime.tryParse(value);
  if (result == null || !result.isUtc || result.toIso8601String() != value) {
    throw FormatException('Invalid UTC $field.');
  }
  return result;
}

List<String> _hexList(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Invalid $field.');
  }
  return List.unmodifiable(
    value.cast<String>().map((item) => _hex(item, field)),
  );
}

bool _listEqual(List<Object?> a, List<Object?> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

bool _mapEqual(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (entry.value is List && other is List) {
      if (!_listEqual(entry.value! as List<Object?>, other.cast<Object?>()))
        return false;
    } else if (entry.value != other) {
      return false;
    }
  }
  return true;
}

int _mapHash(Map<String, Object?> map) => Object.hashAll(
  map.entries.map(
    (entry) => Object.hash(
      entry.key,
      entry.value is List ? Object.hashAll(entry.value! as List) : entry.value,
    ),
  ),
);
