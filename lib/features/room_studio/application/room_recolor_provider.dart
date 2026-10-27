import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recolor/room_recolor_frame.dart';
import 'room_project_session_controller.dart';
import 'room_recolor_service.dart';

RoomRecolorKey _key(RoomProjectSession session, String variantId) =>
    RoomRecolorKey(
      projectId: session.projectId,
      photoId: session.visible.photoId,
      maskRevision: session.visible.maskRevision,
      colorRevision: session.visible.colorRevision,
      variantId: variantId,
    );

RoomRecolorKey? roomActiveRecolorKey(RoomProjectSession? session) =>
    session == null ? null : _key(session, session.activeVariantId);
RoomRecolorKey? roomBaselineRecolorKey(RoomProjectSession? session) {
  final baseline = session?.comparisonBaselineVariantId;
  return session == null ||
          baseline == null ||
          baseline == session.activeVariantId
      ? null
      : _key(session, baseline);
}

final roomRecolorKeyProvider = Provider<RoomRecolorKey?>((ref) {
  final session = ref.watch(roomProjectSessionProvider);
  return roomActiveRecolorKey(session);
});

final roomComparisonKeyProvider = Provider<RoomRecolorKey?>((ref) {
  final session = ref.watch(roomProjectSessionProvider);
  return roomBaselineRecolorKey(session);
});

// Independent provider generations isolate the two sides' results and errors.
// Controlled workers, bounds, timeouts and fairness belong to Task 6.
final roomRecolorPreviewProvider = FutureProvider<RoomRecolorFrame?>((
  ref,
) async {
  final key = ref.watch(
    roomProjectSessionProvider.select(roomActiveRecolorKey),
  );
  // The key and pixels must come from the same visible snapshot. Session Open
  // publishes before the editor mirror installs its returned draft.
  final session = ref.read(roomProjectSessionProvider);
  if (key == null || session == null) return null;
  final draft = session.visible;
  final frame = await ref
      .read(roomRecolorServiceProvider)
      .render(
        key: key,
        photo: draft.photo,
        masks: draft.masks,
        colors: draft.colors,
      );
  if (!ref.mounted) return null;
  if (frame.key != key) throw StateError('Preview identity mismatch');
  return frame;
}, retry: (count, error) => null);

final roomComparisonPreviewProvider = FutureProvider<RoomRecolorFrame?>((
  ref,
) async {
  final key = ref.watch(
    roomProjectSessionProvider.select(roomBaselineRecolorKey),
  );
  final session = ref.read(roomProjectSessionProvider);
  if (key == null || session == null) return null;
  final draft = session.visible;
  final frame = await ref
      .read(roomRecolorServiceProvider)
      .render(
        key: key,
        photo: draft.photo,
        masks: draft.masks,
        colors: session.variantSet.baseline!.colors,
      );
  if (!ref.mounted) return null;
  if (frame.key != key) throw StateError('Preview identity mismatch');
  return frame;
}, retry: (count, error) => null);
