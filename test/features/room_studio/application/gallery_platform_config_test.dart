import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final lockfile = File('pubspec.lock').readAsStringSync();

  test('Android Gallery access is capped and has no broad read permission', () {
    final permissionTags = RegExp(
      r'<uses-permission\b[^>]*>',
      multiLine: true,
    ).allMatches(manifest).map((match) => match.group(0)!).toList();

    final writes = permissionTags
        .where(
          (tag) => tag.contains('android.permission.WRITE_EXTERNAL_STORAGE'),
        )
        .toList();
    expect(writes, hasLength(1));
    expect(writes.single, contains('android:maxSdkVersion="29"'));
    expect(
      writes.single,
      contains('tools:replace="android:maxSdkVersion"'),
      reason: 'The app must override CameraX\'s API-28 permission cap.',
    );
    expect(writes.single, isNot(contains('tools:node="remove"')));

    final reads = permissionTags
        .where((tag) => tag.contains('android.permission.READ_'))
        .toList();
    expect(reads, hasLength(1));
    expect(
      reads.single,
      contains('android:name="android.permission.READ_EXTERNAL_STORAGE"'),
    );
    expect(reads.single, contains('tools:node="remove"'));

    expect(manifest, isNot(contains('android.permission.READ_MEDIA_')));
    expect(
      manifest,
      isNot(contains('android.permission.MANAGE_EXTERNAL_STORAGE')),
    );
    expect(manifest, isNot(contains('requestLegacyExternalStorage')));
  });

  test('iOS keeps photo read copy and adds non-empty add-only copy', () {
    expect(
      _plistString(plist, 'NSPhotoLibraryUsageDescription'),
      'Choose a photo to explore its colors and create an on-device palette.',
    );
    expect(
      _plistString(plist, 'NSPhotoLibraryAddUsageDescription'),
      isNotEmpty,
    );
  });

  test('Gallery and vector renderer are exact direct main dependencies', () {
    final dependencies = _pubspecDependencies(pubspec);
    expect(
      dependencies,
      matches(RegExp(r'^  gal: 2\.3\.2\s*$', multiLine: true)),
    );
    expect(
      dependencies,
      matches(RegExp(r'^  vector_graphics: 1\.2\.4\s*$', multiLine: true)),
    );
    expect(
      _lockPackageBlock(lockfile, 'gal'),
      contains('dependency: "direct main"'),
    );
    expect(_lockPackageBlock(lockfile, 'gal'), contains('version: "2.3.2"'));
    expect(
      _lockPackageBlock(lockfile, 'vector_graphics'),
      contains('dependency: "direct main"'),
    );
    expect(
      _lockPackageBlock(lockfile, 'vector_graphics'),
      contains('version: "1.2.4"'),
    );
  });
}

String _plistString(String plist, String key) {
  final matches = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]*)</string>',
  ).allMatches(plist).toList();
  expect(matches, hasLength(1), reason: '$key must appear exactly once');
  return matches.single.group(1)!.trim();
}

String _pubspecDependencies(String pubspec) {
  final start = pubspec.indexOf('dependencies:\n');
  final end = pubspec.indexOf('\ndev_dependencies:\n', start);
  expect(start, greaterThanOrEqualTo(0));
  expect(end, greaterThan(start));
  return pubspec.substring(start, end);
}

String _lockPackageBlock(String lockfile, String package) {
  final startToken = '  $package:\n';
  final start = lockfile.indexOf(startToken);
  expect(start, greaterThanOrEqualTo(0), reason: '$package must be locked');
  final following = RegExp(
    r'^  [a-zA-Z0-9_]+:',
    multiLine: true,
  ).allMatches(lockfile, start + startToken.length);
  final end = following.isEmpty ? lockfile.length : following.first.start;
  return lockfile.substring(start, end);
}
