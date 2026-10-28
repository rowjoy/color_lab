import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../shell/presentation/studio_page.dart';
import '../application/experiment_restore_service.dart';
import '../application/learning_providers.dart';
import '../domain/experiment_snapshot.dart';

class LearningExperimentRouteScreen extends ConsumerStatefulWidget {
  const LearningExperimentRouteScreen({super.key, required this.experimentId});

  final String experimentId;

  @override
  ConsumerState<LearningExperimentRouteScreen> createState() =>
      _LearningExperimentRouteScreenState();
}

class _LearningExperimentRouteScreenState
    extends ConsumerState<LearningExperimentRouteScreen> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    scheduleMicrotask(_restore);
  }

  Future<void> _restore() async {
    try {
      final session = await ref.read(learningSessionProvider.future);
      if (!mounted) return;
      ExperimentRecord? record;
      for (final candidate in session.visible.experiments) {
        if (candidate.id == widget.experimentId) {
          record = candidate;
          break;
        }
      }
      if (record == null) throw const ExperimentRestoreException();
      if (!mounted) return;
      final location = await ref
          .read(experimentRestoreServiceProvider)
          .restore(record);
      if (mounted) {
        context.replace(
          record.lessonId == null
              ? location
              : Uri(
                  path: location,
                  queryParameters: {'lesson': record.lessonId},
                ).toString(),
        );
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => StudioPage(
    name: 'LearningExperimentRoute',
    children: [
      if (_failed)
        ErrorState(
          key: const ValueKey('learning-experiment-unavailable'),
          title: context.l10n.routeUnavailableTitle,
          message: context.l10n.routeUnavailableBody,
          action: FilledButton(
            onPressed: () => context.go('/learn/notebook'),
            child: Text(context.l10n.learningOpenNotebook),
          ),
        )
      else
        LoadingState(
          key: const ValueKey('learning-experiment-restoring'),
          title: context.l10n.learningLoadingTitle,
          message: context.l10n.learningLoadingBody,
        ),
    ],
  );
}
