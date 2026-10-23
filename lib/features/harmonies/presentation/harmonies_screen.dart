import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/domain/saved_color.dart';
import '../../mixer/presentation/mixer_color_picker.dart';
import '../../palette/application/saved_palettes_providers.dart';
import '../../palette/domain/saved_palette.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/harmony_controller.dart';
import 'harmony_wheel.dart';
import 'save_palette_dialog.dart';

class HarmoniesScreen extends ConsumerStatefulWidget {
  const HarmoniesScreen({super.key});
  @override
  ConsumerState<HarmoniesScreen> createState() => _HarmoniesScreenState();
}

class _HarmoniesScreenState extends ConsumerState<HarmoniesScreen> {
  bool _picking = false, _saving = false;

  Future<void> _chooseBase() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final color = await showMixerColorPicker(
        context,
        initialColor: ref.read(harmonyDraftProvider).base,
      );
      if (mounted && color != null) {
        ref.read(harmonyDraftProvider.notifier).setBase(color);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save(HarmonyDraft draft, List<RgbColor> colors) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saved = await showSavePaletteDialog(
        context,
        base: draft.base,
        mode: draft.mode,
        colors: colors,
      );
      if (mounted && saved != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved “${saved.name}”.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
    final draft = ref.watch(harmonyDraftProvider);
    final controller = ref.read(harmonyDraftProvider.notifier);
    final colors = generateHarmony(draft.base, mode: draft.mode);
    final palettes = ref.watch(savedPalettesProvider);
    final stored = palettes.asData?.value
        .where(
          (palette) => palette.id == SavedPalette.idFor(draft.base, draft.mode),
        )
        .firstOrNull;
    final saved = stored != null && listEquals(stored.colors, colors);
    final collision = stored != null && !saved;
    final canSave =
        palettes.hasValue &&
        !palettes.isLoading &&
        !_saving &&
        !_picking &&
        stored == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Harmonies'),
        leading: IconCircleButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          onPressed: _back,
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('screen-Harmonies'),
          padding: AppSpacing.screenPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const StudioHeading(
                    eyebrow: 'Find a rhythm in color',
                    title: 'Better, together.',
                    description:
                        'Explore six HSL relationships. Keep a whole palette when it feels right.',
                  ),
                  ColorSwatchTile(
                    key: const ValueKey('harmony-base'),
                    color: displayColor(draft.base),
                    name: 'Your base shade',
                    hex: draft.base.hex,
                    onTap: () => showColorDetails(
                      context,
                      draft.base,
                      source: ColorSource.lab,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SecondaryButton(
                    label: 'Choose base color',
                    icon: Icons.colorize_rounded,
                    onPressed: _picking || _saving ? null : _chooseBase,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final mode in HarmonyMode.values)
                        ChoiceChip(
                          key: ValueKey('harmony-mode-${mode.name}'),
                          label: Text(mode.label),
                          selected: draft.mode == mode,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          onSelected: (_) => controller.setMode(mode),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  StudioCard(
                    child: HarmonyWheel(
                      base: draft.base,
                      mode: draft.mode,
                      colors: colors,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  SectionHeader(
                    title: 'Your shades',
                    subtitle:
                        '${colors.length} unique ${colors.length == 1 ? 'shade' : 'shades'} · tap to explore every value',
                  ),
                  PaletteBar(colors: colors.map(displayColor).toList()),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (var i = 0; i < colors.length; i++)
                        ColorChip(
                          key: ValueKey('harmony-swatch-${colors[i].hex}'),
                          color: displayColor(colors[i]),
                          label:
                              '${i == 0 ? 'Base' : 'Shade ${i + 1}'} · ${colors[i].hex}',
                          onTap: () => showColorDetails(
                            context,
                            colors[i],
                            source: ColorSource.lab,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (palettes.hasError && !palettes.hasValue) ...[
                    const Text(
                      'Your palettes could not be opened. You can keep exploring colors.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Retry palettes',
                      icon: Icons.refresh_rounded,
                      onPressed: () =>
                          ref.read(savedPalettesProvider.notifier).retry(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (collision) ...[
                    const Text(
                      'A saved version uses this base and mode. Its original colors are kept; manage it in saved palettes.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  PrimaryButton(
                    label: saved
                        ? 'Palette saved'
                        : collision
                        ? 'Saved version differs'
                        : 'Save palette',
                    icon: saved
                        ? Icons.check_circle_outline_rounded
                        : Icons.bookmark_add_outlined,
                    isLoading: palettes.isLoading,
                    onPressed: canSave ? () => _save(draft, colors) : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: 'View saved palettes',
                    icon: Icons.collections_bookmark_outlined,
                    onPressed: () => context.push('/palettes', extra: true),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Hue relationships are digital color studies, not a guarantee of paint or material compatibility. Your draft stays for this app session; saved palettes keep their exact colors on this device.',
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
