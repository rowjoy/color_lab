import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    this.primary = const Color(0xFF6C5CE7),
    this.gradientStart = const Color(0xFF7C5CFF),
    this.gradientEnd = const Color(0xFFFF5C9E),
    this.success = const Color(0xFF22C55E),
    this.warning = const Color(0xFFF59E0B),
    this.error = const Color(0xFFEF4444),
  });

  final Color background,
      surface,
      surfaceElevated,
      outline,
      textPrimary,
      textSecondary,
      primary,
      gradientStart,
      gradientEnd,
      success,
      warning,
      error;
  static const onPrimary = Color(0xFFFFFFFF);
  static const light = AppColors(
    background: Color(0xFFF7F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF0F1F4),
    outline: Color(0xFFE3E5EA),
    textPrimary: Color(0xFF0F1115),
    textSecondary: Color(0xFF5F6572),
  );
  static const dark = AppColors(
    background: Color(0xFF0E0F13),
    surface: Color(0xFF16181D),
    surfaceElevated: Color(0xFF1E2128),
    outline: Color(0xFF2A2E37),
    textPrimary: Color(0xFFF4F5F7),
    textSecondary: Color(0xFF9AA0AD),
  );
  LinearGradient get accentGradient => LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  List<BoxShadow> get shadows => background == dark.background
      ? const []
      : [
          BoxShadow(
            color: light.textPrimary.withValues(alpha: .06),
            offset: const Offset(0, 8),
            blurRadius: 24,
          ),
        ];

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? primary,
    Color? gradientStart,
    Color? gradientEnd,
    Color? success,
    Color? warning,
    Color? error,
  }) => AppColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    outline: outline ?? this.outline,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    primary: primary ?? this.primary,
    gradientStart: gradientStart ?? this.gradientStart,
    gradientEnd: gradientEnd ?? this.gradientEnd,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
  );

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColors.dark
          : AppColors.light);
}
