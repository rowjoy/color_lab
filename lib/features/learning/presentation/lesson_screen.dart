import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/learning_providers.dart';
import '../data/color_foundations_catalog.dart';
import '../domain/learning_content.dart';
import '../domain/learning_library.dart';
import 'concept_question_view.dart';
import 'learning_copy.dart';
import 'lesson_step_view.dart';

class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late Future<LessonProgress> _opening;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _opening = _open();
  }

  Future<LessonProgress> _open() =>
      ref.read(learningSessionProvider.notifier).openLesson(widget.lessonId);

  Future<void> _run(Future<Object?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      // The controller retains visible work and publishes the recoverable error.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _retryOpen() => setState(() => _opening = _open());

  Future<void> _confirmReset() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.learningResetLessonTitle),
        content: Text(context.l10n.learningResetLessonBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            key: const ValueKey('learning-confirm-reset'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.learningResetLesson),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _run(
        () => ref
            .read(learningSessionProvider.notifier)
            .resetLesson(widget.lessonId),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lesson = ColorFoundationsCatalog.byId(widget.lessonId);
    final session = ref.watch(learningSessionProvider);
    return FutureBuilder<LessonProgress>(
      future: _opening,
      builder: (context, opening) {
        if (opening.hasError || session.hasError) {
          return StudioPage(
            name: 'Lesson',
            children: [
              ErrorState(
                title: context.l10n.learningLoadErrorTitle,
                message: context.l10n.learningLoadErrorBody,
                action: FilledButton(
                  onPressed: _retryOpen,
                  child: Text(context.l10n.roomRetry),
                ),
              ),
            ],
          );
        }
        final value = session.value;
        final progress = value?.visible.progressByLesson[lesson.id];
        if (opening.connectionState != ConnectionState.done ||
            progress == null) {
          return StudioPage(
            name: 'Lesson',
            children: [
              LoadingState(
                title: context.l10n.learningLoadingTitle,
                message: context.l10n.learningLoadingBody,
              ),
            ],
          );
        }
        return _buildLesson(context, lesson, progress, value!);
      },
    );
  }

  Widget _buildLesson(
    BuildContext context,
    LearningLesson lesson,
    LessonProgress progress,
    LearningSessionState session,
  ) {
    final current = lesson.steps[progress.currentStepIndex];
    final controller = ref.read(learningSessionProvider.notifier);
    return StudioPage(
      name: 'Lesson-${lesson.id}',
      children: [
        StudioHeading(
          eyebrow: context.l10n.learningLessonProgress(
            progress.currentStepIndex + 1,
            lesson.steps.length,
          ),
          title: context.l10n.learningCopy(lesson.titleKey),
          description: context.l10n.learningCopy(lesson.summaryKey),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var index = 0; index < lesson.steps.length; index++)
              Chip(
                avatar:
                    progress.completedStepIds.contains(lesson.steps[index].id)
                    ? const Icon(Icons.check_rounded, size: 18)
                    : null,
                label: Text(
                  context.l10n.learningCopy(lesson.steps[index].titleKey),
                ),
                backgroundColor: index == progress.currentStepIndex
                    ? context.appColors.primary.withValues(alpha: .12)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (session.saveError != null) ...[
          Semantics(
            liveRegion: true,
            child: StudioCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.l10n.learningSaveError),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(controller.retryVisible),
                    child: Text(context.l10n.learningRetrySave),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        LessonStepView(
          key: ValueKey(current.id),
          lessonId: lesson.id,
          step: current,
        ),
        if (current.kind == LearningStepKind.check) ...[
          const SizedBox(height: AppSpacing.lg),
          for (final question in lesson.questions) ...[
            ConceptQuestionView(
              question: question,
              response: progress.answers[question.id],
              busy: _busy,
              onAnswer: (answerId) => _run(
                () => controller.answerQuestion(
                  lessonId: lesson.id,
                  questionId: question.id,
                  answerId: answerId,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (lesson.questions.every(
            (question) => progress.answers.containsKey(question.id),
          ))
            FilledButton.icon(
              onPressed: _busy || progress.completed
                  ? null
                  : () => _run(() => controller.completeLesson(lesson.id)),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                progress.completed
                    ? context.l10n.learningLessonComplete
                    : context.l10n.learningFinish,
              ),
            ),
          if (progress.completed) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(context.l10n.learningCompletedAnnouncement),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy || progress.currentStepIndex == 0
                    ? null
                    : () => _run(
                        () => controller.setCurrentStep(
                          lesson.id,
                          lesson.steps[progress.currentStepIndex - 1].id,
                        ),
                      ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(context.l10n.learningPrevious),
              ),
            ),
            if (progress.currentStepIndex < lesson.steps.length - 1) ...[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('learning-next-step'),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => controller.setCurrentStep(
                            lesson.id,
                            lesson.steps[progress.currentStepIndex + 1].id,
                          ),
                        ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(context.l10n.learningNext),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        OutlinedButton.icon(
          key: const ValueKey('learning-reset-lesson'),
          onPressed: _busy ? null : _confirmReset,
          icon: const Icon(Icons.restart_alt_rounded),
          label: Text(context.l10n.learningResetLesson),
        ),
      ],
    );
  }
}
