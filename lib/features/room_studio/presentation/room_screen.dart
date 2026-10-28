import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
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
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    void openRoom() => context.push('/room/masks');
    return StudioPage(
      name: 'Rooms',
      maxContentWidth: 960,
      children: [
        if (largeText) ...[
          PrimaryButton(
            key: const ValueKey('open-room-masks'),
            label: context.l10n.roomUsePhoto,
            icon: Icons.format_paint_outlined,
            onPressed: openRoom,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        _RoomStudioHero(
          key: const ValueKey('room-studio-hero'),
          primaryLabel: context.l10n.roomUsePhoto,
          onOpenRoom: openRoom,
          showPrimaryAction: !largeText,
        ),
        const SizedBox(height: AppSpacing.xxl),
        LayoutBuilder(
          builder: (context, constraints) {
            final realRoom = _RoomJourneyCard(
              key: const ValueKey('room-studio-real-room-card'),
              eyebrow: 'REAL ROOM',
              title: 'Paint your own space',
              description:
                  'Use a room photo, review the detected surfaces, then test '
                  'colors while keeping every correction on your device.',
              icon: Icons.add_a_photo_outlined,
              accent: const Color(0xff7357d9),
              actions: [
                SecondaryButton(
                  key: const ValueKey('rooms-open-projects'),
                  label: context.l10n.roomProjectsTitle,
                  icon: Icons.photo_library_outlined,
                  onPressed: () => context.push('/rooms/projects'),
                ),
              ],
            );
            final illustratedRoom = _RoomJourneyCard(
              key: const ValueKey('room-studio-illustrated-card'),
              eyebrow: 'ILLUSTRATED ROOM',
              title: 'Explore curated spaces',
              description:
                  'Start from black and white, apply a complete look, or tune '
                  'walls, ceilings, floors and furniture independently.',
              icon: Icons.meeting_room_outlined,
              accent: const Color(0xffd35f87),
              actions: [
                PrimaryButton(
                  key: const ValueKey('open-illustrated-gallery'),
                  label: context.l10n.roomTryIllustrated,
                  icon: Icons.auto_awesome_outlined,
                  onPressed: () => context.push('/room/illustrated'),
                ),
              ],
            );
            if (constraints.maxWidth < 720) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  realRoom,
                  const SizedBox(height: AppSpacing.lg),
                  illustratedRoom,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: realRoom),
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: illustratedRoom),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxl),
        StudioCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.appColors.selectedSurface,
                  borderRadius: BorderRadius.circular(AppRadii.medium),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: context.appColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Continue your color research',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Open the last room color in Color Explorer without '
                      'changing the current room.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Explore last room color',
                      icon: Icons.open_in_new_rounded,
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
          ),
        ),
      ],
    );
  }
}

class _RoomStudioHero extends StatelessWidget {
  const _RoomStudioHero({
    super.key,
    required this.primaryLabel,
    required this.onOpenRoom,
    required this.showPrimaryAction,
  });

  final String primaryLabel;
  final VoidCallback onOpenRoom;
  final bool showPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.35;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: context.appColors.accentGradient,
        borderRadius: BorderRadius.circular(AppRadii.large),
        boxShadow: [
          BoxShadow(
            color: context.appColors.primary.withValues(alpha: .2),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .22),
                  ),
                ),
                child: const Icon(
                  Icons.chair_alt_outlined,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ROOM VISUALIZER',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: .82),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Room Studio',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Preview confident color decisions in your own photo or in a '
            'curated illustrated room.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: .88),
            ),
          ),
          if (showPrimaryAction) ...[
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              key: const ValueKey('open-room-masks'),
              label: primaryLabel,
              icon: Icons.format_paint_outlined,
              onPressed: onOpenRoom,
            ),
          ],
          if (!largeText) ...[
            const SizedBox(height: AppSpacing.md),
            const Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _HeroBadge(icon: Icons.lock_outline_rounded, label: 'Private'),
                _HeroBadge(icon: Icons.offline_bolt_outlined, label: 'Offline'),
                _HeroBadge(icon: Icons.tune_rounded, label: 'Editable masks'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 15),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _RoomJourneyCard extends StatelessWidget {
  const _RoomJourneyCard({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.actions,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: Border.all(color: accent.withValues(alpha: .2)),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: .09),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: accent, size: 27),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        ...actions,
      ],
    ),
  );
}
