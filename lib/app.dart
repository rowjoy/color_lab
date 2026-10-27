import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/theme.dart';
import 'core/widgets/color_label_scope.dart';
import 'features/settings/domain/app_preferences.dart';
import 'features/settings/application/theme_mode_provider.dart';
import 'features/settings/application/app_preferences_providers.dart';
import 'l10n/l10n.dart';
import 'routing/app_router.dart';

class ColorLabApp extends ConsumerStatefulWidget {
  const ColorLabApp({super.key});

  @override
  ConsumerState<ColorLabApp> createState() => _ColorLabAppState();
}

class _ColorLabAppState extends ConsumerState<ColorLabApp> {
  bool _preferencesWereLoaded = false;

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(appPreferencesProvider).hasValue;
    final preferences =
        ref.watch(appPreferencesProvider).value ?? const AppPreferences();
    final platform = MediaQueryData.fromView(View.of(context));
    final reduceMotion =
        preferences.motion == MotionPreference.reduce ||
        platform.disableAnimations ||
        platform.accessibleNavigation;
    final animateTheme = _preferencesWereLoaded && loaded;
    _preferencesWereLoaded = loaded;
    return MaterialApp.router(
      restorationScopeId: 'tintatlas-app',
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: preferences.highContrast
          ? AppTheme.highContrastLight
          : AppTheme.light,
      darkTheme: preferences.highContrast
          ? AppTheme.highContrastDark
          : AppTheme.dark,
      highContrastTheme: AppTheme.highContrastLight,
      highContrastDarkTheme: AppTheme.highContrastDark,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations:
                reduceMotion ||
                media.disableAnimations ||
                media.accessibleNavigation,
            highContrast: preferences.highContrast || media.highContrast,
          ),
          child: ColorLabelScope(
            alwaysShow: preferences.alwaysShowColorLabels,
            child: child!,
          ),
        );
      },
      themeMode: ref.watch(themeModeProvider),
      // Do not interpolate from the temporary System startup theme on first load.
      themeAnimationDuration: animateTheme && !reduceMotion
          ? AppMotion.standard
          : Duration.zero,
      themeAnimationCurve: AppMotion.enter,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
