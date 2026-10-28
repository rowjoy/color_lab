import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_learning_repository.dart';

void main() {
  test(
    'provider exposes one shared library and closes its owner on disposal',
    () async {
      final repository = InMemoryLearningRepository();
      final container = ProviderContainer(
        overrides: [
          learningRepositoryProvider.overrideWith((ref) async {
            ref.onDispose(repository.close);
            return repository;
          }),
        ],
      );

      final session = await container.read(learningSessionProvider.future);
      expect(session.visible.progressByLesson, isEmpty);
      expect(container.read(learningLibraryProvider), session.visible);
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(repository.closed, true);
    },
  );
}
