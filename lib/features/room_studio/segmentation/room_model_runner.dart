import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

import 'raw_segmentation.dart';
import 'room_model_descriptor.dart';

abstract interface class RoomModelRunner {
  RoomModelDescriptor get descriptor;
  RawSegmentation invoke(Uint8List inputTensorBytes);
  void close();
}

/// Create and use inside the inference worker; never transfer native handles.
final class TfliteRoomModelRunner implements RoomModelRunner {
  factory TfliteRoomModelRunner(
    Uint8List modelBytes,
    RoomModelDescriptor descriptor,
  ) {
    final checksum = crypto.sha256.convert(modelBytes).toString();
    // This fixed artifact's schema supplies quantization on hosts where the
    // package's public Tensor.params API is unsupported (documented Android-only).
    const selectedSha =
        'da8b3822a22fde45ecaf0ff32022287eff58b500096971b04f3c1b292da66a3c';
    if (checksum != descriptor.sha256 || checksum != selectedSha) {
      throw const FormatException('Room model SHA-256 mismatch');
    }
    tfl.Interpreter? interpreter;
    final options = tfl.InterpreterOptions()..threads = 1;
    try {
      interpreter = tfl.Interpreter.fromBuffer(modelBytes, options: options);
      if (interpreter.getInputTensors().length != 1 ||
          interpreter.getOutputTensors().length != 1) {
        throw const FormatException(
          'Room model must have one input and one output',
        );
      }
      final input = interpreter.getInputTensor(0);
      final output = interpreter.getOutputTensor(0);
      _validateTensor(
        input,
        descriptor.inputShape,
        tfl.TensorType.uint8,
        'PreprocessedImageTensor',
        512 * 512 * 3,
      );
      _validateTensor(
        output,
        descriptor.outputShape,
        tfl.TensorType.int32,
        'SemanticPredictions',
        512 * 512 * 4,
      );
      if (Platform.isAndroid) {
        final params = input.params;
        if (params.scale != descriptor.inputScale ||
            params.zeroPoint != descriptor.inputZeroPoint) {
          throw const FormatException('Room input quantization mismatch');
        }
      }
      return TfliteRoomModelRunner._(interpreter, descriptor);
    } catch (_) {
      interpreter?.close();
      rethrow;
    } finally {
      options.delete();
    }
  }

  TfliteRoomModelRunner._(this._interpreter, this.descriptor);
  final tfl.Interpreter _interpreter;
  @override
  final RoomModelDescriptor descriptor;
  bool _closed = false;

  static void _validateTensor(
    tfl.Tensor tensor,
    List<int> shape,
    tfl.TensorType type,
    String name,
    int bytes,
  ) {
    final actual = tensor.shape;
    if (tensor.name != name ||
        tensor.type != type ||
        actual.length != shape.length ||
        !actual.indexed.every((e) => e.$2 == shape[e.$1]) ||
        tensor.numBytes() != bytes) {
      throw FormatException('Room tensor mismatch: $name');
    }
  }

  @override
  RawSegmentation invoke(Uint8List inputTensorBytes) {
    if (_closed) throw StateError('Room model runner is closed');
    if (inputTensorBytes.length !=
        descriptor.inputWidth * descriptor.inputHeight * 3) {
      throw ArgumentError('Room input must contain exactly 786432 RGB bytes');
    }
    _interpreter.getInputTensor(0).data = inputTensorBytes;
    _interpreter.invoke();
    final output = _interpreter.getOutputTensor(0);
    _validateTensor(
      output,
      descriptor.outputShape,
      tfl.TensorType.int32,
      'SemanticPredictions',
      512 * 512 * 4,
    );
    final data = output.data;
    final values = ByteData.sublistView(data);
    final ids = Uint16List(descriptor.outputWidth * descriptor.outputHeight);
    for (var i = 0; i < ids.length; i++) {
      final id = values.getInt32(i * 4, Endian.host);
      if (id < 0 || id >= descriptor.classCount) {
        throw FormatException('Room model emitted invalid class ID $id');
      }
      ids[i] = id;
    }
    return RawSegmentation(
      width: descriptor.outputWidth,
      height: descriptor.outputHeight,
      classIds: ids,
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _interpreter.close();
  }
}
