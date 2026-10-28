import 'dart:async';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/in_memory_room_design_repository.dart';

final _now = DateTime.utc(2026, 10, 25, 4);

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.design});

  final SavedRoomDesign design;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextButton(
        key: const ValueKey('start-handoff'),
        onPressed: () =>
            openStudyWallHandoff(context, RgbColor.fromHex('#123456')),
        child: const Text('Use in Room'),
      ),
      TextButton(
        key: const ValueKey('start-saved-design'),
        onPressed: () => openIllustratedSavedDesign(context, design),
        child: const Text('Open saved design'),
      ),
    ],
  );
}

final class _Harness {
  _Harness({required this.repository, required this.design})
    : container = ProviderContainer(
        overrides: [
          roomDesignRepositoryProvider.overrideWith((ref) async => repository),
          roomDesignClockProvider.overrideWithValue(() => _now),
        ],
      ) {
    router = GoRouter(
      initialLocation: '/source',
      routes: [
        GoRoute(
          path: '/source',
          builder: (context, state) =>
              Scaffold(body: _ActionPanel(design: design)),
        ),
        GoRoute(
          path: '/room/illustrated/:templateId',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                Text('Editor ${state.pathParameters['templateId']}'),
                _ActionPanel(design: design),
              ],
            ),
          ),
        ),
      ],
    );
  }

  final InMemoryRoomDesignRepository repository;
  final SavedRoomDesign design;
  final ProviderContainer container;
  late final GoRouter router;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() {
    router.dispose();
    container.dispose();
  }
}

SavedRoomDesign _design({
  String id = 'bedroom-saved',
  String name = 'Quiet bedroom',
  String templateId = 'bedroom',
  IllustratedRoomColors? colors,
}) {
  final template = IllustratedRoomCatalog.maybeById(templateId);
  return SavedRoomDesign(
    id: id,
    name: name,
    templateId: templateId,
    colors: colors ?? template!.defaultPalette.colors,
    createdAt: _now,
    updatedAt: _now,
  );
}

Future<_Harness> _pumpHarness(
  WidgetTester tester, {
  InMemoryRoomDesignRepository? repository,
  SavedRoomDesign? design,
}) async {
  final harness = _Harness(
    repository: repository ?? InMemoryRoomDesignRepository(clock: () => _now),
    design: design ?? _design(),
  );
  addTearDown(harness.dispose);
  addTearDown(harness.repository.close);
  await harness.pump(tester);
  return harness;
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('clean Study handoff seeds the complete look without a prompt', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);

    await _tap(tester, 'start-handoff');

    expect(find.text('Replace this room draft?'), findsNothing);
    expect(harness.router.state.uri.path, '/room/illustrated/study');
    expect(harness.container.read(roomColorProvider).hex, '#123456');
    final draft = harness.container
        .read(illustratedRoomProvider)
        .draftFor('study')!;
    expect(draft.mode, IllustratedRoomVisualMode.colored);
    expect(draft.colors!.wall.hex, '#123456');
    expect(draft.colors!.ceiling.hex, '#B7C2A3');
    expect(draft.colors!.floor.hex, '#78866B');
    expect(draft.colors!.furniture.hex, '#4E5B4A');

    harness.router.pop();
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/source');
  });

  testWidgets('colored dirty handoff Cancel is inert and Replace is explicit', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);
    final controller = harness.container.read(illustratedRoomProvider.notifier);
    controller.applyPalette('soft-linen');
    controller.openTemplate(IllustratedRoomCatalog.living);
    final before = harness.container.read(illustratedRoomProvider);
    final legacyBefore = harness.container.read(roomColorProvider);

    await _tap(tester, 'start-handoff');
    expect(find.text('Replace this room draft?'), findsOneWidget);
    expect(find.text('Save current'), findsOneWidget);
    await _tap(tester, 'room-draft-conflict-cancel');

    expect(harness.container.read(illustratedRoomProvider), same(before));
    expect(harness.container.read(roomColorProvider), legacyBefore);
    expect(harness.router.state.uri.path, '/source');

    await _tap(tester, 'start-handoff');
    await _tap(tester, 'room-draft-conflict-replace');
    expect(harness.router.state.uri.path, '/room/illustrated/study');
    expect(harness.container.read(roomColorProvider).hex, '#123456');
    expect(
      harness.container
          .read(illustratedRoomProvider)
          .draftFor('study')!
          .colors!
          .wall
          .hex,
      '#123456',
    );
  });

  testWidgets('dirty black-and-white target cannot offer Save current', (
    tester,
  ) async {
    final stored = _design(
      id: 'study-stored',
      templateId: 'study',
      colors: IllustratedRoomCatalog.study.defaultPalette.colors,
    );
    final harness = await _pumpHarness(tester);
    final controller = harness.container.read(illustratedRoomProvider.notifier);
    controller.openDesign(stored);
    controller.resetToGrayscale();
    controller.openTemplate(IllustratedRoomCatalog.living);
    final before = harness.container.read(illustratedRoomProvider);

    await _tap(tester, 'start-handoff');

    expect(find.text('Save current'), findsNothing);
    expect(find.byKey(const ValueKey('room-draft-conflict-replace')), findsOne);
    await _tap(tester, 'room-draft-conflict-cancel');
    expect(harness.container.read(illustratedRoomProvider), same(before));
    expect(harness.router.state.uri.path, '/source');
  });

  testWidgets('Save current is durable before the handoff replaces the draft', (
    tester,
  ) async {
    final repository = InMemoryRoomDesignRepository(clock: () => _now);
    final harness = await _pumpHarness(tester, repository: repository);
    final controller = harness.container.read(illustratedRoomProvider.notifier);
    controller.applyPalette('soft-linen');
    final previousColors = harness.container
        .read(illustratedRoomProvider)
        .draftFor('study')!
        .colors;
    controller.openTemplate(IllustratedRoomCatalog.living);

    await _tap(tester, 'start-handoff');
    await _tap(tester, 'room-draft-conflict-save');
    expect(find.text('Save room design'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('room-design-name-input')),
      'Study before handoff',
    );
    await _tap(tester, 'room-confirm-save');

    final saved = (await repository.load()).single;
    expect(saved.name, 'Study before handoff');
    expect(saved.colors, previousColors);
    expect(harness.router.state.uri.path, '/room/illustrated/study');
    final replacement = harness.container
        .read(illustratedRoomProvider)
        .draftFor('study')!;
    expect(replacement.savedDesignId, isNull);
    expect(replacement.colors!.wall.hex, '#123456');
  });

  testWidgets('failed Save current can cancel with every target unchanged', (
    tester,
  ) async {
    final repository = InMemoryRoomDesignRepository(clock: () => _now)
      ..failWrites = true;
    final harness = await _pumpHarness(tester, repository: repository);
    final controller = harness.container.read(illustratedRoomProvider.notifier);
    controller.applyPalette('airy-slate');
    controller.openTemplate(IllustratedRoomCatalog.living);
    final before = harness.container.read(illustratedRoomProvider);
    final legacyBefore = harness.container.read(roomColorProvider);

    await _tap(tester, 'start-handoff');
    await _tap(tester, 'room-draft-conflict-save');
    await tester.enterText(
      find.byKey(const ValueKey('room-design-name-input')),
      'Will not save',
    );
    await _tap(tester, 'room-confirm-save');
    expect(find.text('Could not save your room design.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await repository.load(), isEmpty);
    expect(harness.container.read(illustratedRoomProvider), same(before));
    expect(harness.container.read(roomColorProvider), legacyBefore);
    expect(harness.router.state.uri.path, '/source');
  });

  testWidgets(
    'saved-design conflict Cancel is inert and Replace opens target',
    (tester) async {
      final target = _design();
      final harness = await _pumpHarness(tester, design: target);
      final controller = harness.container.read(
        illustratedRoomProvider.notifier,
      );
      controller.openTemplate(IllustratedRoomCatalog.bedroom);
      controller.applyPalette('airy-slate');
      controller.openTemplate(IllustratedRoomCatalog.living);
      final before = harness.container.read(illustratedRoomProvider);
      final legacyBefore = harness.container.read(roomColorProvider);

      await _tap(tester, 'start-saved-design');
      await _tap(tester, 'room-draft-conflict-cancel');
      expect(harness.container.read(illustratedRoomProvider), same(before));
      expect(harness.container.read(roomColorProvider), legacyBefore);
      expect(harness.router.state.uri.path, '/source');

      await _tap(tester, 'start-saved-design');
      await _tap(tester, 'room-draft-conflict-replace');
      expect(harness.router.state.uri.path, '/room/illustrated/bedroom');
      final opened = harness.container
          .read(illustratedRoomProvider)
          .draftFor('bedroom')!;
      expect(opened.savedDesignId, target.id);
      expect(opened.colors, target.colors);
      expect(opened.isDirty, isFalse);
      expect(harness.container.read(roomColorProvider), legacyBefore);
    },
  );

  testWidgets('Save current reopens the freshly updated same record', (
    tester,
  ) async {
    final stored = _design(
      id: 'study-same',
      name: 'Original study',
      templateId: 'study',
      colors: IllustratedRoomCatalog.study.palette('soft-linen').colors,
    );
    final repository = InMemoryRoomDesignRepository(
      designs: [stored],
      clock: () => _now.add(const Duration(minutes: 1)),
    );
    final harness = await _pumpHarness(
      tester,
      repository: repository,
      design: stored,
    );
    final controller = harness.container.read(illustratedRoomProvider.notifier);
    controller.openDesign(stored);
    controller.setSurfaceColor(
      IllustratedRoomSurface.wall,
      RgbColor.fromHex('#ABCDEF'),
    );

    await _tap(tester, 'start-saved-design');
    await _tap(tester, 'room-draft-conflict-save');
    await tester.enterText(
      find.byKey(const ValueKey('room-design-name-input')),
      'Updated study',
    );
    await _tap(tester, 'room-confirm-save');

    final persisted = (await repository.load()).single;
    expect(persisted.id, stored.id);
    expect(persisted.name, 'Updated study');
    expect(persisted.colors.wall.hex, '#ABCDEF');
    final opened = harness.container
        .read(illustratedRoomProvider)
        .draftFor('study')!;
    expect(opened.savedDesignId, persisted.id);
    expect(opened.savedName, persisted.name);
    expect(opened.colors, persisted.colors);
    expect(opened.isDirty, isFalse);
  });

  testWidgets('editor-to-editor navigation replaces instead of stacking', (
    tester,
  ) async {
    final harness = await _pumpHarness(tester);
    unawaited(harness.router.push<void>('/room/illustrated/living'));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/room/illustrated/living');

    await _tap(tester, 'start-saved-design');
    expect(harness.router.state.uri.path, '/room/illustrated/bedroom');

    harness.router.pop();
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/source');
  });

  testWidgets('unavailable saved design does not mutate state or route', (
    tester,
  ) async {
    final unknown = _design(
      id: 'future-design',
      templateId: 'future-room',
      colors: IllustratedRoomCatalog.study.defaultPalette.colors,
    );
    final harness = await _pumpHarness(tester, design: unknown);
    final before = harness.container.read(illustratedRoomProvider);

    await _tap(tester, 'start-saved-design');

    expect(harness.container.read(illustratedRoomProvider), same(before));
    expect(harness.router.state.uri.path, '/source');
  });
}
