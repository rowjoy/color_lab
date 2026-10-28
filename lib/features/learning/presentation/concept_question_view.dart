import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/studio_page.dart';
import '../domain/learning_content.dart';
import '../domain/learning_library.dart';
import 'learning_copy.dart';

class ConceptQuestionView extends StatelessWidget {
  const ConceptQuestionView({
    super.key,
    required this.question,
    required this.response,
    required this.onAnswer,
    this.busy = false,
  });

  final ConceptQuestion question;
  final QuestionResponse? response;
  final ValueChanged<String> onAnswer;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final latest = response?.latest;
    return StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.learningCopy(question.promptKey),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final answer in question.answers) ...[
            OutlinedButton(
              onPressed: busy ? null : () => onAnswer(answer.id),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppTouchTargets.minimum),
                alignment: AlignmentDirectional.centerStart,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.l10n.learningCopy(answer.labelKey)),
                  ),
                  if (latest?.answerId == answer.id)
                    Icon(
                      latest!.correct
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (latest != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(context.l10n.learningCopy(latest.explanationKey)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.learningRetryHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
