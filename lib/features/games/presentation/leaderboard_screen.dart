import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/game_profiles_provider.dart';
import '../domain/game_id.dart';
import '../domain/game_leaderboard.dart';
import 'game_ui_metadata.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

final class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  GameId? _selectedGameId;

  @override
  Widget build(BuildContext context) {
    final entries = _selectedGameId == null
        ? ref.watch(overallLeaderboardProvider)
        : ref.watch(gameLeaderboardProvider(_selectedGameId!));

    return StudioPage(
      name: 'Leaderboard',
      children: [
        const StudioHeading(
          eyebrow: 'Local rankings',
          title: 'Leaderboard',
          description:
              'Compare every player across all games or focus on one game.',
        ),
        _LeaderboardFilters(
          selectedGameId: _selectedGameId,
          onSelected: (gameId) => setState(() => _selectedGameId = gameId),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (entries.isEmpty)
          const _EmptyLeaderboard()
        else
          _LeaderboardList(entries: entries),
      ],
    );
  }
}

final class _LeaderboardFilters extends StatelessWidget {
  const _LeaderboardFilters({
    required this.selectedGameId,
    required this.onSelected,
  });

  final GameId? selectedGameId;
  final ValueChanged<GameId?> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Leaderboard filters',
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _LeaderboardFilter(
            filterId: 'overall',
            label: 'Overall',
            icon: Icons.public_rounded,
            selected: selectedGameId == null,
            onPressed: () => onSelected(null),
          ),
          for (final metadata in gameUiMetadata) ...[
            const SizedBox(width: AppSpacing.sm),
            _LeaderboardFilter(
              filterId: metadata.gameId.storageId,
              label: metadata.label,
              icon: metadata.icon,
              selected: selectedGameId == metadata.gameId,
              onPressed: () => onSelected(metadata.gameId),
            ),
          ],
        ],
      ),
    ),
  );
}

final class _LeaderboardFilter extends StatelessWidget {
  const _LeaderboardFilter({
    required this.filterId,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String filterId;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey('leaderboard-filter-$filterId'),
    container: true,
    button: true,
    selected: selected,
    label: 'Show $label leaderboard',
    onTap: onPressed,
    excludeSemantics: true,
    child: ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPressed(),
    ),
  );
}

final class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard();

  @override
  Widget build(BuildContext context) => StudioCard(
    key: const ValueKey('leaderboard-empty'),
    child: Column(
      children: [
        Icon(
          Icons.people_outline_rounded,
          size: AppSpacing.huge,
          color: context.appColors.textSecondary,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'No players yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Create a player to start the local leaderboard.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

final class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('leaderboard-list'),
    children: [
      for (var index = 0; index < entries.length; index++) ...[
        if (index != 0) const SizedBox(height: AppSpacing.sm),
        _LeaderboardRow(entry: entries[index]),
      ],
    ],
  );
}

final class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final activeSuffix = entry.isActive ? ', active player' : '';

    return Semantics(
      key: ValueKey('leaderboard-row-${entry.profileId}'),
      container: true,
      label:
          'Rank ${entry.rank}, ${entry.profileName}, '
          '${entry.completedLevels} levels completed, ${entry.coins} coins'
          '$activeSuffix',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: entry.isActive
              ? colors.primary.withValues(alpha: .12)
              : colors.surface,
          border: Border.all(
            color: entry.isActive ? colors.primary : colors.outline,
          ),
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadii.small),
              ),
              child: Text(
                '#${entry.rank}',
                key: ValueKey('leaderboard-rank-${entry.profileId}'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        entry.profileName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (entry.isActive)
                        Container(
                          key: ValueKey(
                            'leaderboard-active-${entry.profileId}',
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          ),
                          child: Text(
                            'You',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.onPrimary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.xs,
                    children: [
                      Text(
                        '${entry.completedLevels} completed',
                        key: ValueKey(
                          'leaderboard-completed-${entry.profileId}',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${entry.coins} coins',
                        key: ValueKey('leaderboard-coins-${entry.profileId}'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
