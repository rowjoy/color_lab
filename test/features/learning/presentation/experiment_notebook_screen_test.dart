import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/learning/domain/learning_library.dart';
import 'package:color_lab/features/learning/presentation/experiment_notebook_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_learning_repository.dart';

void main() {
  ExperimentRecord record() => ExperimentRecord(
    id: 'experiment-one',
    title: 'Warm violet',
    lessonId: 'hue',
    inputHexes: const ['#112233'],
    resultHexes: const ['#AABBCC'],
    snapshot: const FormulaExperimentSnapshot(targetHex: '#112233'),
    observation: 'More blue than red.',
    createdAt: DateTime.utc(2026, 10, 28),
    updatedAt: DateTime.utc(2026, 10, 28),
  );

  Future<void> pumpNotebook(
    WidgetTester tester,
    InMemoryLearningRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learningRepositoryProvider.overrideWith((ref) async => repository),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ExperimentNotebookScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('notebook shows an actionable empty state', (tester) async {
    await pumpNotebook(tester, InMemoryLearningRepository());
    expect(find.text('No saved experiments yet'), findsOneWidget);
    expect(find.text('Open an experiment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notebook lists and deletes a durable experiment', (
    tester,
  ) async {
    final repository = InMemoryLearningRepository(
      initial: LearningLibrary.empty().copyWith(experiments: [record()]),
    );
    await pumpNotebook(tester, repository);
    expect(find.text('Warm violet'), findsOneWidget);
    expect(find.text('More blue than red.'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete experiment'));
    await tester.pumpAndSettle();
    expect(find.text('No saved experiments yet'), findsOneWidget);
  });

  testWidgets('failed delete is visible and retries the retained deletion', (
    tester,
  ) async {
    final repository = InMemoryLearningRepository(
      initial: LearningLibrary.empty().copyWith(experiments: [record()]),
    )..failNextTransaction = true;
    await pumpNotebook(tester, repository);
    final delete = find.byTooltip('Delete experiment');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('learning-notebook-save-error')),
      findsOneWidget,
    );
    expect(find.text('Warm violet'), findsNothing);
    final retry = find.widgetWithText(FilledButton, 'Retry save');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('learning-notebook-save-error')),
      findsNothing,
    );
    expect((await repository.load()).library.experiments, isEmpty);
  });
}
