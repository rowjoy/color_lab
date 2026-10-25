import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/bubble_shooter_game.dart';

const bubblePalette = <Color>[
  Color(0xffff4d78),
  Color(0xffffb52e),
  Color(0xff32d69b),
  Color(0xff36c9f5),
  Color(0xffac75ff),
  Color(0xffff82c8),
];

final class BubbleBurst {
  const BubbleBurst({
    required this.x,
    required this.y,
    required this.color,
    required this.startedAt,
    this.falling = false,
  });

  final double x;
  final double y;
  final int color;
  final double startedAt;
  final bool falling;
}

class BubbleShooterPainter extends CustomPainter {
  BubbleShooterPainter({
    required this.game,
    required this.angle,
    required this.aiming,
    required this.elapsed,
    required this.bursts,
    required this.rowDropAt,
    required this.shooterY,
    required this.grid,
  });

  final BubbleShooterGame game;
  final List<List<int?>> grid;
  final double angle;
  final bool aiming;
  final double elapsed;
  final List<BubbleBurst> bursts;
  final double? rowDropAt;
  final double shooterY;
  late Size _size;

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    final radius = size.width / BubbleShooterGame.worldWidth;
    final boardHeight = size.height / radius;
    _paintBackdrop(canvas, size);
    _paintDangerLine(canvas, radius, boardHeight);
    final dropProgress = rowDropAt == null
        ? 1.0
        : ((elapsed - rowDropAt!) / .45).clamp(0.0, 1.0);
    final easedDrop = Curves.easeOutCubic.transform(dropProgress);
    final dropOffset = (1 - easedDrop) * BubbleShooterGame.rowSpacing * radius;

    for (var row = 0; row < grid.length; row++) {
      for (var col = 0; col < grid[row].length; col++) {
        final color = grid[row][col];
        if (color == null) {
          continue;
        }
        final point = _cellCenter(row, col, radius);
        _bubble(canvas, Offset(point.dx, point.dy + dropOffset), color, radius);
      }
    }
    _paintBursts(canvas, radius);
    if (aiming && game.shot == null && !game.isWon && !game.isLost) {
      _paintAim(canvas, radius, boardHeight);
    }
    _paintLauncher(canvas, radius);
    final shot = game.shot;
    if (shot != null) {
      _bubble(
        canvas,
        Offset(shot.x * radius, shot.y * radius),
        shot.color,
        radius,
      );
    }
    _paintNext(canvas, radius);
    _paintPressure(canvas, radius);
  }

  void _paintBackdrop(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff7258df), Color(0xff40317f), Color(0xff24245e)],
        ).createShader(Offset.zero & size),
    );
    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 45);
    canvas.drawCircle(
      Offset(size.width * .18, size.height * .2),
      size.width * .25,
      glow..color = const Color(0x337ae6ff),
    );
    canvas.drawCircle(
      Offset(size.width * .9, size.height * .43),
      size.width * .22,
      glow..color = const Color(0x33ff9ae3),
    );
    for (var i = 0; i < 24; i++) {
      final x = ((i * 73 + 31) % 997) / 997 * size.width;
      final y = ((i * 137 + 17) % 991) / 991 * size.height;
      final twinkle = .25 + .55 * (math.sin(elapsed * 2 + i) + 1) / 2;
      canvas.drawCircle(
        Offset(x, y),
        i % 4 == 0 ? 1.8 : 1.1,
        Paint()..color = Colors.white.withValues(alpha: twinkle * .32),
      );
    }
  }

  void _paintDangerLine(Canvas canvas, double radius, double boardHeight) {
    final y = (shooterY - 5.2) * radius;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .33)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var x = 0.0; x < _size.width; x += 16) {
      path.moveTo(x, y);
      path.lineTo(math.min(x + 8, _size.width), y);
    }
    canvas.drawPath(path, paint);
    final label = TextPainter(
      text: const TextSpan(
        text: 'DANGER LINE',
        style: TextStyle(
          color: Color(0x88ffffff),
          fontSize: 9,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(_size.width - label.width - 10, y - 16));
  }

  void _paintAim(Canvas canvas, double radius, double boardHeight) {
    var x = BubbleShooterGame.worldWidth / 2;
    var y = shooterY;
    var vx = math.cos(angle);
    final vy = math.sin(angle);
    final paint = Paint()..color = Colors.white.withValues(alpha: .72);
    var step = 0;
    while (step < 1000) {
      x += vx * .18;
      y += vy * .18;
      if (x < 1) {
        x = 1;
        vx = vx.abs();
      } else if (x > BubbleShooterGame.worldWidth - 1) {
        x = BubbleShooterGame.worldWidth - 1;
        vx = -vx.abs();
      }
      final hit = y < 1 || _touchesBubble(x, y);
      if (step % 7 == 0) {
        canvas.drawCircle(
          Offset(x * radius, y * radius),
          step > 140 ? 1.0 : 1.7,
          paint
            ..color = Colors.white.withValues(alpha: .72 * (1 - step / 1250)),
        );
      }
      if (hit || y > boardHeight) break;
      step++;
    }
  }

  bool _touchesBubble(double x, double y) {
    final rowGuess = ((y - 1) / BubbleShooterGame.rowSpacing).round();
    for (
      var row = math.max(0, rowGuess - 1);
      row <= math.min(grid.length - 1, rowGuess + 1);
      row++
    ) {
      final colGuess = ((x - 1 - (row.isOdd ? 1 : 0)) / 2).round();
      for (
        var col = math.max(0, colGuess - 1);
        col <= math.min(grid[row].length - 1, colGuess + 1);
        col++
      ) {
        if (grid[row][col] == null) continue;
        final center = _cellCenter(row, col, 1);
        final dx = center.dx - x;
        final dy = center.dy - y;
        if (dx * dx + dy * dy < 3.9) return true;
      }
    }
    return false;
  }

  void _paintLauncher(Canvas canvas, double radius) {
    final center = Offset(
      BubbleShooterGame.worldWidth * .5 * radius,
      shooterY * radius,
    );
    canvas.drawCircle(
      center,
      radius * 1.38,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: .25), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.4)),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + math.pi / 2);
    final barrel = RRect.fromRectAndRadius(
      Rect.fromLTWH(-radius * .36, -radius * 2.0, radius * .72, radius * 1.65),
      Radius.circular(radius * .35),
    );
    canvas.drawRRect(
      barrel.shift(Offset(0, radius * .12)),
      Paint()..color = const Color(0xff29255e).withValues(alpha: .55),
    );
    canvas.drawRRect(
      barrel,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xfff3f0ff), Color(0xffa99af0), Color(0xff7063bb)],
        ).createShader(barrel.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -radius * .23,
          -radius * 1.88,
          radius * .46,
          radius * .28,
        ),
        Radius.circular(radius * .14),
      ),
      Paint()..color = const Color(0xff2c2865),
    );
    canvas.restore();
    _bubble(canvas, center, game.currentColor, radius * .94);
    canvas.drawCircle(
      center,
      radius * 1.24,
      Paint()
        ..color = Colors.white.withValues(alpha: .2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _paintNext(Canvas canvas, double radius) {
    final center = Offset(radius * 2.4, shooterY * radius + radius * .48);
    _bubble(canvas, center, game.nextColor, radius * .64);
    final text = TextPainter(
      text: const TextSpan(
        text: 'NEXT',
        style: TextStyle(
          color: Color(0xbbffffff),
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(center.dx - text.width / 2, center.dy + radius * .92),
    );
  }

  void _paintPressure(Canvas canvas, double radius) {
    final remaining = game.dropEvery - game.shotsSinceDrop;
    final center = Offset(
      _size.width - radius * 2.5,
      shooterY * radius + radius * .36,
    );
    canvas.drawCircle(
      center,
      radius * .64,
      Paint()..color = Colors.white.withValues(alpha: .16),
    );
    final text = TextPainter(
      text: TextSpan(
        text: '$remaining',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset(center.dx - text.width / 2, center.dy - text.height / 2),
    );
    final caption = TextPainter(
      text: const TextSpan(
        text: 'ROW',
        style: TextStyle(
          color: Color(0xbbffffff),
          fontSize: 8,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    caption.paint(
      canvas,
      Offset(center.dx - caption.width / 2, center.dy + radius * .68),
    );
  }

  void _paintBursts(Canvas canvas, double radius) {
    for (final burst in bursts) {
      final age = elapsed - burst.startedAt;
      if (age < 0 || age > (burst.falling ? .65 : .52)) continue;
      final color = bubblePalette[burst.color % bubblePalette.length];
      final center = Offset(
        burst.x * radius,
        (burst.y + (burst.falling ? age * age * 5 : 0)) * radius,
      );
      final progress = (age / (burst.falling ? .65 : .52)).clamp(0.0, 1.0);
      if (burst.falling) {
        _bubble(
          canvas,
          center,
          burst.color,
          radius * (1 - progress * .35),
          animate: false,
        );
      } else {
        final ease = Curves.easeOutCubic.transform(progress);
        canvas.drawCircle(
          center,
          radius * (.45 + ease * 1.3),
          Paint()
            ..color = Color.lerp(
              color,
              Colors.white,
              .42,
            )!.withValues(alpha: (1 - progress) * .2)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .32),
        );
        canvas.drawCircle(
          center,
          radius * (.7 + ease * 1.9),
          Paint()
            ..shader =
                SweepGradient(
                  colors: [
                    color.withValues(alpha: (1 - progress) * .85),
                    Colors.white.withValues(alpha: (1 - progress) * .72),
                    Color.lerp(
                      color,
                      Colors.black,
                      .12,
                    )!.withValues(alpha: (1 - progress) * .8),
                    color.withValues(alpha: (1 - progress) * .85),
                  ],
                  transform: GradientRotation(elapsed * 4),
                ).createShader(
                  Rect.fromCircle(center: center, radius: radius * 2.8),
                )
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * .22 * (1 - ease),
        );
        canvas.drawCircle(
          center,
          radius * (.45 + ease * 2.35),
          Paint()
            ..color = Colors.white.withValues(alpha: (1 - progress) * .52)
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * .055 * (1 - progress),
        );
        final random = math.Random(
          burst.startedAt.hashCode ^
              burst.color ^
              burst.x.hashCode ^
              burst.y.hashCode,
        );
        for (var i = 0; i < 12; i++) {
          final a = i * math.pi * 2 / 12 + random.nextDouble() * .22;
          final travel = radius * (.5 + ease * (1.6 + (i % 3) * .35));
          final gravity = radius * progress * progress * .45;
          final particle =
              center +
              Offset(math.cos(a) * travel, math.sin(a) * travel + gravity);
          canvas.save();
          canvas.translate(particle.dx, particle.dy);
          canvas.rotate(a + elapsed * (i.isEven ? 2 : -2));
          final shard = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: radius * (.2 + (i % 3) * .035) * (1 - progress),
              height: radius * .095 * (1 - progress),
            ),
            Radius.circular(radius * .06),
          );
          canvas.drawRRect(
            shard,
            Paint()
              ..color = Color.lerp(
                color,
                Colors.white,
                i.isEven ? .45 : .08,
              )!.withValues(alpha: 1 - progress),
          );
          canvas.restore();
        }
      }
    }
  }

  void _bubble(
    Canvas canvas,
    Offset center,
    int colorIndex,
    double radius, {
    bool animate = true,
  }) {
    final color = bubblePalette[colorIndex % bubblePalette.length];
    final phase = elapsed * 3.2 + center.dx * .019 + center.dy * .013;
    final breath = animate ? math.sin(phase) : 0.0;
    final pulseX = 1 + .075 * breath;
    final pulseY = 1 - .05 * breath;
    final bob = animate ? math.sin(phase * .72) * radius * .028 : 0.0;
    canvas.save();
    canvas.translate(center.dx, center.dy + bob);
    canvas.scale(pulseX, pulseY);
    canvas.translate(-center.dx, -center.dy);
    final ringRect = Rect.fromCircle(center: center, radius: radius * 1.015);
    canvas.drawCircle(
      center,
      radius * 1.015,
      Paint()
        ..shader = SweepGradient(
          colors: [
            bubblePalette[colorIndex % bubblePalette.length].withValues(
              alpha: .12,
            ),
            Colors.white.withValues(alpha: .82),
            bubblePalette[(colorIndex + 2) % bubblePalette.length].withValues(
              alpha: .48,
            ),
            bubblePalette[colorIndex % bubblePalette.length].withValues(
              alpha: .12,
            ),
          ],
          transform: GradientRotation(elapsed * 1.35 + center.dx * .005),
        ).createShader(ringRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .09,
    );
    final rect = Rect.fromCircle(center: center, radius: radius * .94);
    canvas.drawCircle(
      center + Offset(0, radius * .09),
      radius * .98,
      Paint()..color = const Color(0x440f103d),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: .15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .35),
    );
    canvas.drawCircle(
      center,
      radius * .94,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.38, -.48),
          radius: 1.05,
          colors: [
            Color.lerp(color, Colors.white, .66)!,
            color,
            Color.lerp(color, Colors.black, .22)!,
          ],
          stops: const [.02, .45, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius * .94,
      Paint()
        ..color = Colors.white.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * .055,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center:
            center +
            Offset(
              -radius * (.28 + .1 * math.sin(phase)),
              -radius * (.42 + .07 * math.cos(phase)),
            ),
        width: radius * .53,
        height: radius * .22,
      ),
      Paint()..color = Colors.white.withValues(alpha: .55),
    );
    canvas.drawCircle(
      center + Offset(radius * .42, radius * .26),
      radius * .09,
      Paint()..color = Colors.white.withValues(alpha: .32),
    );
    canvas.restore();
  }

  Offset _cellCenter(int row, int col, double radius) => Offset(
    (1 + col * 2 + (row.isOdd ? 1 : 0)) * radius,
    (1 + row * BubbleShooterGame.rowSpacing) * radius,
  );

  @override
  bool shouldRepaint(covariant BubbleShooterPainter oldDelegate) => true;
}
