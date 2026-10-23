import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as image;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import '../../picker/domain/prepared_photo.dart';
import 'room_wall_depth_protection.dart';

const roomDepthModelAsset = 'assets/models/room_depth.tflite';
const roomDepthModelSha256 =
    '93d871071edff1218973ce25ee27ce95ccd20450c70a55e1b89efa3f5a772cdd';
const roomDepthInputAxis = 256;

abstract interface class RoomDepthRunner {
  RoomDepthFrame invoke(PreparedPhoto photo);
  void close();
}

/// Exact whole-photo transform, independent of the semantic model's letterbox.
/// Normalization follows the upstream EfficientNet-Lite mobile depth demo.
Float32List prepareRoomDepthInput(PreparedPhoto photo) {
  final source = image.Image.fromBytes(
    width: photo.width,
    height: photo.height,
    bytes: photo.rgbaBytes.buffer,
    numChannels: 4,
    order: image.ChannelOrder.rgba,
  );
  final resized = image.copyResize(
    source,
    width: roomDepthInputAxis,
    height: roomDepthInputAxis,
    interpolation: image.Interpolation.linear,
  );
  final input = Float32List(roomDepthInputAxis * roomDepthInputAxis * 3);
  var offset = 0;
  for (final pixel in resized) {
    input[offset++] = (pixel.r - 115) / 58;
    input[offset++] = (pixel.g - 115) / 58;
    input[offset++] = (pixel.b - 115) / 58;
  }
  return input;
}

/// Owned only by the inference isolate. A missing/invalid protection model
/// fails explicitly rather than silently returning the known unsafe wall mask.
final class TfliteRoomDepthRunner implements RoomDepthRunner {
  factory TfliteRoomDepthRunner(Uint8List modelBytes) {
    if (sha256.convert(modelBytes).toString() != roomDepthModelSha256) {
      throw const FormatException('Room depth model SHA-256 mismatch');
    }
    final options = tfl.InterpreterOptions()..threads = 1;
    tfl.Interpreter? interpreter;
    try {
      interpreter = tfl.Interpreter.fromBuffer(modelBytes, options: options);
      if (interpreter.getInputTensors().length != 1 ||
          interpreter.getOutputTensors().length != 1) {
        throw const FormatException('Room depth tensor count mismatch');
      }
      _validate(interpreter.getInputTensor(0), const [1, 256, 256, 3]);
      _validate(interpreter.getOutputTensor(0), const [1, 256, 256, 1]);
      return TfliteRoomDepthRunner._(interpreter);
    } catch (_) {
      interpreter?.close();
      rethrow;
    } finally {
      options.delete();
    }
  }

  TfliteRoomDepthRunner._(this._interpreter);

  final tfl.Interpreter _interpreter;
  bool _closed = false;

  static void _validate(tfl.Tensor tensor, List<int> shape) {
    if (tensor.type != tfl.TensorType.float32 ||
        tensor.shape.length != shape.length ||
        !shape.indexed.every((entry) => tensor.shape[entry.$1] == entry.$2) ||
        tensor.numBytes() != shape.reduce((a, b) => a * b) * 4) {
      throw const FormatException('Room depth tensor contract mismatch');
    }
  }

  @override
  RoomDepthFrame invoke(PreparedPhoto photo) {
    if (_closed) throw StateError('Room depth runner is closed');
    final input = prepareRoomDepthInput(photo);
    _interpreter.getInputTensor(0).data = Uint8List.view(input.buffer);
    _interpreter.invoke();
    final output = _interpreter.getOutputTensor(0);
    _validate(output, const [1, 256, 256, 1]);
    final data = ByteData.sublistView(output.data);
    final depths = Float32List(roomDepthInputAxis * roomDepthInputAxis);
    for (var i = 0; i < depths.length; i++) {
      depths[i] = data.getFloat32(i * 4, Endian.host);
    }
    return RoomDepthFrame(width: 256, height: 256, inverseDepth: depths);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _interpreter.close();
  }
}
