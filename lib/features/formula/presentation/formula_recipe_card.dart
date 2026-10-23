import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/domain/saved_color.dart';
import '../../history/presentation/save_color_actions.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../shell/presentation/studio_page.dart';

/// Recipe data comes from the worker; presentation never repeats its search.
class FormulaRecipeCard extends ConsumerWidget {
  const FormulaRecipeCard({super.key, required this.formula});
  final ColorFormula formula;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref
        .watch(colorNamerProvider)
        .asData
        ?.value
        .nearest(formula.result)
        .name;
    return StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            key: ValueKey('formula-recipe-heading'),
            title: 'Your formula',
            subtitle: 'Approximate LAB blend · 5% steps · 100% total',
          ),
          PaletteBar(
            colors: [
              for (final part in formula.parts) displayColor(part.base.color),
            ],
            weights: [
              for (final part in formula.parts) part.percent.toDouble(),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          for (final part in formula.parts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: AppSpacing.huge,
                    height: AppSpacing.huge,
                    decoration: BoxDecoration(
                      color: displayColor(part.base.color),
                      borderRadius: BorderRadius.circular(AppRadii.small),
                      border: Border.all(color: context.appColors.outline),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          part.base.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          part.base.color.hex,
                          style: AppTypography.mono.copyWith(
                            color: context.appColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    '${part.percent}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'CIE76 difference (ΔE)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            formula.deltaE.toStringAsFixed(2),
            key: const ValueKey('formula-error-value'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Lower is closer. This compares the displayed blend with your target, including screen-gamut rounding.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          SaveColorActions(
            key: ValueKey(formula.result.hex),
            color: formula.result,
            name: name,
            source: ColorSource.lab,
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: 'Blend details',
            icon: Icons.info_outline_rounded,
            onPressed: () => showColorDetails(
              context,
              formula.result,
              source: ColorSource.lab,
            ),
          ),
        ],
      ),
    );
  }
}
