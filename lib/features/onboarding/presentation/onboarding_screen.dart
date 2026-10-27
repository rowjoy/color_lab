import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../l10n/l10n.dart';
import 'onboarding_art.dart';

/// A presentation-only tour. The caller owns saving completion and navigation.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinish,
    this.isReplay = false,
  });

  final Future<void> Function() onFinish;
  final bool isReplay;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    if (_busy) return;
    final duration = AppMotion.duration(context, AppMotion.page);
    if (duration == Duration.zero) {
      _pages.jumpToPage(page);
    } else {
      unawaited(
        _pages.animateToPage(page, duration: duration, curve: AppMotion.enter),
      );
    }
  }

  Future<void> _finish() async {
    if (_busy) return;
    // Cancel any in-flight slide movement before locking the tour.
    _pages.jumpToPage(_page);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.onFinish();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final slides = _slides(l10n);
    return PopScope<Object?>(
      canPop: widget.isReplay && !_busy,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_busy && !widget.isReplay && _page > 0) {
          _goTo(_page - 1);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: AppSpacing.xxl,
                        height: AppSpacing.xxl,
                        decoration: BoxDecoration(
                          gradient: colors.accentGradient,
                          borderRadius: BorderRadius.circular(AppRadii.small),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: AppSpacing.lg,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.appName,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.textPrimary,
                              letterSpacing: 1.6,
                            ),
                      ),
                    ),
                    SecondaryButton(
                      label: l10n.skip,
                      onPressed: _busy ? null : _finish,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: slides.length,
                  physics: _busy ? const NeverScrollableScrollPhysics() : null,
                  onPageChanged: (page) {
                    setState(() {
                      _page = page;
                      _failed = false;
                    });
                  },
                  itemBuilder: (context, page) => _Slide(
                    key: ValueKey('onboarding-page-$page'),
                    index: page,
                    slide: slides[page],
                    failed: _failed && page == _page,
                  ),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ExcludeSemantics(
                              child: Row(
                                children: List.generate(
                                  slides.length,
                                  (index) => Container(
                                    width: index == _page
                                        ? AppSpacing.xxl
                                        : AppSpacing.sm,
                                    height: AppSpacing.xs,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs,
                                    ),
                                    decoration: BoxDecoration(
                                      color: index == _page
                                          ? colors.primary
                                          : colors.outline,
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.pill,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Semantics(
                                label: l10n.onboardingStep(
                                  _page + 1,
                                  slides.length,
                                ),
                                liveRegion: true,
                                excludeSemantics: true,
                                child: Text(
                                  l10n.onboardingStep(_page + 1, slides.length),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            if (_page > 0) ...[
                              IconCircleButton(
                                icon: Icons.arrow_back_rounded,
                                label: l10n.back,
                                onPressed: _busy
                                    ? null
                                    : () => _goTo(_page - 1),
                              ),
                              const SizedBox(width: AppSpacing.md),
                            ],
                            Expanded(
                              child: PrimaryButton(
                                label: _failed
                                    ? l10n.tryAgain
                                    : _page == slides.length - 1
                                    ? (widget.isReplay
                                          ? l10n.done
                                          : l10n.getStarted)
                                    : l10n.next,
                                isLoading: _busy,
                                onPressed: _busy
                                    ? null
                                    : () {
                                        if (_failed ||
                                            _page == slides.length - 1) {
                                          unawaited(_finish());
                                        } else {
                                          _goTo(_page + 1);
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<_SlideContent> _slides(AppLocalizations l10n) => [
  (
    eyebrow: l10n.onboardingCuriousEyeEyebrow,
    title: l10n.onboardingCuriousEyeTitle,
    body: l10n.onboardingCuriousEyeBody,
    note: l10n.onboardingCuriousEyeNote,
    icon: Icons.colorize_outlined,
  ),
  (
    eyebrow: l10n.onboardingPersonalEyebrow,
    title: l10n.onboardingPersonalTitle,
    body: l10n.onboardingPersonalBody,
    note: l10n.onboardingPersonalNote,
    icon: Icons.bookmark_border_rounded,
  ),
  (
    eyebrow: l10n.onboardingControlEyebrow,
    title: l10n.onboardingControlTitle,
    body: l10n.onboardingControlBody,
    note: l10n.onboardingControlNote,
    icon: Icons.verified_user_outlined,
  ),
];

typedef _SlideContent = ({
  String eyebrow,
  String title,
  String body,
  String note,
  IconData icon,
});

class _Slide extends StatelessWidget {
  const _Slide({
    super.key,
    required this.index,
    required this.slide,
    required this.failed,
  });

  final int index;
  final _SlideContent slide;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.md,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (failed) ...[
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: colors.surfaceElevated,
                        border: Border.all(color: colors.outline),
                        borderRadius: BorderRadius.circular(AppRadii.small),
                      ),
                      child: Text(
                        context.l10n.tourFinishError,
                        style: text.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                OnboardingArt(
                  index: index,
                  height: (constraints.maxHeight * .43).clamp(120.0, 240.0),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  slide.eyebrow,
                  style: text.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text(slide.title, style: text.displaySmall),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  slide.body,
                  style: text.bodyLarge?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.outline),
                    borderRadius: BorderRadius.circular(AppRadii.medium),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Icon(slide.icon, color: colors.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(slide.note, style: text.bodyMedium)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
