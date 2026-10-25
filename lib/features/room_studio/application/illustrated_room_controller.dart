import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_models.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';
import '../domain/illustrated_room_session.dart';
import '../domain/room_design_repository.dart';
import '../domain/saved_room_design.dart';
import 'room_designs_providers.dart';

final roomDesignClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final class IllustratedRoomDraftConflict implements Exception {
  const IllustratedRoomDraftConflict(this.templateId);

  final String templateId;

  @override
  String toString() =>
      'IllustratedRoomDraftConflict: $templateId has unsaved changes';
}

final illustratedRoomProvider =
    NotifierProvider<IllustratedRoomController, IllustratedRoomSession>(
      IllustratedRoomController.new,
    );

class IllustratedRoomController extends Notifier<IllustratedRoomSession> {
  @override
  IllustratedRoomSession build() =>
      IllustratedRoomSession.empty().activate(IllustratedRoomCatalog.study);

  void openTemplate(IllustratedRoomTemplate template) {
    state = state.activate(template);
  }

  void closeEditor() {
    state = state.closeEditor();
  }

  void discardActiveChanges() {
    final draft = state.activeDraft;
    if (draft == null) return;
    state = state.updateDraft(draft.template.id, (_) => draft.discardChanges());
  }

  bool hasDirtyDraft(String templateId) =>
      state.draftFor(templateId)?.isDirty ?? false;

  void applyPalette(String paletteId) {
    _updateActive((draft) => draft.applyPalette(paletteId));
  }

  void setSurfaceColor(IllustratedRoomSurface surface, RgbColor color) {
    _updateActive((draft) => draft.setSurfaceColor(surface, color));
  }

  void resetToGrayscale() {
    _updateActive((draft) => draft.resetToGrayscale());
  }

  void openDesign(SavedRoomDesign design, {bool replaceDirty = false}) {
    final template = IllustratedRoomCatalog.maybeById(design.templateId);
    if (template == null) {
      throw ArgumentError.value(
        design.templateId,
        'templateId',
        'The room template is unavailable',
      );
    }
    _guardReplacement(template.id, replaceDirty: replaceDirty);
    state = state.putDraft(
      IllustratedRoomDraft.saved(
        template: template,
        colors: design.colors,
        id: design.id,
        name: design.name,
      ),
    );
  }

  void applyWallHandoff(RgbColor color, {bool replaceDirty = false}) {
    final template = IllustratedRoomCatalog.study;
    _guardReplacement(template.id, replaceDirty: replaceDirty);
    state = state.putDraft(
      IllustratedRoomDraft.grayscale(template).applyWallHandoff(color),
    );
  }

  Future<SavedRoomDesign> saveDesign(String name, {String? templateId}) async {
    final targetId = templateId ?? state.activeTemplateId;
    if (targetId == null) {
      throw StateError('Open a room before saving.');
    }
    final captured = state.draftFor(targetId);
    if (captured == null) {
      throw ArgumentError.value(
        targetId,
        'templateId',
        'No retained draft exists for this template',
      );
    }
    final colors = captured.colors;
    if (colors == null) {
      throw StateError('Choose room colors before saving.');
    }

    if (!captured.isDirty && captured.savedDesignId != null) {
      final designs = await ref.read(savedRoomDesignsProvider.future);
      for (final design in designs) {
        if (design.id == captured.savedDesignId) return design;
      }
      throw const RoomDesignStorageException();
    }

    final saved = await ref
        .read(savedRoomDesignsProvider.notifier)
        .saveDesign(
          existingId: captured.savedDesignId,
          name: name,
          templateId: captured.template.id,
          colors: colors,
        );
    if (ref.mounted && state.draftFor(targetId) == captured) {
      state = state.putDraft(
        captured.markSaved(id: saved.id, name: saved.name),
        activate: false,
      );
    }
    return saved;
  }

  Future<void> deleteDesign(String id) async {
    await ref.read(savedRoomDesignsProvider.notifier).deleteDesign(id);
    if (!ref.mounted) return;
    var next = state;
    for (final entry in state.draftsByTemplateId.entries) {
      if (entry.value.savedDesignId == id) {
        next = next.updateDraft(
          entry.key,
          (draft) => draft.asUnsavedAfterDelete(),
        );
      }
    }
    state = next;
  }

  Future<SavedRoomDesign> renameDesign(String id, String name) async {
    final renamed = await ref
        .read(savedRoomDesignsProvider.notifier)
        .renameDesign(id, name);
    if (!ref.mounted) return renamed;
    var next = state;
    for (final entry in state.draftsByTemplateId.entries) {
      if (entry.value.savedDesignId == id) {
        next = next.updateDraft(
          entry.key,
          (draft) => draft.renameSavedDesign(id: id, name: renamed.name),
        );
      }
    }
    state = next;
    return renamed;
  }

  void _guardReplacement(String templateId, {required bool replaceDirty}) {
    if (!replaceDirty && hasDirtyDraft(templateId)) {
      throw IllustratedRoomDraftConflict(templateId);
    }
  }

  void _updateActive(
    IllustratedRoomDraft Function(IllustratedRoomDraft) update,
  ) {
    final draft = state.activeDraft;
    if (draft == null) throw StateError('Open a room before editing.');
    state = state.updateDraft(draft.template.id, update);
  }
}

String defaultRoomDesignName(IllustratedRoomTemplate template, DateTime date) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${template.title} - ${date.year}-${twoDigits(date.month)}-'
      '${twoDigits(date.day)}';
}
