import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../games/application/game_profiles_provider.dart';
import '../../games/domain/game_id.dart';
import '../../games/domain/game_launch.dart';
import '../../games/domain/game_progression_engine.dart';
import '../../games/presentation/game_play_app_bar.dart';
import '../../history/domain/saved_color.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/matching_game_controller.dart';
import '../domain/color_match_level_adapter.dart';
import '../domain/matching_game.dart';

class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key, this.launch, this.onOpenMap});

  final GameLaunch? launch;
  final VoidCallback? onOpenMap;

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  final _scrollController = ScrollController();
  GameLaunch? _launch;
  MatchingProfileSessionKey? _profileKey;
  int _launchToken = 0;
  bool _confirming = false;
  bool _savingResult = false;
  bool _attemptBusy = false;
  bool _dialogOpen = false;
  bool _staleResult = false;
  String? _resultSaveError;
  List<RgbColor>? _recordedTargets;
  LevelCompletionReceipt? _completionReceipt;

  bool get _navigationLocked =>
      _confirming ||
      _savingResult ||
      _attemptBusy ||
      _dialogOpen ||
      _staleResult;

  @override
  void initState() {
    super.initState();
    _installWidgetLaunch(widget.launch);
  }

  @override
  void didUpdateWidget(covariant MatchingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launch != widget.launch) {
      _installWidgetLaunch(widget.launch);
    }
  }

  void _installWidgetLaunch(GameLaunch? launch) {
    _launchToken++;
    _launch = launch;
    _profileKey = launch == null ? null : MatchingProfileSessionKey(launch);
    _savingResult = false;
    _attemptBusy = false;
    _dialogOpen = false;
    _staleResult = false;
    _resultSaveError = null;
    _recordedTargets = null;
    _completionReceipt = null;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restart() async {
    if (_navigationLocked) return;
    final launch = _launch;
    final token = _launchToken;
    final roundCount = _readGame().targets.length;
    setState(() => _confirming = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        animationStyle: AppMotion.sheetAnimation(context),
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Restart this game?'),
          content: SizedBox(
            width: AppSpacing.huge * 6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Your current $roundCount rounds will be replaced with new targets.',
                ),
                const SizedBox(height: AppSpacing.xxl),
                PrimaryButton(
                  key: const ValueKey('confirm-matching-restart'),
                  label: 'Restart game',
                  icon: Icons.refresh_rounded,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
              ],
            ),
          ),
        ),
      );
      if (mounted && confirmed == true) {
        if (launch == null) {
          if (_launchToken != token || _launch != null) return;
          ref.read(matchingGameProvider.notifier).restart();
        } else {
          if (!_isCurrent(launch, token)) return;
          await _startFreshAttempt();
        }
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  MatchingGame _readGame() {
    final key = _profileKey;
    return key == null
        ? ref.read(matchingGameProvider)
        : ref.read(profileMatchingGameProvider(key));
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/lab');
    }
  }

  bool _isCurrent(GameLaunch launch, int token) =>
      mounted && _launchToken == token && _launch == launch;

  bool _isActiveProfile(GameLaunch launch, int token) {
    if (!_isCurrent(launch, token)) return false;
    final profiles = ref.read(gameProfilesProvider);
    return profiles.hasValue &&
        profiles.requireValue.activeProfileId == launch.profileId;
  }

  Future<GameLaunch> _beginFreshAttempt(GameLaunch launch) {
    final controller = ref.read(gameProfilesProvider.notifier);
    return switch (launch.playKind) {
      GamePlayKind.current => controller.beginCurrentAttempt(
        profileId: launch.profileId,
        gameId: GameId.colorMatch,
      ),
      GamePlayKind.replay => controller.beginReplayAttempt(
        profileId: launch.profileId,
        gameId: GameId.colorMatch,
        level: launch.descriptor.level,
      ),
    };
  }

  void _applyLaunch(GameLaunch launch) {
    _launchToken++;
    setState(() {
      _launch = launch;
      _profileKey = MatchingProfileSessionKey(launch);
      _savingResult = false;
      _attemptBusy = false;
      _dialogOpen = false;
      _staleResult = false;
      _resultSaveError = null;
      _recordedTargets = null;
      _completionReceipt = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  Future<void> _startFreshAttempt() async {
    final launch = _launch;
    if (launch == null || _attemptBusy) return;
    final token = _launchToken;
    while (_isCurrent(launch, token)) {
      if (!_isActiveProfile(launch, token)) {
        _markStale();
        return;
      }
      setState(() => _attemptBusy = true);
      try {
        final replacement = await _beginFreshAttempt(launch);
        if (!_isCurrent(launch, token)) return;
        if (!_isActiveProfile(launch, token)) {
          _markStale();
          return;
        }
        _applyLaunch(replacement);
        return;
      } catch (error) {
        if (!_isCurrent(launch, token)) return;
        setState(() => _attemptBusy = false);
        if (error is GameProgressionException &&
            error.code == GameProgressionError.staleAttempt) {
          _markStale();
          return;
        }
        final retry = await _showProtectedDialog<bool>(
          builder: (dialogContext) => AlertDialog(
            title: const Text('Could not restart level'),
            content: const Text(
              'A fresh attempt has not been saved yet. Check storage and retry.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Retry attempt'),
              ),
            ],
          ),
        );
        if (retry != true || !_isCurrent(launch, token)) return;
      }
    }
  }

  Future<void> _saveResult(MatchingGame game) async {
    final launch = _launch;
    if (launch == null ||
        !game.won ||
        _savingResult ||
        _completionReceipt != null ||
        identical(_recordedTargets, game.targets)) {
      return;
    }
    final token = _launchToken;
    if (!_isActiveProfile(launch, token)) {
      _markStale();
      return;
    }
    _recordedTargets = game.targets;
    setState(() {
      _savingResult = true;
      _staleResult = false;
      _resultSaveError = null;
    });
    try {
      final receipt = await ref
          .read(gameProfilesProvider.notifier)
          .completeLevel(
            launch,
            ColorMatchOutcome(averageScore: game.averageScore),
          );
      if (!_isCurrent(launch, token)) return;
      if (!_isActiveProfile(launch, token)) {
        _markStale();
        return;
      }
      setState(() => _completionReceipt = receipt);
    } catch (error) {
      if (!_isCurrent(launch, token)) return;
      if (error is GameProgressionException &&
          error.code == GameProgressionError.staleAttempt) {
        _markStale();
        return;
      }
      _recordedTargets = null;
      setState(() => _resultSaveError = 'Could not save progress.');
    } finally {
      if (_isCurrent(launch, token)) {
        setState(() => _savingResult = false);
      }
    }
  }

  Future<void> _startNextLevel() async {
    final launch = _launch;
    if (launch == null || _attemptBusy || _completionReceipt == null) return;
    final token = _launchToken;
    while (_isCurrent(launch, token)) {
      if (!_isActiveProfile(launch, token)) {
        _markStale();
        return;
      }
      setState(() => _attemptBusy = true);
      try {
        final controller = ref.read(gameProfilesProvider.notifier);
        await controller.prepareGame(
          profileId: launch.profileId,
          gameId: GameId.colorMatch,
        );
        if (!_isCurrent(launch, token)) return;
        if (!_isActiveProfile(launch, token)) {
          _markStale();
          return;
        }
        final next = await controller.beginCurrentAttempt(
          profileId: launch.profileId,
          gameId: GameId.colorMatch,
        );
        if (!_isCurrent(launch, token)) return;
        if (!_isActiveProfile(launch, token)) {
          _markStale();
          return;
        }
        _applyLaunch(next);
        return;
      } catch (error) {
        if (!_isCurrent(launch, token)) return;
        setState(() => _attemptBusy = false);
        if (error is GameProgressionException &&
            error.code == GameProgressionError.staleAttempt) {
          _markStale();
          return;
        }
        final retry = await _showProtectedDialog<bool>(
          builder: (dialogContext) => AlertDialog(
            title: const Text('Could not start next level'),
            content: const Text(
              'The next level has not started yet. Check storage and retry.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Retry Next Level'),
              ),
            ],
          ),
        );
        if (retry != true || !_isCurrent(launch, token)) return;
      }
    }
  }

  Future<T?> _showProtectedDialog<T>({
    required Widget Function(BuildContext dialogContext) builder,
  }) async {
    if (!mounted || _dialogOpen) return null;
    setState(() => _dialogOpen = true);
    try {
      return await showDialog<T>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) =>
            PopScope(canPop: false, child: builder(dialogContext)),
      );
    } finally {
      if (mounted) setState(() => _dialogOpen = false);
    }
  }

  void _markStale() {
    if (!mounted) return;
    setState(() {
      _savingResult = false;
      _attemptBusy = false;
      _completionReceipt = null;
      _recordedTargets = null;
      _staleResult = true;
      _resultSaveError = 'This attempt is no longer active.';
    });
  }

  void _handleGameChange(MatchingGame? previous, MatchingGame next) {
    if (previous?.phase == MatchingPhase.complete &&
        next.phase != MatchingPhase.complete) {
      _recordedTargets = null;
      _completionReceipt = null;
      _staleResult = false;
      _resultSaveError = null;
    }
    if (previous?.phase != MatchingPhase.complete &&
        next.phase == MatchingPhase.complete &&
        _launch != null &&
        next.won) {
      unawaited(_saveResult(next));
    }
    if (previous != null &&
        (previous.roundIndex != next.roundIndex ||
            (previous.phase == MatchingPhase.complete) !=
                (next.phase == MatchingPhase.complete) ||
            !identical(previous.targets, next.targets)) &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    late final MatchingGame game;
    late final void Function(double) setHue;
    late final void Function(double) setSaturation;
    late final void Function(double) setLightness;
    late final VoidCallback submit;
    late final VoidCallback nextRound;
    late final VoidCallback practiceRestart;
    final profileKey = _profileKey;
    if (profileKey == null) {
      ref.listen(matchingGameProvider, _handleGameChange);
      game = ref.watch(matchingGameProvider);
      final controller = ref.read(matchingGameProvider.notifier);
      setHue = controller.setHue;
      setSaturation = controller.setSaturation;
      setLightness = controller.setLightness;
      submit = controller.submit;
      nextRound = controller.nextRound;
      practiceRestart = controller.restart;
    } else {
      final provider = profileMatchingGameProvider(profileKey);
      ref.listen(provider, _handleGameChange);
      game = ref.watch(provider);
      final controller = ref.read(provider.notifier);
      setHue = controller.setHue;
      setSaturation = controller.setSaturation;
      setLightness = controller.setLightness;
      submit = controller.submit;
      nextRound = controller.nextRound;
      // Profile restarts must allocate and persist a fresh attempt. This
      // callback is never exposed by the profile result UI.
      practiceRestart = () {};
    }
    final editing = game.phase == MatchingPhase.editing;
    final attempt = game.currentAttempt;
    final launch = _launch;
    return Scaffold(
      appBar: GamePlayAppBar(
        title: 'Color Match',
        subtitle: launch == null
            ? 'Color practice'
            : 'Level ${launch.descriptor.level} · ${launch.descriptor.tier.label}',
        onBack: _back,
        onOpenMap: launch == null ? null : widget.onOpenMap,
        locked: _navigationLocked,
        backgroundColor: context.appColors.surface,
        foregroundColor: context.appColors.textPrimary,
        buttonColor: context.appColors.surfaceElevated,
        accentColor: context.appColors.primary,
      ),
      bottomNavigationBar: game.phase == MatchingPhase.complete || _staleResult
          ? null
          : _LiveComparison(game: game),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const ValueKey('screen-Matching'),
          controller: _scrollController,
          padding: AppSpacing.screenPadding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (launch != null)
                    const SizedBox(height: AppSpacing.xl),
                  if (launch != null &&
                      _staleResult &&
                      game.phase != MatchingPhase.complete)
                    const _StaleSessionNotice()
                  else if (game.phase == MatchingPhase.complete)
                    _MatchingResults(
                      game: game,
                      launch: launch,
                      receipt: _completionReceipt,
                      saving: _savingResult,
                      stale: _staleResult,
                      saveError: _resultSaveError,
                      onRetrySave: () => _saveResult(game),
                      onPracticePlayAgain: practiceRestart,
                      onTryAgain: () => unawaited(_startFreshAttempt()),
                      onNextLevel: () => unawaited(_startNextLevel()),
                      attemptBusy: _attemptBusy,
                    )
                  else ...[
                    const StudioHeading(
                      eyebrow: 'Match the target',
                      title: 'Find the same feeling.',
                      description:
                          'Move the HSL sliders to match the target. Take your time, then check your match.',
                    ),
                    _SwatchPair(
                      target: ColorSwatchTile(
                        key: const ValueKey('matching-target'),
                        color: displayColor(game.target),
                        name: 'Target',
                        hex: editing
                            ? 'Hidden until you submit'
                            : game.target.hex,
                        onTap: editing
                            ? null
                            : () => showColorDetails(
                                context,
                                game.target,
                                source: ColorSource.lab,
                              ),
                      ),
                      guess: ColorSwatchTile(
                        key: const ValueKey('matching-guess'),
                        color: displayColor(game.guess),
                        name: 'Your match',
                        hex: editing
                            ? 'Hidden until you submit'
                            : game.guess.hex,
                        onTap: editing
                            ? null
                            : () => showColorDetails(
                                context,
                                game.guess,
                                source: ColorSource.lab,
                              ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (attempt != null) ...[
                      StudioCard(
                        child: Semantics(
                          container: true,
                          liveRegion: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                attempt.isExact
                                    ? 'Exact match!'
                                    : 'Your round result',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                '${attempt.score} / 100 points',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text('ΔE ${attempt.deltaE.toStringAsFixed(2)}'),
                              const SizedBox(height: AppSpacing.sm),
                              const Text(
                                'Lower ΔE means a closer color. Tap either swatch to explore its values.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                    StudioCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader(title: 'Shape your match'),
                          LabeledSlider(
                            key: const ValueKey('matching-hue'),
                            label: 'Hue',
                            value: game.hue,
                            max: 359.999,
                            valueLabel: '${game.hue.round()}°',
                            valueFormatter: (value) => '${value.round()}°',
                            onChanged: editing && !_navigationLocked
                                ? setHue
                                : null,
                          ),
                          LabeledSlider(
                            key: const ValueKey('matching-saturation'),
                            label: 'Saturation',
                            value: game.saturation,
                            valueLabel: '${(game.saturation * 100).round()}%',
                            valueFormatter: (value) =>
                                '${(value * 100).round()}%',
                            onChanged: editing && !_navigationLocked
                                ? setSaturation
                                : null,
                          ),
                          LabeledSlider(
                            key: const ValueKey('matching-lightness'),
                            label: 'Lightness',
                            value: game.lightness,
                            valueLabel: '${(game.lightness * 100).round()}%',
                            valueFormatter: (value) =>
                                '${(value * 100).round()}%',
                            onChanged: editing && !_navigationLocked
                                ? setLightness
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    if (editing)
                      PrimaryButton(
                        key: const ValueKey('matching-submit'),
                        label: 'Check my match',
                        icon: Icons.check_rounded,
                        onPressed: _navigationLocked ? null : submit,
                      )
                    else
                      PrimaryButton(
                        key: const ValueKey('matching-next'),
                        label: game.roundNumber == game.targets.length
                            ? 'See results'
                            : 'Next round',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _navigationLocked ? null : nextRound,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      key: const ValueKey('matching-restart'),
                      label: 'Restart game',
                      icon: Icons.refresh_rounded,
                      onPressed: _navigationLocked ? null : _restart,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Screens and lighting affect how colors look. Points use 100 minus CIE76 ΔE, rounded and limited to 0–100; they are game points, not a scientific percentage. This is a color game, not a medical test or diagnosis. Game rewards stay on this device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaleSessionNotice extends StatelessWidget {
  const _StaleSessionNotice();

  @override
  Widget build(BuildContext context) => StudioCard(
    child: Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Session changed',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'This attempt belongs to a profile that is no longer active. Go back to continue with the active profile.',
          ),
        ],
      ),
    ),
  );
}

class _LiveComparison extends StatelessWidget {
  const _LiveComparison({required this.game});
  final MatchingGame game;

  Widget _color(
    BuildContext context,
    String role,
    String key,
    RgbColor color,
  ) => Expanded(
    child: Semantics(
      label: '$role comparison',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(role, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.small),
            child: ColoredBox(
              key: ValueKey(key),
              color: displayColor(color),
              child: const SizedBox(height: AppSpacing.huge),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Material(
    color: context.appColors.surface,
    child: SafeArea(
      top: false,
      minimum: const EdgeInsets.all(AppSpacing.md),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  'Round ${game.roundNumber} of ${game.targets.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _color(
                    context,
                    'Target',
                    'matching-comparison-target',
                    game.target,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _color(
                    context,
                    'Your match',
                    'matching-comparison-guess',
                    game.guess,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _SwatchPair extends StatelessWidget {
  const _SwatchPair({required this.target, required this.guess});
  final Widget target, guess;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= 520
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: target),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: guess),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              target,
              const SizedBox(height: AppSpacing.lg),
              guess,
            ],
          ),
  );
}

class _MatchingResults extends StatelessWidget {
  const _MatchingResults({
    required this.game,
    required this.launch,
    required this.receipt,
    required this.saving,
    required this.stale,
    required this.saveError,
    required this.onRetrySave,
    required this.onPracticePlayAgain,
    required this.onTryAgain,
    required this.onNextLevel,
    required this.attemptBusy,
  });
  final MatchingGame game;
  final GameLaunch? launch;
  final LevelCompletionReceipt? receipt;
  final bool saving;
  final bool stale;
  final String? saveError;
  final VoidCallback onRetrySave;
  final VoidCallback onPracticePlayAgain;
  final VoidCallback onTryAgain;
  final VoidCallback onNextLevel;
  final bool attemptBusy;

  Widget _shade(BuildContext context, String label, RgbColor color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: AppSpacing.xs),
      ColorChip(
        color: displayColor(color),
        label: color.hex,
        onTap: () => showColorDetails(context, color, source: ColorSource.lab),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final profileLaunch = launch;
    final completion = receipt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StudioHeading(
          eyebrow: profileLaunch == null
              ? '${game.difficulty.label} · ${game.targets.length} rounds'
              : 'Level ${profileLaunch.descriptor.level} · ${profileLaunch.descriptor.tier.label} · ${game.targets.length} rounds',
          title: 'A study in closeness.',
          description: 'Your finished matches stay here until you play again.',
        ),
        StudioCard(
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Total points'),
                Text(
                  '${game.totalScore} / ${game.targets.length * 100}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('Average per round'),
                Text(
                  '${game.averageScore.toStringAsFixed(2)} / 100',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        if (profileLaunch != null) ...[
          const SizedBox(height: AppSpacing.lg),
          StudioCard(
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _profileTitle(completion),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_profileMessage(completion)),
                  if (completion != null &&
                      !completion.alreadyApplied &&
                      completion.coinsAwarded > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text('+${completion.coinsAwarded} coins'),
                  ],
                  if (completion != null &&
                      !completion.alreadyApplied &&
                      completion.badgeId != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    const Text('Badge earned'),
                  ],
                  if (saveError != null && !stale && completion == null) ...[
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      key: const ValueKey('matching-retry-save'),
                      label: 'Retry save',
                      icon: Icons.refresh_rounded,
                      onPressed: onRetrySave,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxl),
        for (var index = 0; index < game.attempts.length; index++) ...[
          StudioCard(
            key: ValueKey('matching-result-${index + 1}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Round ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                _SwatchPair(
                  target: _shade(
                    context,
                    'Target',
                    game.attempts[index].target,
                  ),
                  guess: _shade(
                    context,
                    'Your match',
                    game.attempts[index].guess,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('${game.attempts[index].score} / 100 points'),
                Text('ΔE ${game.attempts[index].deltaE.toStringAsFixed(2)}'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (profileLaunch == null)
          PrimaryButton(
            key: const ValueKey('matching-play-again'),
            label: 'Play again',
            icon: Icons.refresh_rounded,
            onPressed: onPracticePlayAgain,
          )
        else if (!game.won)
          PrimaryButton(
            key: const ValueKey('matching-try-again'),
            label: attemptBusy ? 'Starting…' : 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: stale || attemptBusy ? null : onTryAgain,
          )
        else if (completion != null)
          PrimaryButton(
            key: const ValueKey('matching-next-level'),
            label: attemptBusy ? 'Starting…' : 'Next Level',
            icon: Icons.arrow_forward_rounded,
            onPressed: stale || attemptBusy ? null : onNextLevel,
          ),
      ],
    );
  }

  String _profileTitle(LevelCompletionReceipt? completion) {
    if (stale) return 'Session changed';
    if (!game.won) return 'Keep practicing to win this level.';
    if (saving) return 'Saving your win…';
    if (saveError != null && completion == null) return 'Could not save win';
    if (completion?.alreadyApplied ?? false) return 'Level already saved';
    if (completion != null) return 'Level complete!';
    return 'Checking your result…';
  }

  String _profileMessage(LevelCompletionReceipt? completion) {
    if (stale) return 'This attempt is no longer active.';
    if (!game.won) {
      return 'Reach an average score of ${game.rules.winningAverage}+ to clear this level.';
    }
    if (saving) return 'Saving your progress on this device…';
    if (saveError != null && completion == null) return saveError!;
    if (completion?.alreadyApplied ?? false) {
      return 'Progress was already saved on this device.';
    }
    if (completion != null) return 'Progress saved on this device.';
    return 'Your reward will appear after progress is saved.';
  }
}
