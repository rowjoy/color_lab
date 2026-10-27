import 'dart:async';

import 'package:color_lab/app.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/core/widgets/color_widgets.dart';
import 'package:color_lab/core/widgets/color_label_scope.dart';
import 'package:color_lab/features/settings/presentation/privacy_screen.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_app_preferences_repository.dart';
import '../../support/in_memory_color_history_repository.dart';
import '../../support/in_memory_acquisition_intent_store.dart';

class _QuietPhotoPicker implements PhotoPickerService {
  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async => null;
  @override
  Future<PreparedPhoto?> recoverLost() async => null;
  @override
  Future<bool> openSettings() async => false;
}

double _contrast(Color foreground, Color background) {
  final luminance = [
    foreground.computeLuminance(),
    background.computeLuminance(),
  ]..sort();
  return (luminance.last + .05) / (luminance.first + .05);
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<ProviderContainer> launch(
    WidgetTester tester,
    InMemoryAppPreferencesRepository repository,
  ) async {
    final container = ProviderContainer(
      overrides: [
        acquisitionIntentStoreProvider.overrideWith(
          (ref) async => InMemoryAcquisitionIntentStore(),
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => repository,
        ),
        colorHistoryRepositoryProvider.overrideWith(
          (ref) async => InMemoryColorHistoryRepository(),
        ),
        photoPickerServiceProvider.overrideWithValue(_QuietPhotoPicker()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip(l10n.appearanceSettings));
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets(
      'failed-save text has 4.5 contrast in ${dark ? 'dark' : 'light'} settings',
      (tester) async {
        await launch(
          tester,
          InMemoryAppPreferencesRepository(
            initial: AppPreferences(
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              onboardingCompleted: true,
            ),
          )..failSave = true,
        );
        await openSettings(tester);
        await tester.tap(find.text(dark ? l10n.themeLight : l10n.themeDark));
        await tester.pumpAndSettle();

        final error = find.text(l10n.settingsSaveError);
        expect(error, findsOneWidget);
        final foreground = tester
            .renderObject<RenderParagraph>(error)
            .text
            .style!
            .color!;
        final material = tester.widget<Material>(
          find.ancestor(of: error, matching: find.byType(Material)).first,
        );
        expect(material.color, isNotNull);
        expect(
          _contrast(foreground, material.color!),
          greaterThanOrEqualTo(4.5),
          reason: 'Read the actual error text and sheet background colors.',
        );
      },
    );
  }

  testWidgets('settings modal prevents hit testing every studio tab', (
    tester,
  ) async {
    await launch(tester, InMemoryAppPreferencesRepository());
    await openSettings(tester);
    for (final label in ['home', 'rooms', 'learn', 'games']) {
      expect(
        find.byKey(ValueKey('nav-$label')).hitTestable(),
        findsNothing,
        reason: 'A modal settings route must cover the outer shell tabs.',
      );
    }
  });

  testWidgets('tab-position tap cannot hide a pending appearance save', (
    tester,
  ) async {
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final repository = InMemoryAppPreferencesRepository()..saveGate = gate;
    final container = await launch(tester, repository);
    final tabPosition = tester.getCenter(
      find.byKey(const ValueKey('nav-learn')),
    );
    await openSettings(tester);
    await tester.tap(find.text(l10n.themeDark));
    await tester.pump();
    expect(find.text(l10n.savingAppearance), findsOneWidget);

    await tester.tapAt(tabPosition);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/home',
    );
    expect(find.text(l10n.savingAppearance), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('tab-position tap cannot hide an appearance save error', (
    tester,
  ) async {
    final container = await launch(
      tester,
      InMemoryAppPreferencesRepository()..failSave = true,
    );
    final tabPosition = tester.getCenter(
      find.byKey(const ValueKey('nav-learn')),
    );
    await openSettings(tester);
    await tester.tap(find.text(l10n.themeDark));
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsSaveError), findsOneWidget);

    await tester.tapAt(tabPosition);
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/home',
    );
    expect(find.text(l10n.settingsSaveError), findsOneWidget);
  });

  testWidgets(
    'accessibility preferences drive root motion, theme and optional labels',
    (tester) async {
      final container = await launch(
        tester,
        InMemoryAppPreferencesRepository(
          initial: const AppPreferences(
            onboardingCompleted: true,
            motion: MotionPreference.reduce,
            highContrast: true,
            alwaysShowColorLabels: true,
          ),
        ),
      );
      container.read(appRouterProvider).go('/settings/privacy');
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(PrivacyScreen));
      expect(MediaQuery.of(context).disableAnimations, true);
      expect(ColorLabelScope.of(context), true);
      expect(
        Theme.of(context).colorScheme.outline,
        AppTheme.highContrastLight.colorScheme.outline,
      );
      final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(material.themeAnimationDuration, Duration.zero);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesRepositoryProvider.overrideWith(
              (ref) async => InMemoryAppPreferencesRepository(
                initial: const AppPreferences(alwaysShowColorLabels: true),
              ),
            ),
          ],
          child: const MaterialApp(
            home: ColorLabelScope(
              alwaysShow: true,
              child: Scaffold(body: ColorChip(color: Color(0xFFFF0000))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('#FF0000'), findsOneWidget);
    },
  );

  testWidgets(
    'system reduced motion remains enabled with the system preference',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final container = await launch(
        tester,
        InMemoryAppPreferencesRepository(),
      );
      container.read(appRouterProvider).go('/settings/privacy');
      await tester.pumpAndSettle();
      expect(
        MediaQuery.of(
          tester.element(find.byType(PrivacyScreen)),
        ).disableAnimations,
        true,
      );
    },
  );
}
