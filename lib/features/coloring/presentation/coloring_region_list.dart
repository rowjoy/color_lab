import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../domain/coloring_project.dart';
import '../domain/drawing_definition.dart';

class ColoringRegionList extends StatelessWidget {
  const ColoringRegionList({
    super.key,
    required this.definition,
    required this.project,
    required this.focusedRegionId,
    required this.onSelect,
  });

  final DrawingDefinition definition;
  final ColoringProject project;
  final String? focusedRegionId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.l10n.coloringRegions,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 8),
      for (final region in definition.artwork.regions)
        Semantics(
          button: true,
          selected: focusedRegionId == region.id,
          label: _label(context.l10n, region.labelKey, definition, project),
          child: ListTile(
            key: ValueKey('coloring-region-${region.id}'),
            dense: true,
            selected: focusedRegionId == region.id,
            leading: Icon(
              project.assignments.containsKey(region.id)
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
            ),
            title: Text(context.l10n.coloringRegionLabel(region.labelKey)),
            subtitle: Text(
              _value(context.l10n, region.id, definition, project),
            ),
            onTap: () => onSelect(region.id),
          ),
        ),
    ],
  );
}

String _label(
  AppLocalizations l10n,
  String labelKey,
  DrawingDefinition definition,
  ColoringProject project,
) => l10n.coloringRegionSemantics(
  l10n.coloringRegionLabel(labelKey),
  _valueByKey(l10n, labelKey, definition, project),
);

String _valueByKey(
  AppLocalizations l10n,
  String labelKey,
  DrawingDefinition definition,
  ColoringProject project,
) {
  final region = definition.artwork.regions.firstWhere(
    (item) => item.labelKey == labelKey,
  );
  return _value(l10n, region.id, definition, project);
}

String _value(
  AppLocalizations l10n,
  String regionId,
  DrawingDefinition definition,
  ColoringProject project,
) {
  final color = project.assignments[regionId];
  if (project.mode == ColoringMode.free) {
    return color?.hex ?? l10n.coloringNotColored;
  }
  final rule = definition.regionRules[regionId]!;
  final slot = definition.slotById(rule.targetSlotId!);
  return color == null
      ? l10n.coloringRegionNeeds(l10n.coloringSlotLabel(slot.label))
      : l10n.coloringRegionComplete(l10n.coloringSlotLabel(slot.label));
}
