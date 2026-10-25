import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/rainbow_rings_game.dart';
import 'rainbow_rings_animation.dart';

@immutable
final class RainbowRingsGeometry {
  const RainbowRingsGeometry._({
    required this.size,
    required this.pegCount,
    required this.capacity,
    required this.stageRect,
    required this.baseRect,
    required this.ringSize,
    required this.ringStep,
    required this.hoverY,
    required double contentLeft,
    required double pegSpacing,
    required double perspectiveScale,
    required List<Rect> hitRects,
  }) : _contentLeft = contentLeft,
       _pegSpacing = pegSpacing,
       _perspectiveScale = perspectiveScale,
       _hitRects = hitRects;

  factory RainbowRingsGeometry.layout(
    Size size, {
    required int pegCount,
    required int capacity,
  }) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      throw ArgumentError.value(size, 'size', 'Must be finite and non-empty.');
    }
    if (pegCount <= 0) {
      throw ArgumentError.value(pegCount, 'pegCount', 'Must be positive.');
    }
    if (capacity <= 0) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be positive.');
    }

    final preferredMargin = (size.width * .025).clamp(6.0, 12.0);
    final horizontalMargin = math.min(preferredMargin, size.width * .125);
    final verticalMargin = math.min(preferredMargin, size.height * .125);
    final stageRect = Rect.fromLTRB(
      horizontalMargin,
      verticalMargin,
      size.width - horizontalMargin,
      size.height - verticalMargin,
    );
    final baseSideInset = math.min(6.0, stageRect.width * .1);
    final baseBottomGap = math.min(6.0, stageRect.height * .08);
    final baseHeight = math.min(
      (size.width * .065).clamp(22.0, 30.0),
      stageRect.height * .25,
    );
    final baseBottom = stageRect.bottom - baseBottomGap;
    final baseRect = Rect.fromLTRB(
      stageRect.left + baseSideInset,
      baseBottom - baseHeight,
      stageRect.right - baseSideInset,
      baseBottom,
    );
    final contentInset = math.min(6.0, baseRect.width * .1);
    final contentLeft = baseRect.left + contentInset;
    final contentWidth = baseRect.width - contentInset * 2;
    final pegSpacing = contentWidth / pegCount;
    final ringWidth = math.min(64.0, pegSpacing * .8);
    final towerHeight = baseRect.top - stageRect.top;
    final towerTopInset = math.min(12.0, towerHeight * .12);
    final availableHeight = towerHeight - towerTopInset;
    final preferredRingHeight = (ringWidth * .5).clamp(13.0, 28.0);
    final ringHeight = math.min(
      preferredRingHeight,
      availableHeight / (capacity + 2.6),
    );
    final ringStep = ringHeight * .88;
    final requestedHoverY = baseRect.top - (capacity + 1.35) * ringStep;
    final minimumHoverY = stageRect.top + ringHeight * .75;
    final topRestingY =
        baseRect.top - ringHeight / 2 - (capacity - 1) * ringStep;
    final maximumHoverY = math.max(
      minimumHoverY,
      math.min(baseRect.top - ringHeight * 1.2, topRestingY - ringHeight * .25),
    );
    final hoverY = requestedHoverY.clamp(minimumHoverY, maximumHoverY);
    final baseCenters = List<double>.generate(
      pegCount,
      (peg) => contentLeft + pegSpacing * (peg + .5),
    );
    final hitRects = List<Rect>.generate(pegCount, (peg) {
      final left = peg == 0
          ? 0.0
          : (baseCenters[peg - 1] + baseCenters[peg]) / 2;
      final right = peg == pegCount - 1
          ? size.width
          : (baseCenters[peg] + baseCenters[peg + 1]) / 2;
      return Rect.fromLTRB(left, 0, right, size.height);
    });
    return RainbowRingsGeometry._(
      size: size,
      pegCount: pegCount,
      capacity: capacity,
      stageRect: stageRect,
      baseRect: baseRect,
      ringSize: Size(ringWidth, ringHeight),
      ringStep: ringStep,
      hoverY: hoverY,
      contentLeft: contentLeft,
      pegSpacing: pegSpacing,
      perspectiveScale: .94,
      hitRects: List.unmodifiable(hitRects),
    );
  }

  final Size size;
  final int pegCount;
  final int capacity;
  final Rect stageRect;
  final Rect baseRect;
  final Size ringSize;
  final double ringStep;
  final double hoverY;
  final double _contentLeft;
  final double _pegSpacing;
  final double _perspectiveScale;
  final List<Rect> _hitRects;

  Offset positionFor(RainbowRingsPosition position) {
    RangeError.checkValidIndex(position.peg, _hitRects, 'position.peg');
    return positionForLogical(
      peg: position.peg.toDouble(),
      slot: position.slot.toDouble(),
    );
  }

  Offset positionForLogical({required double peg, required double slot}) {
    final bottomY = baseRect.top - ringSize.height / 2;
    final y = slot < 0
        ? _lerp(hoverY, bottomY, (slot + 1).clamp(0.0, 1.0))
        : bottomY - slot * ringStep;
    final baseX = _contentLeft + _pegSpacing * (peg + .5);
    final topX = size.width / 2 + (baseX - size.width / 2) * _perspectiveScale;
    final verticalSpan = math.max(1.0, baseRect.top - hoverY);
    final perspective = ((baseRect.top - y) / verticalSpan).clamp(0.0, 1.0);
    return Offset(_lerp(baseX, topX, perspective), y);
  }

  Rect ringRectAt(Offset center) => Rect.fromCenter(
    center: center,
    width: ringSize.width,
    height: ringSize.height,
  );

  Rect poleRect(int peg) {
    RangeError.checkValidIndex(peg, _hitRects, 'peg');
    final top = math.min(
      baseRect.top - ringSize.height,
      hoverY + ringSize.height * .62,
    );
    final centerY = (top + baseRect.top) / 2;
    final centerX = positionForLogical(
      peg: peg.toDouble(),
      slot: (baseRect.top - ringSize.height / 2 - centerY) / ringStep,
    ).dx;
    final width = (_pegSpacing * .14).clamp(7.0, 12.0);
    return Rect.fromLTRB(
      centerX - width / 2,
      top,
      centerX + width / 2,
      baseRect.top + 2,
    );
  }

  Rect pegHitRect(int peg) {
    RangeError.checkValidIndex(peg, _hitRects, 'peg');
    return _hitRects[peg];
  }

  int? hitTest(Offset point) {
    if (point.dx < 0 ||
        point.dx > size.width ||
        point.dy < 0 ||
        point.dy > size.height) {
      return null;
    }
    for (var peg = 0; peg < _hitRects.length; peg++) {
      final rect = _hitRects[peg];
      if (point.dx < rect.right ||
          (peg == _hitRects.length - 1 && point.dx <= rect.right)) {
        return peg;
      }
    }
    return null;
  }
}

enum RainbowRingsPaintLayer {
  stageGlass,
  bokeh,
  base,
  selectedGlow,
  completedGlow,
  hintGlow,
  pole,
  ring,
  overlayRing,
  sparkle,
  toast,
  confetti,
}

@immutable
final class RainbowRingsPaintCommand {
  RainbowRingsPaintCommand({
    required this.layer,
    this.bounds,
    this.center,
    this.ringId,
    this.peg,
    this.particleId,
    this.colorIndex,
    this.text,
    this.opacity = 1,
    this.scaleX = 1,
    this.scaleY = 1,
    this.rotation = 0,
    this.glow = 0,
    this.blurRadius = 0,
    this.ringEffect,
    Set<RainbowRingsPegEffectKind> pegEffects = const {},
  }) : pegEffects = Set.unmodifiable(pegEffects);

  final RainbowRingsPaintLayer layer;
  final Rect? bounds;
  final Offset? center;
  final int? ringId;
  final int? peg;
  final int? particleId;
  final int? colorIndex;
  final String? text;
  final double opacity;
  final double scaleX;
  final double scaleY;
  final double rotation;
  final double glow;
  final double blurRadius;
  final RainbowRingsRingEffectKind? ringEffect;
  final Set<RainbowRingsPegEffectKind> pegEffects;
}

final class RainbowRingsPainter extends CustomPainter {
  RainbowRingsPainter({
    required List<List<int>> stacks,
    required List<int> ringColors,
    required this.capacity,
    required this.selectedPeg,
    required this.colors,
    required this.timeline,
    required this.clock,
  }) : stacks = List.unmodifiable(
         stacks.map((stack) => List<int>.unmodifiable(stack)),
       ),
       ringColors = List.unmodifiable(ringColors),
       _timelineRevision = timeline.revision,
       super(repaint: clock);

  final List<List<int>> stacks;
  final List<int> ringColors;
  final int capacity;
  final int? selectedPeg;
  final AppColors colors;
  final RainbowRingsTimeline timeline;
  final ValueListenable<Duration> clock;
  final int _timelineRevision;

  @visibleForTesting
  List<RainbowRingsPaintCommand> debugPaintCommands(Size size) =>
      List.unmodifiable(_buildCommands(size));

  @override
  void paint(Canvas canvas, Size size) {
    for (final command in _buildCommands(size)) {
      _paintBoardCommand(canvas, command, colors);
    }
  }

  List<RainbowRingsPaintCommand> _buildCommands(Size size) {
    if (stacks.isEmpty || size.isEmpty || capacity <= 0) return const [];
    final geometry = RainbowRingsGeometry.layout(
      size,
      pegCount: stacks.length,
      capacity: capacity,
    );
    final frame = timeline.sample(clock.value);
    final commands = <RainbowRingsPaintCommand>[
      RainbowRingsPaintCommand(
        layer: RainbowRingsPaintLayer.stageGlass,
        bounds: geometry.stageRect,
        center: geometry.stageRect.center,
      ),
      for (final particle in frame.bokeh)
        _particleCommand(
          layer: RainbowRingsPaintLayer.bokeh,
          particle: particle,
          center: Offset(
            geometry.stageRect.left + particle.x * geometry.stageRect.width,
            geometry.stageRect.top + particle.y * geometry.stageRect.height,
          ),
        ),
      RainbowRingsPaintCommand(
        layer: RainbowRingsPaintLayer.base,
        bounds: geometry.baseRect,
        center: geometry.baseRect.center,
      ),
    ];

    for (var peg = 0; peg < stacks.length; peg++) {
      final pegTransform = frame.pegEffects[peg];
      final pegEffects = pegTransform?.kinds ?? const {};
      final offsetX = pegTransform?.offsetX ?? 0;
      final poleBounds = geometry.poleRect(peg).shift(Offset(offsetX, 0));
      if (selectedPeg == peg) {
        commands.add(
          RainbowRingsPaintCommand(
            layer: RainbowRingsPaintLayer.selectedGlow,
            bounds: poleBounds.inflate(7),
            center: poleBounds.center,
            peg: peg,
            glow: 1,
            blurRadius: 9,
            pegEffects: pegEffects,
          ),
        );
      }
      if (frame.completedPegs.contains(peg)) {
        commands.add(
          RainbowRingsPaintCommand(
            layer: RainbowRingsPaintLayer.completedGlow,
            bounds: poleBounds.inflate(8),
            center: poleBounds.center,
            peg: peg,
            glow: math.max(pegTransform?.glow ?? 0, 1),
            blurRadius: 12,
            pegEffects: pegEffects,
          ),
        );
      }
      if (pegEffects.contains(RainbowRingsPegEffectKind.hint)) {
        commands.add(
          RainbowRingsPaintCommand(
            layer: RainbowRingsPaintLayer.hintGlow,
            bounds: poleBounds.inflate(8 * (pegTransform?.glow ?? 0)),
            center: poleBounds.center,
            peg: peg,
            glow: pegTransform?.glow ?? 0,
            blurRadius: 22 * (pegTransform?.glow ?? 0),
            pegEffects: pegEffects,
          ),
        );
      }
      commands.add(
        RainbowRingsPaintCommand(
          layer: RainbowRingsPaintLayer.pole,
          bounds: poleBounds,
          center: poleBounds.bottomCenter,
          peg: peg,
          rotation: pegTransform?.rotation ?? 0,
          pegEffects: pegEffects,
        ),
      );
    }

    for (var peg = 0; peg < stacks.length; peg++) {
      for (var slot = 0; slot < stacks[peg].length; slot++) {
        final ringId = stacks[peg][slot];
        if (ringId < 0 || ringId >= ringColors.length) continue;
        final transform = frame.ringTransforms[ringId];
        if (transform?.hideRestingRing ?? false) continue;
        final selected = selectedPeg == peg && slot == stacks[peg].length - 1;
        commands.add(
          _ringCommand(
            geometry: geometry,
            layer: RainbowRingsPaintLayer.ring,
            ringId: ringId,
            restingPeg: peg,
            restingSlot: slot,
            selected: selected,
            transform: transform?.overlay ?? false ? null : transform,
            pegTransform: frame.pegEffects[peg],
          ),
        );
      }
    }

    for (final transform in frame.ringTransforms.values) {
      if (!transform.overlay ||
          transform.ringId < 0 ||
          transform.ringId >= ringColors.length) {
        continue;
      }
      commands.add(
        _ringCommand(
          geometry: geometry,
          layer: RainbowRingsPaintLayer.overlayRing,
          ringId: transform.ringId,
          restingPeg: transform.peg.round().clamp(0, stacks.length - 1),
          restingSlot: math.max(0, transform.restingSlot.round()),
          selected: false,
          transform: transform,
        ),
      );
    }

    for (final particle in frame.sparkles) {
      final peg = particle.peg;
      if (peg == null || peg < 0 || peg >= stacks.length) continue;
      final anchor = geometry.positionFor(
        RainbowRingsPosition(peg: peg, slot: capacity - 1),
      );
      commands.add(
        _particleCommand(
          layer: RainbowRingsPaintLayer.sparkle,
          particle: particle,
          center: anchor + Offset(particle.x, particle.y),
        ),
      );
    }

    final toastPeg = frame.toastPeg;
    if (frame.toast != null &&
        toastPeg != null &&
        toastPeg >= 0 &&
        toastPeg < stacks.length) {
      final anchor = geometry.positionFor(RainbowRingsPosition.hover(toastPeg));
      commands.add(
        RainbowRingsPaintCommand(
          layer: RainbowRingsPaintLayer.toast,
          center: anchor + Offset(0, frame.toastOffsetY - 22),
          peg: toastPeg,
          text: frame.toast,
          opacity: frame.toastOpacity,
          scaleX: frame.toastScale,
          scaleY: frame.toastScale,
        ),
      );
    }
    return commands;
  }

  RainbowRingsPaintCommand _ringCommand({
    required RainbowRingsGeometry geometry,
    required RainbowRingsPaintLayer layer,
    required int ringId,
    required int restingPeg,
    required int restingSlot,
    required bool selected,
    RainbowRingTransform? transform,
    RainbowPegTransform? pegTransform,
  }) {
    final logicalPeg = transform?.peg ?? restingPeg.toDouble();
    final baseCenter = switch (transform) {
      RainbowRingTransform transform => Offset.lerp(
        geometry.positionForLogical(
          peg: transform.peg,
          slot: transform.restingSlot,
        ),
        geometry.positionForLogical(
          peg: transform.peg,
          slot: RainbowRingsPosition.hoverSlot.toDouble(),
        ),
        transform.hoverFraction,
      )!,
      null => geometry.positionForLogical(
        peg: logicalPeg,
        slot: selected
            ? RainbowRingsPosition.hoverSlot.toDouble()
            : restingSlot.toDouble(),
      ),
    };
    final center =
        baseCenter +
        Offset(
          (transform?.offsetX ?? 0) + (pegTransform?.offsetX ?? 0),
          (transform?.offsetY ?? 0) +
              (transform?.offsetYInRings ?? 0) * geometry.ringSize.height,
        );
    return RainbowRingsPaintCommand(
      layer: layer,
      bounds: geometry.ringRectAt(center),
      center: center,
      ringId: ringId,
      peg: logicalPeg.round().clamp(0, stacks.length - 1),
      colorIndex: ringColors[ringId],
      opacity: transform?.opacity ?? 1,
      scaleX: transform?.scaleX ?? 1,
      scaleY: transform?.scaleY ?? 1,
      rotation: transform?.rotation ?? 0,
      ringEffect: transform?.kind,
      pegEffects: pegTransform?.kinds ?? const {},
    );
  }

  @override
  bool shouldRepaint(covariant RainbowRingsPainter oldDelegate) =>
      oldDelegate.capacity != capacity ||
      oldDelegate.selectedPeg != selectedPeg ||
      !_stacksEqual(oldDelegate.stacks, stacks) ||
      !listEquals(oldDelegate.ringColors, ringColors) ||
      !_colorsEqual(oldDelegate.colors, colors) ||
      oldDelegate.timeline != timeline ||
      oldDelegate._timelineRevision != _timelineRevision ||
      oldDelegate.clock != clock;
}

final class RainbowRingsConfettiPainter extends CustomPainter {
  RainbowRingsConfettiPainter({required this.timeline, required this.clock})
    : _timelineRevision = timeline.revision,
      super(repaint: clock);

  final RainbowRingsTimeline timeline;
  final ValueListenable<Duration> clock;
  final int _timelineRevision;

  @visibleForTesting
  List<RainbowRingsPaintCommand> debugPaintCommands(Size size) =>
      List.unmodifiable(_buildCommands(size));

  List<RainbowRingsPaintCommand> _buildCommands(Size size) {
    if (size.isEmpty) return const [];
    return [
      for (final particle in timeline.sample(clock.value).confetti)
        _particleCommand(
          layer: RainbowRingsPaintLayer.confetti,
          particle: particle,
          center: Offset(particle.x * size.width, particle.y * size.height),
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final command in _buildCommands(size)) {
      _paintConfettiCommand(canvas, command);
    }
  }

  @override
  bool shouldRepaint(covariant RainbowRingsConfettiPainter oldDelegate) =>
      oldDelegate.timeline != timeline ||
      oldDelegate._timelineRevision != _timelineRevision ||
      oldDelegate.clock != clock;
}

const _ringPalette = <List<Color>>[
  [Color(0xffd69bf5), Color(0xff9b3fd0), Color(0xff6e1fa0)],
  [Color(0xff7bc5f7), Color(0xff2a86d4), Color(0xff175c9c)],
  [Color(0xffb1ec70), Color(0xff6cc12b), Color(0xff43901a)],
  [Color(0xffff8588), Color(0xffe0303a), Color(0xffa51b25)],
  [Color(0xfffff07b), Color(0xfff7d417), Color(0xffc4a40a)],
  [Color(0xffffc477), Color(0xfff08a1c), Color(0xffbb6208)],
];

RainbowRingsPaintCommand _particleCommand({
  required RainbowRingsPaintLayer layer,
  required RainbowParticle particle,
  required Offset center,
}) {
  final height = layer == RainbowRingsPaintLayer.confetti
      ? particle.size * .58
      : particle.size;
  return RainbowRingsPaintCommand(
    layer: layer,
    bounds: Rect.fromCenter(
      center: center,
      width: particle.size,
      height: height,
    ),
    center: center,
    particleId: particle.id,
    peg: particle.peg,
    colorIndex: particle.colorIndex,
    opacity: particle.opacity,
    scaleX: particle.scale,
    scaleY: particle.scale,
    rotation: particle.rotation,
  );
}

void _paintBoardCommand(
  Canvas canvas,
  RainbowRingsPaintCommand command,
  AppColors colors,
) {
  switch (command.layer) {
    case RainbowRingsPaintLayer.stageGlass:
      final rect = command.bounds!;
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(24));
      canvas.drawRRect(
        shape.shift(const Offset(0, 6)),
        Paint()
          ..color = Colors.black.withValues(alpha: .10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
      canvas.drawRRect(
        shape,
        Paint()
          ..shader = LinearGradient(
            colors: [
              colors.surface.withValues(alpha: .86),
              colors.primary.withValues(alpha: .07),
              colors.surfaceElevated.withValues(alpha: .76),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
      );
      canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = colors.outline.withValues(alpha: .72),
      );
    case RainbowRingsPaintLayer.bokeh:
      final color = _particleColor(command.colorIndex ?? 0);
      canvas.drawCircle(
        command.center!,
        command.bounds!.width / 2,
        Paint()
          ..color = color.withValues(alpha: command.opacity.clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    case RainbowRingsPaintLayer.base:
      final rect = command.bounds!;
      final path = Path()
        ..moveTo(rect.left + 7, rect.top)
        ..lineTo(rect.right - 7, rect.top)
        ..lineTo(rect.right, rect.bottom)
        ..lineTo(rect.left, rect.bottom)
        ..close();
      canvas.drawPath(
        path.shift(const Offset(0, 3)),
        Paint()
          ..color = Colors.black.withValues(alpha: .18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xfff2d9a7), Color(0xffc88f4e)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect),
      );
    case RainbowRingsPaintLayer.selectedGlow:
      _paintGlow(canvas, command, colors.primary);
    case RainbowRingsPaintLayer.completedGlow:
      _paintGlow(canvas, command, colors.success);
    case RainbowRingsPaintLayer.hintGlow:
      _paintGlow(canvas, command, colors.warning);
    case RainbowRingsPaintLayer.pole:
      final rect = command.bounds!;
      final pivot = command.center ?? rect.bottomCenter;
      canvas.save();
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate(command.rotation);
      canvas.translate(-pivot.dx, -pivot.dy);
      final shape = RRect.fromRectAndRadius(rect, const Radius.circular(7));
      canvas.drawRRect(
        shape.shift(const Offset(1.5, 2)),
        Paint()..color = Colors.black.withValues(alpha: .15),
      );
      canvas.drawRRect(
        shape,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xfff3dfb5), Color(0xffc68e4c)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(rect),
      );
      canvas.restore();
    case RainbowRingsPaintLayer.ring:
    case RainbowRingsPaintLayer.overlayRing:
      _paintRing(canvas, command);
    case RainbowRingsPaintLayer.sparkle:
      _paintSparkle(canvas, command);
    case RainbowRingsPaintLayer.toast:
      _paintToast(canvas, command, colors);
    case RainbowRingsPaintLayer.confetti:
      _paintConfettiCommand(canvas, command);
  }
}

void _paintGlow(Canvas canvas, RainbowRingsPaintCommand command, Color color) {
  if (command.glow <= 0) return;
  final rect = command.bounds!;
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(14)),
    Paint()
      ..color = color.withValues(alpha: (.28 * command.glow).clamp(0, 1))
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        math.max(.1, command.blurRadius),
      ),
  );
}

void _paintRing(Canvas canvas, RainbowRingsPaintCommand command) {
  if (command.opacity <= 0) return;
  final rect = command.bounds!;
  final center = command.center ?? rect.center;
  final palette = _ringPalette[(command.colorIndex ?? 0) % _ringPalette.length];
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(command.rotation);
  canvas.scale(command.scaleX, command.scaleY);
  canvas.translate(-center.dx, -center.dy);
  final shape = RRect.fromRectAndRadius(
    rect,
    Radius.circular(rect.height * .46),
  );
  canvas.drawRRect(
    shape.shift(const Offset(0, 3)),
    Paint()
      ..color = Colors.black.withValues(alpha: .2 * command.opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  canvas.drawRRect(
    shape,
    Paint()
      ..shader = LinearGradient(
        colors: [
          for (final color in palette)
            color.withValues(alpha: command.opacity.clamp(0, 1)),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + rect.width * .14,
        rect.top + rect.height * .1,
        rect.width * .36,
        math.max(1.4, rect.height * .14),
      ),
      const Radius.circular(20),
    ),
    Paint()..color = Colors.white.withValues(alpha: .48 * command.opacity),
  );
  canvas.restore();
}

void _paintSparkle(Canvas canvas, RainbowRingsPaintCommand command) {
  if (command.opacity <= 0) return;
  final center = command.center!;
  final radius = command.bounds!.width / 2;
  final path = Path();
  for (var point = 0; point < 10; point++) {
    final angle = -math.pi / 2 + point * math.pi / 5;
    final distance = point.isEven ? radius : radius * .42;
    final offset = Offset(
      center.dx + math.cos(angle) * distance,
      center.dy + math.sin(angle) * distance,
    );
    if (point == 0) {
      path.moveTo(offset.dx, offset.dy);
    } else {
      path.lineTo(offset.dx, offset.dy);
    }
  }
  path.close();
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(command.rotation);
  canvas.scale(command.scaleX, command.scaleY);
  canvas.translate(-center.dx, -center.dy);
  canvas.drawPath(
    path,
    Paint()
      ..color = _particleColor(
        command.colorIndex ?? 0,
      ).withValues(alpha: command.opacity.clamp(0, 1)),
  );
  canvas.restore();
}

void _paintToast(
  Canvas canvas,
  RainbowRingsPaintCommand command,
  AppColors colors,
) {
  if (command.opacity <= 0 || command.text == null) return;
  final painter = TextPainter(
    text: TextSpan(
      text: command.text,
      style: TextStyle(
        color: colors.textPrimary.withValues(
          alpha: command.opacity.clamp(0, 1),
        ),
        fontSize: 18,
        fontWeight: FontWeight.w800,
        shadows: [
          Shadow(
            color: colors.surface.withValues(alpha: command.opacity),
            blurRadius: 8,
          ),
        ],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final center = command.center!;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(command.scaleX, command.scaleY);
  painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
  canvas.restore();
}

void _paintConfettiCommand(Canvas canvas, RainbowRingsPaintCommand command) {
  if (command.opacity <= 0) return;
  final rect = command.bounds!;
  final center = command.center!;
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(command.rotation);
  canvas.scale(command.scaleX, command.scaleY);
  canvas.translate(-center.dx, -center.dy);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
    Paint()
      ..color = _particleColor(
        command.colorIndex ?? 0,
      ).withValues(alpha: command.opacity.clamp(0, 1)),
  );
  canvas.restore();
}

Color _particleColor(int colorIndex) =>
    _ringPalette[colorIndex % _ringPalette.length].first;

bool _stacksEqual(List<List<int>> left, List<List<int>> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (!listEquals(left[index], right[index])) return false;
  }
  return true;
}

bool _colorsEqual(AppColors left, AppColors right) =>
    left.background == right.background &&
    left.surface == right.surface &&
    left.surfaceElevated == right.surfaceElevated &&
    left.outline == right.outline &&
    left.textPrimary == right.textPrimary &&
    left.textSecondary == right.textSecondary &&
    left.primary == right.primary &&
    left.gradientStart == right.gradientStart &&
    left.gradientEnd == right.gradientEnd &&
    left.success == right.success &&
    left.warning == right.warning &&
    left.error == right.error;

double _lerp(double start, double end, double t) => start + (end - start) * t;
