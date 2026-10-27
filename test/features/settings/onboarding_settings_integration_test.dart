import 'dart:async';

import 'package:color_lab/app.dart';
import 'package:color_lab/core/color/color_engine.dart';
import 'package:color_lab/core/config/app_identity.dart';
import 'package:color_lab/core/widgets/widgets.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/history/domain/saved_color.dart';
import 'package:color_lab/features/onboarding/presentation/onboarding_screen.dart';
import 'package:color_lab/features/picker/application/camera_session.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/picker/presentation/color_explorer.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/application/theme_mode_provider.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_app_preferences_repository.dart';
import '../../support/in_memory_color_history_repository.dart';
import '../../support/in_memory_acquisition_intent_store.dart';

class _NoPromptPhotoPicker implements PhotoPickerService {
  int recoveries = 0, picks = 0;
  @override
  Future<PreparedPhoto?> pick({
    PhotoSource source = PhotoSource.gallery,
  }) async {
    picks++;
    return null;
  }

  @override
  Future<PreparedPhoto?> recoverLost() async {
    recoveries++;
    return null;
  }

  @override
  Future<bool> openSettings() async => false;
}

void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester,
    InMemoryAppPreferencesRepository repository, {
    bool settle = true,
    PhotoPickerService? picker,
    void Function()? onCamera,
  }) async {
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
        colorNamerProvider.overrideWith(
          (ref) async =>
              ColorNamer([NamedColor('Lilac', RgbColor.fromHex('#B2A4D4'))]),
        ),
        photoPickerServiceProvider.overrideWithValue(
          picker ?? _NoPromptPhotoPicker(),
        ),
        cameraSessionFactoryProvider.overrideWithValue(() {
          onCamera?.call();
          throw StateError('Onboarding must not create a camera');
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabApp(),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return container;
  }

  testWidgets(
    'first launch guards camera until skipped without requesting permissions',
    (tester) async {
      final repository = InMemoryAppPreferencesRepository(
        initial: const AppPreferences(),
      );
      final picker = _NoPromptPhotoPicker();
      var cameras = 0;
      final container = await launch(
        tester,
        repository,
        picker: picker,
        onCamera: () => cameras++,
      );
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-Capture')), findsNothing);
      container.read(appRouterProvider).go('/camera');
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(cameras, 0);
      expect(picker.recoveries, 0);
      expect(picker.picks, 0);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(repository.value.onboardingCompleted, isTrue);
      expect(find.text('See the world'), findsOneWidget);
      expect(cameras, 0);
      expect(picker.picks, 0);
    },
  );

  testWidgets(
    'pending and failed onboarding saves never start recovery before commit',
    (tester) async {
      final repository =
          InMemoryAppPreferencesRepository(initial: const AppPreferences())
            ..saveGate = Completer<void>()
            ..failSave = true;
      final picker = _NoPromptPhotoPicker();
      var cameras = 0;
      await launch(
        tester,
        repository,
        picker: picker,
        onCamera: () => cameras++,
      );
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(picker.recoveries, 0);
      expect(picker.picks, 0);
      expect(cameras, 0);
      repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(picker.recoveries, 0);
      repository.failSave = false;
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('See the world'), findsOneWidget);
      expect(picker.recoveries, 1);
      expect(picker.picks, 0);
      expect(cameras, 0);
    },
  );

  testWidgets('finishing three slides is remembered by a fresh app container', (
    tester,
  ) async {
    final repository = InMemoryAppPreferencesRepository(
      initial: const AppPreferences(),
    );
    await launch(tester, repository);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    expect(repository.value.onboardingCompleted, isTrue);
    await tester.pumpWidget(const SizedBox());
    await launch(tester, repository);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('See the world'), findsOneWidget);
  });

  testWidgets(
    'failed completion stays on the tour and retries without false success',
    (tester) async {
      final repository = InMemoryAppPreferencesRepository(
        initial: const AppPreferences(),
      )..failSave = true;
      await launch(tester, repository);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(repository.value.onboardingCompleted, isFalse);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('See the world'), findsNothing);
      repository.failSave = false;
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(repository.value.onboardingCompleted, isTrue);
      expect(find.text('See the world'), findsOneWidget);
    },
  );

  testWidgets(
    'startup waits for stored dark appearance before building Capture',
    (tester) async {
      final gate = Completer<void>();
      final repository = InMemoryAppPreferencesRepository(
        initial: const AppPreferences(
          themeMode: ThemeMode.dark,
          onboardingCompleted: true,
        ),
      )..loadGate = gate;
      final container = await launch(tester, repository, settle: false);
      expect(find.byKey(const ValueKey('screen-Capture')), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('screen-Capture'))),
        ).brightness,
        Brightness.dark,
      );
      final router = container.read(appRouterProvider);
      container.read(themeModeProvider.notifier).setMode(ThemeMode.light);
      await tester.pumpAndSettle();
      expect(repository.value.themeMode, ThemeMode.light);
      expect(container.read(appRouterProvider), same(router));
    },
  );

  testWidgets(
    'first Capture frame uses saved dark theme without a light-theme flash',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final gate = Completer<void>();
      final repository = InMemoryAppPreferencesRepository(
        initial: const AppPreferences(
          themeMode: ThemeMode.dark,
          onboardingCompleted: true,
        ),
      )..loadGate = gate;
      await launch(tester, repository, settle: false);
      gate.complete();
      for (
        var frame = 0;
        frame < 20 &&
            find.byKey(const ValueKey('screen-Capture')).evaluate().isEmpty;
        frame++
      ) {
        await tester.pump();
      }
      final capture = find.byKey(const ValueKey('screen-Capture'));
      expect(capture, findsOneWidget);
      expect(Theme.of(tester.element(capture)).brightness, Brightness.dark);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'startup load error has safe retry and never exposes private exception',
    (tester) async {
      final repository = InMemoryAppPreferencesRepository()..failLoad = true;
      await launch(tester, repository);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('private preferences'), findsNothing);
      repository.failLoad = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('See the world'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('appearance failure retains committed mode and permits retry', (
    tester,
  ) async {
    final repository = InMemoryAppPreferencesRepository()..failSave = true;
    final container = await launch(tester, repository);
    await tester.tap(find.byTooltip('Appearance settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't save your appearance. Try again."),
      findsOneWidget,
    );
    expect(container.read(themeModeProvider), ThemeMode.system);
    expect(repository.value.themeMode, ThemeMode.system);
    repository.failSave = false;
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(repository.value.themeMode, ThemeMode.dark);
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('screen-Capture'))),
      ).brightness,
      Brightness.dark,
    );
  });

  testWidgets(
    'replaying tour returns to Lab without resetting its edited color or theme',
    (tester) async {
      final repository = InMemoryAppPreferencesRepository(
        initial: const AppPreferences(
          themeMode: ThemeMode.dark,
          onboardingCompleted: true,
        ),
      );
      final container = await launch(tester, repository);
      await container.read(colorHistoryProvider.future);
      await container
          .read(colorHistoryProvider.notifier)
          .saveColor(
            RgbColor.fromHex('#B2A4D4'),
            name: 'Lilac',
            source: ColorSource.camera,
          );
      final savedColors = container.read(colorHistoryProvider).requireValue;
      await tester.tap(find.byKey(const ValueKey('nav-Lab')));
      await tester.pumpAndSettle();
      tester.widgetList<Slider>(find.byType(Slider)).first.onChanged!(123);
      await tester.pumpAndSettle();
      final edited = tester
          .widget<ColorSwatchTile>(find.byType(ColorSwatchTile))
          .hex;
      await tester.tap(find.byTooltip('Appearance settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Replay welcome tour'));
      await tester.tap(find.text('Replay welcome tour'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('screen-Lab')), findsOneWidget);
      expect(
        tester.widget<ColorSwatchTile>(find.byType(ColorSwatchTile)).hex,
        edited,
      );
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(repository.value.onboardingCompleted, isTrue);
      expect(repository.saves, 0);
      expect(container.read(colorHistoryProvider).requireValue, savedColors);
    },
  );

  testWidgets('appearance controls remain usable at 360px with doubled text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester, InMemoryAppPreferencesRepository());
    await tester.tap(find.byTooltip('Appearance settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dark'));
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Replay welcome tour'));
    expect(find.text('Replay welcome tour').hitTestable(), findsOneWidget);
    final about = find.text('About ${AppIdentity.displayName} & licenses');
    await tester.ensureVisible(about);
    expect(about, findsOneWidget);
  });
}
