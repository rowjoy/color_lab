import 'package:flutter/material.dart';

import '../../../core/color/color_models.dart';
import '../../../core/theme/theme.dart';
import '../domain/illustrated_room_draft.dart';

enum IllustratedRoomTool { looks, wall, ceiling, floor, furniture, designs }

enum IllustratedRoomViewMode { fillScreen, fullRoom }

class IllustratedRoomColorRail extends StatelessWidget {
  const IllustratedRoomColorRail({
    super.key,
    required this.draft,
    required this.activeTool,
    required this.savedDesignCount,
    required this.exportBusy,
    required this.onHide,
    required this.onToolSelected,
    required this.onBlackAndWhite,
    required this.onSaveToGallery,
  });

  final IllustratedRoomDraft draft;
  final IllustratedRoomTool? activeTool;
  final int savedDesignCount;
  final bool exportBusy;
  final VoidCallback onHide;
  final ValueChanged<IllustratedRoomTool> onToolSelected;
  final VoidCallback onBlackAndWhite;
  final VoidCallback? onSaveToGallery;

  @override
  Widget build(BuildContext context) {
    final labels = draft.template.surfaceLabels;
    return Material(
      color: context.appColors.surface.withValues(alpha: .96),
      elevation: 12,
      child: SafeArea(
        left: false,
        right: false,
        child: ListView(
          key: const ValueKey('room-color-rail-scroll'),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, AppSpacing.sm),
          children: [
            _RailAction(
              key: const ValueKey('room-hide-color-tools'),
              icon: Icons.keyboard_arrow_right_rounded,
              selectedIcon: Icons.keyboard_arrow_right_rounded,
              label: 'Hide',
              semanticsLabel: 'Hide color tools',
              selected: false,
              onPressed: onHide,
            ),
            _RailAction(
              key: const ValueKey('room-rail-looks'),
              icon: Icons.palette_outlined,
              selectedIcon: Icons.palette_rounded,
              label: 'Looks',
              selected: activeTool == IllustratedRoomTool.looks,
              onPressed: () => onToolSelected(IllustratedRoomTool.looks),
            ),
            _RailAction(
              key: const ValueKey('room-surface-wall'),
              icon: Icons.format_paint_outlined,
              selectedIcon: Icons.format_paint_rounded,
              label: labels.wall,
              detail: draft.colors?.wall.hex,
              swatchColor: _display(draft.colors?.wall),
              selected: activeTool == IllustratedRoomTool.wall,
              onPressed: () => onToolSelected(IllustratedRoomTool.wall),
            ),
            _RailAction(
              key: const ValueKey('room-surface-ceiling'),
              icon: Icons.vertical_align_top_rounded,
              selectedIcon: Icons.vertical_align_top_rounded,
              label: labels.ceiling,
              detail: draft.colors?.ceiling.hex,
              swatchColor: _display(draft.colors?.ceiling),
              selected: activeTool == IllustratedRoomTool.ceiling,
              onPressed: () => onToolSelected(IllustratedRoomTool.ceiling),
            ),
            _RailAction(
              key: const ValueKey('room-surface-floor'),
              icon: Icons.grid_on_outlined,
              selectedIcon: Icons.grid_on_rounded,
              label: labels.floor,
              detail: draft.colors?.floor.hex,
              swatchColor: _display(draft.colors?.floor),
              selected: activeTool == IllustratedRoomTool.floor,
              onPressed: () => onToolSelected(IllustratedRoomTool.floor),
            ),
            _RailAction(
              key: const ValueKey('room-surface-furniture'),
              icon: Icons.chair_outlined,
              selectedIcon: Icons.chair_rounded,
              label: _compactFurnitureLabel(labels.furniture),
              detail: draft.colors?.furniture.hex,
              swatchColor: _display(draft.colors?.furniture),
              semanticsLabel:
                  '${labels.furniture}${draft.colors == null ? '' : ', ${draft.colors!.furniture.hex}'}',
              selected: activeTool == IllustratedRoomTool.furniture,
              onPressed: () => onToolSelected(IllustratedRoomTool.furniture),
            ),
            _RailAction(
              key: const ValueKey('room-black-white'),
              icon: Icons.tonality_outlined,
              selectedIcon: Icons.tonality_rounded,
              label: 'B&W',
              semanticsLabel: 'Black & white',
              selected: draft.mode == IllustratedRoomVisualMode.grayscale,
              onPressed: onBlackAndWhite,
            ),
            _RailAction(
              key: const ValueKey('room-open-designs'),
              icon: Icons.collections_bookmark_outlined,
              selectedIcon: Icons.collections_bookmark_rounded,
              label: 'Designs',
              detail: savedDesignCount == 0 ? null : '$savedDesignCount',
              semanticsLabel:
                  'Designs, $savedDesignCount saved, current design '
                  '${draft.canSave ? 'can' : 'cannot'} be saved',
              selected: activeTool == IllustratedRoomTool.designs,
              onPressed: () => onToolSelected(IllustratedRoomTool.designs),
            ),
            _RailAction(
              key: const ValueKey('room-save-gallery'),
              icon: Icons.save_alt_outlined,
              selectedIcon: Icons.save_alt_rounded,
              label: 'Gallery',
              semanticsLabel: exportBusy
                  ? 'Saving room image to Gallery'
                  : 'Save room image to Gallery',
              busy: exportBusy,
              selected: false,
              onPressed: exportBusy ? null : onSaveToGallery,
            ),
          ],
        ),
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.detail,
    this.swatchColor,
    this.semanticsLabel,
    this.busy = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? detail;
  final Color? swatchColor;
  final String? semanticsLabel;
  final bool selected;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: busy,
    button: true,
    selected: selected,
    enabled: onPressed != null,
    onTap: onPressed,
    label: semanticsLabel ?? '$label${detail == null ? '' : ', $detail'}',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: AnimatedContainer(
        duration: AppMotion.duration(context),
        decoration: BoxDecoration(
          color: selected
              ? context.appColors.primary.withValues(alpha: .16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(
            color: selected ? context.appColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.medium),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 48, minHeight: 54),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: MediaQuery.disableAnimationsOf(context)
                              ? .7
                              : null,
                        ),
                      )
                    else if (swatchColor case final color?)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.appColors.outline),
                        ),
                      )
                    else
                      Icon(
                        selected ? selectedIcon : icon,
                        size: 22,
                        color: onPressed == null
                            ? Theme.of(context).disabledColor
                            : selected
                            ? context.appColors.primary
                            : context.appColors.textPrimary,
                      ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: onPressed == null
                            ? Theme.of(context).disabledColor
                            : context.appColors.textPrimary,
                        fontWeight: selected ? FontWeight.w700 : null,
                        height: 1.05,
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        detail!,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

String _compactFurnitureLabel(String label) {
  final separator = label.indexOf(' & ');
  return separator == -1 ? label : label.substring(0, separator);
}

Color? _display(RgbColor? color) => color == null
    ? null
    : Color.fromARGB(255, color.red, color.green, color.blue);
