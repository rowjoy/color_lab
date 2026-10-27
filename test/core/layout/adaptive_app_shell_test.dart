import 'dart:ui' show SemanticsAction, Tristate;

import 'package:color_lab/core/layout/adaptive_app_shell.dart';
import 'package:color_lab/core/layout/adaptive_page.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/shell/presentation/studio_page.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/responsive_test_matrix.dart';

const _destinations = <AppDestinationSpec>[
  AppDestinationSpec(
    id: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  AppDestinationSpec(
    id: 'rooms',
    label: 'Rooms',
    icon: Icons.chair_outlined,
    selectedIcon: Icons.chair_rounded,
  ),
  AppDestinationSpec(
    id: 'learn',
    label: 'Learn',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
  ),
  AppDestinationSpec(
    id: 'games',
    label: 'Games',
    icon: Icons.sports_esports_outlined,
    selectedIcon: Icons.sports_esports_rounded,
  ),
];

void main() {
  testWidgets('uses bottom navigation below 600 and a rail from 600', (
    tester,
  ) async {
    configureFoundationTestView(tester, size: const Size(599, 800));
    final harness = await _pumpShell(tester);
    addTearDown(harness.dispose);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    tester.view.physicalSize = const Size(600, 800);
    await tester.pump();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('destinations expose selected semantics and 48dp targets', (
    tester,
  ) async {
    configureFoundationTestView(tester, size: const Size(599, 800));
    final semantics = tester.ensureSemantics();
    final harness = await _pumpShell(tester);
    addTearDown(harness.dispose);
    try {
      _expectDestinationContracts(tester, selectedIndex: 0);

      tester.view.physicalSize = const Size(800, 800);
      await tester.pumpAndSettle();

      _expectDestinationContracts(tester, selectedIndex: 0);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('branch stack and state survive switches and live resize', (
    tester,
  ) async {
    configureFoundationTestView(tester, size: const Size(599, 800));
    final harness = await _pumpShell(tester);
    addTearDown(harness.dispose);

    await tester.tap(find.byKey(const ValueKey('push-home-details')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('increment-detail-count')));
    await tester.pump();
    expect(find.text('Count 1'), findsOneWidget);
    expect(harness.router.state.uri.path, '/home/details');

    await tester.tap(find.byKey(const ValueKey('nav-rooms')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/rooms');

    tester.view.physicalSize = const Size(840, 800);
    await tester.pump();
    expect(find.byType(NavigationRail), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-home')));
    await tester.pumpAndSettle();
    expect(harness.router.state.uri.path, '/home/details');
    expect(find.text('Count 1'), findsOneWidget);
  });

  testWidgets('reduced motion removes navigation and inset animation tails', (
    tester,
  ) async {
    configureFoundationTestView(
      tester,
      size: const Size(599, 800),
      reducedMotion: true,
    );
    final harness = await _pumpShell(tester);
    addTearDown(harness.dispose);

    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .animationDuration,
      Duration.zero,
    );

    await tester.tap(find.byKey(const ValueKey('nav-rooms')));
    await tester.pump();
    expect(harness.router.state.uri.path, '/rooms');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: AdaptivePage(child: Text('Page')),
        ),
      ),
    );
    expect(
      tester
          .widget<AnimatedPadding>(
            find.byKey(const ValueKey('adaptive-page-keyboard-inset')),
          )
          .duration,
      Duration.zero,
    );
  });

  testWidgets('shell rail and page inspector mirror under RTL', (tester) async {
    configureFoundationTestView(tester, size: const Size(1000, 800));
    final ltr = await _pumpShell(tester);
    addTearDown(ltr.dispose);
    expect(
      tester.getCenter(find.byType(NavigationRail)).dx,
      lessThan(tester.getCenter(find.byKey(const ValueKey('branch-home'))).dx),
    );

    final rtl = await _pumpShell(tester, direction: TextDirection.rtl);
    addTearDown(rtl.dispose);
    expect(
      tester.getCenter(find.byType(NavigationRail)).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('branch-home'))).dx,
      ),
    );

    await _pumpAdaptivePage(tester, direction: TextDirection.ltr);
    expect(
      tester.getCenter(find.byKey(const ValueKey('page-main'))).dx,
      lessThan(
        tester.getCenter(find.byKey(const ValueKey('page-inspector'))).dx,
      ),
    );

    await _pumpAdaptivePage(tester, direction: TextDirection.rtl);
    expect(
      tester.getCenter(find.byKey(const ValueKey('page-main'))).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('page-inspector'))).dx,
      ),
    );
  });

  testWidgets('AdaptivePage caps content and changes inspector placement', (
    tester,
  ) async {
    configureFoundationTestView(tester, size: const Size(839, 1200));
    await _pumpAdaptivePage(tester);
    expect(
      tester.getCenter(find.byKey(const ValueKey('page-main'))).dy,
      lessThan(
        tester.getCenter(find.byKey(const ValueKey('page-inspector'))).dy,
      ),
    );

    tester.view.physicalSize = const Size(840, 1200);
    await tester.pump();
    expect(
      tester.getCenter(find.byKey(const ValueKey('page-main'))).dx,
      lessThan(
        tester.getCenter(find.byKey(const ValueKey('page-inspector'))).dx,
      ),
    );

    tester.view.physicalSize = const Size(1600, 1000);
    await tester.pump();
    final content = tester.getRect(
      find.byKey(const ValueKey('adaptive-page-content')),
    );
    final main = tester.getRect(find.byKey(const ValueKey('page-main')));
    final inspector = tester.getRect(
      find.byKey(const ValueKey('page-inspector')),
    );
    expect(content.width, lessThanOrEqualTo(1200));
    expect(content.center.dx, closeTo(800, 0.5));
    expect(inspector.right - main.left, closeTo(1200, 0.5));
  });

  testWidgets('SafeArea and keyboard keep the final action reachable', (
    tester,
  ) async {
    configureFoundationTestView(
      tester,
      size: const Size(320, 568),
      textScale: 2,
      safePadding: const EdgeInsets.fromLTRB(8, 24, 8, 16),
      viewInsets: const EdgeInsets.only(bottom: 240),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: AdaptivePage(
            maxContentWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Keyboard-safe content', key: ValueKey('page-top')),
                const SizedBox(height: 420),
                FilledButton(
                  key: const ValueKey('final-action'),
                  onPressed: () {},
                  child: const Text('Save this project'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('page-top'))).dy,
      greaterThanOrEqualTo(24),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('final-action')));
    await tester.pumpAndSettle();
    expect(
      tester.getBottomRight(find.byKey(const ValueKey('final-action'))).dy,
      lessThanOrEqualTo(328),
    );
    expect(tester.takeException(), isNull);
  });

  for (final testCase in foundationResponsiveCases) {
    testWidgets('${testCase.name} fits shell and StudioPage at 200% text', (
      tester,
    ) async {
      configureFoundationTestView(
        tester,
        size: testCase.size,
        textScale: 2,
        reducedMotion: true,
      );
      final harness = await _pumpShell(tester);
      addTearDown(harness.dispose);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StudioPage(
            name: 'matrix',
            children: [
              const StudioHeading(
                eyebrow: 'Responsive color study',
                title: 'Explore a thoughtful room palette on every screen',
                description:
                    'Long localized copy remains readable without hiding the primary action.',
              ),
              PrimaryButton(
                key: const ValueKey('matrix-action'),
                label: 'Continue with this color study',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('matrix-action')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('matrix-action')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull, reason: testCase.name);
    });
  }
}

void _expectDestinationContracts(
  WidgetTester tester, {
  required int selectedIndex,
}) {
  for (var index = 0; index < _destinations.length; index++) {
    final destination = _destinations[index];
    final keyed = find.byKey(ValueKey('nav-${destination.id}'));
    expect(keyed, findsOneWidget);
    final accessibleNodes = tester.semantics
        .simulatedAccessibilityTraversal()
        .toList();
    final accessibleLabels = accessibleNodes
        .map((node) => node.getSemanticsData().label)
        .toList();
    final semanticMatches = accessibleNodes.where((node) {
      final label = node.getSemanticsData().label;
      return label.contains(destination.label) &&
          label.contains('Tab ${index + 1} of ${_destinations.length}');
    }).toList();
    expect(
      semanticMatches,
      hasLength(1),
      reason: '${destination.id}: $accessibleLabels',
    );
    final semanticsNode = semanticMatches.single;
    final semantics = semanticsNode.getSemanticsData();
    final size = semanticsNode.rect.size;
    expect(size.width, greaterThanOrEqualTo(48), reason: destination.id);
    expect(size.height, greaterThanOrEqualTo(48), reason: destination.id);
    expect(semantics.label, contains(destination.label));
    expect(
      semantics.label,
      contains('Tab ${index + 1} of ${_destinations.length}'),
    );
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
    expect(
      semantics.flagsCollection.isSelected,
      index == selectedIndex ? Tristate.isTrue : Tristate.isFalse,
    );
  }
}

Future<void> _pumpAdaptivePage(
  WidgetTester tester, {
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Directionality(
        textDirection: direction,
        child: const Scaffold(
          resizeToAvoidBottomInset: false,
          body: AdaptivePage(
            inspector: SizedBox(
              key: ValueKey('page-inspector'),
              height: 120,
              width: double.infinity,
            ),
            child: SizedBox(
              key: ValueKey('page-main'),
              height: 120,
              width: double.infinity,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<_ShellHarness> _pumpShell(
  WidgetTester tester, {
  TextDirection direction = TextDirection.ltr,
}) async {
  final harness = _ShellHarness();
  await tester.pumpWidget(
    MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: harness.router,
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
    ),
  );
  await tester.pump();
  return harness;
}

final class _ShellHarness {
  _ShellHarness()
    : router = GoRouter(
        initialLocation: '/home',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => AdaptiveAppShell(
              navigationShell: shell,
              destinations: _destinations,
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/home',
                    pageBuilder: (context, state) => NoTransitionPage(
                      key: state.pageKey,
                      child: const _BranchRoot(
                        id: 'home',
                        detailsPath: '/home/details',
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'details',
                        pageBuilder: (context, state) => NoTransitionPage(
                          key: state.pageKey,
                          child: const _DetailCounter(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              for (final id in ['rooms', 'learn', 'games'])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/$id',
                      pageBuilder: (context, state) => NoTransitionPage(
                        key: state.pageKey,
                        child: _BranchRoot(id: id),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );

  final GoRouter router;

  void dispose() => router.dispose();
}

class _BranchRoot extends StatelessWidget {
  const _BranchRoot({required this.id, this.detailsPath});

  final String id;
  final String? detailsPath;

  @override
  Widget build(BuildContext context) => Center(
    key: ValueKey('branch-$id'),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$id branch'),
        if (detailsPath != null)
          FilledButton(
            key: const ValueKey('push-home-details'),
            onPressed: () => context.push(detailsPath!),
            child: const Text('Open details'),
          ),
      ],
    ),
  );
}

class _DetailCounter extends StatefulWidget {
  const _DetailCounter();

  @override
  State<_DetailCounter> createState() => _DetailCounterState();
}

class _DetailCounterState extends State<_DetailCounter> {
  var count = 0;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Count $count'),
        FilledButton(
          key: const ValueKey('increment-detail-count'),
          onPressed: () => setState(() => count++),
          child: const Text('Increment'),
        ),
      ],
    ),
  );
}
