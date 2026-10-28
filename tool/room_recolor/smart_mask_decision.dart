import 'correction_study.dart';

const roomSmartMaskProtocolSha256 = roomCorrectionProtocolSha256;

/// These are external test/evidence assertions, never production enable flags.
/// A missing assertion is unknown, including when other evidence looks strong.
const smartMaskMandatorySafetyGates = <String>[
  'allSafetyAndReversibilityGatesPassed',
  'frozenCorpusApproved',
  'manualBaselineFrozen',
  'approvedAmendment',
  'previewDoesNotMutate',
  'cancelDoesNotMutate',
  'applyOneCommandOneAutosave',
  'staleProposalRejected',
  'undoRedoExact',
  'abstentionDoesNotMutate',
];

enum SmartMaskOutcome { pass, fail, insufficientEvidence }

/// Summary of scores on the same frozen 24 photos. Means are the unweighted
/// eligible layer-image IoU and per-image protected leakage from quality_metrics.
/// This report cannot establish that people/provenance assertions are truthful.
final class SmartMaskQualityEvidence {
  SmartMaskQualityEvidence({
    required this.manifestSha256,
    required this.protocolSha256,
    required List<String> photoIds,
    required this.meanIou,
    required this.meanProtectedLeakage,
  }) : photoIds = List.unmodifiable(photoIds);
  final String manifestSha256;
  final String protocolSha256;
  final List<String> photoIds;
  final double? meanIou;
  final double? meanProtectedLeakage;
  bool get _valid =>
      RegExp(r'^[0-9a-f]{64}$').hasMatch(manifestSha256) &&
      protocolSha256 == roomSmartMaskProtocolSha256 &&
      photoIds.length == 24 &&
      photoIds.toSet().length == 24 &&
      photoIds.every(
        (id) => RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]*$').hasMatch(id),
      ) &&
      _ratio(meanIou) &&
      _ratio(meanProtectedLeakage);
}

final class SmartMaskDecision {
  SmartMaskDecision._({
    required Map<String, bool?> rules,
    required Map<String, bool?> stretch,
    required this.iouDelta,
    required this.leakageDelta,
    required this.timeReduction,
    required this.relativeLeakageReduction,
  }) : rules = Map.unmodifiable(rules),
       stretch = Map.unmodifiable(stretch);

  static SmartMaskDecision evaluate({
    required SmartMaskQualityEvidence? baseline,
    required SmartMaskQualityEvidence? candidate,
    required CorrectionStudyValidation? study,
    required Map<String, bool?> safetyGates,
  }) {
    final comparable =
        baseline != null &&
        candidate != null &&
        study != null &&
        baseline._valid &&
        candidate._valid &&
        baseline.manifestSha256 == candidate.manifestSha256 &&
        baseline.manifestSha256 == study.schedule.manifestSha256 &&
        baseline.protocolSha256 == study.schedule.protocolSha256 &&
        _samePhotos(baseline.photoIds, candidate.photoIds) &&
        _samePhotos(baseline.photoIds, study.schedule.photoIds);
    final bIou = comparable ? baseline.meanIou : null;
    final cIou = comparable ? candidate.meanIou : null;
    final bLeak = comparable ? baseline.meanProtectedLeakage : null;
    final cLeak = comparable ? candidate.meanProtectedLeakage : null;
    final ready = study?.comparisonReady == true;
    final manual = comparable && ready ? study.manualMedianMilliseconds : null;
    final assisted = comparable && ready
        ? study.assistedMedianMilliseconds
        : null;
    final timed =
        manual != null && assisted != null && manual > 0 && assisted > 0;
    return SmartMaskDecision._(
      rules: {
        for (final gate in smartMaskMandatorySafetyGates)
          gate: safetyGates[gate],
        'comparableFrozenQuality': comparable ? true : null,
        'preregisteredComparisonComplete': ready ? true : null,
        'baselineSuitability': bLeak != null && bLeak > 0 ? true : null,
        'medianCorrectionTimeImproves': timed ? assisted < manual : null,
        // Compare endpoints to avoid rounding an exact .80 -> .79 into a
        // regression greater than .01 when subtracting floating-point values.
        'meanIouRegressionAtMostOnePercentagePoint':
            bIou == null || cIou == null ? null : cIou >= bIou - .01,
        'protectedLeakageDoesNotWorsen': bLeak == null || cLeak == null
            ? null
            : cLeak <= bLeak,
      },
      stretch: {
        'timeReductionAtLeast25Percent': timed
            ? assisted <= manual * .75
            : null,
        'relativeLeakageReductionAtLeast10Percent':
            bLeak == null || cLeak == null || bLeak <= 0
            ? null
            : cLeak <= bLeak * .9,
      },
      iouDelta: bIou == null || cIou == null ? null : cIou - bIou,
      leakageDelta: bLeak == null || cLeak == null ? null : cLeak - bLeak,
      timeReduction: timed ? (manual - assisted) / manual : null,
      relativeLeakageReduction: bLeak == null || cLeak == null || bLeak <= 0
          ? null
          : (bLeak - cLeak) / bLeak,
    );
  }

  final Map<String, bool?> rules;
  final Map<String, bool?> stretch;
  final double? iouDelta;
  final double? leakageDelta;
  final double? timeReduction;
  final double? relativeLeakageReduction;
  SmartMaskOutcome get outcome => rules.values.any((v) => v == false)
      ? SmartMaskOutcome.fail
      : rules.values.any((v) => v == null)
      ? SmartMaskOutcome.insufficientEvidence
      : SmartMaskOutcome.pass;
  Map<String, Object?> toJson() => {
    'outcome': outcome.name,
    'mandatoryRules': rules,
    'stretchResults': stretch,
    'iouDelta': iouDelta,
    'protectedLeakageDelta': leakageDelta,
    'relativeTimeReduction': timeReduction,
    'relativeLeakageReduction': relativeLeakageReduction,
  };
}

bool _ratio(double? value) =>
    value != null && value.isFinite && value >= 0 && value <= 1;
bool _samePhotos(List<String> a, List<String> b) =>
    a.length == b.length &&
    a.toSet().containsAll(b) &&
    b.toSet().containsAll(a);
