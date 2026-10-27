import 'dart:async';

import 'package:color_lab/core/config/app_identity.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/core/widgets/buttons.dart';
import 'package:color_lab/features/onboarding/presentation/onboarding_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> launch(
    WidgetTester tester, {
    Future<void> Function()? onFinish,
    bool isReplay = false,
    Size size = const Size(400, 800),
    double textScale = 1,
    bool reduceMotion = false,
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: OnboardingScreen(
          onFinish: onFinish ?? () async {},
          isReplay: isReplay,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  testWidgets('Next, Back, and swipe move through all three tour steps', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    expect(find.text(AppIdentity.displayName), findsOneWidget);
    expect(find.text('Find your next shade.'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);

    await next(tester);
    expect(find.text('A little library of you.'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 1 of 3'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Step 2 of 3'), findsOneWidget);
    await next(tester);
    expect(find.text('Your curiosity. Your control.'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 3 of 3'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    semantics.dispose();
  });

  for (var page = 0; page < 3; page++) {
    testWidgets('Skip completes directly from step ${page + 1}', (
      tester,
    ) async {
      var finishes = 0;
      await launch(tester, onFinish: () async => finishes++);
      for (var step = 0; step < page; step++) {
        await next(tester);
      }
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(finishes, 1);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  }

  testWidgets('Get started awaits one completion attempt without popping', (
    tester,
  ) async {
    final pending = Completer<void>();
    var finishes = 0;
    await launch(
      tester,
      onFinish: () {
        finishes++;
        return pending.future;
      },
    );
    await next(tester);
    await next(tester);
    await tester.tap(find.text('Get started'));
    await tester.tap(find.text('Get started'));
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(finishes, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending completion blocks swipe, controls, and system back', (
    tester,
  ) async {
    final pending = Completer<void>();
    var finishes = 0;
    await launch(
      tester,
      onFinish: () {
        finishes++;
        return pending.future;
      },
    );
    await next(tester);
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Back'));
    await tester.tap(find.text('Next'));
    await tester.tap(find.text('Skip'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(finishes, 1);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('failure stays on the same step with a safe, working retry', (
    tester,
  ) async {
    var attempts = 0;
    await launch(
      tester,
      onFinish: () async {
        attempts++;
        if (attempts == 1) throw StateError('private-storage-path');
      },
    );
    await next(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(
      find.text('We couldn’t finish the tour. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('private-storage-path'), findsNothing);
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Try again'), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'disposal during ${fail ? 'failed' : 'successful'} await is safe',
      (tester) async {
        final pending = Completer<void>();
        await launch(tester, onFinish: () => pending.future);
        await tester.tap(find.text('Skip'));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
        if (fail) {
          pending.completeError(StateError('gone'));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('replay finishes with Done through the same callback', (
    tester,
  ) async {
    var finishes = 0;
    await launch(tester, isReplay: true, onFinish: () async => finishes++);
    await next(tester);
    await next(tester);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(finishes, 1);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('system back moves to the previous first-run slide', (
    tester,
  ) async {
    var finishes = 0;
    await launch(tester, onFinish: () async => finishes++);
    await next(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(finishes, 0);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(finishes, 0);
  });

  testWidgets(
    'replay blocks route back during completion and allows it after',
    (tester) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: const Scaffold(body: Text('Previous screen')),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(
            builder: (context) => OnboardingScreen(
              isReplay: true,
              onFinish: () => pending.future,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Previous screen'), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  testWidgets('reduced motion changes steps without a transition', (
    tester,
  ) async {
    await launch(tester, reduceMotion: true);
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('A little library of you.').hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('onboarding-page-1'))).dx,
      0,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    expect(find.text('Find your next shade.').hitTestable(), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final scenario in [
      (
        name: '360px portrait at 2x text',
        size: const Size(360, 800),
        scale: 2.0,
      ),
      (name: 'short landscape', size: const Size(800, 360), scale: 1.0),
      (
        name: 'short landscape at 2x text',
        size: const Size(800, 360),
        scale: 2.0,
      ),
    ]) {
      testWidgets('${scenario.name} is usable in ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await launch(
          tester,
          size: scenario.size,
          textScale: scenario.scale,
          dark: dark,
        );
        for (var page = 0; page < 3; page++) {
          expect(tester.takeException(), isNull);
          final button = page == 2 ? 'Get started' : 'Next';
          expect(find.text(button).hitTestable(), findsOneWidget);
          expect(find.text('Skip').hitTestable(), findsOneWidget);
          expect(
            tester.getSize(find.byType(PrimaryButton)).height,
            greaterThanOrEqualTo(48),
          );
          if (page > 0) {
            expect(
              tester.getSize(find.byType(IconCircleButton)).shortestSide,
              greaterThanOrEqualTo(48),
            );
          }
          await tester.drag(
            find.byKey(ValueKey('onboarding-page-$page')),
            const Offset(0, -600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (page < 2) await next(tester);
        }
      });
    }
  }
}
