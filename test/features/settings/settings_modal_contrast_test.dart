import 'dart:async';

import 'package:color_lab/app.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/application/acquisition_intent_providers.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
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
  const errorMessage = "Couldn't save your appearance. Try again.";

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
    await tester.tap(find.byTooltip('Appearance settings'));
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
        await tester.tap(find.text(dark ? 'Light' : 'Dark'));
        await tester.pumpAndSettle();

        final error = find.text(errorMessage);
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
    for (final label in ['Capture', 'Palette', 'Lab', 'Room']) {
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
    final tabPosition = tester.getCenter(find.byKey(const ValueKey('nav-Lab')));
    await openSettings(tester);
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(find.text('Saving appearance…'), findsOneWidget);

    await tester.tapAt(tabPosition);
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/capture',
    );
    expect(find.text('Saving appearance…'), findsOneWidget);
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
    final tabPosition = tester.getCenter(find.byKey(const ValueKey('nav-Lab')));
    await openSettings(tester);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(find.text(errorMessage), findsOneWidget);

    await tester.tapAt(tabPosition);
    await tester.pumpAndSettle();
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/capture',
    );
    expect(find.text(errorMessage), findsOneWidget);
  });
}
