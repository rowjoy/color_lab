import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/domain/saved_color.dart';
import '../../mixer/presentation/mixer_color_picker.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/formula_providers.dart';
import 'formula_recipe_card.dart';

class FormulaScreen extends ConsumerStatefulWidget {
  const FormulaScreen({super.key});

  @override
  ConsumerState<FormulaScreen> createState() => _FormulaScreenState();
}

class _FormulaScreenState extends ConsumerState<FormulaScreen> {
  bool _picking = false;

  Future<void> _chooseTarget() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final selected = await showMixerColorPicker(
        context,
        initialColor: ref.read(formulaTargetProvider),
      );
      if (mounted && selected != null) {
        ref.read(formulaTargetProvider.notifier).setColor(selected);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
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
    final target = ref.watch(formulaTargetProvider);
    final search = ref.watch(formulaResultProvider(target));
    // Refresh/loading/error must never leave an obsolete recipe on screen.
    final output = search.isLoading || search.hasError
        ? null
        : search.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color formula'),
        leading: IconCircleButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          onPressed: _back,
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('screen-Formula'),
          padding: AppSpacing.screenPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StudioHeading(
                    eyebrow: 'Break a shade into possibilities',
                    title: 'A little color chemistry. Almost.',
                    description:
                        'Find the closest blend of up to three digital base shades.',
                  ),
                  Text(
                    'An approximate digital formula, not a paint recipe.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SecondaryButton(
                    label: 'Choose target',
                    icon: Icons.colorize_rounded,
                    onPressed: _picking ? null : _chooseTarget,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stack =
                          MediaQuery.textScalerOf(context).scale(14) > 20 ||
                          constraints.maxWidth < 300;
                      final width = output == null || stack
                          ? constraints.maxWidth
                          : (constraints.maxWidth - AppSpacing.md) / 2;
                      return Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.lg,
                        children: [
                          SizedBox(
                            width: width,
                            child: ColorSwatchTile(
                              key: const ValueKey('formula-target-swatch'),
                              color: displayColor(target),
                              name: 'Your target',
                              hex: target.hex,
                              onTap: () => showColorDetails(
                                context,
                                target,
                                source: ColorSource.lab,
                              ),
                            ),
                          ),
                          if (output != null)
                            SizedBox(
                              width: width,
                              child: ColorSwatchTile(
                                key: const ValueKey('formula-result-swatch'),
                                color: displayColor(output.result),
                                name: 'Closest blend',
                                hex: output.result.hex,
                                onTap: () => showColorDetails(
                                  context,
                                  output.result,
                                  source: ColorSource.lab,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  search.when(
                    skipLoadingOnRefresh: false,
                    skipLoadingOnReload: false,
                    data: (formula) => FormulaRecipeCard(formula: formula),
                    loading: () => StudioCard(
                      child: Column(
                        key: const ValueKey('formula-loading'),
                        children: [
                          if (MediaQuery.disableAnimationsOf(context))
                            const Icon(Icons.hourglass_empty_rounded)
                          else
                            const CircularProgressIndicator(),
                          const SizedBox(height: AppSpacing.lg),
                          const Text('Finding your closest blend…'),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Searching the base shades in 5% steps, entirely on your device.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    error: (_, _) => StudioCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Could not find a formula right now.'),
                          const SizedBox(height: AppSpacing.md),
                          SecondaryButton(
                            label: 'Retry formula',
                            icon: Icons.refresh_rounded,
                            onPressed: () =>
                                ref.invalidate(formulaResultProvider(target)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  StudioCard(
                    child: ExpansionTile(
                      expansionAnimationStyle: AppMotion.sheetAnimation(
                        context,
                      ),
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Our digital bases'),
                      subtitle: const Text('12 reference shades'),
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        for (final base in formulaBases)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ColorChip(
                                key: ValueKey('formula-base-${base.id}'),
                                color: displayColor(base.color),
                                label: '${base.name} · ${base.color.hex}',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'These sRGB references are not measured pigments. Real materials, lighting and screens change the result. Saving keeps only the blend color; this target stays for the current app session.',
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
