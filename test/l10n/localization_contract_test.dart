import 'dart:io';

import 'package:color_lab/core/config/app_identity.dart';
import 'package:color_lab/features/shell/presentation/studio_page.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English localization resolves the frozen TintAtlas identity', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(AppIdentity.displayName, 'TintAtlas');
    expect(AppIdentity.storeTitle, 'TintAtlas: Room Visualizer');
    expect(l10n.appName, AppIdentity.displayName);
    expect(l10n.storeTitle, AppIdentity.storeTitle);
    expect(l10n.onboardingStep(2, 3), 'Step 2 of 3');
    expect(l10n.gamesCreatePlayerTitle, 'Create your player');
    expect(
      l10n.gamesCreatePlayerBody,
      'Choose a local name before playing. Your levels, coins, scores, and badges stay with this player on this device.',
    );
    expect(l10n.gamesCreatePlayerAction, 'Create Player');
    expect(l10n.gamesPlayNamedGame('Bubble Shooter'), 'Play Bubble Shooter');
    expect(l10n.gamesContinueNamedGame('Water Sort'), 'Continue Water Sort');
    expect(l10n.gamesPlayGame, 'Play game');
    expect(l10n.gamesContinueGame, 'Continue game');
    expect(l10n.gamesStartingGame, 'Starting…');
    expect(l10n.gameReplayLevel(3), 'Replay level 3');
    expect(l10n.gamePlayCurrentLevel(4), 'Play current level 4');
    expect(l10n.gamePlayLevel(4), 'Play Level 4');
    expect(l10n.gameBadgeEarned, 'Badge earned');
  });

  testWidgets('generated delegates mount and expose localized copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) =>
              Text(context.l10n.storeTitle, textDirection: TextDirection.ltr),
        ),
      ),
    );

    expect(find.text(AppIdentity.storeTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Studio header mirrors under an RTL direction wrapper', (
    tester,
  ) async {
    Future<({double brand, double settings})> pump(
      TextDirection direction,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Directionality(
            textDirection: direction,
            child: const StudioPage(name: 'contract', children: []),
          ),
        ),
      );
      await tester.pump();
      return (
        brand: tester.getCenter(find.text(AppIdentity.displayName)).dx,
        settings: tester.getCenter(find.byTooltip('Appearance settings')).dx,
      );
    }

    final ltr = await pump(TextDirection.ltr);
    final rtl = await pump(TextDirection.rtl);

    expect(ltr.brand, lessThan(ltr.settings));
    expect(rtl.brand, greaterThan(rtl.settings));
    expect(tester.takeException(), isNull);
  });

  test('touched widgets contain no old visible Color Lab label', () {
    for (final path in const [
      'lib/app.dart',
      'lib/bootstrap.dart',
      'lib/features/shell/presentation/app_shell.dart',
      'lib/features/shell/presentation/studio_page.dart',
      'lib/features/onboarding/presentation/onboarding_screen.dart',
      'lib/features/settings/presentation/preferences_startup_screen.dart',
      'lib/features/settings/presentation/settings_sheet.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(matches(RegExp(r'''['"](?:Color Lab|color lab|COLOR LAB)'''))),
        reason: path,
      );
    }
  });
}
