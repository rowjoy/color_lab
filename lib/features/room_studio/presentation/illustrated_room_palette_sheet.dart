import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/color/color_models.dart';
import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../../palette/application/saved_palettes_providers.dart';

/// The library boundary returns a newly copied color, never a palette identity.
Future<RgbColor?> showIllustratedRoomPalettes(BuildContext context) =>
    showModalBottomSheet<RgbColor>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      sheetAnimationStyle: AppMotion.sheetAnimation(context),
      builder: (context) => const _MyPalettes(),
    );

class _MyPalettes extends ConsumerWidget {
  const _MyPalettes();
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.roomMyPalettes,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ref
                .watch(savedPalettesProvider)
                .when(
                  data: (palettes) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (palettes.isEmpty) Text(context.l10n.roomNoPalettes),
                      for (final palette in palettes) ...[
                        Text(palette.name),
                        IllustratedRoomPaletteSheet(
                          colors: [
                            for (final color in palette.colors)
                              RgbColor(color.red, color.green, color.blue),
                          ],
                          onSelected: (color) =>
                              Navigator.of(context).pop(color),
                        ),
                      ],
                    ],
                  ),
                  loading: () => Text(context.l10n.roomLoading),
                  error: (_, _) => Column(
                    children: [
                      Text(context.l10n.roomPalettesFailed),
                      TextButton(
                        onPressed: ref
                            .read(savedPalettesProvider.notifier)
                            .retry,
                        child: Text(context.l10n.roomRetry),
                      ),
                    ],
                  ),
                ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.roomClose),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Value-only swatches: this editor widget never receives library objects.
class IllustratedRoomPaletteSheet extends StatelessWidget {
  IllustratedRoomPaletteSheet({
    super.key,
    required Iterable<RgbColor> colors,
    required this.onSelected,
  }) : colors = List.unmodifiable(
         colors.map((c) => RgbColor(c.red, c.green, c.blue)),
       );
  final List<RgbColor> colors;
  final ValueChanged<RgbColor> onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final color in colors)
        OutlinedButton.icon(
          key: ValueKey('room-region-color-${color.hex.substring(1)}'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () =>
              onSelected(RgbColor(color.red, color.green, color.blue)),
          icon: Icon(Icons.circle, color: Color(0xFF000000 | color.value)),
          label: Text(color.hex),
        ),
    ],
  );
}
