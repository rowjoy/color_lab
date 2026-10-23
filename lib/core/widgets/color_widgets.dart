import 'package:flutter/material.dart';
import '../theme/theme.dart';

class ColorSwatchTile extends StatelessWidget {
  const ColorSwatchTile({
    super.key,
    required this.color,
    required this.name,
    required this.hex,
    this.onTap,
  });
  final Color color;
  final String name, hex;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$name, $hex',
    button: onTap != null,
    onTap: onTap,
    excludeSemantics: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: context.appColors.shadows,
        borderRadius: BorderRadius.circular(AppRadii.swatch),
      ),
      child: Material(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.swatch),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TweenAnimationBuilder<Color?>(
                duration: AppMotion.duration(context),
                tween: ColorTween(end: color),
                builder: (_, value, _) => ColoredBox(
                  color: value ?? color,
                  child: const SizedBox(height: AppSpacing.huge * 2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      hex,
                      style: AppTypography.mono.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ColorChip extends StatelessWidget {
  const ColorChip({super.key, required this.color, this.label, this.onTap});
  final Color color;
  final String? label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    onTap: onTap,
    label:
        label ??
        'Color #${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
    excludeSemantics: true,
    child: Material(
      color: context.appColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.huge,
            minWidth: AppSpacing.huge,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppSpacing.xxxl,
                  height: AppSpacing.xxxl,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.appColors.outline),
                  ),
                ),
                if (label != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class PaletteBar extends StatelessWidget {
  const PaletteBar({
    super.key,
    required this.colors,
    this.weights,
    this.onColorTap,
    this.height = AppSpacing.huge,
  }) : assert(height >= 48);
  final List<Color> colors;
  final List<double>? weights;
  final ValueChanged<int>? onColorTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (weights != null &&
        (weights!.length != colors.length ||
            weights!.any((weight) => !weight.isFinite || weight < 0) ||
            (weights!.isNotEmpty && weights!.every((weight) => weight == 0)))) {
      throw ArgumentError.value(
        weights,
        'weights',
        'Use nonnegative finite weights with a positive total and one entry per color.',
      );
    }
    final total =
        weights?.fold(0.0, (a, b) => a + b) ?? colors.length.toDouble();
    final segments = List<Widget>.generate(colors.length, (index) {
      final share = (weights?[index] ?? 1) / total;
      return Expanded(
        flex: (share * 10000).round().clamp(1, 10000),
        child: Semantics(
          label: 'Color ${index + 1}, ${(share * 100).round()} percent',
          child: Material(
            color: colors[index],
            child: SizedBox(height: height),
          ),
        ),
      );
    });
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: colors.isEmpty
          ? SizedBox(height: height)
          : Row(children: segments),
    );
    // Preserve the weighted visualization while keeping even tiny shares accessible.
    if (onColorTap != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: bar),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < colors.length; i++)
                ColorChip(
                  color: colors[i],
                  label:
                      'Color ${i + 1} · ${(((weights?[i] ?? 1) / total) * 100).round()}%',
                  onTap: () => onColorTap!(i),
                ),
            ],
          ),
        ],
      );
    }
    return bar;
  }
}
