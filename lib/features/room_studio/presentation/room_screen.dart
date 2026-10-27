import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/domain/saved_color.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/room_color_provider.dart';

class RoomScreen extends ConsumerWidget {
  const RoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final legacyWall = ref.watch(roomColorProvider);
    return StudioPage(
      name: 'Rooms',
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
        const Text('Choose a sample room, or use your own room photo.'),
        const SizedBox(height: AppSpacing.xxl),
        StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Illustrated rooms',
                subtitle:
                    'Compare wall, ceiling, floor and furniture colors in six '
                    'different spaces.',
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                key: const ValueKey('open-illustrated-gallery'),
                label: 'Choose an illustrated room',
                icon: Icons.meeting_room_outlined,
                onPressed: () => context.push('/room/illustrated'),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Every room starts in black & white. Apply a complete look or '
                'choose custom colors when you open it.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        StudioCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionHeader(
                title: 'Your real space',
                subtitle:
                    'The photo editor stays separate from this illustration.',
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Offline AI finds Wall, Ceiling, Floor and Furniture masks in '
                'your photo so you can correct and recolor each layer.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.appColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SecondaryButton(
                label: 'Explore last room color',
                icon: Icons.palette_outlined,
                onPressed: () => showColorDetails(
                  context,
                  legacyWall,
                  source: ColorSource.room,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
