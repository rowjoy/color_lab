import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../../../core/color/color_models.dart';

Future<List<RgbColor>?> showColoringRoomAssignmentDialog(
  BuildContext context,
  Iterable<RgbColor> sourceColors,
) {
  final colors = sourceColors.toSet().toList(growable: false);
  if (colors.isEmpty) return Future.value(null);
  final selected = List<RgbColor?>.filled(4, null);
  final surfaces = [
    context.l10n.coloringSurfaceWall,
    context.l10n.coloringSurfaceCeiling,
    context.l10n.coloringSurfaceFloor,
    context.l10n.coloringSurfaceFurniture,
  ];
  return showDialog<List<RgbColor>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(context.l10n.coloringAssignTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.l10n.coloringAssignBody),
              const SizedBox(height: 16),
              for (var index = 0; index < surfaces.length; index++) ...[
                DropdownButtonFormField<RgbColor>(
                  key: ValueKey('coloring-room-surface-$index'),
                  initialValue: selected[index],
                  decoration: InputDecoration(labelText: surfaces[index]),
                  items: [
                    for (final color in colors)
                      DropdownMenuItem(
                        value: color,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color.fromARGB(
                                  255,
                                  color.red,
                                  color.green,
                                  color.blue,
                                ),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(color.hex),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => selected[index] = value),
                ),
                if (index != surfaces.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.coloringCancel),
          ),
          FilledButton(
            key: const ValueKey('coloring-room-assign-confirm'),
            onPressed: selected.every((color) => color != null)
                ? () => Navigator.pop(
                    context,
                    selected.cast<RgbColor>().toList(growable: false),
                  )
                : null,
            child: Text(context.l10n.coloringApplyRoom),
          ),
        ],
      ),
    ),
  );
}
