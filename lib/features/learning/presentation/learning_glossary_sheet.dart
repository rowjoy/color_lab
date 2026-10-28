import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import 'learning_copy.dart';

class LearningGlossarySheet extends StatelessWidget {
  const LearningGlossarySheet({super.key, required this.copyKeys});

  final List<String> copyKeys;

  static Future<void> show(
    BuildContext context, {
    required Iterable<String> copyKeys,
  }) => AppBottomSheet.show<void>(
    context,
    title: context.l10n.learningGlossary,
    child: LearningGlossarySheet(
      copyKeys: List<String>.unmodifiable(copyKeys.toSet()),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final key in copyKeys) ...[
        Text(context.l10n.learningCopy(key)),
        const SizedBox(height: AppSpacing.lg),
      ],
    ],
  );
}
