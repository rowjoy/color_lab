import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/validate_coloring_catalog.dart' as validator;

// Mutation: accepting unlisted files, hidden brand metadata or invalid paths.
void main() {
  final repository = Directory.current;
  late Directory fixture;
  late Map<String, dynamic> manifest;
  late Map<String, dynamic> artwork;

  Map<String, dynamic> entry() =>
      (manifest['drawings'] as List).first as Map<String, dynamic>;
  Map<String, dynamic> region() =>
      (artwork['regions'] as List).first as Map<String, dynamic>;
  Map<String, dynamic> part() =>
      ((region()['geometry'] as Map)['parts'] as List).first
          as Map<String, dynamic>;

  void save({String? source}) {
    final encoded = source ?? jsonEncode(artwork);
    File('${fixture.path}/${entry()['asset']}').writeAsStringSync(encoded);
    entry()['contentHash'] = sha256.convert(utf8.encode(encoded)).toString();
    File(
      '${fixture.path}/assets/coloring/manifest.json',
    ).writeAsStringSync(jsonEncode(manifest));
  }

  void validate() {
    Directory.current = fixture;
    try {
      validator.main();
    } finally {
      Directory.current = repository;
    }
  }

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('coloring-validator-');
    final destination = Directory('${fixture.path}/assets/coloring')
      ..createSync(recursive: true);
    for (final file in Directory(
      '${repository.path}/assets/coloring',
    ).listSync().whereType<File>()) {
      file.copySync('${destination.path}/${file.uri.pathSegments.last}');
    }
    manifest =
        jsonDecode(File('${destination.path}/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    artwork =
        jsonDecode(
              File('${fixture.path}/${entry()['asset']}').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });
  tearDown(() => fixture.deleteSync(recursive: true));

  test('accepts the shipped catalog and multiple closed contours', () {
    part()['commands'] = [
      ['M', 0, 0],
      ['L', 600, 0],
      ['L', 600, 400],
      ['L', 0, 400],
      ['Z'],
      ['M', 20, 20],
      ['L', 20, 40],
      ['L', 40, 40],
      ['Z'],
    ];
    save();
    expect(validate, returnsNormally);
  });

  for (final name in ['extra.json', 'notes.txt', 'nested/extra.json']) {
    test('rejects unlisted file $name', () {
      File('${fixture.path}/assets/coloring/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync('{}');
      expect(validate, throwsFormatException);
    });
  }
  test('rejects missing referenced files', () {
    File('${fixture.path}/${entry()['asset']}').deleteSync();
    expect(validate, throwsFormatException);
  });

  final forbidden = [
    ['Asian', 'Paints'].join('_'),
    ['Dul', 'ux'].join(),
    ['Sherwin', 'Williams'].join('-'),
    ['Benjamin', 'Moore'].join(' '),
    ['Milkshake', '8012'].join(' '),
    ['White', 'Clay', '8620'].join('_'),
    ['Gossamer', '8052'].join(' '),
    ['White', 'Cameo', 'L145'].join('-'),
    ['Timber', 'Glaze'].join(' '),
  ];
  for (var index = 0; index < forbidden.length; index++) {
    test('rejects forbidden manifest metadata $index', () {
      entry()['sourceNote'] = forbidden[index];
      save();
      expect(validate, throwsFormatException);
    });
  }
  for (final field in ['labelKey', 'groupId', 'id']) {
    test('scans artwork $field for forbidden metadata', () {
      final value = ['Dul', 'ux'].join();
      final oldId = region()['id'];
      region()[field] = value;
      if (field == 'id') {
        for (final rule in entry()['regionRules'] as List) {
          if ((rule as Map)['regionId'] == oldId) rule['regionId'] = value;
        }
      }
      save();
      expect(validate, throwsFormatException);
    });
  }

  final invalidPaths = <String, List<Object?>>{
    'missing initial move': [
      ['L', 10, 10],
      ['Z'],
    ],
    'close without contour': [
      ['Z'],
    ],
    'line after close': [
      ['M', 0, 0],
      ['Z'],
      ['L', 10, 10],
    ],
    'duplicate close': [
      ['M', 0, 0],
      ['Z'],
      ['Z'],
    ],
    'move before closing contour': [
      ['M', 0, 0],
      ['L', 10, 10],
      ['M', 20, 20],
      ['Z'],
    ],
    'unclosed contour': [
      ['M', 0, 0],
      ['L', 10, 10],
    ],
    'x exceeds intrinsic width': [
      ['M', 601, 0],
      ['Z'],
    ],
    'y exceeds intrinsic height': [
      ['M', 0, 401],
      ['Z'],
    ],
    'curve control exceeds bounds': [
      ['M', 0, 0],
      ['Q', 601, 2, 5, 5],
      ['Z'],
    ],
    'negative point': [
      ['M', -1, 0],
      ['Z'],
    ],
    'empty path': [],
    'empty command': [[]],
    'unknown command': [
      ['M', 0, 0],
      ['H', 3],
      ['Z'],
    ],
    'bad arity': [
      ['M', 0],
      ['Z'],
    ],
  };
  for (final path in invalidPaths.entries) {
    test('rejects ${path.key} as malformed artwork', () {
      part()['commands'] = path.value;
      save();
      expect(validate, throwsFormatException);
    });
  }
  test('rejects nonfinite JSON coordinates', () {
    part()['commands'] = [
      ['M', 99999, 0],
      ['Z'],
    ];
    save(source: jsonEncode(artwork).replaceFirst('99999', '1e999'));
    expect(validate, throwsFormatException);
  });
  for (final field in ['labelKey', 'groupId']) {
    test('rejects missing region $field', () {
      region().remove(field);
      save();
      expect(validate, throwsFormatException);
    });
  }
  test('rejects paint slots that contradict region paint order', () {
    part()['slot'] = 99;
    save();
    expect(validate, throwsFormatException);
  });
  test('rejects empty artwork', () {
    artwork['regions'] = [];
    entry()['regionRules'] = [];
    save();
    expect(validate, throwsFormatException);
  });
  test('standalone process reports failure for an invalid catalog', () async {
    File('${fixture.path}/assets/coloring/extra.json').writeAsStringSync('{}');
    final result = await Process.run('dart', [
      'run',
      '${repository.path}/tool/validate_coloring_catalog.dart',
    ], workingDirectory: fixture.path);
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('FormatException'));
  });
}
