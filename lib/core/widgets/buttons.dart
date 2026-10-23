import 'package:flutter/material.dart';
import '../theme/theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  @override
  Widget build(BuildContext context) => _AppButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    isLoading: isLoading,
    primary: true,
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  @override
  Widget build(BuildContext context) => _AppButton(
    label: label,
    onPressed: onPressed,
    icon: icon,
    isLoading: isLoading,
    primary: false,
  );
}

class _AppButton extends StatelessWidget {
  const _AppButton({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.isLoading,
    required this.primary,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading, primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final enabled = onPressed != null && !isLoading;
    final foreground = enabled || isLoading
        ? (primary ? AppColors.onPrimary : colors.textPrimary)
        : colors.textSecondary;
    return Semantics(
      button: true,
      enabled: enabled,
      liveRegion: isLoading,
      onTap: enabled ? onPressed : null,
      label: isLoading ? '$label, loading' : label,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.huge),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.medium),
            gradient: primary && (enabled || isLoading)
                ? colors.accentGradient
                : null,
            color: !primary || !enabled ? colors.surfaceElevated : null,
          ),
          child: Material(
            color: primary && (enabled || isLoading)
                ? AppColors.light.textPrimary.withValues(alpha: .28)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.medium),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(AppRadii.medium),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading) ...[
                      SizedBox.square(
                        dimension: AppSpacing.xl,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                          value: MediaQuery.disableAnimationsOf(context)
                              ? .7
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ] else if (icon != null) ...[
                      Icon(icon, color: foreground),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: foreground),
                      ),
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

class IconCircleButton extends StatelessWidget {
  const IconCircleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: isLoading ? '$label, loading' : label,
    onPressed: isLoading ? null : onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size.square(AppSpacing.huge),
      backgroundColor: context.appColors.surfaceElevated,
      foregroundColor: context.appColors.textPrimary,
    ),
    icon: isLoading
        ? SizedBox.square(
            dimension: AppSpacing.xl,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.appColors.primary,
              value: MediaQuery.disableAnimationsOf(context) ? .7 : null,
            ),
          )
        : Icon(icon),
  );
}
