import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../domain/room_layer.dart';
import 'room_mask_surface_status.dart';
import 'room_mask_viewport.dart';

/// Every painting/navigation action has a button and a keyboard equivalent.
class RoomMaskRegionNavigator extends StatelessWidget {
  const RoomMaskRegionNavigator({
    super.key,
    required this.view,
    required this.layer,
    required this.onLayerSelected,
    required this.onAdd,
    required this.onErase,
    this.onUndo,
    this.onRedo,
    this.enabled = true,
    this.autofocus = false,
  });

  final RoomMaskViewportController view;
  final RoomLayer layer;
  final ValueChanged<RoomLayer> onLayerSelected;
  final VoidCallback onAdd, onErase;
  final VoidCallback? onUndo, onRedo;
  final bool enabled, autofocus;

  void _nextLayer() => onLayerSelected(RoomLayer.values[(layer.index + 1) % RoomLayer.values.length]);

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
      final delta = key == LogicalKeyboardKey.arrowLeft ? const Offset(-1, 0)
          : key == LogicalKeyboardKey.arrowRight ? const Offset(1, 0)
          : key == LogicalKeyboardKey.arrowUp ? const Offset(0, -1) : const Offset(0, 1);
      if (keyboard.isShiftPressed) { view.panBy(delta * 24); } else { view.nudgeCursor(delta); }
    } else if ((keyboard.isControlPressed || keyboard.isMetaPressed) && key == LogicalKeyboardKey.keyZ) {
      if (enabled) (keyboard.isShiftPressed ? onRedo : onUndo)?.call();
    } else if ((keyboard.isControlPressed || keyboard.isMetaPressed) && key == LogicalKeyboardKey.keyY) {
      if (enabled) onRedo?.call();
    } else if (key == LogicalKeyboardKey.keyA && enabled) { onAdd();
    } else if (key == LogicalKeyboardKey.keyE && enabled) { onErase();
    } else if (key == LogicalKeyboardKey.keyL) { _nextLayer();
    } else if (key == LogicalKeyboardKey.equal || key == LogicalKeyboardKey.numpadAdd) { view.zoomIn();
    } else if (key == LogicalKeyboardKey.minus || key == LogicalKeyboardKey.numpadSubtract) { view.zoomOut();
    } else if (key == LogicalKeyboardKey.digit0) { view.reset();
    } else { return KeyEventResult.ignored; }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: autofocus,
    onKeyEvent: _key,
    child: AnimatedBuilder(
      animation: view,
      builder: (context, _) {
        final cursor = view.sourceCursor;
        return Semantics(
          container: true,
          label: 'Precision mask controls',
          customSemanticsActions: {
            CustomSemanticsAction(label: 'Move cursor left'): () => view.nudgeCursor(const Offset(-1, 0)),
            CustomSemanticsAction(label: 'Move cursor right'): () => view.nudgeCursor(const Offset(1, 0)),
            CustomSemanticsAction(label: 'Move cursor up'): () => view.nudgeCursor(const Offset(0, -1)),
            CustomSemanticsAction(label: 'Move cursor down'): () => view.nudgeCursor(const Offset(0, 1)),
            if (enabled) CustomSemanticsAction(label: 'Add selected surface'): onAdd,
            if (enabled) CustomSemanticsAction(label: 'Erase selected surface'): onErase,
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Position the brush', style: Theme.of(context).textTheme.titleMedium),
              Semantics(liveRegion: true, child: Text(cursor == null
                  ? 'Choose a region or use arrow keys.'
                  : 'Source pixel ${cursor.dx.floor() + 1}, ${cursor.dy.floor() + 1} · ${roomSurfaceTitle(layer)}')),
              Wrap(spacing: 4, runSpacing: 4, children: [
                for (var row = 0; row < 3; row++)
                  for (var column = 0; column < 3; column++)
                    OutlinedButton(
                      key: ValueKey('mask-region-$row-$column'),
                      onPressed: () => view.selectRegion(row, column),
                      child: Text('${const ['Upper', 'Middle', 'Lower'][row]} ${const ['left', 'center', 'right'][column]}'),
                    ),
              ]),
              Wrap(spacing: 4, runSpacing: 4, children: [
                IconButton(tooltip: 'Cursor left', onPressed: () => view.nudgeCursor(const Offset(-1, 0)), icon: const Icon(Icons.arrow_back)),
                IconButton(tooltip: 'Cursor right', onPressed: () => view.nudgeCursor(const Offset(1, 0)), icon: const Icon(Icons.arrow_forward)),
                IconButton(tooltip: 'Cursor up', onPressed: () => view.nudgeCursor(const Offset(0, -1)), icon: const Icon(Icons.arrow_upward)),
                IconButton(tooltip: 'Cursor down', onPressed: () => view.nudgeCursor(const Offset(0, 1)), icon: const Icon(Icons.arrow_downward)),
                TextButton(onPressed: _nextLayer, child: const Text('Next surface')),
                FilledButton(onPressed: enabled ? onAdd : null, child: const Text('Add here')),
                OutlinedButton(onPressed: enabled ? onErase : null, child: const Text('Erase here')),
                OutlinedButton(onPressed: enabled ? onUndo : null, child: const Text('Undo')),
                OutlinedButton(onPressed: enabled ? onRedo : null, child: const Text('Redo')),
                IconButton(tooltip: 'Zoom in', onPressed: view.zoomIn, icon: const Icon(Icons.zoom_in)),
                IconButton(tooltip: 'Zoom out', onPressed: view.zoomOut, icon: const Icon(Icons.zoom_out)),
                TextButton(onPressed: view.reset, child: const Text('Fit photo')),
                IconButton(tooltip: 'Pan left', onPressed: () => view.panBy(const Offset(-24, 0)), icon: const Icon(Icons.chevron_left)),
                IconButton(tooltip: 'Pan right', onPressed: () => view.panBy(const Offset(24, 0)), icon: const Icon(Icons.chevron_right)),
                IconButton(tooltip: 'Pan up', onPressed: () => view.panBy(const Offset(0, -24)), icon: const Icon(Icons.expand_less)),
                IconButton(tooltip: 'Pan down', onPressed: () => view.panBy(const Offset(0, 24)), icon: const Icon(Icons.expand_more)),
              ]),
              const Text('Arrow keys move one source pixel; Shift+arrows pan. '
                  'A adds, E erases, L selects the next surface, +/− zoom, 0 fits. '
                  'Ctrl/Command+Z undoes; Ctrl/Command+Shift+Z redoes.'),
            ],
          ),
        );
      },
    ),
  );
}
