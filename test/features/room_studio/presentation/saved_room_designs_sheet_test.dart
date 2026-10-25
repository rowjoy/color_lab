import 'dart:async';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/core/widgets/buttons.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_screen.dart';
import 'package:color_lab/features/room_studio/presentation/saved_room_designs_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_design_repository.dart';

final _now = DateTime.utc(2026, 10, 25, 4);

SavedRoomDesign _saved({
  required String id,
  required String name,
  required String templateId,
  DateTime? updatedAt,
}) {
  final template = IllustratedRoomCatalog.maybeById(templateId);
  return SavedRoomDesign(
    id: id,
    name: name,
    templateId: templateId,
    colors:
        template?.defaultPalette.colors ??
        IllustratedRoomCatalog.study.defaultPalette.colors,
    createdAt: DateTime.utc(2026, 10, 20),
    updatedAt: updatedAt ?? _now,
  );
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
  listen: false,
);

Future<void> _pumpList(
  WidgetTester tester,
  InMemoryRoomDesignRepository repository, {
  required Future<void> Function(SavedRoomDesign) onOpen,
  String? initialTemplateId,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomDesignRepositoryProvider.overrideWith((ref) async => repository),
        roomDesignClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: SavedRoomDesignsList(
              onOpen: onOpen,
              initialTemplateId: initialTemplateId,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpEditor(
  WidgetTester tester,
  InMemoryRoomDesignRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roomDesignRepositoryProvider.overrideWith((ref) async => repository),
        roomDesignClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const IllustratedRoomScreen(templateId: 'study'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key), skipOffstage: false);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('saved library defaults to All and filters by every room', (
    tester,
  ) async {
    final repository = InMemoryRoomDesignRepository(
      designs: [
        _saved(id: 'living-1', name: 'Warm lounge', templateId: 'living'),
        _saved(id: 'bedroom-1', name: 'Quiet sleep', templateId: 'bedroom'),
        _saved(id: 'future-1', name: 'Future space', templateId: 'future-room'),
      ],
    );
    addTearDown(repository.close);
    await _pumpList(tester, repository, onOpen: (_) async {});

    expect(
      tester
          .widget<ChoiceChip>(
            find.descendant(
              of: find.byKey(const ValueKey('room-design-filter-all')),
              matching: find.byType(ChoiceChip),
            ),
          )
          .selected,
      isTrue,
    );
    for (final template in IllustratedRoomCatalog.all) {
      expect(
        find.byKey(ValueKey('room-design-filter-${template.id}')),
        findsOneWidget,
      );
    }
    expect(find.text('Warm lounge'), findsOneWidget);
    expect(find.text('Quiet sleep'), findsOneWidget);
    expect(find.text('Future space'), findsOneWidget);
    expect(find.text('Temporarily unavailable'), findsOneWidget);

    await _tapKey(tester, 'room-design-filter-living');
    expect(find.text('Warm lounge'), findsOneWidget);
    expect(find.text('Quiet sleep'), findsNothing);
    expect(find.text('Future space'), findsNothing);

    await _tapKey(tester, 'room-design-filter-all');
    expect(find.text('Quiet sleep'), findsOneWidget);
  });

  testWidgets(
    'optional initial room filter is explicit and can return to All',
    (tester) async {
      final repository = InMemoryRoomDesignRepository(
        designs: [
          _saved(id: 'living-1', name: 'Living only', templateId: 'living'),
          _saved(id: 'study-1', name: 'Study only', templateId: 'study'),
        ],
      );
      addTearDown(repository.close);
      await _pumpList(
        tester,
        repository,
        initialTemplateId: 'study',
        onOpen: (_) async {},
      );

      expect(
        tester
            .widget<ChoiceChip>(
              find.descendant(
                of: find.byKey(const ValueKey('room-design-filter-study')),
                matching: find.byType(ChoiceChip),
              ),
            )
            .selected,
        isTrue,
      );
      expect(find.text('Study only'), findsOneWidget);
      expect(find.text('Living only'), findsNothing);
      await _tapKey(tester, 'room-design-filter-all');
      expect(find.text('Living only'), findsOneWidget);
    },
  );

  testWidgets('rows expose contextual swatches and delegate opening only', (
    tester,
  ) async {
    final design = _saved(
      id: 'bedroom-1',
      name: 'Bedroom colors',
      templateId: 'bedroom',
    );
    final repository = InMemoryRoomDesignRepository(
      designs: [
        design,
        _saved(id: 'future-1', name: 'Future space', templateId: 'future-room'),
      ],
    );
    addTearDown(repository.close);
    SavedRoomDesign? opened;
    await _pumpList(
      tester,
      repository,
      onOpen: (design) async => opened = design,
    );
    final container = _container(tester);
    final before = container.read(illustratedRoomProvider);

    final swatch = find.byKey(
      const ValueKey('room-design-swatch-bedroom-1-furniture'),
    );
    expect(swatch, findsOneWidget);
    expect(
      tester.getSemantics(swatch).getSemanticsData().label,
      'Bed & furniture, ${design.colors.furniture.hex}',
    );
    await _tapKey(tester, 'room-design-row-bedroom-1');
    expect(opened, design);
    expect(container.read(illustratedRoomProvider), same(before));

    opened = null;
    await _tapKey(tester, 'room-design-row-future-1');
    expect(opened, isNull);
    expect(
      find.byKey(const ValueKey('room-design-rename-future-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('room-design-delete-future-1')),
      findsOneWidget,
    );
  });

  testWidgets('load failure retries without hiding the reusable library', (
    tester,
  ) async {
    final repository = InMemoryRoomDesignRepository()..failLoad = true;
    addTearDown(repository.close);
    await _pumpList(tester, repository, onOpen: (_) async {});

    expect(find.text('Could not load your room designs.'), findsOneWidget);
    repository.failLoad = false;
    await _tapKey(tester, 'room-designs-retry');
    expect(find.text('No saved room designs yet.'), findsOneWidget);
  });

  testWidgets('an in-flight saved-design open ignores duplicate taps', (
    tester,
  ) async {
    final design = _saved(
      id: 'study-gated',
      name: 'Gated study',
      templateId: 'study',
    );
    final repository = InMemoryRoomDesignRepository(designs: [design]);
    addTearDown(repository.close);
    final gate = Completer<void>();
    var calls = 0;
    await _pumpList(
      tester,
      repository,
      onOpen: (_) async {
        calls++;
        await gate.future;
      },
    );

    final row = find.byKey(const ValueKey('room-design-row-study-gated'));
    await tester.tap(row);
    await tester.tap(row);
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<InkWell>(row).onTap, isNull);
    final progress = find.byType(LinearProgressIndicator);
    expect(progress, findsOneWidget);
    expect(
      tester.widget<LinearProgressIndicator>(progress).semanticsLabel,
      'Opening room design',
    );

    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(row).onTap, isNotNull);
  });

  testWidgets('filters remain tappable at 320dp with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = InMemoryRoomDesignRepository(
      designs: [
        _saved(
          id: 'study-large-text',
          name: 'Large text study',
          templateId: 'study',
        ),
      ],
    );
    addTearDown(repository.close);

    await _pumpList(
      tester,
      repository,
      textScaler: const TextScaler.linear(2),
      onOpen: (_) async {},
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('room-design-filters'))).height,
      greaterThanOrEqualTo(64),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('room-design-filter-all')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets(
    'rename and delete failures retry and reconcile background draft',
    (tester) async {
      final stored = _saved(
        id: 'study-shared',
        name: 'Stored study',
        templateId: 'study',
      );
      final repository = InMemoryRoomDesignRepository(
        designs: [stored],
        clock: () => _now.add(const Duration(minutes: 1)),
      );
      addTearDown(repository.close);
      await _pumpList(tester, repository, onOpen: (_) async {});
      final container = _container(tester);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.openDesign(stored);
      controller.setSurfaceColor(
        IllustratedRoomSurface.wall,
        RgbColor.fromHex('#123456'),
      );
      controller.openTemplate(IllustratedRoomCatalog.living);
      await tester.pumpAndSettle();

      repository.failWrites = true;
      await _tapKey(tester, 'room-design-rename-study-shared');
      await tester.enterText(
        find.byKey(const ValueKey('room-design-rename-input')),
        'Renamed study',
      );
      await _tapKey(tester, 'room-confirm-rename');
      expect(find.text('Could not rename this room design.'), findsOneWidget);
      expect(
        container.read(illustratedRoomProvider).draftFor('study')!.savedName,
        'Stored study',
      );

      repository.failWrites = false;
      await _tapKey(tester, 'room-confirm-rename');
      var background = container
          .read(illustratedRoomProvider)
          .draftFor('study')!;
      expect(background.savedName, 'Renamed study');
      expect(background.colors!.wall.hex, '#123456');
      expect(background.isDirty, isTrue);

      repository.failWrites = true;
      await _tapKey(tester, 'room-design-delete-study-shared');
      await _tapKey(tester, 'room-confirm-delete');
      expect(find.text('Could not delete this room design.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(
        container
            .read(illustratedRoomProvider)
            .draftFor('study')!
            .savedDesignId,
        'study-shared',
      );

      repository.failWrites = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(await repository.load(), isEmpty);
      background = container.read(illustratedRoomProvider).draftFor('study')!;
      expect(background.savedDesignId, isNull);
      expect(background.savedName, isNull);
      expect(background.colors!.wall.hex, '#123456');
      expect(background.isDirty, isTrue);
    },
  );

  testWidgets(
    'Designs rail embeds one save action and reusable list semantics',
    (tester) async {
      final repository = InMemoryRoomDesignRepository(
        designs: [
          _saved(id: 'study-1', name: 'Saved study', templateId: 'study'),
        ],
      );
      addTearDown(repository.close);
      await _pumpEditor(tester, repository);
      final container = _container(tester);
      container
          .read(illustratedRoomProvider.notifier)
          .applyPalette('soft-botanical');
      await tester.pumpAndSettle();

      final semantics = tester.ensureSemantics();
      final designsAction = find.byKey(const ValueKey('room-open-designs'));
      expect(
        tester.getSemantics(designsAction).getSemanticsData().label,
        'Designs, 1 saved, current design can be saved',
      );
      await _tapKey(tester, 'room-open-designs');
      expect(find.text('Save design'), findsOneWidget);
      expect(find.text('Saved designs'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('room-design-filter-all')),
        findsOneWidget,
      );
      expect(find.text('Saved study'), findsOneWidget);
      expect(find.text('Browse saved designs'), findsNothing);
      final allFilter = find.descendant(
        of: find.byKey(const ValueKey('room-design-filter-all')),
        matching: find.byType(ChoiceChip),
      );
      expect(tester.widget<ChoiceChip>(allFilter).selected, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('save validates a name and updates the same durable design', (
    tester,
  ) async {
    final repository = InMemoryRoomDesignRepository(clock: () => _now);
    addTearDown(repository.close);
    await _pumpEditor(tester, repository);
    final container = _container(tester);
    final controller = container.read(illustratedRoomProvider.notifier);
    controller.applyPalette('warm-natural');
    await tester.pumpAndSettle();

    await _tapKey(tester, 'room-open-designs');
    await _tapKey(tester, 'room-save-design');
    final nameField = find.byKey(const ValueKey('room-design-name-input'));
    expect(
      tester.widget<TextField>(nameField).controller!.text,
      'Study room - 2026-10-25',
    );
    await tester.enterText(nameField, '   ');
    await _tapKey(tester, 'room-confirm-save');
    expect(find.text('Enter 1–60 characters.'), findsOneWidget);
    await tester.enterText(nameField, 'Focus room');
    await _tapKey(tester, 'room-confirm-save');

    final first = (await repository.load()).single;
    expect(first.name, 'Focus room');
    var draft = container.read(illustratedRoomProvider).draftFor('study')!;
    expect(draft.savedDesignId, first.id);
    expect(draft.isDirty, isFalse);

    controller.setSurfaceColor(
      IllustratedRoomSurface.wall,
      RgbColor.fromHex('#123456'),
    );
    await tester.pumpAndSettle();
    await _tapKey(tester, 'room-save-design');
    await tester.enterText(nameField, 'Updated focus');
    await _tapKey(tester, 'room-confirm-save');
    expect((await repository.load()).single.id, first.id);
    expect((await repository.load()).single.name, 'Updated focus');
    draft = container.read(illustratedRoomProvider).draftFor('study')!;
    expect(draft.savedName, 'Updated focus');
    expect(draft.isDirty, isFalse);
    expect(
      tester
          .widget<PrimaryButton>(
            find.byKey(const ValueKey('room-save-design'), skipOffstage: false),
          )
          .onPressed,
      isNull,
    );
  });
}
