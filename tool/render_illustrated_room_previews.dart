// Run with the compiler-denying sandbox; see README's guarded preview command.
// Writes deterministic multi-room evidence to build/previews.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/theme/theme.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_gallery_screen.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_screen.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as image;

import '../test/support/illustrated_room_svg_contract.dart';
import '../test/support/in_memory_room_design_repository.dart';

final _capturedNames = <String>{};
final _expectedNames = <String>{
  for (final template in IllustratedRoomCatalog.all) ...{
    'illustrated-room-artwork-${template.id}-grayscale.png',
    'illustrated-room-artwork-${template.id}-recommended.png',
    'illustrated-room-artwork-${template.id}-stress.png',
  },
  'illustrated-room-gallery-phone.png',
  'illustrated-room-gallery-tablet.png',
  'illustrated-room-editor-phone-rail-closed.png',
  'illustrated-room-editor-phone-rail-open.png',
  'illustrated-room-editor-phone-focus.png',
  'illustrated-room-editor-phone-whole-room.png',
  'illustrated-room-editor-landscape-640x360.png',
  'illustrated-room-editor-tablet-1024x768.png',
  'illustrated-room-export-study-recommended-2400x1600.png',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final font in [
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      ('PlusJakartaSans', 'assets/fonts/PlusJakartaSans-Variable.ttf'),
      ('JetBrainsMono', 'assets/fonts/JetBrainsMono-Variable.ttf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });

  tearDownAll(() async {
    expect(_capturedNames, _expectedNames);
    expect(_capturedNames, hasLength(27));
    final templates = IllustratedRoomCatalog.all.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final assetMetrics = <String, Map<String, int>>{};
    for (final template in templates) {
      final metrics = illustratedRoomSvgMetrics(
        await rootBundle.loadString(template.assetPath),
      );
      assetMetrics[template.id] = {
        'utf8Bytes': metrics.utf8Bytes,
        'geometryCount': metrics.geometryCount,
        'gradientCount': metrics.gradientCount,
        'clipPathCount': metrics.clipPathCount,
      };
    }
    final output = Directory('build/previews');
    await output.create(recursive: true);
    await File(
      '${output.path}/illustrated-room-render-manifest.json',
    ).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'scope': 'Illustrated room previews captured by this invocation',
        'count': 27,
        'files': _expectedNames.toList()..sort(),
        'assetMetrics': assetMetrics,
      }),
      flush: true,
    );
  });

  testWidgets('render all six canonical room artworks', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();

    for (final template in IllustratedRoomCatalog.all) {
      Future<void> render(IllustratedRoomDraft draft, String suffix) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 1200,
                height: 800,
                child: IllustratedRoomSvg(draft: draft, fit: BoxFit.fill),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _capture(
          tester,
          boundary,
          'illustrated-room-artwork-${template.id}-$suffix',
          pixelRatio: 2,
        );
      }

      await render(IllustratedRoomDraft.grayscale(template), 'grayscale');
      await render(
        IllustratedRoomDraft.grayscale(
          template,
        ).applyPalette(template.defaultPaletteId),
        'recommended',
      );
      var stress = IllustratedRoomDraft.grayscale(template);
      for (final entry in <IllustratedRoomSurface, String>{
        IllustratedRoomSurface.wall: '#F4EEE4',
        IllustratedRoomSurface.ceiling: '#20242C',
        IllustratedRoomSurface.floor: '#0057FF',
        IllustratedRoomSurface.furniture: '#FF4D00',
      }.entries) {
        stress = stress.setSurfaceColor(
          entry.key,
          RgbColor.fromHex(entry.value),
        );
      }
      await render(stress, 'stress');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('render real recommended Study export at 2400 x 1600', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final draft = IllustratedRoomDraft.grayscale(
        IllustratedRoomCatalog.study,
      ).applyPalette(IllustratedRoomCatalog.study.defaultPaletteId);
      final png = await SvgIllustratedRoomArtworkEncoder().encodePng(draft);
      final decoded = image.decodePng(png);
      expect(decoded, isNotNull);
      expect((decoded!.width, decoded.height), (2400, 1600));
      const name = 'illustrated-room-export-study-recommended-2400x1600.png';
      final output = Directory('build/previews');
      await output.create(recursive: true);
      await File('${output.path}/$name').writeAsBytes(png, flush: true);
      expect(_capturedNames.add(name), isTrue);
    });
  });

  for (final scenario in [
    (name: 'illustrated-room-gallery-phone', size: const Size(390, 844)),
    (name: 'illustrated-room-gallery-tablet', size: const Size(1024, 768)),
  ]) {
    testWidgets('render ${scenario.name}', (tester) async {
      final harness = await _pumpUi(
        tester,
        size: scenario.size,
        initialLocation: '/room/illustrated',
      );
      await _capture(tester, harness.boundary, scenario.name);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('render phone editor with rail closed open and focus preview', (
    tester,
  ) async {
    final harness = await _pumpUi(
      tester,
      size: const Size(390, 844),
      initialLocation: '/room/illustrated/study',
    );
    await _capture(
      tester,
      harness.boundary,
      'illustrated-room-editor-phone-rail-closed',
    );

    final showTools = find.byKey(
      const ValueKey('room-show-color-tools'),
      skipOffstage: false,
    );
    await tester.tap(showTools);
    await tester.pumpAndSettle();
    final looks = find.byKey(
      const ValueKey('room-rail-looks'),
      skipOffstage: false,
    );
    await tester.ensureVisible(looks);
    await tester.pumpAndSettle();
    await tester.tap(looks);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('room-flyout')), findsOneWidget);
    await _capture(
      tester,
      harness.boundary,
      'illustrated-room-editor-phone-rail-open',
    );

    await tester.tap(
      find.byKey(const ValueKey('room-focus-preview'), skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('room-exit-focus-preview')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('room-editor-back')), findsNothing);
    expect(find.byKey(const ValueKey('room-color-rail')), findsNothing);
    await _capture(
      tester,
      harness.boundary,
      'illustrated-room-editor-phone-focus',
    );
    await tester.tap(find.byKey(const ValueKey('room-exit-focus-preview')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('room-view-full'), skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<IllustratedRoomSvg>(find.byType(IllustratedRoomSvg)).fit,
      BoxFit.contain,
    );
    await _capture(
      tester,
      harness.boundary,
      'illustrated-room-editor-phone-whole-room',
    );
    expect(tester.takeException(), isNull);
  });

  for (final scenario in [
    (
      name: 'illustrated-room-editor-landscape-640x360',
      size: const Size(640, 360),
    ),
    (
      name: 'illustrated-room-editor-tablet-1024x768',
      size: const Size(1024, 768),
    ),
  ]) {
    testWidgets('render ${scenario.name}', (tester) async {
      final harness = await _pumpUi(
        tester,
        size: scenario.size,
        initialLocation: '/room/illustrated/study',
      );
      harness.container
          .read(illustratedRoomProvider.notifier)
          .applyPalette(IllustratedRoomCatalog.study.defaultPaletteId);
      await tester.pumpAndSettle();
      await _capture(tester, harness.boundary, scenario.name);
      expect(tester.takeException(), isNull);
    });
  }
}

final class _UiHarness {
  const _UiHarness({required this.container, required this.boundary});

  final ProviderContainer container;
  final GlobalKey boundary;
}

Future<_UiHarness> _pumpUi(
  WidgetTester tester, {
  required Size size,
  required String initialLocation,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final fixedNow = DateTime.utc(2026, 10, 25, 4);
  final repository = InMemoryRoomDesignRepository(clock: () => fixedNow);
  addTearDown(repository.close);
  final container = ProviderContainer(
    overrides: [
      roomDesignRepositoryProvider.overrideWith((ref) async => repository),
      roomDesignClockProvider.overrideWithValue(() => fixedNow),
      roomExportClockProvider.overrideWithValue(() => fixedNow),
      illustratedRoomArtworkEncoderProvider.overrideWithValue(
        const _PreviewArtworkEncoder(),
      ),
      roomGalleryWriterProvider.overrideWithValue(
        const _PreviewGalleryWriter(),
      ),
      roomGallerySettingsProvider.overrideWithValue(() async => true),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/room/illustrated',
        builder: (context, state) => const IllustratedRoomGalleryScreen(),
      ),
      GoRoute(
        path: '/room/illustrated/:templateId',
        builder: (context, state) => IllustratedRoomScreen(
          templateId: state.pathParameters['templateId']!,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) =>
            RepaintBoundary(key: boundary, child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _UiHarness(container: container, boundary: boundary);
}

final class _PreviewArtworkEncoder implements IllustratedRoomArtworkEncoder {
  const _PreviewArtworkEncoder();

  @override
  Future<Uint8List> encodePng(IllustratedRoomDraft draft) async =>
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
}

final class _PreviewGalleryWriter implements RoomGalleryWriter {
  const _PreviewGalleryWriter();

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String fileName,
  }) async {}
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String stem, {
  double pixelRatio = 1,
}) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      expect(bytes, isNotNull);
      final output = Directory('build/previews');
      await output.create(recursive: true);
      await File('${output.path}/$stem.png').writeAsBytes(
        bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      expect(
        _capturedNames.add('$stem.png'),
        isTrue,
        reason: 'Each illustrated preview must be captured exactly once',
      );
    } finally {
      image.dispose();
    }
  });
}
