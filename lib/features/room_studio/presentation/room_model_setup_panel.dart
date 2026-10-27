import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../application/room_model_setup_controller.dart';
import '../models/room_model_store.dart';
import 'room_model_download_status.dart';

/// Guards only photo acquisition. The URI stays /room/masks for the editor's
/// lifecycle checks; illustrated routes never build this widget.
class RoomModelSetupGate extends ConsumerStatefulWidget {
  const RoomModelSetupGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<RoomModelSetupGate> createState() => _RoomModelSetupGateState();
}

class _RoomModelSetupGateState extends ConsumerState<RoomModelSetupGate> {
  bool _checked = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(roomModelSetupProvider.notifier).check();
      if (mounted) setState(() => _checked = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(roomModelSetupProvider);
    return _checked && setup.canEnter
        ? widget.child
        : const RoomModelSetupPanel();
  }
}

class RoomModelSetupPanel extends ConsumerWidget {
  const RoomModelSetupPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(roomModelSetupProvider);
    final controller = ref.read(roomModelSetupProvider.notifier);
    final l10n = context.l10n;
    void leave(String route) {
      if (setup.busy) controller.cancel();
      context.go(route);
    }

    final total = roomModelArtifacts.fold<int>(
      0,
      (sum, artifact) => sum + artifact.bytes,
    );
    final availability = setup.availability;
    final retryable =
        availability == RoomModelAvailability.failed ||
        availability == RoomModelAvailability.storageFull ||
        availability == RoomModelAvailability.cancelled;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave('/rooms');
      },
      child: Scaffold(
        key: const ValueKey('room-model-setup'),
        appBar: AppBar(
          title: Text(l10n.roomSetupTitle),
          leading: IconButton(
            tooltip: l10n.back,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => leave('/rooms'),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.roomSetupIntro,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.roomSetupSize(
                        NumberFormat.decimalPattern(
                          l10n.localeName,
                        ).format(total),
                        (total / (1024 * 1024)).toStringAsFixed(1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.roomSetupPrivacy),
                    const SizedBox(height: 12),
                    Text(l10n.roomSetupOffline),
                    const SizedBox(height: 24),
                    if (setup.busy) ...[
                      RoomModelDownloadStatus(
                        progress: RoomModelDownloadProgress(
                          stage: switch (availability) {
                            RoomModelAvailability.downloading =>
                              RoomModelDownloadStage.downloading,
                            RoomModelAvailability.verifying =>
                              RoomModelDownloadStage.verifying,
                            _ => RoomModelDownloadStage.checking,
                          },
                          receivedBytes: setup.progress.receivedBytes,
                          totalBytes: setup.progress.totalBytes,
                          modelName: setup.progress.modelName,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        key: const ValueKey('room-setup-cancel'),
                        onPressed: controller.cancel,
                        child: Text(l10n.cancel),
                      ),
                    ] else ...[
                      if (availability == RoomModelAvailability.ready) ...[
                        Text(l10n.roomSetupReady),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const ValueKey('room-setup-continue'),
                          onPressed: controller.continueWithCachedModels,
                          child: Text(l10n.roomSetupContinue),
                        ),
                      ] else if (retryable) ...[
                        Semantics(
                          liveRegion: true,
                          child: Text(switch (availability) {
                            RoomModelAvailability.storageFull =>
                              l10n.roomSetupStorageFull,
                            RoomModelAvailability.cancelled =>
                              l10n.roomSetupCancelled,
                            _ => l10n.roomSetupFailure,
                          }),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const ValueKey('room-setup-retry'),
                          onPressed: controller.retry,
                          child: Text(l10n.roomSetupRetry),
                        ),
                      ] else
                        FilledButton(
                          key: const ValueKey('room-setup-download'),
                          onPressed: controller.download,
                          child: Text(l10n.roomSetupDownload),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const ValueKey('room-setup-later'),
                        onPressed: () => leave('/rooms'),
                        child: Text(l10n.roomSetupLater),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      key: const ValueKey('room-setup-illustrated'),
                      onPressed: () => leave('/room/illustrated'),
                      child: Text(l10n.roomTryIllustrated),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
