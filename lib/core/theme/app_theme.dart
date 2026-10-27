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
    final minimumControlSize = const WidgetStatePropertyAll(
      Size(AppTouchTargets.minimum, AppTouchTargets.minimum),
    );
    final controlOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (states.contains(WidgetState.focused)) {
        return colors.focusRing.withValues(alpha: .16);
      }
      if (states.contains(WidgetState.pressed)) return colors.pressedOverlay;
      return null;
    });
    Color navigationColor(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return colors.disabled;
      if (states.contains(WidgetState.selected)) return colors.textPrimary;
      return colors.textSecondary;
    }

    final navigationLabel = WidgetStateProperty.resolveWith<TextStyle?>(
      (states) => TextStyle(
        color: navigationColor(states),
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
      ),
    );
    final navigationIcon = WidgetStateProperty.resolveWith<IconThemeData?>(
      (states) => IconThemeData(color: navigationColor(states)),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: scheme,
      focusColor: colors.focusRing,
      highlightColor: colors.pressedOverlay,
      disabledColor: colors.disabled,
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
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: minimumControlSize,
          overlayColor: controlOverlay,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: minimumControlSize,
          overlayColor: controlOverlay,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: minimumControlSize,
          overlayColor: controlOverlay,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: minimumControlSize,
          overlayColor: controlOverlay,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        backgroundColor: colors.surface,
        indicatorColor: colors.selectedSurface,
        labelTextStyle: navigationLabel,
        iconTheme: navigationIcon,
        overlayColor: controlOverlay,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colors.surface,
        indicatorColor: colors.selectedSurface,
        selectedIconTheme: IconThemeData(color: colors.textPrimary),
        unselectedIconTheme: IconThemeData(color: colors.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: colors.textSecondary),
      ),
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
