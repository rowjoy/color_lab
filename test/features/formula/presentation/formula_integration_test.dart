import 'dart:async';

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/formula/application/color_formula_service.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/formula/presentation/formula_screen.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/mixer/presentation/mixer_screen.dart';
import 'package:color_lab/features/picker/application/camera_session.dart';
import 'package:color_lab/features/picker/presentation/camera_picker_screen.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_screen.dart';
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
import '../../picker/camera_screen_test.dart' show FakeCameraSession;

ColorFormula _grayRecipe(RgbColor target) => ColorFormula(
  target: target,
  parts: [
    FormulaPart(
      base: FormulaBase(
        id: 'white',
        name: 'White',
        color: RgbColor(255, 255, 255),
      ),
      percent: 50,
    ),
    FormulaPart(
      base: FormulaBase(id: 'black', name: 'Black', color: RgbColor(0, 0, 0)),
      percent: 50,
    ),
  ],
);

// Replace only the expensive worker boundary, not recipe/state/UI behavior.
class _ImmediateService implements ColorFormulaService {
  @override
  Future<ColorFormula> find(RgbColor target) async => _grayRecipe(target);
}

class _ControlledService implements ColorFormulaService {
  final requests = <(RgbColor, Completer<ColorFormula>)>[];
  @override
  Future<ColorFormula> find(RgbColor target) {
    final completer = Completer<ColorFormula>();
    requests.add((target, completer));
    return completer.future;
  }
}

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    bool openFormula = true,
    bool settleResult = true,
    bool completed = true,
    ThemeMode mode = ThemeMode.light,
    RgbColor? target,
    ColorFormulaService? service,
    CameraSession Function()? cameraFactory,
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
          (ref) async => InMemoryColorHistoryRepository(),
        ),
        colorFormulaServiceProvider.overrideWithValue(
          service ?? _ImmediateService(),
        ),
        if (cameraFactory != null)
          cameraSessionFactoryProvider.overrideWithValue(cameraFactory),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([
            NamedColor('Gray blend', RgbColor(119, 119, 119)),
            NamedColor('Lilac', RgbColor.fromHex('#B2A4D4')),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (target != null) {
      container.read(formulaTargetProvider.notifier).setColor(target);
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (openFormula) {
      unawaited(container.read(appRouterProvider).push<void>('/formula'));
      if (settleResult) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
    }
    return container;
  }

  Future<void> pick(WidgetTester tester, String hex) async {
    await tester.ensureVisible(find.text('Choose target'));
    await tester.tap(find.text('Choose target'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byKey(const ValueKey('mixer-hex-input')), hex);
    await tester.ensureVisible(find.text('Use this color'));
    await tester.tap(find.text('Use this color'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'Lab entry retains formula target, HSL study and separate Mixer draft',
    (tester) async {
      final container = await launch(tester, openFormula: false);
      await tester.tap(find.byKey(const ValueKey('nav-Lab')));
      await tester.pumpAndSettle();
      tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(120);
      await tester.pumpAndSettle();
      final study = tester
          .widget<ColorSwatchTile>(find.byType(ColorSwatchTile))
          .hex;
      container.read(mixerProvider.notifier).setWeight('color-0', 37);
      final mix = container.read(mixerProvider);
      await tester.ensureVisible(find.text('Open color formula'));
      await tester.tap(find.text('Open color formula'));
      await tester.pumpAndSettle();
      expect(find.byType(FormulaScreen), findsOneWidget);
      expect(container.read(formulaTargetProvider).hex, '#B2A4D4');
      await pick(tester, '#00F');
      await tester.pumpAndSettle();
      expect(container.read(formulaTargetProvider).hex, '#0000FF');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        study,
      );
      expect(container.read(mixerProvider), mix);
      await tester.ensureVisible(find.text('Open color formula'));
      await tester.tap(find.text('Open color formula'));
      await tester.pumpAndSettle();
      expect(container.read(formulaTargetProvider).hex, '#0000FF');
    },
  );

  testWidgets(
    'selected mixed shade enters formula and repeated entry does not stack routes',
    (tester) async {
      final container = await launch(tester, openFormula: false);
      unawaited(container.read(appRouterProvider).push<void>('/mixer'));
      final mixer = container.read(mixerProvider.notifier);
      mixer.setColor('color-0', RgbColor(255, 0, 0));
      mixer.setColor('color-1', RgbColor(0, 0, 255));
      mixer.setSpace(MixingSpace.rgb);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Color details'));
      await tester.tap(find.text('Color details'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Find color formula'));
      await tester.tap(find.text('Find color formula'));
      await tester.pumpAndSettle();
      expect(find.byType(FormulaScreen), findsOneWidget);
      expect(find.byType(ColorDetails), findsNothing);
      expect(container.read(formulaTargetProvider).hex, '#800080');
      await tester.ensureVisible(
        find.byKey(const ValueKey('formula-result-swatch')),
      );
      await tester.tap(find.byKey(const ValueKey('formula-result-swatch')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Find color formula'));
      await tester.tap(find.text('Find color formula'));
      await tester.pumpAndSettle();
      expect(container.read(formulaTargetProvider).hex, '#777777');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(MixerScreen), findsOneWidget);
      expect(container.read(mixerProvider).selectedResult?.hex, '#800080');
    },
  );

  testWidgets(
    'camera stays paused through formula and samples afresh after Back',
    (tester) async {
      final cameras = <FakeCameraSession>[];
      final container = await launch(
        tester,
        openFormula: false,
        cameraFactory: () {
          final camera = FakeCameraSession();
          cameras.add(camera);
          return camera;
        },
      );
      await tester.ensureVisible(find.text('Open camera'));
      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraPickerScreen), findsOneWidget);
      expect(cameras, hasLength(1));
      expect(cameras.single.starts, 1);
      cameras.single.emit!(RgbColor(255, 0, 0));
      await tester.pumpAndSettle();
      expect(find.text('#FF0000'), findsOneWidget);
      await tester.ensureVisible(find.text('Color details'));
      await tester.tap(find.text('Color details'));
      await tester.pumpAndSettle();
      expect(find.byType(ColorDetails), findsOneWidget);
      expect(find.text('255, 0, 0'), findsOneWidget);
      expect(cameras.single.stops, 1);
      await tester.ensureVisible(find.text('Find color formula'));
      await tester.tap(find.text('Find color formula'));
      await tester.pumpAndSettle();
      expect(find.byType(FormulaScreen), findsOneWidget);
      expect(find.byType(ColorDetails), findsNothing);
      expect(container.read(formulaTargetProvider).hex, '#FF0000');
      expect(
        tester
            .widget<ColorSwatchTile>(
              find.byKey(const ValueKey('formula-target-swatch')),
            )
            .hex,
        '#FF0000',
      );
      expect(
        cameras,
        hasLength(1),
        reason: 'No camera restarts behind Formula',
      );
      expect(cameras.single.starts, 1);
      expect(cameras.single.stops, 1);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(CameraPickerScreen), findsOneWidget);
      expect(cameras, hasLength(2), reason: 'Returning resumes fresh sampling');
      expect(cameras.first.disposals, 1);
      expect(cameras.last.starts, 1);
      expect(find.text('#FF0000'), findsNothing);
      cameras.last.emit!(RgbColor(0, 0, 255));
      await tester.pumpAndSettle();
      expect(find.text('#0000FF').hitTestable(), findsOneWidget);
      expect(find.textContaining('RGB 0, 0, 255'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recipe shows positive percentages, actual blend/error and digital caveat',
    (tester) async {
      await launch(tester, target: RgbColor(119, 119, 119));
      expect(
        tester
            .widget<ColorSwatchTile>(
              find.byKey(const ValueKey('formula-target-swatch')),
            )
            .hex,
        '#777777',
      );
      expect(
        tester
            .widget<ColorSwatchTile>(
              find.byKey(const ValueKey('formula-result-swatch')),
            )
            .hex,
        '#777777',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('formula-error-value')))
            .data,
        '0.00',
      );
      expect(find.text('50%'), findsNWidgets(2));
      expect(find.textContaining('not a paint recipe'), findsOneWidget);
      final bar = tester.widget<PaletteBar>(find.byType(PaletteBar));
      expect(bar.weights, [50, 50]);
      await tester.ensureVisible(find.text('Our digital bases'));
      await tester.tap(find.text('Our digital bases'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('formula-base-paynes-gray')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cancelled target choice leaves current target and recipe unchanged',
    (tester) async {
      final container = await launch(tester);
      final target = container.read(formulaTargetProvider);
      await tester.ensureVisible(find.text('Choose target'));
      await tester.tap(find.text('Choose target'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('mixer-hex-input')),
        '#F00',
      );
      await tester.tap(find.byTooltip('Close color picker'));
      await tester.pumpAndSettle();
      expect(container.read(formulaTargetProvider), target);
      expect(
        find.byKey(const ValueKey('formula-result-swatch')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'new target hides a successful result recipe and save until it completes',
    (tester) async {
      final service = _ControlledService();
      final container = await launch(
        tester,
        service: service,
        settleResult: false,
      );
      service.requests.single.$2.complete(
        _grayRecipe(service.requests.single.$1),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ColorSwatchTile>(
              find.byKey(const ValueKey('formula-result-swatch')),
            )
            .hex,
        '#777777',
      );
      expect(
        find.byKey(const ValueKey('formula-recipe-heading')),
        findsOneWidget,
      );
      expect(find.text('Save color'), findsOneWidget);

      await pick(tester, '#F00');
      expect(container.read(formulaTargetProvider).hex, '#FF0000');
      expect(service.requests, hasLength(2));
      expect(service.requests.last.$1.hex, '#FF0000');
      expect(find.byKey(const ValueKey('formula-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('formula-result-swatch')), findsNothing);
      expect(
        find.byKey(const ValueKey('formula-recipe-heading')),
        findsNothing,
      );
      expect(find.byType(PaletteBar), findsNothing);
      expect(find.text('Save color'), findsNothing);
      expect(find.text('Blend details'), findsNothing);

      service.requests.last.$2.complete(
        ColorFormula(
          target: RgbColor(255, 0, 0),
          parts: [
            FormulaPart(
              base: FormulaBase(
                id: 'red',
                name: 'Red',
                color: RgbColor(255, 0, 0),
              ),
              percent: 100,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('formula-loading')), findsNothing);
      expect(
        tester
            .widget<ColorSwatchTile>(
              find.byKey(const ValueKey('formula-result-swatch')),
            )
            .hex,
        '#FF0000',
      );
      expect(
        find.byKey(const ValueKey('formula-recipe-heading')),
        findsOneWidget,
      );
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Save color'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'refreshing a successful key hides its result recipe and save until recovery',
    (tester) async {
      final service = _ControlledService();
      final container = await launch(
        tester,
        service: service,
        settleResult: false,
      );
      final target = container.read(formulaTargetProvider);
      service.requests.single.$2.complete(_grayRecipe(target));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ColorSwatchTile>(
              find.byKey(const ValueKey('formula-result-swatch')),
            )
            .hex,
        '#777777',
      );
      expect(
        find.byKey(const ValueKey('formula-recipe-heading')),
        findsOneWidget,
      );
      expect(find.text('Save color'), findsOneWidget);

      container.invalidate(formulaResultProvider(target));
      await tester.pump();
      expect(service.requests, hasLength(2));
      expect(service.requests.last.$1, target);
      expect(container.read(formulaTargetProvider), target);
      expect(find.byKey(const ValueKey('formula-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('formula-result-swatch')), findsNothing);
      expect(
        find.byKey(const ValueKey('formula-recipe-heading')),
        findsNothing,
      );
      expect(find.byType(PaletteBar), findsNothing);
      expect(find.text('Save color'), findsNothing);
      expect(find.text('Blend details'), findsNothing);

      service.requests.last.$2.complete(
        ColorFormula(
          target: target,
          parts: [
            FormulaPart(
              base: FormulaBase(
                id: 'white',
                name: 'White',
                color: RgbColor(255, 255, 255),
              ),
              percent: 100,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('formula-loading')), findsNothing);
      expect(
        tester
            .widget<ColorSwatchTile>(
              find.byKey(const ValueKey('formula-result-swatch')),
            )
            .hex,
        '#FFFFFF',
      );
      expect(container.read(formulaTargetProvider), target);
      expect(
        find.byKey(const ValueKey('formula-recipe-heading')),
        findsOneWidget,
      );
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Save color'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late failure of an old target cannot replace the new search', (
    tester,
  ) async {
    final service = _ControlledService();
    final container = await launch(
      tester,
      service: service,
      settleResult: false,
    );
    expect(find.byKey(const ValueKey('formula-loading')), findsOneWidget);
    await pick(tester, '#F00');
    expect(service.requests.length, 2);
    expect(find.byKey(const ValueKey('formula-result-swatch')), findsNothing);
    service.requests.first.$2.completeError(
      StateError('private worker failure'),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('formula-loading')), findsOneWidget);
    expect(find.text('Retry formula'), findsNothing);
    service.requests.last.$2.complete(_grayRecipe(RgbColor(255, 0, 0)));
    await tester.pumpAndSettle();
    expect(container.read(formulaTargetProvider).hex, '#FF0000');
    expect(find.byKey(const ValueKey('formula-result-swatch')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'worker failure exposes safe retry and leaves target choice available',
    (tester) async {
      final service = _ControlledService();
      await launch(tester, service: service, settleResult: false);
      service.requests.single.$2.completeError(
        StateError('private worker failure'),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('private worker'), findsNothing);
      expect(find.text('Choose target'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry formula'));
      await tester.tap(find.text('Retry formula'));
      await tester.pump();
      expect(service.requests.length, 2);
      service.requests.last.$2.complete(_grayRecipe(service.requests.last.$1));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('formula-result-swatch')),
        findsOneWidget,
      );
      expect(find.text('Retry formula'), findsNothing);
    },
  );

  testWidgets('save/details/Room use approximate result rather than target', (
    tester,
  ) async {
    final container = await launch(tester, target: RgbColor(255, 0, 0));
    await tester.ensureVisible(find.text('Save color'));
    await tester.tap(find.text('Save color'));
    await tester.pumpAndSettle();
    final saved = container.read(colorHistoryProvider).requireValue.single;
    expect(saved.hex, '#777777');
    expect(saved.source.name, 'lab');
    await tester.ensureVisible(
      find.byKey(const ValueKey('formula-result-swatch')),
    );
    await tester.tap(find.byKey(const ValueKey('formula-result-swatch')));
    await tester.pumpAndSettle();
    expect(find.text('119, 119, 119'), findsOneWidget);
    await tester.ensureVisible(find.text('Use in Room'));
    await tester.tap(find.text('Use in Room'));
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).state.uri.path,
      '/room/illustrated/study',
    );
    expect(container.read(roomColorProvider).hex, '#777777');
    final room = container.read(illustratedRoomProvider).draftFor('study')!;
    expect(room.colors!.wall.hex, '#777777');
    expect(room.colors!.ceiling.hex, '#F8F4EB');
    expect(room.colors!.floor.hex, '#C6AC84');
    expect(room.colors!.furniture.hex, '#654A39');
    expect(find.byType(IllustratedRoomScreen), findsOneWidget);
  });

  testWidgets('formula root route obeys first-run guard', (tester) async {
    await launch(tester, completed: false);
    expect(find.byType(FormulaScreen), findsNothing);
    expect(find.text('Find your next shade.'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'formula and target picker fit360px2x reduced-motion ${mode.name}',
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
              .widget<ExpansionTile>(find.byType(ExpansionTile))
              .expansionAnimationStyle
              ?.duration,
          Duration.zero,
        );
        await tester.ensureVisible(find.text('Our digital bases'));
        await tester.tap(find.text('Our digital bases'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Choose target'));
        await tester.tap(find.text('Choose target'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Use this color'));
        expect(find.text('Use this color').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
