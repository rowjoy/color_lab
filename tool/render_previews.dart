// Run with: flutter test tool/render_previews.dart
// Creates real-font phone previews in build/previews for visual inspection.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/image/photo_processing.dart';
import 'package:color_lab/features/color_test/application/matching_game_controller.dart';
import 'package:color_lab/features/color_test/application/vision_controller.dart';
import 'package:color_lab/features/color_test/domain/vision_plate.dart';
import 'package:color_lab/features/formula/application/color_formula_service.dart';
import 'package:color_lab/features/formula/application/formula_providers.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/harmonies/application/harmony_controller.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/palette/domain/saved_palette.dart';
import 'package:color_lab/features/settings/application/theme_mode_provider.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/picker/application/camera_session.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/application/photo_acquisition_controller.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/segmentation/room_segmentation_service.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../test/support/in_memory_color_history_repository.dart';
import '../test/support/in_memory_acquisition_intent_store.dart';
import '../test/support/in_memory_app_preferences_repository.dart';
import '../test/support/in_memory_saved_palette_repository.dart';
import '../test/support/in_memory_room_design_repository.dart';

final _capturedPreviewNames = <String>{};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ColorFormula lilacFormula;

  test('recorded Room masks retain portable actual-model identity', () {
    final metadata =
        jsonDecode(
              File(
                'test/fixtures/room/reference_masks.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(
      metadata['maskSha256'],
      '5ab660689348ba538d622d681742d365d50ce8f08ee8bb3a8712bfa733c840ba',
    );
    expect(
      File('test/fixtures/room/reference_masks.bin').lengthSync(),
      1091840,
    );
    final labels = File(
      'test/fixtures/room/reference_masks.bin',
    ).readAsBytesSync();
    expect(sha256.convert(labels).toString(), metadata['maskSha256']);
    expect(labels.every((label) => label <= 4), isTrue);
    final counts = List<int>.filled(5, 0);
    for (final label in labels) {
      counts[label]++;
    }
    expect(counts[0], metadata['unselectedPixels']);
    for (final layer in RoomLayer.values) {
      expect(counts[layer.label], metadata['layerPixels'][layer.name]);
    }
    for (final identity in [
      ('modelAsset', 'modelSha256'),
      ('descriptorAsset', 'descriptorSha256'),
      ('photoSource', 'photoPngSha256'),
      ('preprocessInput', 'preprocessInputSha256'),
    ]) {
      expect(
        sha256
            .convert(File(metadata[identity.$1] as String).readAsBytesSync())
            .toString(),
        metadata[identity.$2],
      );
    }
    expect(metadata.containsKey('maskPath'), isFalse);
  });

  tearDownAll(() async {
    if (_capturedPreviewNames.isEmpty) return;
    await Directory('build/previews').create(recursive: true);
    await File('build/previews/render-manifest.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'scope': 'Only files actually captured during this invocation',
        'count': _capturedPreviewNames.length,
        'files': _capturedPreviewNames.toList()..sort(),
      }),
    );
  });

  setUpAll(() async {
    // Use the real search, outside widget fake time. The local service below
    // only avoids waiting for native compute dispatch during preview settling.
    lilacFormula = findColorFormula(RgbColor.fromHex('#B2A4D4'));
    for (final font in [
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ('PlusJakartaSans', 'assets/fonts/PlusJakartaSans-Variable.ttf'),
      ('JetBrainsMono', 'assets/fonts/JetBrainsMono-Variable.ttf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('render ${mode.name} phone screens', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final repository = InMemoryColorHistoryRepository(
        colors: [
          SavedColor(
            id: '#B2A4D4',
            hex: '#B2A4D4',
            name: 'Lilac Haze',
            isFavorite: true,
            createdAt: DateTime.utc(2026, 10, 21),
            source: ColorSource.lab,
          ),
          SavedColor(
            id: '#809886',
            hex: '#809886',
            name: 'Sage Garden',
            isFavorite: false,
            createdAt: DateTime.utc(2026, 10, 20),
            source: ColorSource.studio,
          ),
          SavedColor(
            id: '#E8DAA9',
            hex: '#E8DAA9',
            name: 'Butter',
            isFavorite: true,
            createdAt: DateTime.utc(2026, 10, 19),
            source: ColorSource.manual,
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          acquisitionIntentStoreProvider.overrideWith(
            (ref) async => InMemoryAcquisitionIntentStore(),
          ),
          visionPlateGeneratorProvider.overrideWithValue(
            () => [
              for (var index = 0; index < 6; index++)
                VisionPlate(
                  number: [2, 3, 4, 5, 6, 8][index],
                  seed: (index + 1) * 11,
                  palette: VisionPalette.values[index % 3],
                ),
            ],
          ),
          matchingTargetGeneratorProvider.overrideWithValue(
            () => [
              RgbColor.fromHex('#FF0000'),
              RgbColor.fromHex('#00FF00'),
              RgbColor.fromHex('#0000FF'),
              RgbColor.fromHex('#00FFFF'),
              RgbColor.fromHex('#FFFF00'),
            ],
          ),
          savedPaletteRepositoryProvider.overrideWith(
            (ref) async => InMemorySavedPaletteRepository(
              palettes: [
                SavedPalette(
                  name: 'Red complement',
                  base: RgbColor.fromHex('#FF0000'),
                  mode: HarmonyMode.complementary,
                  colors: [
                    RgbColor.fromHex('#FF0000'),
                    RgbColor.fromHex('#00FFFF'),
                  ],
                  createdAt: DateTime.utc(2026, 10, 21),
                ),
              ],
            ),
          ),
          colorFormulaServiceProvider.overrideWithValue(
            _PreviewFormulaService(lilacFormula),
          ),
          appPreferencesRepositoryProvider.overrideWith(
            (ref) async => InMemoryAppPreferencesRepository(
              initial: AppPreferences(themeMode: mode),
            ),
          ),
          cameraSessionFactoryProvider.overrideWithValue(
            () => _PreviewCamera(),
          ),
          colorNamerProvider.overrideWith(
            (ref) async => ColorNamer([
              NamedColor('Lilac Haze', RgbColor.fromHex('#B2A4D4')),
              NamedColor('Butter', RgbColor.fromHex('#E8DAA9')),
              NamedColor('Sage', RgbColor.fromHex('#809886')),
            ]),
          ),
          colorHistoryRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(themeModeProvider.notifier).setMode(mode);
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: UncontrolledProviderScope(
            container: container,
            child: const ColorLabApp(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var slide = 0; slide < 3; slide++) {
        await capturePreview(
          tester,
          boundaryKey,
          'onboarding-${slide + 1}-${mode.name}',
        );
        await tester.tap(find.text(slide < 2 ? 'Next' : 'Get started'));
        await tester.pumpAndSettle();
      }
      for (final destination in ['Capture', 'Palette', 'Lab', 'Room']) {
        await tester.tap(find.byKey(ValueKey('nav-$destination')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capturePreview(
          tester,
          boundaryKey,
          '${destination.toLowerCase()}-${mode.name}',
        );
      }
      await tester.tap(find.byTooltip('Appearance settings'));
      await tester.pumpAndSettle();
      await capturePreview(tester, boundaryKey, 'settings-${mode.name}');
      await tester.tap(find.byTooltip('Close settings'));
      await tester.pumpAndSettle();
      final fixture = img.Image(width: 240, height: 180);
      for (var y = 0; y < fixture.height; y++) {
        for (var x = 0; x < fixture.width; x++) {
          final color = RgbColor.fromHex(
            x < 80
                ? '#E8DAA9'
                : y < 90
                ? '#B2A4D4'
                : '#809886',
          );
          fixture.setPixelRgba(x, y, color.red, color.green, color.blue, 255);
        }
      }
      final photo = preparePhoto(img.encodePng(fixture));
      container.read(appRouterProvider).go('/photo', extra: photo);
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(photo.previewBytes),
          tester.element(find.text('Photo study')),
        ),
      );
      await tester.pumpAndSettle();
      await capturePreview(tester, boundaryKey, 'photo-${mode.name}');
      await tester.ensureVisible(find.text('From this photo'));
      await tester.pumpAndSettle();
      await capturePreview(tester, boundaryKey, 'photo-palette-${mode.name}');
      container.read(appRouterProvider).go('/camera');
      await tester.pumpAndSettle();
      await capturePreview(
        tester,
        boundaryKey,
        'camera-synthetic-${mode.name}',
      );
      expect(tester.takeException(), isNull);

      // Keep the existing captures above at their original phone/text size.
      unawaited(container.read(appRouterProvider).push<void>('/mixer'));
      await tester.pumpAndSettle();
      await capturePreview(tester, boundaryKey, 'mixer-${mode.name}');
      await Scrollable.ensureVisible(
        tester.element(find.text('Parts for color 1')),
        alignment: .15,
      );
      await tester.pumpAndSettle();
      await capturePreview(
        tester,
        boundaryKey,
        'mixer-ingredients-${mode.name}',
      );
      await tester.ensureVisible(find.text('Add a color'));
      await tester.tap(find.text('Add a color'));
      await tester.pumpAndSettle();
      await capturePreview(tester, boundaryKey, 'mixer-picker-${mode.name}');
      await tester.tap(find.byTooltip('Close color picker'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Parts for color 1')),
        alignment: .15,
      );
      await tester.pumpAndSettle();
      await capturePreview(
        tester,
        boundaryKey,
        'mixer-360-text2x-${mode.name}',
      );
      await tester.ensureVisible(find.text('Add a color'));
      await tester.tap(find.text('Add a color'));
      await tester.pumpAndSettle();
      await capturePreview(
        tester,
        boundaryKey,
        'mixer-picker-360-text2x-${mode.name}',
      );
      await tester.tap(find.byTooltip('Close color picker'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();

      container.read(appRouterProvider).go('/formula');
      await tester.pumpAndSettle();
      expect(find.text(lilacFormula.result.hex), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, boundaryKey, 'formula-${mode.name}');
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('formula-recipe-heading'))),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      await capturePreview(
        tester,
        boundaryKey,
        'formula-recipe-error-${mode.name}',
      );
      await tester.ensureVisible(find.text('Choose target'));
      await tester.tap(find.text('Choose target'));
      await tester.pumpAndSettle();
      await capturePreview(tester, boundaryKey, 'formula-picker-${mode.name}');
      await tester.tap(find.byTooltip('Close color picker'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('formula-recipe-heading'))),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      await capturePreview(
        tester,
        boundaryKey,
        'formula-recipe-360-text2x-${mode.name}',
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('CIE76 difference (ΔE)')),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      await capturePreview(
        tester,
        boundaryKey,
        'formula-error-360-text2x-${mode.name}',
      );
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpAndSettle();

      // Additional harmony captures use the actual controller, generator,
      // diagram, save dialog, and library with only native storage replaced.
      container.read(appRouterProvider).go('/harmonies');
      await tester.pumpAndSettle();
      final harmony = container.read(harmonyDraftProvider.notifier);
      for (final harmonyMode in HarmonyMode.values) {
        harmony.setSelection(
          base: RgbColor.fromHex('#B2A4D4'),
          mode: harmonyMode,
        );
        await tester.pumpAndSettle();
        // Start at the mode controls, rather than the screen heading, so the
        // real relationship diagram is visible in every mode overview.
        await Scrollable.ensureVisible(
          tester.element(
            find.byKey(const ValueKey('harmony-mode-complementary')),
          ),
          alignment: .02,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capturePreview(
          tester,
          boundaryKey,
          'harmonies-${harmonyMode.name}-${mode.name}',
        );
      }
      harmony.setSelection(
        base: RgbColor.fromHex('#808080'),
        mode: HarmonyMode.monochromatic,
      );
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(
          find.byKey(const ValueKey('harmony-mode-complementary')),
        ),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      await capturePreview(
        tester,
        boundaryKey,
        'harmonies-monochromatic-neutral-${mode.name}',
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Your shades')),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      await capturePreview(
        tester,
        boundaryKey,
        'harmonies-shades-${mode.name}',
      );

      // The seeded red complement is already saved. Use a different recipe
      // when opening the dialog so the real save action remains enabled.
      harmony.setSelection(
        base: RgbColor.fromHex('#B2A4D4'),
        mode: HarmonyMode.analogous,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save palette'));
      await tester.tap(find.text('Save palette'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('palette-name-input')), findsOneWidget);
      await capturePreview(
        tester,
        boundaryKey,
        'harmonies-save-dialog-${mode.name}',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/palettes');
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(
          find.byKey(const ValueKey('saved-palette-complementary-FF0000')),
        ),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      expect(find.text('Red complement'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, boundaryKey, 'saved-palettes-${mode.name}');

      tester.view.physicalSize = const Size(360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      harmony.setSelection(
        base: RgbColor.fromHex('#B2A4D4'),
        mode: HarmonyMode.monochromatic,
      );
      container.read(appRouterProvider).go('/harmonies');
      await tester.pumpAndSettle();
      // At 2x text, the full choice group needs its own scroll space. Put the
      // selected final mode directly above the diagram for this editor view.
      await Scrollable.ensureVisible(
        tester.element(
          find.byKey(const ValueKey('harmony-mode-monochromatic')),
        ),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'harmonies-360-text2x-reduced-motion-${mode.name}',
      );
      await tester.ensureVisible(find.text('Save palette'));
      await tester.tap(find.text('Save palette'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('palette-name-input')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'harmonies-save-dialog-360-text2x-reduced-motion-${mode.name}',
      );
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      container.read(appRouterProvider).go('/palettes');
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(
          find.byKey(const ValueKey('saved-palette-complementary-FF0000')),
        ),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'saved-palettes-360-text2x-reduced-motion-${mode.name}',
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpAndSettle();

      // Matching captures exercise the real retained game and screen. Only the
      // target generator is fixed, so both themes show the same five rounds.
      container.read(appRouterProvider).go('/matching');
      await tester.pumpAndSettle();
      final matching = container.read(matchingGameProvider.notifier);
      matching.setHue(24);
      matching.setSaturation(.6);
      matching.setLightness(.5);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('matching-hue'))),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'matching-editing-${mode.name}',
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('matching-restart')),
      );
      await tester.tap(find.byKey(const ValueKey('matching-restart')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('confirm-matching-restart')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'matching-restart-dialog-${mode.name}',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      tester.view.physicalSize = const Size(360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('matching-hue'))),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'matching-editing-360-text2x-reduced-motion-${mode.name}',
      );

      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('matching-submit')));
      await tester.tap(find.byKey(const ValueKey('matching-submit')));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Your round result')),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'matching-feedback-${mode.name}',
      );

      tester.view.physicalSize = const Size(360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Your round result')),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'matching-feedback-360-text2x-reduced-motion-${mode.name}',
      );

      // Finish every real round with fixed coordinates; completed results are
      // snapshots produced by the controller, not a fabricated summary model.
      for (final hue in [132.0, 228.0, 190.0, 48.0]) {
        matching.nextRound();
        matching.setHue(hue);
        matching.setSaturation(.6);
        matching.setLightness(.5);
        matching.submit();
      }
      matching.nextRound();
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Total points')),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'matching-summary-${mode.name}',
      );

      tester.view.physicalSize = const Size(360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Total points')),
        alignment: .02,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'matching-summary-360-text2x-reduced-motion-${mode.name}',
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpAndSettle();

      // Original dot plates: use real UI responses and a fixed generator, not
      // fake canvases or clinical reference images. No APK build is involved.
      container.read(appRouterProvider).go('/vision');
      await tester.pumpAndSettle();
      await capturePreview(tester, boundaryKey, 'vision-intro-${mode.name}');
      await tester.ensureVisible(find.byKey(const ValueKey('vision-start')));
      await tester.tap(find.byKey(const ValueKey('vision-start')));
      await tester.pumpAndSettle();
      const responses = <int?>[2, null, 9, 5, null, 8];
      for (var index = 0; index < responses.length; index++) {
        // Capture the real entry viewport after each accepted response, without
        // scrolling the destination into view or hiding its plate counter.
        expect(find.text('Plate ${index + 1} of 6'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capturePreview(
          tester,
          boundaryKey,
          'vision-plate-${index + 1}-${mode.name}',
        );
        if (index == 0) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('vision-restart')),
          );
          await tester.tap(find.byKey(const ValueKey('vision-restart')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('confirm-vision-restart')),
            findsOneWidget,
          );
          await capturePreview(
            tester,
            boundaryKey,
            'vision-restart-dialog-${mode.name}',
          );
          await tester.ensureVisible(find.text('Cancel'));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          tester.view.physicalSize = const Size(360, 800);
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(
            tester.element(find.byKey(const ValueKey('vision-plate'))),
            alignment: .02,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capturePreview(
            tester,
            boundaryKey,
            'vision-active-360-text2x-reduced-motion-${mode.name}',
          );
          tester.view.physicalSize = const Size(390, 844);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
          await tester.pumpAndSettle();
        }
        final response = responses[index];
        if (response == null) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('vision-not-sure')),
          );
          await tester.tap(find.byKey(const ValueKey('vision-not-sure')));
        } else {
          await tester.ensureVisible(
            find.byKey(const ValueKey('vision-answer')),
          );
          await tester.enterText(
            find.byKey(const ValueKey('vision-answer')),
            '$response',
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('vision-record')),
          );
          await tester.tap(find.byKey(const ValueKey('vision-record')));
        }
        await tester.pumpAndSettle();
        expect(
          container.read(visionSessionProvider).responses.length,
          index + 1,
        );
      }
      expect(find.byKey(const ValueKey('vision-results')), findsOneWidget);
      expect(container.read(visionSessionProvider).matchedCount, 3);
      expect(container.read(visionSessionProvider).notSureCount, 2);
      expect(tester.takeException(), isNull);
      await capturePreview(tester, boundaryKey, 'vision-results-${mode.name}');
      tester.view.physicalSize = const Size(360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturePreview(
        tester,
        boundaryKey,
        'vision-results-360-text2x-reduced-motion-${mode.name}',
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpAndSettle();
    });
    testWidgets('render ${mode.name} recorded Room mask workflow', (
      tester,
    ) async {
      await renderRoomPreviews(tester, mode);
    });
    testWidgets('render ${mode.name} illustrated study room', (tester) async {
      await renderIllustratedRoomPreviews(tester, mode);
    });
  }
}

Future<void> renderIllustratedRoomPreviews(
  WidgetTester tester,
  ThemeMode mode,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final fixedNow = DateTime.utc(2026, 10, 25, 4);
  final designs = InMemoryRoomDesignRepository(clock: () => fixedNow);
  addTearDown(designs.close);
  final container = ProviderContainer(
    overrides: [
      acquisitionIntentStoreProvider.overrideWith(
        (ref) async => InMemoryAcquisitionIntentStore(),
      ),
      appPreferencesRepositoryProvider.overrideWith(
        (ref) async => InMemoryAppPreferencesRepository(
          initial: AppPreferences(themeMode: mode, onboardingCompleted: true),
        ),
      ),
      colorHistoryRepositoryProvider.overrideWith(
        (ref) async => InMemoryColorHistoryRepository(),
      ),
      roomDesignRepositoryProvider.overrideWith((ref) async => designs),
      roomDesignClockProvider.overrideWithValue(() => fixedNow),
    ],
  );
  addTearDown(container.dispose);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  container.read(appRouterProvider).go('/room/illustrated/study');
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await capturePreview(tester, boundary, 'room-study-grayscale-${mode.name}');
  container
      .read(illustratedRoomProvider.notifier)
      .applyPalette('soft-botanical');
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await capturePreview(
    tester,
    boundary,
    'room-study-soft-botanical-${mode.name}',
  );
}

/// Native acquisition and inference alone are controlled boundaries. These
/// captures use the actual retained controller, refinement worker and viewport.
Future<void> renderRoomPreviews(WidgetTester tester, ThemeMode mode) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  final photo = preparePhoto(
    File('test/fixtures/room/reference_room.png').readAsBytesSync(),
  );
  final masks = MaskBitmap(
    width: photo.width,
    height: photo.height,
    labels: File('test/fixtures/room/reference_masks.bin').readAsBytesSync(),
  );
  final picker = _RoomPreviewPicker();
  final segmenter = _RecordedRoomSegmenter();
  final container = ProviderContainer(
    overrides: [
      acquisitionIntentStoreProvider.overrideWith(
        (ref) async => InMemoryAcquisitionIntentStore(),
      ),
      appPreferencesRepositoryProvider.overrideWith(
        (ref) async => InMemoryAppPreferencesRepository(
          initial: AppPreferences(themeMode: mode, onboardingCompleted: true),
        ),
      ),
      colorHistoryRepositoryProvider.overrideWith(
        (ref) async => InMemoryColorHistoryRepository(),
      ),
      photoPickerServiceProvider.overrideWithValue(picker),
      roomSegmentationServiceProvider.overrideWithValue(segmenter),
    ],
  );
  addTearDown(container.dispose);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  container.read(appRouterProvider).go('/room/masks');
  await tester.pumpAndSettle();
  final controller = container.read(roomMaskProvider.notifier);
  Finder key(String value) => find.byKey(ValueKey(value));
  Future<void> capture(String name) =>
      capturePreview(tester, boundary, 'room-masks-$name-${mode.name}');
  Future<void> tap(String value) async {
    await tester.ensureVisible(key(value));
    await tester.tap(key(value));
    await tester.pump();
  }

  Future<void> editor(String name) async {
    await tester.ensureVisible(key('room-mask-viewport'));
    await _waitRoomPixels(tester);
    expect(tester.takeException(), isNull);
    await capture(name);
  }

  await capture('empty');
  await tap('room-mask-gallery');
  expect(container.read(roomMaskProvider).stage, RoomMaskStage.acquiring);
  await capture('import-progress');
  picker.next.complete(photo);
  await _waitRoom(tester, () => segmenter.requests.isNotEmpty);
  expect(container.read(roomMaskProvider).stage, RoomMaskStage.analyzing);
  final candidate = key('room-mask-candidate-photo');
  await tester.ensureVisible(candidate);
  await _waitRoom(tester, () {
    final image = find.descendant(
      of: candidate,
      matching: find.byType(RawImage),
    );
    return image.evaluate().length == 1 &&
        tester.widget<RawImage>(image).image != null;
  });
  await capture('analysis-progress');
  segmenter.requests.last.complete(
    RoomSegmentationResult(photoId: segmenter.photoIds.last, masks: masks),
  );
  await _waitRoom(
    tester,
    () => container.read(roomMaskProvider).stage == RoomMaskStage.ready,
  );
  for (final layer in RoomLayer.values) {
    controller.setLayer(layer);
    await tester.pump();
    await editor('reference-${layer.name}');
  }
  controller.setLayer(RoomLayer.wall);
  controller.setTool(RoomMaskTool.add);
  controller.setBrushFraction(.10);
  await tester.pump();
  await _waitRoomPixels(tester);
  final initial = container.read(roomMaskProvider).draft!.maskRevision;
  await _roomPreviewStroke(tester);
  await _waitRoom(
    tester,
    () =>
        !container.read(roomMaskProvider).editBusy &&
        container.read(roomMaskProvider).draft!.maskRevision > initial,
  );
  expect(container.read(roomMaskProvider).draft!.hasEdits, isTrue);
  await editor('add');
  controller.setTool(RoomMaskTool.erase);
  await tester.pump();
  await _roomPreviewStroke(tester);
  await _waitRoom(
    tester,
    () =>
        !container.read(roomMaskProvider).editBusy &&
        container.read(roomMaskProvider).draft!.maskRevision > initial + 1,
  );
  await editor('erase');
  await tap('room-mask-undo');
  await _waitRoom(
    tester,
    () =>
        !container.read(roomMaskProvider).editBusy &&
        container.read(roomMaskProvider).draft!.maskRevision > initial + 2,
  );
  await editor('undo');
  await tap('room-mask-restore');
  await tester.pumpAndSettle();
  await capture('restore-dialog');
  await tap('confirm-room-mask-restore');
  await tester.pumpAndSettle();
  expect(container.read(roomMaskProvider).draft!.hasEdits, isFalse);
  await editor('restored');
  controller.setShowOverlay(false);
  await tester.pump();
  await editor('original');
  controller.setShowOverlay(true);
  await tester.pump();

  tester.view.physicalSize = const Size(360, 800);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  await tester.pumpAndSettle();
  await editor('editor-360-text2x-reduced-motion');
  await tap('room-mask-restore');
  await tester.pumpAndSettle();
  await capture('restore-dialog-360-text2x-reduced-motion');
  await tester.ensureVisible(find.text('Cancel'));
  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();
  await tap('room-mask-gallery');
  await tester.pumpAndSettle();
  await capture('replace-dialog-360-text2x-reduced-motion');
  await tester.ensureVisible(find.text('Cancel'));
  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();
  tester.view.physicalSize = const Size(390, 844);
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  await tester.pumpAndSettle();

  // An explicit delayed native reply becomes pending after the owner hides.
  picker.next = Completer<PreparedPhoto?>();
  var active = true;
  final pending = controller.importPhoto(
    PhotoSource.gallery,
    isActive: () => active,
  );
  await _waitRoom(
    tester,
    () => container.read(roomMaskProvider).stage == RoomMaskStage.acquiring,
  );
  active = false;
  picker.next.complete(photo);
  await pending;
  await tester.pump();
  expect(container.read(photoAcquisitionProvider).pendingReceipt, isNotNull);
  await tester.ensureVisible(key('room-mask-continue-import'));
  await capture('pending');
  final receipt = container.read(photoAcquisitionProvider).pendingReceipt!;
  final failure = controller.continueImport(
    receipt.requestId,
    isActive: () => true,
  );
  await _waitRoom(tester, () => segmenter.requests.length == 2);
  segmenter.requests.last.completeError(
    const RoomSegmentationException(RoomSegmentationFailureKind.processing),
  );
  await failure;
  await tester.pump();
  expect(container.read(roomMaskProvider).stage, RoomMaskStage.error);
  await tester.ensureVisible(find.text('Retry analysis'));
  await capture('error');
  expect(tester.takeException(), isNull);
}

Future<void> _waitRoom(WidgetTester tester, bool Function() complete) async {
  for (var attempt = 0; attempt < 1000 && !complete(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(
    complete(),
    isTrue,
    reason: 'Room preview work exceeded its bounded wait',
  );
  await tester.pump();
}

Future<void> _waitRoomPixels(WidgetTester tester) async {
  await _waitRoom(tester, () {
    final viewport = find.byKey(const ValueKey('room-mask-viewport'));
    final paints = find.descendant(
      of: viewport,
      matching: find.byType(CustomPaint),
    );
    if (paints.evaluate().length != 1) return false;
    // Inspect publicly named image fields on the actual private painter rather
    // than adding a product screenshot hook or assuming an 80ms completion.
    final dynamic painter = tester.widget<CustomPaint>(paints).painter;
    return painter.photo != null &&
        (painter.overlay != null ||
            tester
                .widget<SwitchListTile>(
                  find.byKey(const ValueKey('room-mask-show-original')),
                )
                .value);
  });
}

Future<void> _roomPreviewStroke(WidgetTester tester) async {
  final viewport = find.byKey(const ValueKey('room-mask-viewport'));
  await tester.ensureVisible(viewport);
  final rect = tester.getRect(viewport);
  final imageHeight = rect.width * 853 / 1280;
  final point = Offset(rect.center.dx, rect.center.dy - imageHeight * .40);
  final gesture = await tester.startGesture(point);
  await gesture.moveBy(const Offset(30, 0));
  await gesture.up();
  await tester.pump();
}

class _RoomPreviewPicker implements PhotoPickerService {
  Completer<PreparedPhoto?> next = Completer<PreparedPhoto?>();
  @override
  Future<PreparedPhoto?> pick({PhotoSource source = PhotoSource.gallery}) =>
      next.future;
  @override
  Future<PreparedPhoto?> recoverLost() async => null;
  @override
  Future<bool> openSettings() async => false;
}

class _RecordedRoomSegmenter implements RoomSegmentationService {
  final requests = <Completer<RoomSegmentationResult>>[];
  final photoIds = <String>[];
  @override
  Future<RoomSegmentationResult> analyze({
    required String photoId,
    required PreparedPhoto photo,
  }) {
    photoIds.add(photoId);
    final result = Completer<RoomSegmentationResult>();
    requests.add(result);
    return result.future;
  }

  @override
  Future<void> close() async {}
}

class _PreviewFormulaService implements ColorFormulaService {
  const _PreviewFormulaService(this.formula);

  final ColorFormula formula;

  @override
  Future<ColorFormula> find(RgbColor target) {
    assert(target == formula.target);
    return Future.value(formula);
  }
}

Future<void> capturePreview(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String name,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/previews').create(recursive: true);
    await File(
      'build/previews/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    expect(
      _capturedPreviewNames.add('$name.png'),
      isTrue,
      reason: 'Each preview stem must be captured exactly once per invocation',
    );
    image.dispose();
  });
}

/// Deliberately synthetic preview: this is layout evidence, not camera evidence.
class _PreviewCamera implements CameraSession {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> start({
    required ValueChanged<RgbColor> onColor,
    required ValueChanged<CameraFailure> onError,
  }) async {
    onColor(RgbColor.fromHex('#B2A4D4'));
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<bool> openSettings() async => false;
  @override
  double get previewAspectRatio => .75;
  @override
  Widget buildPreview() => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE8DAA9), Color(0xFFB2A4D4), Color(0xFF809886)],
      ),
    ),
  );
  @override
  void updateSamplePoint({
    required double x,
    required double y,
    required double viewportWidth,
    required double viewportHeight,
  }) {}
}
