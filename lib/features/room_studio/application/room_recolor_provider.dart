import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recolor/room_recolor_frame.dart';
import 'room_mask_controller.dart';
import 'room_recolor_service.dart';

final roomRecolorPreviewProvider = FutureProvider<RoomRecolorFrame?>((ref) {
  final draft = ref.watch(roomMaskProvider.select((state) => state.draft));
  if (draft == null) return Future.value();
  final key = RoomRecolorKey(
    photoId: draft.photoId,
    maskRevision: draft.maskRevision,
    colorRevision: draft.colorRevision,
  );
  return ref
      .read(roomRecolorServiceProvider)
      .render(
        key: key,
        photo: draft.photo,
        masks: draft.masks,
        colors: draft.colors,
      );
});
