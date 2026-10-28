import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/smart_mask_proposal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/mask_edit_fixtures.dart';

SmartMaskProposalKey key({
  String project = 'p',
  String photo = 'f',
  int revision = 0,
  RoomLayer layer = RoomLayer.wall,
  SmartMaskAction action = SmartMaskAction.add,
}) => SmartMaskProposalKey(
  projectId: project,
  photoId: photo,
  maskRevision: revision,
  layer: layer,
  action: action,
);

void main() {
  test(
    'full key equality includes every project photo revision layer action',
    () {
      final value = key();
      expect(value, key());
      expect(value.hashCode, key().hashCode);
      for (final other in [
        key(project: 'q'),
        key(photo: 'g'),
        key(revision: 1),
        key(layer: RoomLayer.floor),
        key(action: SmartMaskAction.remove),
        key(action: SmartMaskAction.cleanup),
      ]) {
        expect(value, isNot(other));
      }
      expect(() => key(project: ''), throwsArgumentError);
      expect(() => key(photo: ''), throwsArgumentError);
      expect(() => key(revision: -1), throwsArgumentError);
      expect(SmartMaskAvailability.values, [
        SmartMaskAvailability.disabledByEvidence,
      ]);
    },
  );

  test('preview and exact command dimensions must align', () {
    final command = historyEdit(0);
    expect(
      () => SmartMaskProposal(
        key: key(),
        command: command,
        previewMasks: MaskBitmap(width: 4, height: 1, labels: Uint8List(4)),
      ),
      throwsArgumentError,
    );
  });
}
