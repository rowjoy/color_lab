import 'dart:async';

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/color_test/application/matching_game_controller.dart';
import 'package:color_lab/features/color_test/domain/matching_game.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_app_preferences_repository.dart';
import '../../../support/in_memory_acquisition_intent_store.dart';
import '../../../support/in_memory_color_history_repository.dart';
import '../../../support/in_memory_saved_palette_repository.dart';

void main() {
  final targets = [
    RgbColor(255, 0, 0),
    RgbColor(0, 255, 0),
    RgbColor(0, 0, 255),
    RgbColor(0, 255, 255),
    RgbColor(255, 255, 0),
  ];

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    String path = '/matching',
    bool completed = true,
    ThemeMode theme = ThemeMode.light,
    InMemoryColorHistoryRepository? history,
    InMemorySavedPaletteRepository? palettes,
    MatchingTargetGenerator? generator,
  }) async {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(
            initial: AppPreferences(
              onboardingCompleted: completed,
              themeMode: theme,
            ),
          ),
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => history ?? InMemoryColorHistoryRepository(),
        ),
        savedPaletteRepositoryProvider.overrideWith(
          (ref) async => palettes ?? InMemorySavedPaletteRepository(),
        ),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([NamedColor('Red', RgbColor(255, 0, 0))]),
        ),
        matchingTargetGeneratorProvider.overrideWithValue(
          generator ?? () => targets,
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(container.read(appRouterProvider).push<void>(path));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> press(WidgetTester tester, String key) async {
    final button = find.byKey(ValueKey(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  // Exercise the real shared sliders: replacing their callback with a wrong
  // coordinate must change the displayed RGB and the frozen attempt.
  Future<void> slide(WidgetTester tester, String key, double value) async {
    final slider = find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(Slider),
    );
    await tester.ensureVisible(slider);
    tester.widget<Slider>(slider).onChanged!(value);
    await tester.pumpAndSettle();
  }

  Future<void> completePerfectGame(WidgetTester tester) async {
    for (final hue in [0.0, 120.0, 240.0, 180.0, 60.0]) {
      await slide(tester, 'matching-hue', hue);
      await slide(tester, 'matching-saturation', 1);
      await press(tester, 'matching-submit');
      expect(find.text('Exact match!'), findsOneWidget);
      await press(tester, 'matching-next');
    }
  }

  testWidgets('Lab opens the retained color matching game', (tester) async {
    await launch(tester, path: '/lab');
    final entry = find.byKey(const ValueKey('open-matching'));
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('screen-Matching')), findsOneWidget);
    expect(find.text('Round 1 of 5'), findsOneWidget);
  });

  testWidgets('direct matching route respects the onboarding guard', (
    tester,
  ) async {
    final container = await launch(tester, completed: false);
    expect(find.byKey(const ValueKey('screen-Matching')), findsNothing);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/onboarding',
    );
  });

  testWidgets(
    'editing hides both HEX values and their accessible detail actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final container = await launch(tester);
        for (final key in ['matching-target', 'matching-guess']) {
          final tile = find.byKey(ValueKey(key));
          final swatch = tester.widget<ColorSwatchTile>(tile);
          expect(swatch.hex, 'Hidden until you submit');
          expect(swatch.onTap, isNull);
          expect(tester.getSemantics(tile).label, isNot(contains('#')));
          await tester.ensureVisible(tile);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(find.byType(ColorDetails), findsNothing);
        }
        expect(find.text('#FF0000'), findsNothing);
        expect(find.text('#808080'), findsNothing);
        expect(find.textContaining(RegExp(r'^ΔE ')), findsNothing);
        expect(find.text('Red'), findsNothing);
        expect(container.read(matchingGameProvider).attempts, isEmpty);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'grey submission scores actual display RGB and freezes one attempt',
    (tester) async {
      final container = await launch(tester);
      final submit = tester
          .widget<PrimaryButton>(find.byKey(const ValueKey('matching-submit')))
          .onPressed!;
      final staleSlider = tester
          .widget<Slider>(find.byType(Slider).first)
          .onChanged!;
      await press(tester, 'matching-submit');
      final game = container.read(matchingGameProvider);
      expect(game.attempts.single.guess.hex, '#808080');
      expect(game.attempts.single.target.hex, '#FF0000');
      expect(game.attempts.single.deltaE, closeTo(104.5518, .001));
      expect(find.text('ΔE 104.55'), findsOneWidget);
      expect(find.text('0 / 100 points'), findsOneWidget);
      for (final feedback in [
        find.text('ΔE 104.55'),
        find.text('0 / 100 points'),
      ]) {
        expect(
          tester
              .widgetList<Semantics>(
                find.ancestor(of: feedback, matching: find.byType(Semantics)),
              )
              .any((s) => s.properties.liveRegion == true),
          isTrue,
        );
      }
      expect(find.text('#FF0000'), findsOneWidget);
      expect(find.text('#808080'), findsOneWidget);
      expect(find.byKey(const ValueKey('matching-submit')), findsNothing);
      for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
        expect(slider.onChanged, isNull);
      }
      submit();
      staleSlider(240);
      await tester.pumpAndSettle();
      expect(container.read(matchingGameProvider), same(game));
      final staleNext = tester
          .widget<PrimaryButton>(find.byKey(const ValueKey('matching-next')))
          .onPressed!;
      await press(tester, 'matching-next');
      staleNext();
      await tester.pumpAndSettle();
      expect(find.text('Round 2 of 5'), findsOneWidget);
      expect(container.read(matchingGameProvider).guess.hex, '#808080');
      expect(find.text('#00FF00'), findsNothing);
    },
  );

  testWidgets(
    'sliders retain neutral hue then score green against red with literal error',
    (tester) async {
      final container = await launch(tester);
      await slide(tester, 'matching-hue', 120);
      expect(container.read(matchingGameProvider).guess.hex, '#808080');
      await slide(tester, 'matching-lightness', 0);
      await slide(tester, 'matching-saturation', 1);
      await slide(tester, 'matching-lightness', .5);
      expect(container.read(matchingGameProvider).guess.hex, '#00FF00');
      expect(
        tester
            .widget<ColorSwatchTile>(
              find.byKey(const ValueKey('matching-guess')),
            )
            .color,
        const Color(0xFF00FF00),
      );
      await press(tester, 'matching-submit');
      expect(find.text('ΔE 170.57'), findsOneWidget);
      expect(find.text('0 / 100 points'), findsOneWidget);
      expect(
        container.read(matchingGameProvider).attempts.single.deltaE,
        closeTo(170.565242, .00001),
      );
    },
  );

  testWidgets('a rounded score of100 does not claim an exact RGB match', (
    tester,
  ) async {
    final container = await launch(
      tester,
      generator: () => [RgbColor(254, 0, 0), ...targets.skip(1)],
    );
    await slide(tester, 'matching-saturation', 1);
    await press(tester, 'matching-submit');
    expect(find.text('100 / 100 points'), findsOneWidget);
    expect(find.text('Exact match!'), findsNothing);
    expect(
      container.read(matchingGameProvider).attempts.single.isExact,
      isFalse,
    );
  });

  testWidgets(
    'both comparison colors stay visible while adjusting Lightness on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await launch(tester);
      await slide(tester, 'matching-hue', 240);
      await slide(tester, 'matching-saturation', 1);
      await slide(tester, 'matching-lightness', .5);
      for (final key in [
        'matching-comparison-target',
        'matching-comparison-guess',
      ]) {
        final swatch = find.byKey(ValueKey(key));
        expect(swatch, findsOneWidget);
        final rect = tester.getRect(swatch);
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(800));
      }
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('matching-comparison-target')),
            )
            .color,
        const Color(0xFFFF0000),
      );
      expect(
        tester
            .widget<ColoredBox>(
              find.byKey(const ValueKey('matching-comparison-guess')),
            )
            .color,
        const Color(0xFF0000FF),
      );
      expect(find.text('#FF0000'), findsNothing);
      expect(find.text('#0000FF'), findsNothing);
    },
  );

  testWidgets(
    'feedback details save the exact Lab target and Room receives the guess',
    (tester) async {
      final history = InMemoryColorHistoryRepository();
      final container = await launch(tester, history: history);
      await press(tester, 'matching-submit');
      final snapshot = container.read(matchingGameProvider);
      await press(tester, 'matching-target');
      expect(
        tester.widget<ColorDetails>(find.byType(ColorDetails)).color.hex,
        '#FF0000',
      );
      expect(
        tester.widget<ColorDetails>(find.byType(ColorDetails)).source,
        ColorSource.lab,
      );
      await tester.ensureVisible(find.text('Save color'));
      await tester.tap(find.text('Save color'));
      await tester.pumpAndSettle();
      final saved = (await history.load()).single;
      expect(saved.hex, '#FF0000');
      expect(saved.source, ColorSource.lab);
      await tester.ensureVisible(find.byTooltip('Close color details'));
      await tester.tap(find.byTooltip('Close color details'));
      await tester.pumpAndSettle();
      await press(tester, 'matching-guess');
      expect(
        tester.widget<ColorDetails>(find.byType(ColorDetails)).color.hex,
        '#808080',
      );
      expect(
        tester.widget<ColorDetails>(find.byType(ColorDetails)).source,
        ColorSource.lab,
      );
      await tester.ensureVisible(find.text('Use in Room'));
      await tester.tap(find.text('Use in Room'));
      await tester.pumpAndSettle();
      expect(container.read(roomColorProvider).hex, '#808080');
      expect(container.read(matchingGameProvider), same(snapshot));
    },
  );

  testWidgets(
    'five frozen pairs finish with total average and explicit replay',
    (tester) async {
      final container = await launch(tester);
      await completePerfectGame(tester);
      expect(
        container.read(matchingGameProvider).phase,
        MatchingPhase.complete,
      );
      expect(find.text('500 / 500'), findsOneWidget);
      expect(find.text('100.00 / 100'), findsOneWidget);
      expect(find.byKey(const ValueKey('matching-next')), findsNothing);
      for (var i = 0; i < 5; i++) {
        expect(
          find.byKey(ValueKey('matching-result-${i + 1}')),
          findsOneWidget,
        );
        final result = find.byKey(ValueKey('matching-result-${i + 1}'));
        expect(
          find.descendant(of: result, matching: find.text(targets[i].hex)),
          findsNWidgets(2),
        );
        expect(
          find.descendant(of: result, matching: find.text('100 / 100 points')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: result, matching: find.text('ΔE 0.00')),
          findsOneWidget,
        );
      }
      final complete = container.read(matchingGameProvider);
      await tester.pump(const Duration(minutes: 2));
      expect(container.read(matchingGameProvider), same(complete));
      await press(tester, 'matching-play-again');
      expect(find.text('Round 1 of 5'), findsOneWidget);
      expect(container.read(matchingGameProvider).attempts, isEmpty);
    },
  );

  testWidgets(
    'restart cancel and system Back retain draft; confirm replaces game',
    (tester) async {
      var generation = 0;
      final container = await launch(
        tester,
        generator: () {
          generation++;
          return generation == 1 ? targets : targets.reversed.toList();
        },
      );
      await slide(tester, 'matching-hue', 240);
      await slide(tester, 'matching-saturation', 1);
      final draft = container.read(matchingGameProvider);
      await press(tester, 'matching-restart');
      expect(find.text('Restart this game?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(matchingGameProvider), same(draft));
      await press(tester, 'matching-restart');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Restart this game?'), findsNothing);
      expect(container.read(matchingGameProvider), same(draft));
      await press(tester, 'matching-submit');
      await press(tester, 'matching-restart');
      await press(tester, 'confirm-matching-restart');
      expect(container.read(matchingGameProvider).target.hex, '#FFFF00');
      expect(container.read(matchingGameProvider).guess.hex, '#808080');
      expect(container.read(matchingGameProvider).attempts, isEmpty);
      expect(generation, 2);
    },
  );

  testWidgets('results and replay open at the top after phone button taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester);
    for (var round = 0; round < 5; round++) {
      await press(tester, 'matching-submit');
      await press(tester, 'matching-next');
    }
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('screen-Matching')),
      matching: find.byType(Scrollable),
    );
    final resultOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    final totalRect = tester.getRect(find.text('Total points'));
    final summaryVisible =
        find.text('Total points').hitTestable().evaluate().isNotEmpty &&
        find.text('Average per round').hitTestable().evaluate().isNotEmpty;
    await press(tester, 'matching-play-again');
    final replayOffset = tester
        .state<ScrollableState>(scrollable)
        .position
        .pixels;
    final targetRect = tester.getRect(
      find.byKey(const ValueKey('matching-target')),
    );
    final replayVisible = find
        .byKey(const ValueKey('matching-target'))
        .hitTestable()
        .evaluate()
        .isNotEmpty;
    expect(
      [summaryVisible, replayVisible],
      [true, true],
      reason:
          'Results offset $resultOffset, total rect $totalRect; replay offset $replayOffset, target rect $targetRect. No scrolling to either entry was performed.',
    );
  });

  testWidgets(
    'coordinate theme and feedback retain scroll; confirmed new game resets it',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await launch(tester);
      await slide(tester, 'matching-lightness', .7);
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('screen-Matching')),
        matching: find.byType(Scrollable),
      );
      final offset = tester.state<ScrollableState>(scrollable).position.pixels;
      expect(offset, greaterThan(0));
      final slider = find.descendant(
        of: find.byKey(const ValueKey('matching-lightness')),
        matching: find.byType(Slider),
      );
      tester.widget<Slider>(slider).onChanged!(.6);
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
      await container
          .read(appPreferencesProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, offset);
      await press(tester, 'matching-restart');
      await press(tester, 'confirm-matching-restart');
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
      expect(
        find.byKey(const ValueKey('matching-target')).hitTestable(),
        findsOneWidget,
      );
      expect(container.read(matchingGameProvider).lightness, .5);
      final submit = find.byKey(const ValueKey('matching-submit'));
      await tester.ensureVisible(submit);
      final submitOffset = tester
          .state<ScrollableState>(scrollable)
          .position
          .pixels;
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        submitOffset,
        reason: 'Submitting should retain the controls/feedback viewport.',
      );
    },
  );

  testWidgets(
    'Back reentry theme and completion preserve game and independent drafts',
    (tester) async {
      final existingColor = SavedColor(
        id: '#123456',
        hex: '#123456',
        name: 'Existing color',
        isFavorite: true,
        createdAt: DateTime.utc(2026, 10, 20),
        source: ColorSource.manual,
      );
      final existingPalette = SavedPalette(
        name: 'Existing palette',
        base: RgbColor(255, 0, 0),
        mode: HarmonyMode.complementary,
        colors: [RgbColor(255, 0, 0), RgbColor(0, 255, 255)],
        createdAt: DateTime.utc(2026, 10, 20),
      );
      final container = await launch(
        tester,
        path: '/lab',
        history: InMemoryColorHistoryRepository(colors: [existingColor]),
        palettes: InMemorySavedPaletteRepository(palettes: [existingPalette]),
      );
      tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(120);
      await tester.pumpAndSettle();
      final hsl = tester
          .widget<ColorSwatchTile>(find.byType(ColorSwatchTile))
          .hex;
      container.read(mixerProvider.notifier).setWeight('color-0', 37);
      container
          .read(formulaTargetProvider.notifier)
          .setColor(RgbColor(1, 2, 3));
      container
          .read(harmonyDraftProvider.notifier)
          .setBase(RgbColor(0, 0, 255));
      final mixer = container.read(mixerProvider);
      final harmony = container.read(harmonyDraftProvider);
      await press(tester, 'open-matching');
      await slide(tester, 'matching-hue', 240);
      final draft = container.read(matchingGameProvider);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        hsl,
      );
      await press(tester, 'open-matching');
      expect(container.read(matchingGameProvider), same(draft));
      await press(tester, 'matching-submit');
      final feedback = container.read(matchingGameProvider);
      await container
          .read(appPreferencesProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(container.read(matchingGameProvider), same(feedback));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await press(tester, 'open-matching');
      expect(container.read(matchingGameProvider), same(feedback));
      for (var i = 0; i < 5; i++) {
        await press(tester, 'matching-next');
        if (i < 4) await press(tester, 'matching-submit');
      }
      final complete = container.read(matchingGameProvider);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await press(tester, 'open-matching');
      expect(container.read(matchingGameProvider), same(complete));
      expect(container.read(mixerProvider), same(mixer));
      expect(container.read(formulaTargetProvider).hex, '#010203');
      expect(container.read(harmonyDraftProvider), same(harmony));
      await press(tester, 'matching-play-again');
      expect(container.read(mixerProvider), same(mixer));
      expect(container.read(harmonyDraftProvider), same(harmony));
      expect(
        await container
            .read(colorHistoryRepositoryProvider.future)
            .then((r) => r.load()),
        [existingColor],
      );
      expect(await container.read(savedPalettesProvider.future), [
        existingPalette,
      ]);
    },
  );

  testWidgets('history load failure does not block play or results', (
    tester,
  ) async {
    final history = InMemoryColorHistoryRepository()..failLoad = true;
    final container = await launch(tester, history: history);
    await tester.runAsync(() async {
      await expectLater(
        container.read(colorHistoryProvider.future),
        throwsStateError,
      );
    });
    expect(container.read(colorHistoryProvider).hasError, isTrue);
    await completePerfectGame(tester);
    expect(container.read(matchingGameProvider).totalScore, 500);
    expect(find.text('500 / 500'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('matching states fit360px2x reduced-motion ${theme.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final container = await launch(tester, theme: theme);
      await slide(tester, 'matching-lightness', .5);
      for (final key in [
        'matching-comparison-target',
        'matching-comparison-guess',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(800));
      }
      expect(tester.takeException(), isNull);
      await press(tester, 'matching-restart');
      for (final key in ['confirm-matching-restart']) {
        final button = find.byKey(ValueKey(key));
        await tester.ensureVisible(button);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await completePerfectGame(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('matching-play-again')),
      );
      expect(
        container.read(matchingGameProvider).phase,
        MatchingPhase.complete,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
