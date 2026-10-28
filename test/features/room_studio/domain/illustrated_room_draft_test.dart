import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final study = IllustratedRoomCatalog.study;

  test('fresh draft uses a clean grayscale baseline', () {
    final draft = IllustratedRoomDraft.grayscale(study);

    expect(draft.template, same(study));
    expect(draft.mode, IllustratedRoomVisualMode.grayscale);
    expect(draft.colors, isNull);
    expect(draft.sourcePaletteId, isNull);
    expect(draft.savedDesignId, isNull);
    expect(draft.savedName, isNull);
    expect(draft.visualStateLabel, 'Black & white');
    expect(draft.isDirty, isFalse);
    expect(draft.canSave, isFalse);
    expect(draft.discardChanges(), draft);
  });

  test(
    'first custom choice seeds the recommended look then changes one surface',
    () {
      final draft = IllustratedRoomDraft.grayscale(study).setSurfaceColor(
        IllustratedRoomSurface.wall,
        RgbColor.fromHex('#123456'),
      );

      expect(draft.mode, IllustratedRoomVisualMode.colored);
      expect(draft.colors!.wall.hex, '#123456');
      expect(draft.colors!.ceiling.hex, '#B7C2A3');
      expect(draft.colors!.floor.hex, '#78866B');
      expect(draft.colors!.furniture.hex, '#4E5B4A');
      expect(draft.sourcePaletteId, isNull);
      expect(draft.visualStateLabel, 'Custom combination');
      expect(draft.isDirty, isTrue);
      expect(draft.canSave, isTrue);
    },
  );

  test(
    'exact colors derive look identity while a later custom value clears it',
    () {
      final look = IllustratedRoomDraft.grayscale(
        study,
      ).applyPalette('airy-slate');

      expect(look.sourcePaletteId, 'airy-slate');
      expect(look.visualStateLabel, 'Airy Slate');
      expect(look.colors, study.palette('airy-slate').colors);

      final custom = look.setSurfaceColor(
        IllustratedRoomSurface.furniture,
        RgbColor.fromHex('#010203'),
      );
      expect(custom.sourcePaletteId, isNull);
      expect(custom.visualStateLabel, 'Custom combination');
    },
  );

  test(
    'saved grayscale reset retains identity and discard restores its baseline',
    () {
      final saved = IllustratedRoomDraft.saved(
        template: study,
        colors: study.palette('soft-linen').colors,
        id: 'saved-1',
        name: 'Warm study',
      );
      final reset = saved.resetToGrayscale();

      expect(reset.mode, IllustratedRoomVisualMode.grayscale);
      expect(reset.colors, isNull);
      expect(reset.savedDesignId, 'saved-1');
      expect(reset.savedName, 'Warm study');
      expect(reset.isDirty, isTrue);
      expect(reset.canSave, isFalse);
      expect(reset.discardChanges(), saved);
    },
  );

  test('manually restoring all baseline colors clears dirty state', () {
    final baseline = IllustratedRoomDraft.saved(
      template: study,
      colors: study.palette('quiet-sage').colors,
      id: 'saved-1',
      name: 'Botanical study',
    );
    final changed = baseline.setSurfaceColor(
      IllustratedRoomSurface.wall,
      RgbColor.fromHex('#010203'),
    );
    final restored = changed.setSurfaceColor(
      IllustratedRoomSurface.wall,
      baseline.colors!.wall,
    );

    expect(changed.isDirty, isTrue);
    expect(restored.isDirty, isFalse);
    expect(restored.canSave, isFalse);
    expect(restored, baseline);
  });

  test(
    'save replaces baseline and rename updates current and baseline identity',
    () {
      final edited = IllustratedRoomDraft.grayscale(
        study,
      ).applyPalette('soft-linen');
      final saved = edited.markSaved(id: 'study-1', name: '  Warm study  ');
      final renamed = saved.renameSavedDesign(
        id: 'study-1',
        name: '  Reading room  ',
      );

      expect(saved.savedName, 'Warm study');
      expect(saved.isDirty, isFalse);
      expect(renamed.savedName, 'Reading room');
      expect(renamed.isDirty, isFalse);
      expect(
        renamed
            .setSurfaceColor(
              IllustratedRoomSurface.wall,
              RgbColor.fromHex('#010203'),
            )
            .discardChanges(),
        renamed,
      );
      expect(
        renamed.renameSavedDesign(id: 'another-id', name: 'Ignored'),
        same(renamed),
      );
    },
  );

  test(
    'deleting a saved identity keeps colored visuals as a dirty new draft',
    () {
      final saved = IllustratedRoomDraft.saved(
        template: study,
        colors: study.palette('airy-slate').colors,
        id: 'saved-1',
        name: 'Cool study',
      );
      final detached = saved.asUnsavedAfterDelete();

      expect(detached.colors, saved.colors);
      expect(detached.savedDesignId, isNull);
      expect(detached.savedName, isNull);
      expect(detached.isDirty, isTrue);
      expect(detached.canSave, isTrue);
      expect(detached.discardChanges(), IllustratedRoomDraft.grayscale(study));
    },
  );

  test(
    'deleting a saved identity from grayscale creates a clean fresh draft',
    () {
      final grayscale = IllustratedRoomDraft.saved(
        template: study,
        colors: study.defaultPalette.colors,
        id: 'saved-1',
        name: 'Saved study',
      ).resetToGrayscale();
      final detached = grayscale.asUnsavedAfterDelete();

      expect(detached, IllustratedRoomDraft.grayscale(study));
      expect(detached.isDirty, isFalse);
    },
  );

  test('wall handoff starts a detached complete recommended combination', () {
    final saved = IllustratedRoomDraft.saved(
      template: study,
      colors: study.palette('soft-linen').colors,
      id: 'saved-1',
      name: 'Warm study',
    );
    final handedOff = saved.applyWallHandoff(RgbColor.fromHex('#00FFFF'));

    expect(handedOff.colors!.wall.hex, '#00FFFF');
    expect(handedOff.colors!.ceiling.hex, '#B7C2A3');
    expect(handedOff.colors!.floor.hex, '#78866B');
    expect(handedOff.colors!.furniture.hex, '#4E5B4A');
    expect(handedOff.savedDesignId, isNull);
    expect(handedOff.isDirty, isTrue);
  });
}
