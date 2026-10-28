import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/features/room_studio/data/mask_edit_history_codec.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_edit_history.dart';
import 'package:color_lab/features/room_studio/domain/mask_intent_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_stroke.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/refine/mask_refinement.dart';
import 'package:crypto/crypto.dart';

final class ManualMaskDevice {
  const ManualMaskDevice({required this.name, required this.platform,
    this.physical = false, this.releaseBuild = false});
  final String name, platform;
  final bool physical, releaseBuild;
  Map<String, Object> toJson() => {
    'name': name, 'platform': platform, 'physical': physical,
    'releaseBuild': releaseBuild,
    'evidence': physical && releaseBuild && const ['android', 'ios'].contains(platform)
        ? 'physical-harness-only' : 'non-release',
  };
}

typedef ManualMaskRecovered = ({MaskBitmap masks, MaskIntentBitmap intent, MaskEditHistory history});

final class ManualMaskBenchmarkReport {
  ManualMaskBenchmarkReport({required this.device, required this.commands,
    required this.peakHistoryBytes, required this.masks, required this.intent,
    required this.history, required this.commitMicros, required this.saveMicros,
    required this.reopenMicros, required this.feedbackMicros});
  final ManualMaskDevice device;
  final int commands, peakHistoryBytes;
  final MaskBitmap masks;
  final MaskIntentBitmap intent;
  final MaskEditHistory history;
  final List<int> commitMicros, saveMicros, feedbackMicros;
  final int? reopenMicros;

  static Map<String, int>? distribution(List<int> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    int rank(double percentile) => sorted[(percentile * sorted.length).ceil() - 1];
    return {'count': values.length, 'p50Micros': rank(.5), 'p95Micros': rank(.95)};
  }

  Map<String, Object?> toJson() => {
    'protocol': 'manual-mask-v1',
    'device': device.toJson(),
    'width': masks.width, 'height': masks.height,
    'commands': commands, 'retainedCommands': history.undoStack.length + history.redoStack.length,
    'peakHistoryBytes': peakHistoryBytes,
    'ownershipIntentSha256': sha256.convert([...masks.labels, ...intent.bytes]).toString(),
    'historySha256': sha256.convert(MaskEditHistoryCodec.encode(history)).toString(),
    'commandCommit': distribution(commitMicros),
    'autosaveAcknowledgment': distribution(saveMicros),
    'pointerToVisibleFeedback': distribution(feedbackMicros),
    'reopenRecoveryMicros': reopenMicros,
    'feedbackSource': feedbackMicros.isEmpty ? 'unmeasured' : 'injected-ui-trace',
    'approvedFeedbackThresholdMicros': null,
    'releaseGateSatisfied': false,
  };
}

/// Synthetic correctness/storage harness. UI feedback can only come from an
/// actual instrumented pointer/render trace; command timing cannot substitute.
Future<ManualMaskBenchmarkReport> runManualMaskBenchmark({
  required ManualMaskDevice device,
  required int Function() nowMicros,
  int width = 64,
  int height = 64,
  int strokes = 24,
  Future<void> Function(MaskBitmap, MaskIntentBitmap, MaskEditHistory)? acknowledge,
  Future<ManualMaskRecovered> Function()? recover,
  List<int> feedbackMicros = const [],
}) async {
  if (strokes < 1 || strokes > 1000 || feedbackMicros.any((time) => time < 0)) {
    throw ArgumentError('Bounded strokes and nonnegative UI trace times required.');
  }
  var intent = MaskIntentBitmap.untouched(width: width, height: height);
  final ai = MaskBitmap(width: width, height: height, labels: Uint8List(width * height));
  var masks = ai;
  var history = MaskEditHistory.empty(width: width, height: height);
  final commits = <int>[]; final saves = <int>[];
  var commands = 0; var peak = 0;
  int elapsed(int started) {
    final duration = nowMicros() - started;
    if (duration < 0) throw StateError('The benchmark clock must be monotonic.');
    return duration;
  }
  for (var i = 0; i < strokes; i++) {
    final index = (i * 17) % masks.pixelCount;
    final start = nowMicros();
    final edit = applyMaskStroke(current: masks, ai: ai, intent: intent,
      stroke: MaskStroke(layer: RoomLayer.values[i % 4], mode: MaskEditMode.add,
        diameterFraction: .005,
        segments: [[MaskPoint(((index % width) + .5) / width, ((index ~/ width) + .5) / height)]]));
    if (edit.command == null) continue;
    masks = edit.masks; intent = edit.intent; history = history.push(edit.command!);
    commits.add(elapsed(start)); commands++;
    if (history.byteLength > peak) peak = history.byteLength;
    if (acknowledge != null) {
      final saveStart = nowMicros(); await acknowledge(masks, intent, history);
      saves.add(elapsed(saveStart));
    }
  }
  int? reopened;
  if (recover != null) {
    final start = nowMicros(); final recovered = await recover(); reopened = elapsed(start);
    bool same(List<int> a, List<int> b) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) { if (a[i] != b[i]) return false; }
      return true;
    }
    if (!same(masks.labels, recovered.masks.labels) || !same(intent.bytes, recovered.intent.bytes) ||
        !same(MaskEditHistoryCodec.encode(history), MaskEditHistoryCodec.encode(recovered.history))) {
      throw StateError('Recovery did not return the acknowledged exact mask state.');
    }
  }
  return ManualMaskBenchmarkReport(device: device, commands: commands,
    peakHistoryBytes: peak, masks: masks, intent: intent, history: history,
    commitMicros: List.unmodifiable(commits), saveMicros: List.unmodifiable(saves),
    reopenMicros: reopened, feedbackMicros: List.unmodifiable(feedbackMicros));
}

Future<void> main(List<String> arguments) async {
  final watch = Stopwatch()..start();
  final report = await runManualMaskBenchmark(
    device: ManualMaskDevice(name: 'unverified-host', platform: Platform.operatingSystem),
    nowMicros: () => watch.elapsedMicroseconds,
  );
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(report.toJson()));
}
