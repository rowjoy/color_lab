import 'dart:typed_data';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/room_design_repository.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_gallery_screen.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_controls.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_screen.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_svg.dart';
import 'package:color_lab/features/room_studio/presentation/room_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/in_memory_room_design_repository.dart';
import '../../../support/in_memory_color_history_repository.dart';

final class _TestNavigation {
  _TestNavigation({required this.color})
    : themeMode = ValueNotifier(ThemeMode.light),
      router = GoRouter(
        initialLocation: '/room',
        routes: [
          ShellRoute(
            builder: (context, state, child) => Scaffold(
              body: child,
              bottomNavigationBar: const SizedBox(
                key: ValueKey('test-shell-bottom-nav'),
                height: 64,
              ),
            ),
            routes: [
              GoRoute(
                path: '/room',
                builder: (context, state) => const RoomScreen(),
              ),
              GoRoute(
                path: '/source',
                builder: (context, state) => _ColorSource(color: color),
              ),
            ],
          ),
          GoRoute(
            path: '/room/masks',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Photo room editor'))),
          ),
          GoRoute(
            path: '/room/study',
            redirect: (context, state) => '/room/illustrated/study',
          ),
          GoRoute(
            path: '/room/illustrated',
            builder: (context, state) => const IllustratedRoomGalleryScreen(),
          ),
          GoRoute(
            path: '/room/illustrated/:templateId',
            builder: (context, state) => IllustratedRoomScreen(
              templateId: state.pathParameters['templateId']!,
            ),
          ),
        ],
      );

  final RgbColor color;
  final ValueNotifier<ThemeMode> themeMode;
  final GoRouter router;

  void dispose() {
    router.dispose();
    themeMode.dispose();
  }
}

class _ColorSource extends StatelessWidget {
  const _ColorSource({required this.color});

  final RgbColor color;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('open-color-details'),
        onPressed: () => showColorDetails(context, color),
        child: const Text('Open color details'),
      ),
    ),
  );
}

final class _RawLoadFailureRepository implements RoomDesignRepository {
  static const rawFailure =
      'FileSystemException: database open failed, path = '
      '/Users/example/Documents/color_lab/room_designs.hive';

  @override
  Future<List<SavedRoomDesign>> load() async => throw StateError(rawFailure);

  @override
  Future<SavedRoomDesign> save({
    String? existingId,
    required String name,
    required String templateId,
    required IllustratedRoomColors colors,
  }) => throw UnsupportedError('save is not used by this test');

  @override
  Future<void> delete(String id) =>
      throw UnsupportedError('delete is not used by this test');

  @override
  Future<void> close() async {}
}

final class _IntegrationArtworkEncoder
    implements IllustratedRoomArtworkEncoder {
  int calls = 0;

  @override
  Future<Uint8List> encodePng(IllustratedRoomDraft draft) async {
    calls++;
    return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  }
}

final class _IntegrationGalleryWriter implements RoomGalleryWriter {
  int calls = 0;
  String? fileName;

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    calls++;
    this.fileName = fileName;
  }
}

Future<_TestNavigation> _pumpApp(
  WidgetTester tester, {
  RgbColor? color,
  RoomDesignRepository? repository,
  IllustratedRoomArtworkEncoder? artworkEncoder,
  RoomGalleryWriter? galleryWriter,
  RoomGallerySettings? gallerySettings,
}) async {
  final navigation = _TestNavigation(
    color: color ?? RgbColor.fromHex('#A7B5A0'),
  );
  addTearDown(navigation.dispose);
  final roomDesignRepository = repository ?? InMemoryRoomDesignRepository();
  addTearDown(roomDesignRepository.close);
  final historyRepository = InMemoryColorHistoryRepository();
  addTearDown(historyRepository.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => historyRepository,
        ),
        colorNamerProvider.overrideWith(
          (ref) async =>
              ColorNamer([NamedColor('Test color', RgbColor(0, 0, 0))]),
        ),
        roomDesignRepositoryProvider.overrideWith(
          (ref) async => roomDesignRepository,
        ),
        roomExportClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 25, 4),
        ),
        if (artworkEncoder != null)
          illustratedRoomArtworkEncoderProvider.overrideWithValue(
            artworkEncoder,
          ),
        if (galleryWriter != null)
          roomGalleryWriterProvider.overrideWithValue(galleryWriter),
        if (gallerySettings != null)
          roomGallerySettingsProvider.overrideWithValue(gallerySettings),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: navigation.themeMode,
        builder: (context, mode, child) => MaterialApp.router(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          routerConfig: navigation.router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return navigation;
}

Future<void> _tapByKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key), skipOffstage: false);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openStudy(WidgetTester tester, _TestNavigation navigation) async {
  navigation.router.go('/room/illustrated/study');
  await tester.pumpAndSettle();
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
  listen: false,
);

Future<void> _withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

void _expectSelectedSemantics(
  WidgetTester tester,
  Finder finder, {
  required String label,
  required bool selected,
}) {
  final data = tester.getSemantics(finder).getSemanticsData();
  expect(data.label.split('\n').first, label);
  expect(data.hasAction(SemanticsAction.tap), isTrue);
  expect(
    data.flagsCollection.isSelected,
    selected ? Tristate.isTrue : Tristate.isFalse,
  );
}

void main() {
  testWidgets(
    'Room keeps photo entry and opens the lazy gallery outside the shell',
    (tester) async {
      await _pumpApp(tester);

      expect(find.byKey(const ValueKey('open-room-masks')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('open-illustrated-gallery')),
        findsOneWidget,
      );
      expect(find.byType(IllustratedRoomSvg), findsNothing);
      expect(
        find.byKey(const ValueKey('test-shell-bottom-nav')),
        findsOneWidget,
      );

      await _tapByKey(tester, 'open-illustrated-gallery');
      expect(find.byType(IllustratedRoomGalleryScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('test-shell-bottom-nav')), findsNothing);

      await _tapByKey(tester, 'room-template-living');
      expect(find.byType(IllustratedRoomScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('test-shell-bottom-nav')), findsNothing);

      await _tapByKey(tester, 'room-editor-back');
      expect(find.byType(IllustratedRoomGalleryScreen), findsOneWidget);
      await _tapByKey(tester, 'room-gallery-back');
      await tester.pumpAndSettle();
      expect(find.byType(RoomScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('test-shell-bottom-nav')),
        findsOneWidget,
      );
    },
  );

  testWidgets('dirty study confirms toolbar and system Back before leaving', (
    tester,
  ) async {
    final navigation = await _pumpApp(tester);
    await _openStudy(tester, navigation);
    final container = _container(tester);
    container
        .read(illustratedRoomProvider.notifier)
        .applyPalette('soft-botanical');
    await tester.pumpAndSettle();

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(IllustratedRoomScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Keep draft'));
    await tester.pumpAndSettle();
    expect(find.byType(IllustratedRoomGalleryScreen), findsOneWidget);
  });

  testWidgets(
    'routed Back dismisses focus flyout and compact rail before exit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigation = await _pumpApp(tester);
      await _openStudy(tester, navigation);
      final container = _container(tester);
      container
          .read(illustratedRoomProvider.notifier)
          .applyPalette('soft-botanical');
      await tester.pumpAndSettle();
      final before = container.read(illustratedRoomProvider).activeDraft!;

      await _tapByKey(tester, 'room-show-color-tools');
      await _tapByKey(tester, 'room-focus-preview');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(navigation.router.state.uri.path, '/room/illustrated/study');
      expect(container.read(illustratedRoomProvider).activeDraft, same(before));

      await _tapByKey(tester, 'room-rail-looks');
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-flyout')), findsNothing);
      expect(navigation.router.state.uri.path, '/room/illustrated/study');
      expect(container.read(illustratedRoomProvider).activeDraft, same(before));

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('room-color-rail')).hitTestable(),
        findsNothing,
      );
      expect(navigation.router.state.uri.path, '/room/illustrated/study');
      expect(container.read(illustratedRoomProvider).activeDraft, same(before));

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft?'), findsOneWidget);
      expect(navigation.router.state.uri.path, '/room/illustrated/study');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'routed colored room saves once without changing route or draft',
    (tester) async {
      final encoder = _IntegrationArtworkEncoder();
      final writer = _IntegrationGalleryWriter();
      final navigation = await _pumpApp(
        tester,
        artworkEncoder: encoder,
        galleryWriter: writer,
      );
      await _openStudy(tester, navigation);
      expect(
        tester
            .widget<IllustratedRoomColorRail>(
              find.byType(IllustratedRoomColorRail),
            )
            .onSaveToGallery,
        isNull,
      );

      await _tapByKey(tester, 'room-rail-looks');
      await _tapByKey(tester, 'room-palette-soft-botanical');
      final container = _container(tester);
      final before = container.read(illustratedRoomProvider).activeDraft!;
      final gallery = find.byKey(
        const ValueKey('room-save-gallery'),
        skipOffstage: false,
      );
      await tester.ensureVisible(gallery);
      await tester.pumpAndSettle();
      await tester.tap(gallery);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Saved to Gallery'), findsOneWidget);
      expect(encoder.calls, 1);
      expect(writer.calls, 1);
      expect(writer.fileName, 'color-lab-study-20261025T040000000Z.png');
      expect(navigation.router.state.uri.path, '/room/illustrated/study');
      expect(container.read(illustratedRoomProvider).activeDraft, same(before));
    },
  );

  testWidgets('theme and route changes retain the current study draft', (
    tester,
  ) async {
    final navigation = await _pumpApp(tester);
    final container = _container(tester);
    container.read(illustratedRoomProvider.notifier).applyPalette('cool-airy');

    await _openStudy(tester, navigation);
    final before = container.read(illustratedRoomProvider).draftFor('study')!;
    expect(before.colors!.wall.hex, '#C7D6DF');

    navigation.themeMode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(
      container.read(illustratedRoomProvider).draftFor('study'),
      same(before),
    );

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Keep draft'));
    await tester.pumpAndSettle();
    await _openStudy(tester, navigation);
    expect(
      container.read(illustratedRoomProvider).draftFor('study'),
      same(before),
    );
  });

  testWidgets(
    'Use in Room preserves legacy color and seeds a complete SVG study',
    (tester) async {
      final selected = RgbColor.fromHex('#123456');
      final navigation = await _pumpApp(tester, color: selected);
      navigation.router.go('/source');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-color-details')));
      await tester.pumpAndSettle();
      final useInRoom = find.text('Use in Room');
      expect(useInRoom, findsOneWidget);
      await tester.ensureVisible(useInRoom);
      await tester.pumpAndSettle();
      await tester.tap(useInRoom);
      await tester.pumpAndSettle();

      expect(navigation.router.state.uri.path, '/room/illustrated/study');
      expect(find.byType(IllustratedRoomScreen), findsOneWidget);
      final container = _container(tester);
      expect(container.read(roomColorProvider), selected);
      final draft = container.read(illustratedRoomProvider).activeDraft!;
      expect(draft.mode, IllustratedRoomVisualMode.colored);
      expect(draft.colors!.wall, selected);
      expect(draft.colors!.ceiling.hex, '#F8F4EB');
      expect(draft.colors!.floor.hex, '#C6AC84');
      expect(draft.colors!.furniture.hex, '#654A39');
      expect(draft.savedDesignId, isNull);
    },
  );

  testWidgets('scene semantics distinguish grayscale from all colored values', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      final navigation = await _pumpApp(tester);
      await _openStudy(tester, navigation);

      const grayscaleLabel = 'Study room, black and white';
      final grayscaleScene = find.bySemanticsLabel(grayscaleLabel);
      expect(grayscaleScene, findsOneWidget);
      expect(
        tester.getSemantics(grayscaleScene),
        matchesSemantics(
          label: grayscaleLabel,
          isImage: true,
          textDirection: TextDirection.ltr,
        ),
      );

      await _tapByKey(tester, 'room-rail-looks');
      await _tapByKey(tester, 'room-palette-soft-botanical');

      const coloredLabel =
          'Study room. Soft Botanical. Wall #B7C5B3. Ceiling #F8F4EB. '
          'Floor #C6AC84. Desk & furniture #654A39.';
      expect(find.bySemanticsLabel(grayscaleLabel), findsNothing);
      expect(find.bySemanticsLabel(coloredLabel), findsOneWidget);
    });
  });

  testWidgets('surface and look selection do not rely on color alone', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      final navigation = await _pumpApp(tester);
      await _openStudy(tester, navigation);

      final wall = find.byKey(
        const ValueKey('room-surface-wall'),
        skipOffstage: false,
      );
      _expectSelectedSemantics(tester, wall, label: 'Wall', selected: false);

      await _tapByKey(tester, 'room-surface-furniture');
      final furniture = find.byKey(
        const ValueKey('room-surface-furniture'),
        skipOffstage: false,
      );
      _expectSelectedSemantics(
        tester,
        furniture,
        label: 'Desk & furniture',
        selected: true,
      );
      _expectSelectedSemantics(tester, wall, label: 'Wall', selected: false);

      await _tapByKey(tester, 'room-rail-looks');
      await _tapByKey(tester, 'room-palette-soft-botanical');
      final palette = find.byKey(
        const ValueKey('room-palette-soft-botanical'),
        skipOffstage: false,
      );
      _expectSelectedSemantics(
        tester,
        palette,
        label: 'Soft Botanical, Recommended',
        selected: true,
      );

      await _tapByKey(tester, 'room-surface-furniture');
      await tester.ensureVisible(furniture);
      await tester.pumpAndSettle();
      _expectSelectedSemantics(
        tester,
        furniture,
        label: 'Desk & furniture, #654A39',
        selected: true,
      );
    });
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('physical sample caveat is reachable in ${theme.name}', (
      tester,
    ) async {
      await _withSemantics(tester, () async {
        final navigation = await _pumpApp(tester);
        navigation.themeMode.value = theme;
        await tester.pumpAndSettle();
        await _openStudy(tester, navigation);

        await _tapByKey(tester, 'room-rail-looks');
        await _tapByKey(tester, 'room-market-guide');
        final caveat = IllustratedRoomCatalog.study.paletteSourceNote;
        final caveatText = find.text(caveat, skipOffstage: false);
        expect(caveatText, findsOneWidget);
        await tester.ensureVisible(caveatText);
        await tester.pumpAndSettle();
        expect(caveatText.hitTestable(), findsOneWidget);
        expect(find.bySemanticsLabel(caveat), findsOneWidget);
      });
    });
  }

  testWidgets('storage failure is a friendly live-region announcement', (
    tester,
  ) async {
    await _withSemantics(tester, () async {
      final navigation = await _pumpApp(
        tester,
        repository: _RawLoadFailureRepository(),
      );
      await _openStudy(tester, navigation);
      await _tapByKey(tester, 'room-open-designs');

      const message = 'Could not load your room designs.';
      final error = find.bySemanticsLabel(message);
      expect(error, findsOneWidget);
      expect(
        tester.getSemantics(error),
        matchesSemantics(
          label: message,
          isLiveRegion: true,
          textDirection: TextDirection.ltr,
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp(r'FileSystemException|/Users/example/')),
        findsNothing,
      );
      expect(
        find.textContaining(RegExp(r'FileSystemException|/Users/example/')),
        findsNothing,
      );
    });
  });
}
