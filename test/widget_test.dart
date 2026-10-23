import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/settings/application/theme_mode_provider.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_color_history_repository.dart';
import 'support/in_memory_app_preferences_repository.dart';
import 'support/in_memory_acquisition_intent_store.dart';

void main() {
  Future<ProviderContainer> launch(WidgetTester tester) async {
    final repository = InMemoryColorHistoryRepository();
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(),
        ),
        colorHistoryRepositoryProvider.overrideWith((ref) async => repository),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([
            NamedColor('Red', RgbColor(255, 0, 0)),
            NamedColor('Lilac Haze', RgbColor.fromHex('#B2A4D4')),
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
    return container;
  }

  testWidgets('starts in Capture and opens each destination', (tester) async {
    await launch(tester);
    expect(find.text('See the world'), findsOneWidget);
    for (final destination in ['Palette', 'Lab', 'Room', 'Capture']) {
      await tester.tap(find.byKey(ValueKey('nav-$destination')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('screen-$destination')), findsOneWidget);
    }
  });

  testWidgets('manual color entry validates and opens actual color values', (
    tester,
  ) async {
    await launch(tester);
    await tester.ensureVisible(find.text('Explore a color'));
    await tester.tap(find.text('Explore a color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hex-input')), 'oops');
    await tester.tap(find.text('View color'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a 3 or 6 digit HEX color.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('hex-input')), '#FF0000');
    await tester.tap(find.text('View color'));
    await tester.pumpAndSettle();
    expect(find.text('#FF0000'), findsWidgets);
    expect(find.text('255, 0, 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme state changes the application theme', (tester) async {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(),
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => InMemoryColorHistoryRepository(),
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
    container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    final context = tester.element(
      find.byKey(const ValueKey('screen-Capture')),
    );
    expect(Theme.of(context).brightness, Brightness.dark);
    container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('a manually saved shade appears in the Palette library', (
    tester,
  ) async {
    final container = await launch(tester);
    await tester.ensureVisible(find.text('Explore a color'));
    await tester.tap(find.text('Explore a color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('hex-input')), '#FF0000');
    await tester.tap(find.text('View color'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save color'));
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    expect(find.text('Saved to library'), findsOneWidget);
    final saved = container.read(colorHistoryProvider).requireValue.single;
    expect(saved.hex, '#FF0000');
    expect(saved.source.name, 'manual');
    await tester.ensureVisible(find.byTooltip('Close color details'));
    await tester.tap(find.byTooltip('Close color details'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-Palette')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('saved-#FF0000')), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
  });

  testWidgets(
    'appearance menu changes theme and lab study survives tab switches',
    (tester) async {
      await launch(tester);
      await tester.tap(find.byTooltip('Appearance settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      final pageContext = tester.element(
        find.byKey(const ValueKey('screen-Capture')),
      );
      expect(Theme.of(pageContext).brightness, Brightness.dark);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-Lab')));
      await tester.pumpAndSettle();
      final slider = find.byType(Slider).first;
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(50, 0));
      await tester.pumpAndSettle();
      final study = tester.widget<ColorSwatchTile>(
        find.byType(ColorSwatchTile),
      );
      expect(study.hex, isNot('#B2A4D4'));
      await tester.tap(find.byKey(const ValueKey('nav-Palette')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-Lab')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        study.hex,
      );
    },
  );

  testWidgets('all destinations fit a narrow phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester);
    for (final destination in ['Palette', 'Lab', 'Room', 'Capture']) {
      await tester.tap(find.byKey(ValueKey('nav-$destination')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: destination);
    }
  });

  testWidgets('color entry opens immediately when reduced motion is enabled', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester);
    await tester.ensureVisible(find.text('Explore a color'));
    await tester.tap(find.text('Explore a color'));
    await tester.pump();
    await tester.pump();
    expect(find.text('View color').hitTestable(), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pump();
    expect(find.text('View color'), findsNothing);
  });

  testWidgets(
    'Lab preserves the chosen hue while saturation passes through gray',
    (tester) async {
      await launch(tester);
      await tester.tap(find.byKey(const ValueKey('nav-Lab')));
      await tester.pumpAndSettle();
      var sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      final originalHue = sliders[0].value;
      sliders[1].onChanged!(0);
      await tester.pumpAndSettle();
      sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders[0].value, originalHue);
      sliders[0].onChanged!(120);
      await tester.pumpAndSettle();
      sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders[0].value, 120);
      sliders[1].onChanged!(.5);
      await tester.pumpAndSettle();
      expect(tester.widgetList<Slider>(find.byType(Slider)).first.value, 120);
    },
  );
}
