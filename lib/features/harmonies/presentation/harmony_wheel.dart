import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';

/// A read-only HSL relationship diagram. Swatch actions belong to its parent.
class HarmonyWheel extends StatelessWidget {
  const HarmonyWheel({
    super.key,
    required this.base,
    required this.mode,
    required this.colors,
  });

  final RgbColor base;
  final HarmonyMode mode;
  final List<RgbColor> colors;

  @override
  Widget build(BuildContext context) {
    final chrome = context.appColors;
    final hasNeutrals = colors.any((color) => color.toHsl().saturation == 0);
    final explanation = [
      if (hasNeutrals) 'Neutral colors have no hue; shown by lightness.',
      if (mode == HarmonyMode.monochromatic)
        'Shades are arranged from darker to lighter.',
      if (!hasNeutrals && mode != HarmonyMode.monochromatic)
        'Hue runs clockwise from red at the top.',
    ].join(' ');

    return Semantics(
      container: true,
      image: true,
      label:
          '${mode.label} harmony. Base ${base.hex}. '
          'Colors: ${colors.map((color) => color.hex).join(', ')}. '
          '$explanation Double outline marks the base color.',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                key: const ValueKey('harmony-wheel-diagram'),
                painter: _HarmonyPainter(
                  base: base,
                  mode: mode,
                  colors: colors,
                  chrome: chrome,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Double outline: base ${base.hex}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              explanation,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _HarmonyPainter extends CustomPainter {
  _HarmonyPainter({
    required this.base,
    required this.mode,
    required List<RgbColor> colors,
    required this.chrome,
  }) : colors = List.unmodifiable(colors);

  final RgbColor base;
  final HarmonyMode mode;
  final List<RgbColor> colors;
  final AppColors chrome;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      side * .46,
      Paint()..color = chrome.surfaceElevated,
    );

    // SweepGradient starts on the right; rotate its red stop to twelve o'clock.
    final hueRing = SweepGradient(
      transform: const GradientRotation(-math.pi / 2),
      colors: [
        for (var hue = 0; hue <= 360; hue += 60)
          HSLColor.fromAHSL(1, hue.toDouble() % 360, 1, .5).toColor(),
      ],
    );
    canvas.drawCircle(
      center,
      side * .41,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .065
        ..shader = hueRing.createShader(
          Rect.fromCircle(center: center, radius: side * .41),
        ),
    );

    final lightnessColors = mode == HarmonyMode.monochromatic
        ? colors
        : colors.where((color) => color.toHsl().saturation == 0).toList();
    if (mode != HarmonyMode.monochromatic) {
      final chromatic = colors
          .where((color) => color.toHsl().saturation != 0)
          .toList();
      final positions = [
        for (final color in chromatic)
          center +
              Offset.fromDirection(
                color.toHsl().hue * math.pi / 180 - math.pi / 2,
                side * .30,
              ),
      ];
      if (positions.length > 1) {
        final path = Path()..moveTo(positions.first.dx, positions.first.dy);
        for (final point in positions.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        if (positions.length > 2) path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = chrome.textSecondary.withValues(alpha: .65)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
      }
      for (var i = 0; i < chromatic.length; i++) {
        _marker(canvas, positions[i], chromatic[i], side);
      }
    }

    if (lightnessColors.isNotEmpty) {
      final sorted = List<RgbColor>.of(lightnessColors)
        ..sort((a, b) => a.toHsl().lightness.compareTo(b.toHsl().lightness));
      final left = center.translate(-side * .30, 0);
      final right = center.translate(side * .30, 0);
      canvas.drawLine(
        left,
        right,
        Paint()
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(colors: [Colors.black, Colors.white])
              .createShader(
                Rect.fromPoints(left.translate(0, -2), right.translate(0, 2)),
              ),
      );
      // Ordinal spacing preserves lightness order even for nearly identical
      // endpoint shades, keeping each generated color individually visible.
      for (var i = 0; i < sorted.length; i++) {
        final fraction = sorted.length == 1 ? .5 : i / (sorted.length - 1);
        _marker(canvas, Offset.lerp(left, right, fraction)!, sorted[i], side);
      }
    }
  }

  void _marker(Canvas canvas, Offset point, RgbColor color, double side) {
    final radius = side * .03125;
    if (color == base) {
      canvas.drawCircle(
        point,
        radius + 5,
        Paint()
          ..color = chrome.textPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(point, radius + 2, Paint()..color = chrome.surface);
    canvas.drawCircle(
      point,
      radius,
      Paint()..color = Color(0xFF000000 | color.value),
    );
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..color = chrome.textPrimary.withValues(alpha: .4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _HarmonyPainter oldDelegate) =>
      base != oldDelegate.base ||
      mode != oldDelegate.mode ||
      !listEquals(colors, oldDelegate.colors) ||
      chrome != oldDelegate.chrome;
}
