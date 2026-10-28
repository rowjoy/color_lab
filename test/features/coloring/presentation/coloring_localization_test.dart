import 'dart:io';

import 'package:color_lab/features/coloring/application/coloring_project_providers.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/presentation/coloring_catalog_screen.dart';
import 'package:color_lab/l10n/generated/app_localizations_en.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_coloring_project_repository.dart';

class _ColoringTranslation extends AppLocalizationsEn {
  @override
  String get coloringStudioTitle => 'Translated studio';
  @override
  String coloringDrawingTitle(String key) => 'Translated drawing';
  @override
  String coloringDrawingDescription(String key) => 'Translated description';
  @override
  String coloringRegionLabel(String key) => 'Translated region';
  @override
  String get coloringNotColored => 'Translated empty';
}

class _TranslationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _TranslationDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(_ColoringTranslation());
  @override
  bool shouldReload(_TranslationDelegate old) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<DrawingDefinition> catalog;
  setUpAll(() async {
    catalog = await AssetDrawingCatalogLoader().load();
  });

  test(
    'every authored artwork key resolves, with safe unknown-key fallback',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(catalog, hasLength(12));
      for (final drawing in catalog) {
        expect(
          l10n.coloringDrawingTitle(drawing.title),
          isNot('Unknown drawing'),
        );
        expect(
          l10n.coloringDrawingDescription(drawing.description),
          isNot('Drawing description unavailable.'),
        );
        for (final slot in drawing.slots) {
          expect(l10n.coloringSlotLabel(slot.label), isNot('Color'));
        }
        for (final region in drawing.artwork.regions) {
          expect(l10n.coloringRegionLabel(region.labelKey), isNot('Region'));
        }
      }
      final apple = catalog.firstWhere(
        (drawing) => drawing.id == 'fruit_red_apple',
      );
      expect(l10n.coloringDrawingTitle(apple.title), 'Red Apple');
      expect(
        l10n.coloringDrawingDescription(apple.description),
        'A bright apple with a leaf, stem, and soft highlight.',
      );
      expect(l10n.coloringSlotLabel(apple.slots.first.label), 'Apple red');
      expect(l10n.coloringRegionLabel('coloringAppleBody'), 'Apple Body');
      expect(l10n.coloringDrawingTitle('missing-key'), 'Unknown drawing');
      expect(l10n.coloringRegionLabel('missing-key'), 'Region');
      expect(l10n.coloringSlotLabel('missing-key'), 'Color');
      expect(l10n.coloringProgress(2, 4), '2 of 4 regions');
      expect(
        l10n.coloringShareTitle('Red Apple'),
        'TintAtlas Coloring Studio — Red Apple',
      );
    },
  );

  test('Games entry contains no hard-coded Coloring Studio copy', () {
    final source = File(
      'lib/features/games/presentation/games_screen.dart',
    ).readAsStringSync();
    for (final copy in const [
      "'Coloring Studio'",
      "'Relax with 12 original offline drawings in Guided or Free Color. No timer, score, coins, or lives.'",
      "'Open Coloring Studio'",
    ]) {
      expect(source, isNot(contains(copy)), reason: copy);
    }
  });

  testWidgets('catalog and canvas resolve localized artwork copy under RTL', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final apple = catalog.firstWhere(
      (drawing) => drawing.id == 'fruit_red_apple',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          drawingCatalogProvider.overrideWith((ref) async => [apple]),
          coloringProjectRepositoryProvider.overrideWith(
            (ref) async => InMemoryColoringProjectRepository(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            _TranslationDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: ColoringCatalogScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Translated studio'), findsOneWidget);
    expect(find.text('Translated drawing'), findsOneWidget);
    expect(find.text('Translated description'), findsOneWidget);
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('coloring-canvas-paint')),
    );
    final regions = paint.painter!.semanticsBuilder!(const Size(600, 400));
    expect(regions, hasLength(4));
    for (final region in regions) {
      expect(region.properties.label, 'Translated region');
      expect(region.properties.value, 'Translated empty');
      expect(region.properties.textDirection, TextDirection.rtl);
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
