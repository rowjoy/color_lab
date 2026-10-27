import 'dart:typed_data';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_provider.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_undo.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'room_png_fixtures.dart';

RoomExportSource source({
  required Object lifetime,
  required Object owner,
  String project = 'project',
  String photoId = 'photo',
  String variant = 'a',
  int mask = 0,
  int color = 0,
  int width = 2,
  bool eligible = true,
  bool ready = true,
}) {
  final photo = PreparedPhoto(
    width: width,
    height: 1,
    rgbaBytes: Uint8List(width * 4),
    previewBytes: roomPng(width: width),
    palette: const [],
  );
  final masks = MaskBitmap(width: width, height: 1, labels: Uint8List(width));
  final draft = RoomMaskDraft(
    photoId: photoId,
    photo: photo,
    aiMasks: masks,
    masks: masks,
    history: MaskUndoHistory(),
    maskRevision: mask,
    changedFromAiCount: 0,
    colorRevision: color,
  );
  final session = RoomProjectSession(
    projectId: project,
    name: 'private project',
    durable: null,
    visible: draft,
    saveStatus: RoomProjectSaveStatus.failed,
    saveError: RoomProjectSaveError.storage,
    pendingSaveCount: 0,
    acknowledgedRevision: 0,
    variantSet: RoomVariantSet(
      variants: [
        RoomColorVariant(id: variant, name: 'Selected', colors: draft.colors),
      ],
      activeVariantId: variant,
    ),
    lifetime: lifetime,
  );
  return RoomExportSource(
    session: session,
    owner: owner,
    eligible: eligible,
    ready: ready,
    frame: RoomRecolorFrame(
      key: roomActiveRecolorKey(session)!,
      width: width,
      height: 1,
      rgbaBytes: photo.rgbaBytes,
      pngBytes: photo.previewBytes,
    ),
  );
}
