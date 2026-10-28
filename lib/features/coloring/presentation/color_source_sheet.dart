import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';

import '../../../core/color/color_models.dart';
import '../../history/application/history_providers.dart';
import '../../history/domain/saved_color.dart';
import '../../palette/application/saved_palettes_providers.dart';
import '../../palette/domain/saved_palette.dart';
import '../domain/drawing_definition.dart';

class ColorSourceSheet extends ConsumerStatefulWidget {
  const ColorSourceSheet({
    super.key,
    required this.definition,
    required this.onSelected,
    this.guidedOnly = false,
    this.selectedColor,
    this.extraColors = const [],
  });

  final DrawingDefinition definition;
  final ValueChanged<RgbColor> onSelected;
  final bool guidedOnly;
  final RgbColor? selectedColor;
  final List<RgbColor> extraColors;

  @override
  ConsumerState<ColorSourceSheet> createState() => _ColorSourceSheetState();
}

class _ColorSourceSheetState extends ConsumerState<ColorSourceSheet> {
  final _hex = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<SavedColor> colors = widget.guidedOnly
        ? const []
        : ref.watch(colorHistoryProvider).value ?? const [];
    final List<SavedPalette> palettes = widget.guidedOnly
        ? const []
        : ref.watch(savedPalettesProvider).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.coloringSuggestedColors,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _swatches([
          for (final slot in widget.definition.slots)
            (slot.color, context.l10n.coloringSlotLabel(slot.label)),
        ], labeled: widget.guidedOnly),
        if (!widget.guidedOnly) ...[
          if (widget.extraColors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.l10n.coloringFromLearning,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _swatches([
              for (final color in widget.extraColors) (color, color.hex),
            ]),
          ],
          if (colors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.l10n.coloringMyColors,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _swatches([
              for (final saved in colors)
                (
                  RgbColor.fromHex(saved.hex),
                  context.l10n.coloringNamedHex(saved.name, saved.hex),
                ),
            ]),
          ],
          if (palettes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.l10n.coloringMyPalettes,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _swatches([
              for (final palette in palettes)
                for (final color in palette.colors)
                  (
                    color,
                    context.l10n.coloringNamedHex(palette.name, color.hex),
                  ),
            ]),
          ],
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('coloring-custom-hex'),
            controller: _hex,
            textCapitalization: TextCapitalization.characters,
            maxLength: 7,
            decoration: InputDecoration(
              labelText: context.l10n.coloringCustomHex,
              hintText: context.l10n.coloringHexHint,
              errorText: _error,
              suffixIcon: IconButton(
                tooltip: context.l10n.coloringUseCustom,
                onPressed: _useCustom,
                icon: const Icon(Icons.check_rounded),
              ),
            ),
            onSubmitted: (_) => _useCustom(),
          ),
        ],
      ],
    );
  }

  Widget _swatches(
    List<(RgbColor, String)> values, {
    bool labeled = false,
  }) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (var index = 0; index < values.length; index++)
        if (labeled)
          ChoiceChip(
            key: ValueKey('color-source-${values[index].$1.hex}'),
            avatar: _ColorDot(color: values[index].$1),
            label: Text(
              context.l10n.coloringNumberedSwatch(
                index + 1,
                values[index].$2,
                values[index].$1.hex,
              ),
            ),
            selected: widget.selectedColor == values[index].$1,
            onSelected: (_) => widget.onSelected(
              RgbColor(
                values[index].$1.red,
                values[index].$1.green,
                values[index].$1.blue,
              ),
            ),
          )
        else
          Semantics(
            button: true,
            selected: widget.selectedColor == values[index].$1,
            label: context.l10n.coloringSwatchSemantics(
              values[index].$2,
              values[index].$1.hex,
            ),
            child: Tooltip(
              message: context.l10n.coloringSwatchTooltip(
                values[index].$2,
                values[index].$1.hex,
              ),
              child: InkWell(
                key: ValueKey(
                  'color-source-${values[index].$2}-${values[index].$1.hex}',
                ),
                customBorder: const CircleBorder(),
                onTap: () => widget.onSelected(
                  RgbColor(
                    values[index].$1.red,
                    values[index].$1.green,
                    values[index].$1.blue,
                  ),
                ),
                child: _ColorDot(color: values[index].$1, size: 48),
              ),
            ),
          ),
    ],
  );

  void _useCustom() {
    try {
      final color = RgbColor.fromHex(_hex.text.trim());
      setState(() => _error = null);
      widget.onSelected(RgbColor(color.red, color.green, color.blue));
    } on FormatException {
      setState(() => _error = context.l10n.coloringInvalidHex);
    }
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, this.size = 22});

  final RgbColor color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color.fromARGB(255, color.red, color.green, color.blue),
      border: Border.all(color: Theme.of(context).colorScheme.outline),
    ),
  );
}
