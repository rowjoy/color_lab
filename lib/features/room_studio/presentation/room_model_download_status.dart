import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../models/room_model_store.dart';

class RoomModelDownloadStatus extends StatelessWidget {
  const RoomModelDownloadStatus({required this.progress, super.key});

  final RoomModelDownloadProgress progress;

  @override
  Widget build(BuildContext context) {
    if (!progress.busy) return const SizedBox.shrink();
    final downloading = progress.stage == RoomModelDownloadStage.downloading;
    final label = switch (progress.stage) {
      RoomModelDownloadStage.downloading => 'Downloading AI models…',
      RoomModelDownloadStage.verifying => 'Verifying AI models…',
      _ => 'Checking saved AI models…',
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
              '${mib(progress.receivedBytes)} / ${mib(progress.totalBytes)} MiB · ${(progress.fraction * 100).floor()}%',
            ),
          if (progress.modelName != null)
            Text(
              progress.modelName == 'room_seg.tflite'
                  ? 'Room surfaces'
                  : 'Foreground depth protection',
            ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Your photo stays on this device. Once models are saved, AI works offline.',
          ),
        ],
      ),
    );
  }
}
