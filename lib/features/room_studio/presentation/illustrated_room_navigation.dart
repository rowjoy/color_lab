import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_models.dart';
import '../../learning/domain/learning_palette_copy.dart';
import '../application/illustrated_room_controller.dart';
import '../application/room_color_provider.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';
import '../domain/saved_room_design.dart';
import 'saved_room_designs_sheet.dart';

enum _DraftReplacementChoice { saveCurrent, replaceDraft }

Future<bool> openIllustratedSavedDesign(
  BuildContext context,
  SavedRoomDesign design,
) async {
  final template = IllustratedRoomCatalog.maybeById(design.templateId);
  if (template == null || !context.mounted) return false;
  final container = ProviderScope.containerOf(context, listen: false);
  final controller = container.read(illustratedRoomProvider.notifier);
  final accepted = await _replaceRetainedDraft(
    context,
    templateId: template.id,
    replace: ({required replaceDirty, savedCurrent}) {
      final selected = savedCurrent?.id == design.id ? savedCurrent! : design;
      controller.openDesign(selected, replaceDirty: replaceDirty);
    },
  );
  if (!accepted || !context.mounted) return false;
  _openEditorRoute(context, template.id);
  return true;
}

Future<bool> openStudyWallHandoff(BuildContext context, RgbColor color) async {
  if (!context.mounted) return false;
  final container = ProviderScope.containerOf(context, listen: false);
  final controller = container.read(illustratedRoomProvider.notifier);
  final accepted = await _replaceRetainedDraft(
    context,
    templateId: IllustratedRoomCatalog.study.id,
    replace: ({required replaceDirty, savedCurrent}) =>
        controller.applyWallHandoff(color, replaceDirty: replaceDirty),
  );
  if (!accepted || !context.mounted) return false;
  container.read(roomColorProvider.notifier).setColor(color);
  _openEditorRoute(context, IllustratedRoomCatalog.study.id);
  return true;
}

Future<bool> openLearningPaletteInIllustratedRoom(
  BuildContext context,
  LearningPaletteCopy payload,
) async {
  if (!context.mounted ||
      !isLearningPaletteDestinationAvailable(
        LearningPaletteDestination.illustratedRoom,
      )) {
    return false;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final controller = container.read(illustratedRoomProvider.notifier);
  final accepted = await _replaceRetainedDraft(
    context,
    templateId: IllustratedRoomCatalog.study.id,
    replace: ({required replaceDirty, savedCurrent}) =>
        controller.applyLearningPalette(payload, replaceDirty: replaceDirty),
  );
  if (!accepted || !context.mounted) return false;
  _openEditorRoute(context, IllustratedRoomCatalog.study.id);
  return true;
}

Future<bool> _replaceRetainedDraft(
  BuildContext context, {
  required String templateId,
  required void Function({
    required bool replaceDirty,
    SavedRoomDesign? savedCurrent,
  })
  replace,
}) async {
  try {
    replace(replaceDirty: false, savedCurrent: null);
    return true;
  } on IllustratedRoomDraftConflict {
    // The controller owns the conflict decision. Read its exact target only
    // after the guarded mutation rejects the replacement.
  }

  if (!context.mounted) return false;
  final container = ProviderScope.containerOf(context, listen: false);
  final draft = container.read(illustratedRoomProvider).draftFor(templateId);
  if (draft == null || !draft.isDirty) return false;
  final choice = await _showDraftReplacementDialog(context, draft);
  if (choice == null || !context.mounted) return false;

  if (choice == _DraftReplacementChoice.saveCurrent) {
    final initialName =
        draft.savedName ??
        defaultRoomDesignName(
          draft.template,
          container.read(roomDesignClockProvider)(),
        );
    final saved = await showSaveRoomDesignDialog(
      context,
      initialName: initialName,
      templateId: templateId,
    );
    if (saved == null || !context.mounted) return false;
    try {
      replace(replaceDirty: false, savedCurrent: saved);
      return true;
    } on IllustratedRoomDraftConflict {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'The room draft changed while saving. Review it before replacing.',
          ),
        ),
      );
      return false;
    }
  }

  replace(replaceDirty: true, savedCurrent: null);
  return true;
}

Future<_DraftReplacementChoice?> _showDraftReplacementDialog(
  BuildContext context,
  IllustratedRoomDraft draft,
) => showDialog<_DraftReplacementChoice>(
  context: context,
  useRootNavigator: true,
  builder: (context) => AlertDialog(
    title: const Text('Replace this room draft?'),
    content: Text(
      draft.canSave
          ? '${draft.template.title} has unsaved changes. Save them first, '
                'replace the draft, or cancel.'
          : '${draft.template.title} has unsaved black-and-white changes. '
                'Replace the draft or cancel.',
    ),
    actions: [
      TextButton(
        key: const ValueKey('room-draft-conflict-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(
        key: const ValueKey('room-draft-conflict-replace'),
        onPressed: () =>
            Navigator.of(context).pop(_DraftReplacementChoice.replaceDraft),
        child: const Text('Replace draft'),
      ),
      if (draft.canSave)
        TextButton(
          key: const ValueKey('room-draft-conflict-save'),
          onPressed: () =>
              Navigator.of(context).pop(_DraftReplacementChoice.saveCurrent),
          child: const Text('Save current'),
        ),
    ],
  ),
);

void _openEditorRoute(BuildContext context, String templateId) {
  final router = GoRouter.of(context);
  final destination = '/room/illustrated/$templateId';
  final current = router.state.uri.path;
  if (current == destination) return;
  if (current.startsWith('/room/illustrated/')) {
    unawaited(router.replace<void>(destination));
  } else {
    unawaited(router.push<void>(destination));
  }
}
