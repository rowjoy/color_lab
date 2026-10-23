import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/domain/saved_color.dart';
import '../../history/presentation/save_color_actions.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/mixer_controller.dart';
import '../domain/mixer_state.dart';
import 'mixer_color_picker.dart';

class MixerScreen extends ConsumerStatefulWidget {
  const MixerScreen({super.key});
  @override
  ConsumerState<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends ConsumerState<MixerScreen> {
  bool _picking = false;

  Future<void> _chooseColor([MixerIngredient? ingredient]) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final color = await showMixerColorPicker(
        context,
        initialColor: ingredient?.color,
      );
      if (!mounted || color == null) return;
      final controller = ref.read(mixerProvider.notifier);
      if (ingredient == null) {
        controller.addColor(color);
      } else {
        controller.setColor(ingredient.id, color);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset this mix?'),
        content: const Text(
          'Return to Lilac and Butter at equal parts. Your saved colors will stay in your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('confirm-reset-mix'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) ref.read(mixerProvider.notifier).reset();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/lab');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mix = ref.watch(mixerProvider);
    final controller = ref.read(mixerProvider.notifier);
    final result = mix.selectedResult;
    final name = result == null
        ? null
        : ref.watch(colorNamerProvider).asData?.value.nearest(result).name;
    final fractions = mix.fractions;
    final active = [
      for (var i = 0; i < mix.ingredients.length; i++)
        if (mix.ingredients[i].weight > 0) i,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color mixer'),
        leading: IconCircleButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back to Lab',
          onPressed: _back,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: IconCircleButton(
              icon: Icons.restart_alt_rounded,
              label: 'Reset mix',
              onPressed: _picking ? null : _reset,
            ),
          ),
        ],
      ),
      bottomNavigationBar: result == null
          ? null
          : _LiveResult(
              color: result,
              space: mix.space,
              onDetails: () =>
                  showColorDetails(context, result, source: ColorSource.lab),
            ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('screen-Mixer'),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StudioHeading(
                    eyebrow: 'A little of this. A little of that.',
                    title: 'Find your happy medium.',
                    description:
                        'Choose your colors. Adjust the parts. Watch a new shade take shape.',
                  ),
                  SegmentedButton<MixingSpace>(
                    segments: const [
                      ButtonSegment(
                        value: MixingSpace.lab,
                        label: Text('LAB', key: ValueKey('mixer-space-lab')),
                      ),
                      ButtonSegment(
                        value: MixingSpace.rgb,
                        label: Text('RGB', key: ValueKey('mixer-space-rgb')),
                      ),
                    ],
                    selected: {mix.space},
                    onSelectionChanged: (selection) =>
                        controller.setSpace(selection.single),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    mix.space == MixingSpace.lab
                        ? 'LAB averages perceptual lightness and color coordinates.'
                        : 'RGB averages sRGB display channels, not linear-light values.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (result == null)
                    StudioCard(
                      child: Column(
                        key: const ValueKey('mixer-empty-result'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.water_drop_outlined,
                            size: AppSpacing.huge,
                            color: context.appColors.textSecondary,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Give at least one color a few parts.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                            'Every ratio is zero. Move a slider below to start mixing again.',
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Semantics(
                      button: true,
                      label:
                          '${mix.space == MixingSpace.lab ? 'LAB' : 'RGB'} result ${result.hex}. Open color details.',
                      child: InkWell(
                        key: const ValueKey('mixer-result-swatch'),
                        borderRadius: BorderRadius.circular(AppRadii.swatch),
                        onTap: () => showColorDetails(
                          context,
                          result,
                          source: ColorSource.lab,
                          heroTag: 'mixer-selected-result',
                        ),
                        child: Hero(
                          tag: 'mixer-selected-result',
                          child: TweenAnimationBuilder<Color?>(
                            tween: ColorTween(end: displayColor(result)),
                            duration: AppMotion.duration(context),
                            builder: (context, color, child) => Container(
                              height: 160,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(
                                  AppRadii.swatch,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      name ?? 'Your new shade',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      result.hex,
                      key: const ValueKey('mixer-result-hex'),
                      style: AppTypography.mono.copyWith(
                        color: context.appColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SaveColorActions(
                      color: result,
                      name: name,
                      source: ColorSource.lab,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Color details',
                      icon: Icons.info_outline_rounded,
                      onPressed: () => showColorDetails(
                        context,
                        result,
                        source: ColorSource.lab,
                        heroTag: 'mixer-selected-result',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const SectionHeader(
                      title: 'Same colors. Different character.',
                      subtitle:
                          'Compare both blends. Tap to choose your result.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final stack =
                            MediaQuery.textScalerOf(context).scale(14) > 20 ||
                            constraints.maxWidth < 300;
                        final width = stack
                            ? constraints.maxWidth
                            : (constraints.maxWidth - AppSpacing.md) / 2;
                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            for (final space in MixingSpace.values)
                              SizedBox(
                                width: width,
                                child: _ComparisonCard(
                                  space: space,
                                  color: space == MixingSpace.lab
                                      ? mix.labResult!
                                      : mix.rgbResult!,
                                  selected: mix.space == space,
                                  onTap: () => controller.setSpace(space),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxxl),
                  const SectionHeader(
                    title: 'Your ingredients',
                    subtitle:
                        'Parts are relative. Their percentages always add up to the whole.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (active.isNotEmpty) ...[
                    PaletteBar(
                      colors: [
                        for (final index in active)
                          displayColor(mix.ingredients[index].color),
                      ],
                      weights: [for (final index in active) fractions[index]],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                  for (var index = 0; index < mix.ingredients.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _IngredientCard(
                        key: ValueKey(
                          'mixer-input-${mix.ingredients[index].id}',
                        ),
                        ingredient: mix.ingredients[index],
                        number: index + 1,
                        fraction: fractions[index],
                        onEdit: _picking
                            ? null
                            : () => _chooseColor(mix.ingredients[index]),
                        onRemove: mix.ingredients.length <= 2 || _picking
                            ? null
                            : () => controller.removeColor(
                                mix.ingredients[index].id,
                              ),
                        onWeight: (value) => controller.setWeight(
                          mix.ingredients[index].id,
                          value,
                        ),
                      ),
                    ),
                  SecondaryButton(
                    label: 'Add a color',
                    icon: Icons.add_rounded,
                    onPressed: _picking ? null : _chooseColor,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Digital color blending, not a paint recipe. This mix stays while you explore; save the result to keep its color in your library.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps the actual selected output in view while editing any ingredient.
class _LiveResult extends StatelessWidget {
  const _LiveResult({
    required this.color,
    required this.space,
    required this.onDetails,
  });
  final RgbColor color;
  final MixingSpace space;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.appColors.surface,
      border: Border(top: BorderSide(color: context.appColors.outline)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.huge,
              height: AppSpacing.huge,
              decoration: BoxDecoration(
                color: displayColor(color),
                borderRadius: BorderRadius.circular(AppRadii.small),
                border: Border.all(color: context.appColors.outline),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    space == MixingSpace.lab ? 'LAB result' : 'RGB result',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  Text(
                    color.hex,
                    key: const ValueKey('mixer-live-hex'),
                    style: AppTypography.mono.copyWith(
                      color: context.appColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconCircleButton(
              icon: Icons.open_in_new_rounded,
              label: 'View mixed color',
              onPressed: onDetails,
            ),
          ],
        ),
      ),
    ),
  );
}

class _IngredientCard extends StatelessWidget {
  const _IngredientCard({
    super.key,
    required this.ingredient,
    required this.number,
    required this.fraction,
    required this.onEdit,
    required this.onRemove,
    required this.onWeight,
  });
  final MixerIngredient ingredient;
  final int number;
  final double fraction;
  final VoidCallback? onEdit, onRemove;
  final ValueChanged<double> onWeight;

  @override
  Widget build(BuildContext context) => StudioCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Color $number',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconCircleButton(
              icon: Icons.edit_outlined,
              label: 'Edit color $number',
              onPressed: onEdit,
            ),
            const SizedBox(width: AppSpacing.xs),
            IconCircleButton(
              icon: Icons.remove_rounded,
              label: 'Remove color $number',
              onPressed: onRemove,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: AppSpacing.huge,
              height: AppSpacing.huge,
              decoration: BoxDecoration(
                color: displayColor(ingredient.color),
                borderRadius: BorderRadius.circular(AppRadii.small),
                border: Border.all(color: context.appColors.outline),
              ),
            ),
            Text(
              ingredient.color.hex,
              style: AppTypography.mono.copyWith(
                color: context.appColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LabeledSlider(
          key: ValueKey('mixer-weight-${ingredient.id}'),
          label: 'Parts for color $number',
          value: ingredient.weight,
          min: 0,
          max: 100,
          divisions: 100,
          valueLabel: '${ingredient.weight.round()} parts',
          valueFormatter: (value) => '${value.round()} parts',
          onChanged: onWeight,
        ),
        Text(
          '${(fraction * 100).toStringAsFixed(1)}% of this mix',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.space,
    required this.color,
    required this.selected,
    required this.onTap,
  });
  final MixingSpace space;
  final RgbColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    space == MixingSpace.lab ? 'LAB blend' : 'RGB channels',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: AppSpacing.xl,
                      color: context.appColors.textPrimary,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: displayColor(color),
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                color.hex,
                key: ValueKey(
                  space == MixingSpace.lab ? 'mixer-lab-hex' : 'mixer-rgb-hex',
                ),
                style: AppTypography.mono.copyWith(
                  color: context.appColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
