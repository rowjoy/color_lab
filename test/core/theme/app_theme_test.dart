import 'package:color_lab/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sheet motion follows reduced-motion preference', (tester) async {
    for (final disabled in [false, true]) {
      late AnimationStyle style;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disabled),
          child: Builder(
            builder: (context) {
              style = AppMotion.sheetAnimation(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        style.duration,
        disabled ? Duration.zero : const Duration(milliseconds: 400),
      );
      expect(
        style.reverseDuration,
        disabled ? Duration.zero : const Duration(milliseconds: 250),
      );
    }
  });

  testWidgets('themes supply approved surfaces and readable text', (
    tester,
  ) async {
    for (final entry in [
      (AppTheme.light, const Color(0xFFF7F7F9), const Color(0xFF0F1115)),
      (AppTheme.dark, const Color(0xFF0E0F13), const Color(0xFFF4F5F7)),
    ]) {
      late AppColors colors;
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.$1,
          home: Builder(
            builder: (context) {
              colors = context.appColors;
              return const Scaffold(body: Text('Color Lab'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(colors.background, entry.$2);
      expect(colors.textPrimary, entry.$3);
      expect(entry.$1.scaffoldBackgroundColor, entry.$2);
      expect(entry.$1.textTheme.bodyMedium?.color, entry.$3);
      expect(entry.$1.textTheme.bodyMedium?.fontFamily, 'PlusJakartaSans');
      expect(entry.$1.textTheme.displaySmall?.fontSize, 32);
      expect(entry.$1.textTheme.headlineSmall?.fontSize, 22);
      expect(entry.$1.textTheme.titleSmall?.fontSize, 16);
      expect(entry.$1.textTheme.labelSmall?.fontSize, 12);
    }
  });
}
