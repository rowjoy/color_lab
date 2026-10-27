import 'dart:io';

import 'package:color_lab/app.dart';
import 'package:color_lab/bootstrap.dart';
import 'package:color_lab/features/games/presentation/games_screen.dart';
import 'package:color_lab/features/room_studio/application/room_model_download_providers.dart';
import 'package:color_lab/features/room_studio/models/room_model_store.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_gallery_screen.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/domain/app_preferences.dart';
import 'package:color_lab/features/color_test/presentation/vision_screen.dart';
import 'package:color_lab/features/shell/presentation/app_shell.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_app_preferences_repository.dart';

void main() {
  late ProviderContainer container;
  late RoomModelStore? modelStore;
  late int modelStoreReads;
  late int prepareAttempts;

  Future<void> launch(WidgetTester tester) async {
    modelStore = null;
    modelStoreReads = 0;
    prepareAttempts = 0;
    container = ProviderContainer(
      overrides: [
        roomModelStoreProvider.overrideWith((ref) {
          modelStoreReads++;
          return modelStore ??= RoomModelStore(
            directory: () {
              prepareAttempts++;
              return Future<Directory>.error(
                StateError('offline model storage must stay untouched'),
              );
            },
          );
        }),
        appPreferencesRepositoryProvider.overrideWith(
          (ref) async => InMemoryAppPreferencesRepository(
            initial: const AppPreferences(
              onboardingCompleted: true,
              themeMode: ThemeMode.dark,
            ),
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await modelStore?.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ColorLabBootstrap(),
      ),
    );
    await tester.pump();
  }

  testWidgets('mounts the app immediately without allocating Room models', (
    tester,
  ) async {
    await launch(tester);

    expect(find.byType(ColorLabApp), findsOneWidget);
    expect(modelStoreReads, 0);
    expect(prepareAttempts, 0);
    expect(container.exists(roomModelStartupProvider), isFalse);
    expect(container.exists(roomModelDownloadProgressProvider), isFalse);

    await tester.pumpAndSettle();

    expect(
      container.read(appRouterProvider).routeInformationProvider.value.uri.path,
      '/capture',
    );
    expect(find.text('Room Studio setup'), findsNothing);
    expect(
      Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
      Brightness.dark,
    );
    expect(modelStoreReads, 0);
    expect(prepareAttempts, 0);
  });

  testWidgets('offline models do not block non-model and illustrated routes', (
    tester,
  ) async {
    await launch(tester);
    await tester.pumpAndSettle();
    final router = container.read(appRouterProvider);

    router.go('/vision');
    await _pumpUntilRouteMounted(
      tester,
      present: find.byType(VisionScreen),
      absent: find.byType(AppShell),
    );
    expect(router.state.uri.path, '/vision');
    expect(find.byType(VisionScreen), findsOneWidget);

    router.go('/games');
    await _pumpUntilRouteMounted(
      tester,
      present: find.byType(GamesScreen),
      absent: find.byType(VisionScreen),
    );
    expect(router.state.uri.path, '/games');
    expect(find.byType(GamesScreen), findsOneWidget);

    router.go('/room/illustrated');
    await _pumpUntilRouteMounted(
      tester,
      present: find.byType(IllustratedRoomGalleryScreen),
      absent: find.byType(AppShell),
    );
    expect(router.state.uri.path, '/room/illustrated');
    expect(find.byType(IllustratedRoomGalleryScreen), findsOneWidget);

    expect(modelStoreReads, 0);
    expect(prepareAttempts, 0);
    expect(container.exists(roomModelStartupProvider), isFalse);
    expect(container.exists(roomModelDownloadProgressProvider), isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUntilRouteMounted(
  WidgetTester tester, {
  required Finder present,
  required Finder absent,
}) async {
  for (var frame = 0; frame < 60; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    if (present.evaluate().isNotEmpty && absent.evaluate().isEmpty) return;
  }
  fail(
    'Route transition did not complete within 60 frames: '
    '$present present, $absent absent',
  );
}
