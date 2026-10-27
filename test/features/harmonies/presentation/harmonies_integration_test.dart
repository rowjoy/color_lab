import 'dart:async';
import 'dart:io';

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/data/db/hive_palette_repository.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/harmonies/presentation/harmonies_screen.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/mixer/application/mixer_controller.dart';
import 'package:color_lab/features/mixer/presentation/mixer_screen.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/palette/domain/saved_palette_repository.dart';
import 'package:color_lab/features/picker/application/camera_session.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/room_studio/application/room_color_provider.dart';
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
import '../../picker/camera_screen_test.dart' show FakeCameraSession;

SavedPalette _saved({String name = 'Red balance', List<RgbColor>? colors}) =>
    SavedPalette(
      name: name,
      base: RgbColor(255, 0, 0),
      mode: HarmonyMode.complementary,
      colors: colors ?? [RgbColor(255, 0, 0), RgbColor(0, 255, 255)],
      createdAt: DateTime.utc(2026, 10, 21),
    );

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    String? path = '/harmonies',
    bool completed = true,
    ThemeMode theme = ThemeMode.light,
    SavedPaletteRepository? repository,
    CameraSession Function()? cameraFactory,
    bool preload = false,
  }) async {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(
            initial: AppPreferences(
              themeMode: theme,
              onboardingCompleted: completed,
            ),
          ),
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => InMemoryColorHistoryRepository(),
        ),
        savedPaletteRepositoryProvider.overrideWith(
          (ref) async => repository ?? InMemorySavedPaletteRepository(),
        ),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([
            NamedColor('Red', RgbColor(255, 0, 0)),
            NamedColor('Cyan', RgbColor(0, 255, 255)),
            NamedColor('Lilac', RgbColor.fromHex('#B2A4D4')),
          ]),
        ),
        if (cameraFactory != null)
          cameraSessionFactoryProvider.overrideWithValue(cameraFactory),
      ],
    );
    addTearDown(container.dispose);
    if (preload) {
      await tester.runAsync(() => container.read(savedPalettesProvider.future));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (path != null) {
      unawaited(container.read(appRouterProvider).push<void>(path));
      await tester.pumpAndSettle();
    }
    return container;
  }

  Future<void> choose(WidgetTester tester, String hex) async {
    await tester.ensureVisible(find.text('Choose base color'));
    await tester.tap(find.text('Choose base color'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mixer-hex-input')), hex);
    await tester.ensureVisible(find.text('Use this color'));
    await tester.tap(find.text('Use this color'));
    await tester.pumpAndSettle();
  }

  Future<void> beginSave(
    WidgetTester tester,
    String name, {
    bool submit = true,
  }) async {
    await tester.ensureVisible(find.text('Save palette'));
    await tester.tap(find.text('Save palette'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('palette-name-input')),
      name,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('confirm-save-palette')),
    );
    if (submit) {
      await tester.tap(find.byKey(const ValueKey('confirm-save-palette')));
    }
    await tester.pump();
  }

  testWidgets(
    'six mode chips show actual HSL shades and collapse neutral duplicates',
    (tester) async {
      await launch(tester);
      await choose(tester, '#F00');
      const fixtures = {
        'complementary': ['#FF0000', '#00FFFF'],
        'analogous': ['#FF0000', '#FF0080', '#FF8000'],
        'triadic': ['#FF0000', '#00FF00', '#0000FF'],
        'tetradic': ['#FF0000', '#80FF00', '#00FFFF', '#8000FF'],
        'splitComplementary': ['#FF0000', '#00FF80', '#0080FF'],
      };
      for (final entry in fixtures.entries) {
        final chip = find.byKey(ValueKey('harmony-mode-${entry.key}'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        for (final hex in entry.value) {
          expect(find.byKey(ValueKey('harmony-swatch-$hex')), findsOneWidget);
        }
        expect(
          tester.widget<PaletteBar>(find.byType(PaletteBar)).colors.length,
          entry.value.length,
        );
      }
      await choose(tester, '#808080');
      expect(
        tester.widget<PaletteBar>(find.byType(PaletteBar)).colors.length,
        1,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('harmony-mode-monochromatic')),
      );
      await tester.tap(
        find.byKey(const ValueKey('harmony-mode-monochromatic')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<PaletteBar>(find.byType(PaletteBar)).colors.length,
        5,
      );
    },
  );

  testWidgets(
    'Lab entry and picker cancellation preserve all separate session drafts',
    (tester) async {
      final container = await launch(tester, path: null);
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
      final hsl = tester
          .widget<ColorSwatchTile>(find.byType(ColorSwatchTile))
          .hex;
      container.read(mixerProvider.notifier).setWeight('color-0', 37);
      container
          .read(formulaTargetProvider.notifier)
          .setColor(RgbColor(1, 2, 3));
      final mixer = container.read(mixerProvider);
      await tester.ensureVisible(find.text('Open harmonies'));
      await tester.tap(find.text('Open harmonies'));
      await tester.pumpAndSettle();
      await choose(tester, '#00F');
      await tester.ensureVisible(
        find.byKey(const ValueKey('harmony-mode-triadic')),
      );
      await tester.tap(find.byKey(const ValueKey('harmony-mode-triadic')));
      await tester.pumpAndSettle();
      final draft = container.read(harmonyDraftProvider);
      await tester.ensureVisible(find.text('Choose base color'));
      await tester.tap(find.text('Choose base color'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('mixer-hex-input')),
        '#F00',
      );
      await tester.tap(find.byTooltip('Close color picker'));
      await tester.pumpAndSettle();
      expect(container.read(harmonyDraftProvider), draft);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        hsl,
      );
      expect(container.read(mixerProvider), mixer);
      expect(container.read(formulaTargetProvider).hex, '#010203');
      await tester.ensureVisible(find.text('Open harmonies'));
      await tester.tap(find.text('Open harmonies'));
      await tester.pumpAndSettle();
      expect(container.read(harmonyDraftProvider), draft);
    },
  );

  testWidgets(
    'common details use exact selected shade and update harmony without stacking',
    (tester) async {
      final container = await launch(tester, path: '/mixer');
      final mix = container.read(mixerProvider.notifier);
      mix.setColor('color-0', RgbColor(255, 0, 0));
      mix.setColor('color-1', RgbColor(0, 0, 255));
      mix.setSpace(MixingSpace.rgb);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Color details'));
      await tester.tap(find.text('Color details'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Explore harmonies'));
      await tester.tap(find.text('Explore harmonies'));
      await tester.pumpAndSettle();
      expect(container.read(harmonyDraftProvider).base.hex, '#800080');
      await tester.ensureVisible(
        find.byKey(const ValueKey('harmony-mode-triadic')),
      );
      await tester.tap(find.byKey(const ValueKey('harmony-mode-triadic')));
      await tester.pumpAndSettle();
      final shade = find.byKey(const ValueKey('harmony-swatch-#808000'));
      await tester.ensureVisible(shade);
      await tester.tap(shade);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Explore harmonies'));
      await tester.tap(find.text('Explore harmonies'));
      await tester.pumpAndSettle();
      expect(container.read(harmonyDraftProvider).base.hex, '#808000');
      expect(container.read(harmonyDraftProvider).mode, HarmonyMode.triadic);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(MixerScreen), findsOneWidget);
    },
  );

  testWidgets(
    'named save validates blank names, persists a whole palette and deduplicates',
    (tester) async {
      final repository = InMemorySavedPaletteRepository();
      final container = await launch(tester, repository: repository);
      await choose(tester, '#F00');
      await beginSave(tester, '   ');
      await tester.pumpAndSettle();
      expect(find.text('Give this palette a name.'), findsOneWidget);
      expect(await repository.load(), isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('palette-name-input')),
        '  Red balance  ',
      );
      await tester.tap(find.byKey(const ValueKey('confirm-save-palette')));
      await tester.pumpAndSettle();
      final palette = container.read(savedPalettesProvider).requireValue.single;
      expect(palette.name, 'Red balance');
      expect(palette.colors.map((color) => color.hex), ['#FF0000', '#00FFFF']);
      expect(find.text('Palette saved'), findsOneWidget);
      await container
          .read(savedPalettesProvider.notifier)
          .savePalette(
            name: 'Duplicate name',
            base: palette.base,
            mode: palette.mode,
            colors: palette.colors,
          );
      expect((await repository.load()).single.name, 'Red balance');
    },
  );

  testWidgets(
    'save cancellation and failed write never claim success; retry keeps name',
    (tester) async {
      final repository = InMemorySavedPaletteRepository();
      await launch(tester, repository: repository);
      await tester.ensureVisible(find.text('Save palette'));
      await tester.tap(find.text('Save palette'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await repository.load(), isEmpty);
      repository.failWrites = true;
      await beginSave(tester, 'Lilac friends');
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't save this palette"), findsOneWidget);
      expect(find.text('Palette saved'), findsNothing);
      expect(await repository.load(), isEmpty);
      repository.failWrites = false;
      await tester.tap(find.byKey(const ValueKey('confirm-save-palette')));
      await tester.pumpAndSettle();
      expect((await repository.load()).single.name, 'Lilac friends');
    },
  );

  testWidgets(
    'pending save captures its original draft, not a later selection',
    (tester) async {
      final repository = InMemorySavedPaletteRepository()
        ..writeGate = Completer<void>();
      final container = await launch(tester, repository: repository);
      await choose(tester, '#F00');
      await beginSave(tester, 'Original red');
      container
          .read(harmonyDraftProvider.notifier)
          .setSelection(base: RgbColor(0, 0, 255), mode: HarmonyMode.triadic);
      await tester.pump();
      repository.writeGate!.complete();
      await tester.pumpAndSettle();
      final saved = (await repository.load()).single;
      expect(saved.base.hex, '#FF0000');
      expect(saved.mode, HarmonyMode.complementary);
      expect(saved.colors.map((color) => color.hex), ['#FF0000', '#00FFFF']);
      expect(container.read(harmonyDraftProvider).base.hex, '#0000FF');
      expect(find.text('Palette saved'), findsNothing);
      expect(find.text('Save palette'), findsOneWidget);
    },
  );

  testWidgets(
    'base picker returns an exact saved shade without editing color filters',
    (tester) async {
      final container = await launch(tester);
      await container
          .read(colorHistoryProvider.notifier)
          .saveColor(RgbColor.fromHex('#123456'), name: 'Stored blue');
      container.read(historyFilterProvider.notifier).setQuery('unchanged');
      final mode = container.read(harmonyDraftProvider).mode;
      await tester.ensureVisible(find.text('Choose base color'));
      await tester.tap(find.text('Choose base color'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('mixer-saved-#123456')),
      );
      await tester.tap(find.byKey(const ValueKey('mixer-saved-#123456')));
      await tester.pumpAndSettle();
      expect(container.read(harmonyDraftProvider).base.hex, '#123456');
      expect(container.read(harmonyDraftProvider).mode, mode);
      expect(container.read(historyFilterProvider).query, 'unchanged');
      expect(
        container.read(colorHistoryProvider).requireValue.single.hex,
        '#123456',
      );
    },
  );

  testWidgets('failed palette delete retains the snapshot and can be retried', (
    tester,
  ) async {
    final stored = _saved();
    final repository = InMemorySavedPaletteRepository(palettes: [stored])
      ..failWrites = true;
    await launch(tester, path: '/palettes', repository: repository);
    await tester.tap(find.byTooltip('Delete Red balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-palette')));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not delete this palette. Try again.'),
      findsOneWidget,
    );
    expect(await repository.load(), [stored]);
    expect(find.text('Red balance'), findsOneWidget);
    repository.failWrites = false;
    await tester.tap(find.byTooltip('Delete Red balance'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-palette')));
    await tester.pumpAndSettle();
    expect(await repository.load(), isEmpty);
    expect(
      find.text('Could not delete this palette. Try again.'),
      findsNothing,
    );
  });

  testWidgets(
    'a different stored snapshot never claims the current harmony was saved',
    (tester) async {
      final stored = _saved(
        colors: [RgbColor(255, 0, 0), RgbColor.fromHex('#123456')],
      );
      final repository = InMemorySavedPaletteRepository(palettes: [stored]);
      await launch(tester, repository: repository);
      await choose(tester, '#F00');
      await tester.ensureVisible(find.text('Saved version differs'));
      expect(find.text('Palette saved'), findsNothing);
      final button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Saved version differs'),
      );
      expect(button.onPressed, isNull);
      expect(await repository.load(), [stored]);
      expect(
        find.byKey(const ValueKey('harmony-swatch-#00FFFF')),
        findsOneWidget,
      );
    },
  );

  testWidgets('collections retry is isolated from individual-color filters', (
    tester,
  ) async {
    final repository = InMemorySavedPaletteRepository()..failLoad = true;
    final container = await launch(
      tester,
      repository: repository,
      path: '/palettes',
    );
    container.read(historyFilterProvider.notifier).setQuery('purple');
    expect(find.text('Retry palettes'), findsOneWidget);
    expect(find.textContaining('PaletteStorageException'), findsNothing);
    repository.failLoad = false;
    await tester.tap(find.text('Retry palettes'));
    await tester.pumpAndSettle();
    expect(find.text('No saved palettes yet.'), findsOneWidget);
    expect(container.read(historyFilterProvider).query, 'purple');
  });

  testWidgets(
    'saved library renders exact snapshot and confirmed delete is durable',
    (tester) async {
      final stored = _saved(
        colors: [RgbColor(255, 0, 0), RgbColor.fromHex('#123456')],
      );
      final repository = InMemorySavedPaletteRepository(palettes: [stored]);
      final container = await launch(
        tester,
        path: '/palettes',
        repository: repository,
      );
      expect(
        find.byKey(const ValueKey('saved-swatch-complementary-FF0000-#123456')),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Delete Red balance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await repository.load()).single.colors.last.hex, '#123456');
      await tester.tap(find.byTooltip('Delete Red balance'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-palette')));
      await tester.pumpAndSettle();
      expect(await repository.load(), isEmpty);
      expect(find.text('No saved palettes yet.'), findsOneWidget);
      expect(await container.read(colorHistoryProvider.future), isEmpty);
    },
  );

  testWidgets(
    'opening a saved palette edits base/mode without changing the saved snapshot',
    (tester) async {
      final stored = _saved();
      final repository = InMemorySavedPaletteRepository(palettes: [stored]);
      final container = await launch(tester, repository: repository);
      await tester.ensureVisible(find.text('View saved palettes'));
      await tester.tap(find.text('View saved palettes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(ValueKey('open-palette-${stored.id}')),
      );
      await tester.tap(find.byKey(ValueKey('open-palette-${stored.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(HarmoniesScreen), findsOneWidget);
      expect(container.read(harmonyDraftProvider).base.hex, '#FF0000');
      await choose(tester, '#00F');
      expect((await repository.load()).single, stored);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(HarmoniesScreen), findsNothing);
    },
  );

  testWidgets(
    'saved swatch entry returns to the existing harmony editor without stacking',
    (tester) async {
      final container = await launch(
        tester,
        repository: InMemorySavedPaletteRepository(palettes: [_saved()]),
      );
      for (var trip = 0; trip < 2; trip++) {
        await tester.ensureVisible(find.text('View saved palettes'));
        await tester.tap(find.text('View saved palettes'));
        await tester.pumpAndSettle();
        final cyan = find.byKey(
          const ValueKey('saved-swatch-complementary-FF0000-#00FFFF'),
        );
        await tester.ensureVisible(cyan);
        await tester.tap(cyan);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Explore harmonies'));
        await tester.tap(find.text('Explore harmonies'));
        await tester.pumpAndSettle();
        expect(container.read(harmonyDraftProvider).base.hex, '#00FFFF');
      }
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(HarmoniesScreen), findsNothing);
      expect(find.text('Saved palettes'), findsNothing);
      expect(
        container
            .read(appRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .path,
        '/home',
      );
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'delete dialog labels meet contrast and target size in ${theme.name}',
      (tester) async {
        await launch(
          tester,
          path: '/palettes',
          theme: theme,
          repository: InMemorySavedPaletteRepository(palettes: [_saved()]),
        );
        await tester.tap(find.byTooltip('Delete Red balance'));
        await tester.pumpAndSettle();
        for (final label in ['Cancel', 'Delete']) {
          final text = find.text(label);
          final foreground = tester
              .renderObject<RenderParagraph>(text)
              .text
              .style!
              .color!;
          final background = tester
              .widgetList<Material>(
                find.ancestor(of: text, matching: find.byType(Material)),
              )
              .firstWhere(
                (material) => material.color != null && material.color!.a == 1,
              )
              .color!;
          final luminances = [
            foreground.computeLuminance(),
            background.computeLuminance(),
          ]..sort();
          expect(
            (luminances.last + .05) / (luminances.first + .05),
            greaterThanOrEqualTo(4.5),
          );
          final button = find.ancestor(
            of: text,
            matching: find.byType(TextButton),
          );
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
        }
      },
    );
  }

  testWidgets('Palette tab preserves Saved and Studio views', (tester) async {
    await launch(
      tester,
      path: null,
      repository: InMemorySavedPaletteRepository(palettes: [_saved()]),
    );
    final learn = find.byKey(const ValueKey('nav-learn'));
    expect(learn, findsOneWidget);
    await tester.tap(learn);
    await tester.pumpAndSettle();
    final openPalette = find.byKey(const ValueKey('learn-open-palette'));
    expect(openPalette, findsOneWidget);
    await tester.ensureVisible(openPalette);
    await tester.tap(openPalette);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('palette-collections')));
    await tester.pumpAndSettle();
    expect(find.text('Red balance'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('palette-studio')));
    await tester.pumpAndSettle();
    expect(find.text('Slow Sunday'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('palette-saved')));
    await tester.pumpAndSettle();
    expect(find.text('Red balance'), findsNothing);
  });

  testWidgets('generated swatch details set the selected Room shade', (
    tester,
  ) async {
    final container = await launch(tester);
    await choose(tester, '#F00');
    final shade = find.byKey(const ValueKey('harmony-swatch-#00FFFF'));
    await tester.ensureVisible(shade);
    await tester.tap(shade);
    await tester.pumpAndSettle();
    expect(find.text('0, 255, 255'), findsOneWidget);
    await tester.ensureVisible(find.text('Use in Room'));
    await tester.tap(find.text('Use in Room'));
    await tester.pumpAndSettle();
    expect(container.read(roomColorProvider).hex, '#00FFFF');
  });

  testWidgets(
    'camera stays paused through harmonies and samples freshly after Back',
    (tester) async {
      final cameras = <FakeCameraSession>[];
      final container = await launch(
        tester,
        path: null,
        cameraFactory: () {
          final camera = FakeCameraSession();
          cameras.add(camera);
          return camera;
        },
      );
      final learn = find.byKey(const ValueKey('nav-learn'));
      expect(learn, findsOneWidget);
      await tester.tap(learn);
      await tester.pumpAndSettle();
      final openCapture = find.byKey(const ValueKey('learn-open-capture'));
      expect(openCapture, findsOneWidget);
      await tester.ensureVisible(openCapture);
      await tester.tap(openCapture);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open camera'));
      await tester.tap(find.text('Open camera'));
      await tester.pumpAndSettle();
      cameras.single.emit!(RgbColor(255, 0, 0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Color details'));
      await tester.tap(find.text('Color details'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Explore harmonies'));
      await tester.tap(find.text('Explore harmonies'));
      await tester.pumpAndSettle();
      expect(container.read(harmonyDraftProvider).base.hex, '#FF0000');
      expect(cameras, hasLength(1));
      expect(cameras.single.starts, 1);
      expect(cameras.single.stops, greaterThanOrEqualTo(1));
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(cameras, hasLength(2));
      cameras.last.emit!(RgbColor(0, 0, 255));
      await tester.pumpAndSettle();
      expect(find.text('#0000FF'), findsWidgets);
    },
  );

  testWidgets('both new routes obey first-run guards', (tester) async {
    final container = await launch(
      tester,
      path: '/harmonies',
      completed: false,
    );
    expect(find.byType(HarmoniesScreen), findsNothing);
    container.read(appRouterProvider).go('/palettes');
    await tester.pumpAndSettle();
    expect(find.text('Find your next shade.'), findsOneWidget);
  });

  testWidgets(
    'a fresh app container reopens the whole palette from real disk',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('harmony-app-restart-'),
      ))!;
      final repositories = <HivePaletteRepository>[];
      addTearDown(() async {
        for (final repository in repositories) {
          await repository.close();
        }
        await directory.delete(recursive: true);
      });
      final first = await tester.runAsync(
        () => HivePaletteRepository.open(directory: directory.path),
      );
      repositories.add(first!);
      final firstContainer = await launch(
        tester,
        repository: first,
        preload: true,
      );
      await choose(tester, '#F00');
      await beginSave(tester, 'Disk kept palette', submit: false);
      final committed = Completer<void>();
      final subscription = firstContainer.listen(savedPalettesProvider, (
        _,
        next,
      ) {
        if (next.asData?.value.any(
                  (palette) => palette.name == 'Disk kept palette',
                ) ==
                true &&
            !committed.isCompleted) {
          committed.complete();
        }
      });
      // Native IO runs in real time; widget/provider continuations use fake
      // microtasks. Advance both until the actual committed state is published,
      // rather than settling an indefinitely animated pending-save spinner.
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('confirm-save-palette')));
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (!committed.isCompleted && DateTime.now().isBefore(deadline)) {
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        expect(
          committed.isCompleted,
          isTrue,
          reason: 'The real disk save must publish its committed snapshot.',
        );
      });
      subscription.close();
      await tester.pumpAndSettle();
      expect(find.text('Palette saved'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      firstContainer.dispose();
      await tester.runAsync(() => first.close());
      final second = await tester.runAsync(
        () => HivePaletteRepository.open(directory: directory.path),
      );
      repositories.add(second!);
      await launch(
        tester,
        repository: second,
        preload: true,
        path: '/palettes',
      );
      expect(find.text('Disk kept palette'), findsOneWidget);
      final snapshot = (await tester.runAsync(() => second.load()))!.single;
      expect(snapshot.colors.map((color) => color.hex), ['#FF0000', '#00FFFF']);
      expect(snapshot.mode, HarmonyMode.complementary);
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'harmonies and collections fit360px2x reduced-motion ${theme.name}',
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
        final container = await launch(
          tester,
          theme: theme,
          repository: InMemorySavedPaletteRepository(
            palettes: [
              _saved(name: 'A long saved palette name to wrap safely'),
            ],
          ),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('harmony-mode-monochromatic')),
        );
        await tester.tap(
          find.byKey(const ValueKey('harmony-mode-monochromatic')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save palette'));
        await tester.tap(find.text('Save palette'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        container.read(appRouterProvider).go('/palettes');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Open harmony'));
        expect(find.text('Open harmony').hitTestable(), findsOneWidget);
      },
    );
  }
}
