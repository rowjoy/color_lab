import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../history/domain/saved_color.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/room_color_provider.dart';

class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});
  static const _colors = [
    (hex: '#A7B5A0', name: 'Sage'),
    (hex: '#C5B7D0', name: 'Lilac'),
    (hex: '#D9BC9E', name: 'Sand'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wall = ref.watch(roomColorProvider);
    return StudioPage(
      name: 'Room',
      children: [
        Text('Room studio', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          key: const ValueKey('open-room-masks'),
          label: 'Visualize your room',
          icon: Icons.format_paint_outlined,
          onPressed: () => context.push('/room/masks'),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text('Explore photo previews and illustrated color studies.'),
        const SizedBox(height: AppSpacing.xxl),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.large),
          child: Semantics(
            image: true,
            label: 'Illustrated room with a ${wall.hex} wall',
            child: AspectRatio(
              aspectRatio: 1.15,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: displayColor(wall)),
                duration: AppMotion.duration(context),
                builder: (context, color, child) => CustomPaint(
                  painter: _RoomPainter(
                    wall: color!,
                    floor: displayColor(RgbColor.fromHex('#D5C8B5')),
                    sofa: displayColor(RgbColor.fromHex('#F1EADF')),
                    shadow: displayColor(RgbColor.fromHex('#8D816F')),
                    plant: displayColor(RgbColor.fromHex('#4C6450')),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'AN ILLUSTRATED COLOR STUDY',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.5,
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final color in _colors)
              Semantics(
                selected: color.hex == wall.hex,
                child: ColorChip(
                  color: displayColor(RgbColor.fromHex(color.hex)),
                  label: color.name,
                  onTap: () => ref
                      .read(roomColorProvider.notifier)
                      .setColor(RgbColor.fromHex(color.hex)),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxxl),
        StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Your space. Your palette.',
                subtitle: 'Explore an illustrated color study.',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Try colors in this illustration, or take or choose your own room photo above. Offline AI finds Wall, Ceiling, Floor, and Furniture masks so you can correct them and preview each layer color.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SecondaryButton(
                label: 'Explore this wall color',
                icon: Icons.palette_outlined,
                onPressed: () =>
                    showColorDetails(context, wall, source: ColorSource.room),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter({
    required this.wall,
    required this.floor,
    required this.sofa,
    required this.shadow,
    required this.plant,
  });
  final Color wall, floor, sofa, shadow, plant;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint();
    void rect(double x, double y, double width, double height, Color color) {
      canvas.drawRect(
        Rect.fromLTWH(x * w, y * h, width * w, height * h),
        paint..color = color,
      );
    }

    void rounded(double x, double y, double width, double height, Color color) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x * w, y * h, width * w, height * h),
          const Radius.circular(AppRadii.small),
        ),
        paint..color = color,
      );
    }

    rect(0, 0, 1, 1, wall);
    rect(0, .73, 1, .27, floor);
    // Soft window light falls across the illustrated wall.
    rect(.12, .1, .24, .43, sofa.withValues(alpha: .18));
    rect(.39, .1, .12, .43, sofa.withValues(alpha: .12));
    rect(0, .72, 1, .015, shadow.withValues(alpha: .12));
    rounded(.51, .16, .22, .24, sofa);
    rounded(.535, .185, .17, .19, floor);
    canvas.drawCircle(Offset(.62 * w, .26 * h), w * .045, paint..color = wall);
    canvas.drawOval(
      Rect.fromLTWH(w * .11, h * .78, w * .66, h * .1),
      paint..color = shadow.withValues(alpha: .18),
    );
    rounded(.14, .48, .57, .24, sofa);
    rounded(.12, .63, .62, .17, sofa);
    rounded(.105, .58, .085, .23, floor);
    rounded(.665, .58, .085, .23, floor);
    rect(.17, .79, .025, .055, shadow);
    rect(.66, .79, .025, .055, shadow);
    rect(.416, .51, .003, .19, floor.withValues(alpha: .7));
    rounded(.2, .55, .11, .12, wall);
    rounded(.53, .54, .095, .13, floor);
    rounded(.82, .7, .1, .14, shadow);
    rect(.865, .43, .008, .3, plant);
    for (final (x, y, rotation) in [
      (.82, .48, -.6),
      (.9, .41, .6),
      (.82, .35, -.5),
    ]) {
      canvas.save();
      canvas.translate(x * w, y * h);
      canvas.rotate(rotation);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * .11, height: h * .055),
        paint..color = plant,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RoomPainter oldDelegate) =>
      wall != oldDelegate.wall ||
      floor != oldDelegate.floor ||
      sofa != oldDelegate.sofa ||
      shadow != oldDelegate.shadow ||
      plant != oldDelegate.plant;
}
