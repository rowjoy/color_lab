import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../application/experiment_capture_service.dart';
import '../application/learning_providers.dart';
import '../domain/experiment_snapshot.dart';

class LearningExperimentHost extends StatelessWidget {
  const LearningExperimentHost({
    super.key,
    required this.tool,
    required this.child,
    this.lessonId,
  });

  final ExperimentTool tool;
  final Widget child;
  final String? lessonId;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      PositionedDirectional(
        end: 16,
        bottom: 72,
        child: SafeArea(
          child: FloatingActionButton.extended(
            key: const ValueKey('learning-save-experiment'),
            heroTag: 'learning-save-${tool.name}',
            onPressed: () => _save(context),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(context.l10n.learningSaveExperiment),
          ),
        ),
      ),
    ],
  );

  Future<void> _save(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) =>
          _SaveExperimentDialog(tool: tool, lessonId: lessonId),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.learningExperimentSaved)),
      );
    }
  }
}

class _SaveExperimentDialog extends ConsumerStatefulWidget {
  const _SaveExperimentDialog({required this.tool, required this.lessonId});

  final ExperimentTool tool;
  final String? lessonId;

  @override
  ConsumerState<_SaveExperimentDialog> createState() =>
      _SaveExperimentDialogState();
}

class _SaveExperimentDialogState extends ConsumerState<_SaveExperimentDialog> {
  late final TextEditingController _title;
  final _observation = TextEditingController();
  bool _busy = false;
  bool _retryingRetainedDraft = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: '${widget.tool.name} study');
  }

  @override
  void dispose() {
    _title.dispose();
    _observation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _title.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final controller = ref.read(learningSessionProvider.notifier);
      if (_retryingRetainedDraft) {
        await controller.retryVisible();
      } else {
        final capture = ref
            .read(experimentCaptureServiceProvider)
            .capture(widget.tool);
        await controller.saveExperiment(
          title: _title.text,
          lessonId: widget.lessonId,
          snapshot: capture.snapshot,
          results: capture.results,
          observation: _observation.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (mounted) {
        final hasRetainedWrite =
            ref.read(learningSessionProvider).value?.saveError != null;
        setState(() {
          _busy = false;
          _retryingRetainedDraft = hasRetainedWrite;
          _error = context.l10n.learningExperimentSaveFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.learningSaveExperimentTitle),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('learning-experiment-title'),
            controller: _title,
            maxLength: 120,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.l10n.learningExperimentTitleLabel,
            ),
          ),
          TextField(
            key: const ValueKey('learning-experiment-observation'),
            controller: _observation,
            maxLength: 2000,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: context.l10n.learningExperimentObservationLabel,
            ),
          ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Text(_error!, key: const ValueKey('learning-save-error')),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const ValueKey('learning-confirm-save'),
        onPressed: _busy ? null : _submit,
        child: Text(
          _retryingRetainedDraft
              ? context.l10n.learningRetrySave
              : context.l10n.learningSaveExperiment,
        ),
      ),
    ],
  );
}
