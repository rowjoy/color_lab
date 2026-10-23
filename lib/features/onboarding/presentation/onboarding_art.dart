import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';

/// Static, theme-aware artwork with no image assets or ongoing animations.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({super.key, required this.index, required this.height});

  final int index;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _TourPainter(index: index, colors: context.appColors),
      ),
    ),
  );
}

class _TourPainter extends CustomPainter {
  const _TourPainter({required this.index, required this.colors});

  final int index;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 340, size.height / 236);
    canvas.save();
    canvas.translate(
      (size.width - 340 * scale) / 2,
      (size.height - 236 * scale) / 2,
    );
    canvas.scale(scale);
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 340, 236),
      const Radius.circular(AppRadii.large),
    );
    canvas.drawRRect(frame, Paint()..color = colors.surfaceElevated);
    canvas.save();
    canvas.clipRRect(frame);
    canvas.drawCircle(
      const Offset(294, 30),
      116,
      Paint()..color = colors.gradientStart.withValues(alpha: .10),
    );
    canvas.drawCircle(
      const Offset(20, 224),
      112,
      Paint()..color = colors.gradientEnd.withValues(alpha: .09),
    );
    _line(canvas, const Offset(22, 48), const Offset(44, 48), colors.outline);
    _line(canvas, const Offset(33, 37), const Offset(33, 59), colors.outline);
    canvas.drawCircle(
      const Offset(310, 197),
      4,
      Paint()..color = colors.primary,
    );
    canvas.drawCircle(
      const Offset(293, 213),
      2,
      Paint()..color = colors.gradientEnd,
    );
    switch (index) {
      case 0:
        _discover(canvas);
      case 1:
        _library(canvas);
      default:
        _privacy(canvas);
    }
    canvas.restore();
    canvas.restore();
  }

  void _discover(Canvas canvas) {
    canvas.save();
    canvas.translate(168, 114);
    canvas.rotate(-.07);
    _card(canvas, const Rect.fromLTWH(-109, -85, 218, 174));
    final photo = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-97, -73, 194, 120),
      const Radius.circular(AppRadii.small),
    );
    canvas.save();
    canvas.clipRRect(photo);
    canvas.drawRRect(
      photo,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors.warning, colors.surface, .30)!,
            colors.gradientEnd,
            colors.gradientStart,
          ],
        ).createShader(photo.outerRect),
    );
    canvas.drawCircle(
      const Offset(42, -41),
      24,
      Paint()..color = colors.surface.withValues(alpha: .65),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-110, 44)
        ..cubicTo(-40, -72, -4, 80, 116, -6)
        ..lineTo(116, 55)
        ..lineTo(-110, 55)
        ..close(),
      Paint()..color = colors.primary.withValues(alpha: .44),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-110, 47)
        ..cubicTo(-30, 7, 40, 92, 110, 18)
        ..lineTo(110, 55)
        ..lineTo(-110, 55)
        ..close(),
      Paint()..color = colors.textPrimary.withValues(alpha: .18),
    );
    canvas.restore();
    final focus = Paint()
      ..color = AppColors.onPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(-7, -11), 19, focus);
    canvas.drawCircle(
      const Offset(-7, -11),
      4,
      Paint()..color = AppColors.onPrimary,
    );
    for (final (x, y, dx, dy) in [
      (-40.0, -44.0, 1.0, 1.0),
      (26.0, -44.0, -1.0, 1.0),
      (-40.0, 22.0, 1.0, -1.0),
      (26.0, 22.0, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x + dx * 9, y)
          ..lineTo(x, y)
          ..lineTo(x, y + dy * 9),
        focus,
      );
    }
    for (var i = 0; i < 4; i++) {
      _roundRect(
        canvas,
        Rect.fromLTWH(-96 + i * 49, 58, 44, 18),
        _swatches[i],
        radius: 6,
      );
    }
    canvas.restore();
    _badge(canvas, const Offset(279, 56), camera: true);
    _badge(canvas, const Offset(57, 186));
  }

  List<Color> get _swatches => [
    colors.gradientStart,
    Color.lerp(colors.gradientStart, colors.gradientEnd, .45)!,
    colors.gradientEnd,
    Color.lerp(colors.warning, colors.surface, .30)!,
  ];

  void _library(Canvas canvas) {
    canvas.save();
    canvas.translate(171, 119);
    canvas.rotate(-.13);
    _roundRect(
      canvas,
      const Rect.fromLTWH(-97, -79, 194, 164),
      colors.primary.withValues(alpha: .16),
      radius: AppRadii.medium,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(172, 117);
    canvas.rotate(.07);
    _card(canvas, const Rect.fromLTWH(-96, -89, 192, 182));
    for (var i = 0; i < 3; i++) {
      _roundRect(
        canvas,
        Rect.fromLTWH(-80 + i * 55, -73, 49, 62),
        _swatches[i],
        radius: AppRadii.small,
      );
    }
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(-68, 12 + i * 27),
        7,
        Paint()..color = _swatches[i],
      );
      _roundRect(
        canvas,
        Rect.fromLTWH(-50, 8 + i * 27, 79 - i * 13, 5),
        colors.textSecondary.withValues(alpha: .36),
        radius: 3,
      );
      _roundRect(
        canvas,
        Rect.fromLTWH(-50, 18 + i * 27, 42, 3),
        colors.outline,
        radius: 2,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(55, 12)
        ..lineTo(72, 12)
        ..lineTo(72, 38)
        ..lineTo(63.5, 32)
        ..lineTo(55, 38)
        ..close(),
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
    _check(canvas, const Offset(270, 180));
    _badge(canvas, const Offset(58, 66));
  }

  void _privacy(Canvas canvas) {
    for (final center in [
      const Offset(64, 75),
      const Offset(279, 67),
      const Offset(276, 185),
    ]) {
      _line(
        canvas,
        const Offset(171, 118),
        center,
        colors.primary.withValues(alpha: .20),
        width: 2,
      );
    }
    final shield = Path()
      ..moveTo(170, 28)
      ..cubicTo(196, 44, 221, 48, 235, 50)
      ..lineTo(232, 117)
      ..cubicTo(229, 155, 204, 186, 170, 205)
      ..cubicTo(136, 186, 111, 155, 108, 117)
      ..lineTo(105, 50)
      ..cubicTo(119, 48, 144, 44, 170, 28)
      ..close();
    canvas.drawPath(shield, Paint()..color = colors.surface);
    canvas.drawPath(
      shield,
      Paint()
        ..shader = colors.accentGradient.createShader(
          const Rect.fromLTWH(105, 28, 130, 177),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      const Offset(170, 113),
      43,
      Paint()..color = colors.primary.withValues(alpha: .08),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(155, 82, 30, 43),
        const Radius.circular(15),
      ),
      Paint()
        ..color = colors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    _roundRect(
      canvas,
      const Rect.fromLTWH(146, 105, 48, 37),
      colors.primary,
      radius: AppRadii.small,
    );
    canvas.drawCircle(
      const Offset(170, 120),
      3,
      Paint()..color = AppColors.onPrimary,
    );
    _line(
      canvas,
      const Offset(170, 122),
      const Offset(170, 128),
      AppColors.onPrimary,
    );
    _badge(canvas, const Offset(64, 75), camera: true);
    _badge(canvas, const Offset(279, 67));
    _check(canvas, const Offset(276, 185));
  }

  void _card(Canvas canvas, Rect rect) {
    final rounded = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(AppRadii.medium),
    );
    canvas.drawShadow(
      Path()..addRRect(rounded),
      colors.textPrimary.withValues(alpha: .12),
      8,
      false,
    );
    canvas.drawRRect(rounded, Paint()..color = colors.surface);
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = colors.outline
        ..style = PaintingStyle.stroke,
    );
  }

  void _badge(Canvas canvas, Offset center, {bool camera = false}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    _card(canvas, const Rect.fromLTWH(-24, -24, 48, 48));
    final ink = Paint()
      ..color = colors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    if (camera) {
      canvas.drawPath(
        Path()
          ..moveTo(-13, -6)
          ..lineTo(-6, -6)
          ..lineTo(-3, -10)
          ..lineTo(5, -10)
          ..lineTo(8, -6)
          ..lineTo(13, -6)
          ..lineTo(13, 10)
          ..lineTo(-13, 10)
          ..close(),
        ink,
      );
      canvas.drawCircle(const Offset(0, 2), 5, ink);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -10, 24, 20),
          const Radius.circular(4),
        ),
        ink,
      );
      canvas.drawCircle(const Offset(5, -4), 2, ink);
      canvas.drawPath(
        Path()
          ..moveTo(-11, 5)
          ..lineTo(-4, -1)
          ..lineTo(2, 5)
          ..lineTo(6, 2)
          ..lineTo(12, 7),
        ink,
      );
    }
    canvas.restore();
  }

  void _check(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 25, Paint()..color = colors.surface);
    canvas.drawCircle(
      center,
      20,
      Paint()..color = colors.success.withValues(alpha: .15),
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - 9, center.dy)
        ..lineTo(center.dx - 3, center.dy + 6)
        ..lineTo(center.dx + 10, center.dy - 7),
      Paint()
        ..color = colors.success
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _roundRect(
    Canvas canvas,
    Rect rect,
    Color color, {
    required double radius,
  }) => canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    Paint()..color = color,
  );

  void _line(
    Canvas canvas,
    Offset from,
    Offset to,
    Color color, {
    double width = 2,
  }) => canvas.drawLine(
    from,
    to,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );

  @override
  bool shouldRepaint(_TourPainter oldDelegate) =>
      oldDelegate.index != index || oldDelegate.colors != colors;
}
