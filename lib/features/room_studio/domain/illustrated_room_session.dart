import 'dart:collection';

import 'illustrated_room.dart';
import 'illustrated_room_draft.dart';
import 'illustrated_room_history.dart';

final class IllustratedRoomSession {
  IllustratedRoomSession._(
    Map<String, IllustratedRoomDraft> drafts,
    this.activeTemplateId,
  ) : _drafts = Map.unmodifiable(drafts) {
    if (activeTemplateId != null && !_drafts.containsKey(activeTemplateId)) {
      throw ArgumentError.value(
        activeTemplateId,
        'activeTemplateId',
        'Must identify a retained draft',
      );
    }
  }

  factory IllustratedRoomSession.empty() => IllustratedRoomSession._({}, null);

  final Map<String, IllustratedRoomDraft> _drafts;
  final String? activeTemplateId;

  Map<String, IllustratedRoomDraft> get draftsByTemplateId =>
      UnmodifiableMapView(Map<String, IllustratedRoomDraft>.of(_drafts));

  IllustratedRoomDraft? get activeDraft =>
      activeTemplateId == null ? null : _drafts[activeTemplateId];

  IllustratedRoomDraft? draftFor(String templateId) => _drafts[templateId];

  IllustratedRoomHistory? get activeHistory => activeDraft?.history;

  IllustratedRoomHistory? historyFor(String templateId) =>
      draftFor(templateId)?.history;

  IllustratedRoomSession activate(IllustratedRoomTemplate template) {
    final drafts = Map<String, IllustratedRoomDraft>.of(_drafts);
    drafts.putIfAbsent(
      template.id,
      () => IllustratedRoomDraft.grayscale(template),
    );
    return IllustratedRoomSession._(drafts, template.id);
  }

  IllustratedRoomSession closeEditor() =>
      activeTemplateId == null ? this : IllustratedRoomSession._(_drafts, null);

  IllustratedRoomSession putDraft(
    IllustratedRoomDraft draft, {
    bool activate = true,
  }) {
    final drafts = Map<String, IllustratedRoomDraft>.of(_drafts)
      ..[draft.template.id] = draft;
    return IllustratedRoomSession._(
      drafts,
      activate ? draft.template.id : activeTemplateId,
    );
  }

  IllustratedRoomSession updateDraft(
    String templateId,
    IllustratedRoomDraft Function(IllustratedRoomDraft) update,
  ) {
    final current = _drafts[templateId];
    if (current == null) {
      throw ArgumentError.value(
        templateId,
        'templateId',
        'No retained draft exists for this template',
      );
    }
    final updated = update(current);
    if (updated.template.id != templateId) {
      throw ArgumentError.value(
        updated.template.id,
        'update',
        'Cannot replace a draft with a different template',
      );
    }
    return putDraft(updated, activate: false);
  }
}
