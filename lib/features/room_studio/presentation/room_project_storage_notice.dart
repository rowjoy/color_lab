import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../domain/room_project.dart';
import 'room_project_actions.dart';

class RoomProjectStorageNotice extends StatelessWidget {
  const RoomProjectStorageNotice({super.key, required this.warning});
  final RoomProjectRecoveryWarning warning;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Text(
      warning.reason == RoomProjectRecoveryReason.earlierRevision
          ? context.l10n.roomProjectRecovered
          : context.l10n.roomProjectThumbnailWarning,
    ),
  );
}

String roomProjectActionFailureText(
  BuildContext context,
  RoomProjectActionFailure failure,
) {
  final l10n = context.l10n;
  return switch (failure) {
    RoomProjectActionFailure.busy => l10n.roomProjectActionBusy,
    RoomProjectActionFailure.unsaved => l10n.roomProjectActionUnsaved,
    RoomProjectActionFailure.conflict => l10n.roomProjectActionConflict,
    RoomProjectActionFailure.unavailable => l10n.roomProjectActionUnavailable,
    RoomProjectActionFailure.storage => l10n.roomProjectActionStorage,
    RoomProjectActionFailure.invalidName => l10n.roomProjectNameInvalid,
    RoomProjectActionFailure.limit => l10n.roomProjectActionLimit,
  };
}
