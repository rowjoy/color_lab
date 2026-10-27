import 'package:flutter/material.dart';

import '../../../core/layout/adaptive_page.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../settings/presentation/settings_sheet.dart';

class StudioPage extends StatelessWidget {
  const StudioPage({super.key, required this.name, required this.children});

  final String name;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppScaffold(
    useSafeArea: false,
    resizeToAvoidBottomInset: false,
    body: AdaptivePage(
      key: ValueKey('screen-$name'),
      maxContentWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.blur_on_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: AppSpacing.xxxl,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.l10n.appName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconCircleButton(
                icon: Icons.tune_rounded,
                label: context.l10n.appearanceSettings,
                onPressed: () => showAppSettings(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          ...children,
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    ),
  );
}

class StudioHeading extends StatelessWidget {
  const StudioHeading({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
  });
  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          letterSpacing: 2,
          color: context.appColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(title, style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: AppSpacing.md),
      Text(
        description,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),
    ],
  );
}

class StudioCard extends StatelessWidget {
  const StudioCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.xl,
  });
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
    ),
    child: child,
  );
}
