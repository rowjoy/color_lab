import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/room_recolor/smart_mask_decision.dart';
import 'correction_study_test.dart' as fixtures;

SmartMaskDecision decide({
  double? baselineIou = .8,
  double? candidateIou = .79,
  double? baselineLeakage = .2,
  double? candidateLeakage = .18,
  Map<String, bool?>? gates,
  bool baselineOnly = false,
  bool missingStudy = false,
  bool missingQuality = false,
  String? manifest,
  int assistedDuration = 750,
}) {
  final schedule = baselineOnly
      ? fixtures.baselineSchedule()
      : fixtures.comparisonSchedule();
  final study = fixtures.validate(
    schedule,
    schedule.assignments
        .map(
          (a) => fixtures.record(
            a,
            end:
                a.order * 10000 +
                (a.method.name == 'assisted' ? assistedDuration : 1000),
          ),
        )
        .toList(),
  );
  return SmartMaskDecision.evaluate(
    baseline: SmartMaskQualityEvidence(
      manifestSha256: 'a' * 64,
      protocolSha256: roomSmartMaskProtocolSha256,
      photoIds: [for (var i = 0; i < 24; i++) 'photo-$i'],
      meanIou: baselineIou,
      meanProtectedLeakage: baselineLeakage,
    ),
    candidate: missingQuality
        ? null
        : SmartMaskQualityEvidence(
            manifestSha256: manifest ?? 'a' * 64,
            protocolSha256: roomSmartMaskProtocolSha256,
            photoIds: [for (var i = 0; i < 24; i++) 'photo-$i'],
            meanIou: candidateIou,
            meanProtectedLeakage: candidateLeakage,
          ),
    study: missingStudy ? null : study,
    safetyGates:
        gates ?? {for (final gate in smartMaskMandatorySafetyGates) gate: true},
  );
}

void main() {
  test(
    'mandatory gates pass at exact IoU allowance; stretch reported separately',
    () {
      final result = decide();
      expect(result.outcome, SmartMaskOutcome.pass);
      expect(result.rules.values, everyElement(isTrue));
      expect(result.stretch['timeReductionAtLeast25Percent'], isTrue);
      expect(
        result.stretch['relativeLeakageReductionAtLeast10Percent'],
        isTrue,
      );
      expect(result.timeReduction, .25);
      expect(result.iouDelta, closeTo(-.01, 1e-12));
      expect(jsonEncode(result.toJson()), jsonEncode(decide().toJson()));
    },
  );
  test(
    'stretch leakage is optional and leakage equality satisfies mandatory rule',
    () {
      final result = decide(candidateLeakage: .2, assistedDuration: 999);
      expect(result.outcome, SmartMaskOutcome.pass);
      expect(
        result.stretch['relativeLeakageReductionAtLeast10Percent'],
        isFalse,
      );
      expect(result.stretch['timeReductionAtLeast25Percent'], isFalse);
    },
  );
  test('equal or slower correction medians fail despite good quality', () {
    expect(decide(assistedDuration: 1000).outcome, SmartMaskOutcome.fail);
    expect(decide(assistedDuration: 1001).outcome, SmartMaskOutcome.fail);
  });
  for (final gate in smartMaskMandatorySafetyGates) {
    test('false safety gate $gate fails even when stretches succeed', () {
      expect(
        decide(
          gates: {
            for (final key in smartMaskMandatorySafetyGates) key: key != gate,
          },
        ).outcome,
        SmartMaskOutcome.fail,
      );
      expect(
        decide(
          gates: {
            for (final key in smartMaskMandatorySafetyGates)
              key: key == gate ? null : true,
          },
        ).outcome,
        SmartMaskOutcome.insufficientEvidence,
      );
    });
  }
  test('IoU loss beyond allowance and any leakage increase fail', () {
    expect(decide(candidateIou: .789999).outcome, SmartMaskOutcome.fail);
    expect(decide(candidateLeakage: .200001).outcome, SmartMaskOutcome.fail);
  });
  test(
    'null, nonfinite, out of range, incomparable, baseline-only evidence cannot pass',
    () {
      for (final result in [
        decide(candidateIou: null),
        decide(candidateLeakage: null),
        decide(baselineIou: null),
        decide(baselineLeakage: null),
        decide(candidateIou: double.nan),
        decide(candidateLeakage: double.infinity),
        decide(candidateIou: 1.1),
        decide(manifest: 'f' * 64),
        decide(gates: {}),
        decide(baselineOnly: true),
        decide(missingStudy: true),
        decide(missingQuality: true),
      ]) {
        expect(result.outcome, SmartMaskOutcome.insufficientEvidence);
        expect(() => jsonEncode(result.toJson()), returnsNormally);
      }
    },
  );
  test('zero leakage cannot manufacture a relative reduction', () {
    final result = decide(baselineLeakage: 0, candidateLeakage: 0);
    expect(result.stretch['relativeLeakageReductionAtLeast10Percent'], isNull);
    expect(result.outcome, SmartMaskOutcome.insufficientEvidence);
  });
}
