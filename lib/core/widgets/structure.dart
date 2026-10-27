import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.useSafeArea = true,
    this.resizeToAvoidBottomInset = true,
  });
  final Widget body;
  final Widget? bottomNavigationBar;
  final bool useSafeArea;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.appColors.background,
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    body: useSafeArea ? SafeArea(child: body) : body,
    bottomNavigationBar: bottomNavigationBar,
  );
}

/// Floating chrome for use over photographs or camera content.
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.borderRadius = AppRadii.pill,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: ColoredBox(
        color: context.appColors.surface.withValues(alpha: .7),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.md),
          trailing!,
        ],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppStatusView(
    title: title,
    message: message,
    action: action,
    visual: Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: context.appColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Icon(
        icon,
        size: AppSpacing.huge,
        color: context.appColors.primary,
      ),
    ),
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => AppStatusView(
    title: title,
    message: message,
    liveRegion: true,
    visual: const SizedBox.square(
      dimension: AppTouchTargets.minimum,
      child: CircularProgressIndicator(),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    required this.message,
    this.action,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppStatusView(
    title: title,
    message: message,
    action: action,
    liveRegion: true,
    visual: Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: context.appColors.error.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppRadii.large),
      ),
      child: Icon(
        Icons.error_outline_rounded,
        size: AppSpacing.huge,
        color: context.appColors.error,
      ),
    ),
  );
}

class AppStatusView extends StatelessWidget {
  const AppStatusView({
    super.key,
    required this.visual,
    required this.title,
    required this.message,
    this.action,
    this.liveRegion = false,
  });

  final Widget visual;
  final String title;
  final String message;
  final Widget? action;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: liveRegion,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              visual,
              const SizedBox(height: AppSpacing.xxl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.xxl),
                action!,
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({super.key, required this.child, this.title});
  final Widget child;
  final String? title;

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
  }) => showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: AppMotion.sheetAnimation(context),
    builder: (_) => AppBottomSheet(title: title, child: child),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Semantics(
                header: true,
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            child,
          ],
        ),
      ),
    ),
  );
}
