import 'dart:async';

import 'package:color_lab/app.dart';
import 'package:color_lab/bootstrap.dart';
import 'package:color_lab/features/room_studio/application/room_model_download_providers.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_app_preferences_repository.dart';

void main() {
  late Completer<void> preparation;
  late StreamController<RoomModelDownloadProgress> progress;
  late ProviderContainer container;
  late int attempts;

  Future<void> launch(WidgetTester tester, {bool cached = false}) async {
    preparation = Completer<void>();
    progress = StreamController.broadcast();
    attempts = 0;
    container = ProviderContainer(
      overrides: [
        roomModelStartupProvider.overrideWith((ref) {
          attempts++;
          return cached ? Future<void>.value() : preparation.future;
        }),
        roomModelDownloadProgressProvider.overrideWith(
          (ref) => progress.stream,
        ),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(
            initial: const AppPreferences(
              onboardingCompleted: false,
              themeMode: ThemeMode.dark,
            ),
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await progress.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabBootstrap(),
      ),
    );
    await tester.pump();
  }

  Future<void> emit(
    WidgetTester tester,
    RoomModelDownloadStage stage,
    int bytes,
  ) async {
    progress.add(
      RoomModelDownloadProgress(
        stage: stage,
        receivedBytes: bytes,
        totalBytes: 100,
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('gates app with actual progress and waits for verification', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('Room Studio setup'), findsOneWidget);
    expect(find.text('1%'), findsOneWidget);
    expect(find.byType(ColorLabApp), findsNothing);
    await emit(tester, RoomModelDownloadStage.downloading, 42);
    expect(find.text('42%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .42,
    );
    await emit(tester, RoomModelDownloadStage.verifying, 100);
    expect(find.text('99%'), findsOneWidget);
    expect(find.text('Verifying AI models…'), findsOneWidget);
    expect(find.byType(ColorLabApp), findsNothing);
    preparation.complete();
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(ColorLabApp), findsOneWidget);
    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/onboarding',
    );
    expect(attempts, 1);
  });

  testWidgets('verified cache advances automatically with saved dark theme', (
    tester,
  ) async {
    await launch(tester, cached: true);
    await tester.pumpAndSettle();
    expect(find.byType(ColorLabApp), findsOneWidget);
    expect(find.text('Room Studio setup'), findsNothing);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(attempts, 1);
  });

  testWidgets('failure stays gated with safe retry and no automatic retry', (
    tester,
  ) async {
    await launch(tester);
    preparation.completeError(StateError('private storage path or URL'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorLabApp), findsNothing);
    expect(find.textContaining('private storage'), findsNothing);
    expect(find.text('Retry setup'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(attempts, 1);
    preparation = Completer<void>();
    await tester.tap(find.text('Retry setup'));
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(ColorLabApp), findsNothing);
    expect(find.text('Setup could not finish'), findsNothing);
    expect(find.text('Retry setup'), findsNothing);
    await emit(tester, RoomModelDownloadStage.downloading, 25);
    expect(find.text('Downloading AI models…'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    preparation.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ColorLabApp), findsOneWidget);
  });

  testWidgets('post-setup provider updates never remount app or router', (
    tester,
  ) async {
    await launch(tester, cached: true);
    await tester.pumpAndSettle();
    final appState = tester.state(find.byType(ColorLabApp));
    final router = container.read(appRouterProvider);
    router.go('/onboarding?source=setup-test');
    await tester.pumpAndSettle();
    container.invalidate(roomModelStartupProvider);
    await emit(tester, RoomModelDownloadStage.failed, 0);
    await tester.pumpAndSettle();
    expect(identical(tester.state(find.byType(ColorLabApp)), appState), isTrue);
    expect(identical(container.read(appRouterProvider), router), isTrue);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/onboarding?source=setup-test',
    );
  });

  testWidgets('setup and error fit narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await launch(tester);
    await emit(tester, RoomModelDownloadStage.downloading, 50);
    expect(tester.takeException(), isNull);
    preparation.completeError(const RoomModelDownloadException());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry setup'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('late completion after disposal cannot open app', (tester) async {
    await launch(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    preparation.complete();
    await tester.pump();
    expect(find.byType(ColorLabApp), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
