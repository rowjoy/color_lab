import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../domain/room_mask_state.dart';

Future<bool> confirmRestoreAiMasks(BuildContext context) => _confirm(
  context,
  title: context.l10n.roomRestoreTitle,
  message: context.l10n.roomRestoreMessage,
  action: context.l10n.roomRestoreAction,
  confirmationKey: 'confirm-room-mask-restore',
);

Future<bool> confirmReplaceRoomPhoto(
  BuildContext context, {
  bool hasUnsavedChanges = false,
}) => _confirm(
  context,
  title: context.l10n.roomReplaceTitle,
  message: hasUnsavedChanges
      ? context.l10n.roomProjectReplaceUnsaved
      : context.l10n.roomReplaceMessage,
  action: context.l10n.roomChoosePhoto,
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
            child: Text(dialogContext.l10n.roomDialogCancel),
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

enum RoomFailureRecovery {
  settings,
  gallery,
  smaller,
  supported,
  picker,
  storage,
  model,
  analysis,
}

(String, String, RoomFailureRecovery) roomFailureCopy(
  AppLocalizations l10n,
  RoomMaskFailureKind? failure,
) => switch (failure) {
  RoomMaskFailureKind.permissionDenied => (
    l10n.roomPhotoPermission,
    l10n.roomOpenSettings,
    RoomFailureRecovery.settings,
  ),
  RoomMaskFailureKind.cameraUnavailable => (
    l10n.roomCameraUnavailable,
    l10n.roomChoosePhoto,
    RoomFailureRecovery.gallery,
  ),
  RoomMaskFailureKind.acquisitionUnavailable => (
    l10n.roomPickerUnavailable,
    l10n.roomTryAgain,
    RoomFailureRecovery.picker,
  ),
  RoomMaskFailureKind.unsupported => (
    l10n.roomPhotoUnsupported,
    l10n.roomChooseSupported,
    RoomFailureRecovery.supported,
  ),
  RoomMaskFailureKind.invalidImage => (
    l10n.roomPhotoInvalid,
    l10n.roomChooseSupported,
    RoomFailureRecovery.supported,
  ),
  RoomMaskFailureKind.tooLarge => (
    l10n.roomPhotoTooLarge,
    l10n.roomChooseSmaller,
    RoomFailureRecovery.smaller,
  ),
  RoomMaskFailureKind.preparation => (
    l10n.roomPhotoPreparation,
    l10n.roomChooseSupported,
    RoomFailureRecovery.supported,
  ),
  RoomMaskFailureKind.storage => (
    l10n.roomPhotoStorage,
    l10n.roomRetryPhotoStorage,
    RoomFailureRecovery.storage,
  ),
  RoomMaskFailureKind.modelUnavailable => (
    l10n.roomModelUnavailable,
    l10n.roomModelSetupAction,
    RoomFailureRecovery.model,
  ),
  RoomMaskFailureKind.incompatibleModel => (
    l10n.roomModelIncompatible,
    l10n.roomModelSetupAction,
    RoomFailureRecovery.model,
  ),
  RoomMaskFailureKind.invalidOutput => (
    l10n.roomAnalysisInvalid,
    l10n.roomRetryAnalysis,
    RoomFailureRecovery.analysis,
  ),
  _ => (
    l10n.roomAnalysisFailed,
    l10n.roomRetryAnalysis,
    RoomFailureRecovery.analysis,
  ),
};
