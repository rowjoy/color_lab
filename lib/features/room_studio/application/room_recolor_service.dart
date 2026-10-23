import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../picker/domain/prepared_photo.dart';
import '../domain/mask_bitmap.dart';
import '../domain/room_layer_colors.dart';
import '../recolor/room_photo_recolorer.dart';
import '../recolor/room_recolor_frame.dart';

abstract interface class RoomRecolorService {
  Future<RoomRecolorFrame> render({
    required RoomRecolorKey key,
    required PreparedPhoto photo,
    required MaskBitmap masks,
    required RoomLayerColors colors,
  });
}

final class IsolateRoomRecolorService implements RoomRecolorService {
  const IsolateRoomRecolorService();

  @override
  Future<RoomRecolorFrame> render({
    required RoomRecolorKey key,
    required PreparedPhoto photo,
    required MaskBitmap masks,
    required RoomLayerColors colors,
  }) => Isolate.run(
    () =>
        recolorRoomPhoto(key: key, photo: photo, masks: masks, colors: colors),
  );
}

final roomRecolorServiceProvider = Provider<RoomRecolorService>(
  (ref) => const IsolateRoomRecolorService(),
);
