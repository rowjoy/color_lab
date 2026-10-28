import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/room_mask_controller.dart';
import '../application/room_recolor_provider.dart';
import '../domain/mask_stroke.dart';
import '../domain/room_layer.dart';
import '../domain/room_mask_state.dart';
import 'room_mask_region_navigator.dart';
import 'room_mask_review_panel.dart';
import 'room_mask_surface_status.dart';
import 'room_mask_viewport.dart';
import 'room_recolor_viewport.dart';

class RoomMaskFullscreenEditor extends ConsumerStatefulWidget {
  const RoomMaskFullscreenEditor({super.key, required this.photoId});
  final String photoId;

  @override
  ConsumerState<RoomMaskFullscreenEditor> createState() => _RoomMaskFullscreenEditorState();
}

class _RoomMaskFullscreenEditorState extends ConsumerState<RoomMaskFullscreenEditor>
    with WidgetsBindingObserver {
  final _view = RoomMaskViewportController();
  late final RoomMaskController _editor;
  late final RoomRecolorCoordinator _previews;
  Object? _previewOwner;
  RoomMaskReviewView _reviewView = RoomMaskReviewView.overlay;

  bool get _active => mounted && (ModalRoute.of(context)?.isCurrent ?? false) &&
      (WidgetsBinding.instance.lifecycleState == null ||
       WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    _editor = ref.read(roomMaskProvider.notifier);
    _previews = ref.read(roomRecolorCoordinatorProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_active && (_previewOwner == null || !_previews.owns(_previewOwner!))) {
      _previewOwner = _previews.attachOwner(isVisible: () => _active);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _editor.cancelStroke();
      _view.cancelStroke();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _editor.cancelStroke();
    if (_previewOwner != null) _previews.detachOwner(_previewOwner!);
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roomMaskProvider);
    final draft = state.draft;
    final available = draft?.photoId == widget.photoId;
    final enabled = available && state.stage == RoomMaskStage.ready && !state.editBusy;
    final key = ref.watch(roomRecolorKeyProvider);
    final frame = ref.watch(roomRecolorDisplayProvider);
    final preview = ref.watch(roomRecolorPreviewProvider);
    void close() {
      _view.cancelStroke();
      _editor.cancelStroke();
      Navigator.of(context).pop();
    }
    void paint(MaskEditMode mode) {
      if (!_active || !state.canEdit) return;
      _editor.setTool(mode == MaskEditMode.add ? RoomMaskTool.add : RoomMaskTool.erase);
      _view.paintCursor(mode);
    }
    VoidCallback? undo = enabled && state.canEdit && draft!.history.canUndo
        ? () => _editor.undo(photoId: draft.photoId, maskRevision: draft.maskRevision)
        : null;
    VoidCallback? redo = enabled && state.canEdit && draft!.history.canRedo
        ? () => _editor.redo(photoId: draft.photoId, maskRevision: draft.maskRevision)
        : null;
    return Scaffold(
      key: const ValueKey('room-mask-fullscreen-editor'),
      backgroundColor: context.appColors.surface,
      appBar: AppBar(
        leading: IconButton(key: const ValueKey('room-mask-fullscreen-close'),
          tooltip: 'Done', onPressed: close, icon: const Icon(Icons.close_rounded)),
        title: const Text('Check Masks', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(key: const ValueKey('room-mask-fullscreen-undo'), tooltip: 'Undo', onPressed: undo, icon: const Icon(Icons.undo_rounded)),
          IconButton(key: const ValueKey('room-mask-fullscreen-redo'), tooltip: 'Redo', onPressed: redo, icon: const Icon(Icons.redo_rounded)),
          IconButton(key: const ValueKey('room-mask-fullscreen-overlay'),
            tooltip: state.showOverlay ? 'Hide mask overlay' : 'Show mask overlay',
            isSelected: state.showOverlay,
            icon: const Icon(Icons.visibility_off_outlined),
            selectedIcon: const Icon(Icons.visibility_outlined),
            onPressed: () {
              _view.cancelStroke();
              _editor.setShowOverlay(!state.showOverlay);
              setState(() => _reviewView = state.showOverlay ? RoomMaskReviewView.original : RoomMaskReviewView.overlay);
            }),
        ],
      ),
      body: !available
          ? const Center(child: Text('This room photo is no longer available.'))
          : SafeArea(top: false, child: LayoutBuilder(builder: (context, constraints) => Column(
              children: [
                Expanded(child: Stack(fit: StackFit.expand, children: [
                  if (_reviewView == RoomMaskReviewView.recolored && key != null)
                    SingleChildScrollView(child: RoomRecolorViewport(
                      sourcePngBytes: draft!.photo.previewBytes,
                      width: draft.photo.width,
                      height: draft.photo.height,
                      currentKey: key,
                      frame: frame,
                      showAfter: true,
                      updating: preview.isLoading,
                    ))
                  else
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
                        if (_active) _editor.applyStroke(photoId: draft.photoId, maskRevision: draft.maskRevision, stroke: stroke);
                      },
                    ),
                  PositionedDirectional(top: 4, start: 4, child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(key: const ValueKey('room-mask-fullscreen-zoom-out'), tooltip: 'Zoom out', onPressed: _view.zoomOut, icon: const Icon(Icons.remove)),
                      IconButton(key: const ValueKey('room-mask-fullscreen-zoom-in'), tooltip: 'Zoom in', onPressed: _view.zoomIn, icon: const Icon(Icons.add)),
                      IconButton(key: const ValueKey('room-mask-fullscreen-fit'), tooltip: 'Fit photo', onPressed: _view.reset, icon: const Icon(Icons.fit_screen)),
                    ]),
                  )),
                ])),
                const Divider(height: 1),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: constraints.maxHeight * .5),
                  child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RoomMaskReviewPanel(
                        photoId: draft!.photoId,
                        maskRevision: draft.maskRevision,
                        masks: draft.masks,
                        selectedLayer: state.selectedLayer,
                        busy: !enabled,
                        view: _reviewView,
                        onSelect: _editor.setLayer,
                        onDone: close,
                        onCancel: close,
                        onViewChanged: (view) {
                          _view.cancelStroke();
                          _editor.setShowOverlay(view == RoomMaskReviewView.overlay);
                          setState(() => _reviewView = view);
                        },
                      ),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        for (final layer in RoomLayer.values)
                          ChoiceChip(key: ValueKey('room-mask-fullscreen-layer-${layer.name}'),
                            label: Text(roomSurfaceTitle(layer)),
                            selected: layer == state.selectedLayer,
                            onSelected: (_) => _editor.setLayer(layer)),
                        for (final tool in RoomMaskTool.values)
                          ChoiceChip(key: ValueKey('room-mask-fullscreen-tool-${tool.name}'),
                            label: Text(switch (tool) { RoomMaskTool.move => 'Move', RoomMaskTool.add => 'Pencil', RoomMaskTool.erase => 'Eraser' }),
                            selected: state.tool == tool,
                            onSelected: enabled && (state.showOverlay || tool == RoomMaskTool.move)
                                ? (_) => _editor.setTool(tool) : null),
                      ]),
                      Text('Brush ${(state.brushFraction * 100).toStringAsFixed(1)}% of the shorter image side'),
                      Slider(key: const ValueKey('room-mask-fullscreen-brush'),
                        value: state.brushFraction, min: .005, max: .20,
                        semanticFormatterCallback: (value) => '${(value * 100).toStringAsFixed(1)} percent of the shorter image side',
                        onChanged: state.canEdit ? _editor.setBrushFraction : null),
                      if (state.editBusy) Semantics(liveRegion: true, child: const Text('Applying mask edit…')),
                      RoomMaskRegionNavigator(
                        view: _view,
                        layer: state.selectedLayer,
                        enabled: state.canEdit,
                        autofocus: true,
                        onLayerSelected: _editor.setLayer,
                        onAdd: () => paint(MaskEditMode.add),
                        onErase: () => paint(MaskEditMode.erase),
                        onUndo: undo,
                        onRedo: redo,
                      ),
                    ],
                  )),
                ),
              ],
            ))),
    );
  }
}
