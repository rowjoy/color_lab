import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/room_recolor/manual_mask_benchmark.dart';

void main() {
  test('manual benchmark records literal bytes counts and injected clock without release claims', () async {
    var time = 0;
    final result = await runManualMaskBenchmark(
      device: const ManualMaskDevice(name: 'test simulator', platform: 'ios'),
      nowMicros: () => time += 10,
      width: 2, height: 2, strokes: 4,
    );
    expect(result.masks.labels, [1, 2, 3, 4]);
    expect(result.intent.bytes, [2, 3, 4, 5]);
    expect(result.commands, 4); expect(result.peakHistoryBytes, 32);
    final report = result.toJson();
    expect(report['ownershipIntentSha256'], sha256.convert([1, 2, 3, 4, 2, 3, 4, 5]).toString());
    expect(report['commandCommit'], {'count': 4, 'p50Micros': 10, 'p95Micros': 10});
    expect(report['pointerToVisibleFeedback'], isNull);
    expect(report['autosaveAcknowledgment'], isNull);
    expect(report['reopenRecoveryMicros'], isNull);
    expect(report['approvedFeedbackThresholdMicros'], isNull);
    expect(report['releaseGateSatisfied'], isFalse);
    expect((report['device'] as Map)['evidence'], 'non-release');
  });

  test('manual benchmark bounds whole history and reproduces checksum', () async {
    Future<ManualMaskBenchmarkReport> run() => runManualMaskBenchmark(
      device: const ManualMaskDevice(name: 'host', platform: 'linux'),
      nowMicros: () => 0, width: 8, height: 4,
    );
    final a = await run(); final b = await run();
    expect(a.commands, 24); expect(a.history.undoStack.length, 20);
    expect(a.peakHistoryBytes, 160);
    expect(a.toJson()['ownershipIntentSha256'], b.toJson()['ownershipIntentSha256']);
    expect(a.toJson()['historySha256'], b.toJson()['historySha256']);
    expect(ManualMaskBenchmarkReport.distribution([100, 10, 20, 30]),
      {'count': 4, 'p50Micros': 20, 'p95Micros': 100});
  });
}
