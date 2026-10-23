import 'package:flutter/material.dart';

import '../../../core/color/color_models.dart';
import '../domain/vision_dot_pattern.dart';
import '../domain/vision_plate.dart';

/// A read-only, original dot pattern. Response controls belong to its parent.
class VisionPlateView extends StatefulWidget {
  const VisionPlateView({super.key, required this.plate});

  final VisionPlate plate;

  @override
  State<VisionPlateView> createState() => _VisionPlateViewState();
}

class _VisionPlateViewState extends State<VisionPlateView> {
  late _VisionPlatePainter _painter;

  @override
  void initState() {
    super.initState();
    _cachePlate();
  }

  @override
  void didUpdateWidget(VisionPlateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plate != widget.plate) _cachePlate();
  }

  void _cachePlate() {
    _painter = _VisionPlatePainter(
      plate: widget.plate,
      dots: generateVisionDots(widget.plate),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    image: true,
    label:
        'Generated dot pattern. Enter the number you see, or choose Not sure.',
    child: ExcludeSemantics(
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(painter: _painter),
        ),
      ),
    ),
  );
}

class _VisionPlatePainter extends CustomPainter {
  _VisionPlatePainter({required this.plate, required List<VisionDot> dots})
    : dots = List.unmodifiable(dots);

  final VisionPlate plate;
  final List<VisionDot> dots;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final origin = size.center(Offset.zero) - Offset(side / 2, side / 2);
    final paint = Paint()..color = _color(visionPlatePaper);
    canvas.drawCircle(size.center(Offset.zero), side / 2, paint);
    for (final dot in dots) {
      paint.color = _color(dot.color);
      canvas.drawCircle(
        origin + Offset(dot.x * side, dot.y * side),
        dot.radius * side,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VisionPlatePainter oldDelegate) =>
      oldDelegate.plate != plate;
}

Color _color(RgbColor color) => Color(0xff000000 | color.value);
