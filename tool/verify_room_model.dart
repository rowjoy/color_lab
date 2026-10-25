// Real-model acceptance executable. Run through run_room_model_smoke.dart.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/core/image/photo_processing.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/room_studio/segmentation/raw_segmentation.dart';
import 'package:color_lab/features/room_studio/segmentation/room_depth_runner.dart';
import 'package:color_lab/features/room_studio/segmentation/room_mask_processing.dart';
import 'package:color_lab/features/room_studio/segmentation/room_model_descriptor.dart';
import 'package:color_lab/features/room_studio/segmentation/room_model_runner.dart';
import 'package:color_lab/features/room_studio/segmentation/room_segmentation_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as image;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void rejects(void Function() operation, String label) {
  try {
    operation();
  } catch (_) {
    return;
  }
  throw StateError('$label was accepted');
}

/// Acceptance gate for this reference photo, never a fallback inference path.
Map<String, int> supportedSurfaceCounts(RawSegmentation raw) {
  check(raw.width == 512 && raw.height == 512, 'Output dimensions');
  final counts = <String, int>{
    'wall': 0,
    'ceiling': 0,
    'floor': 0,
    'furniture': 0,
  };
  for (var i = 0; i < 512 * 341; i++) {
    final layer = switch (raw.classIds[i]) {
      1 => 'wall',
      6 => 'ceiling',
      4 => 'floor',
      8 || 11 || 16 || 20 || 24 || 25 || 31 => 'furniture',
      _ => null,
    };
    if (layer != null) counts[layer] = counts[layer]! + 1;
  }
  for (final layer in counts.entries) {
    check(layer.value > 0, 'Missing supported surface: ${layer.key}');
  }
  return counts;
}

/// Optional private photo probe. Its image and outputs stay in system temp;
/// neither model predictions nor coverage percentages are ground truth.
Future<Map<String, Object?>?> verifyAdditionalPhoto(
  IsolateRoomSegmentationService service,
  Uint8List modelBytes,
  RoomModelDescriptor descriptor,
) async {
  final path = Platform.environment['COLOR_LAB_ROOM_TEST_PHOTO'];
  if (path == null) return null;
  final bytes = await File(path).readAsBytes();
  final photo = preparePhoto(bytes);
  final watch = Stopwatch()..start();
  final result = await service.analyze(
    photoId: 'private-photo-test',
    photo: photo,
  );
  watch.stop();
  final input = prepareRoomInput(photo, descriptor);
  final runner = TfliteRoomModelRunner(modelBytes, descriptor);
  final RawSegmentation raw;
  try {
    raw = runner.invoke(input.tensorBytes);
  } finally {
    runner.close();
  }
  final classes = <String, int>{};
  for (var y = 0; y < input.transform.contentHeight; y++) {
    for (var x = 0; x < input.transform.contentWidth; x++) {
      final id = raw.classIds[y * raw.width + x];
      final name = descriptor.labelsById[id]!;
      classes[name] = (classes[name] ?? 0) + 1;
    }
  }
  final directory = Directory.systemTemp.createTempSync(
    'color-lab-photo-evidence.',
  );
  final masks = result.masks;
  final baseline = postprocessRoomOutput(raw, input.transform, descriptor);
  final colors = <List<int>>[
    [0, 0, 0],
    [128, 80, 240],
    [240, 160, 40],
    [40, 180, 100],
    [40, 140, 240],
  ];
  for (final layer in RoomLayer.values) {
    final rgba = Uint8List.fromList(photo.rgbaBytes);
    for (var i = 0; i < masks.pixelCount; i++) {
      if (masks.labels[i] != layer.label) continue;
      for (var channel = 0; channel < 3; channel++) {
        final offset = i * 4 + channel;
        rgba[offset] = (rgba[offset] * .55 + colors[layer.label][channel] * .45)
            .round();
      }
    }
    final overlay = image.Image.fromBytes(
      width: photo.width,
      height: photo.height,
      bytes: rgba.buffer,
      numChannels: 4,
      order: image.ChannelOrder.rgba,
    );
    File(
      '${directory.path}/${layer.name}.png',
    ).writeAsBytesSync(image.encodePng(overlay));
  }
  File('${directory.path}/ownership.bin').writeAsBytesSync(masks.labels);
  final report = <String, Object?>{
    'status': 'PASS',
    'runtime': tfl.version,
    'photoSha256': sha256.convert(bytes).toString(),
    'width': masks.width,
    'height': masks.height,
    'modelSha256': descriptor.sha256,
    'depthModelSha256': roomDepthModelSha256,
    'maskSha256': sha256.convert(masks.labels).toString(),
    'layerPixels': {
      for (final layer in RoomLayer.values) layer.name: masks.count(layer),
    },
    'baselineLayerPixels': {
      for (final layer in RoomLayer.values) layer.name: baseline.count(layer),
    },
    'protectedWallPixels':
        baseline.count(RoomLayer.wall) - masks.count(RoomLayer.wall),
    'semanticClassPixels': classes,
    'elapsedMs': watch.elapsedMicroseconds / 1000,
    'groundTruthAvailable': false,
    'accuracy': null,
    'limitations':
        'Real-photo host inference and visual overlays, not measured segmentation accuracy or phone timing.',
    'evidenceDirectory': directory.path,
  };
  File('${directory.path}/report.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  return report;
}

Future<void> main() async {
  TfliteRoomModelRunner? runner;
  IsolateRoomSegmentationService? service;
  RoomModelStore? modelStore;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final descriptor = RoomModelDescriptor.fromMap(
      (jsonDecode(
                await rootBundle.loadString(
                  'assets/models/room_seg_descriptor.json',
                ),
              )
              as Map)
          .cast<String, Object?>(),
    );
    final bytes = await rootBundle.load('assets/models/room_seg.tflite');
    final model = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    final reference =
        (jsonDecode(
                  File(
                    'test/fixtures/room/model_reference.json',
                  ).readAsStringSync(),
                )
                as Map)
            .cast<String, Object?>();
    final input = File(
      'test/fixtures/room/reference_input.bin',
    ).readAsBytesSync();
    check(
      sha256.convert(input).toString() == reference['inputSha256'],
      'Reference input checksum mismatch',
    );
    rejects(
      () => TfliteRoomModelRunner(Uint8List(8), descriptor),
      'Corrupt model',
    );
    runner = TfliteRoomModelRunner(model, descriptor);
    final active = runner;
    rejects(() => active.invoke(Uint8List(3)), 'Wrong input length');
    final timer = Stopwatch()..start();
    final raw = active.invoke(input);
    timer.stop();
    check(raw.width == 512 && raw.height == 512, 'Output dimensions');
    final histogram = List<int>.filled(32, 0);
    final photoHistogram = List<int>.filled(32, 0);
    for (var i = 0; i < raw.classIds.length; i++) {
      final id = raw.classIds[i];
      check(id < 32, 'Out-of-range output ID $id');
      histogram[id]++;
      if (i < 512 * 341) photoHistogram[id]++;
    }
    final layers = supportedSurfaceCounts(raw);
    for (final anchor in reference['outputAnchors'] as List) {
      final a = anchor as Map;
      final actual = raw.classIds[(a['y'] as int) * 512 + (a['x'] as int)];
      check(
        actual == a['id'],
        'Reference anchor ${a['name']}: $actual != ${a['id']}',
      );
    }
    // Invoke again to prove returned snapshots survive native buffer reuse.
    final first = Uint16List.fromList(raw.classIds);
    active.invoke(Uint8List(input.length));
    check(
      raw.classIds.indexed.every((e) => e.$2 == first[e.$1]),
      'Output snapshot mutated',
    );
    active.close();
    active.close();
    rejects(() => active.invoke(input), 'Closed runner');
    final png = File('test/fixtures/room/reference_room.png').readAsBytesSync();
    check(
      sha256.convert(png).toString() == reference['pngSha256'],
      'Reference photo checksum mismatch',
    );
    final decoded = image.decodePng(png)!;
    final rgba = decoded.getBytes(order: image.ChannelOrder.rgba);
    final photo = PreparedPhoto(
      width: decoded.width,
      height: decoded.height,
      rgbaBytes: rgba,
      previewBytes: png,
      palette: const [],
    );
    // The CLI has no platform path_provider plugin. Seed a private temporary
    // cache with fixture bytes, then exercise the same verified-file factory
    // used by the app. No model asset is required in a production APK.
    final modelCache = Directory.systemTemp.createTempSync(
      'color-lab-model-cache.',
    );
    final verifyDownloads =
        Platform.environment['COLOR_LAB_VERIFY_MODEL_DOWNLOADS'] == '1';
    for (final artifact
        in verifyDownloads ? <RoomModelArtifact>[] : roomModelArtifacts) {
      final data = await rootBundle.load('assets/models/${artifact.name}');
      final file = File(
        '${modelCache.path}/room_models/${artifact.sha256}/${artifact.name}',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    }
    final cacheStore = RoomModelStore(
      directory: () async => modelCache,
      clientFactory: verifyDownloads
          ? null
          : () => throw StateError('Smoke must use verified offline fixtures'),
    );
    modelStore = cacheStore;
    service = IsolateRoomSegmentationService(
      workerFactory: () => createRoomSegmentationWorker(modelStore: cacheStore),
    );
    var heartbeatTicks = 0;
    final heartbeat = Timer.periodic(const Duration(milliseconds: 1), (_) {
      heartbeatTicks++;
    });
    final serviceTimer = Stopwatch()..start();
    late RoomSegmentationResult result;
    try {
      result = await service.analyze(
        photoId: 'task1-reference-room',
        photo: photo,
      );
    } finally {
      heartbeat.cancel();
      serviceTimer.stop();
    }
    check(
      heartbeatTicks > 0,
      'UI isolate did not progress during worker analysis',
    );
    check(result.photoId == 'task1-reference-room', 'Caller photo ID changed');
    final masks = result.masks;
    check(
      masks.width == 1280 && masks.height == 853,
      'Non-square working dimensions were lost',
    );
    // Independent inverse calculation from the frozen reference dimensions.
    // ADE0 has no pixels in this host reference, so closing cannot alter it.
    check(
      histogram[0] == 0,
      'Host alignment fixture unexpectedly contains ADE0',
    );
    final semanticMasks = postprocessRoomOutput(
      raw,
      prepareRoomInput(photo, descriptor).transform,
      descriptor,
    );
    var alignmentPixels = 0;
    var protectedWallPixels = 0;
    for (var y = 0; y < 853; y++) {
      final sy = (y * 340 / 852).round();
      for (var x = 0; x < 1280; x++) {
        final sx = (x * 511 / 1279).round();
        final expected = switch (raw.classIds[sy * 512 + sx]) {
          1 => 1,
          6 => 2,
          4 => 3,
          8 || 11 || 16 || 20 || 24 || 25 || 31 => 4,
          _ => 0,
        };
        check(
          semanticMasks.labels[y * 1280 + x] == expected,
          'Semantic mask alignment differs at $x,$y',
        );
        final protected = masks.labels[y * 1280 + x];
        check(
          expected == 1
              ? protected == 1 || protected == 0
              : protected == expected,
          'Depth protection changed a non-Wall owner at $x,$y',
        );
        if (expected == 1 && protected == 0) protectedWallPixels++;
        alignmentPixels++;
      }
    }
    for (final anchor in reference['outputAnchors'] as List) {
      final a = anchor as Map;
      final expected = switch (a['id']) {
        6 => 2,
        4 => 3,
        8 || 11 || 16 || 20 || 24 || 25 || 31 => 4,
        _ => 1,
      };
      check(
        masks.labels[(a['sourceY'] as int) * 1280 + (a['sourceX'] as int)] ==
            expected,
        'Working-photo reference anchor ${a['name']} differs',
      );
    }
    final maskCounts = <String, int>{
      for (final layer in RoomLayer.values) layer.name: masks.count(layer),
    };
    check(
      maskCounts.values.every((count) => count > 0),
      'Production service missed a known supported surface',
    );
    final cached = await service.analyze(
      photoId: 'new-caller-revision',
      photo: photo,
    );
    check(
      cached.photoId == 'new-caller-revision' && identical(cached.masks, masks),
      'Production service cache changed caller revision or masks',
    );
    final offlineStore = RoomModelStore(
      directory: () async => modelCache,
      clientFactory: () =>
          throw const SocketException('Cold cache must work offline'),
    );
    try {
      final offline = await offlineStore.load();
      check(
        sha256.convert(offline.semantic).toString() ==
            roomModelArtifacts[0].sha256,
        'Offline segmentation cache',
      );
      check(
        sha256.convert(offline.depth).toString() ==
            roomModelArtifacts[1].sha256,
        'Offline depth cache',
      );
    } finally {
      await offlineStore.close();
    }
    final additionalPhoto = await verifyAdditionalPhoto(
      service,
      model,
      descriptor,
    );
    await service.close();
    await service.close();
    try {
      await service.analyze(photoId: 'closed', photo: photo);
      throw StateError('Closed service accepted analysis');
    } on RoomSegmentationException catch (error) {
      check(
        error.kind == RoomSegmentationFailureKind.processing,
        'Closed service failure kind',
      );
    }
    // Owned scratch evidence only: source fixtures remain frozen.
    final diagnostics = Directory.systemTemp.createTempSync(
      'color-lab-task5-evidence.',
    );
    final maskFile = File('${diagnostics.path}/reference-room.labels.bin');
    maskFile.writeAsBytesSync(masks.labels, flush: true);
    final maskSha = sha256.convert(masks.labels).toString();
    final serviceEvidence = <String, Object?>{
      'status': 'PASS',
      'factory':
          'createRoomSegmentationWorker with verified offline model files',
      'runtime': tfl.version,
      'modelSource': verifyDownloads
          ? 'public fixed GitHub Release'
          : 'temporary seeded model cache',
      'coldOfflineCacheVerified': true,
      'descriptorAsset': 'assets/models/room_seg_descriptor.json',
      'modelSha256': descriptor.sha256,
      'depthModelSha256': roomDepthModelSha256,
      'protectedWallPixels': protectedWallPixels,
      'sourceRevision': descriptor.sourceRevision,
      'descriptorSha256': sha256
          .convert(
            utf8.encode(
              await rootBundle.loadString(
                'assets/models/room_seg_descriptor.json',
              ),
            ),
          )
          .toString(),
      'photoId': result.photoId,
      'photoSource': 'test/fixtures/room/reference_room.png',
      'photoPngSha256': sha256.convert(png).toString(),
      'photoRgbaSha256': sha256.convert(rgba).toString(),
      'preprocessInputSha256': reference['inputSha256'],
      'preprocess': reference['resize'],
      'inverse':
          'aligned corners nearest: round(x * 511 / 1279), round(y * 340 / 852)',
      'width': masks.width,
      'height': masks.height,
      'labels': {
        '0': 'unselected',
        '1': 'wall',
        '2': 'ceiling',
        '3': 'floor',
        '4': 'furniture',
      },
      'layerPixels': maskCounts,
      'unselectedPixels':
          masks.pixelCount - maskCounts.values.reduce((a, b) => a + b),
      'maskBytes': masks.labels.length,
      'maskSha256': maskSha,
      'maskPath': maskFile.path,
      'alignmentPixelsChecked': alignmentPixels,
      'uiHeartbeatTicks': heartbeatTicks,
      'elapsedMs': serviceTimer.elapsedMicroseconds / 1000,
      'limitations':
          'Host TFLite 2.11.0 evidence, not mobile validation or dense ground truth',
    };
    final evidenceFile = File(
      '${diagnostics.path}/reference-room.evidence.json',
    );
    evidenceFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(serviceEvidence)}\n',
      flush: true,
    );
    stdout.writeln(
      jsonEncode({
        'status': 'PASS',
        'runtime': tfl.version,
        'modelSha256': descriptor.sha256,
        'input': {
          'name': 'PreprocessedImageTensor',
          'type': descriptor.inputType.name,
          'shape': descriptor.inputShape,
          'bytes': input.length,
          'scale': descriptor.inputScale,
          'zeroPoint': descriptor.inputZeroPoint,
        },
        'output': {
          'name': 'SemanticPredictions',
          'type': descriptor.outputType.name,
          'shape': descriptor.outputShape,
          'elements': raw.classIds.length,
        },
        'histogramAll512': histogram,
        'histogramPhotoRegion': photoHistogram,
        'layerPixels': layers,
        'elapsedMs': timer.elapsedMicroseconds / 1000,
        'productionService': serviceEvidence,
        'additionalPhoto': ?additionalPhoto,
        'diagnostics': evidenceFile.path,
        'checks': [
          'staged reference fixtures and verified model files',
          'actual production runner',
          'corrupt model',
          'input length',
          'class domain',
          'four surfaces',
          'independent anchors',
          'snapshot',
          'idempotent close',
          'closed use',
          'production factory and verified offline model files',
          'real isolate production pipeline',
          'non-square dense aligned-corner inverse',
          'depth protection changes Wall to unselected only',
          'working-photo independent reference anchors',
          'production service cache and safe close',
        ],
      }),
    );
    await stdout.flush();
    exit(0);
  } catch (error, stack) {
    stderr.writeln('ROOM MODEL FAILED: $error\n$stack');
    exitCode = 1;
  } finally {
    await service?.close();
    await modelStore?.close();
    runner?.close();
  }
  await stderr.flush();
  exit(1);
}
