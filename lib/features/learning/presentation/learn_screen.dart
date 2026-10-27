import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/studio_page.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) => StudioPage(
    name: 'Learn',
    children: [
      StudioHeading(
        eyebrow: context.l10n.learnEyebrow,
        title: context.l10n.learnTitle,
        description: context.l10n.learnDescription,
      ),
      SectionHeader(title: context.l10n.learnGuidedTitle),
      _LearnLink(
        key: const ValueKey('learn-open-vision'),
        icon: Icons.visibility_outlined,
        label: context.l10n.learnOpenVision,
        onTap: () => context.push('/vision'),
      ),
      const SizedBox(height: AppSpacing.md),
      _LearnLink(
        key: const ValueKey('learn-open-matching'),
        icon: Icons.tune_rounded,
        label: context.l10n.learnOpenMatching,
        onTap: () => context.push('/matching'),
      ),
      const SizedBox(height: AppSpacing.xxl),
      SectionHeader(title: context.l10n.learnExperimentTitle),
      for (final link in [
        (
          key: 'learn-open-capture',
          icon: Icons.center_focus_strong_rounded,
          label: context.l10n.learnOpenCapture,
          path: '/capture',
        ),
        (
          key: 'learn-open-palette',
          icon: Icons.palette_outlined,
          label: context.l10n.learnOpenPalette,
          path: '/palette',
        ),
        (
          key: 'learn-open-lab',
          icon: Icons.science_outlined,
          label: context.l10n.learnOpenLab,
          path: '/lab',
        ),
        (
          key: 'learn-open-mixer',
          icon: Icons.blender_outlined,
          label: context.l10n.learnOpenMixer,
          path: '/mixer',
        ),
        (
          key: 'learn-open-formula',
          icon: Icons.functions_rounded,
          label: context.l10n.learnOpenFormula,
          path: '/formula',
        ),
        (
          key: 'learn-open-harmonies',
          icon: Icons.hub_outlined,
          label: context.l10n.learnOpenHarmonies,
          path: '/harmonies',
        ),
      ]) ...[
        _LearnLink(
          key: ValueKey(link.key),
          icon: link.icon,
          label: link.label,
          onTap: () => context.push(link.path),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      const SizedBox(height: AppSpacing.lg),
      _LearnLink(
        key: const ValueKey('learn-open-my-work'),
        icon: Icons.collections_bookmark_outlined,
        label: context.l10n.learnOpenMyWork,
        onTap: () => context.push('/my-work'),
      ),
    ],
  );
}

class _LearnLink extends StatelessWidget {
  const _LearnLink({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    onTap: onTap,
    excludeSemantics: true,
    child: Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTargets.minimum),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(icon, color: context.appColors.primary),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
