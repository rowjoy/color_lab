import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/storage/app_storage_directory.dart';
import 'package:color_lab/features/coloring/application/coloring_export_service.dart';
import 'package:color_lab/features/coloring/application/coloring_project_providers.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/coloring_project_repository.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/history/application/history_providers.dart';
import 'package:color_lab/features/learning/application/learning_providers.dart';
import 'package:color_lab/features/learning/domain/learning_palette_copy.dart';
import 'package:color_lab/features/palette/application/saved_palettes_providers.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/features/settings/application/app_preferences_providers.dart';
import 'package:color_lab/features/settings/domain/app_preferences_repository.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:color_lab/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Runs the production routes and providers against isolated, real Hive files.
final class ColoringFlowHarness {
  ColoringFlowHarness._(
    this.container,
    this.router,
    this.repository,
    this.project,
    this.drawing,
  );

  final ProviderContainer container;
  final GoRouter router;
  final ColoringProjectRepository repository;
  final ColoringProject project;
  final DrawingDefinition drawing;

  static Future<ColoringFlowHarness> launch(
    WidgetTester tester, {
    String? location,
    LearningPaletteCopy? paletteCopy,
    ColoringExportService? encoder,
    RoomImageExportService? transport,
    bool seed = true,
  }) async {
    tester.view.physicalSize = const Size(1100, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late Directory temporary;
    late ProviderContainer container;
    late ColoringProjectRepository repository;
    late AppPreferencesRepository preferences;
    late ColoringProject project;
    late DrawingDefinition drawing;
    await tester.runAsync(() async {
      temporary = await Directory.systemTemp.createTemp('coloring-flow-');
      container = ProviderContainer(
        overrides: [
          appStorageDirectoryProvider.overrideWith(
            (ref) async => Directory('${temporary.path}/color_lab'),
          ),
          if (encoder != null)
            coloringExportServiceProvider.overrideWithValue(encoder),
          if (transport != null)
            roomImageExportServiceProvider.overrideWithValue(transport),
        ],
      );
      preferences = await container.read(
        appPreferencesRepositoryProvider.future,
      );
      await container.read(appPreferencesProvider.future);
      await container
          .read(appPreferencesProvider.notifier)
          .completeOnboarding();
      repository = await container.read(
        coloringProjectRepositoryProvider.future,
      );
      drawing = (await container.read(
        drawingCatalogProvider.future,
      )).firstWhere((item) => item.id == 'fruit_red_apple');
      project = ColoringProject.create(
        drawingId: drawing.id,
        drawingRevision: drawing.revision,
        mode: ColoringMode.free,
        clock: () => DateTime.utc(2026, 10, 28),
      );
      for (final region in drawing.artwork.regions.where(
        (item) => item.fillable,
      )) {
        final rule = drawing.regionRules[region.id]!;
        project = project.fill(
          region.id,
          drawing.slotById(rule.targetSlotId!).color,
          now: DateTime.utc(2026, 10, 28, 1),
        );
      }
      project = project.copyWith(completed: true);
      if (seed) await repository.save(project);
      await container.read(coloringProjectsProvider.future);
    });

    final router = container.read(appRouterProvider);
    router.go(
      location ?? '/coloring/complete/${project.id}',
      extra: paletteCopy,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      final learning = container.exists(learningRepositoryProvider)
          ? container.read(learningRepositoryProvider).value
          : null;
      final history = container.exists(colorHistoryRepositoryProvider)
          ? container.read(colorHistoryRepositoryProvider).value
          : null;
      final palettes = container.exists(savedPaletteRepositoryProvider)
          ? container.read(savedPaletteRepositoryProvider).value
          : null;
      var closed = false;
      Object? closeError;
      StackTrace? closeStack;
      Future.wait([
        repository.close(),
        preferences.close(),
        if (learning != null) learning.close(),
        if (history != null) history.close(),
        if (palettes != null) palettes.close(),
      ]).then(
        (_) => closed = true,
        onError: (Object error, StackTrace stackTrace) {
          closeError = error;
          closeStack = stackTrace;
          closed = true;
        },
      );
      // Repository queues can originate in the widget fake clock while Hive
      // completes file work on the real event loop. Drain both until the close
      // condition is observed instead of blocking either side of that bridge.
      for (var attempt = 0; !closed && attempt < 100; attempt++) {
        await tester.pump(const Duration(milliseconds: 1));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2)),
        );
      }
      if (!closed) {
        throw TimeoutException('Coloring flow storage did not close.');
      }
      if (closeError != null) {
        Error.throwWithStackTrace(closeError!, closeStack!);
      }
      container.dispose();
      await tester.runAsync(() => temporary.delete(recursive: true));
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ColoringFlowHarness._(
      container,
      router,
      repository,
      project,
      drawing,
    );
  }

  Future<ColoringProject?> persisted(WidgetTester tester, [String? id]) =>
      tester.runAsync<ColoringProject?>(
        () => repository.read(id ?? project.id),
      );
}

Future<void> tapColoringKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> pumpColoringUntil(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  expect(finder, findsOneWidget);
}

/// The only substituted boundaries are encoding and the native gallery/share UI.
final class ColoringEncoderBoundary implements ColoringExportService {
  ColoringEncoderBoundary(this.bytes, {this.fail = false});
  final Uint8List bytes;
  final bool fail;
  final projects = <ColoringProject>[];

  @override
  Future<Uint8List> encodePng(
    DrawingDefinition definition,
    ColoringProject project, {
    double scale = 2,
  }) async {
    projects.add(project);
    if (fail) throw const ColoringExportException();
    return Uint8List.fromList(bytes);
  }
}

final class ColoringNativeTransportBoundary implements RoomImageExportService {
  ColoringNativeTransportBoundary({
    this.shareResult = RoomShareResult.completed,
    this.failSave = false,
  });
  final RoomShareResult shareResult;
  bool failSave;
  final saved = <Uint8List>[];
  final shared = <Uint8List>[];
  final photoIds = <String>[];
  int preparations = 0;

  @override
  Future<void> prepareSave({required bool Function() isCurrent}) async {
    expect(isCurrent(), isTrue);
    preparations++;
  }

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String photoId,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    expect(isCurrent(), isTrue);
    if (failSave) throw const FileSystemException('No space left on device');
    saved.add(Uint8List.fromList(pngBytes));
    photoIds.add(photoId);
    onHandoff?.call();
  }

  @override
  Future<RoomShareResult> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
    required String title,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    expect(isCurrent(), isTrue);
    expect(origin.isEmpty, isFalse);
    expect(origin.isFinite, isTrue);
    expect(title, isNotEmpty);
    shared.add(Uint8List.fromList(pngBytes));
    photoIds.add(photoId);
    onHandoff?.call();
    return shareResult;
  }
}

final bridgeColors = [RgbColor(11, 22, 33), RgbColor(44, 55, 66)];
