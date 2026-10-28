import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/learning_providers.dart';
import '../data/color_foundations_catalog.dart';
import '../domain/learning_content.dart';
import '../domain/learning_library.dart';
import 'learning_copy.dart';

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(learningSessionProvider);
    return StudioPage(
      name: 'Learn',
      children: [
        StudioHeading(
          eyebrow: context.l10n.learnEyebrow,
          title: context.l10n.learnTitle,
          description: context.l10n.learnDescription,
        ),
        session.when(
          data: (value) => _LearnContent(library: value.visible),
          loading: () => LoadingState(
            title: context.l10n.learningLoadingTitle,
            message: context.l10n.learningLoadingBody,
          ),
          error: (error, stackTrace) => ErrorState(
            title: context.l10n.learningLoadErrorTitle,
            message: context.l10n.learningLoadErrorBody,
            action: FilledButton(
              onPressed: () => ref.invalidate(learningSessionProvider),
              child: Text(context.l10n.roomRetry),
            ),
          ),
        ),
      ],
    );
  }
}

class _LearnContent extends StatelessWidget {
  const _LearnContent({required this.library});
  final LearningLibrary library;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(title: context.l10n.learningSectionLearn),
      for (final lesson in ColorFoundationsCatalog.lessons) ...[
        _LessonCard(
          key: ValueKey('learning-lesson-${lesson.id}'),
          lesson: lesson,
          progress: library.progressByLesson[lesson.id],
          onTap: () => context.push('/learn/lesson/${lesson.id}'),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      const SizedBox(height: AppSpacing.xl),
      SectionHeader(title: context.l10n.learningSectionExperiment),
      for (final tool in [
        (
          key: 'learn-open-capture',
          icon: Icons.colorize_outlined,
          label: context.l10n.learnOpenCapture,
          path: '/capture',
        ),
        (
          key: 'learn-open-palette',
          icon: Icons.palette_outlined,
          label: context.l10n.learnOpenPalette,
          path: '/palette',
        ),
        (
          key: 'learn-open-lab',
          icon: Icons.science_outlined,
          label: context.l10n.learnOpenLab,
          path: '/learn/experiment/lab',
        ),
        (
          key: 'learn-open-mixer',
          icon: Icons.blender_outlined,
          label: context.l10n.learnOpenMixer,
          path: '/learn/experiment/mixer',
        ),
        (
          key: 'learn-open-harmonies',
          icon: Icons.hub_outlined,
          label: context.l10n.learnOpenHarmonies,
          path: '/learn/experiment/harmonies',
        ),
        (
          key: 'learn-open-formula',
          icon: Icons.functions_rounded,
          label: context.l10n.learnOpenFormula,
          path: '/learn/experiment/formula',
        ),
        (
          key: 'learn-open-matching',
          icon: Icons.tune_rounded,
          label: context.l10n.learnOpenMatching,
          path: '/learn/experiment/matching',
        ),
        (
          key: 'learn-open-vision',
          icon: Icons.visibility_outlined,
          label: context.l10n.learnOpenVision,
          path: '/vision',
        ),
      ]) ...[
        _LearningLink(
          key: ValueKey(tool.key),
          icon: tool.icon,
          label: tool.label,
          onTap: () => context.push(tool.path),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      const SizedBox(height: AppSpacing.xl),
      SectionHeader(title: context.l10n.learningSectionMyWork),
      _LearningLink(
        key: const ValueKey('learn-open-my-work'),
        icon: Icons.collections_bookmark_outlined,
        label: context.l10n.learningOpenNotebook,
        onTap: () => context.push('/learn/notebook'),
      ),
    ],
  );
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    super.key,
    required this.lesson,
    required this.progress,
    required this.onTap,
  });
  final LearningLesson lesson;
  final LessonProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final current = progress?.currentStepIndex ?? 0;
    final status = progress?.completed == true
        ? context.l10n.learningLessonComplete
        : progress == null
        ? context.l10n.learningStartLesson
        : context.l10n.learningResumeStage(
            context.l10n.learningCopy(lesson.steps[current].titleKey),
          );
    return Semantics(
      button: true,
      label:
          '${context.l10n.learningCopy(lesson.titleKey)}. $status. '
          '${context.l10n.learningCopy(lesson.summaryKey)}',
      child: Material(
        color: context.appColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.large),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppTouchTargets.minimum,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    progress?.completed == true
                        ? Icons.check_circle_rounded
                        : Icons.school_outlined,
                    color: context.appColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.learningCopy(lesson.titleKey),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(context.l10n.learningCopy(lesson.summaryKey)),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          status,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: context.appColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.arrow_forward_rounded),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LearningLink extends StatelessWidget {
  const _LearningLink({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: context.appColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppTouchTargets.minimum),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(icon, color: context.appColors.primary),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
