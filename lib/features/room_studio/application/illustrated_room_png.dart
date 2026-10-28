import 'dart:typed_data';
import 'room_export_metadata_verifier.dart';

/// ui.Image encoders may add color-profile chunks. Our rendered pixels already
/// have the selected display RGB values; exported room/card files intentionally
/// contain only the image header, pixel stream and end marker.
Uint8List cleanIllustratedRoomPng(Uint8List renderedPng) {
  if (renderedPng.length < 8 ||
      renderedPng.length > RoomExportMetadataVerifier.maxEncodedBytes) {
    throw const RoomExportVerificationException();
  }
  final output = BytesBuilder(copy: true)..add(renderedPng.sublist(0, 8));
  final data = ByteData.sublistView(renderedPng);
  var offset = 8;
  while (offset < renderedPng.length) {
    if (renderedPng.length - offset < 12) {
      throw const RoomExportVerificationException();
    }
    final length = data.getUint32(offset);
    final end = offset + 12 + length;
    if (end > renderedPng.length) throw const RoomExportVerificationException();
    final type = String.fromCharCodes(
      renderedPng.sublist(offset + 4, offset + 8),
    );
    if (type == 'IHDR' || type == 'IDAT' || type == 'IEND') {
      output.add(renderedPng.sublist(offset, end));
    } else if ((renderedPng[offset + 4] & 32) == 0) {
      throw const RoomExportVerificationException();
    }
    offset = end;
  }
  final bytes = output.takeBytes();
  const RoomExportMetadataVerifier().verify(bytes);
  return bytes;
}
