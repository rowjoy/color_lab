import 'dart:typed_data';
import 'dart:ui';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';

/// Preserves existing recording-writer test seams. Real permission/temp/terminal
/// cancellation is exercised separately against PlatformRoomImageExportService.
final class IllustratedRoomTestExportService implements RoomImageExportService {
  IllustratedRoomTestExportService(this.writer);
  final RoomGalleryWriter writer;
  @override
  Future<void> prepareSave({required bool Function() isCurrent}) async {
    if (!isCurrent()) throw const RoomExportInterrupted();
  }

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String photoId,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    if (!isCurrent()) throw const RoomExportInterrupted();
    onHandoff?.call();
    await writer.savePng(
      pngBytes: pngBytes,
      fileName: 'tintatlas-room-$photoId.png',
    );
  }

  @override
  Future<RoomShareResult> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
    required String title,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) => throw UnimplementedError('Use a recording Share service.');
}
