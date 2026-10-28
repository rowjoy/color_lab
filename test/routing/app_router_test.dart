import 'dart:async';
import 'dart:typed_data';

import 'package:color_lab/app.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/games/domain/game_profiles_state.dart';
import 'package:color_lab/features/games/presentation/invalid_game_launch_screen.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/home/presentation/home_screen.dart';
import 'package:color_lab/features/lab/presentation/lab_screen.dart';
import 'package:color_lab/features/learning/presentation/learn_screen.dart';
import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/my_work/presentation/my_work_screen.dart';
import 'package:color_lab/features/onboarding/presentation/onboarding_screen.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/presentation/palette_screen.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/segmentation/room_segmentation_service.dart';
import 'package:color_lab/features/picker/presentation/capture_screen.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_model_setup_controller.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_provider.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_service.dart';
import 'package:color_lab/features/room_studio/recolor/room_photo_recolorer.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';
import 'package:color_lab/features/room_studio/presentation/room_projects_screen.dart';
import 'package:color_lab/features/room_studio/presentation/room_project_open_screen.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_screen.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_gallery_screen.dart';
import 'package:color_lab/features/room_studio/presentation/room_screen.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/shell/presentation/app_shell.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;

import '../support/in_memory_acquisition_intent_store.dart';
import '../support/controlled_room_recolor_worker.dart';
import '../support/in_memory_app_preferences_repository.dart';
import '../support/in_memory_color_history_repository.dart';
import '../support/in_memory_game_profiles_repository.dart';
import '../support/in_memory_learning_repository.dart';
import '../support/in_memory_room_design_repository.dart';
import '../support/in_memory_saved_palette_repository.dart';
import '../support/in_memory_room_project_repository.dart';
import '../support/room_project_fixtures.dart';

void main() {
  for (final single in [false, true]) {
    testWidgets(
      'library Compare opens selected project with ${single ? 'one variant guidance' : 'persisted baseline'} and restores query and Back',
      (tester) async {
        final source = roomProjectFixture(revision: 1);
        final project = single
            ? source.copyWith(
                variants: [source.variants.first],
                comparisonBaselineVariantId: null,
              )
            : source;
        final repo = InMemoryRoomProjectRepository(initial: [project]);
        final original = await _launch(tester, projects: repo);
        original.router.go('/rooms/projects');
        await tester.pumpAndSettle();
        await _tapKey(tester, 'room-project-menu-project-1');
        await tester.pumpAndSettle();
        await _tapKey(tester, 'room-project-compare');
        await _waitForProject(tester);
        expect(original.router.state.uri.queryParameters['compare'], '1');
        expect(
          original.router.state.uri.queryParameters['project'],
          'project-1',
        );
        expect(
          find.byKey(const ValueKey('room-variant-controls')),
          findsOneWidget,
        );
        if (single) {
          expect(
            find.text('Create another variant to compare two color choices.'),
            findsOneWidget,
          );
        } else {
          expect(
            original.container
                .read(roomProjectSessionProvider)!
                .comparisonBaselineVariantId,
            'variant-b',
          );
        }
        final restoration = await tester.getRestorationData();
        await tester.pumpWidget(const SizedBox.shrink());
        original.dispose();
        await tester.restoreFrom(restoration);
        final restored = await _launch(
          tester,
          projects: repo,
          expectedScreen: find.byType(RoomProjectOpenScreen),
        );
        addTearDown(restored.dispose);
        await _waitForProject(tester);
        expect(restored.router.state.uri.queryParameters['compare'], '1');
        expect(
          restored.container.read(roomProjectSessionProvider)!.activeVariantId,
          'variant-a',
        );
        expect(
          restored.container
              .read(roomProjectSessionProvider)!
              .comparisonBaselineVariantId,
          single ? null : 'variant-b',
        );
        expect(await tester.binding.handlePopRoute(), isTrue);
        await tester.pumpAndSettle();
        expect(restored.router.state.uri.path, '/rooms/projects');
      },
    );
  }
  for (final setupId in ['project-1', 'unsafe!']) {
    testWidgets(
      'setup detour owner $setupId cannot bypass permission with a project query',
      (tester) async {
        final picker = _ReplacementPicker();
        final segmenter = _ReplacementAnalysis();
        final harness = await _launch(
          tester,
          projects: InMemoryRoomProjectRepository(
            initial: [roomProjectFixture(revision: 1)],
          ),
          picker: picker,
          segmenter: segmenter,
          setup: _CachedSetup(),
        );
        addTearDown(harness.dispose);
        harness.router.go(
          Uri(
            path: '/room/masks',
            queryParameters: {'setupProject': setupId, 'project': 'project-1'},
          ).toString(),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('room-model-setup')), findsOneWidget);
        expect(find.byType(RoomMaskScreen), findsNothing);
        expect(harness.container.read(roomProjectSessionProvider), isNull);
        expect(picker.requests, 0);
        expect(segmenter.requests, 0);
        await _tapKey(tester, 'room-setup-continue');
        if (setupId == 'project-1') {
          await _waitForProject(tester);
          expect(
            harness.container.read(roomProjectSessionProvider)!.projectId,
            setupId,
          );
        } else {
          await _pumpUntil(
            tester,
            find.byKey(const ValueKey('room-project-open-error')),
          );
          expect(find.byType(RoomMaskScreen), findsNothing);
          expect(harness.container.read(roomProjectSessionProvider), isNull);
        }
        expect(picker.requests, 0);
        expect(segmenter.requests, 0);
      },
    );
  }

  testWidgets(
    'setup detour replacement keeps its saved identity through fresh restoration',
    (tester) async {
      final source = roomProjectFixture(revision: 1);
      final repository = InMemoryRoomProjectRepository(initial: [source]);
      final picker = _ReplacementPicker();
      final segmenter = _ReplacementAnalysis();
      final original = await _launch(
        tester,
        projects: repository,
        picker: picker,
        segmenter: segmenter,
        setup: _CachedSetup(),
      );
      original.router.go('/rooms/project/${source.projectId}');
      await _waitForProject(tester);
      await _tapKey(tester, 'room-mask-gallery');
      await _pumpUntil(tester, find.byKey(const ValueKey('room-model-setup')));
      expect(picker.requests, 0);
      expect(segmenter.requests, 0);
      await _tapKey(tester, 'room-setup-continue');
      await _waitForProject(tester);
      await _tapKey(tester, 'room-mask-gallery');
      await _pumpUntil(
        tester,
        find.byKey(const ValueKey('confirm-room-mask-replace')),
      );
      await _tapKey(tester, 'confirm-room-mask-replace');
      await _waitForSavedReplacement(tester, original, source.projectId);
      final saved = original.container
          .read(roomProjectSessionProvider)!
          .durable!;
      expect(saved.projectId, isNot(source.projectId));
      expect(saved.photoId, isNot(source.photoId));
      expect(saved.revision, 1);
      expect(saved.width, 2);
      expect(saved.height, 1);
      expect(saved.maskBytes, [2, 4]);
      expect(picker.requests, 1);
      expect(segmenter.requests, 1);
      expect(
        original.router.state.uri.queryParameters['project'],
        saved.projectId,
      );

      final restoration = await tester.getRestorationData();
      await tester.pumpWidget(const SizedBox.shrink());
      original.dispose();
      await tester.restoreFrom(restoration);
      final restored = await _launch(
        tester,
        projects: repository,
        picker: picker,
        segmenter: segmenter,
        setup: _CachedSetup(),
        expectedScreen: find.byType(RoomProjectOpenScreen),
      );
      addTearDown(restored.dispose);
      await _waitForProject(tester);
      final reopened = restored.container.read(roomProjectSessionProvider)!;
      expect(
        restored.router.state.uri.queryParameters['project'],
        saved.projectId,
      );
      expect(reopened.projectId, saved.projectId);
      expect(reopened.acknowledgedRevision, 1);
      expect(reopened.visible.photoId, saved.photoId);
      expect(reopened.visible.photo.rgbaBytes, picker.photo.rgbaBytes);
      expect(reopened.visible.masks.labels, [2, 4]);
      expect(reopened.durable!.photoPng, saved.photoPng);
      expect(find.byKey(const ValueKey('room-model-setup')), findsNothing);
      expect(picker.requests, 1);
      expect(segmenter.requests, 1);
    },
  );

  testWidgets(
    'setup detour restored before Continue retains project ownership and permission gate',
    (tester) async {
      final source = roomProjectFixture(revision: 1);
      final repository = InMemoryRoomProjectRepository(initial: [source]);
      final picker = _ReplacementPicker();
      final segmenter = _ReplacementAnalysis();
      final original = await _launch(
        tester,
        projects: repository,
        picker: picker,
        segmenter: segmenter,
        setup: _CachedSetup(),
      );
      original.router.go('/rooms/project/${source.projectId}');
      await _waitForProject(tester);
      await _tapKey(tester, 'room-mask-gallery');
      await _pumpUntil(tester, find.byKey(const ValueKey('room-model-setup')));
      expect(
        original.router.state.uri.queryParameters['setupProject'],
        source.projectId,
      );
      final restoration = await tester.getRestorationData();
      await tester.pumpWidget(const SizedBox.shrink());
      original.dispose();
      await tester.restoreFrom(restoration);
      final restored = await _launch(
        tester,
        projects: repository,
        picker: picker,
        segmenter: segmenter,
        setup: _CachedSetup(),
        expectedScreen: find.byKey(const ValueKey('room-model-setup')),
      );
      addTearDown(restored.dispose);
      await tester.pumpAndSettle();
      expect(
        restored.router.state.uri.queryParameters['setupProject'],
        source.projectId,
      );
      expect(find.byType(RoomMaskScreen), findsNothing);
      expect(picker.requests, 0);
      expect(segmenter.requests, 0);
      await _tapKey(tester, 'room-setup-continue');
      await _waitForProject(tester);
      expect(
        restored.container.read(roomProjectSessionProvider)!.projectId,
        source.projectId,
      );
      expect(
        restored.container.read(roomMaskProvider).draft!.photoId,
        source.photoId,
      );
      expect(picker.requests, 0);
      expect(segmenter.requests, 0);
    },
  );

  for (final useSystemBack in [true, false]) {
    for (final screen in ['library', 'saved', 'opening', 'error']) {
      testWidgets(
        'direct project Back from $screen uses ${useSystemBack ? 'system' : 'visible'} fallback',
        (tester) async {
          final repository = _ReadGateProjects(roomProjectFixture(revision: 1));
          if (screen == 'opening') repository.gate = Completer<void>();
          final harness = await _launch(tester, projects: repository);
          addTearDown(harness.dispose);
          harness.router.go(
            screen == 'library'
                ? '/rooms/projects'
                : '/rooms/project/${screen == 'error' ? 'missing' : 'project-1'}',
          );
          if (screen == 'saved') {
            await _waitForProject(tester);
          } else {
            await tester.pumpAndSettle();
          }
          expect(harness.router.canPop(), isFalse);
          if (screen == 'opening') {
            expect(find.text('Opening room project…'), findsOneWidget);
          }
          if (screen == 'error') {
            expect(
              find.byKey(const ValueKey('room-project-open-error')),
              findsOneWidget,
            );
          }
          if (useSystemBack) {
            expect(await tester.binding.handlePopRoute(), isTrue);
          } else {
            final back = find.byTooltip('Back');
            await tester.ensureVisible(back);
            await tester.tap(back);
          }
          await _pumpUntil(
            tester,
            find.byType(screen == 'library' ? RoomScreen : RoomProjectsScreen),
          );
          expect(
            harness.router.state.uri.path,
            screen == 'library' ? '/rooms' : '/rooms/projects',
          );
          if (repository.gate != null) {
            repository.gate!.complete();
            await tester.pumpAndSettle();
            expect(harness.container.read(roomProjectSessionProvider), isNull);
          }
        },
      );
    }

    testWidgets(
      'pushed project Back uses ${useSystemBack ? 'system' : 'visible'} prior route without double pop',
      (tester) async {
        final harness = await _launch(
          tester,
          projects: InMemoryRoomProjectRepository(
            initial: [roomProjectFixture(revision: 1)],
          ),
        );
        addTearDown(harness.dispose);
        harness.router.go('/my-work');
        await tester.pumpAndSettle();
        harness.router.push('/rooms/projects');
        await tester.pumpAndSettle();
        harness.router.push('/rooms/project/project-1');
        await _waitForProject(tester);
        for (final expected in ['/rooms/projects', '/my-work']) {
          if (useSystemBack) {
            expect(await tester.binding.handlePopRoute(), isTrue);
          } else {
            final back = find.byTooltip('Back');
            await tester.ensureVisible(back);
            await tester.tap(back);
          }
          await tester.pumpAndSettle();
          expect(harness.router.state.uri.path, expected);
        }
      },
    );
  }

  for (final action in ['room-mask-gallery', 'room-mask-refresh']) {
    testWidgets(
      'saved project $action requests setup before new photo analysis',
      (tester) async {
        final project = roomProjectFixture(revision: 1);
        final segmenter = _NoImplicitAnalysis();
        final picker = _NoImplicitPhotoPicker();
        final harness = await _launch(
          tester,
          projects: InMemoryRoomProjectRepository(initial: [project]),
          segmenter: segmenter,
          picker: picker,
        );
        addTearDown(harness.dispose);
        harness.router.go('/rooms/project/${project.projectId}');
        await _waitForProject(tester);
        final draft = harness.container.read(roomMaskProvider).draft;
        expect(segmenter.requests, 0);
        expect(picker.requests, 0);
        final button = find.byKey(ValueKey(action));
        await tester.ensureVisible(button);
        await tester.tap(button);
        await _pumpUntil(
          tester,
          find.byKey(const ValueKey('room-model-setup')),
        );
        expect(find.byKey(const ValueKey('room-model-setup')), findsOneWidget);
        expect(segmenter.requests, 0);
        expect(picker.requests, 0);
        expect(harness.container.read(roomMaskProvider).draft, same(draft));
        expect(
          harness.container.read(roomProjectSessionProvider)!.projectId,
          project.projectId,
        );
      },
    );
  }

  testWidgets('saved-project links still respect onboarding', (tester) async {
    final harness = await _launch(
      tester,
      preferences: const AppPreferences(),
      expectedScreen: find.byType(OnboardingScreen),
    );
    addTearDown(harness.dispose);
    for (final route in [
      '/rooms/projects',
      '/rooms/project/project-1',
      '/room/masks?project=project-1',
    ]) {
      harness.router.go(route);
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/onboarding');
      expect(find.byType(RoomProjectsScreen), findsNothing);
      expect(find.byType(RoomMaskScreen), findsNothing);
    }
  });

  testWidgets(
    'fresh provider container restores saved project URI and editor from storage',
    (tester) async {
      final project = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(initial: [project]);
      final original = await _launch(tester, projects: repo);
      original.router.go('/rooms/project/${project.projectId}');
      await _waitForProject(tester);
      final restoration = await tester.getRestorationData();
      await tester.pumpWidget(const SizedBox.shrink());
      original.dispose();
      await tester.restoreFrom(restoration);
      final restored = await _launch(
        tester,
        projects: repo,
        expectedScreen: find.byType(RoomProjectOpenScreen),
      );
      addTearDown(restored.dispose);
      await _waitForProject(tester);
      expect(restored.router.state.uri.queryParameters['project'], 'project-1');
      expect(
        restored.container
            .read(roomProjectSessionProvider)!
            .acknowledgedRevision,
        1,
      );
      expect(restored.container.read(roomMaskProvider).draft!.masks.labels, [
        1,
        2,
        3,
        4,
      ]);
      expect(find.byKey(const ValueKey('room-model-setup')), findsNothing);
    },
  );

  testWidgets(
    'fresh restoration opens covered project only when Back makes it current',
    (tester) async {
      final project = roomProjectFixture(revision: 1);
      final repo = InMemoryRoomProjectRepository(
        initial: [
          project,
          project.copyWith(projectId: 'other', photoId: 'other-photo'),
        ],
      );
      final original = await _launch(tester, projects: repo);
      original.router.go('/rooms/project/${project.projectId}');
      await _waitForProject(tester);
      original.router.push('/rooms/projects');
      await tester.pumpAndSettle();
      original.router.push('/rooms/project/other');
      await _waitForProject(tester);
      final restoration = await tester.getRestorationData();
      await tester.pumpWidget(const SizedBox.shrink());
      original.dispose();
      await tester.restoreFrom(restoration);
      final restored = await _launch(
        tester,
        projects: repo,
        expectedScreen: find.byType(RoomProjectOpenScreen),
      );
      addTearDown(restored.dispose);
      await _waitForProject(tester);
      expect(
        restored.container.read(roomProjectSessionProvider)!.projectId,
        'other',
      );
      restored.router.pop();
      await tester.pumpAndSettle();
      restored.router.pop();
      await _waitForProject(tester);
      expect(
        restored.container.read(roomProjectSessionProvider)!.projectId,
        project.projectId,
      );
      expect(
        restored.container.read(roomMaskProvider).draft!.photoId,
        project.photoId,
      );
    },
  );

  testWidgets(
    'Back to a retained project route reopens its own saved identity',
    (tester) async {
      final project = roomProjectFixture(revision: 1);
      final harness = await _launch(
        tester,
        projects: InMemoryRoomProjectRepository(
          initial: [
            project,
            project.copyWith(projectId: 'other', photoId: 'other-photo'),
          ],
        ),
      );
      addTearDown(harness.dispose);
      harness.router.go('/rooms/project/${project.projectId}');
      await _waitForProject(tester);
      harness.router.push('/rooms/projects');
      await tester.pumpAndSettle();
      harness.router.push('/rooms/project/other');
      await _waitForProject(tester);
      expect(
        harness.container.read(roomProjectSessionProvider)!.projectId,
        'other',
      );
      harness.router.pop();
      await tester.pumpAndSettle();
      harness.router.pop();
      await _waitForProject(tester);
      expect(
        harness.router.state.uri.queryParameters['project'],
        project.projectId,
      );
      expect(
        harness.container.read(roomProjectSessionProvider)!.projectId,
        project.projectId,
      );
      expect(
        harness.container.read(roomMaskProvider).draft!.photoId,
        project.photoId,
      );
    },
  );

  testWidgets(
    'new project in a saved editor updates restart URI without reopening old photo',
    (tester) async {
      final project = roomProjectFixture(revision: 1);
      final harness = await _launch(
        tester,
        projects: InMemoryRoomProjectRepository(initial: [project]),
      );
      addTearDown(harness.dispose);
      harness.router.go('/rooms/project/${project.projectId}');
      await _waitForProject(tester);
      final draft = harness.container.read(roomMaskProvider).draft!;
      final creating = harness.container
          .read(roomProjectSessionProvider.notifier)
          .createFromAnalysis(
            RoomMaskDraft(
              photoId: 'new-working-photo',
              photo: draft.photo,
              aiMasks: draft.aiMasks,
              masks: draft.masks,
              history: draft.history,
              maskRevision: 0,
              changedFromAiCount: draft.changedFromAiCount,
            ),
          );
      final nextId = harness.container
          .read(roomProjectSessionProvider)!
          .projectId;
      harness.container.read(roomMaskProvider.notifier).continueProject(nextId);
      for (
        var i = 0;
        i < 100 &&
            harness.container.read(roomProjectSessionProvider)!.saveStatus ==
                RoomProjectSaveStatus.saving;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      await creating;
      await _waitForProject(tester);
      expect(harness.router.state.uri.queryParameters['project'], nextId);
      expect(
        harness.container.read(roomMaskProvider).draft!.photoId,
        'new-working-photo',
      );
    },
  );

  testWidgets('Rooms and My Work link to projects with pushed Back', (
    tester,
  ) async {
    final harness = await _launch(tester);
    addTearDown(harness.dispose);
    for (final entry in [
      ('/rooms', 'rooms-open-projects'),
      ('/my-work', 'my-work-open-projects'),
    ]) {
      harness.router.go(entry.$1);
      await tester.pumpAndSettle();
      final link = find.byKey(ValueKey(entry.$2));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(find.byType(RoomProjectsScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('room-model-setup')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('room-projects-back')));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, entry.$1);
    }
  });

  testWidgets(
    'saved deep link opens existing editor without setup and restores identity',
    (tester) async {
      final project = roomProjectFixture(revision: 1);
      final repository = InMemoryRoomProjectRepository(initial: [project]);
      final harness = await _launch(tester, projects: repository);
      addTearDown(harness.dispose);
      harness.router.go('/rooms/projects');
      await tester.pumpAndSettle();
      harness.router.push('/rooms/project/${project.projectId}');
      await _waitForProject(tester);
      expect(harness.router.state.uri.path, '/room/masks');
      expect(
        harness.router.state.uri.queryParameters['project'],
        project.projectId,
      );
      expect(find.byType(RoomMaskScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('room-model-setup')), findsNothing);
      expect(
        harness.container.read(roomProjectSessionProvider)!.durable!.maskBytes,
        project.maskBytes,
      );
      final restoredUri = harness.router.state.uri.toString();
      await tester.restartAndRestore();
      await _waitForProject(tester);
      expect(harness.router.state.uri.toString(), restoredUri);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(RoomProjectsScreen), findsOneWidget);
      await harness.container.read(roomMaskProvider.notifier).closeProject();
      harness.router.go(restoredUri);
      await _waitForProject(tester);
      expect(
        harness.container.read(roomProjectSessionProvider)!.projectId,
        project.projectId,
      );
    },
  );

  testWidgets(
    'Continue retains unsaved draft while other deep link offers safe recovery',
    (tester) async {
      final project = roomProjectFixture(revision: 1);
      final repository = InMemoryRoomProjectRepository(
        initial: [
          project,
          project.copyWith(projectId: 'other'),
        ],
      );
      final harness = await _launch(tester, projects: repository);
      addTearDown(harness.dispose);
      harness.router.go('/rooms/project/${project.projectId}');
      await _waitForProject(tester);
      repository.saveError = const RoomProjectStorageException();
      harness.container
          .read(roomMaskProvider.notifier)
          .setLayerColor(RoomLayer.wall, RgbColor(3, 4, 5));
      await tester.pumpAndSettle();
      final draft = harness.container.read(roomMaskProvider).draft;
      harness.router.go('/rooms/projects');
      await tester.pumpAndSettle();
      final continued = find.byKey(
        ValueKey('room-project-open-${project.projectId}'),
      );
      await tester.ensureVisible(continued);
      expect(
        find.descendant(of: continued, matching: find.text('Continue')),
        findsOneWidget,
      );
      await tester.tap(continued);
      await _waitForProject(tester);
      expect(harness.container.read(roomMaskProvider).draft, same(draft));
      harness.router.go('/rooms/project/other');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('room-project-open-error')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Continue your current project'),
        findsOneWidget,
      );
      expect(harness.container.read(roomMaskProvider).draft, same(draft));
      expect(find.byKey(const ValueKey('room-model-setup')), findsNothing);
    },
  );

  for (final id in ['missing', 'bad', 'unsafe!']) {
    testWidgets('$id saved link has safe error, retry and library recovery', (
      tester,
    ) async {
      final harness = await _launch(tester, projects: _UnreadableProjects());
      addTearDown(harness.dispose);
      harness.router.go('/rooms/project/$id');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('room-project-open-error')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('room-project-open-retry')),
        findsOneWidget,
      );
      expect(find.textContaining('/private'), findsNothing);
      expect(find.byType(RoomMaskScreen), findsNothing);
      expect(find.byKey(const ValueKey('room-model-setup')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('room-project-open-library')));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/rooms/projects');
    });
  }

  for (final route in [
    '/settings/privacy',
    '/settings/data',
    '/settings/licenses',
  ]) {
    testWidgets('$route supports pushed Back and direct-entry Home fallback', (
      tester,
    ) async {
      final harness = await _launch(tester);
      addTearDown(harness.dispose);
      harness.router.push(route);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/home');
      harness.router.go(route);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, '/home');
    });
  }
  testWidgets('completed onboarding lands on Home with exactly four roots', (
    tester,
  ) async {
    _configureView(tester, const Size(599, 800));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    expect(harness.router.state.uri.path, '/home');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(AppDestination.values, [
      AppDestination.home,
      AppDestination.rooms,
      AppDestination.learn,
      AppDestination.games,
    ]);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(4),
    );
    for (final id in ['home', 'rooms', 'learn', 'games']) {
      expect(find.byKey(ValueKey('nav-$id')), findsOneWidget, reason: id);
    }
    for (final removed in ['my-work', 'capture', 'palette', 'lab']) {
      expect(find.byKey(ValueKey('nav-$removed')), findsNothing);
    }

    tester.view.physicalSize = const Size(840, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).destinations,
      hasLength(4),
    );
  });

  testWidgets('Learn branch stack and draft survive switches and live resize', (
    tester,
  ) async {
    _configureView(tester, const Size(599, 800));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await _pumpUntil(tester, find.byType(LearnScreen));
    final openLab = find.byKey(const ValueKey('learn-open-lab'));
    await _pumpUntil(tester, openLab);
    await tester.ensureVisible(openLab);
    await tester.tap(openLab);
    await _pumpUntil(tester, find.byType(LabScreen));
    final slider = tester.widgetList<Slider>(find.byType(Slider)).first;
    slider.onChanged!(123);
    await tester.pump();
    expect(
      tester.widgetList<Slider>(find.byType(Slider)).first.value,
      closeTo(123, .01),
    );

    await tester.tap(find.byKey(const ValueKey('nav-rooms')));
    await _pumpUntil(tester, find.byType(RoomScreen));
    tester.view.physicalSize = const Size(840, 800);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await _pumpUntil(tester, find.byType(LabScreen));
    expect(harness.router.state.uri.path, '/learn/experiment/lab');
    expect(
      tester.widgetList<Slider>(find.byType(Slider)).first.value,
      closeTo(123, .01),
    );

    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await _pumpUntil(tester, find.byType(LearnScreen));
    expect(harness.router.state.uri.path, '/learn');
  });

  testWidgets('My Work is not a fifth tab and system Back returns Home', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    final openMyWork = find.byKey(const ValueKey('home-card-my-work'));
    await tester.ensureVisible(openMyWork);
    await tester.tap(openMyWork);
    await _pumpUntil(tester, find.byType(MyWorkScreen));
    expect(harness.router.state.uri.path, '/my-work');
    expect(find.byKey(const ValueKey('nav-my-work')), findsNothing);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await _pumpUntil(tester, find.byType(HomeScreen));
    expect(harness.router.state.uri.path, '/home');
  });

  testWidgets('My Work visible Back returns to the preceding desktop route', (
    tester,
  ) async {
    _configureView(tester, const Size(1280, 800));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);
    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await _pumpUntil(tester, find.byType(LearnScreen));
    harness.router.push<void>('/my-work');
    await tester.pumpAndSettle();

    final back = find.byKey(const ValueKey('my-work-back'));
    expect(back.hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: back, matching: find.text('Back')),
      findsOneWidget,
    );
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(harness.router.state.uri.path, '/learn');
  });

  testWidgets('My Work direct link has a visible Back fallback to Home', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);
    harness.router.go('/my-work');
    await tester.pumpAndSettle();
    expect(harness.router.canPop(), isFalse);

    await tester.tap(find.byKey(const ValueKey('my-work-back')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(harness.router.state.uri.path, '/home');
  });

  testWidgets(
    'Home Learn card restores Lab stack and draft, then system Back',
    (tester) async {
      _configureView(tester, const Size(390, 844));
      final harness = await _launch(tester);
      addTearDown(harness.dispose);
      await tester.tap(find.byKey(const ValueKey('nav-learn')));
      await tester.pumpAndSettle();
      final openLab = find.byKey(const ValueKey('learn-open-lab'));
      await tester.ensureVisible(openLab);
      await tester.tap(openLab);
      await tester.pumpAndSettle();
      tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(123);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('nav-home')));
      await tester.pumpAndSettle();
      final learnCard = find.byKey(const ValueKey('home-card-learn'));
      await tester.ensureVisible(learnCard);
      await tester.tap(learnCard);
      await tester.pumpAndSettle();

      expect(find.byType(LabScreen), findsOneWidget);
      expect(harness.router.state.uri.path, '/learn/experiment/lab');
      expect(
        tester.widgetList<Slider>(find.byType(Slider)).first.value,
        closeTo(123, .01),
      );
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(LearnScreen), findsOneWidget);
      expect(harness.router.state.uri.path, '/learn');
    },
  );

  testWidgets('fresh router restores active and retained branch stacks', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final original = await _launch(tester);
    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await tester.pumpAndSettle();
    final openLab = find.byKey(const ValueKey('learn-open-lab'));
    await tester.ensureVisible(openLab);
    await tester.tap(openLab);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-rooms')));
    await tester.pumpAndSettle();
    final restoration = await tester.getRestorationData();

    await tester.pumpWidget(const SizedBox.shrink());
    original.dispose();
    await tester.restoreFrom(restoration);
    final restored = await _launch(
      tester,
      expectedScreen: find.byType(RoomScreen),
    );
    addTearDown(restored.dispose);
    expect(identical(restored.router, original.router), isFalse);
    await tester.pumpAndSettle();

    expect(find.byType(RoomScreen), findsOneWidget);
    expect(restored.router.state.uri.path, '/rooms');
    await tester.tap(find.byKey(const ValueKey('nav-learn')));
    await tester.pumpAndSettle();
    expect(find.byType(LabScreen), findsOneWidget);
    expect(restored.router.state.uri.path, '/learn/experiment/lab');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(LearnScreen), findsOneWidget);
    expect(restored.router.state.uri.path, '/learn');
  });

  testWidgets('legacy tool paths and the Room redirect remain valid', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    for (final entry in <String, Finder>{
      '/capture': find.byType(CaptureScreen),
      '/palette': find.byType(PaletteScreen),
      '/lab': find.byType(LabScreen),
      '/room': find.byType(RoomScreen),
      '/room/illustrated': find.byType(IllustratedRoomGalleryScreen),
    }.entries) {
      harness.router.go(entry.key);
      await _pumpUntil(tester, entry.value);
      await tester.pumpAndSettle();
      expect(entry.value, findsOneWidget, reason: entry.key);
      expect(tester.takeException(), isNull, reason: entry.key);
    }
    harness.router.go('/room');
    await _pumpUntil(tester, find.byType(RoomScreen));
    expect(harness.router.state.uri.path, '/rooms');
  });

  testWidgets('direct photo editor route presents optional model setup', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);
    harness.router.go('/room/masks');
    await _pumpUntil(tester, find.byKey(const ValueKey('room-model-setup')));
    expect(harness.router.state.uri.path, '/room/masks');
    expect(find.byKey(const ValueKey('room-mask-gallery')), findsNothing);
    expect(
      find.byKey(const ValueKey('room-setup-illustrated')),
      findsOneWidget,
    );
  });

  testWidgets('invalid and unknown deep links recover safely to Home', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    harness.router.go('/water-sort');
    await _pumpUntil(tester, find.byType(InvalidGameLaunchScreen));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invalid-game-launch')), findsOneWidget);

    harness.router.go('/not-a-real-route');
    await _pumpUntil(tester, find.byKey(const ValueKey('route-unavailable')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Color Lab'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('route-recovery-home')));
    await _pumpUntil(tester, find.byType(HomeScreen));
    expect(harness.router.state.uri.path, '/home');
  });

  testWidgets('router and branches declare stable restoration identities', (
    tester,
  ) async {
    _configureView(tester, const Size(390, 844));
    final harness = await _launch(tester);
    addTearDown(harness.dispose);

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).restorationScopeId,
      'tintatlas-app',
    );
    expect(
      harness.router.routerDelegate.builder.restorationScopeId,
      'tintatlas-router',
    );
    final shell = harness.router.configuration.routes
        .whereType<StatefulShellRoute>()
        .single;
    expect(shell.restorationScopeId, 'tintatlas-shell');
    expect(shell.branches.map((branch) => branch.restorationScopeId), [
      'home-branch',
      'rooms-branch',
      'learn-branch',
      'games-branch',
    ]);
    expect(
      shell.branches.map((branch) => branch.navigatorKey).toSet(),
      hasLength(4),
    );
  });
}

final class _RouterHarness {
  const _RouterHarness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;

  void dispose() => container.dispose();
}

Future<_RouterHarness> _launch(
  WidgetTester tester, {
  Finder? expectedScreen,
  RoomProjectRepository? projects,
  AppPreferences? preferences,
  RoomSegmentationService? segmenter,
  PhotoPickerService? picker,
  RoomModelSetupController? setup,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (setup != null) roomModelSetupProvider.overrideWith(() => setup),
      if (segmenter != null)
        roomSegmentationServiceProvider.overrideWithValue(segmenter),
      if (picker != null) photoPickerServiceProvider.overrideWithValue(picker),
      roomProjectRepositoryProvider.overrideWith(
        (ref) async => projects ?? InMemoryRoomProjectRepository(),
      ),
      roomRecolorPreviewProvider.overrideWithBuild(
        (ref, notifier) => const AsyncData(null),
      ),
      roomRecolorWorkerFactoryProvider.overrideWithValue(
        () => CallbackRecolorWorker(
          (input) async => recolorRoomPhoto(
            key: input.key,
            photo: input.photo,
            masks: input.masks,
            colors: input.colors,
          ),
        ),
      ),
      acquisitionIntentStoreProvider.overrideWith(
        (ref) async => InMemoryAcquisitionIntentStore(),
      ),
      appPreferencesRepositoryProvider.overrideWith(
        (ref) async => InMemoryAppPreferencesRepository(initial: preferences),
      ),
      colorHistoryRepositoryProvider.overrideWith(
        (ref) async => InMemoryColorHistoryRepository(),
      ),
      savedPaletteRepositoryProvider.overrideWith(
        (ref) async => InMemorySavedPaletteRepository(),
      ),
      roomDesignRepositoryProvider.overrideWith(
        (ref) async => InMemoryRoomDesignRepository(),
      ),
      gameProfilesRepositoryProvider.overrideWith(
        (ref) async => InMemoryGameProfilesRepository(
          initialState: GameProfilesState(
            activeProfileId: null,
            profiles: const {},
            legacyMigrationComplete: true,
          ),
        ),
      ),
      learningRepositoryProvider.overrideWith(
        (ref) async => InMemoryLearningRepository(),
      ),
    ],
  );
  await container.read(appPreferencesProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ColorLabApp()),
  );
  final router = container.read(appRouterProvider);
  await _pumpUntil(tester, expectedScreen ?? find.byType(HomeScreen));
  return _RouterHarness(container, router);
}

Future<void> _waitForProject(WidgetTester tester) async {
  for (var frame = 0; frame < 100; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (find.byType(RoomMaskScreen).evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(find.byType(RoomMaskScreen), findsOneWidget);
}

class _UnreadableProjects extends InMemoryRoomProjectRepository {
  @override
  Future<RoomProjectReadResult?> read(String id) async {
    if (id == 'bad') {
      throw const RoomProjectStorageException(
        RoomProjectStorageFailure.corrupt,
      );
    }
    return null;
  }
}

class _NoImplicitAnalysis implements RoomSegmentationService {
  int requests = 0;
  @override
  Future<RoomSegmentationResult> analyze({
    required String photoId,
    required PreparedPhoto photo,
  }) async {
    requests++;
    throw const RoomSegmentationException(
      RoomSegmentationFailureKind.modelUnavailable,
    );
  }

  @override
  Future<void> close() async {}
}

class _NoImplicitPhotoPicker implements PhotoPickerService {
  int requests = 0;
  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async {
    requests++;
    return null;
  }

  @override
  Future<PreparedPhoto?> recoverLost() async => null;
  @override
  Future<bool> openSettings() async => false;
}

class _CachedSetup extends RoomModelSetupController {
  static const progress = RoomModelDownloadProgress(
    stage: RoomModelDownloadStage.idle,
    receivedBytes: 0,
    totalBytes: 68316288,
  );
  @override
  RoomModelSetupState build() => const RoomModelSetupState(progress: progress);
  @override
  Future<void> check() async {
    state = const RoomModelSetupState(
      availability: RoomModelAvailability.ready,
      progress: progress,
    );
  }

  @override
  Future<bool> continueWithCachedModels() async {
    state = const RoomModelSetupState(
      availability: RoomModelAvailability.ready,
      progress: progress,
      canEnter: true,
    );
    return true;
  }
}

class _ReplacementPicker implements PhotoPickerService {
  _ReplacementPicker() {
    final pixels = Uint8List.fromList([10, 20, 30, 255, 40, 50, 60, 255]);
    photo = PreparedPhoto(
      width: 2,
      height: 1,
      rgbaBytes: pixels,
      previewBytes: Uint8List.fromList(
        img.encodePng(
          img.Image.fromBytes(
            width: 2,
            height: 1,
            bytes: pixels.buffer,
            numChannels: 4,
          ),
        ),
      ),
      palette: const [],
    );
  }
  late final PreparedPhoto photo;
  int requests = 0;
  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async {
    requests++;
    return photo;
  }

  @override
  Future<PreparedPhoto?> recoverLost() async => null;
  @override
  Future<bool> openSettings() async => false;
}

class _ReplacementAnalysis implements RoomSegmentationService {
  int requests = 0;
  @override
  Future<RoomSegmentationResult> analyze({
    required String photoId,
    required PreparedPhoto photo,
  }) async {
    requests++;
    return RoomSegmentationResult(
      photoId: photoId,
      masks: MaskBitmap(
        width: 2,
        height: 1,
        labels: Uint8List.fromList([2, 4]),
      ),
    );
  }

  @override
  Future<void> close() async {}
}

class _ReadGateProjects extends InMemoryRoomProjectRepository {
  _ReadGateProjects(RoomProjectSnapshot source) : super(initial: [source]);
  Completer<void>? gate;
  @override
  Future<RoomProjectReadResult?> read(String id) async {
    await gate?.future;
    return super.read(id);
  }
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _waitForSavedReplacement(
  WidgetTester tester,
  _RouterHarness harness,
  String previousId,
) async {
  for (var frame = 0; frame < 150; frame++) {
    await tester.pump(const Duration(milliseconds: 20));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    final session = harness.container.read(roomProjectSessionProvider);
    if (session != null &&
        session.projectId != previousId &&
        session.saveStatus == RoomProjectSaveStatus.saved) {
      return;
    }
  }
  fail('Replacement project did not reach Saved');
}

void _configureView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  for (var frame = 0; frame < 40; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  expect(finder, findsOneWidget);
}
