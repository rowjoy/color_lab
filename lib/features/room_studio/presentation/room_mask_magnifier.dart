import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../picker/domain/photo_viewport.dart';

/// The outline and magnifier use this one clamped source sample.
final class RoomMaskSample {
  RoomMaskSample({
    required PhotoViewport viewport,
    required Offset source,
    required double brushFraction,
  }) : source = Offset(
         source.dx.clamp(0.0, viewport.imageSize.width - .000001),
         source.dy.clamp(0.0, viewport.imageSize.height - .000001),
       ),
       screenRadius = viewport.brushRadius(brushFraction),
       sourceRadius = math.min(viewport.imageSize.width, viewport.imageSize.height) * brushFraction / 2;

  final Offset source;
  final double screenRadius, sourceRadius;
}

class RoomMaskMagnifier extends StatelessWidget {
  const RoomMaskMagnifier({
    super.key,
    required this.sample,
    required this.image,
    this.overlay,
  });

  final RoomMaskSample sample;
  final ui.Image? image, overlay;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Magnified source pixel ${sample.source.dx.floor() + 1}, '
        '${sample.source.dy.floor() + 1}',
    child: SizedBox.square(
      dimension: 112,
      child: CustomPaint(painter: _MagnifierPainter(
        sample, image, overlay, Theme.of(context).colorScheme.onSurface,
      )),
    ),
  );
}

class _MagnifierPainter extends CustomPainter {
  _MagnifierPainter(this.sample, this.image, this.overlay, this.outline);
  final RoomMaskSample sample;
  final ui.Image? image, overlay;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
    canvas.drawRect(rect, Paint()..color = Colors.grey.shade700);
    const magnification = 3.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(magnification);
    canvas.translate(-sample.source.dx, -sample.source.dy);
    if (image != null) canvas.drawImage(image!, Offset.zero, Paint()..filterQuality = FilterQuality.none);
    if (overlay != null) canvas.drawImage(overlay!, Offset.zero, Paint()..color = const Color(0x99ffffff));
    canvas.restore();
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, sample.sourceRadius * magnification, Paint()
      ..color = Colors.white ..style = PaintingStyle.stroke ..strokeWidth = 3);
    canvas.drawCircle(center, sample.sourceRadius * magnification, Paint()
      ..color = Colors.black ..style = PaintingStyle.stroke ..strokeWidth = 1);
    canvas.drawLine(center - const Offset(7, 0), center + const Offset(7, 0), Paint()..color = Colors.white..strokeWidth = 2);
    canvas.drawLine(center - const Offset(0, 7), center + const Offset(0, 7), Paint()..color = Colors.white..strokeWidth = 2);
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(16)), Paint()
      ..color = outline ..style = PaintingStyle.stroke ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _MagnifierPainter oldDelegate) => true;
}
