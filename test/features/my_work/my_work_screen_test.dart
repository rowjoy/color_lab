import 'dart:async';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/games/application/game_profiles_provider.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/color_history_repository.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/domain/experiment_snapshot.dart';
import 'package:color_lab/features/learning/domain/learning_library.dart';
import 'package:color_lab/features/my_work/presentation/my_work_screen.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_color_history_repository.dart';
import '../../support/in_memory_learning_repository.dart';
import '../../support/in_memory_room_design_repository.dart';
import '../../support/in_memory_saved_palette_repository.dart';

void main() {
  testWidgets('My Work shows all existing shared-library records', (
    tester,
  ) async {
    var gameProfileReads = 0;
    final harness = await _pumpMyWork(
      tester,
      history: InMemoryColorHistoryRepository(colors: [_savedColor]),
      palettes: InMemorySavedPaletteRepository(palettes: [_savedPalette]),
      designs: InMemoryRoomDesignRepository(designs: [_savedDesign]),
      onGameProfileRead: () => gameProfileReads++,
    );
    addTearDown(harness.dispose);

    expect(find.byKey(const ValueKey('my-work-colors')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-work-palettes')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-work-room-designs')), findsOneWidget);
    expect(find.text('Forest study'), findsOneWidget);
    expect(find.text('#123456'), findsOneWidget);
    expect(find.text('Sunset harmony'), findsOneWidget);
    expect(find.text('Quiet living room'), findsOneWidget);
    expect(gameProfileReads, 0);
  });

  testWidgets('My Work keeps three empty states independent', (tester) async {
    final harness = await _pumpMyWork(
      tester,
      history: InMemoryColorHistoryRepository(),
      palettes: InMemorySavedPaletteRepository(),
      designs: InMemoryRoomDesignRepository(),
    );
    addTearDown(harness.dispose);

    for (final key in [
      'my-work-colors-empty',
      'my-work-palettes-empty',
      'my-work-room-designs-empty',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
    }
  });

  testWidgets('My Work lists and deletes a learning experiment independently', (
    tester,
  ) async {
    final learning = InMemoryLearningRepository(
      initial: LearningLibrary.empty().copyWith(experiments: [_experiment]),
    );
    final harness = await _pumpMyWork(
      tester,
      history: InMemoryColorHistoryRepository(),
      palettes: InMemorySavedPaletteRepository(),
      designs: InMemoryRoomDesignRepository(),
      learning: learning,
    );
    addTearDown(harness.dispose);

    expect(find.text('Warm violet'), findsOneWidget);
    final delete = find.byTooltip('Delete experiment');
    await tester.ensureVisible(delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('Warm violet'), findsNothing);
    expect(
      find.byKey(const ValueKey('my-work-experiments-empty')),
      findsOneWidget,
    );
  });

  testWidgets('one failed library leaves healthy work visible and retries', (
    tester,
  ) async {
    final history = InMemoryColorHistoryRepository(colors: [_savedColor])
      ..failLoad = true;
    final harness = await _pumpMyWork(
      tester,
      history: history,
      palettes: InMemorySavedPaletteRepository(palettes: [_savedPalette]),
      designs: InMemoryRoomDesignRepository(designs: [_savedDesign]),
    );
    addTearDown(harness.dispose);

    expect(find.byKey(const ValueKey('my-work-colors-error')), findsOneWidget);
    expect(find.text('Sunset harmony'), findsOneWidget);
    expect(find.text('Quiet living room'), findsOneWidget);
    expect(find.textContaining('private storage'), findsNothing);

    history.failLoad = false;
    final retry = find.byKey(const ValueKey('my-work-colors-retry'));
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('Forest study'), findsOneWidget);
    expect(find.byKey(const ValueKey('my-work-colors-error')), findsNothing);
  });

  testWidgets('a pending library does not hide already-loaded sections', (
    tester,
  ) async {
    final pendingHistory = Completer<ColorHistoryRepository>();
    final harness = await _pumpMyWork(
      tester,
      pendingHistory: pendingHistory.future,
      palettes: InMemorySavedPaletteRepository(palettes: [_savedPalette]),
      designs: InMemoryRoomDesignRepository(designs: [_savedDesign]),
    );
    addTearDown(harness.dispose);

    await tester.pump();
    expect(
      find.byKey(const ValueKey('my-work-colors-loading')),
      findsOneWidget,
    );
    expect(find.text('Sunset harmony'), findsOneWidget);
    expect(find.text('Quiet living room'), findsOneWidget);

    pendingHistory.complete(
      InMemoryColorHistoryRepository(colors: [_savedColor]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Forest study'), findsOneWidget);
  });

  testWidgets('My Work is scrollable at 320x568 with 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = await _pumpMyWork(
      tester,
      history: InMemoryColorHistoryRepository(colors: [_savedColor]),
      palettes: InMemorySavedPaletteRepository(palettes: [_savedPalette]),
      designs: InMemoryRoomDesignRepository(designs: [_savedDesign]),
    );
    addTearDown(harness.dispose);

    await tester.ensureVisible(find.text('Quiet living room'));
    expect(find.text('Quiet living room').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

final _savedColor = SavedColor(
  id: '#123456',
  hex: '#123456',
  name: 'Forest study',
  isFavorite: true,
  createdAt: DateTime.utc(2026, 10, 20),
  source: ColorSource.manual,
);

final _savedPalette = SavedPalette(
  name: 'Sunset harmony',
  base: RgbColor.fromHex('#FF0000'),
  mode: HarmonyMode.complementary,
  colors: [RgbColor.fromHex('#FF0000'), RgbColor.fromHex('#00FFFF')],
  createdAt: DateTime.utc(2026, 10, 21),
);

final _savedDesign = SavedRoomDesign(
  id: 'living-quiet',
  name: 'Quiet living room',
  templateId: IllustratedRoomCatalog.living.id,
  colors: IllustratedRoomCatalog.living.defaultPalette.colors,
  createdAt: DateTime.utc(2026, 10, 22),
  updatedAt: DateTime.utc(2026, 10, 23),
);

final _experiment = ExperimentRecord(
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

final class _MyWorkHarness {
  const _MyWorkHarness(this.container);

  final ProviderContainer container;

  void dispose() => container.dispose();
}

Future<_MyWorkHarness> _pumpMyWork(
  WidgetTester tester, {
  InMemoryColorHistoryRepository? history,
  Future<ColorHistoryRepository>? pendingHistory,
  required InMemorySavedPaletteRepository palettes,
  required InMemoryRoomDesignRepository designs,
  InMemoryLearningRepository? learning,
  VoidCallback? onGameProfileRead,
}) async {
  assert((history == null) != (pendingHistory == null));
  final container = ProviderContainer(
    overrides: [
      colorHistoryRepositoryProvider.overrideWith(
        (ref) => pendingHistory ?? Future.value(history!),
      ),
      savedPaletteRepositoryProvider.overrideWith((ref) async => palettes),
      roomDesignRepositoryProvider.overrideWith((ref) async => designs),
      gameProfilesRepositoryProvider.overrideWith((ref) async {
        onGameProfileRead?.call();
        throw StateError('Game profiles must not own My Work.');
      }),
      learningRepositoryProvider.overrideWith(
        (ref) async => learning ?? InMemoryLearningRepository(),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MyWorkScreen(),
      ),
    ),
  );
  if (pendingHistory == null) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
  return _MyWorkHarness(container);
}
