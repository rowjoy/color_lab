import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/game_profiles_provider.dart';
import '../domain/game_id.dart';
import '../domain/game_launch.dart';
import '../domain/game_level.dart';
import '../domain/player_profile.dart';
import 'game_ui_metadata.dart';
import 'player_profile_dialog.dart';
import 'profile_management_sheet.dart';

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({
    super.key,
    this.onLaunchGame,
    this.onOpenMap,
    this.onOpenBadges,
    this.onOpenLeaderboard,
    this.onOpenColoring,
  });

  final ValueChanged<GameLaunch>? onLaunchGame;
  final ValueChanged<GameId>? onOpenMap;
  final VoidCallback? onOpenBadges;
  final VoidCallback? onOpenLeaderboard;
  final VoidCallback? onOpenColoring;

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

final class _GamesScreenState extends ConsumerState<GamesScreen> {
  final Set<GameId> _startingGames = <GameId>{};

  Future<void> _startGame(
    PlayerProfile profile,
    GameUiMetadata metadata,
  ) async {
    if (widget.onLaunchGame == null || _startingGames.isNotEmpty) {
      return;
    }
    setState(() => _startingGames.add(metadata.gameId));
    try {
      final controller = ref.read(gameProfilesProvider.notifier);
      final launch = await controller.prepareAndResumeGame(
        profileId: profile.id,
        gameId: metadata.gameId,
      );
      if (!mounted) return;
      if (!controller.isProfileLaunchCurrent(profile.id)) {
        if (profile.gameProgress[metadata.gameId]?.activeAttempt == null) {
          await controller.discardStaleNewAttempt(
            originalProfile: profile,
            launch: launch,
          );
        }
        return;
      }
      widget.onLaunchGame?.call(launch);
      // Fill the remaining level cache after the transition so generation
      // cannot delay the first game frame.
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 350)).then<void>((
          _,
        ) async {
          if (!mounted) return;
          try {
            await controller.prepareGame(
              profileId: profile.id,
              gameId: metadata.gameId,
            );
          } on Object {
            // The game is already playable; a later visit can retry refill.
          }
        }),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${metadata.label} could not be started. Try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _startingGames.remove(metadata.gameId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(gameProfilesProvider);
    return StudioPage(
      name: 'Games',
      children: [
        const StudioHeading(
          eyebrow: 'Color games',
          title: 'Play with color.',
          description:
              'Keep leveling up across five color games. Progress stays on this device for each player.',
        ),
        StudioCard(
          key: const ValueKey('games-coloring-studio-card'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.draw_outlined, color: context.appColors.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      context.l10n.coloringStudioTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(context.l10n.coloringGamesEntryBody),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: widget.onOpenColoring,
                icon: const Icon(Icons.palette_outlined),
                label: Text(context.l10n.coloringOpenStudio),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        profiles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _LoadError(
            onRetry: () => ref.read(gameProfilesProvider.notifier).retry(),
          ),
          data: (state) {
            final profile = state.activeProfile;
            if (profile == null) {
              return const _FirstPlayerCard();
            }
            return _GamesHub(
              profile: profile,
              onManageProfiles: _startingGames.isEmpty
                  ? () => showProfileManagementSheet(context)
                  : null,
              onStartGame: (metadata) => _startGame(profile, metadata),
              onOpenMap: widget.onOpenMap,
              onOpenBadges: widget.onOpenBadges,
              onOpenLeaderboard: widget.onOpenLeaderboard,
              launchEnabled:
                  widget.onLaunchGame != null && _startingGames.isEmpty,
              startingGames: _startingGames,
            );
          },
        ),
      ],
    );
  }
}

final class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StudioCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Game profiles could not be opened on this device.'),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

final class _FirstPlayerCard extends StatelessWidget {
  const _FirstPlayerCard();

  @override
  Widget build(BuildContext context) => StudioCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.gamesCreatePlayerTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          context.l10n.gamesCreatePlayerBody,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          key: const ValueKey('create-player'),
          onPressed: () => unawaited(
            showPlayerProfileDialog(context, requiredProfile: true),
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text(context.l10n.gamesCreatePlayerAction),
        ),
      ],
    ),
  );
}

final class _GamesHub extends StatelessWidget {
  const _GamesHub({
    required this.profile,
    required this.onManageProfiles,
    required this.onStartGame,
    required this.onOpenMap,
    required this.onOpenBadges,
    required this.onOpenLeaderboard,
    required this.launchEnabled,
    required this.startingGames,
  });

  final PlayerProfile profile;
  final VoidCallback? onManageProfiles;
  final ValueChanged<GameUiMetadata> onStartGame;
  final ValueChanged<GameId>? onOpenMap;
  final VoidCallback? onOpenBadges;
  final VoidCallback? onOpenLeaderboard;
  final bool launchEnabled;
  final Set<GameId> startingGames;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            button: true,
            label: 'Active player ${profile.name}',
            excludeSemantics: true,
            child: Tooltip(
              message: 'Change player name or switch player',
              child: ActionChip(
                key: const ValueKey('games-profile-chip'),
                avatar: const Icon(Icons.account_circle_rounded),
                label: Text(profile.name),
                onPressed: onManageProfiles,
              ),
            ),
          ),
          Tooltip(
            message: 'Badges',
            child: IconButton.filledTonal(
              key: const ValueKey('games-badges'),
              onPressed: onOpenBadges,
              icon: const Icon(Icons.workspace_premium_rounded),
            ),
          ),
          Tooltip(
            message: 'Leaderboard',
            child: IconButton.filledTonal(
              key: const ValueKey('games-leaderboard'),
              onPressed: onOpenLeaderboard,
              icon: const Icon(Icons.leaderboard_rounded),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      _GameCards(
        profile: profile,
        onStartGame: onStartGame,
        onOpenMap: onOpenMap,
        launchEnabled: launchEnabled,
        startingGames: startingGames,
      ),
      const SizedBox(height: AppSpacing.xxl),
      StudioCard(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                valueKey: const ValueKey('games-stat-coins'),
                label: 'Coins',
                value: '${profile.coins}',
                icon: Icons.stars_rounded,
              ),
            ),
            Expanded(
              child: _Stat(
                valueKey: const ValueKey('games-stat-wins'),
                label: 'Wins',
                value: '${profile.gamesWon}',
                icon: Icons.emoji_events_outlined,
              ),
            ),
            Expanded(
              child: _Stat(
                valueKey: const ValueKey('games-stat-best'),
                label: 'Best',
                value: '${profile.bestScore}',
                icon: Icons.trending_up_rounded,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        '${profile.gamesPlayed} games played · Progress stays on this device.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.appColors.textSecondary),
      ),
    ],
  );
}

final class _Stat extends StatelessWidget {
  const _Stat({
    required this.valueKey,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
  final Key valueKey;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: context.appColors.primary),
      const SizedBox(height: AppSpacing.xs),
      Text(value, key: valueKey, style: Theme.of(context).textTheme.titleLarge),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.fade,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ],
  );
}

final class _GameCards extends StatelessWidget {
  const _GameCards({
    required this.profile,
    required this.onStartGame,
    required this.onOpenMap,
    required this.launchEnabled,
    required this.startingGames,
  });

  final PlayerProfile profile;
  final ValueChanged<GameUiMetadata> onStartGame;
  final ValueChanged<GameId>? onOpenMap;
  final bool launchEnabled;
  final Set<GameId> startingGames;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 780
          ? 3
          : constraints.maxWidth >= 420
          ? 2
          : 1;
      const gap = AppSpacing.md;
      final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final metadata in gameUiMetadata)
            SizedBox(
              width: width,
              child: _GameCard(
                metadata: metadata,
                progress: profile.gameProgress[metadata.gameId],
                starting: startingGames.contains(metadata.gameId),
                onPlay: launchEnabled ? () => onStartGame(metadata) : null,
                onOpenMap: onOpenMap == null
                    ? null
                    : () => onOpenMap!(metadata.gameId),
              ),
            ),
        ],
      );
    },
  );
}

final class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.metadata,
    required this.progress,
    required this.starting,
    required this.onPlay,
    required this.onOpenMap,
  });

  final GameUiMetadata metadata;
  final PlayerGameProgress? progress;
  final bool starting;
  final VoidCallback? onPlay;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    final currentLevel = progress?.currentLevel ?? 1;
    final completed = progress?.highestCompletedLevel ?? 0;
    final nextBadge = ((completed ~/ 20) + 1) * 20;
    final resume = progress?.activeAttempt != null;
    final accent = _gameAccent(metadata.gameId);
    final badgeProgress = (completed % 20) / 20;
    final radius = BorderRadius.circular(AppRadii.large);
    final actionLabel = resume
        ? context.l10n.gamesContinueNamedGame(metadata.label)
        : context.l10n.gamesPlayNamedGame(metadata.label);
    return Tooltip(
      message: actionLabel,
      child: Semantics(
        key: ValueKey('play-${metadata.gameId.storageId}'),
        button: true,
        enabled: !starting && onPlay != null,
        label: actionLabel,
        child: Material(
          key: ValueKey('game-card-${metadata.gameId.storageId}'),
          color: context.appColors.surface,
          elevation: 3,
          shadowColor: accent.withValues(alpha: .16),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('game-tile-${metadata.gameId.storageId}'),
            borderRadius: radius,
            onTap: starting ? null : onPlay,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _GameLogo(metadata: metadata),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            metadata.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.08,
                                ),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: 'Open ${metadata.label} level map',
                        child: IconButton.filledTonal(
                          key: ValueKey('map-${metadata.gameId.storageId}'),
                          visualDensity: VisualDensity.compact,
                          onPressed: onOpenMap,
                          style: IconButton.styleFrom(
                            backgroundColor: accent.withValues(alpha: .1),
                            foregroundColor: accent,
                          ),
                          icon: const Icon(Icons.map_outlined),
                        ),
                      ),
                      if (starting)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          resume
                              ? Icons.play_circle_fill_rounded
                              : Icons.play_arrow_rounded,
                          color: context.appColors.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    metadata.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _GameInfoChip(
                        'Level $currentLevel',
                        key: ValueKey(
                          'game-level-${metadata.gameId.storageId}',
                        ),
                        color: accent,
                      ),
                      _GameInfoChip(
                        GameTier.forLevel(currentLevel).label,
                        key: ValueKey('game-tier-${metadata.gameId.storageId}'),
                        color: accent,
                      ),
                      _GameInfoChip(
                        '$completed completed',
                        key: ValueKey(
                          'game-completed-${metadata.gameId.storageId}',
                        ),
                        color: accent,
                      ),
                      _GameInfoChip(
                        'Next badge: Level $nextBadge',
                        key: ValueKey(
                          'game-next-badge-${metadata.gameId.storageId}',
                        ),
                        color: accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'NEXT BADGE  ·  ${completed % 20}/20',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .4,
                              ),
                        ),
                      ),
                      Icon(Icons.auto_awesome_rounded, size: 15, color: accent),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: badgeProgress,
                      minHeight: 5,
                      color: accent,
                      backgroundColor: accent.withValues(alpha: .12),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent,
                          Color.lerp(accent, Colors.black, .12)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: .18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (starting)
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          Icon(
                            resume
                                ? Icons.play_arrow_rounded
                                : Icons.sports_esports_rounded,
                            color: Colors.white,
                            size: 19,
                          ),
                        const SizedBox(width: 7),
                        Text(
                          starting
                              ? context.l10n.gamesStartingGame
                              : resume
                              ? context.l10n.gamesContinueGame
                              : context.l10n.gamesPlayGame,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .25,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
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
}

final class _GameLogo extends StatelessWidget {
  const _GameLogo({required this.metadata});

  final GameUiMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final background = switch (metadata.gameId) {
      GameId.bubbleShooter => const Color(0xffffe2ed),
      GameId.fruitPop => const Color(0xffe1f5df),
      GameId.waterSort => const Color(0xffdceeff),
      GameId.rainbowRings => const Color(0xfff0e4ff),
      GameId.colorMatch => const Color(0xffffefd4),
    };
    return Semantics(
      image: true,
      label: '${metadata.label} game logo',
      child: Container(
        width: 72,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(background, Colors.white, .32)!, background],
          ),
          borderRadius: BorderRadius.circular(AppRadii.medium),
          border: Border.all(color: Colors.white.withValues(alpha: .85)),
          boxShadow: [
            BoxShadow(
              color: background.withValues(alpha: .55),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: switch (metadata.gameId) {
          GameId.bubbleShooter => const _BubbleGameMark(),
          GameId.fruitPop => const _FruitGameMark(),
          GameId.waterSort => const _WaterGameMark(),
          GameId.rainbowRings => const _RingsGameMark(),
          GameId.colorMatch => const _ColorMatchGameMark(),
        },
      ),
    );
  }
}

final class _GameInfoChip extends StatelessWidget {
  const _GameInfoChip(this.label, {super.key, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .14)),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.appColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

Color _gameAccent(GameId gameId) => switch (gameId) {
  GameId.bubbleShooter => const Color(0xffdb4e82),
  GameId.fruitPop => const Color(0xff319466),
  GameId.waterSort => const Color(0xff347fc4),
  GameId.rainbowRings => const Color(0xff8059c8),
  GameId.colorMatch => const Color(0xffd78732),
};

final class _BubbleGameMark extends StatelessWidget {
  const _BubbleGameMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    height: 52,
    child: Stack(
      children: [
        _bubble(.08, .06, 22, const Color(0xfff04f84)),
        _bubble(.55, .03, 21, const Color(0xff39baf2)),
        _bubble(.32, .37, 22, const Color(0xff8a62e8)),
        _bubble(.02, .52, 16, const Color(0xffffc13e)),
        _bubble(.68, .48, 16, const Color(0xff42c887)),
        const Positioned(
          left: 24,
          bottom: -1,
          child: Icon(
            Icons.arrow_drop_up_rounded,
            size: 22,
            color: Color(0xff4c4f68),
          ),
        ),
      ],
    ),
  );

  Widget _bubble(double x, double y, double size, Color color) => Positioned(
    left: x * 48,
    top: y * 48,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.35, -.42),
          colors: [Color.lerp(color, Colors.white, .55)!, color],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: .8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .25),
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    ),
  );
}

final class _FruitGameMark extends StatelessWidget {
  const _FruitGameMark();

  @override
  Widget build(BuildContext context) => const Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '🍎🥕',
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: 25, height: 1.05),
      ),
      Text(
        '🍇🥦',
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: 19, height: 1.05),
      ),
    ],
  );
}

final class _WaterGameMark extends StatelessWidget {
  const _WaterGameMark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      _tube(const Color(0xff48a8f2), .42),
      _tube(const Color(0xfff1bd48), .68),
      _tube(const Color(0xffe9758e), .53),
    ],
  );

  Widget _tube(Color liquid, double fill) => Container(
    width: 13,
    height: 43,
    margin: const EdgeInsets.symmetric(horizontal: 2),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xff55708f), width: 1.8),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
    ),
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 39 * fill,
        decoration: BoxDecoration(
          color: liquid,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
        ),
      ),
    ),
  );
}

final class _RingsGameMark extends StatelessWidget {
  const _RingsGameMark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      _peg(const [Color(0xffef6671), Color(0xfff1bf4d)]),
      _peg(const [Color(0xff6f65d8), Color(0xff53b4df), Color(0xff65c482)]),
      _peg(const [Color(0xffea8c48)]),
    ],
  );

  Widget _peg(List<Color> colors) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final color in colors)
          Container(
            width: 19,
            height: 9,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
          ),
        Container(width: 3, height: 7, color: const Color(0xffad895e)),
      ],
    ),
  );
}

final class _ColorMatchGameMark extends StatelessWidget {
  const _ColorMatchGameMark();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 54,
    height: 50,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(left: 2, child: _swatch(const Color(0xffee5c70))),
        Positioned(right: 2, child: _swatch(const Color(0xff428be5))),
        Positioned(top: 0, child: _swatch(const Color(0xffffca48))),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xff9164d8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const Positioned(
          right: 0,
          bottom: 0,
          child: Icon(
            Icons.colorize_rounded,
            size: 20,
            color: Color(0xff675078),
          ),
        ),
      ],
    ),
  );

  Widget _swatch(Color color) => Container(
    width: 25,
    height: 25,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 3,
          offset: Offset(0, 2),
        ),
      ],
    ),
  );
}
