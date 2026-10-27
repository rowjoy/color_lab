import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/theme.dart';
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
    final animateTheme = _preferencesWereLoaded && loaded;
    _preferencesWereLoaded = loaded;
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appName,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      // Do not interpolate from the temporary System startup theme on first load.
      themeAnimationDuration:
          animateTheme &&
              !(MediaQuery.maybeOf(context)?.disableAnimations ?? false)
          ? AppMotion.standard
          : Duration.zero,
      themeAnimationCurve: AppMotion.enter,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
