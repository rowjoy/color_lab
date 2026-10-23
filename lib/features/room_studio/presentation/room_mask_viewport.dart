import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_models.dart';
import '../../../core/theme/app_colors.dart';
import '../../picker/domain/photo_viewport.dart';
import '../../picker/domain/prepared_photo.dart';
import '../application/mask_overlay_service.dart';
import '../domain/mask_bitmap.dart';
import '../domain/mask_stroke.dart';
import '../domain/room_layer.dart';
import '../domain/room_mask_state.dart';

/// View controls share the very same transform used to place brush strokes.
class RoomMaskViewportController extends ChangeNotifier {
  _RoomMaskViewportState? _viewport;

  double get zoom => _viewport?._zoom ?? 1;

  void zoomIn() => _viewport?._changeZoom(zoom * 1.5);
  void zoomOut() => _viewport?._changeZoom(zoom / 1.5);
  void reset() => _viewport?._resetView();

  void _changed() => notifyListeners();
}

/// Displays a transparent ownership preview over the unchanged room photo.
/// The parent owns masks/revisions; this widget owns only images and gestures.
class RoomMaskViewport extends ConsumerStatefulWidget {
  const RoomMaskViewport({
    super.key,
    required this.photoId,
    required this.maskRevision,
    required this.photo,
    required this.masks,
    required this.layer,
    required this.tool,
    required this.brushFraction,
    required this.showOverlay,
    required this.editingEnabled,
    required this.onStroke,
    this.viewController,
  });

  final String photoId;
  final int maskRevision;
  final PreparedPhoto photo;
  final MaskBitmap masks;
  final RoomLayer layer;
  final RoomMaskTool tool;
  final double brushFraction;
  final bool showOverlay;
  final bool editingEnabled;
  final ValueChanged<MaskStroke> onStroke;
  final RoomMaskViewportController? viewController;

  @override
  ConsumerState<RoomMaskViewport> createState() => _RoomMaskViewportState();
}

typedef _OverlayKey = ({
  String photoId,
  int revision,
  RoomLayer layer,
  int tint,
  int feather,
});

class _RoomMaskViewportState extends ConsumerState<RoomMaskViewport> {
  ui.Image? _photo;
  ui.Image? _overlay;
  int _photoGeneration = 0;
  int _overlayGeneration = 0;
  _OverlayKey? _overlayKey;
  Color _tint = AppColors.light.primary;
  bool _overlayFailed = false;
  Size _size = Size.zero;
  double _zoom = 1;
  Offset _pan = Offset.zero;
  final _pointers = <int, Offset>{};
  bool _blocked = false;
  final _segments = <List<MaskPoint>>[];
  bool _gap = true;
  RoomLayer? _strokeLayer;
  MaskEditMode? _strokeMode;
  double _strokeDiameter = .05;
  Offset _gestureCenter = Offset.zero;
  Offset _gesturePan = Offset.zero;
  double _gestureDistance = 1;
  double _gestureZoom = 1;

  PhotoViewport get _viewport => PhotoViewport(
    imageSize: Size(
      widget.photo.width.toDouble(),
      widget.photo.height.toDouble(),
    ),
    size: _size,
    zoom: _zoom,
    pan: _pan,
  );

  @override
  void initState() {
    super.initState();
    widget.viewController?._viewport = this;
    _loadPhoto();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tint = context.appColors.primary;
    _loadOverlay();
  }

  @override
  void didUpdateWidget(covariant RoomMaskViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewController != widget.viewController) {
      if (oldWidget.viewController?._viewport == this) {
        oldWidget.viewController?._viewport = null;
      }
      widget.viewController?._viewport = this;
    }
    final newPhoto =
        oldWidget.photoId != widget.photoId ||
        !identical(oldWidget.photo, widget.photo);
    if (newPhoto ||
        oldWidget.maskRevision != widget.maskRevision ||
        oldWidget.tool != widget.tool ||
        oldWidget.layer != widget.layer ||
        oldWidget.editingEnabled != widget.editingEnabled ||
        oldWidget.showOverlay != widget.showOverlay ||
        oldWidget.brushFraction != widget.brushFraction) {
      _cancelStroke();
      _blocked = _pointers.isNotEmpty;
    }
    if (newPhoto) {
      _zoom = 1;
      _pan = Offset.zero;
      _loadPhoto();
      // Even a replaced PreparedPhoto under the same ID must never reuse pixels.
      _overlayKey = null;
    }
    _loadOverlay();
  }

  Future<ui.Image> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _loadPhoto() async {
    final generation = ++_photoGeneration;
    _photo?.dispose();
    _photo = null;
    try {
      final image = await _decode(widget.photo.previewBytes);
      if (!mounted || generation != _photoGeneration) {
        image.dispose();
        return;
      }
      setState(() => _photo = image);
    } catch (_) {
      // PreparedPhoto is validated upstream; failed decoding leaves no stale image.
    }
  }

  Future<void> _loadOverlay() async {
    final key = (
      photoId: widget.photoId,
      revision: widget.maskRevision,
      layer: widget.layer,
      tint: _tint.toARGB32(),
      feather: 2,
    );
    if (key == _overlayKey) return;
    _overlayKey = key;
    final generation = ++_overlayGeneration;
    _overlay?.dispose();
    _overlay = null;
    _overlayFailed = false;
    try {
      final bytes = await ref
          .read(maskOverlayServiceProvider)
          .render(
            masks: widget.masks,
            layer: key.layer,
            tint: RgbColor(
              (key.tint >> 16) & 255,
              (key.tint >> 8) & 255,
              key.tint & 255,
            ),
            featherRadius: key.feather,
          );
      if (!mounted || generation != _overlayGeneration) return;
      final image = await _decode(bytes);
      if (!mounted || generation != _overlayGeneration) {
        image.dispose();
        return;
      }
      setState(() => _overlay = image);
    } catch (_) {
      if (mounted && generation == _overlayGeneration) {
        setState(() => _overlayFailed = true);
      }
    }
  }

  void _cancelStroke() {
    _segments.clear();
    _strokeLayer = null;
    _strokeMode = null;
    _gap = true;
  }

  void _append(Offset position) {
    // The image can extend beyond the visible clip after zooming. Invisible
    // pointer travel is a disconnected gap, just like travel in a letterbox.
    final normalized = (Offset.zero & _size).contains(position)
        ? _viewport.normalizedAt(position)
        : null;
    if (normalized == null) {
      _gap = true;
      return;
    }
    if (_gap) _segments.add([]);
    _gap = false;
    final segment = _segments.last;
    if (segment.isEmpty ||
        segment.last.x != normalized.dx ||
        segment.last.y != normalized.dy) {
      segment.add(MaskPoint(normalized.dx, normalized.dy));
    }
  }

  void _anchorMove() {
    final points = _pointers.values.take(2).toList();
    _gestureCenter = points.length == 1
        ? points[0]
        : (points[0] + points[1]) / 2;
    _gestureDistance = points.length == 1
        ? 1
        : math.max(1, (points[0] - points[1]).distance);
    _gesturePan = _pan;
    _gestureZoom = _zoom;
  }

  void _clampPan() {
    final rect = _viewport.imageRect;
    final x = math.max(0.0, (rect.width - _size.width) / 2);
    final y = math.max(0.0, (rect.height - _size.height) / 2);
    _pan = Offset(_pan.dx.clamp(-x, x), _pan.dy.clamp(-y, y));
  }

  void _changeZoom(double zoom) {
    setState(() {
      _cancelStroke();
      _blocked = _pointers.isNotEmpty;
      final next = zoom.clamp(1.0, 8.0);
      _pan *= next / _zoom;
      _zoom = next;
      _clampPan();
      if (_pointers.isNotEmpty) _anchorMove();
    });
    widget.viewController?._changed();
  }

  void _resetView() {
    setState(() {
      _cancelStroke();
      _blocked = _pointers.isNotEmpty;
      _zoom = 1;
      _pan = Offset.zero;
      if (_pointers.isNotEmpty) _anchorMove();
    });
    widget.viewController?._changed();
  }

  void _transform() {
    final points = _pointers.values.take(2).toList();
    final center = points.length == 1 ? points[0] : (points[0] + points[1]) / 2;
    if (points.length > 1) {
      _zoom =
          (_gestureZoom * (points[0] - points[1]).distance / _gestureDistance)
              .clamp(1.0, 8.0);
    }
    final viewportCenter = _size.center(Offset.zero);
    _pan =
        center -
        viewportCenter -
        (_gestureCenter - viewportCenter - _gesturePan) *
            (_zoom / _gestureZoom);
    _clampPan();
  }

  void _down(PointerDownEvent event) {
    if (!mounted) return;
    setState(() {
      _pointers[event.pointer] = event.localPosition;
      if (_pointers.length > 1) {
        _cancelStroke();
        _blocked = true;
        _anchorMove();
        return;
      }
      if (widget.tool == RoomMaskTool.move) {
        _anchorMove();
        return;
      }
      if (_blocked ||
          !widget.editingEnabled ||
          !widget.showOverlay ||
          widget.tool == RoomMaskTool.move) {
        return;
      }
      _strokeLayer = widget.layer;
      _strokeMode = widget.tool == RoomMaskTool.add
          ? MaskEditMode.add
          : MaskEditMode.erase;
      _strokeDiameter = widget.brushFraction;
      _append(event.localPosition);
    });
  }

  void _move(PointerMoveEvent event) {
    if (!mounted || !_pointers.containsKey(event.pointer)) return;
    final previousZoom = _zoom;
    setState(() {
      _pointers[event.pointer] = event.localPosition;
      if (_pointers.length > 1 || widget.tool == RoomMaskTool.move) {
        _transform();
      } else if (!_blocked && _strokeLayer != null) {
        _append(event.localPosition);
      }
    });
    if (previousZoom != _zoom) widget.viewController?._changed();
  }

  void _up(PointerUpEvent event) {
    if (!mounted || !_pointers.containsKey(event.pointer)) return;
    MaskStroke? accepted;
    setState(() {
      if (!_blocked && _pointers.length == 1 && _strokeLayer != null) {
        _append(event.localPosition);
        if (_segments.isNotEmpty) {
          accepted = MaskStroke(
            layer: _strokeLayer!,
            mode: _strokeMode!,
            segments: _segments,
            diameterFraction: _strokeDiameter,
          );
        }
      }
      _cancelStroke();
      _pointers.remove(event.pointer);
      if (_pointers.isEmpty) {
        _blocked = false;
      } else if (_pointers.length > 1 || widget.tool == RoomMaskTool.move) {
        _anchorMove();
      }
    });
    if (accepted != null) widget.onStroke(accepted!);
  }

  void _cancel(PointerCancelEvent event) {
    if (!mounted) return;
    setState(() {
      _cancelStroke();
      _pointers.remove(event.pointer);
      _blocked = _pointers.isNotEmpty;
      if (_pointers.isNotEmpty) _anchorMove();
    });
  }

  @override
  void dispose() {
    if (widget.viewController?._viewport == this) {
      widget.viewController?._viewport = null;
    }
    _photoGeneration++;
    _overlayGeneration++;
    _photo?.dispose();
    _overlay?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.layer.name;
    final label = '${name[0].toUpperCase()}${name.substring(1)}';
    return Semantics(
      image: true,
      label: widget.showOverlay
          ? 'Room photo, $label mask preview${_overlayFailed ? ' unavailable' : ''}'
          : 'Original room photo',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          if (_size != size) {
            _size = size;
            _cancelStroke();
            _blocked = _pointers.isNotEmpty;
            _clampPan();
          }
          final interactive =
              widget.tool == RoomMaskTool.move ||
              (widget.editingEnabled && widget.showOverlay);
          return ClipRect(
            // Claim editor drags against an ancestor ScrollView. Raw events
            // retain single-pointer buffering and explicit cancellation rules.
            child: RawGestureDetector(
              excludeFromSemantics: true,
              gestures: {
                if (interactive)
                  EagerGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        EagerGestureRecognizer
                      >(EagerGestureRecognizer.new, (_) {}),
              },
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _down,
                onPointerMove: _move,
                onPointerUp: _up,
                onPointerCancel: _cancel,
                child: CustomPaint(
                  size: size,
                  painter: _MaskPainter(
                    viewport: _viewport,
                    photo: _photo,
                    overlay: widget.showOverlay ? _overlay : null,
                    background: context.appColors.surfaceElevated,
                    tint: _tint,
                    segments: _segments
                        .map((segment) => List<MaskPoint>.of(segment))
                        .toList(),
                    diameter: _strokeDiameter,
                    erase: _strokeMode == MaskEditMode.erase,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  _MaskPainter({
    required this.viewport,
    required this.photo,
    required this.overlay,
    required this.background,
    required this.tint,
    required this.segments,
    required this.diameter,
    required this.erase,
  });

  final PhotoViewport viewport;
  final ui.Image? photo;
  final ui.Image? overlay;
  final Color background;
  final Color tint;
  final List<List<MaskPoint>> segments;
  final double diameter;
  final bool erase;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final rect = viewport.imageRect;
    void draw(ui.Image image, double opacity) => canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..filterQuality = FilterQuality.none,
    );
    if (photo != null) draw(photo!, 1);
    if (overlay != null && photo != null) draw(overlay!, .45);
    canvas.save();
    canvas.clipRect(rect);
    final width = math.min(rect.width, rect.height) * diameter;
    final paint = Paint()
      ..color = (erase ? Colors.white : tint).withValues(alpha: .7)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final segment in segments) {
      final first = viewport.positionOf(
        Offset(segment.first.x, segment.first.y),
      );
      if (segment.length == 1) {
        canvas.drawCircle(first, width / 2, Paint()..color = paint.color);
      } else {
        final path = Path()..moveTo(first.dx, first.dy);
        for (final point in segment.skip(1)) {
          final position = viewport.positionOf(Offset(point.x, point.y));
          path.lineTo(position.dx, position.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaskPainter oldDelegate) => true;
}
