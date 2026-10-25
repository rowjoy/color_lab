import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../domain/illustrated_room.dart';

Future<void> showIllustratedRoomMarketGuide(
  BuildContext context,
  IllustratedRoomTemplate template,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: true,
  sheetAnimationStyle: AppMotion.sheetAnimation(context),
  builder: (context) => IllustratedRoomMarketGuide(template: template),
);

class IllustratedRoomMarketGuide extends StatelessWidget {
  const IllustratedRoomMarketGuide({super.key, required this.template});

  final IllustratedRoomTemplate template;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    key: const ValueKey('room-market-guide-sheet'),
    heightFactor: .86,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Why these looks?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close market guide',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  template.paletteReviewLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.appColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'These are practical starting points for '
                  '${template.title.toLowerCase()} lighting and materials.',
                ),
                const SizedBox(height: AppSpacing.xl),
                for (final palette in template.palettes) ...[
                  _GuidePalette(palette: palette),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Divider(color: context.appColors.outline),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  container: true,
                  label: template.paletteSourceNote,
                  excludeSemantics: true,
                  child: Text(
                    template.paletteSourceNote,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _GuidePalette extends StatelessWidget {
  const _GuidePalette({required this.palette});

  final IllustratedRoomPalette palette;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.appColors.surfaceElevated,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      border: Border.all(color: context.appColors.outline),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(palette.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(palette.guidance),
          if (palette.provenance case final provenance?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              provenance,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.appColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
