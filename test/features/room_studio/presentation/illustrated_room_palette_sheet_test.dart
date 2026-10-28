import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_palette_sheet.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/in_memory_saved_palette_repository.dart';

void main() {
  // Mutation: retaining a palette object/provider rather than copying a value.
  testWidgets(
    'My Palettes returns a copied swatch that survives source deletion',
    (tester) async {
      final repository = InMemorySavedPaletteRepository();
      final source = await repository.save(
        name: 'Source',
        base: RgbColor.fromHex('#123456'),
        mode: HarmonyMode.analogous,
        colors: [RgbColor.fromHex('#123456'), RgbColor.fromHex('#ABCDEF')],
      );
      RgbColor? chosen;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedPaletteRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async =>
                      chosen = await showIllustratedRoomPalettes(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#ABCDEF'));
      await tester.pumpAndSettle();
      expect(chosen?.hex, '#ABCDEF');
      expect(identical(chosen, source.colors.last), isFalse);
      await repository.delete(source.id);
      await repository.save(
        name: 'Changed',
        base: RgbColor.fromHex('#123456'),
        mode: HarmonyMode.analogous,
        colors: [RgbColor.fromHex('#123456')],
      );
      expect(chosen?.hex, '#ABCDEF');
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );
}
