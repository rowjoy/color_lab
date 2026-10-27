import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/home/presentation/home_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'Home shows room-first actions and an honest Continue placeholder',
    (tester) async {
      final harness = _HomeHarness();
      addTearDown(harness.dispose);
      await harness.pump(tester);

      for (final key in [
        'home-sample-room',
        'home-continue',
        'home-card-rooms',
        'home-card-learn',
        'home-card-games',
        'home-card-my-work',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      }
      expect(
        tester
            .widget<SecondaryButton>(
              find.byKey(const ValueKey('home-continue-action')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('Home actions open their canonical destinations', (tester) async {
    final harness = _HomeHarness();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    for (final entry in const {
      'home-sample-room': '/room/illustrated/living',
      'home-card-rooms': '/rooms',
      'home-card-learn': '/learn',
      'home-card-games': '/games',
      'home-card-my-work': '/my-work',
    }.entries) {
      harness.router.go('/home');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(ValueKey(entry.key)));
      await tester.tap(find.byKey(ValueKey(entry.key)));
      await tester.pumpAndSettle();
      expect(harness.router.state.uri.path, entry.value, reason: entry.key);
    }
  });

  testWidgets('Home remains usable at compact and large sizes with 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = _HomeHarness();
    addTearDown(harness.dispose);
    await harness.pump(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('home-card-my-work')));
    expect(
      find.byKey(const ValueKey('home-card-my-work')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('home-sample-room')));
    expect(tester.takeException(), isNull);
  });
}

final class _HomeHarness {
  _HomeHarness()
    : router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          for (final path in [
            '/rooms',
            '/learn',
            '/games',
            '/my-work',
            '/room/illustrated/living',
          ])
            GoRoute(
              path: path,
              builder: (context, state) =>
                  Scaffold(key: ValueKey('target-$path'), body: Text(path)),
            ),
        ],
      );

  final GoRouter router;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
  }

  void dispose() => router.dispose();
}
