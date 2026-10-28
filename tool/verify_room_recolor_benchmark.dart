import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'room_recolor/benchmark.dart';
import 'room_recolor/smart_mask_decision.dart';

void main(List<String> arguments) {
  exitCode = verifyRoomRecolorBenchmark(arguments, out: stdout, err: stderr);
}

/// Validates evidence without creating or repairing a corpus. Release mode
/// requires both adjudicated annotations and a separately retained human audit.
/// The audit is a human assertion, not proof supplied by this program.
int verifyRoomRecolorBenchmark(
  List<String> arguments, {
  required StringSink out,
  required StringSink err,
}) {
  String? root;
  String? humanAuditPath;
  var adjudicated = false;
  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--root':
      case '--human-audit':
        final option = arguments[i];
        if ((option == '--root' ? root : humanAuditPath) != null ||
            i + 1 == arguments.length ||
            arguments[i + 1].startsWith('--')) {
          return _usage(err);
        }
        final path = arguments[++i];
        if (option == '--root') {
          root = path;
        } else {
          humanAuditPath = path;
        }
      case '--require-adjudicated':
        if (adjudicated) return _usage(err);
        adjudicated = true;
      default:
        return _usage(err);
    }
  }
  if (root == null) return _usage(err);
  try {
    final benchmark = loadRoomRecolorBenchmark(
      Directory(root),
      requireAdjudicatedAnnotations: adjudicated,
    );
    // Report references from the exact validated manifest, not a later revision.
    final manifestBytes = File('$root/manifest.json').readAsBytesSync();
    if (_hash(manifestBytes) != benchmark.manifestSha256) {
      throw const FormatException('Manifest changed during verification');
    }
    final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map;
    final fileHashes = <String, String>{
      'protocol.json': benchmark.protocolSha256,
      'manifest.json': benchmark.manifestSha256,
    };
    void record(Map ref) {
      final path = ref['path'] as String;
      final hash = ref['sha256'] as String;
      if (fileHashes.containsKey(path) && fileHashes[path] != hash) {
        throw FormatException('Conflicting verified file hashes: $path');
      }
      fileHashes[path] = hash;
    }

    for (final photo in manifest['photos'] as List) {
      record(photo['provenance']['licenseText'] as Map);
      record(photo['source'] as Map);
      record(photo['working'] as Map);
      final annotations = photo['annotations'] as Map?;
      if (annotations != null) {
        for (final role in ['annotator-a', 'annotator-b', 'adjudicated']) {
          for (final kind in ['ownership', 'protection']) {
            record(annotations[role][kind] as Map);
          }
        }
        record(annotations['adjudication'] as Map);
      }
    }
    final audit = humanAuditPath == null
        ? null
        : _readHumanAudit(humanAuditPath, benchmark);
    final humanAuditStatus = audit == null ? 'pending' : 'approved';
    final pendingAudit = adjudicated && audit == null;
    final categories = benchmark.photos.map((p) => p.category).toSet().toList()
      ..sort();
    final tags = benchmark.photos.expand((p) => p.tags).toSet().toList()
      ..sort();
    final paths = fileHashes.keys.toList()..sort();
    out.writeln(
      jsonEncode({
        'status': pendingAudit
            ? 'PENDING HUMAN AUDIT'
            : adjudicated
            ? 'PASS'
            : 'INSPECTION ONLY',
        'automatedValidationStatus': 'PASS',
        'humanAuditStatus': humanAuditStatus,
        if (audit != null) ...audit,
        'automatedValidationLimits':
            'Automated validation cannot prove lawful provenance, actual human '
            'identities, independence, blindness, faithful source preparation, '
            'representative tags, or absence of near duplicates. An approved '
            'audit is an external human attestation, not machine proof.',
        'acceptedDistinctPhotos': benchmark.photos.length,
        'adjudicatedAnnotations': benchmark.hasAdjudicatedAnnotations,
        'manifestSha256': benchmark.manifestSha256,
        'protocolSha256': benchmark.protocolSha256,
        'fileSha256': {for (final path in paths) path: fileHashes[path]},
        'photos': [
          for (final photo in manifest['photos'] as List)
            {
              'id': photo['id'],
              'sourceDecodedRgbaSha256': photo['decodedRgbaSha256'],
              'workingDecodedRgbaSha256': photo['working']['decodedRgbaSha256'],
            },
        ],
        'categories': {
          for (final category in categories)
            category: benchmark.photos
                .where((p) => p.category == category)
                .length,
        },
        'tags': tags,
        'baselineSuitability':
            'NOT CHECKED: requires separately scored frozen baseline coverage',
        'qualityMetricsStatus':
            'NOT SCORED: corpus verification supplies no baseline or candidate masks',
        'correctionStudyStatus':
            'NOT PROVIDED: requires frozen manual baseline and later preregistered comparison',
        'smartMaskDecision': SmartMaskDecision.evaluate(
          baseline: null,
          candidate: null,
          study: null,
          safetyGates: const {},
        ).toJson(),
      }),
    );
    if (pendingAudit) {
      err.writeln(
        'ROOM RECOLOR BENCHMARK FAILED: approved human audit required',
      );
      return 1;
    }
    return 0;
  } on FormatException catch (error) {
    err.writeln('ROOM RECOLOR BENCHMARK FAILED: ${error.message}');
    return 1;
  } on FileSystemException {
    err.writeln(
      'ROOM RECOLOR BENCHMARK FAILED: missing or unreadable evidence',
    );
    return 1;
  }
}

Map<String, Object?> _readHumanAudit(
  String path,
  RoomRecolorBenchmark benchmark,
) {
  final bytes = File(path).readAsBytesSync();
  final value = jsonDecode(utf8.decode(bytes));
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Human audit must be an object');
  }
  void require(bool condition, String field) {
    if (!condition) throw FormatException('Invalid human audit $field');
  }

  require(value['humanAuditStatus'] == 'approved', 'humanAuditStatus');
  require(value['decision'] == 'FROZEN_FOR_AMENDMENT', 'decision');
  require(
    value['manifestSha256'] == benchmark.manifestSha256,
    'manifestSha256',
  );
  require(
    value['protocolSha256'] == benchmark.protocolSha256,
    'protocolSha256',
  );
  final reviewedAt = value['reviewedAt'];
  require(
    reviewedAt is String &&
        reviewedAt.endsWith('Z') &&
        DateTime.tryParse(reviewedAt) != null,
    'reviewedAt',
  );
  for (final field in ['acquisitionReviewerRoleId', 'productOwnerRoleId']) {
    final roleId = value[field];
    require(
      roleId is String &&
          RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]*$').hasMatch(roleId),
      field,
    );
  }
  final checksum = value['externalAttestationSha256'];
  require(
    checksum is String && RegExp(r'^[0-9a-f]{64}$').hasMatch(checksum),
    'externalAttestationSha256',
  );
  // Copy only redacted audit metadata; never echo arbitrary owner-held fields.
  return {
    'humanAuditSha256': _hash(bytes),
    'humanAudit': {
      for (final field in [
        'decision',
        'reviewedAt',
        'acquisitionReviewerRoleId',
        'productOwnerRoleId',
        'externalAttestationSha256',
      ])
        field: value[field],
    },
  };
}

String _hash(List<int> bytes) => sha256.convert(bytes).toString();

int _usage(StringSink err) {
  err.writeln(
    'Usage: dart run tool/verify_room_recolor_benchmark.dart --root <directory> '
    '[--require-adjudicated] [--human-audit <redacted-audit.json>]\n'
    '--require-adjudicated is release mode: requires an approved human audit.\n'
    'Without it, results are inspection only and cannot freeze evidence.',
  );
  return 64;
}
