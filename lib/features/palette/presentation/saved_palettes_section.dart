import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../harmonies/application/harmony_controller.dart';
import '../../history/domain/saved_color.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/saved_palettes_providers.dart';
import '../domain/saved_palette.dart';

class SavedPalettesSection extends ConsumerStatefulWidget {
  const SavedPalettesSection({super.key, this.returnToHarmony = false});
  final bool returnToHarmony;
  @override
  ConsumerState<SavedPalettesSection> createState() =>
      _SavedPalettesSectionState();
}

class _SavedPalettesSectionState extends ConsumerState<SavedPalettesSection> {
  String? _deleting, _error;

  Future<void> _delete(SavedPalette palette) async {
    if (_deleting != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('Delete this palette?'),
        content: Text(
          '“${palette.name}” will be removed from this device. Your individual saved colors will stay.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: dialogContext.appColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('confirm-delete-palette'),
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: dialogContext.appColors.textPrimary,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _deleting = palette.id;
      _error = null;
    });
    try {
      await ref.read(savedPalettesProvider.notifier).deletePalette(palette.id);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not delete this palette. Try again.');
      }
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  Future<void> _open(SavedPalette palette) async {
    ref
        .read(harmonyDraftProvider.notifier)
        .setSelection(base: palette.base, mode: palette.mode);
    await _navigateToHarmony();
  }

  Future<void> _navigateToHarmony() async {
    // A library opened from the editor returns to that same editor instance.
    if (widget.returnToHarmony && context.canPop()) {
      context.pop();
    } else {
      await context.push<void>('/harmonies');
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(savedPalettesProvider)
      .when(
        skipLoadingOnRefresh: false,
        loading: () => const StudioCard(child: Text('Opening your palettes…')),
        error: (_, _) => StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Could not open your saved palettes.'),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'Retry palettes',
                icon: Icons.refresh_rounded,
                onPressed: () =>
                    ref.read(savedPalettesProvider.notifier).retry(),
              ),
            ],
          ),
        ),
        data: (palettes) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'Saved palettes',
              subtitle: 'Whole color stories, kept on this device.',
            ),
            if (_error != null) ...[
              Semantics(liveRegion: true, child: Text(_error!)),
              const SizedBox(height: AppSpacing.md),
            ],
            if (palettes.isEmpty)
              const StudioCard(child: Text('No saved palettes yet.')),
            for (final palette in palettes) ...[
              StudioCard(
                key: ValueKey('saved-palette-${palette.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      palette.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${palette.mode.label} · ${palette.colors.length} shades',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PaletteBar(
                      colors: palette.colors.map(displayColor).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final color in palette.colors)
                          ColorChip(
                            key: ValueKey(
                              'saved-swatch-${palette.id}-${color.hex}',
                            ),
                            color: displayColor(color),
                            label: color.hex,
                            onTap: () => showColorDetails(
                              context,
                              color,
                              source: ColorSource.lab,
                              onOpenHarmonies: _navigateToHarmony,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            key: ValueKey('open-palette-${palette.id}'),
                            label: 'Open harmony',
                            icon: Icons.palette_outlined,
                            onPressed: () => _open(palette),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        IconCircleButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete ${palette.name}',
                          isLoading: _deleting == palette.id,
                          onPressed: _deleting != null
                              ? null
                              : () => _delete(palette),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      );
}
