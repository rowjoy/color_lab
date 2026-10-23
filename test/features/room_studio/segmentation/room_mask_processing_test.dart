import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/core/image/photo_processing.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/segmentation/raw_segmentation.dart';
import 'package:color_lab/features/room_studio/segmentation/room_input.dart';
import 'package:color_lab/features/room_studio/segmentation/room_mask_processing.dart';
import 'package:color_lab/features/room_studio/segmentation/room_model_descriptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

final descriptor = RoomModelDescriptor.fromMap(
  (jsonDecode(File('assets/models/room_seg_descriptor.json').readAsStringSync())
          as Map)
      .cast<String, Object?>(),
);

PreparedPhoto photo(int width, int height, List<int> rgba) => PreparedPhoto(
  width: width,
  height: height,
  rgbaBytes: Uint8List.fromList(rgba),
  previewBytes: Uint8List(0),
  palette: const [],
);

RoomInputTransform transform({
  int sourceWidth = 512,
  int sourceHeight = 512,
  int contentWidth = 512,
  int contentHeight = 512,
  int paddingLeft = 0,
  int paddingTop = 0,
}) => RoomInputTransform(
  sourceWidth: sourceWidth,
  sourceHeight: sourceHeight,
  inputWidth: 512,
  inputHeight: 512,
  contentWidth: contentWidth,
  contentHeight: contentHeight,
  paddingLeft: paddingLeft,
  paddingTop: paddingTop,
);

RawSegmentation patch(List<List<int>> rows, {int x = 10, int y = 10}) {
  // Building (2) is a protected, unselected background, not ignored zero.
  final ids = Uint16List(512 * 512)..fillRange(0, 512 * 512, 2);
  for (var row = 0; row < rows.length; row++) {
    ids.setRange(
      (y + row) * 512 + x,
      (y + row) * 512 + x + rows[row].length,
      rows[row],
    );
  }
  return RawSegmentation(width: 512, height: 512, classIds: ids);
}

List<int> rgb(RoomInput input, int x, int y) =>
    input.tensorBytes.sublist((y * 512 + x) * 3, (y * 512 + x) * 3 + 3);

void main() {
  test('room input snapshots bytes including buffer views', () {
    final bytes = Uint8List.fromList([10, 20, 30]);
    final input = RoomInput(tensorBytes: bytes, transform: transform());
    bytes[0] = 99;
    expect(input.tensorBytes, [10, 20, 30]);
    expect(() => input.tensorBytes[0] = 99, throwsUnsupportedError);
    expect(
      () => input.tensorBytes.buffer.asUint8List()[0] = 99,
      throwsUnsupportedError,
    );
  });

  test('transform rejects nonpositive sizes and content outside input', () {
    final base = [2, 3, 512, 512, 341, 512, 0, 0];
    for (var index = 0; index < 6; index++) {
      for (final invalid in [0, -1]) {
        final values = [...base]..[index] = invalid;
        expect(
          () => RoomInputTransform(
            sourceWidth: values[0],
            sourceHeight: values[1],
            inputWidth: values[2],
            inputHeight: values[3],
            contentWidth: values[4],
            contentHeight: values[5],
            paddingLeft: values[6],
            paddingTop: values[7],
          ),
          throwsArgumentError,
        );
      }
    }
    for (final make in <RoomInputTransform Function()>[
      () => transform(paddingLeft: -1),
      () => transform(paddingTop: -1),
      () => transform(contentWidth: 513),
      () => transform(contentHeight: 513),
      () => transform(contentWidth: 512, paddingLeft: 1),
      () => transform(contentHeight: 512, paddingTop: 1),
    ]) {
      expect(make, throwsArgumentError);
    }
  });

  test('49 by 49 fit fills exactly 512 without a rounding padding strip', () {
    final rgba = Uint8List(49 * 49 * 4);
    for (var offset = 0; offset < rgba.length; offset += 4) {
      rgba.setRange(offset, offset + 4, [7, 8, 9, 255]);
    }
    final input = prepareRoomInput(photo(49, 49, rgba), descriptor);
    expect(
      [input.transform.contentWidth, input.transform.contentHeight],
      [512, 512],
    );
    expect(rgb(input, 511, 0), [7, 8, 9]);
    expect(rgb(input, 0, 511), [7, 8, 9]);
    expect(rgb(input, 511, 511), [7, 8, 9]);
  });

  test('wide fit keeps corners, truncates interpolation, pads bottom', () {
    final input = prepareRoomInput(
      photo(3, 2, [
        0,
        10,
        20,
        255,
        100,
        110,
        120,
        255,
        200,
        210,
        220,
        255,
        20,
        30,
        40,
        255,
        120,
        130,
        140,
        255,
        220,
        230,
        240,
        255,
      ]),
      descriptor,
    );
    final t = input.transform;
    expect(
      [
        t.sourceWidth,
        t.sourceHeight,
        t.inputWidth,
        t.inputHeight,
        t.contentWidth,
        t.contentHeight,
        t.paddingLeft,
        t.paddingTop,
      ],
      [3, 2, 512, 512, 512, 341, 0, 0],
    );
    expect(input.tensorBytes.length, 786432);
    expect(rgb(input, 0, 0), [0, 10, 20]);
    expect(rgb(input, 511, 0), [200, 210, 220]);
    expect(rgb(input, 0, 340), [20, 30, 40]);
    expect(rgb(input, 511, 340), [220, 230, 240]);
    expect(rgb(input, 255, 170), [109, 119, 129]);
    expect(rgb(input, 0, 341), [123, 115, 103]);
    expect(rgb(input, 511, 511), [123, 115, 103]);
  });

  test('tall fit pads right and keeps prepared row orientation', () {
    final input = prepareRoomInput(
      photo(2, 3, [
        10,
        0,
        0,
        255,
        20,
        0,
        0,
        255,
        30,
        0,
        0,
        255,
        40,
        0,
        0,
        255,
        50,
        0,
        0,
        255,
        60,
        0,
        0,
        255,
      ]),
      descriptor,
    );
    expect(
      [input.transform.contentWidth, input.transform.contentHeight],
      [341, 512],
    );
    expect(rgb(input, 0, 0), [10, 0, 0]);
    expect(rgb(input, 340, 0), [20, 0, 0]);
    expect(rgb(input, 0, 511), [50, 0, 0]);
    expect(rgb(input, 340, 511), [60, 0, 0]);
    expect(rgb(input, 341, 0), [123, 115, 103]);
  });

  test(
    'already baked EXIF orientation is consumed once at picker boundary',
    () {
      final source = image.Image(width: 32, height: 16);
      for (final pixel in source) {
        pixel.setRgb(pixel.x < 16 ? 255 : 0, 0, pixel.y < 8 ? 0 : 255);
      }
      source.exif.imageIfd.orientation = 6;
      final prepared = preparePhoto(image.encodeJpg(source, quality: 100));
      expect([prepared.width, prepared.height], [16, 32]);
      final input = prepareRoomInput(prepared, descriptor);
      expect(
        [input.transform.sourceWidth, input.transform.sourceHeight],
        [16, 32],
      );
      expect(rgb(input, 255, 0), [
        closeTo(255, 3),
        closeTo(0, 3),
        closeTo(0, 3),
      ]);
      expect(rgb(input, 0, 511), [
        closeTo(0, 3),
        closeTo(0, 3),
        closeTo(255, 3),
      ]);
    },
  );

  test('extreme fits clamp content to one and sample coordinate zero', () {
    for (final dims in [(1600, 1), (1, 1600), (1, 1)]) {
      final bytes = Uint8List(dims.$1 * dims.$2 * 4);
      bytes.setRange(0, 4, [7, 8, 9, 255]);
      bytes.setRange(bytes.length - 4, bytes.length, [70, 80, 90, 255]);
      final input = prepareRoomInput(
        photo(dims.$1, dims.$2, bytes),
        descriptor,
      );
      final t = input.transform;
      expect(
        [t.contentWidth, t.contentHeight],
        switch (dims) {
          (1600, 1) => [512, 1],
          (1, 1600) => [1, 512],
          _ => [512, 512],
        },
      );
      expect(rgb(input, 0, 0), dims == (1, 1) ? [70, 80, 90] : [7, 8, 9]);
      expect(rgb(input, t.contentWidth - 1, t.contentHeight - 1), [70, 80, 90]);
    }
  });

  test('preprocessing exactly matches independent Task1 RGB fixture', () {
    final decoded = image.decodePng(
      File('test/fixtures/room/reference_room.png').readAsBytesSync(),
    )!;
    final input = prepareRoomInput(
      photo(
        decoded.width,
        decoded.height,
        decoded.getBytes(order: image.ChannelOrder.rgba),
      ),
      descriptor,
    );
    expect(
      [input.transform.contentWidth, input.transform.contentHeight],
      [512, 341],
    );
    expect(
      input.tensorBytes,
      File('test/fixtures/room/reference_input.bin').readAsBytesSync(),
    );
    expect(rgb(input, 0, 0), [218, 199, 153]);
    expect(rgb(input, 511, 340), [33, 27, 17]);
    expect(rgb(input, 0, 341), [123, 115, 103]);
  });

  test('maps all original ADE IDs with shelf and armchair furniture', () {
    final masks = postprocessRoomOutput(
      patch([List<int>.generate(32, (index) => index)]),
      transform(
        sourceWidth: 32,
        sourceHeight: 1,
        contentWidth: 32,
        contentHeight: 1,
        paddingLeft: 10,
        paddingTop: 10,
      ),
      descriptor,
    );
    expect(masks.labels, [
      0,
      1,
      0,
      0,
      3,
      0,
      2,
      0,
      4,
      0,
      0,
      4,
      0,
      0,
      0,
      0,
      4,
      0,
      0,
      0,
      4,
      0,
      0,
      0,
      4,
      4,
      0,
      0,
      0,
      0,
      0,
      4,
    ]);
    expect(RoomLayer.values.map(masks.count), [1, 1, 1, 7]);
  });

  test('removes non-square padding and nearest maps working pixels', () {
    final masks = postprocessRoomOutput(
      patch(
        [
          [1, 6, 4],
          [8, 9, 15],
        ],
        x: 7,
        y: 9,
      ),
      transform(
        sourceWidth: 5,
        sourceHeight: 3,
        contentWidth: 3,
        contentHeight: 2,
        paddingLeft: 7,
        paddingTop: 9,
      ),
      descriptor,
    );
    expect([masks.width, masks.height], [5, 3]);
    expect(masks.labels, [1, 2, 2, 3, 3, 4, 0, 0, 0, 0, 4, 0, 0, 0, 0]);
  });

  test('inverse aligned corners recovers three source pixels from 512', () {
    final ids = Uint16List(512 * 512)..fillRange(0, 512 * 512, 2);
    ids[0] = 1;
    ids[256] = 6;
    ids[511] = 4;
    final masks = postprocessRoomOutput(
      RawSegmentation(width: 512, height: 512, classIds: ids),
      transform(sourceWidth: 3, sourceHeight: 1, contentHeight: 1),
      descriptor,
    );
    expect(masks.labels, [1, 2, 3]);
  });

  test('closing fills only ignored zero and protects door/window/person', () {
    final raw = patch([
      [1, 1, 1, 1, 1, 1, 1],
      [1, 0, 1, 9, 1, 15, 1],
      [1, 1, 1, 1, 1, 1, 1],
      [1, 13, 1, 0, 1, 0, 1],
      [1, 1, 1, 1, 1, 1, 1],
    ]);
    final masks = postprocessRoomOutput(
      raw,
      transform(
        sourceWidth: 7,
        sourceHeight: 5,
        contentWidth: 7,
        contentHeight: 5,
        paddingLeft: 10,
        paddingTop: 10,
      ),
      descriptor,
    );
    expect(masks.labels, [
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      0,
      1,
      0,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      0,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
      1,
    ]);
    expect(raw.classIds[11 * 512 + 11], 0);
  });

  test('shelf and armchair close gaps without selecting protected objects', () {
    final masks = postprocessRoomOutput(
      patch([
        [25, 25, 25, 25, 31, 31, 31],
        [25, 13, 25, 0, 31, 9, 31],
        [25, 25, 25, 25, 31, 31, 31],
        [31, 15, 31, 23, 25, 28, 25],
        [31, 31, 31, 31, 25, 25, 25],
      ]),
      transform(
        sourceWidth: 7,
        sourceHeight: 5,
        contentWidth: 7,
        contentHeight: 5,
        paddingLeft: 10,
        paddingTop: 10,
      ),
      descriptor,
    );
    expect(masks.labels, [
      4,
      4,
      4,
      4,
      4,
      4,
      4,
      4,
      0,
      4,
      4,
      4,
      0,
      4,
      4,
      4,
      4,
      4,
      4,
      4,
      4,
      4,
      0,
      4,
      0,
      4,
      0,
      4,
      4,
      4,
      4,
      4,
      4,
      4,
      4,
    ]);
    expect(masks.count(RoomLayer.furniture), 30);
  });

  test(
    'closing ties resolve wall before ceiling without replacing ownership',
    () {
      final masks = postprocessRoomOutput(
        patch([
          [2, 1, 2, 1, 2],
          [6, 1, 6, 1, 6],
          [2, 1, 0, 1, 2],
          [6, 1, 6, 1, 6],
          [2, 1, 2, 1, 2],
        ]),
        transform(
          sourceWidth: 5,
          sourceHeight: 5,
          contentWidth: 5,
          contentHeight: 5,
          paddingLeft: 10,
          paddingTop: 10,
        ),
        descriptor,
      );
      expect(masks.labels, [
        0,
        1,
        0,
        1,
        0,
        2,
        1,
        2,
        1,
        2,
        0,
        1,
        1,
        1,
        0,
        2,
        1,
        2,
        1,
        2,
        0,
        1,
        0,
        1,
        0,
      ]);
    },
  );

  test(
    'ignored border is not invented by closing and fixed pixels stay owned',
    () {
      final masks = postprocessRoomOutput(
        patch(
          [
            [0, 1, 0],
            [1, 1, 1],
            [0, 1, 0],
          ],
          x: 0,
          y: 0,
        ),
        transform(
          sourceWidth: 3,
          sourceHeight: 3,
          contentWidth: 3,
          contentHeight: 3,
        ),
        descriptor,
      );
      expect(masks.labels, [0, 1, 0, 1, 1, 1, 0, 1, 0]);
    },
  );

  test('postprocessing rejects unverified output and transform dimensions', () {
    expect(
      () => postprocessRoomOutput(
        RawSegmentation(
          width: 1,
          height: 1,
          classIds: Uint16List.fromList([1]),
        ),
        transform(),
        descriptor,
      ),
      throwsArgumentError,
    );
    expect(
      () => postprocessRoomOutput(
        patch([
          [1],
        ]),
        RoomInputTransform(
          sourceWidth: 1,
          sourceHeight: 1,
          inputWidth: 511,
          inputHeight: 512,
          contentWidth: 1,
          contentHeight: 1,
          paddingLeft: 0,
          paddingTop: 0,
        ),
        descriptor,
      ),
      throwsArgumentError,
    );
  });

  test('radius one alpha uses binomial kernel and zero exterior', () {
    final masks = MaskBitmap(
      width: 3,
      height: 3,
      labels: Uint8List.fromList([0, 0, 0, 0, 1, 0, 0, 0, 0]),
    );
    expect(buildLayerAlpha(masks, RoomLayer.wall, featherRadius: 1), [
      16,
      32,
      16,
      32,
      64,
      32,
      16,
      32,
      16,
    ]);
    final corner = MaskBitmap(
      width: 2,
      height: 2,
      labels: Uint8List.fromList([1, 0, 0, 0]),
    );
    expect(buildLayerAlpha(corner, RoomLayer.wall, featherRadius: 1), [
      64,
      32,
      32,
      16,
    ]);
    expect(masks.labels, [0, 0, 0, 0, 1, 0, 0, 0, 0]);
    expect(masks.count(RoomLayer.wall), 1);
  });

  test(
    'radius two alpha uses full precision then rounds and leaves ownership',
    () {
      final labels = Uint8List(25)..[12] = 4;
      final masks = MaskBitmap(width: 5, height: 5, labels: labels);
      final alpha = buildLayerAlpha(masks, RoomLayer.furniture);
      expect(alpha, [
        1,
        4,
        6,
        4,
        1,
        4,
        16,
        24,
        16,
        4,
        6,
        24,
        36,
        24,
        6,
        4,
        16,
        24,
        16,
        4,
        1,
        4,
        6,
        4,
        1,
      ]);
      alpha[12] = 0;
      expect(masks.labels[12], 4);
      expect(masks.count(RoomLayer.furniture), 1);
      expect(buildLayerAlpha(masks, RoomLayer.wall), everyElement(0));
      expect(
        buildLayerAlpha(
          MaskBitmap(width: 1, height: 1, labels: Uint8List.fromList([1])),
          RoomLayer.wall,
        ),
        [36],
      );
    },
  );

  test(
    'alpha bounds include opaque interiors and radius zero binary output',
    () {
      final masks = MaskBitmap(
        width: 7,
        height: 7,
        labels: Uint8List(49)..fillRange(0, 49, 3),
      );
      for (final radius in [1, 2]) {
        final alpha = buildLayerAlpha(
          masks,
          RoomLayer.floor,
          featherRadius: radius,
        );
        expect(alpha, everyElement(inInclusiveRange(0, 255)));
        expect(alpha[24], 255);
      }
      expect(
        buildLayerAlpha(masks, RoomLayer.floor, featherRadius: 0),
        everyElement(255),
      );
      for (final radius in [-1, 3]) {
        expect(
          () => buildLayerAlpha(masks, RoomLayer.floor, featherRadius: radius),
          throwsArgumentError,
        );
      }
    },
  );
}
