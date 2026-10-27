import 'dart:typed_data';

import '../domain/mask_edit_command.dart';
import '../domain/mask_edit_history.dart';
import '../domain/room_project.dart' show RoomProjectLimits;

/// TAEH v1, big endian: 28-byte header, then undo followed by redo records.
/// Each record has width/height/count uint32 fields and five typed payloads.
abstract final class MaskEditHistoryCodec {
  static const headerBytes = 28;
  static const maxEncodedBytes =
      headerBytes + MaskEditHistory.maxCommands * 12 + MaskEditHistory.maxBytes;

  static Uint8List encode(MaskEditHistory history) {
    final commands = [...history.undoStack, ...history.redoStack];
    final bytes = Uint8List(
      headerBytes + commands.length * 12 + history.byteLength,
    );
    bytes.setRange(0, 4, const [84, 65, 69, 72]);
    final data = ByteData.sublistView(bytes);
    data.setUint16(4, 1);
    data.setUint32(8, history.width);
    data.setUint32(12, history.height);
    data.setUint32(16, history.undoStack.length);
    data.setUint32(20, history.redoStack.length);
    data.setUint32(24, history.byteLength);
    var offset = headerBytes;
    for (final command in commands) {
      data.setUint32(offset, command.width);
      data.setUint32(offset + 4, command.height);
      data.setUint32(offset + 8, command.indices.length);
      offset += 12;
      for (final index in command.indices) {
        data.setUint32(offset, index);
        offset += 4;
      }
      for (final values in [
        command.beforeLabels,
        command.afterLabels,
        command.beforeIntent,
        command.afterIntent,
      ]) {
        bytes.setRange(offset, offset + values.length, values);
        offset += values.length;
      }
    }
    return bytes.asUnmodifiableView();
  }

  static MaskEditHistory decode(
    Uint8List bytes, {
    required int width,
    required int height,
  }) {
    Never invalid() =>
        throw const FormatException('Invalid Room edit history.');
    if (bytes.length < headerBytes || bytes.length > maxEncodedBytes) invalid();
    final data = ByteData.sublistView(bytes);
    if (data.getUint32(0) != 0x54414548 ||
        data.getUint16(4) != 1 ||
        data.getUint16(6) != 0 ||
        data.getUint32(8) != width ||
        data.getUint32(12) != height ||
        width < 1 ||
        height < 1 ||
        width > RoomProjectLimits.maxDimension ||
        height > RoomProjectLimits.maxDimension) {
      invalid();
    }
    final undoCount = data.getUint32(16);
    final redoCount = data.getUint32(20);
    final count = undoCount + redoCount;
    final payload = data.getUint32(24);
    if (count > MaskEditHistory.maxCommands ||
        payload > MaskEditHistory.maxBytes ||
        headerBytes + count * 12 + payload != bytes.length) {
      invalid();
    }
    // Validate every record's dimensions/count/extent before allocating deltas.
    final records = <({int count, int offset})>[];
    var offset = headerBytes;
    var total = 0;
    for (var i = 0; i < count; i++) {
      if (offset + 12 > bytes.length ||
          data.getUint32(offset) != width ||
          data.getUint32(offset + 4) != height) {
        invalid();
      }
      final pixels = data.getUint32(offset + 8);
      offset += 12;
      if (pixels < 1 ||
          pixels > width * height ||
          pixels * 8 > bytes.length - offset ||
          total + pixels * 8 > MaskEditHistory.maxBytes) {
        invalid();
      }
      records.add((count: pixels, offset: offset));
      offset += pixels * 8;
      total += pixels * 8;
    }
    if (offset != bytes.length || total != payload) invalid();
    try {
      final commands = <MaskEditCommand>[];
      for (final record in records) {
        var cursor = record.offset;
        final indices = Uint32List(record.count);
        for (var i = 0; i < indices.length; i++) {
          indices[i] = data.getUint32(cursor);
          cursor += 4;
        }
        Uint8List values() {
          final result = Uint8List.sublistView(
            bytes,
            cursor,
            cursor + record.count,
          );
          cursor += record.count;
          return result;
        }

        commands.add(
          MaskEditCommand(
            width: width,
            height: height,
            indices: indices,
            beforeLabels: values(),
            afterLabels: values(),
            beforeIntent: values(),
            afterIntent: values(),
          ),
        );
      }
      return MaskEditHistory.fromStacks(
        width: width,
        height: height,
        undoStack: commands.sublist(0, undoCount),
        redoStack: commands.sublist(undoCount),
      );
    } on ArgumentError {
      invalid();
    }
  }
}
