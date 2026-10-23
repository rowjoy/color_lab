import 'dart:async';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/color_history_repository.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/history/presentation/color_history_section.dart';
import 'package:color_lab/features/palette/presentation/palette_screen.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_color_history_repository.dart';

final _rose = SavedColor(
  id: '#D58A79',
  hex: '#D58A79',
  name: 'Dusty Rose',
  isFavorite: false,
  createdAt: DateTime.utc(2026, 10, 21),
  source: ColorSource.camera,
);
final _green = SavedColor(
  id: '#809886',
  hex: '#809886',
  name: 'Quiet Green',
  isFavorite: true,
  createdAt: DateTime.utc(2026, 10, 20),
  source: ColorSource.manual,
);

Future<void> _launch(
  WidgetTester tester,
  InMemoryColorHistoryRepository repository, {
  bool palette = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        colorHistoryRepositoryProvider.overrideWith((ref) async => repository),
        colorNamerProvider.overrideWith(
          (ref) async => ColorNamer([
            NamedColor('Rose', RgbColor(213, 138, 121)),
            NamedColor('Golden cream', RgbColor(232, 218, 169)),
          ]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: palette
            ? const PaletteScreen()
            : const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: ColorHistorySection(),
                ),
              ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows loading until the repository opens', (tester) async {
    final ready = Completer<ColorHistoryRepository>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          colorHistoryRepositoryProvider.overrideWith((ref) => ready.future),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: ColorHistorySection()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    ready.complete(InMemoryColorHistoryRepository());
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No saved colors yet'), findsOneWidget);
  });

  testWidgets('empty library opens manual color entry', (tester) async {
    await _launch(tester, InMemoryColorHistoryRepository());
    expect(find.text('No saved colors yet'), findsOneWidget);
    await _tap(tester, find.text('Explore a color'));
    expect(find.byKey(const ValueKey('hex-input')), findsOneWidget);
  });

  testWidgets('saved colors show their name, HEX and result count', (
    tester,
  ) async {
    await _launch(
      tester,
      InMemoryColorHistoryRepository(colors: [_rose, _green]),
    );
    expect(find.text('Dusty Rose'), findsOneWidget);
    expect(find.text('#D58A79'), findsOneWidget);
    expect(find.text('Quiet Green'), findsOneWidget);
    expect(find.text('2 colors'), findsOneWidget);
  });

  testWidgets('search matches names and hashless HEX then clears', (
    tester,
  ) async {
    await _launch(
      tester,
      InMemoryColorHistoryRepository(colors: [_rose, _green]),
    );
    final search = find.byKey(const ValueKey('history-search'));
    await tester.enterText(search, 'rOsE');
    await tester.pumpAndSettle();
    expect(find.text('Dusty Rose'), findsOneWidget);
    expect(find.text('Quiet Green'), findsNothing);
    await tester.enterText(search, '8098');
    await tester.pumpAndSettle();
    expect(find.text('Quiet Green'), findsOneWidget);
    expect(find.text('Dusty Rose'), findsNothing);
    await _tap(tester, find.byTooltip('Clear search'));
    expect(find.text('Dusty Rose'), findsOneWidget);
    expect(find.text('Quiet Green'), findsOneWidget);
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
  });

  testWidgets('favorites combine with search and no matches clears filters', (
    tester,
  ) async {
    await _launch(
      tester,
      InMemoryColorHistoryRepository(colors: [_rose, _green]),
    );
    await _tap(tester, find.byKey(const ValueKey('favorites-filter')));
    expect(find.text('Quiet Green'), findsOneWidget);
    expect(find.text('Dusty Rose'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('history-search')),
      'rose',
    );
    await tester.pumpAndSettle();
    expect(find.text('No matching colors'), findsOneWidget);
    expect(find.text('No saved colors yet'), findsNothing);
    await _tap(tester, find.text('Clear filters'));
    expect(find.text('Dusty Rose'), findsOneWidget);
    expect(find.text('Quiet Green'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('history-search')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('favorite action persists and updates accessible action', (
    tester,
  ) async {
    final repository = InMemoryColorHistoryRepository(colors: [_rose]);
    await _launch(tester, repository);
    await _tap(tester, find.byKey(const ValueKey('favorite-#D58A79')));
    expect(find.byTooltip('Remove Dusty Rose from favorites'), findsOneWidget);
    expect((await repository.load()).single.isFavorite, isTrue);
  });

  testWidgets(
    'delete cancellation preserves color and confirmation removes it',
    (tester) async {
      final repository = InMemoryColorHistoryRepository(colors: [_rose]);
      await _launch(tester, repository);
      await _tap(tester, find.byKey(const ValueKey('delete-#D58A79')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await _tap(tester, find.text('Cancel'));
      expect((await repository.load()).single.hex, '#D58A79');
      expect(find.text('Dusty Rose'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('delete-#D58A79')));
      await _tap(tester, find.widgetWithText(TextButton, 'Delete'));
      expect(await repository.load(), isEmpty);
      expect(find.text('No saved colors yet'), findsOneWidget);
    },
  );

  testWidgets('repository error is friendly and retry reloads stored colors', (
    tester,
  ) async {
    final repository = InMemoryColorHistoryRepository(colors: [_rose])
      ..failLoad = true;
    await _launch(tester, repository);
    expect(find.text('Could not load your colors'), findsOneWidget);
    expect(find.textContaining('Exception'), findsNothing);
    repository.failLoad = false;
    await _tap(tester, find.text('Retry'));
    expect(find.text('Dusty Rose'), findsOneWidget);
    expect(find.text('Could not load your colors'), findsNothing);
  });

  testWidgets('favorite and delete failures keep the loaded list', (
    tester,
  ) async {
    final repository = InMemoryColorHistoryRepository(colors: [_rose])
      ..failWrites = true;
    await _launch(tester, repository);
    await _tap(tester, find.byKey(const ValueKey('favorite-#D58A79')));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Dusty Rose'), findsOneWidget);
    expect(find.byTooltip('Add Dusty Rose to favorites'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await _tap(tester, find.byKey(const ValueKey('delete-#D58A79')));
    await _tap(tester, find.widgetWithText(TextButton, 'Delete'));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Dusty Rose'), findsOneWidget);
  });

  testWidgets('saved details retain the original capture source', (
    tester,
  ) async {
    await _launch(tester, InMemoryColorHistoryRepository(colors: [_rose]));
    await _tap(tester, find.byKey(const ValueKey('history-color-#D58A79')));
    final details = tester.widget<ColorDetails>(find.byType(ColorDetails));
    expect(details.color.hex, '#D58A79');
    expect(details.source, ColorSource.camera);
  });

  testWidgets('pending writes disable both actions and survive page disposal', (
    tester,
  ) async {
    final gate = Completer<void>();
    final repository = InMemoryColorHistoryRepository(colors: [_rose])
      ..writeGate = gate;
    await _launch(tester, repository);
    final favorite = find.byKey(const ValueKey('favorite-#D58A79'));
    await tester.ensureVisible(favorite);
    await tester.tap(favorite);
    await tester.pump();
    expect(tester.widget<IconButton>(favorite).onPressed, isNull);
    expect(
      tester
          .widget<IconButton>(find.byKey(const ValueKey('delete-#D58A79')))
          .onPressed,
      isNull,
    );
    expect(find.text('Dusty Rose'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Palette defaults to saved colors and retains Studio studies', (
    tester,
  ) async {
    await _launch(
      tester,
      InMemoryColorHistoryRepository(colors: [_rose]),
      palette: true,
    );
    expect(find.byKey(const ValueKey('screen-Palette')), findsOneWidget);
    expect(find.text('Dusty Rose'), findsOneWidget);
    expect(find.text('Slow Sunday'), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('palette-studio')));
    expect(find.text('Slow Sunday'), findsOneWidget);
    expect(find.text('After the rain'), findsOneWidget);
    expect(find.text('A little unexpected'), findsOneWidget);
    expect(find.text('Dusty Rose'), findsNothing);
    await _tap(tester, find.text('#E8DAA9'));
    expect(
      tester.widget<ColorDetails>(find.byType(ColorDetails)).source,
      ColorSource.studio,
    );
  });

  testWidgets('library, actions and Studio fit 360px with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _launch(
      tester,
      InMemoryColorHistoryRepository(colors: [_rose, _green]),
      palette: true,
    );
    expect(tester.takeException(), isNull);
    for (final key in ['favorite-#D58A79', 'delete-#D58A79']) {
      final action = find.byKey(ValueKey(key));
      await tester.ensureVisible(action);
      expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    }
    await _tap(tester, find.byKey(const ValueKey('delete-#D58A79')));
    expect(tester.takeException(), isNull);
    await _tap(tester, find.text('Cancel'));
    await _tap(tester, find.byKey(const ValueKey('palette-studio')));
    expect(tester.takeException(), isNull);
  });
}
