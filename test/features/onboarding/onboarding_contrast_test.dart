import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/onboarding/presentation/onboarding_screen.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color foreground, Color background) {
  final luminance = [
    foreground.computeLuminance(),
    background.computeLuminance(),
  ]..sort();
  return (luminance.last + .05) / (luminance.first + .05);
}

void main() {
  const eyebrows = ['A CURIOUS EYE', 'MAKE IT PERSONAL', 'ON YOUR TERMS'];

  for (final dark in [false, true]) {
    for (var page = 0; page < eyebrows.length; page++) {
      testWidgets(
        'slide ${page + 1} small label has 4.5 contrast in ${dark ? 'dark' : 'light'}',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: dark ? AppTheme.dark : AppTheme.light,
              home: OnboardingScreen(onFinish: () async {}),
            ),
          );
          await tester.pumpAndSettle();
          for (var step = 0; step < page; step++) {
            await tester.tap(find.text('Next'));
            await tester.pumpAndSettle();
          }

          final label = find.text(eyebrows[page]);
          final paragraph = tester.renderObject<RenderParagraph>(label);
          final foreground = paragraph.text.style!.color!;
          final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
          final background =
              scaffold.backgroundColor ??
              Theme.of(tester.element(label)).scaffoldBackgroundColor;

          expect(
            _contrast(foreground, background),
            greaterThanOrEqualTo(4.5),
            reason: 'Small text must remain readable on its rendered canvas.',
          );
        },
      );
    }
  }
}
