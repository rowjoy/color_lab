import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../history/domain/saved_color.dart';
import '../../shell/presentation/studio_page.dart';

class LabScreen extends StatefulWidget {
  const LabScreen({super.key});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  final _initial = RgbColor.fromHex('#B2A4D4').toHsl();
  late double _hue = _initial.hue;
  late double _saturation = _initial.saturation;
  late double _lightness = _initial.lightness;

  @override
  Widget build(BuildContext context) {
    // Keep the editing coordinates even when an achromatic result has no hue.
    final color = HslColor(_hue, _saturation, _lightness).toRgb();
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
                value: _hue,
                min: 0,
                max: 359.999,
                valueLabel: '${_hue.round()}°',
                valueFormatter: (value) => '${value.round()}°',
                onChanged: (value) => setState(() => _hue = value),
              ),
              LabeledSlider(
                label: 'Saturation',
                value: _saturation,
                valueLabel: '${(_saturation * 100).round()}%',
                valueFormatter: (value) => '${(value * 100).round()}%',
                onChanged: (value) => setState(() => _saturation = value),
              ),
              LabeledSlider(
                label: 'Lightness',
                value: _lightness,
                valueLabel: '${(_lightness * 100).round()}%',
                valueFormatter: (value) => '${(value * 100).round()}%',
                onChanged: (value) => setState(() => _lightness = value),
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
