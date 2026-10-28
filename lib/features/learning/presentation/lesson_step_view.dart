import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/studio_page.dart';
import '../domain/learning_content.dart';
import 'learning_copy.dart';
import 'learning_glossary_sheet.dart';

class LessonStepView extends StatefulWidget {
  const LessonStepView({super.key, required this.lessonId, required this.step});

  final String lessonId;
  final LearningStep step;

  @override
  State<LessonStepView> createState() => _LessonStepViewState();
}

class _LessonStepViewState extends State<LessonStepView> {
  double _practiceValue = 50;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final value = _practiceValue.round();
    return StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              context.l10n.learningCopy(step.titleKey),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(context.l10n.learningCopy(step.instructionKey)),
          if (step.kind == LearningStepKind.manipulate) ...[
            const SizedBox(height: AppSpacing.xl),
            Semantics(
              label: context.l10n.learningPracticeValue(value),
              slider: true,
              value: '$value%',
              child: Slider(
                value: _practiceValue,
                min: 0,
                max: 100,
                divisions: 20,
                label: '$value%',
                onChanged: (next) => setState(() => _practiceValue = next),
              ),
            ),
            Text(
              context.l10n.learningPracticeValue(value),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (step.experimentTool case final tool?) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                key: const ValueKey('learning-open-practice-tool'),
                onPressed: () => context.push(
                  Uri(
                    path: '/learn/experiment/${tool.name}',
                    queryParameters: {'lesson': widget.lessonId},
                  ).toString(),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(context.l10n.learningOpenPracticeTool(tool.name)),
              ),
            ],
          ],
          const SizedBox(height: AppSpacing.xl),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.appColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppRadii.small),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.learningNonVisualAlternative,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(context.l10n.learningCopy(step.nonVisualInstructionKey)),
              ],
            ),
          ),
          if (step.glossaryKeys.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => LearningGlossarySheet.show(
                  context,
                  copyKeys: step.glossaryKeys,
                ),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(context.l10n.learningGlossary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
