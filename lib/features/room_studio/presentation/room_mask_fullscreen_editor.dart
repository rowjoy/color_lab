import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/room_mask_controller.dart';
import '../domain/room_layer.dart';
import '../domain/room_mask_state.dart';
import 'room_mask_viewport.dart';

/// A photo-first workspace backed by the same draft as the room screen.
class RoomMaskFullscreenEditor extends ConsumerStatefulWidget {
  const RoomMaskFullscreenEditor({super.key, required this.photoId});

  final String photoId;

  @override
  ConsumerState<RoomMaskFullscreenEditor> createState() =>
      _RoomMaskFullscreenEditorState();
}

class _RoomMaskFullscreenEditorState
    extends ConsumerState<RoomMaskFullscreenEditor> {
  final _view = RoomMaskViewportController();

  bool get _active =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? false) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomMaskProvider);
    final controller = ref.read(roomMaskProvider.notifier);
    final draft = state.draft;
    final available = draft?.photoId == widget.photoId;
    final enabled =
        available && state.stage == RoomMaskStage.ready && !state.editBusy;

    return Scaffold(
      key: const ValueKey('room-mask-fullscreen-editor'),
      backgroundColor: context.appColors.surface,
      appBar: AppBar(
        leading: IconButton(
          key: const ValueKey('room-mask-fullscreen-close'),
          tooltip: 'Done',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Refine masks',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            key: const ValueKey('room-mask-fullscreen-undo'),
            tooltip: 'Undo',
            icon: const Icon(Icons.undo_rounded),
            onPressed: enabled && state.canEdit && draft!.history.canUndo
                ? () => controller.undo(
                    photoId: draft.photoId,
                    maskRevision: draft.maskRevision,
                  )
                : null,
          ),
          IconButton(
            key: const ValueKey('room-mask-fullscreen-overlay'),
            tooltip: state.showOverlay
                ? 'Hide mask overlay'
                : 'Show mask overlay',
            isSelected: state.showOverlay,
            icon: const Icon(Icons.visibility_off_outlined),
            selectedIcon: const Icon(Icons.visibility_outlined),
            onPressed: enabled
                ? () => controller.setShowOverlay(!state.showOverlay)
                : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !available
          ? const Center(child: Text('This room photo is no longer available.'))
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RoomMaskViewport(
                          key: const ValueKey('room-mask-fullscreen-viewport'),
                          photoId: draft!.photoId,
                          maskRevision: draft.maskRevision,
                          photo: draft.photo,
                          masks: draft.masks,
                          layer: state.selectedLayer,
                          tool: state.tool,
                          brushFraction: state.brushFraction,
                          showOverlay: state.showOverlay,
                          editingEnabled: state.canEdit,
                          viewController: _view,
                          onStroke: (stroke) {
                            if (_active) {
                              controller.applyStroke(
                                photoId: draft.photoId,
                                maskRevision: draft.maskRevision,
                                stroke: stroke,
                              );
                            }
                          },
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Material(
                            color: context.appColors.surface.withValues(
                              alpha: .95,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedBuilder(
                              animation: _view,
                              builder: (context, _) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    key: const ValueKey(
                                      'room-mask-fullscreen-zoom-out',
                                    ),
                                    tooltip: 'Zoom out',
                                    icon: const Icon(Icons.remove_rounded),
                                    onPressed: _view.zoom > 1
                                        ? _view.zoomOut
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      '${_view.zoom.toStringAsFixed(1)}×',
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ),
                                  IconButton(
                                    key: const ValueKey(
                                      'room-mask-fullscreen-zoom-in',
                                    ),
                                    tooltip: 'Zoom in',
                                    icon: const Icon(Icons.add_rounded),
                                    onPressed: _view.zoom < 8
                                        ? _view.zoomIn
                                        : null,
                                  ),
                                  IconButton(
                                    key: const ValueKey(
                                      'room-mask-fullscreen-fit',
                                    ),
                                    tooltip: 'Fit photo',
                                    icon: const Icon(Icons.fit_screen_rounded),
                                    onPressed: _view.reset,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final layer in RoomLayer.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    key: ValueKey(
                                      'room-mask-fullscreen-layer-${layer.name}',
                                    ),
                                    label: Text(_title(layer.name)),
                                    selected: state.selectedLayer == layer,
                                    onSelected: enabled
                                        ? (_) => controller.setLayer(layer)
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final tool in const [
                                      RoomMaskTool.add,
                                      RoomMaskTool.erase,
                                      RoomMaskTool.move,
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: ChoiceChip(
                                          key: ValueKey(
                                            'room-mask-fullscreen-tool-${tool.name}',
                                          ),
                                          avatar: Icon(switch (tool) {
                                            RoomMaskTool.move =>
                                              Icons.pan_tool_outlined,
                                            RoomMaskTool.add =>
                                              Icons.edit_outlined,
                                            RoomMaskTool.erase =>
                                              Icons.auto_fix_normal_rounded,
                                          }, size: 18),
                                          label: Text(switch (tool) {
                                            RoomMaskTool.move => 'Move',
                                            RoomMaskTool.add => 'Pencil',
                                            RoomMaskTool.erase => 'Eraser',
                                          }),
                                          selected: state.tool == tool,
                                          onSelected:
                                              enabled &&
                                                  (state.showOverlay ||
                                                      tool == RoomMaskTool.move)
                                              ? (_) => controller.setTool(tool)
                                              : null,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (state.editBusy)
                              const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'Brush ${(state.brushFraction * 100).round()}%',
                            ),
                            Expanded(
                              child: Slider(
                                key: const ValueKey(
                                  'room-mask-fullscreen-brush',
                                ),
                                value: state.brushFraction,
                                min: .01,
                                max: .20,
                                label:
                                    '${(state.brushFraction * 100).round()}%',
                                onChanged: state.canEdit
                                    ? controller.setBrushFraction
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          !state.showOverlay
                              ? 'Show the overlay to draw. Pinch to zoom.'
                              : switch (state.tool) {
                                  RoomMaskTool.move =>
                                    'Drag to move · Pinch to zoom up to 8×',
                                  RoomMaskTool.add =>
                                    'Pencil adds to ${state.selectedLayer.name} · Pinch to zoom',
                                  RoomMaskTool.erase =>
                                    'Erase from ${state.selectedLayer.name} · Pinch to zoom',
                                },
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  static String _title(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
