import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/theme/theme.dart';
import 'features/room_studio/application/room_model_download_providers.dart';
import 'features/room_studio/models/room_model_store.dart';
import 'features/settings/application/theme_mode_provider.dart';
import 'l10n/l10n.dart';

/// Production entry: no router, camera or photo recovery mounts before setup.
class ColorLabBootstrap extends ConsumerStatefulWidget {
  const ColorLabBootstrap({super.key});

  @override
  ConsumerState<ColorLabBootstrap> createState() => _ColorLabBootstrapState();
}

class _ColorLabBootstrapState extends ConsumerState<ColorLabBootstrap> {
  bool _enteredApp = false;
  bool _handoffScheduled = false;

  @override
  Widget build(BuildContext context) {
    // Latch the handoff: later model/provider updates must not reset navigation.
    if (_enteredApp) return const ColorLabApp();
    final setup = ref.watch(roomModelStartupProvider);
    final ready = setup.hasValue && !setup.isLoading && !setup.hasError;
    final progress = ref.watch(roomModelDownloadProgressProvider).asData?.value;
    if (ready && !_handoffScheduled) {
      _handoffScheduled = true;
      // Render a verified 100% frame before entering the existing app flow.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handoffScheduled = false;
        final current = ref.read(roomModelStartupProvider);
        if (current.hasValue && !current.isLoading && !current.hasError) {
          setState(() => _enteredApp = true);
        }
      });
    }
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: Duration.zero,
      home: _RoomModelSetupScreen(
        progress: progress,
        ready: ready,
        failed: setup.hasError && !setup.isLoading,
        onRetry: () => ref.invalidate(roomModelStartupProvider),
      ),
    );
  }
}

class _RoomModelSetupScreen extends StatelessWidget {
  const _RoomModelSetupScreen({
    required this.progress,
    required this.ready,
    required this.failed,
    required this.onRetry,
  });

  final RoomModelDownloadProgress? progress;
  final bool ready;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fraction = (progress?.fraction ?? 0).clamp(0.0, 1.0);
    final percent = ready ? 100 : (fraction * 100).floor().clamp(1, 99);
    final label = ready
        ? l10n.roomStudioReady
        : failed
        ? l10n.setupCouldNotFinish
        : switch (progress?.stage) {
            RoomModelDownloadStage.downloading => l10n.downloadingAiModels,
            RoomModelDownloadStage.verifying => l10n.verifyingAiModels,
            _ => l10n.checkingSavedAiModels,
          };
    final checking =
        !ready &&
        !failed &&
        (progress == null ||
            progress!.stage == RoomModelDownloadStage.idle ||
            progress!.stage == RoomModelDownloadStage.checking);
    String mib(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    failed ? Icons.cloud_off_outlined : Icons.home_outlined,
                    size: 64,
                    color: failed ? colors.error : colors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.roomStudioSetup,
                    style: text.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: text.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    l10n.progressPercent(percent),
                    style: text.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: checking
                        ? null
                        : ready
                        ? 1
                        : fraction.clamp(0.01, 0.99),
                    semanticsLabel: label,
                    semanticsValue: l10n.progressPercent(percent),
                  ),
                  const SizedBox(height: 12),
                  if (progress != null && progress!.receivedBytes > 0 && !ready)
                    Text(
                      l10n.downloadProgressMib(
                        mib(progress!.receivedBytes),
                        mib(progress!.totalBytes),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),
                  Text(
                    failed ? l10n.setupFailureHelp : l10n.setupDownloadHelp,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.roomPhotosStayOnDevice,
                    textAlign: TextAlign.center,
                  ),
                  if (failed) ...[
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.retrySetup),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
