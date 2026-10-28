import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_room_recolor_benchmark.dart';
import 'room_recolor/benchmark_test.dart' show Corpus;

void main() {
  late Corpus corpus;
  late StringBuffer output;
  late StringBuffer errors;
  setUp(() {
    corpus = Corpus();
    output = StringBuffer();
    errors = StringBuffer();
  });
  tearDown(() => corpus.root.deleteSync(recursive: true));

  // Only synthetic temporary inputs exercise the verifier; these are never
  // genuine people, signatures, provenance, or releasable evidence.
  Map<String, dynamic> audit() => {
    'humanAuditStatus': 'approved',
    'decision': 'FROZEN_FOR_AMENDMENT',
    'manifestSha256': Corpus.hash(
      File('${corpus.root.path}/manifest.json').readAsBytesSync(),
    ),
    'protocolSha256':
        '9bb3b0f379054af42598deebb4cc8a90e1a3e3a3a5cb5821c9587fc1281c31fb',
    'reviewedAt': '2026-10-28T10:00:00Z',
    'acquisitionReviewerRoleId': 'test-reviewer',
    'productOwnerRoleId': 'test-owner',
    'externalAttestationSha256': 'a' * 64,
  };
  String saveAudit(Map<String, dynamic> value) {
    final file = File('${corpus.root.path}/human-audit.json')
      ..writeAsStringSync(jsonEncode(value));
    return file.path;
  }

  int verify({bool release = true, String? auditPath}) =>
      verifyRoomRecolorBenchmark(
        [
          '--root',
          corpus.root.path,
          if (release) '--require-adjudicated',
          if (auditPath != null) ...['--human-audit', auditPath],
        ],
        out: output,
        err: errors,
      );

  test('release rejects missing human audit despite automated acceptance', () {
    expect(verify(), 1);
    final report = jsonDecode(output.toString());
    expect(report['automatedValidationStatus'], 'PASS');
    expect(report['humanAuditStatus'], 'pending');
    expect(report['status'], 'PENDING HUMAN AUDIT');
    expect(errors.toString(), contains('human audit'));
  });
  for (final status in [null, 'pending', 'rejected']) {
    test('release rejects humanAuditStatus $status', () {
      final value = audit()..['humanAuditStatus'] = status;
      if (status == null) value.remove('humanAuditStatus');
      expect(verify(auditPath: saveAudit(value)), 1);
      expect(errors.toString(), contains('humanAuditStatus'));
    });
  }
  for (final field in [
    'manifestSha256',
    'protocolSha256',
    'externalAttestationSha256',
    'reviewedAt',
    'decision',
    'acquisitionReviewerRoleId',
    'productOwnerRoleId',
  ]) {
    test('release rejects absent audit $field', () {
      final value = audit()..remove(field);
      expect(verify(auditPath: saveAudit(value)), 1);
      expect(errors.toString(), contains(field));
    });
  }
  for (final field in ['manifestSha256', 'protocolSha256']) {
    test('release rejects audit bound to different $field', () {
      final value = audit()..[field] = '0' * 64;
      expect(verify(auditPath: saveAudit(value)), 1);
      expect(errors.toString(), contains(field));
    });
  }
  test('release report preserves all verified file hashes and coverage', () {
    final auditPath = saveAudit(audit());
    expect(verify(auditPath: auditPath), 0);
    expect(errors.toString(), isEmpty);
    final report = jsonDecode(output.toString()) as Map;
    expect(report['status'], 'PASS');
    expect(report['humanAuditStatus'], 'approved');
    expect(report['acceptedDistinctPhotos'], 24);
    expect(report['adjudicatedAnnotations'], true);
    expect(report['categories'], {
      'living-room': 6,
      'bedroom': 6,
      'kitchen-dining': 6,
      'other-indoor': 6,
    });
    expect(
      report['tags'],
      unorderedEquals([
        'people',
        'windows',
        'doors',
        'wall-decoration',
        'furniture-touching-walls',
        'low-contrast',
        'patterned',
        'daylight',
        'artificial-light',
        'shadows',
        'reflections',
      ]),
    );
    final hashes = report['fileSha256'] as Map;
    expect(hashes.length, 242); // protocol + manifest + 24 * (3 + 7).
    for (final entry in hashes.entries) {
      expect(
        entry.value,
        Corpus.hash(File('${corpus.root.path}/${entry.key}').readAsBytesSync()),
        reason: entry.key as String,
      );
    }
    expect(
      hashes.keys,
      containsAll([
        'protocol.json',
        'manifest.json',
        'licenses/photo-0.txt',
        'photos/photo-0/source.png',
        'photos/photo-0/working.png',
        for (final role in ['annotator-a', 'annotator-b', 'adjudicated'])
          for (final kind in ['ownership', 'protection'])
            'photos/photo-0/annotations/$role.$kind.bin',
        'photos/photo-0/annotations/adjudication.json',
      ]),
    );
    final first = (report['photos'] as List).first as Map;
    expect(
      first['sourceDecodedRgbaSha256'],
      corpus.photos.first['decodedRgbaSha256'],
    );
    expect(
      first['workingDecodedRgbaSha256'],
      corpus.photos.first['working']['decodedRgbaSha256'],
    );
    expect(
      report['humanAuditSha256'],
      Corpus.hash(File(auditPath).readAsBytesSync()),
    );
    expect(report['automatedValidationLimits'], contains('cannot prove'));
    expect(report['automatedValidationLimits'], contains('independence'));
    expect(report['automatedValidationLimits'], contains('provenance'));
    expect(report['baselineSuitability'], startsWith('NOT CHECKED'));
    expect(report['qualityMetricsStatus'], startsWith('NOT SCORED'));
    expect(report['correctionStudyStatus'], startsWith('NOT PROVIDED'));
    expect(report['smartMaskDecision']['outcome'], 'insufficientEvidence');
  });
  test('inspection reports pending audit and never a release PASS', () {
    expect(verify(release: false), 0);
    final report = jsonDecode(output.toString());
    expect(report['humanAuditStatus'], 'pending');
    expect(report['status'], 'INSPECTION ONLY');
  });
  test('approved audit cannot bypass missing adjudicated maps', () {
    (corpus.photos.first['annotations'] as Map).remove('adjudicated');
    corpus.save();
    expect(verify(auditPath: saveAudit(audit())), 1);
    expect(errors.toString(), contains('adjudicated'));
  });
  test(
    'human-audit option requires one path and rejects duplicate options',
    () {
      for (final args in [
        ['--root', corpus.root.path, '--human-audit'],
        ['--root', corpus.root.path, '--human-audit', '--require-adjudicated'],
        [
          '--root',
          corpus.root.path,
          '--human-audit',
          'a',
          '--human-audit',
          'b',
        ],
        ['--help'],
      ]) {
        expect(verifyRoomRecolorBenchmark(args, out: output, err: errors), 64);
      }
    },
  );
}
