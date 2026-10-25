import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/water_sort_game.dart';

const waterSortColors = <Color>[
  Color(0xffe8453c),
  Color(0xfff7a928),
  Color(0xfff2f23d),
  Color(0xff5dbb63),
  Color(0xff3a7bd5),
  Color(0xff8a43c4),
  Color(0xffff7eb6),
  Color(0xff2ec4c9),
  Color(0xffa0623a),
];

class WaterSortGeometry {
  const WaterSortGeometry({
    required this.positions,
    required this.tubeWidth,
    required this.tubeHeight,
  });

  final List<Offset> positions;
  final double tubeWidth;
  final double tubeHeight;

  factory WaterSortGeometry.layout(Size size, int tubeCount) {
    final rows = tubeCount > 6 ? 2 : 1;
    final perRow = rows == 2 ? (tubeCount + 1) ~/ 2 : tubeCount;
    const gap = 12.0;
    final rowHeight = (size.height - 30) / rows;
    final width = math.max(
      30.0,
      math.min(54.0, (size.width - 24 - gap * (perRow - 1)) / perRow),
    );
    final height = math.max(90.0, math.min(200.0, rowHeight - 95));
    final positions = <Offset>[];
    for (var i = 0; i < tubeCount; i++) {
      final row = rows == 2 && i >= perRow ? 1 : 0;
      final count = row == 1 ? tubeCount - perRow : perRow;
      final column = row == 1 ? i - perRow : i;
      final left = (size.width - count * width - (count - 1) * gap) / 2;
      positions.add(
        Offset(left + column * (width + gap) + width / 2, 48 + row * rowHeight),
      );
    }
    return WaterSortGeometry(
      positions: positions,
      tubeWidth: width,
      tubeHeight: height,
    );
  }

  int? hitTest(Offset point) {
    for (var i = 0; i < positions.length; i++) {
      final top = positions[i];
      if ((point.dx - top.dx).abs() < tubeWidth / 2 + 8 &&
          point.dy > top.dy - 30 &&
          point.dy < top.dy + tubeHeight + 14) {
        return i;
      }
    }
    return null;
  }
}

class WaterPourMotion {
  static const waterStartMillis = 380;

  const WaterPourMotion({
    required this.source,
    required this.target,
    required this.color,
    required this.amount,
    required this.direction,
    required this.pourMillis,
  });

  final int source;
  final int target;
  final int color;
  final int amount;
  final double direction;
  final int pourMillis;

  int get totalMillis => 760 + pourMillis;

  bool isPouringAt(double progress) =>
      progress * totalMillis >= waterStartMillis;
}

class WaterSortPainter extends CustomPainter {
  WaterSortPainter({
    required this.tubes,
    required this.geometry,
    required this.selectedTube,
    required this.selectedLift,
    required this.motion,
    required this.motionProgress,
    required this.time,
  });

  final List<List<WaterSegment>> tubes;
  final WaterSortGeometry geometry;
  final int? selectedTube;
  final double selectedLift;
  final WaterPourMotion? motion;
  final double motionProgress;
  final double time;

  static final _samples = _buildSamples();
  static final _stars = List<Offset>.generate(14, (i) {
    final random = math.Random(113 + i);
    return Offset(random.nextDouble(), random.nextDouble());
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      _drawStar(
        canvas,
        Offset(star.dx * size.width, star.dy * size.height),
        6 + (i % 5) * 1.8,
        Colors.white.withValues(alpha: .25),
      );
    }

    final frame = _motionFrame();
    final order = List<int>.generate(tubes.length, (i) => i);
    if (motion != null) {
      order.remove(motion!.source);
      order.add(motion!.source);
    }
    for (final index in order) {
      final isMoving = motion != null && index == motion!.source;
      final top = isMoving ? frame.sourcePosition : geometry.positions[index];
      final angle = isMoving ? frame.angle : 0.0;
      final layers = _layersFor(index, frame.pouredAmount);
      final lifted = isMoving
          ? frame.lift
          : selectedTube == index
          ? 20.0 * selectedLift
          : 0.0;
      final wave = motion != null && index == motion!.target
          ? 1.2 + 2.2 * math.sin(frame.pourProgress * math.pi).abs()
          : 0.0;
      _drawTube(
        canvas,
        top + Offset(0, -lifted),
        angle,
        layers,
        _isComplete(tubes[index]),
        wave,
        index,
      );
    }
    if (motion != null && frame.isPouring && frame.pourProgress < .96) {
      _drawWaterStream(canvas, frame);
    }
  }

  _MotionFrame _motionFrame() {
    final active = motion;
    if (active == null) return _MotionFrame.empty;
    final elapsed = motionProgress * active.totalMillis;
    final base = geometry.positions[active.source];
    final target = geometry.positions[active.target];
    final upMillis = WaterPourMotion.waterStartMillis.toDouble();
    final pourEnd = upMillis + active.pourMillis;
    final maximumAngle = active.direction * 1.36;
    Offset pose(double angle) => Offset(
      target.dx - active.direction * geometry.tubeWidth / 2 * math.cos(angle),
      target.dy - 34 - geometry.tubeWidth / 2 * math.sin(angle),
    );
    if (elapsed < upMillis) {
      final progress = _ease(elapsed / upMillis);
      final angle = active.direction * .9 * progress;
      return _MotionFrame(
        sourcePosition: _lerpOffset(
          base,
          pose(active.direction * .9),
          progress,
        ),
        angle: angle,
        lift: 0,
        pourProgress: 0,
        pouredAmount: 0,
        isPouring: false,
      );
    }
    if (elapsed < pourEnd) {
      final progress = _ease((elapsed - upMillis) / active.pourMillis);
      final angle =
          active.direction *
          (.9 + .46 * progress + .035 * math.sin(progress * math.pi));
      return _MotionFrame(
        sourcePosition: pose(angle),
        angle: angle,
        lift: 0,
        pourProgress: progress,
        pouredAmount: active.amount * progress,
        isPouring: true,
      );
    }
    final progress = _ease((elapsed - pourEnd) / 380);
    return _MotionFrame(
      sourcePosition: _lerpOffset(pose(maximumAngle), base, progress),
      angle: maximumAngle * (1 - progress),
      lift: 0,
      pourProgress: 1,
      pouredAmount: active.amount.toDouble(),
      isPouring: false,
    );
  }

  List<_WaterLayer> _layersFor(int tubeIndex, double poured) {
    final layers = tubes[tubeIndex]
        .map((segment) => _WaterLayer(segment.color, segment.amount.toDouble()))
        .toList();
    final active = motion;
    if (active == null || poured <= 0) return layers;
    if (tubeIndex == active.source) {
      final last = layers.removeLast();
      final remaining = last.amount - poured;
      if (remaining > .001) layers.add(_WaterLayer(last.color, remaining));
    } else if (tubeIndex == active.target) {
      if (layers.isNotEmpty && layers.last.color == active.color) {
        final last = layers.removeLast();
        layers.add(_WaterLayer(last.color, last.amount + poured));
      } else {
        layers.add(_WaterLayer(active.color, poured));
      }
    }
    return layers;
  }

  void _drawTube(
    Canvas canvas,
    Offset top,
    double angle,
    List<_WaterLayer> layers,
    bool done,
    double wave,
    int index,
  ) {
    final width = geometry.tubeWidth;
    final height = geometry.tubeHeight;
    final radius = width / 2;
    final path = _tubePath(width, height, radius);
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(angle);
    canvas.drawPath(path, Paint()..color = const Color(0x29ffffff));
    canvas.save();
    canvas.clipPath(path);

    final axis = Offset(math.sin(angle), math.cos(angle));
    final tangent = Offset(math.cos(angle), -math.sin(angle));
    var volume = 0.0;
    final boundaries = <double>[];
    for (final layer in layers) {
      volume += layer.amount;
      boundaries.add(_levelFor(volume, angle, width, height));
    }
    final extent = height * 2;
    for (var layerIndex = layers.length - 1; layerIndex >= 0; layerIndex--) {
      final boundary = boundaries[layerIndex];
      final ripple = layerIndex == layers.length - 1 ? 1.4 + wave : 0.0;
      final liquidPath = Path();
      final surfacePath = Path();
      for (var s = -extent; s <= extent; s += 8) {
        final displacement = ripple * math.sin(s * .12 + time * 5);
        final point = Offset(
          axis.dx * (boundary + displacement) + tangent.dx * s,
          axis.dy * (boundary + displacement) + tangent.dy * s,
        );
        if (s == -extent) {
          liquidPath.moveTo(point.dx, point.dy);
        } else {
          liquidPath.lineTo(point.dx, point.dy);
        }
        if (layerIndex == layers.length - 1) {
          if (s == -extent) {
            surfacePath.moveTo(point.dx, point.dy);
          } else {
            surfacePath.lineTo(point.dx, point.dy);
          }
        }
      }
      final far = boundary + extent * 2;
      liquidPath
        ..lineTo(
          axis.dx * far + tangent.dx * extent,
          axis.dy * far + tangent.dy * extent,
        )
        ..lineTo(
          axis.dx * far - tangent.dx * extent,
          axis.dy * far - tangent.dy * extent,
        )
        ..close();
      canvas.drawPath(
        liquidPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(
                waterSortColors[layers[layerIndex].color],
                Colors.white,
                .2,
              )!,
              waterSortColors[layers[layerIndex].color],
              Color.lerp(
                waterSortColors[layers[layerIndex].color],
                Colors.black,
                .12,
              )!,
            ],
          ).createShader(Rect.fromLTWH(-width / 2, 0, width, height)),
      );
      if (layerIndex == layers.length - 1) {
        canvas.drawPath(
          surfacePath,
          Paint()
            ..color = Colors.white.withValues(alpha: .32)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    canvas.drawRect(
      Rect.fromLTWH(width * .32, 0, width * .18, height),
      Paint()..color = const Color(0x21000000),
    );
    canvas.drawRect(
      Rect.fromLTWH(-width * .38, 8, width * .07, height * .55),
      Paint()..color = const Color(0x59ffffff),
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff2b2b3a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    final rim = RRect.fromRectAndRadius(
      Rect.fromLTWH(-width / 2 - 4, -7, width + 8, 11),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      rim,
      Paint()
        ..color = done && layers.isNotEmpty
            ? waterSortColors[layers.first.color]
            : const Color(0xffb9c1da),
    );
    canvas.drawRRect(
      rim,
      Paint()
        ..color = const Color(0xff2b2b3a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    if (done) {
      final sparkle = (time * 1.4 + index * .3) % 1;
      _drawStar(
        canvas,
        Offset(math.sin(index * 3) * width * .7, -8 - sparkle * 18),
        4 * (1 - sparkle),
        Colors.white.withValues(alpha: .85),
      );
    }
    canvas.restore();
  }

  void _drawWaterStream(Canvas canvas, _MotionFrame frame) {
    final active = motion!;
    final target = geometry.positions[active.target];
    final volume =
        tubes[active.target].fold<double>(
          0,
          (sum, layer) => sum + layer.amount,
        ) +
        frame.pouredAmount;
    final endY =
        target.dy +
        geometry.tubeHeight -
        volume / WaterSortGame.tubeCapacity * geometry.tubeHeight;
    final color = waterSortColors[active.color];
    final lipOffset = active.direction * geometry.tubeWidth * .43;
    final source =
        frame.sourcePosition +
        Offset(
          lipOffset * math.cos(frame.angle),
          lipOffset * math.sin(frame.angle) + 1,
        );
    final impact = Offset(target.dx, endY + 1);
    final bend =
        Offset.lerp(source, impact, .52)! + Offset(active.direction * 10, -4);
    final stream = Path()
      ..moveTo(source.dx, source.dy)
      ..quadraticBezierTo(bend.dx, bend.dy, impact.dx, impact.dy);
    final startEndEase = math.sin(frame.pourProgress * math.pi).abs();
    final pulse = .92 + .08 * math.sin(time * 13);
    final unit = (.76 + .24 * startEndEase) * pulse;
    final glow = Paint()
      ..color = color.withValues(alpha: .25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * unit
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(stream, glow);
    final liquid = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: .66),
          color,
          color.withValues(alpha: .8),
        ],
      ).createShader(Rect.fromPoints(source, impact))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2 * unit
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(stream, liquid);
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * unit
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(stream, highlight);

    // Drops travel down the curved stream, with a small splash at impact.
    for (var i = 0; i < 3; i++) {
      final phase = (time * 2.8 + i / 3) % 1;
      final t = phase;
      final inverse = 1 - t;
      final point = Offset(
        inverse * inverse * source.dx +
            2 * inverse * t * bend.dx +
            t * t * impact.dx,
        inverse * inverse * source.dy +
            2 * inverse * t * bend.dy +
            t * t * impact.dy,
      );
      canvas.drawOval(
        Rect.fromCenter(center: point, width: 3.2, height: 5.5),
        Paint()..color = color.withValues(alpha: .9),
      );
    }
    final splash =
        math.sin(frame.pourProgress * math.pi * 5).abs() *
        (.35 + .65 * startEndEase);
    final ripplePaint = Paint()
      ..color = color.withValues(alpha: .55 - splash * .2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    canvas.drawOval(
      Rect.fromCenter(
        center: impact,
        width: 12 + splash * 10,
        height: 4 + splash * 3,
      ),
      ripplePaint,
    );
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final lift = (math.sin(frame.pourProgress * math.pi * 4 + i) + 1) * 4;
      canvas.drawCircle(
        impact + Offset(side * (5 + lift), -lift),
        1.5,
        Paint()..color = color.withValues(alpha: .72),
      );
    }
  }

  static Path _tubePath(double width, double height, double radius) => Path()
    ..moveTo(-width / 2, 0)
    ..lineTo(-width / 2, height - radius)
    ..arcToPoint(
      Offset(width / 2, height - radius),
      radius: Radius.circular(radius),
      clockwise: false,
    )
    ..lineTo(width / 2, 0)
    ..close();

  static double _levelFor(
    double volume,
    double angle,
    double width,
    double height,
  ) {
    if (volume <= 0) return height;
    if (angle.abs() < .0001) {
      return height * (1 - volume / WaterSortGame.tubeCapacity);
    }
    final values =
        _samples
            .map(
              (point) =>
                  point.dx * width * math.sin(angle) +
                  point.dy * height * math.cos(angle),
            )
            .toList()
          ..sort();
    final count = (values.length * .9 / WaterSortGame.tubeCapacity * volume)
        .round()
        .clamp(1, values.length)
        .toInt();
    return values[values.length - count];
  }

  static List<Offset> _buildSamples() {
    const gx = 16;
    const gy = 70;
    final points = <Offset>[];
    const radius = .5;
    for (var a = 0; a < gx; a++) {
      for (var b = 0; b < gy; b++) {
        final x = -radius + (a + .5) / gx;
        final y = (b + .5) / gy;
        if (y <= 1 - radius ||
            math.sqrt(x * x + math.pow(y - (1 - radius), 2)) <= radius) {
          points.add(Offset(x, y));
        }
      }
    }
    return points;
  }

  static bool _isComplete(List<WaterSegment> tube) =>
      tube.length == 1 && tube.single.amount == WaterSortGame.tubeCapacity;

  static double _ease(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static Offset _lerpOffset(Offset a, Offset b, double t) =>
      Offset.lerp(a, b, t)!;

  static void _drawStar(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    if (radius <= 0) return;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? radius : radius * .45;
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant WaterSortPainter oldDelegate) => true;
}

class _WaterLayer {
  const _WaterLayer(this.color, this.amount);
  final int color;
  final double amount;
}

class _MotionFrame {
  const _MotionFrame({
    required this.sourcePosition,
    required this.angle,
    required this.lift,
    required this.pourProgress,
    required this.pouredAmount,
    required this.isPouring,
  });

  static const empty = _MotionFrame(
    sourcePosition: Offset.zero,
    angle: 0,
    lift: 0,
    pourProgress: 0,
    pouredAmount: 0,
    isPouring: false,
  );

  final Offset sourcePosition;
  final double angle;
  final double lift;
  final double pourProgress;
  final double pouredAmount;
  final bool isPouring;
}
