import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../application/app_preferences_providers.dart';

/// No content or native feature is mounted until stored preferences resolve.
class PreferencesStartupScreen extends ConsumerWidget {
  const PreferencesStartupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.blur_on_rounded,
                    size: AppSpacing.huge,
                    color: context.appColors.primary,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    context.l10n.appName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (preferences.hasError) ...[
                    Text(
                      context.l10n.preferencesLoadErrorTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      context.l10n.preferencesLoadErrorBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    PrimaryButton(
                      label: context.l10n.tryAgain,
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          ref.read(appPreferencesProvider.notifier).retry(),
                    ),
                  ] else ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      context.l10n.loadingPreferences,
                      textAlign: TextAlign.center,
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
