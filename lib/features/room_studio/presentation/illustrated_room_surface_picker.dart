import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';
import '../domain/illustrated_room_assignments.dart';
import '../rendering/illustrated_room_rendering.dart';

String roomRegionName(AppLocalizations l10n, String id) => switch (id) {
  'wall-back' => l10n.roomWallBack,
  'wall-side' => l10n.roomWallSide,
  'wall-accent' => l10n.roomWallAccent,
  'desk' => l10n.roomDesk,
  'chair' => l10n.roomChair,
  'shelves' => l10n.roomShelves,
  'console' => l10n.roomConsole,
  'sofa' => l10n.roomSofa,
  'accent-chair' => l10n.roomAccentChair,
  'coffee-table' => l10n.roomCoffeeTable,
  'wardrobe' => l10n.roomWardrobe,
  'bedside-table-left' => l10n.roomBedsideTableLeft,
  'bedside-table-right' => l10n.roomBedsideTableRight,
  'bed' => l10n.roomBed,
  'sideboard' => l10n.roomSideboard,
  'chair-back-left' => l10n.roomChairBackLeft,
  'chair-back-right' => l10n.roomChairBackRight,
  'chair-front-left' => l10n.roomChairFrontLeft,
  'chair-front-right' => l10n.roomChairFrontRight,
  'dining-table' => l10n.roomDiningTable,
  'cabinet-upper-left' => l10n.roomCabinetUpperLeft,
  'cabinet-lower-left' => l10n.roomCabinetLowerLeft,
  'cabinet-upper-right' => l10n.roomCabinetUpperRight,
  'cabinet-lower-right' => l10n.roomCabinetLowerRight,
  'island' => l10n.roomIsland,
  'vanity' => l10n.roomVanity,
  'storage' => l10n.roomStorage,
  'walls' => l10n.roomWalls,
  'ceiling' => l10n.roomCeiling,
  'floor' => l10n.roomFloor,
  'furniture' => l10n.roomFurniture,
  _ => throw ArgumentError.value(id, 'region'),
};

/// Accessible authored identities for every bundled room.
class IllustratedRoomSurfacePicker extends StatelessWidget {
  const IllustratedRoomSurfacePicker({
    super.key,
    required this.draft,
    required this.selectedRegionId,
    required this.onSelected,
  });
  final IllustratedRoomDraft draft;
  final String? selectedRegionId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final authored = draft.template.regionAssetPath != null;
    final membership = IllustratedRoomRegionMembership.forTemplate(
      draft.template,
    );
    final ids = authored
        ? membership.groups.values.expand((ids) => ids)
        : membership.groups.keys;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final id in ids)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(
              builder: (context) {
                final group = authored ? membership.groupFor(id) : id;
                final name = roomRegionName(context.l10n, id);
                final groupName = roomRegionName(context.l10n, group);
                final color = authored && draft.displayAssignments != null
                    ? draft.displayAssignments!.colorFor(id)
                    : illustratedRoomEffectiveColors(
                        draft,
                      ).colorFor(illustratedRoomSurfaceForGroup(group));
                final selected = selectedRegionId == id;
                return Semantics(
                  key: ValueKey('room-region-$id'),
                  container: true,
                  button: true,
                  selected: selected,
                  label: '$name, $groupName, ${color.hex}',
                  excludeSemantics: true,
                  onTap: () => onSelected(id),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      side: BorderSide(
                        width: selected ? 3 : 1,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    onPressed: () => onSelected(id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${selected ? '✓ ' : ''}$name · $groupName · ${color.hex}',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
