import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_gallery_screen.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_svg.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/in_memory_app_preferences_repository.dart';
import '../../../support/in_memory_room_design_repository.dart';

final class _GalleryHarness {
  const _GalleryHarness(this.container, this.router);

  final ProviderContainer container;
  final GoRouter router;
}

Future<_GalleryHarness> _pumpGallery(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  List<IllustratedRoomTemplate>? templates,
  InMemoryRoomDesignRepository? repository,
  TextScaler textScaler = TextScaler.noScaling,
  void Function(ProviderContainer container)? beforePump,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final designRepository = repository ?? InMemoryRoomDesignRepository();
  addTearDown(designRepository.close);
  final container = ProviderContainer(
    overrides: [
      roomDesignRepositoryProvider.overrideWith(
        (ref) async => designRepository,
      ),
    ],
  );
  addTearDown(container.dispose);
  beforePump?.call(container);
  final router = GoRouter(
    initialLocation: '/room/illustrated',
    routes: [
      GoRoute(
        path: '/room/illustrated',
        builder: (context, state) =>
            IllustratedRoomGalleryScreen(templates: templates),
      ),
      GoRoute(
        path: '/room/illustrated/:templateId',
        builder: (context, state) => IllustratedRoomScreen(
          templateId: state.pathParameters['templateId']!,
        ),
      ),
      GoRoute(
        path: '/room',
        builder: (context, state) => const Scaffold(body: Text('Room root')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _GalleryHarness(container, router);
}

Finder _key(String value, {bool skipOffstage = false}) =>
    find.byKey(ValueKey(value), skipOffstage: skipOffstage);

Future<void> _revealCard(WidgetTester tester, String templateId) async {
  final card = _key('room-template-$templateId');
  await tester.scrollUntilVisible(
    card,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  expect(card, findsOneWidget);
}

IllustratedRoomTemplate _missingTemplate() => IllustratedRoomTemplate(
  id: 'broken',
  title: 'Broken room',
  summary: 'Test-only unavailable illustration.',
  assetPath: 'assets/rooms/does_not_exist.svg',
  defaultPaletteId: IllustratedRoomCatalog.living.defaultPaletteId,
  palettes: IllustratedRoomCatalog.living.palettes,
  surfaceLabels: IllustratedRoomCatalog.living.surfaceLabels,
  focalPoint: IllustratedRoomCatalog.living.focalPoint,
  paletteReviewLabel: IllustratedRoomCatalog.living.paletteReviewLabel,
  paletteSourceNote: IllustratedRoomCatalog.living.paletteSourceNote,
);

void main() {
  testWidgets('one failed SVG stays isolated and retries only its card', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpGallery(
        tester,
        size: const Size(1024, 768),
        templates: [IllustratedRoomCatalog.living, _missingTemplate()],
      );

      expect(_key('room-template-preview-living'), findsOneWidget);
      expect(_key('room-template-retry-broken'), findsOneWidget);
      expect(find.bySemanticsLabel('Retry'), findsOneWidget);
      expect(_key('room-template-retry-living'), findsNothing);
      final frame = tester.getRect(_key('room-template-preview-broken'));

      await tester.tap(_key('room-template-retry-broken'));
      await tester.pumpAndSettle();
      expect(_key('room-template-retry-broken'), findsOneWidget);
      expect(tester.getRect(_key('room-template-preview-broken')), frame);
      expect(_key('room-template-preview-living'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('phone gallery is lazy, ordered and uses stable 3:2 cards', (
    tester,
  ) async {
    await _pumpGallery(tester);

    expect(find.text('Choose a room'), findsOneWidget);
    expect(
      tester.widget(_key('room-gallery-saved-designs')),
      isA<IconButton>(),
    );
    expect(
      find.text(
        'Start in black & white, then test complete looks or your own colors.',
      ),
      findsOneWidget,
    );
    expect(_key('room-gallery-saved-designs'), findsOneWidget);

    final grid = tester.widget<SliverGrid>(_key('room-template-grid'));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      1,
    );
    expect(_key('room-template-bathroom'), findsNothing);

    for (final template in IllustratedRoomCatalog.all) {
      await _revealCard(tester, template.id);
      final preview = _key('room-template-preview-${template.id}');
      final loading = _key('room-template-loading-${template.id}');
      expect(tester.getSize(preview).aspectRatio, closeTo(1.5, .001));
      expect(tester.getRect(loading), tester.getRect(preview));
    }
  });

  testWidgets('wide gallery uses two columns without changing artwork ratio', (
    tester,
  ) async {
    await _pumpGallery(tester, size: const Size(1024, 768));

    expect(
      tester.widget(_key('room-gallery-saved-designs')),
      isA<TextButton>(),
    );
    final grid = tester.widget<SliverGrid>(_key('room-template-grid'));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    final living = tester.getRect(_key('room-template-living'));
    final bedroom = tester.getRect(_key('room-template-bedroom'));
    final study = tester.getRect(_key('room-template-study'));
    expect(living.top, bedroom.top);
    expect(study.top, greaterThan(living.top));
    expect(
      tester.getSize(_key('room-template-preview-living')).aspectRatio,
      closeTo(1.5, .001),
    );
  });

  testWidgets('phone gallery cards fit every room at 2x text', (tester) async {
    await _pumpGallery(
      tester,
      textScaler: const TextScaler.linear(2),
      beforePump: (container) => container
          .read(illustratedRoomProvider.notifier)
          .applyPalette('soft-botanical'),
    );

    for (final template in IllustratedRoomCatalog.all) {
      await _revealCard(tester, template.id);
      expect(tester.takeException(), isNull);
      if (template.id == IllustratedRoomCatalog.study.id) {
        expect(_key('room-template-draft-study'), findsOneWidget);
      }
    }
  });

  testWidgets('previews stay grayscale while retained colors get Draft badge', (
    tester,
  ) async {
    late IllustratedRoomDraft retained;
    final harness = await _pumpGallery(
      tester,
      beforePump: (container) {
        container
            .read(illustratedRoomProvider.notifier)
            .applyPalette('soft-botanical');
        retained = container.read(illustratedRoomProvider).draftFor('study')!;
      },
    );
    await _revealCard(tester, 'study');

    expect(_key('room-template-draft-study'), findsOneWidget);
    expect(_key('room-template-draft-living'), findsNothing);
    final preview = _key('room-template-preview-study');
    final svg = tester.widget<IllustratedRoomSvg>(
      find.descendant(of: preview, matching: find.byType(IllustratedRoomSvg)),
    );
    expect(svg.draft.mode, IllustratedRoomVisualMode.grayscale);
    expect(svg.fit, BoxFit.cover);
    expect(
      svg.alignment,
      Alignment(
        IllustratedRoomCatalog.study.focalPoint.x,
        IllustratedRoomCatalog.study.focalPoint.y,
      ),
    );
    expect(
      harness.container.read(illustratedRoomProvider).draftFor('study'),
      same(retained),
    );
  });

  testWidgets('cards expose complete semantics and activate dynamic editor', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final harness = await _pumpGallery(tester);
      await _revealCard(tester, 'dining');

      expect(
        find.bySemanticsLabel(
          'Dining room, black-and-white color-testing template',
        ),
        findsOneWidget,
      );
      await tester.tap(_key('room-template-dining'));
      await tester.pumpAndSettle();

      expect(harness.router.state.uri.path, '/room/illustrated/dining');
      expect(
        tester
            .widget<IllustratedRoomScreen>(find.byType(IllustratedRoomScreen))
            .templateId,
        'dining',
      );
      expect(
        harness.container.read(illustratedRoomProvider).activeTemplateId,
        'dining',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Saved designs defaults to All and safely opens exact colors', (
    tester,
  ) async {
    final template = IllustratedRoomCatalog.dining;
    final design = SavedRoomDesign(
      id: 'dining-saved',
      name: 'Evening dining',
      templateId: template.id,
      colors: template.palette('cool-airy').colors,
      createdAt: DateTime.utc(2026, 10, 24),
      updatedAt: DateTime.utc(2026, 10, 25),
    );
    final repository = InMemoryRoomDesignRepository(designs: [design]);
    final harness = await _pumpGallery(tester, repository: repository);

    await tester.tap(_key('room-gallery-saved-designs'));
    await tester.pumpAndSettle();
    expect(find.text('My room designs'), findsOneWidget);
    final allFilter = find.descendant(
      of: _key('room-design-filter-all'),
      matching: find.byType(ChoiceChip),
    );
    expect(tester.widget<ChoiceChip>(allFilter).selected, isTrue);
    await tester.tap(_key('room-design-row-dining-saved'));
    await tester.pumpAndSettle();

    expect(harness.router.state.uri.path, '/room/illustrated/dining');
    final opened = harness.container
        .read(illustratedRoomProvider)
        .draftFor('dining')!;
    expect(opened.savedDesignId, design.id);
    expect(opened.colors, design.colors);
    expect(opened.isDirty, isFalse);

    harness.router.pop();
    await tester.pumpAndSettle();
    await _revealCard(tester, 'dining');
    expect(_key('room-template-draft-dining'), findsOneWidget);
    final preview = _key('room-template-preview-dining');
    final svg = tester.widget<IllustratedRoomSvg>(
      find.descendant(of: preview, matching: find.byType(IllustratedRoomSvg)),
    );
    expect(svg.draft.mode, IllustratedRoomVisualMode.grayscale);
  });

  testWidgets('saved-design conflict Cancel keeps the gallery sheet open', (
    tester,
  ) async {
    final template = IllustratedRoomCatalog.study;
    final design = SavedRoomDesign(
      id: 'study-saved',
      name: 'Stored study',
      templateId: template.id,
      colors: template.palette('cool-airy').colors,
      createdAt: DateTime.utc(2026, 10, 24),
      updatedAt: DateTime.utc(2026, 10, 25),
    );
    final repository = InMemoryRoomDesignRepository(designs: [design]);
    final harness = await _pumpGallery(
      tester,
      repository: repository,
      beforePump: (container) => container
          .read(illustratedRoomProvider.notifier)
          .applyPalette('warm-natural'),
    );
    final before = harness.container.read(illustratedRoomProvider);

    await tester.tap(_key('room-gallery-saved-designs'));
    await tester.pumpAndSettle();
    await tester.tap(_key('room-design-row-study-saved'));
    await tester.pumpAndSettle();
    expect(find.text('Replace this room draft?'), findsOneWidget);
    await tester.tap(_key('room-draft-conflict-cancel'));
    await tester.pumpAndSettle();

    expect(find.text('My room designs'), findsOneWidget);
    expect(harness.router.state.uri.path, '/room/illustrated');
    expect(harness.container.read(illustratedRoomProvider), same(before));

    await tester.tap(_key('room-design-row-study-saved'));
    await tester.pumpAndSettle();
    await tester.tap(_key('room-draft-conflict-replace'));
    await tester.pumpAndSettle();
    expect(find.text('My room designs'), findsNothing);
    expect(harness.router.state.uri.path, '/room/illustrated/study');
    expect(
      harness.container
          .read(illustratedRoomProvider)
          .draftFor('study')!
          .savedDesignId,
      design.id,
    );
  });

  testWidgets('production router registers gallery, six editors and fallback', (
    tester,
  ) async {
    final repository = InMemoryRoomDesignRepository();
    addTearDown(repository.close);
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(),
        ),
        roomDesignRepositoryProvider.overrideWith((ref) async => repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appPreferencesProvider.future);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    router.go('/room/illustrated');
    await tester.pumpAndSettle();
    expect(find.byType(IllustratedRoomGalleryScreen), findsOneWidget);

    for (final template in IllustratedRoomCatalog.all) {
      router.go('/room/illustrated/${template.id}');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IllustratedRoomScreen>(find.byType(IllustratedRoomScreen))
            .templateId,
        template.id,
      );
      expect(
        container.read(illustratedRoomProvider).activeTemplateId,
        template.id,
      );
    }

    router.go('/room/study');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/room/illustrated/study');

    final before = container.read(illustratedRoomProvider);
    router.go('/room/illustrated/not-a-room');
    await tester.pumpAndSettle();
    expect(_key('room-template-unavailable'), findsOneWidget);
    expect(
      container.read(illustratedRoomProvider).draftsByTemplateId,
      before.draftsByTemplateId,
    );
  });
}
