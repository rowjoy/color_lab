import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4,
      sm = 8,
      md = 12,
      lg = 16,
      xl = 20,
      xxl = 24,
      xxxl = 32,
      huge = 48;
  static const screenPadding = EdgeInsets.all(xl);
}

abstract final class AppLayout {
  static const double compactPagePadding = AppSpacing.lg;
  static const double regularPagePadding = AppSpacing.xxl;
  static const double widePagePadding = AppSpacing.xxxl;
  static const double contentGap = AppSpacing.xxl;
  static const double inspectorWidth = 320;
  static const double defaultMaxContentWidth = 1200;
}

abstract final class AppTouchTargets {
  static const double minimum = 48;
}

abstract final class AppRadii {
  static const double small = 12,
      medium = 20,
      large = 28,
      swatch = 24,
      pill = 999;
}

abstract final class AppMotion {
  static const micro = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 250);
  static const page = Duration(milliseconds: 400);
  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const sheet = Curves.easeOutBack;
  static Duration duration(BuildContext context, [Duration value = standard]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
  static AnimationStyle sheetAnimation(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : const AnimationStyle(duration: page, reverseDuration: standard);
}

abstract final class AppTypography {
  static const family = 'PlusJakartaSans';
  static const monoFamily = 'JetBrainsMono';
  static const mono = TextStyle(
    fontFamily: monoFamily,
    fontSize: 14,
    height: 22 / 14,
  );
  static TextTheme textTheme(Color primary, Color secondary) {
    final display = TextStyle(
      fontSize: 32,
      height: 40 / 32,
      fontWeight: FontWeight.w700,
      color: primary,
    );
    final title = TextStyle(
      fontSize: 22,
      height: 28 / 22,
      fontWeight: FontWeight.w700,
      color: primary,
    );
    final subtitle = TextStyle(
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w600,
      color: primary,
    );
    final body = TextStyle(
      fontSize: 14,
      height: 22 / 14,
      fontWeight: FontWeight.w400,
      color: primary,
    );
    final caption = TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
      color: secondary,
    );
    return TextTheme(
      displayLarge: display,
      displayMedium: display,
      displaySmall: display,
      headlineLarge: title,
      headlineMedium: title,
      headlineSmall: title,
      titleLarge: title,
      titleMedium: subtitle,
      titleSmall: subtitle,
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: caption,
      labelLarge: body.copyWith(fontWeight: FontWeight.w600),
      labelMedium: caption,
      labelSmall: caption,
    ).apply(fontFamily: family);
  }
}
