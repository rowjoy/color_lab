import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/domain/saved_color.dart';
import '../../history/presentation/save_color_actions.dart';
import '../domain/photo_viewport.dart';
import '../domain/prepared_photo.dart';
import 'color_explorer.dart';

class PhotoPickerScreen extends ConsumerStatefulWidget {
  const PhotoPickerScreen({super.key, required this.photo});
  final PreparedPhoto photo;

  @override
  ConsumerState<PhotoPickerScreen> createState() => _PhotoPickerScreenState();
}

class _PhotoPickerScreenState extends ConsumerState<PhotoPickerScreen> {
  Offset _selected = const Offset(.5, .5);
  double _zoom = 1;
  Offset _pan = Offset.zero;
  Size _size = Size.zero;
  bool _dragging = false;
  bool _multitouch = false;
  final _pointers = <int, Offset>{};
  Offset _gestureCenter = Offset.zero;
  double _gestureDistance = 1;
  double _gestureZoom = 1;
  Offset _gesturePan = Offset.zero;

  PhotoViewport get _viewport => PhotoViewport(
    imageSize: Size(
      widget.photo.width.toDouble(),
      widget.photo.height.toDouble(),
    ),
    size: _size,
    zoom: _zoom,
    pan: _pan,
  );

  void _sample(Offset point) {
    final normalized = _viewport.normalizedAt(point);
    if (normalized != null) _selected = normalized;
  }

  void _down(PointerDownEvent event) {
    setState(() {
      _pointers[event.pointer] = event.localPosition;
      if (_pointers.length == 1) {
        _sample(event.localPosition);
      } else {
        _multitouch = true;
        _dragging = false;
        final points = _pointers.values.take(2).toList();
        _gestureCenter = (points[0] + points[1]) / 2;
        _gestureDistance = math.max(1, (points[0] - points[1]).distance);
        _gestureZoom = _zoom;
        _gesturePan = _pan;
      }
    });
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    setState(() {
      _pointers[event.pointer] = event.localPosition;
      if (_pointers.length >= 2) {
        final points = _pointers.values.take(2).toList();
        final center = (points[0] + points[1]) / 2;
        final distance = (points[0] - points[1]).distance;
        _zoom = (_gestureZoom * distance / _gestureDistance).clamp(1.0, 8.0);
        final viewportCenter = _size.center(Offset.zero);
        _pan =
            center -
            viewportCenter -
            (_gestureCenter - viewportCenter - _gesturePan) *
                (_zoom / _gestureZoom);
        final image = _viewport.imageRect;
        final maxX = math.max(0.0, (image.width - _size.width) / 2);
        final maxY = math.max(0.0, (image.height - _size.height) / 2);
        _pan = Offset(_pan.dx.clamp(-maxX, maxX), _pan.dy.clamp(-maxY, maxY));
      } else if (!_multitouch) {
        _dragging = _viewport.normalizedAt(event.localPosition) != null;
        _sample(event.localPosition);
      }
    });
  }

  void _up(PointerEvent event) {
    setState(() {
      _pointers.remove(event.pointer);
      _dragging = false;
      if (_pointers.isEmpty) _multitouch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.photo.sample(_selected.dx, _selected.dy);
    final name = ref
        .watch(colorNamerProvider)
        .asData
        ?.value
        .nearest(color)
        .name;
    return Scaffold(
      appBar: AppBar(title: const Text('Photo study')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Text(
                  'Touch a shade. Drag to look closer. Use two fingers to zoom and move.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * .42).clamp(
                  240.0,
                  440.0,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _size = constraints.biggest;
                    return _buildPreview(color);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      '${_zoom.toStringAsFixed(1)}×',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () =>
                          setState(() => _sample(_size.center(Offset.zero))),
                      icon: const Icon(Icons.center_focus_strong_rounded),
                      label: const Text('Sample center'),
                    ),
                    IconButton(
                      tooltip: 'Reset photo zoom',
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => setState(() {
                        _zoom = 1;
                        _pan = Offset.zero;
                      }),
                      icon: const Icon(Icons.fit_screen_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        name ?? 'Picked shade',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 64),
                        padding: const EdgeInsets.all(12),
                      ),
                      onPressed: () => showColorDetails(
                        context,
                        color,
                        source: ColorSource.gallery,
                        heroTag: 'photo-selected-color',
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Hero(
                            tag: 'photo-selected-color',
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: displayColor(color),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: context.appColors.outline,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            color.hex,
                            key: const ValueKey('photo-selected-hex'),
                          ),
                          const Icon(Icons.arrow_outward_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'RGB ${color.red}, ${color.green}, ${color.blue}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SaveColorActions(
                      color: color,
                      name: name,
                      source: ColorSource.gallery,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'From this photo',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The share of each shade in your image.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (widget.photo.palette.isEmpty)
                      const Text(
                        'No palette could be found. You can still sample any shade above.',
                      )
                    else ...[
                      PaletteBar(
                        key: const ValueKey('photo-palette-bar'),
                        colors: [
                          for (final entry in widget.photo.palette)
                            displayColor(entry.color),
                        ],
                        weights: [
                          for (final entry in widget.photo.palette)
                            entry.population,
                        ],
                        onColorTap: (index) => showColorDetails(
                          context,
                          widget.photo.palette[index].color,
                          source: ColorSource.gallery,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var i = 0; i < widget.photo.palette.length; i++)
                            _PaletteSwatch(
                              key: ValueKey('photo-palette-$i'),
                              entry: widget.photo.palette[i],
                              onTap: () => showColorDetails(
                                context,
                                widget.photo.palette[i].color,
                                source: ColorSource.gallery,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(RgbColor color) {
    final viewport = _viewport;
    final imageRect = viewport.imageRect;
    final position = viewport.positionOf(_selected);
    final image = Image.memory(
      widget.photo.previewBytes,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('This preview could not be shown. Try another photo.'),
        ),
      ),
    );
    return Semantics(
      label:
          'Photo color sampler. Touch or drag to sample. Pinch with two fingers to zoom.',
      image: true,
      child: GestureDetector(
        // Claim drags within the picture so its enclosing page can still scroll
        // outside it. Pointer positions remain in the same viewport coordinates.
        onScaleStart: (_) {},
        onScaleUpdate: (_) {},
        onScaleEnd: (_) {},
        child: Listener(
          key: const ValueKey('photo-viewport'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _up,
          child: ClipRect(
            child: ColoredBox(
              color: context.appColors.surfaceElevated,
              child: Stack(
                children: [
                  Positioned.fromRect(rect: imageRect, child: image),
                  if (Offset.zero & _size case final bounds
                      when bounds.contains(position))
                    Positioned(
                      left: position.dx - 15,
                      top: position.dy - 15,
                      child: IgnorePointer(
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 2),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: displayColor(color),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_dragging)
                    Positioned(
                      left: (position.dx - 52).clamp(
                        8.0,
                        math.max(8.0, _size.width - 112),
                      ),
                      top: position.dy > 130
                          ? position.dy - 124
                          : position.dy + 28,
                      child: IgnorePointer(
                        child: _PhotoLoupe(
                          photo: widget.photo,
                          normalized: _selected,
                          imageSize: imageRect.size,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoLoupe extends StatelessWidget {
  const _PhotoLoupe({
    required this.photo,
    required this.normalized,
    required this.imageSize,
  });
  final PreparedPhoto photo;
  final Offset normalized;
  final Size imageSize;

  @override
  Widget build(BuildContext context) {
    final magnified = imageSize * 3;
    return Container(
      key: const ValueKey('photo-loupe'),
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.white)),
            Positioned(
              left: 49 - normalized.dx * magnified.width,
              top: 49 - normalized.dy * magnified.height,
              width: magnified.width,
              height: magnified.height,
              child: Image.memory(
                photo.previewBytes,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                excludeFromSemantics: true,
              ),
            ),
            const Center(
              child: Icon(
                Icons.add_rounded,
                size: 24,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black, blurRadius: 2)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({super.key, required this.entry, required this.onTap});
  final PaletteColor entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${entry.color.hex}, ${(entry.population * 100).toStringAsFixed(1)} percent of photo',
    button: true,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(128, 64),
        padding: const EdgeInsets.all(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 48,
            decoration: BoxDecoration(
              color: displayColor(entry.color),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appColors.outline),
            ),
          ),
          const SizedBox(height: 8),
          Text(entry.color.hex),
          Text('${(entry.population * 100).toStringAsFixed(1)}%'),
        ],
      ),
    ),
  );
}
