import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'tokens.dart';

abstract final class AppTheme {
  static final light = _build(Brightness.light, AppColors.light);
  static final dark = _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: AppColors.onPrimary,
          surface: colors.surface,
          onSurface: colors.textPrimary,
          onSurfaceVariant: colors.textSecondary,
          outline: colors.outline,
          error: colors.error,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      scaffoldBackgroundColor: colors.background,
      textTheme: AppTypography.textTheme(
        colors.textPrimary,
        colors.textSecondary,
      ),
      extensions: [colors],
      dividerColor: colors.outline,
      splashFactory: InkRipple.splashFactory,
      iconTheme: IconThemeData(color: colors.textPrimary, size: 24),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.textPrimary,
        contentTextStyle: TextStyle(
          color: colors.background,
          fontFamily: AppTypography.family,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.large),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colors.primary,
        inactiveTrackColor: colors.outline,
        thumbColor: colors.primary,
        overlayColor: colors.primary.withValues(alpha: .12),
        trackHeight: 4,
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: TextStyle(
          color: colors.background,
          fontFamily: AppTypography.family,
        ),
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
      ),
    );
  }
}
