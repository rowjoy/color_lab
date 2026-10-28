import 'dart:async';
import 'dart:ui' as ui;

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/color_test/application/matching_game_controller.dart';
import 'package:color_lab/features/color_test/application/vision_controller.dart';
import 'package:color_lab/features/color_test/domain/vision_plate.dart';
import 'package:color_lab/features/color_test/domain/vision_session.dart';
import 'package:color_lab/features/color_test/presentation/vision_plate_view.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_app_preferences_repository.dart';
import '../../../support/in_memory_acquisition_intent_store.dart';
import '../../../support/in_memory_color_history_repository.dart';
import '../../../support/in_memory_saved_palette_repository.dart';

const caveat =
    'Generated patterns for exploration only. This is not a validated screening test or medical diagnosis and cannot rule out a condition.';
const professional =
    'If you have concerns about your color vision, talk to an eye care professional.';

List<VisionPlate> fixture({int seed = 100}) => [
  VisionPlate(number: 2, seed: seed),
  VisionPlate(number: 3, seed: seed + 1, palette: VisionPalette.tealRose),
  VisionPlate(number: 4, seed: seed + 2, palette: VisionPalette.blueSand),
  VisionPlate(number: 5, seed: seed + 3),
  VisionPlate(number: 6, seed: seed + 4, palette: VisionPalette.tealRose),
  VisionPlate(number: 8, seed: seed + 5, palette: VisionPalette.blueSand),
];

Future<ProviderContainer> launch(
  WidgetTester tester, {
  String path = '/lab',
  bool completed = true,
  ThemeMode theme = ThemeMode.light,
  VisionPlateGenerator? generator,
  InMemoryColorHistoryRepository? history,
  InMemorySavedPaletteRepository? palettes,
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
      visionPlateGeneratorProvider.overrideWithValue(generator ?? fixture),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RepaintBoundary(
        key: ValueKey('app-snapshot'),
        child: ColorLabApp(),
      ),
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

Future<ProviderContainer> start(WidgetTester tester) async {
  final container = await launch(tester, path: '/vision');
  await press(tester, 'vision-start');
  return container;
}

Future<void> answer(WidgetTester tester, String value) async {
  await tester.ensureVisible(find.byKey(const ValueKey('vision-answer')));
  await tester.enterText(find.byKey(const ValueKey('vision-answer')), value);
  await tester.pumpAndSettle();
  await press(tester, 'vision-record');
}

double offset(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('screen-Vision')),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position
    .pixels;

void phone(WidgetTester tester, {bool large = false}) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  if (large) {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
}

Future<List<int>> platePixels(
  WidgetTester tester,
) async => (await tester.runAsync(() async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('app-snapshot')),
  );
  final rect = tester.getRect(find.byKey(const ValueKey('vision-plate')));
  final image = await boundary.toImage();
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = <int>[];
    // Central canvas crop excludes page chrome and the transparent outer edge.
    for (
      var y = (rect.top + rect.height * .2).ceil();
      y < (rect.bottom - rect.height * .2).floor();
      y++
    ) {
      for (
        var x = (rect.left + rect.width * .2).ceil();
        x < (rect.right - rect.width * .2).floor();
        x++
      ) {
        final index = (y * image.width + x) * 4;
        result.addAll(bytes.buffer.asUint8List(index, 4));
      }
    }
    return result;
  } finally {
    image.dispose();
  }
}))!;

void main() {
  // Removing the Lab route entry must prevent reaching the real introduction.
  testWidgets('Lab opens vision introduction and requires explicit start', (
    tester,
  ) async {
    await launch(tester);
    expect(find.byKey(const ValueKey('open-vision')), findsOneWidget);
    await press(tester, 'open-vision');
    expect(find.byKey(const ValueKey('screen-Vision')), findsOneWidget);
    expect(find.byKey(const ValueKey('vision-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('vision-answer')), findsNothing);
    expect(
      find.text(
        'Generated patterns for exploration only. This is not a validated screening test or medical diagnosis and cannot rule out a condition.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'If you have concerns about your color vision, talk to an eye care professional.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('direct vision route respects onboarding guard', (tester) async {
    final container = await launch(tester, path: '/vision', completed: false);
    expect(find.byKey(const ValueKey('screen-Vision')), findsNothing);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/onboarding',
    );
  });

  // Revealing a generated answer in live text/semantics breaks this boundary.
  testWidgets('active plate hides answer and exposes only response semantics', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    try {
      final container = await start(tester);
      expect(find.text('Plate 1 of 6'), findsOneWidget);
      expect(find.byType(VisionPlateView), findsOneWidget);
      expect(
        tester.widget<VisionPlateView>(find.byType(VisionPlateView)).plate,
        container.read(visionSessionProvider).currentPlate,
      );
      expect(find.text('Generated number'), findsNothing);
      expect(find.text('Your response'), findsNothing);
      expect(find.text('2'), findsNothing);
      final label = tester
          .getSemantics(find.byKey(const ValueKey('vision-plate')))
          .label;
      expect(
        label,
        'Generated dot pattern. Enter the number you see, or choose Not sure.',
      );
      expect(label, isNot(contains('100')));
      expect(label, isNot(contains('roseOlive')));
      expect(find.bySemanticsLabel('2'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp(r'Generated number|2-roseOlive-100')),
        findsNothing,
      );
      expect(find.bySemanticsLabel('Number you see'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('vision-answer')),
      );
      expect(field.keyboardType, TextInputType.number);
      expect(field.maxLength, 1);
      expect(find.text(caveat), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  // Empty input must not become zero, while explicit Not sure records null.
  testWidgets(
    'blank validates, typing accepts only one digit, zero and Not sure differ',
    (tester) async {
      final container = await start(tester);
      await press(tester, 'vision-record');
      expect(find.text('Enter one digit, or choose Not sure.'), findsOneWidget);
      expect(container.read(visionSessionProvider).responses, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('vision-answer')),
        'a07',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('vision-answer')))
            .controller!
            .text,
        '0',
      );
      await press(tester, 'vision-record');
      expect(container.read(visionSessionProvider).responses.single.answer, 0);
      expect(find.text('Plate 2 of 6'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('vision-answer')))
            .controller!
            .text,
        isEmpty,
      );
      await press(tester, 'vision-not-sure');
      expect(
        container.read(visionSessionProvider).responses.last.answer,
        isNull,
      );
      expect(container.read(visionSessionProvider).notSureCount, 1);
      expect(find.text('Plate 3 of 6'), findsOneWidget);
    },
  );

  // A callback retained from plate1 must not answer or clear plate2's draft.
  testWidgets(
    'stale Record and Not sure reject without clearing next draft or keyboard',
    (tester) async {
      final container = await start(tester);
      final blankRecord = tester
          .widget<PrimaryButton>(find.byKey(const ValueKey('vision-record')))
          .onPressed!;
      await tester.enterText(find.byKey(const ValueKey('vision-answer')), '2');
      await tester.pumpAndSettle();
      final record = tester
          .widget<PrimaryButton>(find.byKey(const ValueKey('vision-record')))
          .onPressed!;
      final notSure = tester
          .widget<SecondaryButton>(
            find.byKey(const ValueKey('vision-not-sure')),
          )
          .onPressed!;
      final staleEdit = tester
          .widget<TextField>(find.byKey(const ValueKey('vision-answer')))
          .onChanged!;
      await press(tester, 'vision-record');
      await tester.ensureVisible(find.byKey(const ValueKey('vision-answer')));
      await tester.enterText(find.byKey(const ValueKey('vision-answer')), '7');
      await tester.pumpAndSettle();
      final next = container.read(visionSessionProvider);
      record();
      notSure();
      blankRecord();
      staleEdit('9');
      await tester.pumpAndSettle();
      expect(container.read(visionSessionProvider), same(next));
      expect(next.responses.length, 1);
      expect(next.draft, 7);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('vision-answer')))
            .controller!
            .text,
        '7',
      );
      expect(tester.testTextInput.isVisible, isTrue);
      expect(find.text('Enter one digit, or choose Not sure.'), findsNothing);
    },
  );

  testWidgets(
    'new response updates actual plate pixels and theme preserves them',
    (tester) async {
      phone(tester);
      final container = await start(tester);
      final first = await platePixels(tester);
      await container
          .read(appPreferencesProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(await platePixels(tester), first);
      await press(tester, 'vision-not-sure');
      final second = await platePixels(tester);
      expect(second, isNot(first));
      expect(second, isNotEmpty);
      expect(container.read(visionSessionProvider).currentPlate.number, 3);
    },
  );

  testWidgets(
    'Back from a replacement root vision route returns to Lab without resetting draft',
    (tester) async {
      final container = await start(tester);
      await tester.enterText(find.byKey(const ValueKey('vision-answer')), '7');
      await tester.pumpAndSettle();
      final draft = container.read(visionSessionProvider);
      container.read(appRouterProvider).go('/vision');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/learn/experiment/lab',
      );
      expect(container.read(visionSessionProvider), same(draft));
      expect(find.byKey(const ValueKey('open-vision')), findsOneWidget);
    },
  );

  testWidgets(
    'six real responses reveal frozen pairs and neutral counts only at completion',
    (tester) async {
      final container = await start(tester);
      for (final value in ['2', '0', '4']) {
        await answer(tester, value);
      }
      await press(tester, 'vision-not-sure');
      await answer(tester, '6');
      expect(find.text('Generated number'), findsNothing);
      await answer(tester, '8');
      expect(container.read(visionSessionProvider).stage, VisionStage.complete);
      expect(find.byKey(const ValueKey('vision-results')), findsOneWidget);
      expect(find.text('Review your 6 recorded responses'), findsOneWidget);
      expect(find.text('Not sure: 1'), findsOneWidget);
      const generated = ['2', '3', '4', '5', '6', '8'];
      const recorded = ['2', '0', '4', 'Not sure', '6', '8'];
      for (var i = 0; i < 6; i++) {
        final row = find.byKey(ValueKey('vision-result-${i + 1}'));
        expect(row, findsOneWidget);
        expect(
          find.descendant(of: row, matching: find.text('Generated number')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text('Your response')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(generated[i])),
          generated[i] == recorded[i] ? findsNWidgets(2) : findsOneWidget,
        );
        expect(
          find.descendant(of: row, matching: find.text(recorded[i])),
          generated[i] == recorded[i] ? findsNWidgets(2) : findsOneWidget,
        );
      }
      expect(find.text(caveat), findsOneWidget);
      expect(find.text(professional), findsOneWidget);
      expect(
        find.textContaining(
          RegExp(r'normal|deficien|pass|fail|severity', caseSensitive: false),
        ),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('vision-answer')), findsNothing);
    },
  );

  testWidgets(
    'pending draft survives Back reentry theme and leaves other drafts and saved data intact',
    (tester) async {
      final color = SavedColor(
        id: '#123456',
        hex: '#123456',
        name: 'Existing',
        isFavorite: true,
        createdAt: DateTime.utc(2026),
        source: ColorSource.manual,
      );
      final palette = SavedPalette(
        name: 'Existing',
        base: RgbColor(255, 0, 0),
        mode: HarmonyMode.complementary,
        colors: [RgbColor(255, 0, 0), RgbColor(0, 255, 255)],
        createdAt: DateTime.utc(2026),
      );
      final history = InMemoryColorHistoryRepository(colors: [color]);
      final palettes = InMemorySavedPaletteRepository(palettes: [palette]);
      final container = await launch(
        tester,
        history: history,
        palettes: palettes,
      );
      tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(120);
      await tester.pumpAndSettle();
      final labColor = tester
          .widget<ColorSwatchTile>(find.byType(ColorSwatchTile))
          .hex;
      container.read(mixerProvider.notifier).setWeight('color-0', 37);
      container
          .read(formulaTargetProvider.notifier)
          .setColor(RgbColor(1, 2, 3));
      container
          .read(harmonyDraftProvider.notifier)
          .setBase(RgbColor(0, 0, 255));
      container.read(matchingGameProvider.notifier).setHue(240);
      final mixer = container.read(mixerProvider);
      final harmony = container.read(harmonyDraftProvider);
      final matching = container.read(matchingGameProvider);
      await press(tester, 'open-vision');
      await press(tester, 'vision-start');
      await answer(tester, '2');
      await tester.enterText(find.byKey(const ValueKey('vision-answer')), '0');
      await tester.pumpAndSettle();
      final pending = container.read(visionSessionProvider);
      final field = tester
          .widget<TextField>(find.byKey(const ValueKey('vision-answer')))
          .controller!;
      field.selection = const TextSelection.collapsed(offset: 0);
      await container
          .read(appPreferencesProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      await tester.pumpAndSettle();
      expect(field.selection.baseOffset, 0);
      expect(container.read(visionSessionProvider), same(pending));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        labColor,
      );
      await press(tester, 'open-vision');
      expect(container.read(visionSessionProvider), same(pending));
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('vision-answer')))
            .controller!
            .text,
        '0',
      );
      for (var i = 1; i < 6; i++) {
        await press(tester, 'vision-not-sure');
      }
      final complete = container.read(visionSessionProvider);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await press(tester, 'open-vision');
      expect(container.read(visionSessionProvider), same(complete));
      await press(tester, 'vision-try-again');
      expect(container.read(mixerProvider), same(mixer));
      expect(container.read(harmonyDraftProvider), same(harmony));
      expect(container.read(matchingGameProvider), same(matching));
      expect(container.read(formulaTargetProvider).hex, '#010203');
      expect(await history.load(), [color]);
      expect(await palettes.load(), [palette]);
    },
  );

  testWidgets(
    'restart cancel and system Back preserve draft; confirm and Try again create active fresh sets',
    (tester) async {
      var generation = 0;
      final container = await launch(
        tester,
        path: '/vision',
        generator: () => fixture(seed: 100 + generation++ * 100),
      );
      await press(tester, 'vision-start');
      await tester.enterText(find.byKey(const ValueKey('vision-answer')), '7');
      await tester.pumpAndSettle();
      final draft = container.read(visionSessionProvider);
      await press(tester, 'vision-restart');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(visionSessionProvider), same(draft));
      await press(tester, 'vision-restart');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(container.read(visionSessionProvider), same(draft));
      await press(tester, 'vision-restart');
      await press(tester, 'confirm-vision-restart');
      expect(container.read(visionSessionProvider).currentPlate.seed, 200);
      expect(container.read(visionSessionProvider).draft, isNull);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('vision-answer')))
            .controller!
            .text,
        isEmpty,
      );
      for (var i = 0; i < 6; i++) {
        await press(tester, 'vision-not-sure');
      }
      await press(tester, 'vision-try-again');
      expect(container.read(visionSessionProvider).stage, VisionStage.active);
      expect(container.read(visionSessionProvider).responses, isEmpty);
      expect(container.read(visionSessionProvider).currentPlate.seed, 300);
      expect(generation, 3);
    },
  );

  // Check visibility after source-button taps; never scroll to the destination.
  testWidgets(
    'phone responses results and replay reset viewport to current entry',
    (tester) async {
      phone(tester);
      final container = await start(tester);
      for (var i = 0; i < 6; i++) {
        expect(offset(tester), 0);
        expect(find.text('Plate ${i + 1} of 6').hitTestable(), findsOneWidget);
        expect(
          tester
              .widget<VisionPlateView>(find.byType(VisionPlateView))
              .plate
              .seed,
          100 + i,
        );
        await press(tester, 'vision-not-sure');
      }
      expect(offset(tester), 0);
      expect(
        find.text('Review your 6 recorded responses').hitTestable(),
        findsOneWidget,
      );
      await press(tester, 'vision-try-again');
      expect(offset(tester), 0);
      expect(find.text('Plate 1 of 6').hitTestable(), findsOneWidget);
      expect(container.read(visionSessionProvider).draft, isNull);
    },
  );

  testWidgets('typing and theme preserve viewport while response resets it', (
    tester,
  ) async {
    phone(tester);
    final container = await start(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('vision-answer')));
    final before = offset(tester);
    expect(before, greaterThan(0));
    await tester.enterText(find.byKey(const ValueKey('vision-answer')), '7');
    await tester.pumpAndSettle();
    final typing = offset(tester);
    await container
        .read(appPreferencesProvider.notifier)
        .setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(offset(tester), typing);
    await tester.enterText(find.byKey(const ValueKey('vision-answer')), '3');
    await tester.pumpAndSettle();
    expect(offset(tester), typing);
    await press(tester, 'vision-record');
    expect(offset(tester), 0);
    expect(find.text('Plate 2 of 6').hitTestable(), findsOneWidget);
  });

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('vision fits 360px 2x reduced motion ${theme.name}', (
      tester,
    ) async {
      phone(tester, large: true);
      await launch(tester, path: '/vision', theme: theme);
      await press(tester, 'vision-start');
      expect(find.text('Plate 1 of 6').hitTestable(), findsOneWidget);
      for (final key in [
        'vision-record',
        'vision-not-sure',
        'vision-restart',
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        expect(
          tester.getSize(find.byKey(ValueKey(key))).height,
          greaterThanOrEqualTo(48),
        );
      }
      await press(tester, 'vision-restart');
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('confirm-vision-restart')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: dialog,
                matching: find.byType(SecondaryButton),
              ),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      for (final label in ['Restart activity', 'Cancel']) {
        final button = find.descendant(of: dialog, matching: find.text(label));
        await tester.ensureVisible(button);
        expect(button.hitTestable(), findsOneWidget);
      }
      await press(tester, 'confirm-vision-restart');
      expect(find.text('Plate 1 of 6').hitTestable(), findsOneWidget);
      for (var i = 0; i < 6; i++) {
        await press(tester, 'vision-not-sure');
      }
      expect(
        find.text('Review your 6 recorded responses').hitTestable(),
        findsOneWidget,
      );
      expect(find.text(caveat), findsOneWidget);
      await press(tester, 'vision-try-again');
      expect(find.text('Plate 1 of 6').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
