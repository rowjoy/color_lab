import 'dart:io';

import 'package:color_lab/data/storage/app_storage_directory.dart';
import 'package:color_lab/data/storage/local_data_manager.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/settings/application/local_data_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/room_project_fixtures.dart';

void main() {
  test(
    'Settings maps roomProjects to its actual file owner beneath color_lab',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'room-owner-provider-',
      );
      final container = ProviderContainer(
        overrides: [
          appStorageDirectoryProvider.overrideWith((ref) async => root),
        ],
      );
      final repository = await container.read(
        roomProjectRepositoryProvider.future,
      );
      try {
        await repository.save(roomProjectFixture(), expectedRevision: 0);
        expect(
          await File(
            '${root.path}/color_lab/room_projects/projects/project-1/current',
          ).exists(),
          true,
        );
        final manager = container.read(localDataManagerProvider);
        const selected = {LocalDataCategory.roomProjects};
        final preview = await manager.preview(selected);
        expect(preview.recordCount, 1);
        expect(preview.revisionCount, 1);
        await manager.delete(selected);
        expect((await repository.listSnapshot()).records, isEmpty);
        expect(
          identical(
            await container.read(roomProjectRepositoryProvider.future),
            repository,
          ),
          true,
        );
      } finally {
        await repository.close();
        container.dispose();
        await root.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'deletion refreshes Room library values without replacing the owner',
    (tester) async {
      final repository = InMemoryRoomProjectRepository(
        initial: [roomProjectFixture(revision: 1)],
      );
      final container = ProviderContainer(
        overrides: [
          roomProjectRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                final projects = ref
                    .watch(roomProjectsProvider)
                    .asData
                    ?.value
                    .records
                    .length;
                return Column(
                  children: [
                    Text('Projects: $projects'),
                    TextButton(
                      onPressed: () async {
                        await repository.delete('project-1');
                        refreshDeletedData(ref, {
                          LocalDataCategory.roomProjects,
                        });
                      },
                      child: const Text('Delete projects'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Projects: 1'), findsOneWidget);
      await tester.tap(find.text('Delete projects'));
      await tester.pumpAndSettle();
      expect(find.text('Projects: 0'), findsOneWidget);
      expect(
        identical(
          container.read(roomProjectRepositoryProvider).requireValue,
          repository,
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      // Drain this fake-clock queue while its owning test zone is still active.
      final closing = repository.close();
      await tester.pump();
      await closing;
    },
  );
}
