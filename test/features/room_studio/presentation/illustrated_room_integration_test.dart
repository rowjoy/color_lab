import 'package:color_lab/l10n/generated/app_localizations_en.dart';
import '../../../support/room_png_fixtures.dart';
import '../../../support/illustrated_room_test_export_service.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/data/schema/repository_snapshot.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_draft_store.dart';
import 'package:color_lab/features/room_studio/domain/recoverable_room_draft.dart';
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
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/in_memory_room_design_repository.dart';
import '../../../support/in_memory_color_history_repository.dart';

class _LongRoomLocalizations extends AppLocalizationsEn {
  static const long =
      'A deliberately extended translated label for a small screen';
  @override
  String get roomEditFlow => '$long: choose, change and save';
  @override
  String get roomChooseLook => '$long: choose a complete look';
  @override
  String get roomChangeSurface => '$long: change one surface';
  @override
  String get roomApplyCompleteLook => '$long: apply the complete look';
  @override
  String get roomSave => '$long: save';
  @override
  String get roomSaveCopy => '$long: save a copy';
  @override
  String get roomMyDesigns => '$long: my designs';
  @override
  String get roomUndo => '$long: undo';
  @override
  String get roomRedo => '$long: redo';
  @override
  String get roomDesk => '$long: desk';
  @override
  String get roomFurniture => '$long: furniture';
  @override
  String roomSelectedSurface(String name) => '$long: selected $name';
  @override
  String get illustratedPaletteQuietSageName => '$long: Quiet Sage';
}

class _LongRoomDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _LongRoomDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(_LongRoomLocalizations());
  @override
  bool shouldReload(_LongRoomDelegate old) => false;
}

bool _focusedWithin(String key) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  var found = context.widget.key == ValueKey(key);
  context.visitAncestorElements((element) {
    if (element.widget.key == ValueKey(key)) found = true;
    return !found;
  });
  return found;
}

Future<void> _keyboardActivate(
  WidgetTester tester,
  String key, {
  bool space = false,
}) async {
  for (var step = 0; step < 100 && !_focusedWithin(key); step++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
  }
  expect(_focusedWithin(key), isTrue, reason: 'Tab traversal must reach $key');
  await tester.sendKeyEvent(
    space ? LogicalKeyboardKey.space : LogicalKeyboardKey.enter,
  );
  await tester.pumpAndSettle();
}

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
  Future<RepositorySnapshot<SavedRoomDesign>> loadSnapshot() async =>
      throw StateError(rawFailure);

  @override
  Future<List<SavedRoomDesign>> load() =>
      loadSnapshot().then((snapshot) => snapshot.records);

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

  // This read-failure boundary never reaches editing or draft persistence.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Mutation is not used by this test');
}

final class _IntegrationArtworkEncoder
    implements IllustratedRoomArtworkEncoder {
  int calls = 0;

  @override
  Future<Uint8List> encodePng(IllustratedRoomDraft draft) async {
    calls++;
    return roomPng();
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
  Future<IllustratedRoomDraftStore>? draftStore,
  MediaQueryData? media,
  TextDirection direction = TextDirection.ltr,
  LocalizationsDelegate<AppLocalizations>? localizationDelegate,
  Future<RoomDesignRepository> Function()? repositoryFactory,
  bool disposeRepository = true,
}) async {
  final navigation = _TestNavigation(
    color: color ?? RgbColor.fromHex('#A7B5A0'),
  );
  addTearDown(navigation.dispose);
  final roomDesignRepository = repository ?? InMemoryRoomDesignRepository();
  if (disposeRepository) addTearDown(roomDesignRepository.close);
  final historyRepository = InMemoryColorHistoryRepository();
  addTearDown(historyRepository.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (draftStore != null)
          illustratedRoomDraftStoreProvider.overrideWith((ref) => draftStore),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => historyRepository,
        ),
        colorNamerProvider.overrideWith(
          (ref) async =>
              ColorNamer([NamedColor('Test color', RgbColor(0, 0, 0))]),
        ),
        roomDesignRepositoryProvider.overrideWith(
          (ref) async => repositoryFactory == null
              ? roomDesignRepository
              : await repositoryFactory(),
        ),
        roomExportClockProvider.overrideWithValue(
          () => DateTime.utc(2026, 10, 25, 4),
        ),
        if (artworkEncoder != null)
          illustratedRoomArtworkEncoderProvider.overrideWithValue(
            artworkEncoder,
          ),
        if (galleryWriter != null)
          roomImageExportServiceProvider.overrideWithValue(
            IllustratedRoomTestExportService(galleryWriter),
          ),
        if (gallerySettings != null)
          roomGallerySettingsProvider.overrideWithValue(gallerySettings),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: navigation.themeMode,
        builder: (context, mode, child) => MaterialApp.router(
          localizationsDelegates: [
            ?localizationDelegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          routerConfig: navigation.router,
          builder: (context, child) => Directionality(
            textDirection: direction,
            child: media == null
                ? child!
                : MediaQuery(data: media, child: child!),
          ),
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
  // Mutation: invalidating the failed store alone reuses a failed repository
  // factory, or reloading replaces the queue/session with the old durable draft.
  testWidgets(
    'Task5 review: initial repository factory Retry preserves latest queued edits',
    (tester) async {
      final repository = InMemoryRoomDesignRepository();
      var unavailable = true;
      final navigation = await _pumpApp(
        tester,
        repository: repository,
        repositoryFactory: () async {
          if (unavailable) throw const RoomDesignStorageException();
          return repository;
        },
      );
      await _openStudy(tester, navigation);
      final container = _container(tester);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.setRegionColor('desk', RgbColor.fromHex('#123456'));
      controller.setRegionColor('desk', RgbColor.fromHex('#ABCDEF'));
      final latest = container.read(illustratedRoomProvider).activeDraft;
      unavailable = false;
      await _tapByKey(tester, 'room-draft-retry');
      expect(container.read(illustratedRoomProvider).activeDraft, same(latest));
      expect(
        (await repository.loadDraftSnapshot())
            .records
            .single
            .visible!
            .regionOverrides,
        {'desk': '#ABCDEF'},
      );
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  for (final deletion in [false, true]) {
    // Mutation: library edits leave an unopened template's loaded store stale,
    // or raw reconciliation destroys the dirty/pinned snapshot on late resume.
    testWidgets(
      'Task5 review: loaded store late-open identity follows ${deletion ? 'delete' : 'rename'}',
      (tester) async {
        final repository = InMemoryRoomDesignRepository();
        final savedSnapshot = RoomDesignSnapshot.fromColors(
          IllustratedRoomCatalog.bedroom.defaultPalette.colors,
        );
        final saved = await repository.saveNew(
          name: 'Original',
          templateId: 'bedroom',
          snapshot: savedSnapshot,
        );
        final dirtySnapshot = RoomDesignSnapshot(
          groupColors: {...savedSnapshot.groupColors, 'walls': '#123456'},
        );
        final record = RecoverableRoomDraft(
          templateId: 'bedroom',
          visible: dirtySnapshot,
          activeBaseline: dirtySnapshot,
          savedSnapshot: savedSnapshot,
          savedDesignId: saved.id,
          savedName: saved.name,
          updatedAt: DateTime.utc(2026, 1, 1),
        );
        await repository.saveDraft(record);
        final navigation = await _pumpApp(tester, repository: repository);
        await _openStudy(tester, navigation);
        final container = _container(tester);
        final controller = container.read(illustratedRoomProvider.notifier);
        if (deletion) {
          await controller.deleteDesign(saved.id);
        } else {
          await controller.renameDesign(saved.id, 'Renamed');
        }
        final store = await container.read(
          illustratedRoomDraftStoreProvider.future,
        );
        expect(
          store.acknowledgedFor('bedroom')!.savedName,
          deletion ? null : 'Renamed',
        );
        controller.openTemplate(IllustratedRoomCatalog.bedroom);
        await tester.pumpAndSettle();
        final restored = container.read(illustratedRoomProvider).activeDraft!;
        expect(restored.savedName, deletion ? null : 'Renamed');
        expect(restored.savedDesignId, deletion ? null : saved.id);
        expect(restored.assignments!.groupColors['walls']!.hex, '#123456');
        expect(restored.pinnedBaseline!.groupColors['walls']!.hex, '#123456');
        expect(restored.isDirty, isTrue);
        expect(
          (await repository.loadDraftSnapshot()).records.single.toMap(),
          deletion
              ? {
                  ...record.toMap(),
                  'savedDesignId': null,
                  'savedName': null,
                  'savedSnapshot': null,
                }
              : {...record.toMap(), 'savedName': 'Renamed'},
        );
      },
    );
  }

  for (final storeFirst in [false, true]) {
    for (final futureRevision in [false, true]) {
      // Mutation: only initial arrival catches restore errors, or subsequent
      // autosave overwrites an unsupported record. Preserve the exact raw map.
      testWidgets(
        'Task5 review: unsupported recovery preserves bytes storeFirst=$storeFirst revision=$futureRevision',
        (tester) async {
          final repository = InMemoryRoomDesignRepository();
          final snapshot = RoomDesignSnapshot(
            groupColors: const {
              'walls': '#123456',
              'ceiling': '#ABCDEF',
              'floor': '#010203',
              'furniture': '#FFEEDD',
            },
            regionOverrides: futureRevision
                ? const {}
                : const {'unknown-region': '#112233'},
          );
          final record = RecoverableRoomDraft(
            templateId: 'bedroom',
            templateRevision: futureRevision ? 2 : 1,
            visible: snapshot,
            activeBaseline: snapshot,
            savedSnapshot: null,
            savedDesignId: null,
            savedName: null,
            updatedAt: DateTime.utc(2026, 1, 1),
          );
          await repository.saveDraft(record);
          await repository.saveDraft(
            RecoverableRoomDraft.fromDraft(
              IllustratedRoomDraft.grayscale(
                IllustratedRoomCatalog.study,
              ).setRegionColor('desk', RgbColor.fromHex('#654321')),
              updatedAt: DateTime.utc(2026, 1, 1),
            ),
          );
          final store = IllustratedRoomDraftStore(repository);
          await store.load();
          addTearDown(store.dispose);
          final gate = Completer<IllustratedRoomDraftStore>();
          if (storeFirst) gate.complete(store);
          final navigation = await _pumpApp(
            tester,
            repository: repository,
            draftStore: gate.future,
          );
          await _openStudy(tester, navigation);
          navigation.router.go('/room/illustrated/bedroom');
          await tester.pumpAndSettle();
          if (!storeFirst) {
            gate.complete(store);
            await tester.pumpAndSettle();
          }
          final container = _container(tester);
          expect(tester.takeException(), isNull);
          expect(
            container
                .read(illustratedRoomProvider)
                .draftFor('bedroom')!
                .assignments,
            isNull,
          );
          expect(
            container
                .read(illustratedRoomProvider)
                .draftFor('study')!
                .assignments!
                .colorFor('desk')
                .hex,
            '#654321',
          );
          expect(find.textContaining('newer app version'), findsOneWidget);
          expect(find.byKey(const ValueKey('room-draft-retry')), findsNothing);
          container
              .read(illustratedRoomProvider.notifier)
              .setGroupColor('walls', RgbColor.fromHex('#FFFFFF'));
          await tester.pumpAndSettle();
          expect(
            (await repository.loadDraftSnapshot()).records
                .singleWhere((r) => r.templateId == 'bedroom')
                .toMap(),
            record.toMap(),
          );
        },
      );
    }
  }

  // Mutation: fixed-height or single-line controls clip translated labels at
  // 200%, or translation delegates fail to reach the actual editor widgets.
  testWidgets(
    'Task5 review: long localized flow completes at 320x568 and 200 percent',
    (tester) async {
      const size = Size(320, 568);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final navigation = await _pumpApp(
        tester,
        localizationDelegate: const _LongRoomDelegate(),
        media: const MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(2),
        ),
      );
      await _openStudy(tester, navigation);
      await _tapByKey(tester, 'room-edit-flow');
      final words = _LongRoomLocalizations();
      expect(find.text(words.roomEditFlow), findsOneWidget);
      expect(find.text(words.illustratedPaletteQuietSageName), findsOneWidget);
      await _tapByKey(tester, 'room-flow-look-quiet-sage');
      await _tapByKey(tester, 'room-apply-complete-look');
      await _tapByKey(tester, 'room-region-desk');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('room-flow-scroll')),
          matching: find.text(words.roomSelectedSurface(words.roomDesk)),
        ),
        findsOneWidget,
      );
      await _tapByKey(tester, 'room-region-color-ECE9DF');
      await _tapByKey(tester, 'room-undo');
      await _tapByKey(tester, 'room-redo');
      await _tapByKey(tester, 'room-flow-save');
      await _tapByKey(tester, 'room-confirm-save');
      await _tapByKey(tester, 'room-my-designs');
      expect(find.byKey(const ValueKey('room-design-list')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  // Mutation: keyboard focus skips a control or modal restoration fails; apply
  // acts on preview, a region edit changes neighbors, history loses an override,
  // or Save persists an older snapshot. No taps/requestFocus/ensureVisible here.
  testWidgets(
    'Task5 review: external keyboard completes editor workflow and restores modal focus',
    (tester) async {
      final repository = InMemoryRoomDesignRepository();
      final navigation = await _pumpApp(tester, repository: repository);
      await _openStudy(tester, navigation);
      final container = _container(tester);
      final before = container.read(illustratedRoomProvider).activeDraft!;
      await _keyboardActivate(tester, 'room-edit-flow');
      await _keyboardActivate(tester, 'room-flow-look-quiet-sage', space: true);
      expect(container.read(illustratedRoomProvider).activeDraft, same(before));
      expect((await repository.loadDraftSnapshot()).records, isEmpty);
      await _keyboardActivate(tester, 'room-apply-complete-look');
      final look = container
          .read(illustratedRoomProvider)
          .activeDraft!
          .assignments!;
      expect(look.groupColors.map((k, v) => MapEntry(k, v.hex)), {
        'walls': '#ECE9DF',
        'ceiling': '#B7C2A3',
        'floor': '#78866B',
        'furniture': '#4E5B4A',
      });
      await _keyboardActivate(tester, 'room-region-desk', space: true);
      await _keyboardActivate(tester, 'room-region-color-ECE9DF');
      final edited = container
          .read(illustratedRoomProvider)
          .activeDraft!
          .assignments!;
      expect(edited.regionOverrides.map((k, v) => MapEntry(k, v.hex)), {
        'desk': '#ECE9DF',
      });
      expect(edited.colorFor('chair').hex, '#4E5B4A');
      expect(edited.colorFor('shelves').hex, '#4E5B4A');
      await _keyboardActivate(tester, 'room-undo');
      expect(
        container.read(illustratedRoomProvider).activeDraft!.assignments,
        look,
      );
      await _keyboardActivate(tester, 'room-redo', space: true);
      expect(
        container.read(illustratedRoomProvider).activeDraft!.assignments,
        edited,
      );
      await _keyboardActivate(tester, 'room-flow-save');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_focusedWithin('room-flow-save'), isTrue);
      await _keyboardActivate(tester, 'room-flow-save');
      await _keyboardActivate(tester, 'room-confirm-save');
      final saved = (await repository.load()).single;
      expect(saved.snapshot.regionOverrides, {'desk': '#ECE9DF'});
      expect(saved.snapshot.groupColors, {
        'walls': '#ECE9DF',
        'ceiling': '#B7C2A3',
        'floor': '#78866B',
        'furniture': '#4E5B4A',
      });
      expect(
        container.read(illustratedRoomProvider).activeDraft!.savedDesignId,
        saved.id,
      );
      await _keyboardActivate(tester, 'room-my-designs');
      expect(find.byKey(const ValueKey('room-design-list')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_focusedWithin('room-my-designs'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_focusedWithin('room-edit-flow'), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  // Mutation: selecting a look writes assignments/history or a durable draft
  // before confirmation; cancel and preview must leave the exact object intact.
  testWidgets(
    'look preview is nonmutating until explicit Apply Complete Look',
    (tester) async {
      final repository = InMemoryRoomDesignRepository();
      final navigation = await _pumpApp(tester, repository: repository);
      await _openStudy(tester, navigation);
      final container = _container(tester);
      final before = container.read(illustratedRoomProvider).activeDraft;
      await _tapByKey(tester, 'room-rail-looks');
      await _tapByKey(tester, 'room-palette-quiet-sage');
      expect(container.read(illustratedRoomProvider).activeDraft, same(before));
      expect((await repository.loadDraftSnapshot()).records, isEmpty);
      await _tapByKey(tester, 'room-flyout-close');
      expect(container.read(illustratedRoomProvider).activeDraft, same(before));
      await _tapByKey(tester, 'room-rail-looks');
      await _tapByKey(tester, 'room-palette-quiet-sage');
      await _tapByKey(tester, 'room-apply-complete-look');
      expect(
        container.read(illustratedRoomProvider).activeDraft!.colors!.wall.hex,
        '#ECE9DF',
      );
      expect(
        (await repository.loadDraftSnapshot()).records.single
            .restore(IllustratedRoomCatalog.study)
            .colors!
            .wall
            .hex,
        '#ECE9DF',
      );
    },
  );

  // Mutation: Save a Copy takes its predecessor's stored colors, or region
  // editing changes the furniture group, or Undo/Redo lose exact overrides.
  testWidgets(
    'list flow edits one region and saves the visible draft as an independent copy',
    (tester) async {
      final repository = InMemoryRoomDesignRepository();
      final navigation = await _pumpApp(tester, repository: repository);
      await _openStudy(tester, navigation);
      final container = _container(tester);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.applyPalette('quiet-sage');
      final original = await controller.saveDesign('Original');
      await tester.pumpAndSettle();
      await _tapByKey(tester, 'room-edit-flow');
      await _tapByKey(tester, 'room-region-desk');
      await _tapByKey(tester, 'room-region-color-ECE9DF');
      final edited = container.read(illustratedRoomProvider).activeDraft!;
      expect(edited.assignments!.colorFor('desk').hex, '#ECE9DF');
      expect(edited.assignments!.colorFor('chair').hex, '#4E5B4A');
      await _tapByKey(tester, 'room-undo');
      expect(
        container
            .read(illustratedRoomProvider)
            .activeDraft!
            .assignments!
            .colorFor('desk')
            .hex,
        '#4E5B4A',
      );
      await _tapByKey(tester, 'room-redo');
      expect(
        container.read(illustratedRoomProvider).activeDraft!.assignments,
        edited.assignments,
      );
      await _tapByKey(tester, 'room-save-copy');
      await tester.enterText(
        find.byKey(const ValueKey('room-design-name-input')),
        'Visible copy',
      );
      await _tapByKey(tester, 'room-confirm-save');
      final designs = await repository.load();
      expect(designs, hasLength(2));
      expect(
        designs
            .singleWhere((d) => d.id == original.id)
            .snapshot
            .regionOverrides,
        isEmpty,
      );
      final copy = designs.singleWhere((d) => d.name == 'Visible copy');
      expect(copy.snapshot.regionOverrides, {'desk': '#ECE9DF'});
      expect(copy.id, isNot(original.id));
      await _tapByKey(tester, 'room-my-designs');
      expect(find.text('Visible copy'), findsWidgets);
    },
  );

  // Mutation: store changes fail to rebuild the status, failed retain silently
  // drops visible work, or Retry saves an old snapshot.
  testWidgets(
    'draft recovery status and explicit Retry retain the latest edit',
    (tester) async {
      final repository = InMemoryRoomDesignRepository();
      await repository.saveDraft(
        RecoverableRoomDraft.fromDraft(
          IllustratedRoomDraft.grayscale(
            IllustratedRoomCatalog.study,
          ).setRegionColor('chair', RgbColor.fromHex('#123456')),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      final navigation = await _pumpApp(tester, repository: repository);
      await _openStudy(tester, navigation);
      final container = _container(tester);
      expect(
        container
            .read(illustratedRoomProvider)
            .activeDraft!
            .assignments!
            .colorFor('chair')
            .hex,
        '#123456',
      );
      await _tapByKey(tester, 'room-edit-flow');
      repository.writeGate = Completer<void>();
      container
          .read(illustratedRoomProvider.notifier)
          .setRegionColor('desk', RgbColor.fromHex('#654321'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      repository.failWrites = true;
      repository.writeGate!.complete();
      await tester.pumpAndSettle();
      await _tapByKey(tester, 'room-draft-retry');
      expect(
        container
            .read(illustratedRoomProvider)
            .activeDraft!
            .assignments!
            .colorFor('desk')
            .hex,
        '#654321',
      );
      repository.failWrites = false;
      await _tapByKey(tester, 'room-draft-retry');
      expect(find.text('Saved'), findsOneWidget);
      expect(
        (await repository.loadDraftSnapshot()).records.single
            .restore(IllustratedRoomCatalog.study)
            .assignments!
            .colorFor('desk')
            .hex,
        '#654321',
      );
    },
  );

  // Mutation: late recovery overwrites a newer visible instance, including
  // equal-content histories after edit/undo. Identity is the resume guard.
  testWidgets('late recovery cannot replace a newer edit then Undo', (
    tester,
  ) async {
    final repository = InMemoryRoomDesignRepository();
    await repository.saveDraft(
      RecoverableRoomDraft.fromDraft(
        IllustratedRoomDraft.grayscale(
          IllustratedRoomCatalog.study,
        ).applyPalette('quiet-sage'),
        updatedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    final store = IllustratedRoomDraftStore(repository);
    await store.load();
    addTearDown(store.dispose);
    final gate = Completer<IllustratedRoomDraftStore>();
    final navigation = await _pumpApp(
      tester,
      repository: repository,
      draftStore: gate.future,
    );
    await _openStudy(tester, navigation);
    final container = _container(tester);
    final controller = container.read(illustratedRoomProvider.notifier);
    controller.setRegionColor('desk', RgbColor.fromHex('#123456'));
    controller.undo();
    final current = container.read(illustratedRoomProvider).activeDraft;
    gate.complete(store);
    await tester.pumpAndSettle();
    expect(container.read(illustratedRoomProvider).activeDraft, same(current));
    expect(
      (await repository.loadDraftSnapshot()).records.single
          .restore(IllustratedRoomCatalog.study)
          .assignments,
      isNull,
    );
  });

  const sizes = [
    Size(320, 568),
    Size(360, 800),
    Size(390, 844),
    Size(568, 320),
    Size(844, 390),
    Size(600, 960),
    Size(800, 1280),
    Size(1024, 1366),
    Size(1280, 800),
  ];
  for (final (index, size) in sizes.indexed) {
    // Mutation: non-scrollable fixed-height controls, wrong width breakpoints,
    // inset overlap or inaccessible actions at text scale / RTL / live resize.
    testWidgets(
      'complete list flow remains reachable at ${size.width} x ${size.height}',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final navigation = await _pumpApp(
          tester,
          direction: index.isOdd ? TextDirection.rtl : TextDirection.ltr,
          media: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear([1.0, 1.5, 2.0][index % 3]),
            disableAnimations: index.isOdd,
            highContrast: index.isOdd,
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
            viewInsets: EdgeInsets.only(bottom: index == 3 ? 100 : 0),
          ),
        );
        if (index.isOdd) navigation.themeMode.value = ThemeMode.dark;
        await _openStudy(tester, navigation);
        await _tapByKey(tester, 'room-edit-flow');
        await _tapByKey(tester, 'room-flow-look-quiet-sage');
        await _tapByKey(tester, 'room-apply-complete-look');
        await _tapByKey(tester, 'room-region-desk');
        await _tapByKey(tester, 'room-region-color-ECE9DF');
        await _tapByKey(tester, 'room-undo');
        await _tapByKey(tester, 'room-redo');
        final save = find.byKey(const ValueKey('room-flow-save'));
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        await _tapByKey(tester, 'room-flow-save');
        await _tapByKey(tester, 'room-confirm-save');
        await _tapByKey(tester, 'room-my-designs');
        expect(find.byKey(const ValueKey('room-design-list')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
    container.read(illustratedRoomProvider.notifier).applyPalette('quiet-sage');
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
          .applyPalette('quiet-sage');
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
      await _tapByKey(tester, 'room-palette-quiet-sage');
      await _tapByKey(tester, 'room-apply-complete-look');
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

      expect(find.text(AppLocalizationsEn().roomExportSaved), findsOneWidget);
      expect(encoder.calls, 1);
      expect(writer.calls, 1);
      expect(
        writer.fileName,
        'tintatlas-room-study-artwork-20261025T040000000Z.png',
      );
      expect(navigation.router.state.uri.path, '/room/illustrated/study');
      expect(container.read(illustratedRoomProvider).activeDraft, same(before));
    },
  );

  testWidgets('theme and route changes retain the current study draft', (
    tester,
  ) async {
    final navigation = await _pumpApp(tester);
    final container = _container(tester);
    container.read(illustratedRoomProvider.notifier).applyPalette('airy-slate');

    await _openStudy(tester, navigation);
    final before = container.read(illustratedRoomProvider).draftFor('study')!;
    expect(before.colors!.wall.hex, '#F2F4F3');

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
      expect(draft.colors!.ceiling.hex, '#B7C2A3');
      expect(draft.colors!.floor.hex, '#78866B');
      expect(draft.colors!.furniture.hex, '#4E5B4A');
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
      await _tapByKey(tester, 'room-palette-quiet-sage');
      await _tapByKey(tester, 'room-apply-complete-look');

      const coloredLabel =
          'Study room. Quiet Sage. Wall #ECE9DF. Ceiling #B7C2A3. '
          'Floor #78866B. Desk & furniture #4E5B4A.';
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
      await _tapByKey(tester, 'room-palette-quiet-sage');
      await _tapByKey(tester, 'room-apply-complete-look');
      final palette = find.byKey(
        const ValueKey('room-palette-quiet-sage'),
        skipOffstage: false,
      );
      _expectSelectedSemantics(
        tester,
        palette,
        label: 'Quiet Sage, Starting look',
        selected: true,
      );

      await _tapByKey(tester, 'room-surface-furniture');
      await tester.ensureVisible(furniture);
      await tester.pumpAndSettle();
      _expectSelectedSemantics(
        tester,
        furniture,
        label: 'Desk & furniture, #4E5B4A',
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
        final caveat = AppLocalizationsEn().illustratedPalettePreviewLimit;
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
