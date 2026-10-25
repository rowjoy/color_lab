import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/game_profiles_provider.dart';
import '../domain/game_badge.dart';
import '../domain/player_profile.dart';
import 'game_ui_metadata.dart';

/// Read-only gallery of the active player's first three badge milestones.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  static const _milestones = [20, 40, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(gameProfilesProvider);
    final activeProfile = ref.watch(activePlayerProfileProvider);

    return StudioPage(
      name: 'Badges',
      children: [
        const StudioHeading(
          eyebrow: 'Player rewards',
          title: 'Badges',
          description:
              'Clear milestone levels in each game to fill your badge gallery.',
        ),
        profiles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const _BadgeMessage(
            icon: Icons.error_outline_rounded,
            message: 'Badges could not be loaded.',
          ),
          data: (_) => activeProfile == null
              ? const _BadgeMessage(
                  icon: Icons.person_add_alt_1_rounded,
                  message: 'Create a player to earn badges.',
                )
              : _BadgeGallery(profile: activeProfile),
        ),
      ],
    );
  }
}

final class _BadgeGallery extends StatelessWidget {
  const _BadgeGallery({required this.profile});

  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < gameUiMetadata.length; index++) ...[
        _GameBadgeSection(
          metadata: gameUiMetadata[index],
          badges: profile.badges,
        ),
        if (index != gameUiMetadata.length - 1)
          const SizedBox(height: AppSpacing.lg),
      ],
    ],
  );
}

final class _GameBadgeSection extends StatelessWidget {
  const _GameBadgeSection({required this.metadata, required this.badges});

  final GameUiMetadata metadata;
  final Map<String, GameBadge> badges;

  @override
  Widget build(BuildContext context) => StudioCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(metadata.icon, color: context.appColors.primary, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                metadata.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 560
                ? 3
                : constraints.maxWidth >= 360
                ? 2
                : 1;
            const gap = AppSpacing.md;
            final tileWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final milestone in BadgesScreen._milestones)
                  SizedBox(
                    width: tileWidth,
                    child: _BadgeTile(
                      metadata: metadata,
                      milestone: milestone,
                      badge: badges['${metadata.gameId.storageId}:$milestone'],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

final class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.metadata,
    required this.milestone,
    required this.badge,
  });

  final GameUiMetadata metadata;
  final int milestone;
  final GameBadge? badge;

  @override
  Widget build(BuildContext context) {
    final earned = badge != null;
    final color = earned
        ? context.appColors.success
        : context.appColors.textSecondary;
    final stateLabel = earned ? 'earned' : 'locked';

    return Semantics(
      key: ValueKey('badge-${metadata.gameId.storageId}-$milestone'),
      container: true,
      label: '${metadata.label} Level $milestone badge, $stateLabel',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.appColors.surfaceElevated,
          border: Border.all(
            color: earned
                ? color.withValues(alpha: .45)
                : context.appColors.outline,
          ),
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                earned
                    ? Icons.workspace_premium_rounded
                    : Icons.lock_outline_rounded,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $milestone',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    earned ? _earnedDate(badge!.earnedAt) : 'Locked',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _BadgeMessage extends StatelessWidget {
  const _BadgeMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => StudioCard(
    child: Column(
      children: [
        Icon(icon, size: 40, color: context.appColors.textSecondary),
        const SizedBox(height: AppSpacing.md),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ),
  );
}

String _earnedDate(DateTime value) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = value.toUtc();
  return 'Earned ${months[date.month - 1]} ${date.day}, ${date.year}';
}
