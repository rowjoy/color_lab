import 'dart:convert';
import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:crypto/crypto.dart' as crypto;

import 'quality_metrics.dart';

const roomCorrectionProtocolSha256 =
    '9bb3b0f379054af42598deebb4cc8a90e1a3e3a3a5cb5821c9587fc1281c31fb';

enum CorrectionMethod { manual, assisted }

enum CorrectionCompletion { completed, incomplete, excluded }

enum CorrectionStudyMode { manualBaseline, comparison }

/// Identities hash a canonical JSON array of domain, width, height, base64
/// ownership and base64 effective coverage (or protection for ground truth).
/// Distinct versioned domains separate final masks from ground truth; dimensions
/// bind both identities to the frozen corpus coordinate system.
/// Scoring occurs here, at protocol-v1 tolerance, rather than trusting a supplied
/// metric JSON object. No photo bytes or participant identities are exported.
final class CorrectionFinalMask {
  CorrectionFinalMask._(
    this.width,
    this.height,
    this.sha256,
    this.groundTruthSha256,
    this.quality,
  );

  factory CorrectionFinalMask.score({
    required MaskBitmap ownership,
    required Uint8List effectiveCoverage,
    required MaskBitmap groundTruthOwnership,
    required Uint8List groundTruthProtection,
  }) {
    final quality = scoreRoomQuality(
      predictedOwnership: ownership,
      effectiveCoverage: effectiveCoverage,
      groundTruthOwnership: groundTruthOwnership,
      groundTruthProtection: groundTruthProtection,
    );
    for (var i = 0; i < groundTruthOwnership.pixelCount; i++) {
      if (groundTruthProtection[i] == 255 &&
          groundTruthOwnership.labels[i] != 0) {
        throw ArgumentError('Protected ground truth must have ownership zero');
      }
    }
    return CorrectionFinalMask._(
      ownership.width,
      ownership.height,
      _maskHash(
        'tintatlas.correction-final-mask.v1',
        ownership,
        effectiveCoverage,
      ),
      _maskHash(
        'tintatlas.correction-ground-truth.v1',
        groundTruthOwnership,
        groundTruthProtection,
      ),
      quality,
    );
  }

  final int width;
  final int height;
  final String sha256;
  final String groundTruthSha256;
  final RoomQualityMetrics quality;
  Map<String, Object?> toJson() => {
    'width': width,
    'height': height,
    'sha256': sha256,
    'groundTruthSha256': groundTruthSha256,
    'quality': quality.toJson(),
  };
}

final class CorrectionStudyAssignment {
  const CorrectionStudyAssignment({
    required this.id,
    required this.photoId,
    required this.participantId,
    required this.method,
    required this.order,
  });
  final String id;
  final String photoId;

  /// Numeric pseudonyms only (p-001, for example); consent/identity stays offline.
  final String participantId;
  final CorrectionMethod method;
  final int order;
  Map<String, Object?> toJson() => {
    'id': id,
    'photoId': photoId,
    'participantId': participantId,
    'method': method.name,
    'order': order,
  };
}

/// Supply the independently retained schedule digest to validation. Computing a
/// digest from today's rows is not proof of historical freezing/registration.
/// Baseline registration is separate from the later comparison amendment.
final class CorrectionStudySchedule {
  CorrectionStudySchedule({
    required this.mode,
    required this.manifestSha256,
    required this.protocolSha256,
    required this.registrationSha256,
    required Map<String, String> photoGroundTruthSha256,
    required List<CorrectionStudyAssignment> assignments,
  }) : photoGroundTruthSha256 = Map.unmodifiable(photoGroundTruthSha256),
       assignments = List.unmodifiable(assignments);
  final CorrectionStudyMode mode;
  final String manifestSha256;
  final String protocolSha256;
  final String registrationSha256;
  final Map<String, String> photoGroundTruthSha256;
  final List<CorrectionStudyAssignment> assignments;
  List<String> get photoIds => photoGroundTruthSha256.keys.toList()..sort();
  Map<String, Object?> toJson() {
    final sorted = assignments.toList()..sort((a, b) => a.id.compareTo(b.id));
    return {
      'mode': mode.name,
      'manifestSha256': manifestSha256,
      'protocolSha256': protocolSha256,
      'registrationSha256': registrationSha256,
      'photoGroundTruthSha256': {
        for (final id in photoIds) id: photoGroundTruthSha256[id],
      },
      'assignments': sorted.map((a) => a.toJson()).toList(),
    };
  }

  String get sha256 => _hash(utf8.encode(jsonEncode(toJson())));
}

final class CorrectionStudyRecord {
  const CorrectionStudyRecord({
    required this.assignmentId,
    required this.photoId,
    required this.participantId,
    required this.method,
    required this.order,
    required this.monotonicStartMilliseconds,
    required this.monotonicEndMilliseconds,
    required this.completion,
    required this.deviceId,
    required this.buildId,
    this.exclusionReason,
    this.finalMaskSha256,
    this.finalMask,
  });
  final String assignmentId;
  final String photoId;
  final String participantId;
  final CorrectionMethod method;
  final int order;
  final int monotonicStartMilliseconds;
  final int monotonicEndMilliseconds;
  final CorrectionCompletion completion;
  final String? exclusionReason;
  final String deviceId;
  final String buildId;
  final String? finalMaskSha256;
  final CorrectionFinalMask? finalMask;
  int get durationMilliseconds =>
      monotonicEndMilliseconds - monotonicStartMilliseconds;
  Map<String, Object?> toJson() => {
    'assignmentId': assignmentId,
    'photoId': photoId,
    'participantId': participantId,
    'method': method.name,
    'order': order,
    'monotonicStartMilliseconds': monotonicStartMilliseconds,
    'monotonicEndMilliseconds': monotonicEndMilliseconds,
    'durationMilliseconds': durationMilliseconds,
    'completion': completion.name,
    'exclusionReason': exclusionReason,
    'deviceId': deviceId,
    'buildId': buildId,
    'finalMaskSha256': finalMaskSha256,
    'finalMask': finalMask?.toJson(),
  };
}

final class CorrectionStudyValidation {
  CorrectionStudyValidation._(
    this.schedule,
    List<CorrectionStudyRecord> records,
    Iterable<String> errors,
  ) : records = List.unmodifiable(records..sort(_recordOrder)),
      errors = List.unmodifiable(errors.toSet().toList()..sort());
  final CorrectionStudySchedule schedule;
  final List<CorrectionStudyRecord> records;
  final List<String> errors;
  bool get isValid => errors.isEmpty;
  bool get isComplete =>
      isValid &&
      records.length == schedule.assignments.length &&
      records.every((r) => r.completion == CorrectionCompletion.completed);
  bool get comparisonReady =>
      isComplete && schedule.mode == CorrectionStudyMode.comparison;
  int get completedManual => _completed(CorrectionMethod.manual).length;
  int get completedAssisted => _completed(CorrectionMethod.assisted).length;
  int get excluded => records
      .where((r) => r.completion == CorrectionCompletion.excluded)
      .length;
  int get incomplete => records
      .where((r) => r.completion == CorrectionCompletion.incomplete)
      .length;
  Iterable<CorrectionStudyRecord> _completed(CorrectionMethod method) =>
      records.where(
        (r) =>
            r.method == method &&
            r.completion == CorrectionCompletion.completed,
      );
  double? _median(CorrectionMethod method) {
    // Do not let missing, invalid, excluded or dropout rows improve a decision.
    if (!isComplete) return null;
    final values = _completed(
      method,
    ).map((r) => r.durationMilliseconds).toList()..sort();
    if (values.isEmpty) return null;
    final mid = values.length ~/ 2;
    return values.length.isOdd
        ? values[mid].toDouble()
        : (values[mid - 1] + values[mid]) / 2;
  }

  double? get manualMedianMilliseconds => _median(CorrectionMethod.manual);
  double? get assistedMedianMilliseconds => _median(CorrectionMethod.assisted);
  Map<String, Object?> toJson() => {
    'mode': schedule.mode.name,
    'scheduleSha256': schedule.sha256,
    'manifestSha256': schedule.manifestSha256,
    'protocolSha256': schedule.protocolSha256,
    'registrationSha256': schedule.registrationSha256,
    'photoIds': schedule.photoIds,
    'isValid': isValid,
    'isComplete': isComplete,
    'comparisonReady': comparisonReady,
    'errors': errors,
    'completedManual': completedManual,
    'completedAssisted': completedAssisted,
    'excluded': excluded,
    'incomplete': incomplete,
    'manualMedianMilliseconds': manualMedianMilliseconds,
    'assistedMedianMilliseconds': assistedMedianMilliseconds,
    'records': records.map((r) => r.toJson()).toList(),
  };
}

CorrectionStudyValidation validateManualBaseline({
  required CorrectionStudySchedule schedule,
  required Iterable<CorrectionStudyRecord> records,
  required String expectedScheduleSha256,
}) => _validate(
  schedule,
  records,
  expectedScheduleSha256,
  CorrectionStudyMode.manualBaseline,
  null,
);

CorrectionStudyValidation validateComparison({
  required CorrectionStudySchedule schedule,
  required Iterable<CorrectionStudyRecord> records,
  required String expectedScheduleSha256,
  required String expectedAmendmentSha256,
}) => _validate(
  schedule,
  records,
  expectedScheduleSha256,
  CorrectionStudyMode.comparison,
  expectedAmendmentSha256,
);

CorrectionStudyValidation _validate(
  CorrectionStudySchedule schedule,
  Iterable<CorrectionStudyRecord> input,
  String expectedHash,
  CorrectionStudyMode requiredMode,
  String? amendment,
) {
  final rows = input.toList();
  final errors = <String>[];
  void require(bool ok, String message) {
    if (!ok) errors.add(message);
  }

  require(schedule.mode == requiredMode, 'Wrong study mode');
  require(
    _digest(expectedHash) && schedule.sha256 == expectedHash,
    'Schedule differs from frozen registration',
  );
  require(_digest(schedule.manifestSha256), 'Invalid manifest hash');
  require(
    schedule.protocolSha256 == roomCorrectionProtocolSha256,
    'Wrong immutable protocol hash',
  );
  require(_digest(schedule.registrationSha256), 'Missing registration hash');
  if (requiredMode == CorrectionStudyMode.comparison) {
    require(
      amendment != null &&
          _digest(amendment) &&
          schedule.registrationSha256 == amendment,
      'Comparison requires the separately preregistered amendment',
    );
  }
  require(
    schedule.photoGroundTruthSha256.length == 24 &&
        schedule.photoGroundTruthSha256.entries.every(
          (e) => _id(e.key) && _digest(e.value),
        ),
    'Exactly 24 frozen corpus photo and ground-truth hashes required',
  );
  final assignments = <String, CorrectionStudyAssignment>{};
  final participants = <String, List<CorrectionStudyAssignment>>{};
  for (final a in schedule.assignments) {
    require(
      _id(a.id) && _id(a.photoId) && _anonymous(a.participantId) && a.order > 0,
      'Invalid assignment identity or order: ${a.id}',
    );
    require(
      schedule.photoGroundTruthSha256.containsKey(a.photoId),
      'Unknown assigned photo: ${a.id}',
    );
    require(!assignments.containsKey(a.id), 'Duplicate assignment: ${a.id}');
    assignments[a.id] = a;
    (participants[a.participantId] ??= []).add(a);
  }
  for (final entry in participants.entries) {
    final orders = entry.value.map((a) => a.order).toList()..sort();
    require(
      List.generate(orders.length, (i) => i + 1).join(',') == orders.join(','),
      'Participant order must be unique and contiguous: ${entry.key}',
    );
  }
  if (requiredMode == CorrectionStudyMode.manualBaseline) {
    require(
      schedule.assignments.length == 48 &&
          participants.length == 8 &&
          participants.values.every(
            (v) => v.length == 6 && v.map((a) => a.photoId).toSet().length == 6,
          ),
      'Manual baseline requires 8 participants by 6 distinct rooms',
    );
    require(
      schedule.assignments.every((a) => a.method == CorrectionMethod.manual),
      'Manual baseline rejects assisted assignments',
    );
    for (final photo in schedule.photoIds) {
      final assigned = schedule.assignments
          .where((a) => a.photoId == photo)
          .toList();
      require(
        assigned.length == 2 &&
            assigned.map((a) => a.participantId).toSet().length == 2 &&
            assigned.map((a) => a.order).toSet().length == 2,
        'Baseline requires two independent, different-order sessions per photo: $photo',
      );
    }
  } else {
    // No fixed comparison sample size is invented here. The later amendment
    // supplies its exact schedule; both methods must be paired and balanced.
    for (final photo in schedule.photoIds) {
      final assigned = schedule.assignments.where((a) => a.photoId == photo);
      final manual = assigned
          .where((a) => a.method == CorrectionMethod.manual)
          .length;
      final assisted = assigned
          .where((a) => a.method == CorrectionMethod.assisted)
          .length;
      require(
        manual > 0 && manual == assisted,
        'Missing/broken method coverage: $photo',
      );
    }
    final firstByPhoto = <String, List<CorrectionMethod>>{};
    for (final entry in participants.entries) {
      final pairs = <String, List<CorrectionStudyAssignment>>{};
      for (final a in entry.value) {
        (pairs[a.photoId] ??= []).add(a);
      }
      final firstMethods = <CorrectionMethod>[];
      for (final pair in pairs.entries) {
        final values = pair.value..sort((a, b) => a.order.compareTo(b.order));
        require(
          values.length == 2 && values.map((a) => a.method).toSet().length == 2,
          'Comparison requires manual/assisted participant-photo pairs: ${entry.key}/${pair.key}',
        );
        firstMethods.add(values.first.method);
        (firstByPhoto[pair.key] ??= []).add(values.first.method);
      }
      require(_balanced(firstMethods), 'Unbalanced method order: ${entry.key}');
    }
    for (final photo in schedule.photoIds) {
      require(
        _balanced(firstByPhoto[photo] ?? []),
        'Unbalanced photo order: $photo',
      );
    }
  }

  final seen = <String>{};
  for (final row in rows) {
    final prefix = row.assignmentId;
    final a = assignments[prefix];
    require(seen.add(prefix), 'Duplicate record: $prefix');
    require(
      a != null &&
          a.photoId == row.photoId &&
          a.participantId == row.participantId &&
          a.method == row.method &&
          a.order == row.order,
      'Record differs from assignment: $prefix',
    );
    require(
      _anonymous(row.participantId) && _id(row.deviceId) && _id(row.buildId),
      'Anonymous participant/device/build IDs required: $prefix',
    );
    require(
      row.monotonicStartMilliseconds >= 0 && row.durationMilliseconds > 0,
      'Positive monotonic duration required: $prefix',
    );
    if (requiredMode == CorrectionStudyMode.manualBaseline) {
      require(
        row.method == CorrectionMethod.manual,
        'Assisted row in baseline: $prefix',
      );
    }
    if (row.completion == CorrectionCompletion.completed) {
      require(
        row.exclusionReason == null &&
            row.finalMask != null &&
            row.finalMaskSha256 != null,
        'Completed row requires final mask and no exclusion: $prefix',
      );
    } else {
      require(
        row.exclusionReason != null && row.exclusionReason!.trim().isNotEmpty,
        'Incomplete/excluded row requires reason: $prefix',
      );
    }
    final mask = row.finalMask;
    require(
      (mask == null && row.finalMaskSha256 == null) ||
          (mask != null &&
              _digest(row.finalMaskSha256 ?? '') &&
              row.finalMaskSha256 == mask.sha256),
      'Final mask hash mismatch: $prefix',
    );
    if (mask != null) {
      require(
        mask.groundTruthSha256 == schedule.photoGroundTruthSha256[row.photoId],
        'Final metrics use different frozen ground truth: $prefix',
      );
      require(
        mask.quality.protectedPixels > 0 && mask.quality.macroIou != null,
        'Final quality metrics lack eligible evidence: $prefix',
      );
    }
  }
  require(
    seen.length == assignments.length && assignments.keys.every(seen.contains),
    'Every registered assignment requires a completion or exclusion record',
  );
  for (final participant in participants.keys) {
    final ordered = rows.where((r) => r.participantId == participant).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    for (var i = 1; i < ordered.length; i++) {
      require(
        ordered[i].monotonicStartMilliseconds >=
            ordered[i - 1].monotonicEndMilliseconds,
        'Participant session times overlap or reverse: $participant',
      );
    }
  }
  return CorrectionStudyValidation._(schedule, rows, errors);
}

bool _balanced(List<CorrectionMethod> methods) =>
    methods.isNotEmpty &&
    methods.where((m) => m == CorrectionMethod.manual).length * 2 ==
        methods.length;
bool _anonymous(String id) => RegExp(r'^p-[0-9]+$').hasMatch(id);
bool _id(String id) => RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]*$').hasMatch(id);
bool _digest(String hash) => RegExp(r'^[0-9a-f]{64}$').hasMatch(hash);
String _hash(List<int> bytes) => crypto.sha256.convert(bytes).toString();
String _maskHash(String domain, MaskBitmap ownership, Uint8List secondary) =>
    _hash(
      utf8.encode(
        jsonEncode([
          domain,
          ownership.width,
          ownership.height,
          base64Encode(ownership.labels),
          base64Encode(secondary),
        ]),
      ),
    );
int _recordOrder(CorrectionStudyRecord a, CorrectionStudyRecord b) {
  final id = a.assignmentId.compareTo(b.assignmentId);
  return id == 0
      ? jsonEncode(a.toJson()).compareTo(jsonEncode(b.toJson()))
      : id;
}
