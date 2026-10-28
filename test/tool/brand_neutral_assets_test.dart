import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shipped source assets copy tests and metadata stay brand neutral', () {
    // Match identifying phrases, not generic color words or incidental digits.
    final forbidden = RegExp(
      [
        r'asian[\s._-]*paints?',
        r'asianpaints\.com',
        r'milkshake[\s_-]*8012',
        r'white[\s_-]*clay[\s_-]*8620',
        r'gossamer[\s_-]*8052',
        r'white[\s_-]*cameo[\s_-]*l145',
        r'timber[\s_-]*glaze',
        r'bangladesh paint guidance',
        r'market[ -]guided',
        r'market guide - reviewed',
      ].join('|'),
      caseSensitive: false,
    );
    final failures = <String>[];
    // Explicit shipping/test roots exclude history, caches and planning/policy
    // documents (including the design spec's manufacturer prohibition sentence).
    final roots = [
      'lib',
      'test',
      'assets',
      'tool',
      'android',
      'ios',
      '.github',
    ];
    final files = <File>[
      for (final root in roots)
        if (Directory(root).existsSync())
          ...Directory(
            root,
          ).listSync(recursive: true, followLinks: false).whereType<File>(),
      for (final path in [
        'README.md',
        'pubspec.yaml',
        'pubspec.lock',
        'l10n.yaml',
      ])
        if (File(path).existsSync()) File(path),
    ];
    for (final file in files) {
      // The scanner's phrase definitions are test inputs, never product copy.
      if (file.path == 'test/tool/brand_neutral_assets_test.dart') continue;
      if (file.path
          .split('/')
          .any(
            (part) => [
              'build',
              '.gradle',
              'Pods',
              '.symlinks',
              '.git',
            ].contains(part),
          )) {
        continue;
      }
      final bytes = file.readAsBytesSync();
      if (bytes.contains(0)) continue;
      String source;
      try {
        source = utf8.decode(bytes);
      } on FormatException {
        continue;
      }
      // Dart adjacent literals can split a prohibited phrase across lines.
      source = source.replaceAll(RegExp(r'''['"]\s*['"]'''), '');
      final match = forbidden.firstMatch(source);
      if (match != null) failures.add('${file.path}: ${match.group(0)}');
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
