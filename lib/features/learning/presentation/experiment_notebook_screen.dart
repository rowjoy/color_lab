import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/color/color_models.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/learning_providers.dart';
import '../domain/learning_palette_copy.dart';
import '../../room_studio/presentation/illustrated_room_navigation.dart';
import '../../coloring/presentation/coloring_navigation.dart';
import 'learning_work_section.dart';

class ExperimentNotebookScreen extends ConsumerWidget {
  const ExperimentNotebookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(learningSessionProvider);
    return StudioPage(
      name: 'ExperimentNotebook',
      children: [
        StudioHeading(
          eyebrow: context.l10n.learningSectionMyWork,
          title: context.l10n.learningNotebookTitle,
          description: context.l10n.learningNotebookDescription,
        ),
        session.when(
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
          data: (value) {
            final records = value.visible.experiments;
            final content = records.isEmpty
                ? EmptyState(
                    icon: Icons.science_outlined,
                    title: context.l10n.learningNotebookEmptyTitle,
                    message: context.l10n.learningNotebookEmptyBody,
                    action: FilledButton(
                      onPressed: () => context.go('/learn'),
                      child: Text(context.l10n.learningOpenExperiment),
                    ),
                  )
                : LearningWorkSection(
                    records: records,
                    onOpen: (record) =>
                        context.push('/learn/experiment/${record.id}'),
                    onDelete: ref
                        .read(learningSessionProvider.notifier)
                        .deleteExperiment,
                    onUseInRoom: (record) =>
                        openLearningPaletteInIllustratedRoom(
                          context,
                          LearningPaletteCopy(
                            colors: record.resultHexes.map(RgbColor.fromHex),
                            returnLocation: '/learn/notebook',
                          ),
                        ),
                    onUseInColoring: (record) => openLearningPaletteInColoring(
                      context,
                      LearningPaletteCopy(
                        colors: record.resultHexes.map(RgbColor.fromHex),
                        returnLocation: '/learn/notebook',
                      ),
                    ),
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (value.saveError != null) ...[
                  ErrorState(
                    key: const ValueKey('learning-notebook-save-error'),
                    title: context.l10n.learningSaveError,
                    message: context.l10n.learningExperimentSaveFailed,
                    action: FilledButton(
                      onPressed: value.saving
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(learningSessionProvider.notifier)
                                    .retryVisible();
                              } on Object {
                                // The controller retains the retryable error.
                              }
                            },
                      child: Text(context.l10n.learningRetrySave),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                content,
              ],
            );
          },
        ),
      ],
    );
  }
}
