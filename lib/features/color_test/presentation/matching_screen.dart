import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_engine.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../history/domain/saved_color.dart';
import '../../picker/presentation/color_explorer.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/matching_game_controller.dart';
import '../domain/matching_game.dart';

class MatchingScreen extends ConsumerStatefulWidget {
  const MatchingScreen({super.key});

  @override
  ConsumerState<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends ConsumerState<MatchingScreen> {
  final _scrollController = ScrollController();
  bool _confirming = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _restart() async {
    if (_confirming) return;
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
                const Text(
                  'Your current rounds will be replaced with five new targets.',
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
        ref.read(matchingGameProvider.notifier).restart();
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/lab');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(matchingGameProvider, (previous, next) {
      if (previous != null &&
          (previous.roundIndex != next.roundIndex ||
              (previous.phase == MatchingPhase.complete) !=
                  (next.phase == MatchingPhase.complete) ||
              !identical(previous.targets, next.targets)) &&
          _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
    final game = ref.watch(matchingGameProvider);
    final controller = ref.read(matchingGameProvider.notifier);
    final editing = game.phase == MatchingPhase.editing;
    final attempt = game.currentAttempt;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color matching'),
        leading: IconCircleButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          onPressed: _back,
        ),
      ),
      bottomNavigationBar: game.phase == MatchingPhase.complete
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
                  if (game.phase == MatchingPhase.complete)
                    _MatchingResults(
                      game: game,
                      onPlayAgain: controller.restart,
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
                            onChanged: editing ? controller.setHue : null,
                          ),
                          LabeledSlider(
                            key: const ValueKey('matching-saturation'),
                            label: 'Saturation',
                            value: game.saturation,
                            valueLabel: '${(game.saturation * 100).round()}%',
                            valueFormatter: (value) =>
                                '${(value * 100).round()}%',
                            onChanged: editing
                                ? controller.setSaturation
                                : null,
                          ),
                          LabeledSlider(
                            key: const ValueKey('matching-lightness'),
                            label: 'Lightness',
                            value: game.lightness,
                            valueLabel: '${(game.lightness * 100).round()}%',
                            valueFormatter: (value) =>
                                '${(value * 100).round()}%',
                            onChanged: editing ? controller.setLightness : null,
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
                        onPressed: controller.submit,
                      )
                    else
                      PrimaryButton(
                        key: const ValueKey('matching-next'),
                        label: game.roundNumber == 5
                            ? 'See results'
                            : 'Next round',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: controller.nextRound,
                      ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      key: const ValueKey('matching-restart'),
                      label: 'Restart game',
                      icon: Icons.refresh_rounded,
                      onPressed: _confirming ? null : _restart,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Screens and lighting affect how colors look. Points use 100 minus CIE76 ΔE, rounded and limited to 0–100; they are game points, not a scientific percentage. This is a color game, not a medical test or diagnosis. Your game stays for this app session.',
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
                  'Round ${game.roundNumber} of 5',
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
  const _MatchingResults({required this.game, required this.onPlayAgain});
  final MatchingGame game;
  final VoidCallback onPlayAgain;

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const StudioHeading(
        eyebrow: 'Five rounds, your way',
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
                '${game.totalScore} / 500',
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
                target: _shade(context, 'Target', game.attempts[index].target),
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
      PrimaryButton(
        key: const ValueKey('matching-play-again'),
        label: 'Play again',
        icon: Icons.refresh_rounded,
        onPressed: onPlayAgain,
      ),
    ],
  );
}
