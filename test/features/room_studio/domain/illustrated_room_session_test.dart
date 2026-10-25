import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'six templates retain independent drafts across activation and close',
    () {
      var session = IllustratedRoomSession.empty();

      for (final room in IllustratedRoomCatalog.all) {
        session = session.activate(room);
        session = session.updateDraft(
          room.id,
          (draft) => draft.applyPalette(room.defaultPaletteId),
        );
      }

      expect(session.draftsByTemplateId.keys, [
        'living',
        'bedroom',
        'study',
        'dining',
        'kitchen',
        'bathroom',
      ]);
      expect(session.activeTemplateId, 'bathroom');
      expect(session.activeDraft?.template.id, 'bathroom');
      for (final room in IllustratedRoomCatalog.all) {
        expect(
          session.draftFor(room.id)?.sourcePaletteId,
          room.defaultPaletteId,
        );
      }

      final closed = session.closeEditor();
      expect(closed.activeTemplateId, isNull);
      expect(closed.activeDraft, isNull);
      expect(closed.draftsByTemplateId, session.draftsByTemplateId);
      expect(
        closed.activate(IllustratedRoomCatalog.study).activeDraft,
        session.draftFor('study'),
      );
    },
  );

  test('exposed draft maps are immutable snapshots', () {
    final session = IllustratedRoomSession.empty().activate(
      IllustratedRoomCatalog.study,
    );
    final exposed = session.draftsByTemplateId;

    expect(() => exposed.clear(), throwsUnsupportedError);
    final updated = session.updateDraft(
      'study',
      (draft) => draft.applyPalette('warm-natural'),
    );
    expect(exposed['study']?.mode.name, 'grayscale');
    expect(updated.draftFor('study')?.sourcePaletteId, 'warm-natural');
  });

  test('putDraft can replace a draft without changing current activation', () {
    final living = IllustratedRoomCatalog.living;
    final study = IllustratedRoomCatalog.study;
    final session = IllustratedRoomSession.empty()
        .activate(living)
        .putDraft(sessionDraft(study), activate: false);

    expect(session.activeTemplateId, 'living');
    expect(session.draftFor('study')?.sourcePaletteId, 'cool-airy');
  });

  test('invalid updates fail atomically', () {
    final session = IllustratedRoomSession.empty().activate(
      IllustratedRoomCatalog.study,
    );

    expect(
      () => session.updateDraft('missing', (draft) => draft),
      throwsArgumentError,
    );
    expect(
      () => session.updateDraft(
        'study',
        (_) => sessionDraft(IllustratedRoomCatalog.living),
      ),
      throwsArgumentError,
    );
    expect(session.draftsByTemplateId.keys, ['study']);
    expect(session.activeDraft?.mode.name, 'grayscale');
  });
}

IllustratedRoomDraft sessionDraft(IllustratedRoomTemplate template) =>
    IllustratedRoomDraft.grayscale(template).applyPalette('cool-airy');
