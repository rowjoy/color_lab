import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../application/room_project_session_controller.dart';

class RoomProjectSaveStatusView extends StatelessWidget {
  const RoomProjectSaveStatusView({
    super.key,
    required this.session,
    required this.onRetry,
  });

  final RoomProjectSession session;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = switch (session.saveStatus) {
      RoomProjectSaveStatus.saving => l10n.roomProjectSaving,
      RoomProjectSaveStatus.saved => l10n.roomProjectSaved,
      RoomProjectSaveStatus.conflict => l10n.roomProjectSaveConflict,
      RoomProjectSaveStatus.failed =>
        session.saveError == RoomProjectSaveError.limit
            ? l10n.roomProjectSaveLimit
            : l10n.roomProjectSaveFailed,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: const ValueKey('room-project-save-status'),
          liveRegion: true,
          child: Text(label),
        ),
        if (session.saveStatus == RoomProjectSaveStatus.failed ||
            session.saveStatus == RoomProjectSaveStatus.conflict) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            key: const ValueKey('room-project-retry-save'),
            label: l10n.roomProjectRetrySave,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}
