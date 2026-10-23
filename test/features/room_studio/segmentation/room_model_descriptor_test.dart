import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/features/room_studio/segmentation/raw_segmentation.dart';
import 'package:color_lab/features/room_studio/segmentation/room_model_descriptor.dart';
import 'package:color_lab/features/room_studio/segmentation/room_model_runner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../tool/verify_room_model.dart' as verifier;

Map<String, Object?> validDescriptor() => {
  'schemaVersion': 1,
  'sourceRevision': '404e4c284d01b1c9e415b09d7cf8aa0648c4015d',
  'sha256': 'da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c',
  'requiredOperators': [
    'CONV_2D:1',
    'DEPTHWISE_CONV_2D:2',
    'ADD:1',
    'AVERAGE_POOL_2D:1',
    'SPLIT:1',
    'CONCATENATION:1',
    'QUANTIZE:1',
    'RESIZE_BILINEAR:1',
    'ARG_MAX:1',
  ],
  'inputShape': [1, 512, 512, 3],
  'outputShape': [1, 512, 512],
  'inputType': 'uint8',
  'outputType': 'int32',
  'inputEncoding': 'rgbUint8',
  'channelMeans': [0, 0, 0],
  'channelStdDevs': [1, 1, 1],
  'inputScale': 0.007843137718737125,
  'inputZeroPoint': 128,
  'classCount': 32,
  'ignoredLabel': 0,
  'labelsById': {
    '0': 'unscored',
    '1': 'wall',
    '2': 'building',
    '3': 'sky',
    '4': 'floor',
    '5': 'tree',
    '6': 'ceiling',
    '7': 'road',
    '8': 'bed',
    '9': 'windowpane',
    '10': 'grass',
    '11': 'cabinet',
    '12': 'sidewalk',
    '13': 'person',
    '14': 'earth',
    '15': 'door',
    '16': 'table',
    '17': 'mountain',
    '18': 'plant',
    '19': 'curtain',
    '20': 'chair',
    '21': 'car',
    '22': 'water',
    '23': 'painting',
    '24': 'sofa',
    '25': 'shelf',
    '26': 'house',
    '27': 'sea',
    '28': 'mirror',
    '29': 'rug',
    '30': 'field',
    '31': 'armchair',
  },
};

void main() {
  test('resolves original ADE classes without shifting zero or furniture', () {
    final d = RoomModelDescriptor.fromMap(validDescriptor());
    expect(d.schemaVersion, 1);
    expect(
      [d.inputWidth, d.inputHeight, d.outputWidth, d.outputHeight],
      [512, 512, 512, 512],
    );
    expect(d.inputType, RoomTensorType.uint8);
    expect(d.outputType, RoomTensorType.int32);
    expect(d.inputEncoding, RoomInputEncoding.rgbUint8);
    expect(
      [
        'wall',
        'ceiling',
        'floor',
        'bed',
        'cabinet',
        'table',
        'chair',
        'sofa',
        'windowpane',
        'door',
        'armchair',
      ].map(d.idForName),
      [1, 6, 4, 8, 11, 16, 20, 24, 9, 15, 31],
    );
    expect(d.ignoredLabel, 0);
    expect(d.classCount, 32);
    expect(() => d.idForName('unknown'), throwsFormatException);
  });

  final malformed = <String, Object?>{
    'schemaVersion': 99,
    'sourceRevision': '',
    'sha256': 'not-a-sha',
    'requiredOperators': ['CUSTOM:1'],
    'inputShape': [1, 256, 512, 3],
    'outputShape': [1, 512, 512, 32],
    'inputType': 'float32',
    'outputType': 'float32',
    'inputEncoding': 'normalized',
    'channelMeans': [127.5, 127.5, 127.5],
    'channelStdDevs': [1, double.nan, 1],
    'inputScale': 0.5,
    'inputZeroPoint': 127,
    'classCount': 151,
    'ignoredLabel': 1,
  };
  for (final entry in malformed.entries) {
    test('rejects incompatible ${entry.key}', () {
      expect(
        () => RoomModelDescriptor.fromMap(
          validDescriptor()..[entry.key] = entry.value,
        ),
        throwsFormatException,
      );
    });
  }
  test('rejects incomplete, duplicate, shifted and mistyped labels', () {
    for (final map in [
      validDescriptor()..remove('inputScale'),
      validDescriptor()..['inputZeroPoint'] = 128.5,
      validDescriptor()..['inputShape'] = [1, 512.0, 512, 3],
      validDescriptor()..['labelsById'] = {'0': 'unscored'},
      validDescriptor()
        ..['labelsById'] = {for (var i = 0; i < 32; i++) '$i': 'wall'},
      validDescriptor()
        ..['labelsById'] = {
          ...validDescriptor()['labelsById'] as Map,
          '1': 'floor',
          '4': 'wall',
        },
    ]) {
      expect(() => RoomModelDescriptor.fromMap(map), throwsFormatException);
    }
    expect(
      () => RoomModelDescriptor.fromMap({'schema': 99}),
      throwsFormatException,
    );
  });
  test('descriptor snapshots collections and exposes no mutable buffers', () {
    final map = validDescriptor();
    final d = RoomModelDescriptor.fromMap(map);
    (map['inputShape'] as List)[1] = 9;
    (map['labelsById'] as Map)['1'] = 'floor';
    expect(d.inputWidth, 512);
    expect(d.idForName('wall'), 1);
    expect(() => d.inputShape[1] = 9, throwsUnsupportedError);
    expect(() => d.outputShape[1] = 9, throwsUnsupportedError);
    expect(() => d.labelsById[1] = 'floor', throwsUnsupportedError);
    expect(() => d.requiredOperators.clear(), throwsUnsupportedError);
    expect(() => d.channelMeans[0] = 2, throwsUnsupportedError);
    expect(() => d.channelStdDevs[0] = 2, throwsUnsupportedError);
  });
  test('rejects floating-point values in integer-only metadata', () {
    for (final entry in {
      'schemaVersion': 1.0,
      'classCount': 32.0,
      'ignoredLabel': 0.0,
    }.entries) {
      expect(
        () => RoomModelDescriptor.fromMap(
          validDescriptor()..[entry.key] = entry.value,
        ),
        throwsFormatException,
      );
    }
  });
  test('raw output snapshots storage including byte-buffer views', () {
    final ids = Uint16List.fromList([0, 1, 4, 31]);
    final raw = RawSegmentation(width: 2, height: 2, classIds: ids);
    ids[1] = 20;
    expect(raw.classIds, [0, 1, 4, 31]);
    expect(() => raw.classIds[0] = 3, throwsUnsupportedError);
    expect(
      () => raw.classIds.buffer.asUint16List()[0] = 3,
      throwsUnsupportedError,
    );
  });
  test('raw output rejects invalid dimensions, lengths and class IDs', () {
    for (final dims in [(0, 2), (2, -1), (2, 2)]) {
      expect(
        () => RawSegmentation(
          width: dims.$1,
          height: dims.$2,
          classIds: Uint16List(3),
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => RawSegmentation(
        width: 1,
        height: 1,
        classIds: Uint16List.fromList([32]),
      ),
      throwsArgumentError,
    );
  });
  test('wrong model checksum fails before attempting native allocation', () {
    expect(
      () => TfliteRoomModelRunner(
        Uint8List(8),
        RoomModelDescriptor.fromMap(validDescriptor()),
      ),
      throwsFormatException,
    );
  });
  test(
    'bundled descriptor preserves the independently frozen label contract',
    () {
      final d = RoomModelDescriptor.fromMap(
        (jsonDecode(
                  File(
                    'assets/models/room_seg_descriptor.json',
                  ).readAsStringSync(),
                )
                as Map)
            .cast<String, Object?>(),
      );
      expect(
        d.labelsById,
        RoomModelDescriptor.fromMap(validDescriptor()).labelsById,
      );
      expect(d.sha256, validDescriptor()['sha256']);
    },
  );
  test(
    'native evidence gate rejects malformed dimensions and absent surfaces',
    () {
      expect(
        () => verifier.supportedSurfaceCounts(
          RawSegmentation(
            width: 1,
            height: 1,
            classIds: Uint16List.fromList([1]),
          ),
        ),
        throwsStateError,
      );
      expect(
        () => verifier.supportedSurfaceCounts(
          RawSegmentation(
            width: 512,
            height: 512,
            classIds: Uint16List(512 * 512),
          ),
        ),
        throwsStateError,
      );
    },
  );
}
