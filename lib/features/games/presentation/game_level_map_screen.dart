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
    final profiles = ref.watch(gameProfilesProvider);
    return StudioPage(
      name: '${metadata.label} level map',
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
        StudioHeading(
          eyebrow: metadata.label,
          title: 'Level map',
          description:
              'Clear levels to move along the path. Tap the gift to preview its coins and badge.',
        ),
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
    required this.progress,
    required this.launching,
    required this.launchAvailable,
    required this.onPlayCurrent,
    required this.onReplay,
  });

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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final giftLevel = ((progress.highestCompletedLevel ~/ 20) + 1) * 20;
      final giftEarned = progress.badgeMilestones.contains(giftLevel);
      final giftPreview = giftLevel > progress.generatedThrough;
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
                    levelCount: progress.generatedThrough,
                    giftPreview: giftPreview,
                  ),
                ),
              ),
              for (var level = 1; level <= progress.generatedThrough; level++)
                _positionLevel(
                  size,
                  level,
                  _LevelNode(
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
  );

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

final class _LevelNode extends StatelessWidget {
  const _LevelNode({
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
        ? context.appColors.success
        : current
        ? context.appColors.primary
        : context.appColors.textSecondary;
    final actionTooltip = completed
        ? context.l10n.gameReplayLevel(level)
        : current
        ? context.l10n.gamePlayCurrentLevel(level)
        : null;
    final material = Material(
      color: current
          ? const Color(0xff3eaf56)
          : completed
          ? const Color(0xff4f9c64)
          : const Color(0xff9bb49a),
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
                  ? const Color(0xffffe072)
                  : const Color(0xffe8f0dc),
              width: current ? 4 : 3,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: current
                  ? const [Color(0xff75dd65), Color(0xff219748)]
                  : completed
                  ? const [Color(0xffa0df8d), Color(0xff438857)]
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
    required this.levelCount,
    required this.giftPreview,
  });

  final int levelCount;
  final bool giftPreview;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = BorderRadius.circular(AppRadii.large).toRRect(rect);
    canvas.drawRRect(
      radius,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff78c95c), Color(0xff39994d), Color(0xff74bf4f)],
        ).createShader(rect),
    );
    final hillPaint = Paint()
      ..color = const Color(0xffb2e16d).withValues(alpha: .42);
    for (var i = 0; i < 7; i++) {
      final x = size.width * (i.isEven ? .08 : .92);
      final y = size.height * (i + 1) / 8;
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
        ..color = const Color(0xff8b5a32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 28
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xffffd866)
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
      oldDelegate.levelCount != levelCount ||
      oldDelegate.giftPreview != giftPreview;
}
