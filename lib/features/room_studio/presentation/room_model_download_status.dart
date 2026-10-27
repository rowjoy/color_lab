import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../models/room_model_store.dart';

class RoomModelDownloadStatus extends StatelessWidget {
  const RoomModelDownloadStatus({required this.progress, super.key});

  final RoomModelDownloadProgress progress;

  @override
  Widget build(BuildContext context) {
    if (!progress.busy) return const SizedBox.shrink();
    final downloading = progress.stage == RoomModelDownloadStage.downloading;
    final label = switch (progress.stage) {
      RoomModelDownloadStage.downloading => context.l10n.roomModelsDownloading,
      RoomModelDownloadStage.verifying => context.l10n.roomModelsVerifying,
      _ => context.l10n.roomModelsChecking,
    };
    String mib(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
    return Semantics(
      liveRegion: true,
      child: Column(
        key: const ValueKey('room-model-download-status'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(
            value: downloading ? progress.fraction : null,
            semanticsLabel: label,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (downloading)
            Text(
              context.l10n.roomModelsProgress(
                mib(progress.receivedBytes),
                mib(progress.totalBytes),
                (progress.fraction * 100).floor().toString(),
              ),
            ),
          if (progress.modelName != null)
            Text(
              progress.modelName == 'room_seg.tflite'
                  ? context.l10n.roomModelsSurfaces
                  : context.l10n.roomModelsDepth,
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(context.l10n.roomModelsPrivacyOffline),
        ],
      ),
    );
  }
}
