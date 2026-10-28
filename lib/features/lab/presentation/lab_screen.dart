import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../history/domain/saved_color.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/lab_controller.dart';

class LabScreen extends ConsumerWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(labProvider);
    final controller = ref.read(labProvider.notifier);
    final color = draft.color;
    return StudioPage(
      name: 'Lab',
      children: [
        const StudioHeading(
          eyebrow: 'A space to experiment',
          title: 'Follow the feeling.',
          description:
              'A little warmer. A touch softer.\nMake one shade your own.',
        ),
        PrimaryButton(
          label: 'Open color mixer',
          icon: Icons.blender_outlined,
          onPressed: () => context.push('/mixer'),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SecondaryButton(
          label: 'Open color formula',
          icon: Icons.science_outlined,
          onPressed: () => context.push('/formula'),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SecondaryButton(
          label: 'Open harmonies',
          icon: Icons.palette_outlined,
          onPressed: () => context.push('/harmonies'),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SecondaryButton(
          key: const ValueKey('open-matching'),
          label: 'Play color matching',
          icon: Icons.tune_rounded,
          onPressed: () => context.push('/matching'),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SecondaryButton(
          key: const ValueKey('open-vision'),
          label: 'Explore vision plates',
          icon: Icons.blur_circular_rounded,
          onPressed: () => context.push('/vision'),
        ),
        const SizedBox(height: AppSpacing.xxl),
        ColorSwatchTile(
          color: displayColor(color),
          name: 'Your color study',
          hex: color.hex,
          onTap: () =>
              showColorDetails(context, color, source: ColorSource.lab),
        ),
        const SizedBox(height: AppSpacing.xxl),
        StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(title: 'Fine-tune the mood'),
              LabeledSlider(
                label: 'Hue',
                value: draft.hue,
                min: 0,
                max: 359.999,
                valueLabel: '${draft.hue.round()}°',
                valueFormatter: (value) => '${value.round()}°',
                onChanged: controller.setHue,
              ),
              LabeledSlider(
                label: 'Saturation',
                value: draft.saturation,
                valueLabel: '${(draft.saturation * 100).round()}%',
                valueFormatter: (value) => '${(value * 100).round()}%',
                onChanged: controller.setSaturation,
              ),
              LabeledSlider(
                label: 'Lightness',
                value: draft.lightness,
                valueLabel: '${(draft.lightness * 100).round()}%',
                valueFormatter: (value) => '${(value * 100).round()}%',
                onChanged: controller.setLightness,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SecondaryButton(
          label: 'See every color value',
          icon: Icons.data_object_rounded,
          onPressed: () =>
              showColorDetails(context, color, source: ColorSource.lab),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          'Original color studies, made for exploration.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
