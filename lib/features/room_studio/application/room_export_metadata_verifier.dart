import 'dart:io' as io;
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// No codec details, bytes, filenames, or source metadata cross this boundary.
final class RoomExportVerificationException implements Exception {
  const RoomExportVerificationException();
  @override
  String toString() => 'RoomExportVerificationException';
}

final class RoomExportDimensions {
  const RoomExportDimensions(this.width, this.height);
  final int width, height;
}

/// Validates our deliberately narrow still-PNG profile. Never repairs bytes.
final class RoomExportMetadataVerifier {
  const RoomExportMetadataVerifier();
  static const maxEncodedBytes = 64 * 1024 * 1024;
  static const _signature = [137, 80, 78, 71, 13, 10, 26, 10];

  RoomExportDimensions verify(Uint8List bytes) {
    try {
      return _verify(bytes);
    } catch (_) {
      throw const RoomExportVerificationException();
    }
  }

  RoomExportDimensions _verify(Uint8List bytes) {
    void require(bool condition) {
      if (!condition) throw const RoomExportVerificationException();
    }

    require(bytes.length >= 8 && bytes.length <= maxEncodedBytes);
    for (var i = 0; i < 8; i++) {
      require(bytes[i] == _signature[i]);
    }
    final data = ByteData.sublistView(bytes);
    var offset = 8, count = 0, width = 0, height = 0, channels = 0;
    var idatBytes = 0;
    final payloads = <Uint8List>[];
    var ended = false;
    while (offset < bytes.length) {
      require(++count <= 4096 && bytes.length - offset >= 12);
      final length = data.getUint32(offset);
      require(length <= bytes.length - offset - 12);
      final end = offset + 8 + length;
      final type = String.fromCharCodes(
        Uint8List.sublistView(bytes, offset + 4, offset + 8),
      );
      require(type == 'IHDR' || type == 'IDAT' || type == 'IEND');
      require(
        getCrc32(Uint8List.sublistView(bytes, offset + 4, end)) ==
            data.getUint32(end),
      );
      switch (type) {
        case 'IHDR':
          require(count == 1 && length == 13);
          width = data.getUint32(offset + 8);
          height = data.getUint32(offset + 12);
          require(
            width > 0 &&
                height > 0 &&
                width <= 4096 &&
                height <= 4096 &&
                width * height <= 16777216,
          );
          require(bytes[offset + 16] == 8);
          final color = bytes[offset + 17];
          require(color == 2 || color == 6);
          channels = color == 2 ? 3 : 4;
          require(
            bytes[offset + 18] == 0 &&
                bytes[offset + 19] == 0 &&
                bytes[offset + 20] == 0,
          );
        case 'IDAT':
          require(count > 1 && width > 0 && length > 0 && !ended);
          idatBytes += length;
          payloads.add(Uint8List.sublistView(bytes, offset + 8, end));
        case 'IEND':
          require(
            length == 0 && payloads.isNotEmpty && end + 4 == bytes.length,
          );
          ended = true;
      }
      offset = end + 4;
    }
    require(ended);
    // Chunk lengths and the encoded budget are validated before this copy.
    final compressed = Uint8List(idatBytes);
    var cursor = 0;
    for (final payload in payloads) {
      compressed.setRange(cursor, cursor + payload.length, payload);
      cursor += payload.length;
    }
    require(compressed.length >= 6);
    final cmf = compressed[0], flg = compressed[1];
    require(
      cmf & 15 == 8 &&
          cmf >> 4 <= 7 &&
          (cmf * 256 + flg) % 31 == 0 &&
          flg & 32 == 0,
    );
    final rowLength = 1 + width * channels;
    final output = _BoundedRows(rowLength, height);
    // Keep the Adler suffix available for Huffman lookahead. Inflate rewinds
    // complete unread bytes. Position must finish exactly before that suffix.
    final input = InputMemoryStream(compressed, offset: 2);
    final inflater = Inflate.lazy(input, output: output);
    while (true) {
      require(input.position < compressed.length - 6);
      final more = inflater.inflateBlock();
      if (!more) break;
    }
    require(input.position == compressed.length - 6);
    require(output.length == rowLength * height);
    require(
      output.adler ==
          ByteData.sublistView(compressed).getUint32(compressed.length - 4),
    );
    // The SDK validates the complete deflate grammar/checksum as a second
    // independent check. It is reached only after bounded output/termination
    // validation, so a bomb never reaches the native decoder.
    final check = _RowCheck(rowLength * height);
    final sink = io.ZLibDecoder().startChunkedConversion(check);
    sink.add(compressed);
    sink.close();
    require(check.length == rowLength * height);
    return RoomExportDimensions(width, height);
  }
}

/// Constant-size LZ77 history; rejects excess output before writing a byte.
final class _BoundedRows extends OutputStream {
  _BoundedRows(this.rowLength, int height)
    : limit = rowLength * height,
      super(byteOrder: ByteOrder.bigEndian);
  final int rowLength, limit;
  final _history = Uint8List(32768);
  int _length = 0, _a = 1, _b = 0;
  @override
  int get length => _length;
  int get adler => (_b << 16) | _a;
  @override
  void writeByte(int value) {
    if (_length >= limit || (_length % rowLength == 0 && value > 4)) {
      throw const RoomExportVerificationException();
    }
    _history[_length++ & 32767] = value;
    _a = (_a + value) % 65521;
    _b = (_b + _a) % 65521;
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    if (count > limit - _length) throw const RoomExportVerificationException();
    for (var i = 0; i < count; i++) {
      writeByte(bytes[i]);
    }
  }

  @override
  void writeStream(InputStream stream) {
    if (stream.length > limit - _length) {
      throw const RoomExportVerificationException();
    }
    while (!stream.isEOS) {
      writeByte(stream.readByte());
    }
  }

  @override
  void writeBackReference(int distance, int count) {
    if (distance < 1 ||
        distance > 32768 ||
        distance > _length ||
        count < 0 ||
        count > limit - _length) {
      throw const RoomExportVerificationException();
    }
    for (var i = 0; i < count; i++) {
      writeByte(_history[(_length - distance) & 32767]);
    }
  }

  @override
  Uint8List subset(int start, [int? end]) =>
      throw const RoomExportVerificationException();
  @override
  void clear() => throw const RoomExportVerificationException();
  @override
  void flush() {}
}

final class _RowCheck implements Sink<List<int>> {
  _RowCheck(this.limit);
  final int limit;
  int length = 0;
  @override
  void add(List<int> data) {
    if (data.length > limit - length) {
      throw const RoomExportVerificationException();
    }
    length += data.length;
  }

  @override
  void close() {}
}
