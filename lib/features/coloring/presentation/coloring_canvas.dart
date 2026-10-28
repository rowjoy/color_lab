import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter/semantics.dart';

import '../../../l10n/l10n.dart';

import '../../../core/color/color_models.dart';
import '../../../core/vector_regions/application/vector_region_transform.dart';
import '../domain/drawing_definition.dart';
import '../domain/drawing_geometry.dart';
import '../rendering/coloring_artwork_renderer.dart';

class ColoringCanvas extends StatefulWidget {
  const ColoringCanvas({
    super.key,
    required this.definition,
    required this.assignments,
    required this.onRegionTap,
    this.focusedRegionId,
  });

  final DrawingDefinition definition;
  final Map<String, RgbColor> assignments;
  final ValueChanged<String> onRegionTap;
  final String? focusedRegionId;

  @override
  State<ColoringCanvas> createState() => _ColoringCanvasState();
}

class _ColoringCanvasState extends State<ColoringCanvas> {
  double _zoom = 1;
  Offset _pan = Offset.zero;
  int _pointers = 0;
  bool _transforming = false;
  bool _cancelTap = false;
  double _gestureStartZoom = 1;
  Offset _gestureStartFocal = Offset.zero;
  Offset _gestureStartPan = Offset.zero;
  Size? _lastViewport;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (size.isEmpty) return const SizedBox.shrink();
      if (_lastViewport != null && _lastViewport != size && _pointers > 0) {
        _cancelTap = true;
      }
      _lastViewport = size;
      final transform = VectorRegionTransform.fit(
        intrinsicSize: widget.definition.artwork.intrinsicSize,
        viewport: size,
        zoom: _zoom,
        pan: _pan,
      );
      return Listener(
        onPointerDown: (_) {
          if (_pointers == 0) {
            _cancelTap = false;
            _transforming = false;
          }
          _pointers++;
          if (_pointers > 1) _cancelTap = true;
        },
        onPointerUp: (_) => _pointers = (_pointers - 1).clamp(0, 10),
        onPointerCancel: (_) {
          _cancelTap = true;
          _pointers = (_pointers - 1).clamp(0, 10);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: (details) {
            _gestureStartZoom = _zoom;
            _gestureStartFocal = details.focalPoint;
            _gestureStartPan = _pan;
          },
          onScaleUpdate: (details) {
            final delta = details.focalPoint - _gestureStartFocal;
            if (details.scale == 1 && delta.distance < 3 && _pointers < 2) {
              return;
            }
            _transforming = true;
            _cancelTap = true;
            setState(() {
              _zoom = (_gestureStartZoom * details.scale).clamp(1, 4);
              _pan = _gestureStartPan + delta;
            });
          },
          onScaleEnd: (_) {
            if (_transforming) _cancelTap = true;
          },
          onTapUp: (details) {
            if (_cancelTap || _transforming || _pointers > 1) return;
            final region = DrawingGeometry.hitTest(
              widget.definition,
              details.localPosition,
              transform,
            );
            if (region != null) widget.onRegionTap(region.id);
          },
          child: CustomPaint(
            key: const ValueKey('coloring-canvas-paint'),
            size: size,
            painter: _ColoringPainter(
              definition: widget.definition,
              assignments: widget.assignments,
              focusedRegionId: widget.focusedRegionId,
              transform: transform,
              focus: Theme.of(context).colorScheme.primary,
              textDirection: Directionality.of(context),
              l10n: context.l10n,
              onRegionTap: widget.onRegionTap,
            ),
          ),
        ),
      );
    },
  );
}

final class _ColoringPainter extends CustomPainter {
  _ColoringPainter({
    required this.definition,
    required this.assignments,
    required this.focusedRegionId,
    required this.transform,
    required this.focus,
    required this.textDirection,
    required this.l10n,
    required this.onRegionTap,
  });

  final DrawingDefinition definition;
  final Map<String, RgbColor> assignments;
  final String? focusedRegionId;
  final VectorRegionTransform transform;
  final Color focus;
  final TextDirection textDirection;
  final AppLocalizations l10n;
  final ValueChanged<String> onRegionTap;

  @override
  void paint(Canvas canvas, Size size) {
    ColoringArtworkRenderer.draw(canvas, definition, assignments, transform);
    if (focusedRegionId != null) {
      final region = definition.artwork.regions
          .where((item) => item.id == focusedRegionId)
          .firstOrNull;
      if (region != null) {
        canvas.save();
        transform.apply(canvas);
        canvas.clipRect(Offset.zero & definition.artwork.intrinsicSize);
        canvas.drawPath(
          region.geometry.toPath(),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 / ((transform.scaleX + transform.scaleY) / 2)
            ..color = focus,
        );
        canvas.restore();
      }
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final region in definition.artwork.regions)
          CustomPainterSemantics(
            rect: transform.screenBounds(region.geometry.bounds),
            properties: SemanticsProperties(
              label: l10n.coloringRegionLabel(region.labelKey),
              button: true,
              selected: region.id == focusedRegionId,
              value: assignments[region.id]?.hex ?? l10n.coloringNotColored,
              textDirection: textDirection,
              onTap: () => onRegionTap(region.id),
            ),
          ),
      ];

  @override
  bool shouldRepaint(covariant _ColoringPainter oldDelegate) =>
      oldDelegate.definition != definition ||
      !mapEquals(oldDelegate.assignments, assignments) ||
      oldDelegate.focusedRegionId != focusedRegionId ||
      oldDelegate.transform.scaleX != transform.scaleX ||
      oldDelegate.transform.scaleY != transform.scaleY ||
      oldDelegate.transform.offset != transform.offset ||
      oldDelegate.focus != focus;

  @override
  bool shouldRebuildSemantics(covariant _ColoringPainter oldDelegate) =>
      shouldRepaint(oldDelegate) ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.l10n != l10n;
}
