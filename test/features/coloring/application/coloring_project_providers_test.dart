import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/coloring/application/coloring_project_providers.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_coloring_project_repository.dart';

void main() {
  test(
    'workspace reopen reads committed state and library receives acknowledgements',
    () async {
      final original = ColoringProject.create(
        drawingId: 'fruit_red_apple',
        drawingRevision: 1,
        mode: ColoringMode.free,
      );
      final repository = InMemoryColoringProjectRepository([original]);
      final container = ProviderContainer(
        overrides: [
          coloringProjectRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });

      final firstOpen = await container.read(
        coloringProjectProvider(original.id).future,
      );
      expect(firstOpen!.assignments, isEmpty);

      final acknowledged = original.fill(
        'apple-body',
        RgbColor.fromHex('#123456'),
      );
      await repository.save(acknowledged);
      container.invalidate(coloringProjectProvider(original.id));
      final reopened = await container.read(
        coloringProjectProvider(original.id).future,
      );
      expect(reopened!.assignments['apple-body']?.hex, '#123456');

      await container.read(coloringProjectsProvider.future);
      final later = acknowledged.fill(
        'apple-leaf',
        RgbColor.fromHex('#4F8A4C'),
      );
      container
          .read(coloringProjectsProvider.notifier)
          .publishAcknowledged(later);
      expect(
        container
            .read(coloringProjectsProvider)
            .requireValue
            .single
            .assignments['apple-leaf']
            ?.hex,
        '#4F8A4C',
      );
    },
  );
}
