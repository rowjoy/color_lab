import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'package:flutter_test/flutter_test.dart';

RoomRecolorKey key({
  String project = 'project',
  String photo = 'photo',
  String variant = 'a',
  int mask = 1,
  int color = 2,
}) => RoomRecolorKey(
  projectId: project,
  photoId: photo,
  variantId: variant,
  maskRevision: mask,
  colorRevision: color,
);
void main() {
  test(
    'full key equality and hash partition projects photos masks colors and variants',
    () {
      expect(key(), key());
      expect(key().hashCode, key().hashCode);
      expect({
        key(),
        key(),
        key(project: 'other'),
        key(photo: 'other'),
        key(variant: 'b'),
        key(mask: 2),
        key(color: 3),
      }, hasLength(6));
    },
  );
  test(
    'unsafe IDs and unbounded revisions rejected for every identity field',
    () {
      for (final id in ['', '../path', 'a' * 81]) {
        expect(() => key(project: id), throwsArgumentError);
        expect(() => key(photo: id), throwsArgumentError);
        expect(() => key(variant: id), throwsArgumentError);
      }
      for (final revision in [-1, 2147483648]) {
        expect(() => key(mask: revision), throwsArgumentError);
        expect(() => key(color: revision), throwsArgumentError);
      }
    },
  );
}
