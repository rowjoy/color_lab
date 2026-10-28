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

/// Shows the durable, endless level path for one game.
class GameLevelMapScreen extends ConsumerStatefulWidget {
  const GameLevelMapScreen({
    super.key,
    required this.gameId,
    this.onLaunchGame,
  });

  final GameId gameId;
  final ValueChanged<GameLaunch>? onLaunchGame;

  @override
  ConsumerState<GameLevelMapScreen> createState() => _GameLevelMapScreenState();
}

final class _GameLevelMapScreenState extends ConsumerState<GameLevelMapScreen> {
  String? _preparationRequest;
  String? _failedPreparationRequest;
  bool _preparing = false;
  bool _launching = false;

  String _requestFor(PlayerProfile profile) =>
      '${profile.id}:${widget.gameId.storageId}';

  void _scheduleInitialPreparation(PlayerProfile profile) {
    final request = _requestFor(profile);
    if (_preparationRequest == request) return;
    _preparationRequest = request;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final activeProfile = ref.read(activePlayerProfileProvider);
      if (activeProfile?.id != profile.id ||
          activeProfile!.gameProgress.containsKey(widget.gameId)) {
        return;
      }
      _prepareMissingGame(profile, request);
    });
  }

  Future<void> _prepareMissingGame(
    PlayerProfile profile,
    String request,
  ) async {
    if (_preparing) return;
    setState(() {
      _preparing = true;
      _failedPreparationRequest = null;
    });
    try {
      await ref
          .read(gameProfilesProvider.notifier)
          .prepareGame(profileId: profile.id, gameId: widget.gameId);
    } catch (_) {
      if (mounted) {
        setState(() => _failedPreparationRequest = request);
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  void _retryPreparation(PlayerProfile profile) {
    final request = _requestFor(profile);
    _preparationRequest = request;
    _prepareMissingGame(profile, request);
  }

  Future<void> _playCurrent(
    PlayerProfile profile,
    PlayerGameProgress progress,
  ) async {
    if (_launching || widget.onLaunchGame == null) return;
    setState(() => _launching = true);
    try {
      final active = progress.activeAttempt;
      final canResumeCurrent =
          active != null &&
          active.playKind == GamePlayKind.current &&
          active.level == progress.currentLevel;
      final GameLaunch launch;
      if (canResumeCurrent) {
        final descriptor = progress.descriptors[active.level];
        if (descriptor == null) {
          throw StateError('The active game level is unavailable.');
        }
        launch = GameLaunch(
          profileId: profile.id,
          gameId: widget.gameId,
          descriptor: descriptor,
          attemptId: active.attemptId,
          playKind: active.playKind,
        );
      } else {
        launch = await ref
            .read(gameProfilesProvider.notifier)
            .beginCurrentAttempt(profileId: profile.id, gameId: widget.gameId);
      }
      if (!mounted) return;
      widget.onLaunchGame?.call(launch);
      // Keep a resumed attempt locked until the current event loop has ended.
      await Future<void>.delayed(Duration.zero);
    } catch (_) {
      if (mounted) _showLaunchError();
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<void> _replay(PlayerProfile profile, int level) async {
    if (_launching || widget.onLaunchGame == null) return;
    setState(() => _launching = true);
    try {
      final launch = await ref
          .read(gameProfilesProvider.notifier)
          .beginReplayAttempt(
            profileId: profile.id,
            gameId: widget.gameId,
            level: level,
          );
      if (!mounted) return;
      widget.onLaunchGame?.call(launch);
    } catch (_) {
      if (mounted) _showLaunchError();
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _showLaunchError() {
    final metadata = metadataForGame(widget.gameId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${metadata.label} level could not be started. Try again.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadata = metadataForGame(widget.gameId);
    final palette = _journeyPalette(widget.gameId);
    final profiles = ref.watch(gameProfilesProvider);
    return StudioPage(
      name: '${metadata.label} level map',
      maxContentWidth: 980,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('level-map-back'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to games'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _JourneyHero(metadata: metadata, palette: palette),
        const SizedBox(height: AppSpacing.xxl),
        profiles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _MapLoadError(
            onRetry: () => ref.read(gameProfilesProvider.notifier).retry(),
          ),
          data: (state) {
            final profile = state.activeProfile;
            if (profile == null) return const _NoProfileMessage();

            final progress = profile.gameProgress[widget.gameId];
            if (progress == null) {
              final request = _requestFor(profile);
              if (_failedPreparationRequest == request) {
                return _PreparationError(
                  onRetry: () => _retryPreparation(profile),
                );
              }
              _scheduleInitialPreparation(profile);
              return const _PreparingMap();
            }

            return _LevelMap(
              metadata: metadata,
              palette: palette,
              progress: progress,
              launching: _launching,
              launchAvailable: widget.onLaunchGame != null,
              onPlayCurrent: () => _playCurrent(profile, progress),
              onReplay: (level) => _replay(profile, level),
            );
          },
        ),
      ],
    );
  }
}

typedef _JourneyPalette = ({
  Color accent,
  Color accentLight,
  Color backgroundTop,
  Color backgroundBottom,
  Color completed,
  Color path,
  Color pathHighlight,
});

_JourneyPalette _journeyPalette(GameId gameId) => switch (gameId) {
  GameId.bubbleShooter => (
    accent: const Color(0xffdb4e82),
    accentLight: const Color(0xffff9fc0),
    backgroundTop: const Color(0xff5d306f),
    backgroundBottom: const Color(0xff291f56),
    completed: const Color(0xff9a67d9),
    path: const Color(0xff78395d),
    pathHighlight: const Color(0xffffbfd3),
  ),
  GameId.fruitPop => (
    accent: const Color(0xff319466),
    accentLight: const Color(0xff9be4a7),
    backgroundTop: const Color(0xff235f4d),
    backgroundBottom: const Color(0xff102f35),
    completed: const Color(0xff74b957),
    path: const Color(0xff3b7650),
    pathHighlight: const Color(0xffd5f2a8),
  ),
  GameId.waterSort => (
    accent: const Color(0xff347fc4),
    accentLight: const Color(0xff75d9ed),
    backgroundTop: const Color(0xff276b9a),
    backgroundBottom: const Color(0xff173458),
    completed: const Color(0xff3aa8a1),
    path: const Color(0xff255c82),
    pathHighlight: const Color(0xffa9e9f4),
  ),
  GameId.rainbowRings => (
    accent: const Color(0xff8059c8),
    accentLight: const Color(0xffd8a3ff),
    backgroundTop: const Color(0xff5d428c),
    backgroundBottom: const Color(0xff2b245d),
    completed: const Color(0xffc15fa7),
    path: const Color(0xff5f3f85),
    pathHighlight: const Color(0xffffc2ed),
  ),
  GameId.colorMatch => (
    accent: const Color(0xffd78732),
    accentLight: const Color(0xffffc875),
    backgroundTop: const Color(0xff8d5543),
    backgroundBottom: const Color(0xff432c55),
    completed: const Color(0xffcf5d73),
    path: const Color(0xff84504d),
    pathHighlight: const Color(0xffffd99a),
  ),
};

final class _JourneyHero extends StatelessWidget {
  const _JourneyHero({required this.metadata, required this.palette});

  final GameUiMetadata metadata;
  final _JourneyPalette palette;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('level-map-hero-${metadata.gameId.storageId}'),
    padding: const EdgeInsets.all(AppSpacing.xl),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.backgroundTop, palette.backgroundBottom],
      ),
      borderRadius: BorderRadius.circular(AppRadii.large),
      border: Border.all(color: palette.accentLight.withValues(alpha: .28)),
      boxShadow: [
        BoxShadow(
          color: palette.accent.withValues(alpha: .18),
          blurRadius: 28,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: .2)),
          ),
          child: Icon(metadata.icon, color: Colors.white, size: 32),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PREMIUM JOURNEY MAP',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.accentLight,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${metadata.label} Journey',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Clear the current level, replay completed challenges, and follow the path to your next reward.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: .82),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _NoProfileMessage extends StatelessWidget {
  const _NoProfileMessage();

  @override
  Widget build(BuildContext context) => StudioCard(
    key: const ValueKey('level-map-no-profile'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create a player first',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'A player profile keeps every level, score, coin, and badge on this device.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

final class _PreparingMap extends StatelessWidget {
  const _PreparingMap();

  @override
  Widget build(BuildContext context) => const StudioCard(
    child: Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: AppSpacing.md),
        Text('Preparing your first 15 levels…'),
      ],
    ),
  );
}

final class _PreparationError extends StatelessWidget {
  const _PreparationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StudioCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('These levels could not be prepared. Try again.'),
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

final class _MapLoadError extends StatelessWidget {
  const _MapLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => StudioCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Game progress could not be opened on this device.'),
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

final class _LevelMap extends StatelessWidget {
  const _LevelMap({
    required this.metadata,
    required this.palette,
    required this.progress,
    required this.launching,
    required this.launchAvailable,
    required this.onPlayCurrent,
    required this.onReplay,
  });

  final GameUiMetadata metadata;
  final _JourneyPalette palette;
  final PlayerGameProgress progress;
  final bool launching;
  final bool launchAvailable;
  final VoidCallback onPlayCurrent;
  final ValueChanged<int> onReplay;

  void _showGift(BuildContext context, int level, bool earned) {
    final coins = GameTier.forLevel(level).rewardCoins;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: Icon(
          earned ? Icons.redeem_rounded : Icons.card_giftcard_rounded,
          size: 44,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        title: Text(earned ? 'Gift collected!' : 'Level $level gift'),
        content: Text(
          earned
              ? 'You collected $coins coins and the level badge.'
              : 'Beat Level $level to open this gift: $coins coins and an exclusive game badge.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final giftLevel = ((progress.highestCompletedLevel ~/ 20) + 1) * 20;
    final giftEarned = progress.badgeMilestones.contains(giftLevel);
    final giftPreview = giftLevel > progress.generatedThrough;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MapOverview(
          metadata: metadata,
          palette: palette,
          progress: progress,
          nextRewardLevel: giftLevel,
          launching: launching,
          launchAvailable: launchAvailable,
          onPlayCurrent: onPlayCurrent,
        ),
        const SizedBox(height: AppSpacing.xxl),
        _JourneySectionHeader(palette: palette),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) {
            final height = 280.0 + progress.generatedThrough * 88.0;
            final size = Size(constraints.maxWidth, height);
            return SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.large),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _LevelPathPainter(
                          palette: palette,
                          levelCount: progress.generatedThrough,
                          giftPreview: giftPreview,
                        ),
                      ),
                    ),
                    for (
                      var level = 1;
                      level <= progress.generatedThrough;
                      level++
                    )
                      _positionLevel(
                        size,
                        level,
                        _LevelNode(
                          palette: palette,
                          level: level,
                          progress: progress,
                          launching: launching,
                          launchAvailable: launchAvailable,
                          isGift: level == giftLevel,
                          giftEarned: giftEarned,
                          onPlayCurrent: onPlayCurrent,
                          onReplay: () => onReplay(level),
                          onShowGift: () => _showGift(
                            context,
                            level,
                            progress.badgeMilestones.contains(level),
                          ),
                        ),
                      ),
                    if (giftPreview)
                      _positionGift(
                        size,
                        giftLevel,
                        GameTier.forLevel(giftLevel).rewardCoins,
                        () => _showGift(context, giftLevel, giftEarned),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _positionLevel(Size size, int level, Widget child) {
    final center = _levelCenter(level, size);
    return Positioned(
      left: center.dx - 40,
      top: center.dy - 33,
      width: 80,
      height: 96,
      child: child,
    );
  }

  Widget _positionGift(Size size, int level, int coins, VoidCallback onTap) =>
      Positioned(
        left: size.width * .5 - 54,
        top: 5,
        width: 108,
        height: 150,
        child: _GiftPreview(level: level, coins: coins, onTap: onTap),
      );
}

final class _MapOverview extends StatelessWidget {
  const _MapOverview({
    required this.metadata,
    required this.palette,
    required this.progress,
    required this.nextRewardLevel,
    required this.launching,
    required this.launchAvailable,
    required this.onPlayCurrent,
  });

  final GameUiMetadata metadata;
  final _JourneyPalette palette;
  final PlayerGameProgress progress;
  final int nextRewardLevel;
  final bool launching;
  final bool launchAvailable;
  final VoidCallback onPlayCurrent;

  @override
  Widget build(BuildContext context) {
    final active = progress.activeAttempt;
    final resumesCurrent =
        active != null &&
        active.playKind == GamePlayKind.current &&
        active.level == progress.currentLevel;
    final rewardCoins = GameTier.forLevel(nextRewardLevel).rewardCoins;
    final primaryLabel = launching
        ? 'Opening Level ${progress.currentLevel}…'
        : resumesCurrent
        ? 'Continue Level ${progress.currentLevel}'
        : 'Play Level ${progress.currentLevel}';
    final primaryAction = FilledButton.icon(
      key: const ValueKey('level-map-primary-action'),
      onPressed: launchAvailable && !launching ? onPlayCurrent : null,
      style: FilledButton.styleFrom(
        backgroundColor: palette.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
      ),
      icon: launching
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              resumesCurrent
                  ? Icons.play_circle_fill_rounded
                  : Icons.play_arrow_rounded,
            ),
      label: Text(primaryLabel),
    );
    return Container(
      key: const ValueKey('level-map-overview'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        border: Border.all(color: palette.accent.withValues(alpha: .18)),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: .09),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 680 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.35;
          final identity = Container(
            key: const ValueKey('level-map-game-identity'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  metadata.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  resumesCurrent
                      ? 'Your current attempt is ready to continue.'
                      : 'Your next challenge is ready to play.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
          final header = compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: AppSpacing.lg),
                    primaryAction,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: AppSpacing.xl),
                    primaryAction,
                  ],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const SizedBox(height: AppSpacing.xl),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _MapStat(
                    valueKey: const ValueKey('level-map-current'),
                    label: 'Current level',
                    value: '${progress.currentLevel}',
                    icon: Icons.flag_rounded,
                    color: palette.accent,
                  ),
                  _MapStat(
                    valueKey: const ValueKey('level-map-completed'),
                    label: 'Completed',
                    value: '${progress.highestCompletedLevel}',
                    icon: Icons.check_circle_rounded,
                    color: palette.completed,
                  ),
                  _MapStat(
                    valueKey: const ValueKey('level-map-next-reward'),
                    label: 'Next reward',
                    value: 'Level $nextRewardLevel · $rewardCoins coins',
                    icon: Icons.card_giftcard_rounded,
                    color: const Color(0xffd9911d),
                    wide: true,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _MapStat extends StatelessWidget {
  const _MapStat({
    required this.valueKey,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  final Key valueKey;
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool wide;

  @override
  Widget build(BuildContext context) => Container(
    key: valueKey,
    width: wide ? 270 : 160,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(AppRadii.medium),
      border: Border.all(color: color.withValues(alpha: .16)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.appColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

final class _JourneySectionHeader extends StatelessWidget {
  const _JourneySectionHeader({required this.palette});

  final _JourneyPalette palette;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.md,
    runSpacing: AppSpacing.sm,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        'Journey path',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      ),
      _MapLegend(color: palette.completed, label: 'Completed'),
      _MapLegend(color: palette.accent, label: 'Current'),
      _MapLegend(
        color: context.appColors.textSecondary.withValues(alpha: .5),
        label: 'Locked',
      ),
    ],
  );
}

final class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

final class _LevelNode extends StatelessWidget {
  const _LevelNode({
    required this.palette,
    required this.level,
    required this.progress,
    required this.launching,
    required this.launchAvailable,
    required this.isGift,
    required this.giftEarned,
    required this.onPlayCurrent,
    required this.onReplay,
    required this.onShowGift,
  });

  final _JourneyPalette palette;
  final int level;
  final PlayerGameProgress progress;
  final bool launching;
  final bool launchAvailable;
  final bool isGift;
  final bool giftEarned;
  final VoidCallback onPlayCurrent;
  final VoidCallback onReplay;
  final VoidCallback onShowGift;

  @override
  Widget build(BuildContext context) {
    final completed = progress.clearedLevels.contains(level);
    final current = level == progress.currentLevel;
    final milestone = level % 20 == 0;
    final badgeEarned = progress.badgeMilestones.contains(level);
    final score = progress.bestScores[level];
    final stateKey = completed
        ? 'level-completed-$level'
        : current
        ? 'level-current-$level'
        : 'level-locked-$level';
    final semanticLabel = completed
        ? 'Level $level, completed, best score ${score ?? 0}'
        : current
        ? 'Level $level, current'
        : 'Level $level, locked';

    final enabled = launchAvailable && !launching;
    final callback = completed
        ? onReplay
        : current
        ? onPlayCurrent
        : null;
    final iconColor = completed
        ? palette.completed
        : current
        ? palette.accent
        : context.appColors.textSecondary;
    final actionTooltip = completed
        ? context.l10n.gameReplayLevel(level)
        : current
        ? context.l10n.gamePlayCurrentLevel(level)
        : null;
    final material = Material(
      color: current
          ? palette.accent
          : completed
          ? palette.completed
          : const Color(0xff718091),
      shape: const CircleBorder(),
      elevation: current ? 8 : 4,
      child: InkWell(
        key: completed
            ? ValueKey('replay-level-$level')
            : current
            ? const ValueKey('play-current-level')
            : ValueKey('locked-level-$level'),
        customBorder: const CircleBorder(),
        onTap: enabled ? callback : null,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: current
                  ? palette.accentLight
                  : Colors.white.withValues(alpha: .78),
              width: current ? 4 : 3,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: current
                  ? [palette.accentLight, palette.accent]
                  : completed
                  ? [
                      Color.lerp(palette.completed, Colors.white, .38)!,
                      palette.completed,
                    ]
                  : const [Color(0xffd6dfc9), Color(0xff859b80)],
            ),
          ),
          alignment: Alignment.center,
          child: launching && current
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : completed
              ? Icon(Icons.check_rounded, color: Colors.white, size: 23)
              : current
              ? Text(
                  '$level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Color(0x55000000), blurRadius: 3)],
                  ),
                )
              : Icon(
                  Icons.lock_rounded,
                  color: Colors.white.withValues(alpha: .9),
                  size: 21,
                ),
        ),
      ),
    );
    final node = actionTooltip == null
        ? material
        : Tooltip(message: actionTooltip, child: material);

    return SizedBox(
      key: ValueKey('level-node-$level'),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Semantics(
            key: ValueKey(stateKey),
            container: true,
            button: callback != null && enabled,
            label: semanticLabel,
            child: SizedBox(width: 66, height: 66, child: node),
          ),
          Positioned(
            top: 68,
            left: 0,
            right: 0,
            child: Text(
              current ? context.l10n.gamePlayLevel(level) : 'Level $level',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                shadows: const [
                  Shadow(color: Color(0x99000000), blurRadius: 3),
                ],
              ),
            ),
          ),
          if (milestone || isGift)
            Positioned(
              top: -8,
              right: -10,
              child: InkWell(
                key: ValueKey('level-milestone-$level'),
                onTap: onShowGift,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isGift && !giftEarned
                        ? const Color(0xffffd44f)
                        : const Color(0xfff8f5e8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xff835b26),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isGift && !giftEarned
                        ? Icons.card_giftcard_rounded
                        : Icons.workspace_premium_rounded,
                    color: isGift && !giftEarned
                        ? const Color(0xff9d402c)
                        : iconColor,
                    size: 21,
                  ),
                ),
              ),
            ),
          if (completed)
            Positioned(
              bottom: badgeEarned ? -36 : -20,
              child: Column(
                children: [
                  Text(
                    'Best ${score ?? 0}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Color(0x99000000), blurRadius: 3),
                      ],
                    ),
                  ),
                  if (badgeEarned)
                    Text(
                      context.l10n.gameBadgeEarned,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 3),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Offset _levelCenter(int level, Size size) {
  final x = switch ((level - 1) % 4) {
    0 => .5,
    1 => .78,
    2 => .5,
    _ => .22,
  };
  return Offset(size.width * x, size.height - 70 - (level - 1) * 88.0);
}

final class _GiftPreview extends StatefulWidget {
  const _GiftPreview({
    required this.level,
    required this.coins,
    required this.onTap,
  });

  final int level;
  final int coins;
  final VoidCallback onTap;

  @override
  State<_GiftPreview> createState() => _GiftPreviewState();
}

final class _GiftPreviewState extends State<_GiftPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool? _reducedMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion == reducedMotion) return;
    _reducedMotion = reducedMotion;
    if (reducedMotion) {
      _pulse
        ..stop()
        ..value = .5;
    } else {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        'Level ${widget.level} mystery gift, ${widget.coins} coins and a badge. Tap to preview.',
    child: InkWell(
      key: const ValueKey('level-gift-preview'),
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final progress = Curves.easeInOut.transform(_pulse.value);
          return Transform.scale(scale: .95 + progress * .09, child: child);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final glow = Curves.easeInOut.transform(_pulse.value);
                return Container(
                  width: 68,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xffffed84),
                        Color(0xffffb33f),
                        Color(0xffe78332),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xff8a5129),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xffffdb5c,
                        ).withValues(alpha: .5 + glow * .35),
                        blurRadius: 8 + glow * 13,
                        spreadRadius: 1 + glow * 3,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: const Icon(
                Icons.card_giftcard_rounded,
                size: 40,
                color: Color(0xff944324),
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'LEVEL ${widget.level} GIFT',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  shadows: const [
                    Shadow(color: Color(0xff304324), blurRadius: 4),
                  ],
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '+${widget.coins} coins',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  shadows: const [
                    Shadow(color: Color(0xff304324), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

final class _LevelPathPainter extends CustomPainter {
  const _LevelPathPainter({
    required this.palette,
    required this.levelCount,
    required this.giftPreview,
  });

  final _JourneyPalette palette;
  final int levelCount;
  final bool giftPreview;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = BorderRadius.circular(AppRadii.large).toRRect(rect);
    canvas.drawRRect(
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.backgroundTop, palette.backgroundBottom],
        ).createShader(rect),
    );
    final hillPaint = Paint()
      ..color = palette.accentLight.withValues(alpha: .09);
    for (var i = 0; i < 9; i++) {
      final x = size.width * (i.isEven ? .08 : .92);
      final y = size.height * (i + 1) / 10;
      canvas.drawCircle(Offset(x, y), 40 + (i % 3) * 8, hillPaint);
    }

    if (levelCount < 1) return;
    final path = Path()
      ..moveTo(_levelCenter(1, size).dx, _levelCenter(1, size).dy);
    for (var level = 2; level <= levelCount; level++) {
      final previous = _levelCenter(level - 1, size);
      final next = _levelCenter(level, size);
      path.quadraticBezierTo(
        (previous.dx + next.dx) / 2 + (level.isEven ? 22 : -22),
        (previous.dy + next.dy) / 2,
        next.dx,
        next.dy,
      );
    }
    if (giftPreview) {
      final top = _levelCenter(levelCount, size);
      path.quadraticBezierTo(size.width * .5, top.dy - 40, size.width * .5, 40);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.path
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.pathHighlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xfffff1aa).withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LevelPathPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.levelCount != levelCount ||
      oldDelegate.giftPreview != giftPreview;
}
