import 'package:flutter/material.dart';

import '../../../core/color/color_models.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/buttons.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';
import 'illustrated_room_controls.dart';

class IllustratedRoomFlyout extends StatelessWidget {
  const IllustratedRoomFlyout({
    super.key,
    required this.tool,
    required this.draft,
    required this.onClose,
    required this.onPaletteSelected,
    required this.onSuggestedColor,
    required this.onCustomColor,
    required this.onMarketGuide,
    required this.designsContent,
  });

  final IllustratedRoomTool tool;
  final IllustratedRoomDraft draft;
  final VoidCallback onClose;
  final ValueChanged<String> onPaletteSelected;
  final ValueChanged<RgbColor> onSuggestedColor;
  final VoidCallback onCustomColor;
  final VoidCallback onMarketGuide;
  final Widget designsContent;

  IllustratedRoomSurface? get _surface => switch (tool) {
    IllustratedRoomTool.wall => IllustratedRoomSurface.wall,
    IllustratedRoomTool.ceiling => IllustratedRoomSurface.ceiling,
    IllustratedRoomTool.floor => IllustratedRoomSurface.floor,
    IllustratedRoomTool.furniture => IllustratedRoomSurface.furniture,
    IllustratedRoomTool.looks || IllustratedRoomTool.designs => null,
  };

  String get _title => switch (tool) {
    IllustratedRoomTool.looks => 'Recommended looks',
    IllustratedRoomTool.designs => 'Designs',
    _ => draft.template.surfaceLabels.labelFor(_surface!),
  };

  @override
  Widget build(BuildContext context) => Material(
    color: context.appColors.surface,
    elevation: 18,
    shadowColor: Colors.black45,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.large),
      side: BorderSide(color: context.appColors.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    _title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('room-flyout-close'),
                tooltip: 'Close color tools',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.appColors.outline),
        Expanded(
          child: tool == IllustratedRoomTool.designs
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  child: designsContent,
                )
              : SingleChildScrollView(
                  key: const ValueKey('room-flyout-scroll'),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  child: switch (tool) {
                    IllustratedRoomTool.looks => _LooksContent(
                      draft: draft,
                      onPaletteSelected: onPaletteSelected,
                      onMarketGuide: onMarketGuide,
                    ),
                    _ => _SurfaceContent(
                      draft: draft,
                      surface: _surface!,
                      onSuggestedColor: onSuggestedColor,
                      onCustomColor: onCustomColor,
                    ),
                  },
                ),
        ),
      ],
    ),
  );
}

class _LooksContent extends StatelessWidget {
  const _LooksContent({
    required this.draft,
    required this.onPaletteSelected,
    required this.onMarketGuide,
  });

  final IllustratedRoomDraft draft;
  final ValueChanged<String> onPaletteSelected;
  final VoidCallback onMarketGuide;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Choose a complete combination, then fine-tune any surface.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary),
      ),
      const SizedBox(height: AppSpacing.md),
      for (final palette in draft.template.palettes) ...[
        _PaletteOption(
          key: ValueKey('room-palette-${palette.id}'),
          palette: palette,
          selected: draft.sourcePaletteId == palette.id,
          recommended: palette.id == draft.template.defaultPaletteId,
          onPressed: () => onPaletteSelected(palette.id),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      const SizedBox(height: AppSpacing.sm),
      SecondaryButton(
        key: const ValueKey('room-market-guide'),
        label: 'Why these looks?',
        icon: Icons.info_outline_rounded,
        onPressed: onMarketGuide,
      ),
    ],
  );
}

class _PaletteOption extends StatelessWidget {
  const _PaletteOption({
    super.key,
    required this.palette,
    required this.selected,
    required this.recommended,
    required this.onPressed,
  });

  final IllustratedRoomPalette palette;
  final bool selected;
  final bool recommended;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    selected: selected,
    onTap: onPressed,
    label: '${palette.name}${recommended ? ', Recommended' : ''}',
    excludeSemantics: true,
    child: Material(
      color: selected
          ? context.appColors.primary.withValues(alpha: .12)
          : context.appColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: selected
              ? context.appColors.primary
              : context.appColors.outline,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        palette.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: context.appColors.primary,
                      ),
                  ],
                ),
                if (recommended) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Recommended',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.appColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _PaletteSwatches(colors: palette.colors),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  palette.guidance,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SurfaceContent extends StatelessWidget {
  const _SurfaceContent({
    required this.draft,
    required this.surface,
    required this.onSuggestedColor,
    required this.onCustomColor,
  });

  final IllustratedRoomDraft draft;
  final IllustratedRoomSurface surface;
  final ValueChanged<RgbColor> onSuggestedColor;
  final VoidCallback onCustomColor;

  @override
  Widget build(BuildContext context) {
    final label = draft.template.surfaceLabels.labelFor(surface);
    final current = draft.colors?.colorFor(surface);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Suggested $label colors',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Suggestions come from the three complete room looks.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final color in draft.template.suggestedColors(surface)) ...[
          _SuggestedColor(
            key: ValueKey(
              'room-suggestion-${surface.name}-${color.hex.substring(1)}',
            ),
            label: label,
            color: color,
            selected: current == color,
            onPressed: () => onSuggestedColor(color),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          key: const ValueKey('room-custom-color'),
          label: 'Custom color',
          icon: Icons.colorize_rounded,
          onPressed: onCustomColor,
        ),
      ],
    );
  }
}

class _SuggestedColor extends StatelessWidget {
  const _SuggestedColor({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final RgbColor color;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    selected: selected,
    onTap: onPressed,
    label: '$label ${color.hex}',
    excludeSemantics: true,
    child: Material(
      color: selected
          ? context.appColors.primary.withValues(alpha: .12)
          : context.appColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.medium),
        side: BorderSide(
          color: selected
              ? context.appColors.primary
              : context.appColors.outline,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _display(color),
                    shape: BoxShape.circle,
                    border: Border.all(color: context.appColors.outline),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    color.hex,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.add_rounded,
                  color: selected
                      ? context.appColors.primary
                      : context.appColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _PaletteSwatches extends StatelessWidget {
  const _PaletteSwatches({required this.colors});

  final IllustratedRoomColors colors;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 28,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.small),
      child: Row(
        children: [
          for (final surface in IllustratedRoomSurface.values)
            Expanded(
              child: ColoredBox(color: _display(colors.colorFor(surface))),
            ),
        ],
      ),
    ),
  );
}

Color _display(RgbColor color) =>
    Color.fromARGB(255, color.red, color.green, color.blue);
