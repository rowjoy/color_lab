enum RoomTensorType { float32, int8, uint8, int32, int64 }

enum RoomInputEncoding { rgbUint8 }

/// Frozen MOSAIC R4 contract. Quantization describes the native tensor;
/// [RoomInputEncoding.rgbUint8] transfers bytes without normalization.
final class RoomModelDescriptor {
  RoomModelDescriptor._({
    required this.sourceRevision,
    required this.sha256,
    required this.requiredOperators,
    required this.inputShape,
    required this.outputShape,
    required this.channelMeans,
    required this.channelStdDevs,
    required this.labelsById,
  });

  factory RoomModelDescriptor.fromMap(Map<String, Object?> map) {
    Never invalid(String field) =>
        throw FormatException('Invalid room model $field');
    void exact(String field, Object value) {
      if (map[field] != value) invalid(field);
    }

    List<int> shape(String field, List<int> expected) {
      final value = map[field];
      if (value is! List || value.length != expected.length) invalid(field);
      for (var i = 0; i < expected.length; i++) {
        if (value[i] is! int || value[i] != expected[i]) invalid(field);
      }
      return List<int>.unmodifiable(value.cast<int>());
    }

    List<double> channels(String field, double expected) {
      final value = map[field];
      if (value is! List || value.length != 3) invalid(field);
      for (final channel in value) {
        if (channel is! num || !channel.isFinite || channel != expected) {
          invalid(field);
        }
      }
      return List<double>.unmodifiable(
        value.cast<num>().map((v) => v.toDouble()),
      );
    }

    for (final field in ['schemaVersion', 'classCount', 'ignoredLabel']) {
      if (map[field] is! int) invalid(field);
    }
    exact('schemaVersion', 1);
    final revision = map['sourceRevision'];
    if (revision is! String || !RegExp(r'^[0-9a-f]{40}$').hasMatch(revision)) {
      invalid('sourceRevision');
    }
    final checksum = map['sha256'];
    if (checksum is! String ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(checksum)) {
      invalid('sha256');
    }
    exact('inputType', 'uint8');
    exact('outputType', 'int32');
    exact('inputEncoding', 'rgbUint8');
    exact('inputScale', 0.007843137718737125);
    if (map['inputZeroPoint'] is! int) invalid('inputZeroPoint');
    exact('inputZeroPoint', 128);
    exact('classCount', 32);
    exact('ignoredLabel', 0);
    final operators = map['requiredOperators'];
    if (operators is! List ||
        operators.length != _operators.length ||
        operators.toSet().length != _operators.length ||
        !_operators.every(operators.contains)) {
      invalid('requiredOperators');
    }
    final labels = map['labelsById'];
    if (labels is! Map || labels.length != _labels.length) {
      invalid('labelsById');
    }
    final parsedLabels = <int, String>{};
    for (var id = 0; id < _labels.length; id++) {
      if (labels['$id'] != _labels[id]) invalid('labelsById[$id]');
      parsedLabels[id] = _labels[id];
    }
    return RoomModelDescriptor._(
      sourceRevision: revision,
      sha256: checksum.toLowerCase(),
      requiredOperators: List<String>.unmodifiable(operators.cast<String>()),
      inputShape: shape('inputShape', const [1, 512, 512, 3]),
      outputShape: shape('outputShape', const [1, 512, 512]),
      channelMeans: channels('channelMeans', 0),
      channelStdDevs: channels('channelStdDevs', 1),
      labelsById: Map<int, String>.unmodifiable(parsedLabels),
    );
  }

  int get schemaVersion => 1;
  final String sourceRevision;
  final String sha256;
  final List<String> requiredOperators;
  final List<int> inputShape;
  final List<int> outputShape;
  RoomTensorType get inputType => RoomTensorType.uint8;
  RoomTensorType get outputType => RoomTensorType.int32;
  RoomInputEncoding get inputEncoding => RoomInputEncoding.rgbUint8;
  final List<double> channelMeans;
  final List<double> channelStdDevs;
  double? get inputScale => 0.007843137718737125;
  int? get inputZeroPoint => 128;
  int get classCount => 32;
  int get ignoredLabel => 0;
  final Map<int, String> labelsById;
  int get inputWidth => inputShape[2];
  int get inputHeight => inputShape[1];
  int get outputWidth => outputShape[2];
  int get outputHeight => outputShape[1];

  int idForName(String name) {
    for (final entry in labelsById.entries) {
      if (entry.value == name) return entry.key;
    }
    throw FormatException('Unknown room label: $name');
  }

  static const _operators = [
    'CONV_2D:1',
    'DEPTHWISE_CONV_2D:2',
    'ADD:1',
    'AVERAGE_POOL_2D:1',
    'SPLIT:1',
    'CONCATENATION:1',
    'QUANTIZE:1',
    'RESIZE_BILINEAR:1',
    'ARG_MAX:1',
  ];
  static const _labels = [
    'unscored',
    'wall',
    'building',
    'sky',
    'floor',
    'tree',
    'ceiling',
    'road',
    'bed',
    'windowpane',
    'grass',
    'cabinet',
    'sidewalk',
    'person',
    'earth',
    'door',
    'table',
    'mountain',
    'plant',
    'curtain',
    'chair',
    'car',
    'water',
    'painting',
    'sofa',
    'shelf',
    'house',
    'sea',
    'mirror',
    'rug',
    'field',
    'armchair',
  ];
}
