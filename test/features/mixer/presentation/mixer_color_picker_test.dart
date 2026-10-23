import 'dart:async';
import 'dart:io';

import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/color_history_repository.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/mixer/presentation/mixer_color_picker.dart';
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

class _Selection {
  RgbColor? color;
  bool completed = false;
  final root = GlobalKey<NavigatorState>();
  final nested = GlobalKey<NavigatorState>();
}

Future<({ProviderContainer container, _Selection selection})> _open(
  WidgetTester tester, {
  InMemoryColorHistoryRepository? repository,
  Future<ColorHistoryRepository>? pendingRepository,
  RgbColor? initialColor,
  ThemeData? theme,
  bool settle = true,
  bool globalFilter = false,
}) async {
  final container = ProviderContainer(
    overrides: [
      historyStorageDirectoryProvider.overrideWith(
        (ref) async => Directory.systemTemp,
      ),
      colorHistoryRepositoryProvider.overrideWith(
        (ref) =>
            pendingRepository ??
            Future.value(repository ?? InMemoryColorHistoryRepository()),
      ),
    ],
  );
  addTearDown(container.dispose);
  if (globalFilter) {
    container.read(historyFilterProvider.notifier).setQuery('unrelated');
    container.read(historyFilterProvider.notifier).toggleFavorites();
  }
  final selection = _Selection();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: selection.root,
        theme: theme ?? AppTheme.light,
        home: Navigator(
          key: selection.nested,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selection.color = await showMixerColorPicker(
                    context,
                    initialColor: initialColor,
                  );
                  selection.completed = true;
                },
                child: const Text('Choose ingredient'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Choose ingredient'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }
  return (container: container, selection: selection);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  final hex = find.byKey(const ValueKey('mixer-hex-input'));
  final search = find.byKey(const ValueKey('mixer-library-search'));

  testWidgets(
    'invalid manual HEX stays open then trimmed short HEX returns RGB',
    (tester) async {
      final opened = await _open(tester);
      expect(tester.widget<TextField>(hex).controller!.text, '#6C5CE7');
      await tester.enterText(hex, 'oops');
      await _tap(tester, find.text('Use this color'));
      expect(opened.selection.completed, isFalse);
      expect(find.text('Enter a 3 or 6 digit HEX color.'), findsOneWidget);
      await tester.enterText(hex, '  #0f8  ');
      await _tap(tester, find.text('Use this color'));
      expect(opened.selection.completed, isTrue);
      expect(opened.selection.color, RgbColor(0, 255, 136));
    },
  );

  testWidgets(
    'initial ingredient can be edited and returns actual edited RGB',
    (tester) async {
      final opened = await _open(tester, initialColor: RgbColor(18, 52, 86));
      expect(tester.widget<TextField>(hex).controller!.text, '#123456');
      await tester.enterText(hex, 'abcdef');
      await _tap(tester, find.text('Use this color'));
      expect(opened.selection.color, RgbColor(171, 205, 239));
    },
  );

  testWidgets('saved selection returns stored RGB without writing history', (
    tester,
  ) async {
    final repository = InMemoryColorHistoryRepository(colors: [_rose, _green]);
    final opened = await _open(tester, repository: repository);
    await _tap(tester, find.byKey(const ValueKey('mixer-saved-#D58A79')));
    expect(opened.selection.color, RgbColor(213, 138, 121));
    expect(await repository.load(), [_rose, _green]);
  });

  testWidgets(
    'long saved library scrolls to an ingredient beyond the first page',
    (tester) async {
      final colors = [
        for (var blue = 0; blue < 60; blue++)
          SavedColor(
            id: RgbColor(0, 0, blue).hex,
            hex: RgbColor(0, 0, blue).hex,
            name: 'Shade $blue',
            isFavorite: false,
            createdAt: DateTime.utc(2026),
            source: ColorSource.manual,
          ),
      ];
      final opened = await _open(
        tester,
        repository: InMemoryColorHistoryRepository(colors: colors),
      );
      final list = find.byType(ListView);
      await tester.ensureVisible(list);
      final last = find.byKey(const ValueKey('mixer-saved-#00003B'));
      await tester.scrollUntilVisible(
        last,
        200,
        scrollable: find.descendant(
          of: list,
          matching: find.byType(Scrollable),
        ),
      );
      await _tap(tester, last);
      expect(opened.selection.color, RgbColor(0, 0, 59));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('local name and HEX search ignores and preserves global filter', (
    tester,
  ) async {
    final opened = await _open(
      tester,
      repository: InMemoryColorHistoryRepository(colors: [_rose, _green]),
      globalFilter: true,
    );
    expect(find.text('Dusty Rose'), findsOneWidget);
    expect(find.text('Quiet Green'), findsOneWidget);
    await tester.enterText(search, '  rOsE  ');
    await tester.pumpAndSettle();
    expect(find.text('Dusty Rose'), findsOneWidget);
    expect(find.text('Quiet Green'), findsNothing);
    await tester.enterText(search, '8098');
    await tester.pumpAndSettle();
    expect(find.text('Quiet Green'), findsOneWidget);
    expect(find.text('Dusty Rose'), findsNothing);
    expect(opened.container.read(historyFilterProvider), (
      query: 'unrelated',
      favoritesOnly: true,
    ));
    await _tap(tester, find.byTooltip('Close color picker'));
    expect(opened.selection.completed, isTrue);
    expect(opened.selection.color, isNull);
    expect(opened.container.read(historyFilterProvider), (
      query: 'unrelated',
      favoritesOnly: true,
    ));
  });

  testWidgets('modal uses root navigator and close returns null', (
    tester,
  ) async {
    final opened = await _open(tester);
    expect(opened.selection.root.currentState!.canPop(), isTrue);
    expect(opened.selection.nested.currentState!.canPop(), isFalse);
    await _tap(tester, find.byTooltip('Close color picker'));
    expect(opened.selection.completed, isTrue);
    expect(opened.selection.color, isNull);
    expect(opened.selection.root.currentState!.canPop(), isFalse);
  });

  testWidgets('system back cancels without selecting default manual color', (
    tester,
  ) async {
    final opened = await _open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(opened.selection.completed, isTrue);
    expect(opened.selection.color, isNull);
  });

  testWidgets('manual entry works while saved library is still loading', (
    tester,
  ) async {
    final ready = Completer<ColorHistoryRepository>();
    final opened = await _open(
      tester,
      pendingRepository: ready.future,
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.enterText(hex, '#123');
    await tester.ensureVisible(find.text('Use this color'));
    await tester.tap(find.text('Use this color'));
    await tester.pump(const Duration(seconds: 1));
    expect(opened.selection.color, RgbColor(17, 34, 51));
    ready.complete(InMemoryColorHistoryRepository());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed library exposes safe retry and recovers actual saved colors',
    (tester) async {
      final repository = InMemoryColorHistoryRepository(colors: [_rose])
        ..failLoad = true;
      await _open(tester, repository: repository);
      expect(find.text('Could not load your saved colors.'), findsOneWidget);
      expect(find.textContaining('private storage'), findsNothing);
      repository.failLoad = false;
      await _tap(tester, find.text('Retry library'));
      expect(find.text('Dusty Rose'), findsOneWidget);
      expect(find.text('Could not load your saved colors.'), findsNothing);
    },
  );

  testWidgets('failed library leaves manual entry usable', (tester) async {
    final opened = await _open(
      tester,
      repository: InMemoryColorHistoryRepository()..failLoad = true,
    );
    await tester.enterText(hex, '#fed');
    await _tap(tester, find.text('Use this color'));
    expect(opened.selection.color, RgbColor(255, 238, 221));
  });

  testWidgets('empty and unmatched library leave manual selection available', (
    tester,
  ) async {
    final empty = await _open(tester);
    expect(find.text('No saved colors yet.'), findsOneWidget);
    await _tap(tester, find.byTooltip('Close color picker'));
    expect(empty.selection.color, isNull);
    final opened = await _open(
      tester,
      repository: InMemoryColorHistoryRepository(colors: [_rose]),
    );
    await tester.enterText(search, 'no match');
    await tester.pumpAndSettle();
    expect(find.text('No matching saved colors.'), findsOneWidget);
    await tester.enterText(hex, '#000');
    await _tap(tester, find.text('Use this color'));
    expect(opened.selection.color, RgbColor(0, 0, 0));
  });

  for (final dark in [false, true]) {
    testWidgets(
      '360px doubled text remains usable in ${dark ? 'dark' : 'light'}',
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
        final opened = await _open(
          tester,
          repository: InMemoryColorHistoryRepository(colors: [_rose, _green]),
          theme: dark ? AppTheme.dark : AppTheme.light,
        );
        expect(tester.takeException(), isNull);
        final close = find.byTooltip('Close color picker');
        expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(48));
        final tile = find.byKey(const ValueKey('mixer-saved-#D58A79'));
        await tester.ensureVisible(tile);
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
        await _tap(tester, tile);
        expect(opened.selection.color, RgbColor(213, 138, 121));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('short landscape with keyboard can scroll to manual action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 160);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final opened = await _open(tester);
    await tester.enterText(hex, '#012');
    await _tap(tester, find.text('Use this color'));
    expect(opened.selection.color, RgbColor(0, 17, 34));
    expect(tester.takeException(), isNull);
  });
}
