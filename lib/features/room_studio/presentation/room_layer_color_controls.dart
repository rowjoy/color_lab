import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../domain/room_layer.dart';
import '../domain/room_layer_colors.dart';
import 'room_mask_surface_status.dart';

class RoomLayerColorControls extends StatelessWidget {
  const RoomLayerColorControls({
    super.key,
    required this.colors,
    required this.selectedLayer,
    required this.enabled,
    required this.onSelect,
    required this.onChoose,
    required this.onReset,
  });

  final RoomLayerColors colors;
  final RoomLayer selectedLayer;
  final bool enabled;
  final ValueChanged<RoomLayer> onSelect;
  final VoidCallback onChoose;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Surface colors', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.md),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final layer in RoomLayer.values)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSpacing.huge),
              child: ChoiceChip(
                key: ValueKey('room-color-layer-${layer.name}'),
                materialTapTargetSize: MaterialTapTargetSize.padded,
                selected: selectedLayer == layer,
                onSelected: enabled ? (_) => onSelect(layer) : null,
                avatar: CircleAvatar(
                  backgroundColor: colors.colorFor(layer) == null
                      ? context.appColors.surfaceElevated
                      : Color(0xff000000 | colors.colorFor(layer)!.value),
                ),
                label: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_title(layer.name)} · ${roomSurfacePattern(layer)}'),
                    Text(
                      colors.colorFor(layer)?.hex ?? 'Not set',
                      style: AppTypography.mono,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(
        key: const ValueKey('room-color-choose'),
        label: 'Choose color',
        icon: Icons.palette_outlined,
        onPressed: enabled ? onChoose : null,
      ),
      const SizedBox(height: AppSpacing.sm),
      SecondaryButton(
        key: const ValueKey('room-color-reset'),
        label: 'Reset color',
        onPressed: enabled && colors.colorFor(selectedLayer) != null
            ? onReset
            : null,
      ),
    ],
  );

  static String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
