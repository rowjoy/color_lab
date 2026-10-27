import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';

Future<bool> confirmRestoreAiMasks(BuildContext context) => _confirm(
  context,
  title: 'Restore AI masks?',
  message:
      'Your manual changes will be replaced by the original automatic masks. This clears the undo history.',
  action: 'Restore',
  confirmationKey: 'confirm-room-mask-restore',
);

Future<bool> confirmReplaceRoomPhoto(
  BuildContext context, {
  bool hasUnsavedChanges = false,
}) => _confirm(
  context,
  title: 'Replace room photo?',
  message: hasUnsavedChanges
      ? context.l10n.roomProjectReplaceUnsaved
      : 'After a new photo is analyzed successfully, it replaces these masks and their undo history. Your current masks stay available if you cancel or analysis fails.',
  action: 'Choose photo',
  confirmationKey: 'confirm-room-mask-replace',
);

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  required String confirmationKey,
}) async =>
    await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      animationStyle: AppMotion.sheetAnimation(context),
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        backgroundColor: dialogContext.appColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: dialogContext.appColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: ValueKey(confirmationKey),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: dialogContext.appColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
