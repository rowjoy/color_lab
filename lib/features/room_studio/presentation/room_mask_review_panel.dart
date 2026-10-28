import 'package:flutter/material.dart';

import '../domain/mask_bitmap.dart';
import '../domain/room_layer.dart';
import 'room_mask_surface_status.dart';

class RoomMaskReviewPanel extends StatefulWidget {
  const RoomMaskReviewPanel({
    super.key,
    required this.photoId,
    required this.maskRevision,
    required this.masks,
    required this.selectedLayer,
    required this.onSelect,
    required this.onViewChanged,
    this.view = RoomMaskReviewView.overlay,
    this.busy = false,
    this.onDone,
    this.onCancel,
  });

  final String photoId;
  final int maskRevision;
  final MaskBitmap masks;
  final RoomLayer selectedLayer;
  final ValueChanged<RoomLayer> onSelect;
  final ValueChanged<RoomMaskReviewView> onViewChanged;
  final RoomMaskReviewView view;
  final bool busy;
  final VoidCallback? onDone, onCancel;

  @override
  State<RoomMaskReviewPanel> createState() => _RoomMaskReviewPanelState();
}

class _RoomMaskReviewPanelState extends State<RoomMaskReviewPanel> {
  var _review = RoomMaskReview();
  bool _completed = false;

  @override
  void didUpdateWidget(covariant RoomMaskReviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId ||
        oldWidget.maskRevision != widget.maskRevision) {
      // Any pixel revision requires a fresh review, including equal coverage.
      _review = RoomMaskReview(selectedLayer: widget.selectedLayer);
      _completed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final layer = widget.selectedLayer;
    final checked = _review.checked.contains(layer);
    return Semantics(
      container: true,
      label: 'Check Masks, surface-by-surface review',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Check Masks', style: Theme.of(context).textTheme.titleLarge),
          const Text('Review every surface. Empty surfaces can be marked Absent.'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final surface in RoomLayer.values)
                ChoiceChip(
                  key: ValueKey('mask-review-layer-${surface.name}'),
                  selected: surface == layer,
                  label: Text(
                    '${roomSurfaceTitle(surface)} · '
                    '${_review.status(surface, widget.masks).name}',
                  ),
                  avatar: Icon(switch (surface) {
                    RoomLayer.wall => Icons.texture,
                    RoomLayer.ceiling => Icons.more_horiz,
                    RoomLayer.floor => Icons.horizontal_rule,
                    RoomLayer.furniture => Icons.grid_4x4,
                  }, size: 18),
                  tooltip: '${roomSurfaceTitle(surface)}, ${roomSurfacePattern(surface)}',
                  onSelected: (_) {
                    setState(() => _review = _review.selectReviewLayer(surface));
                    widget.onSelect(surface);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              '${roomSurfaceTitle(layer)} · ${roomSurfacePattern(layer)}\n'
              '${roomPixelCoverage(widget.masks, layer)}',
              key: const ValueKey('mask-review-coverage'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final view in RoomMaskReviewView.values)
                ChoiceChip(
                  key: ValueKey('mask-review-view-${view.name}'),
                  label: Text(switch (view) {
                    RoomMaskReviewView.original => 'Original',
                    RoomMaskReviewView.recolored => 'Recolored',
                    RoomMaskReviewView.overlay => 'Overlay',
                  }),
                  selected: widget.view == view,
                  onSelected: (_) => widget.onViewChanged(view),
                ),
            ],
          ),
          Semantics(
            liveRegion: true,
            child: Text('View: ${widget.view.name}. '
                '${_review.checked.length} of ${RoomLayer.values.length} surfaces checked.'),
          ),
          if (_completed)
            Semantics(liveRegion: true, child: const Text(
              'All surfaces reviewed. You can review any surface again.',
              key: ValueKey('mask-review-complete'),
            )),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton(
                key: const ValueKey('mask-review-check'),
                onPressed: widget.busy ? null : () {
                  setState(() {
                    _completed = false;
                    _review = checked
                        ? _review.reopen(layer)
                        : _review.markLayerChecked(layer);
                  });
                },
                child: Text(checked
                    ? 'Review again'
                    : widget.masks.count(layer) == 0 ? 'Mark Absent' : 'Mark reviewed'),
              ),
              FilledButton(
                key: const ValueKey('mask-review-done'),
                onPressed: _review.complete && !widget.busy
                    ? () { setState(() => _completed = true); widget.onDone?.call(); }
                    : null,
                child: const Text('Done reviewing'),
              ),
              if (widget.onCancel != null)
                TextButton(onPressed: widget.onCancel, child: const Text('Cancel review')),
            ],
          ),
        ],
      ),
    );
  }
}
