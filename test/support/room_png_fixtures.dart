import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

const pngSignature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
int pngCrc(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var i = 0; i < 8; i++) {
      crc = (crc >> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
    }
  }
  return crc ^ 0xffffffff;
}

Uint8List pngChunk(String name, List<int> payload) {
  final result = Uint8List(payload.length + 12);
  final data = ByteData.sublistView(result);
  data.setUint32(0, payload.length);
  result.setRange(4, 8, name.codeUnits);
  result.setRange(8, 8 + payload.length, payload);
  data.setUint32(
    result.length - 4,
    pngCrc(result.sublist(4, result.length - 4)),
  );
  return result;
}

List<(String, Uint8List)> pngChunks(Uint8List bytes) {
  final chunks = <(String, Uint8List)>[];
  var offset = 8;
  while (offset < bytes.length) {
    final length = ByteData.sublistView(bytes).getUint32(offset);
    chunks.add((
      String.fromCharCodes(bytes.sublist(offset + 4, offset + 8)),
      Uint8List.fromList(bytes.sublist(offset + 8, offset + 8 + length)),
    ));
    offset += length + 12;
  }
  return chunks;
}

Uint8List pngFromChunks(List<(String, List<int>)> chunks) =>
    Uint8List.fromList([
      ...pngSignature,
      for (final chunk in chunks) ...pngChunk(chunk.$1, chunk.$2),
    ]);
Uint8List roomPng({int width = 2, int height = 1, int channels = 4}) =>
    img.encodePng(
      img.Image(width: width, height: height, numChannels: channels)
        ..clear(img.ColorRgba8(19, 67, 123, 255)),
    );
Uint8List rawPng(
  List<int> rows, {
  int width = 1,
  int height = 1,
  int color = 6,
  List<int>? compressed,
}) {
  final header = Uint8List(13);
  ByteData.sublistView(header)
    ..setUint32(0, width)
    ..setUint32(4, height);
  header[8] = 8;
  header[9] = color;
  return pngFromChunks([
    ('IHDR', header),
    ('IDAT', compressed ?? zlib.encode(rows)),
    ('IEND', []),
  ]);
}
