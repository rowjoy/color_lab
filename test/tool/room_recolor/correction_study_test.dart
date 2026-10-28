import 'dart:convert';
import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/room_recolor/correction_study.dart';

// Synthetic bookkeeping fixtures only; these do not establish human evidence.
CorrectionFinalMask finalMask() => CorrectionFinalMask.score(
  ownership: MaskBitmap(
    width: 2,
    height: 1,
    labels: Uint8List.fromList([1, 0]),
  ),
  effectiveCoverage: Uint8List.fromList([1, 0]),
  groundTruthOwnership: MaskBitmap(
    width: 2,
    height: 1,
    labels: Uint8List.fromList([1, 0]),
  ),
  groundTruthProtection: Uint8List.fromList([0, 255]),
);

CorrectionStudySchedule baselineSchedule() => CorrectionStudySchedule(
  mode: CorrectionStudyMode.manualBaseline,
  manifestSha256: 'a' * 64,
  protocolSha256: roomCorrectionProtocolSha256,
  registrationSha256: 'b' * 64,
  photoGroundTruthSha256: {
    for (var i = 0; i < 24; i++) 'photo-$i': finalMask().groundTruthSha256,
  },
  assignments: [
    for (var p = 0; p < 8; p++)
      for (var j = 0; j < 6; j++)
        CorrectionStudyAssignment(
          id: 'a-$p-$j',
          photoId: 'photo-${(p * 3 + j) % 24}',
          participantId: 'p-$p',
          method: CorrectionMethod.manual,
          order: j + 1,
        ),
  ],
);

CorrectionStudySchedule comparisonSchedule({bool baselineMode = false}) =>
    CorrectionStudySchedule(
      mode: baselineMode
          ? CorrectionStudyMode.manualBaseline
          : CorrectionStudyMode.comparison,
      manifestSha256: 'a' * 64,
      protocolSha256: roomCorrectionProtocolSha256,
      registrationSha256: 'c' * 64,
      photoGroundTruthSha256: {
        for (var i = 0; i < 24; i++) 'photo-$i': finalMask().groundTruthSha256,
      },
      assignments: [
        for (var p = 0; p < 2; p++)
          for (var photo = 0; photo < 24; photo++)
            for (var turn = 0; turn < 2; turn++)
              CorrectionStudyAssignment(
                id: 'a-$p-$photo-$turn',
                photoId: 'photo-$photo',
                participantId: 'p-$p',
                method: (p + photo + turn).isEven
                    ? CorrectionMethod.manual
                    : CorrectionMethod.assisted,
                order: photo * 2 + turn + 1,
              ),
      ],
    );

CorrectionStudyRecord record(
  CorrectionStudyAssignment assignment, {
  int? start,
  int? end,
  String? hash,
  String? participant,
  int? order,
  CorrectionCompletion status = CorrectionCompletion.completed,
  String? reason,
  bool includeMask = true,
}) => CorrectionStudyRecord(
  assignmentId: assignment.id,
  photoId: assignment.photoId,
  participantId: participant ?? assignment.participantId,
  method: assignment.method,
  order: order ?? assignment.order,
  monotonicStartMilliseconds: start ?? assignment.order * 10000,
  monotonicEndMilliseconds:
      end ??
      assignment.order * 10000 +
          (assignment.method == CorrectionMethod.manual ? 1000 : 750),
  completion: status,
  exclusionReason: reason,
  deviceId: 'device-test',
  buildId: 'build-test',
  finalMaskSha256: hash ?? (includeMask ? finalMask().sha256 : null),
  finalMask: includeMask ? finalMask() : null,
);

CorrectionStudyValidation validate(
  CorrectionStudySchedule schedule,
  List<CorrectionStudyRecord> records, {
  String? expectedHash,
}) => schedule.mode == CorrectionStudyMode.manualBaseline
    ? validateManualBaseline(
        schedule: schedule,
        records: records,
        expectedScheduleSha256: expectedHash ?? schedule.sha256,
      )
    : validateComparison(
        schedule: schedule,
        records: records,
        expectedScheduleSha256: expectedHash ?? schedule.sha256,
        expectedAmendmentSha256: 'c' * 64,
      );

void main() {
  test('reshaped masks cannot validate against frozen dimensions', () {
    final schedule = baselineSchedule();
    final assignment = schedule.assignments.first;
    final reshaped = CorrectionFinalMask.score(
      ownership: MaskBitmap(
        width: 1,
        height: 2,
        labels: Uint8List.fromList([1, 0]),
      ),
      effectiveCoverage: Uint8List.fromList([1, 0]),
      groundTruthOwnership: MaskBitmap(
        width: 1,
        height: 2,
        labels: Uint8List.fromList([1, 0]),
      ),
      groundTruthProtection: Uint8List.fromList([0, 255]),
    );
    final rows = schedule.assignments.map((a) => record(a)).toList();
    rows[0] = CorrectionStudyRecord(
      assignmentId: assignment.id,
      photoId: assignment.photoId,
      participantId: assignment.participantId,
      method: assignment.method,
      order: assignment.order,
      monotonicStartMilliseconds: 10000,
      monotonicEndMilliseconds: 11000,
      completion: CorrectionCompletion.completed,
      deviceId: 'device-test',
      buildId: 'build-test',
      finalMaskSha256: reshaped.sha256,
      finalMask: reshaped,
    );
    final result = validate(schedule, rows);
    expect(result.isValid, isFalse);
    expect(result.manualMedianMilliseconds, isNull);
    expect(result.errors.any((e) => e.contains('ground truth')), isTrue);
    expect(reshaped.sha256, isNot(finalMask().sha256));
    expect(reshaped.groundTruthSha256, isNot(finalMask().groundTruthSha256));

    // Equal dimensions and payloads must still distinguish artifact domains.
    final equalPayloads = CorrectionFinalMask.score(
      ownership: MaskBitmap(
        width: 2,
        height: 1,
        labels: Uint8List.fromList([1, 0]),
      ),
      effectiveCoverage: Uint8List.fromList([0, 255]),
      groundTruthOwnership: MaskBitmap(
        width: 2,
        height: 1,
        labels: Uint8List.fromList([1, 0]),
      ),
      groundTruthProtection: Uint8List.fromList([0, 255]),
    );
    expect(equalPayloads.sha256, isNot(equalPayloads.groundTruthSha256));
  });

  test(
    'frozen 8 by 6 manual baseline reports 48 completions and honest median',
    () {
      final schedule = baselineSchedule();
      final result = validate(
        schedule,
        schedule.assignments.map((a) => record(a)).toList(),
      );
      expect(result.errors, isEmpty);
      expect(result.isComplete, isTrue);
      expect(result.completedManual, 48);
      expect(result.completedAssisted, 0);
      expect(result.manualMedianMilliseconds, 1000);
      expect(result.assistedMedianMilliseconds, isNull);
      expect(result.comparisonReady, isFalse);
    },
  );

  test(
    'separately registered paired comparison covers both methods on every photo',
    () {
      final schedule = comparisonSchedule();
      final rows = schedule.assignments.map((a) => record(a)).toList();
      final result = validate(schedule, rows);
      expect(result.errors, isEmpty);
      expect(result.comparisonReady, isTrue);
      expect(result.completedManual, 48);
      expect(result.completedAssisted, 48);
      expect(result.manualMedianMilliseconds, 1000);
      expect(result.assistedMedianMilliseconds, 750);
      expect(
        jsonEncode(result.toJson()),
        jsonEncode(validate(schedule, rows.reversed.toList()).toJson()),
      );
      expect(result.toJson()['records'], hasLength(96));
    },
  );

  for (final defect in [
    'duplicate',
    'duration-zero',
    'duration-negative',
    'negative-start',
    'overlap',
    'hash',
    'missing-mask',
    'participant',
    'order',
    'registration',
    'missing-row',
    'ground-truth',
  ]) {
    test('invalid $defect cannot contribute a median', () {
      final schedule = baselineSchedule();
      final rows = schedule.assignments.map((a) => record(a)).toList();
      final first = schedule.assignments.first;
      switch (defect) {
        case 'duplicate':
          rows.add(rows.first);
        case 'duration-zero':
          rows[0] = record(first, end: 10000);
        case 'duration-negative':
          rows[0] = record(first, end: 9999);
        case 'negative-start':
          rows[0] = record(first, start: -1);
        case 'overlap':
          rows[1] = record(schedule.assignments[1], start: 10001);
        case 'hash':
          rows[0] = record(first, hash: 'f' * 64);
        case 'missing-mask':
          rows[0] = record(first, includeMask: false);
        case 'participant':
          rows[0] = record(first, participant: 'Jane Doe');
        case 'order':
          rows[0] = record(first, order: 2);
        case 'missing-row':
          rows.removeLast();
        case 'registration':
          break;
        case 'ground-truth':
          final wrong = CorrectionFinalMask.score(
            ownership: MaskBitmap(
              width: 2,
              height: 1,
              labels: Uint8List.fromList([1, 0]),
            ),
            effectiveCoverage: Uint8List.fromList([1, 0]),
            groundTruthOwnership: MaskBitmap(
              width: 2,
              height: 1,
              labels: Uint8List.fromList([0, 0]),
            ),
            groundTruthProtection: Uint8List.fromList([0, 255]),
          );
          rows[0] = CorrectionStudyRecord(
            assignmentId: first.id,
            photoId: first.photoId,
            participantId: first.participantId,
            method: first.method,
            order: first.order,
            monotonicStartMilliseconds: 10000,
            monotonicEndMilliseconds: 11000,
            completion: CorrectionCompletion.completed,
            deviceId: 'device-test',
            buildId: 'build-test',
            finalMaskSha256: wrong.sha256,
            finalMask: wrong,
          );
      }
      final result = validate(
        schedule,
        rows,
        expectedHash: defect == 'registration' ? 'd' * 64 : null,
      );
      expect(result.isValid, isFalse);
      expect(result.errors, isNotEmpty);
      expect(result.manualMedianMilliseconds, isNull);
      expect(result.assistedMedianMilliseconds, isNull);
    });
  }

  test(
    'dropouts stay separate and cannot silently improve completed median',
    () {
      final schedule = baselineSchedule();
      final rows = schedule.assignments.map((a) => record(a)).toList();
      rows[0] = record(
        schedule.assignments.first,
        status: CorrectionCompletion.incomplete,
        reason: 'participant stopped',
        includeMask: false,
      );
      rows[1] = record(
        schedule.assignments[1],
        status: CorrectionCompletion.excluded,
        reason: 'interrupted',
        includeMask: false,
      );
      final result = validate(schedule, rows);
      expect(result.isValid, isTrue);
      expect(result.isComplete, isFalse);
      expect(result.completedManual, 46);
      expect(result.incomplete, 1);
      expect(result.excluded, 1);
      expect(result.manualMedianMilliseconds, isNull);
      rows[0] = record(
        schedule.assignments.first,
        status: CorrectionCompletion.incomplete,
        includeMask: false,
      );
      expect(validate(schedule, rows).isValid, isFalse);
    },
  );

  test(
    'baseline cannot be reused as comparison and assisted rows fail baseline',
    () {
      final baseline = baselineSchedule();
      final rows = baseline.assignments.map((a) => record(a)).toList();
      expect(
        validateComparison(
          schedule: baseline,
          records: rows,
          expectedScheduleSha256: baseline.sha256,
          expectedAmendmentSha256: 'c' * 64,
        ).comparisonReady,
        isFalse,
      );
      final mixed = comparisonSchedule(baselineMode: true);
      expect(
        validate(
          mixed,
          mixed.assignments.map((a) => record(a)).toList(),
        ).isValid,
        isFalse,
      );
    },
  );

  test('missing comparison coverage and unfrozen changed schedules fail', () {
    final complete = comparisonSchedule();
    for (final assignments in [
      complete.assignments
          .where((a) => a.method == CorrectionMethod.manual)
          .toList(),
      complete.assignments.where((a) => a.photoId != 'photo-23').toList(),
      [...complete.assignments, complete.assignments.first],
    ]) {
      final changed = CorrectionStudySchedule(
        mode: CorrectionStudyMode.comparison,
        manifestSha256: complete.manifestSha256,
        protocolSha256: complete.protocolSha256,
        registrationSha256: complete.registrationSha256,
        photoGroundTruthSha256: complete.photoGroundTruthSha256,
        assignments: assignments,
      );
      final result = validate(
        changed,
        assignments.map((a) => record(a)).toList(),
        expectedHash: complete.sha256,
      );
      expect(result.comparisonReady, isFalse);
      expect(result.errors, isNotEmpty);
    }
  });

  test('even-count median uses the central pair rather than a percentile', () {
    final schedule = baselineSchedule();
    final rows = [
      for (var i = 0; i < schedule.assignments.length; i++)
        record(
          schedule.assignments[i],
          end: schedule.assignments[i].order * 10000 + (i < 24 ? 100 : 300),
        ),
    ];
    expect(validate(schedule, rows).manualMedianMilliseconds, 200);
  });

  test(
    'counterbalance is checked even if malformed schedule hash is supplied',
    () {
      final original = comparisonSchedule();
      final assignments = [
        for (final a in original.assignments)
          CorrectionStudyAssignment(
            id: a.id,
            photoId: a.photoId,
            participantId: a.participantId,
            method: a.order.isOdd
                ? CorrectionMethod.manual
                : CorrectionMethod.assisted,
            order: a.order,
          ),
      ];
      final changed = CorrectionStudySchedule(
        mode: original.mode,
        manifestSha256: original.manifestSha256,
        protocolSha256: original.protocolSha256,
        registrationSha256: original.registrationSha256,
        photoGroundTruthSha256: original.photoGroundTruthSha256,
        assignments: assignments,
      );
      final result = validate(
        changed,
        assignments.map((a) => record(a)).toList(),
      );
      expect(result.isValid, isFalse);
      expect(result.errors.any((e) => e.contains('Unbalanced')), isTrue);
    },
  );

  test('a comparison with an unapproved amendment remains unusable', () {
    final schedule = comparisonSchedule();
    final result = validateComparison(
      schedule: schedule,
      records: schedule.assignments.map((a) => record(a)),
      expectedScheduleSha256: schedule.sha256,
      expectedAmendmentSha256: 'f' * 64,
    );
    expect(result.comparisonReady, isFalse);
    expect(result.manualMedianMilliseconds, isNull);
  });
}
