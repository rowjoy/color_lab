import 'package:flutter/material.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/studio_page.dart';
import '../domain/experiment_snapshot.dart';

class LearningWorkSection extends StatefulWidget {
  const LearningWorkSection({
    super.key,
    required this.records,
    required this.onOpen,
    required this.onDelete,
    this.onUseInRoom,
    this.onUseInColoring,
  });

  final List<ExperimentRecord> records;
  final ValueChanged<ExperimentRecord> onOpen;
  final Future<void> Function(String experimentId) onDelete;
  final ValueChanged<ExperimentRecord>? onUseInRoom;
  final ValueChanged<ExperimentRecord>? onUseInColoring;

  @override
  State<LearningWorkSection> createState() => _LearningWorkSectionState();
}

class _LearningWorkSectionState extends State<LearningWorkSection> {
  final Set<String> _deleting = {};

  Future<void> _delete(String experimentId) async {
    if (!_deleting.add(experimentId)) return;
    setState(() {});
    try {
      await widget.onDelete(experimentId);
    } on Object {
      // The parent renders the controller's retained visible error and Retry.
    } finally {
      if (mounted) setState(() => _deleting.remove(experimentId));
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final record in widget.records) ...[
        StudioCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science_outlined, color: context.appColors.primary),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: InkWell(
                  onTap: () => widget.onOpen(record),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          context.l10n.learningExperimentTool(
                            record.snapshot.tool.name,
                          ),
                        ),
                        if (record.observation.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(record.observation),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  if (widget.onUseInRoom != null)
                    IconButton(
                      tooltip: context.l10n.learningUseInRoom,
                      onPressed: () => widget.onUseInRoom!(record),
                      icon: const Icon(Icons.meeting_room_outlined),
                    ),
                  if (widget.onUseInColoring != null)
                    IconButton(
                      tooltip: 'Use colors in Coloring Studio',
                      onPressed: () => widget.onUseInColoring!(record),
                      icon: const Icon(Icons.draw_outlined),
                    ),
                  IconButton(
                    tooltip: context.l10n.learningDeleteExperiment,
                    onPressed: _deleting.contains(record.id)
                        ? null
                        : () => _delete(record.id),
                    icon: _deleting.contains(record.id)
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ],
  );
}
