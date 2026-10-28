import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/learning/presentation/learning_experiment_host.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_learning_repository.dart';

void main() {
  testWidgets('user saves current state and retries the same failed draft', (
    tester,
  ) async {
    final repository = InMemoryLearningRepository()..failNextTransaction = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LearningExperimentHost(
            tool: ExperimentTool.lab,
            lessonId: 'hue',
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('learning-save-experiment')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('learning-experiment-title')),
      'My hue study',
    );
    await tester.enterText(
      find.byKey(const ValueKey('learning-experiment-observation')),
      'A labeled observation',
    );
    await tester.tap(find.byKey(const ValueKey('learning-confirm-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('learning-save-error')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry save'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learning-confirm-save')));
    await tester.pumpAndSettle();

    final loaded = await repository.load();
    expect(loaded.library.experiments, hasLength(1));
    expect(loaded.library.experiments.single.title, 'My hue study');
    expect(loaded.library.experiments.single.lessonId, 'hue');
    expect(
      loaded.library.experiments.single.observation,
      'A labeled observation',
    );
    expect(find.text('Experiment saved to your Notebook.'), findsOneWidget);
  });
}
