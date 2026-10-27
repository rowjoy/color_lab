import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/mixer/presentation/mixer_screen.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
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

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    bool openMixer = true,
    ThemeMode mode = ThemeMode.light,
    bool completed = true,
    InMemoryColorHistoryRepository? history,
  }) async {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(
            initial: AppPreferences(
              themeMode: mode,
              onboardingCompleted: completed,
            ),
          ),
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => history ?? InMemoryColorHistoryRepository(),
        ),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([
            NamedColor('Purple', RgbColor.fromHex('#800080')),
            NamedColor('Lilac', RgbColor.fromHex('#B2A4D4')),
            NamedColor('Gray', RgbColor.fromHex('#808080')),
          ]),
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
    if (openMixer) {
      container.read(appRouterProvider).push('/mixer');
      await tester.pumpAndSettle();
    }
    return container;
  }

  Slider slider(WidgetTester tester, String id) => tester.widget<Slider>(
    find.descendant(
      of: find.byKey(ValueKey('mixer-weight-$id')),
      matching: find.byType(Slider),
    ),
  );
  String selectedHex(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('mixer-result-hex'))).data!;

  testWidgets(
    'Lab entry preserves HSL study and mixer draft through navigation',
    (tester) async {
      final container = await launch(tester, openMixer: false);
      final learn = find.byKey(const ValueKey('nav-learn'));
      expect(learn, findsOneWidget);
      await tester.tap(learn);
      await tester.pumpAndSettle();
      final openLab = find.byKey(const ValueKey('learn-open-lab'));
      expect(openLab, findsOneWidget);
      await tester.ensureVisible(openLab);
      await tester.tap(openLab);
      await tester.pumpAndSettle();
      tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(120);
      await tester.pumpAndSettle();
      final study = tester
          .widget<ColorSwatchTile>(find.byType(ColorSwatchTile))
          .hex;
      await tester.ensureVisible(find.text('Open color mixer'));
      await tester.tap(find.text('Open color mixer'));
      await tester.pumpAndSettle();
      expect(find.byType(MixerScreen), findsOneWidget);
      container.read(mixerProvider.notifier).setWeight('color-0', 23);
      container.read(mixerProvider.notifier).setSpace(MixingSpace.rgb);
      await tester.pumpAndSettle();
      final draft = container.read(mixerProvider);
      await tester.tap(find.byTooltip('Back to Lab'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        study,
      );
      await tester.ensureVisible(find.text('Open color mixer'));
      await tester.tap(find.text('Open color mixer'));
      await tester.pumpAndSettle();
      expect(container.read(mixerProvider), draft);
    },
  );

  testWidgets(
    'mode toggles actual LAB and RGB results while ratios update live',
    (tester) async {
      final container = await launch(tester);
      final controller = container.read(mixerProvider.notifier);
      controller.setColor('color-0', RgbColor(0, 0, 0));
      controller.setColor('color-1', RgbColor(255, 255, 255));
      await tester.pumpAndSettle();
      expect(selectedHex(tester), '#777777');
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mixer-rgb-hex'))).data,
        '#808080',
      );
      await tester.tap(find.byKey(const ValueKey('mixer-space-rgb')));
      await tester.pumpAndSettle();
      expect(selectedHex(tester), '#808080');
      slider(tester, 'color-0').onChanged!(25);
      slider(tester, 'color-1').onChanged!(75);
      await tester.pumpAndSettle();
      expect(selectedHex(tester), '#BFBFBF');
      expect(container.read(mixerProvider).fractions, [.25, .75]);
    },
  );

  testWidgets(
    'live result stays visible and opens the updated color while moving parts',
    (tester) async {
      final container = await launch(tester);
      final controller = container.read(mixerProvider.notifier);
      controller.setColor('color-0', RgbColor(0, 0, 0));
      controller.setColor('color-1', RgbColor(255, 255, 255));
      controller.setSpace(MixingSpace.rgb);
      await tester.pumpAndSettle();
      final input = find.descendant(
        of: find.byKey(const ValueKey('mixer-weight-color-1')),
        matching: find.byType(Slider),
      );
      await tester.ensureVisible(input);
      expect(
        find.byKey(const ValueKey('mixer-live-hex')).hitTestable(),
        findsOneWidget,
      );
      await tester.drag(input, const Offset(400, 0));
      await tester.pumpAndSettle();
      expect(container.read(mixerProvider).ingredients.last.weight, 100);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('mixer-live-hex'))).data,
        '#AAAAAA',
      );
      await tester.tap(find.byTooltip('View mixed color'));
      await tester.pumpAndSettle();
      expect(find.byType(ColorDetails), findsOneWidget);
      expect(find.text('170, 170, 170'), findsOneWidget);
    },
  );

  testWidgets(
    'zero total removes result and save actions until a part is restored',
    (tester) async {
      await launch(tester);
      slider(tester, 'color-0').onChanged!(0);
      slider(tester, 'color-1').onChanged!(0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mixer-result-hex')), findsNothing);
      expect(find.byKey(const ValueKey('mixer-empty-result')), findsOneWidget);
      expect(find.text('Save color'), findsNothing);
      expect(find.text('Color details'), findsNothing);
      expect(find.byKey(const ValueKey('mixer-live-hex')), findsNothing);
      slider(tester, 'color-1').onChanged!(100);
      await tester.pumpAndSettle();
      expect(selectedHex(tester), '#E8DAA9');
      final bars = tester.widgetList<PaletteBar>(find.byType(PaletteBar));
      expect(bars.single.colors.length, 1);
    },
  );

  testWidgets(
    'manual input edits and adds real colors without applying cancelled choices',
    (tester) async {
      final container = await launch(tester);
      await tester.ensureVisible(find.byTooltip('Edit color 1'));
      await tester.tap(find.byTooltip('Edit color 1'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('mixer-hex-input')),
        '#F00',
      );
      await tester.ensureVisible(find.text('Use this color'));
      await tester.tap(find.text('Use this color'));
      await tester.pumpAndSettle();
      expect(
        container.read(mixerProvider).ingredients.first.color.hex,
        '#FF0000',
      );
      final draft = container.read(mixerProvider);
      await tester.ensureVisible(find.text('Add a color'));
      await tester.tap(find.text('Add a color'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close color picker'));
      await tester.pumpAndSettle();
      expect(container.read(mixerProvider), draft);
      await tester.tap(find.text('Add a color'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('mixer-hex-input')),
        '#00F',
      );
      await tester.ensureVisible(find.text('Use this color'));
      await tester.tap(find.text('Use this color'));
      await tester.pumpAndSettle();
      expect(container.read(mixerProvider).ingredients.length, 3);
      expect(
        container.read(mixerProvider).ingredients.last.color.hex,
        '#0000FF',
      );
    },
  );

  testWidgets(
    'minimum two colors and confirmed reset preserve deliberate choices',
    (tester) async {
      final container = await launch(tester);
      final remove = find.byTooltip('Remove color 1');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(container.read(mixerProvider).ingredients.length, 2);
      container.read(mixerProvider.notifier).setWeight('color-0', 10);
      container.read(mixerProvider.notifier).addColor(RgbColor(255, 0, 0));
      await tester.pumpAndSettle();
      final draft = container.read(mixerProvider);
      await tester.tap(find.byTooltip('Reset mix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(mixerProvider), draft);
      await tester.tap(find.byTooltip('Reset mix'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-reset-mix')));
      await tester.pumpAndSettle();
      expect(container.read(mixerProvider).ingredients.length, 2);
      expect(container.read(mixerProvider).ingredients.first.weight, 50);
      expect(container.read(mixerProvider).space, MixingSpace.lab);
    },
  );

  testWidgets('save and details use the selected result with Lab source', (
    tester,
  ) async {
    final container = await launch(tester);
    final controller = container.read(mixerProvider.notifier);
    controller.setColor('color-0', RgbColor(255, 0, 0));
    controller.setColor('color-1', RgbColor(0, 0, 255));
    controller.setSpace(MixingSpace.rgb);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save color'));
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    final saved = container.read(colorHistoryProvider).requireValue.single;
    expect(saved.hex, '#800080');
    expect(saved.source.name, 'lab');
    await tester.ensureVisible(find.text('Color details'));
    await tester.tap(find.text('Color details'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorDetails), findsOneWidget);
    expect(find.text('128, 0, 128'), findsOneWidget);
  });

  testWidgets('mixer route is subject to the first-run guard', (tester) async {
    final container = await launch(tester, openMixer: false, completed: false);
    container.read(appRouterProvider).go('/mixer');
    await tester.pumpAndSettle();
    expect(find.byType(MixerScreen), findsNothing);
    expect(find.text('Find your next shade.'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'mixer fits360px with2x text and reduced motion in ${mode.name}',
      (tester) async {
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
        await launch(tester, mode: mode);
        expect(
          tester
              .widget<TweenAnimationBuilder<Color?>>(
                find.descendant(
                  of: find.byKey(const ValueKey('mixer-result-swatch')),
                  matching: find.byType(TweenAnimationBuilder<Color?>),
                ),
              )
              .duration,
          Duration.zero,
        );
        await tester.ensureVisible(find.text('Add a color'));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Add a color'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Use this color'));
        expect(find.text('Use this color').hitTestable(), findsOneWidget);
      },
    );
  }
}
