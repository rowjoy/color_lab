import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/app_shell.dart';
import '../../shell/presentation/studio_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => StudioPage(
    name: 'Home',
    children: [
      StudioHeading(
        eyebrow: context.l10n.homeEyebrow,
        title: context.l10n.homeTitle,
        description: context.l10n.homeDescription,
      ),
      StudioCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: context.l10n.homeSampleTitle,
              subtitle: context.l10n.homeSampleBody,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              key: const ValueKey('home-sample-room'),
              label: context.l10n.homeTrySampleRoom,
              icon: Icons.meeting_room_outlined,
              onPressed: () => context.push('/room/illustrated/living'),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      StudioCard(
        key: const ValueKey('home-continue'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: context.l10n.homeContinueTitle,
              subtitle: context.l10n.homeContinueEmpty,
            ),
            const SizedBox(height: AppSpacing.md),
            SecondaryButton(
              key: const ValueKey('home-continue-action'),
              label: context.l10n.homeNothingToContinue,
              icon: Icons.play_arrow_rounded,
              onPressed: null,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.xxl),
      LayoutBuilder(
        builder: (context, constraints) {
          final twoColumns = constraints.maxWidth >= 560;
          final cardWidth = twoColumns
              ? (constraints.maxWidth - AppSpacing.lg) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.lg,
            children: [
              _HomeActionCard(
                key: const ValueKey('home-card-rooms'),
                width: cardWidth,
                icon: Icons.chair_outlined,
                title: context.l10n.homeRoomsTitle,
                description: context.l10n.homeRoomsBody,
                onTap: () => _openDestination(context, AppDestination.rooms),
              ),
              _HomeActionCard(
                key: const ValueKey('home-card-learn'),
                width: cardWidth,
                icon: Icons.school_outlined,
                title: context.l10n.homeLearnTitle,
                description: context.l10n.homeLearnBody,
                onTap: () => _openDestination(context, AppDestination.learn),
              ),
              _HomeActionCard(
                key: const ValueKey('home-card-games'),
                width: cardWidth,
                icon: Icons.sports_esports_outlined,
                title: context.l10n.homeGamesTitle,
                description: context.l10n.homeGamesBody,
                onTap: () => _openDestination(context, AppDestination.games),
              ),
              _HomeActionCard(
                key: const ValueKey('home-card-my-work'),
                width: cardWidth,
                icon: Icons.collections_bookmark_outlined,
                title: context.l10n.homeMyWorkTitle,
                description: context.l10n.homeMyWorkBody,
                onTap: () => context.push('/my-work'),
              ),
            ],
          );
        },
      ),
    ],
  );

  void _openDestination(BuildContext context, AppDestination destination) {
    final shell = StatefulNavigationShell.maybeOf(context);
    if (shell != null) {
      shell.goBranch(destination.index);
    } else {
      context.go(destination.path);
    }
  }
}

class _HomeActionCard extends StatelessWidget {
  const _HomeActionCard({
    super.key,
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final double width;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Semantics(
      button: true,
      label: '$title. $description',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: context.appColors.primary),
                const SizedBox(height: AppSpacing.lg),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
