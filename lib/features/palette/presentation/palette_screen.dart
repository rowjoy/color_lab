import 'package:flutter/material.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/domain/saved_color.dart';
import '../../history/presentation/color_history_section.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../shell/presentation/studio_page.dart';
import 'saved_palettes_section.dart';

enum _PaletteView { saved, studio, palettes }

class PaletteScreen extends StatefulWidget {
  const PaletteScreen({super.key});

  @override
  State<PaletteScreen> createState() => _PaletteScreenState();
}

class _PaletteScreenState extends State<PaletteScreen> {
  _PaletteView _view = _PaletteView.saved;

  static const _studies = [
    (
      name: 'Slow Sunday',
      mood: 'Warm light. A softer pace.',
      colors: ['#E8DAA9', '#D6B59B', '#809886', '#444E43', '#F3EFE5'],
    ),
    (
      name: 'After the rain',
      mood: 'Grounded greens meet a quiet sky.',
      colors: ['#A7BDB6', '#647C72', '#D7DEDC', '#75889A', '#344E55'],
    ),
    (
      name: 'A little unexpected',
      mood: 'A playful twist on everyday neutrals.',
      colors: ['#B2A4D4', '#ECE29E', '#D58A79', '#5C5367', '#F1E9E0'],
    ),
  ];

  @override
  Widget build(BuildContext context) => StudioPage(
    name: 'Palette',
    children: [
      const StudioHeading(
        eyebrow: 'The collection',
        title: 'Colors, in good company.',
        description: 'Keep your discoveries, or find a little inspiration.',
      ),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          ChoiceChip(
            key: const ValueKey('palette-saved'),
            label: const Text('Saved'),
            avatar: const Icon(Icons.bookmark_border_rounded, size: 20),
            selected: _view == _PaletteView.saved,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => setState(() => _view = _PaletteView.saved),
          ),
          ChoiceChip(
            key: const ValueKey('palette-studio'),
            label: const Text('Studio'),
            avatar: const Icon(Icons.palette_outlined, size: 20),
            selected: _view == _PaletteView.studio,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => setState(() => _view = _PaletteView.studio),
          ),
          ChoiceChip(
            key: const ValueKey('palette-collections'),
            label: const Text('Palettes'),
            avatar: const Icon(Icons.collections_bookmark_outlined, size: 20),
            selected: _view == _PaletteView.palettes,
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => setState(() => _view = _PaletteView.palettes),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      if (_view == _PaletteView.saved) const ColorHistorySection(),
      if (_view == _PaletteView.palettes) const SavedPalettesSection(),
      if (_view == _PaletteView.studio) ...[
        const SectionHeader(
          title: 'Studio studies',
          subtitle: 'Curated inspiration · tap a shade to explore',
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final study in _studies) ...[
          StudioCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PaletteBar(
                  colors: study.colors
                      .map((hex) => displayColor(RgbColor.fromHex(hex)))
                      .toList(),
                  height: AppSpacing.huge * 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  study.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  study.mood,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final hex in study.colors)
                      ColorChip(
                        color: displayColor(RgbColor.fromHex(hex)),
                        label: hex,
                        onTap: () => showColorDetails(
                          context,
                          RgbColor.fromHex(hex),
                          source: ColorSource.studio,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    ],
  );
}
