import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/theme/app_colors.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/mask_overlay_service.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/mask_stroke.dart';
import 'package:color_lab/features/room_studio/domain/room_layer.dart';
import 'package:color_lab/features/room_studio/domain/room_mask_state.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_viewport.dart';
import 'package:color_lab/features/room_studio/presentation/room_mask_magnifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List png(int r, int g, int b) {
  final image = img.Image(width: 16, height: 8, numChannels: 4);
  img.fill(image, color: img.ColorRgba8(r, g, b, 255));
  return Uint8List.fromList(img.encodePng(image));
}

PreparedPhoto photo({int value = 100}) => PreparedPhoto(
  width: 16,
  height: 8,
  rgbaBytes: Uint8List.fromList(
    List.generate(16 * 8 * 4, (i) => i % 4 == 3 ? 255 : value),
  ),
  previewBytes: png(value, value, value),
  palette: const [],
);

MaskBitmap masks() => MaskBitmap(
  width: 16,
  height: 8,
  labels: Uint8List.fromList(List.generate(128, (i) => i % 16 < 8 ? 1 : 3)),
);

class PendingOverlay implements MaskOverlayService {
  final calls = <Completer<Uint8List>>[];
  @override
  Future<Uint8List> render({
    required MaskBitmap masks,
    required RoomLayer layer,
    required RgbColor tint,
    int featherRadius = 2,
  }) {
    final result = Completer<Uint8List>();
    calls.add(result);
    return result.future;
  }
}

class Harness {
  Harness({this.service});
  final MaskOverlayService? service;
  PreparedPhoto image = photo();
  final strokes = <MaskStroke>[];
  final boundary = GlobalKey();
  String id = 'a';
  int revision = 0;
  RoomLayer layer = RoomLayer.wall;
  RoomMaskTool tool = RoomMaskTool.add;
  bool show = true;
  bool enabled = true;
  bool dark = false;
  double width = 320;
  double height = 320;
  double brush = .05;
  ScrollController? scroll;
  RoomMaskViewportController? view;
  Color? tint;

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (service != null)
            maskOverlayServiceProvider.overrideWithValue(service!),
        ],
        child: MaterialApp(
          themeAnimationDuration: Duration.zero,
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            extensions: [
              if (tint != null) AppColors.light.copyWith(primary: tint),
            ],
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) {
                  final content = Align(
                    alignment: Alignment.topLeft,
                    child: RepaintBoundary(
                      key: boundary,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: RoomMaskViewport(
                          viewController: view,
                          photoId: id,
                          maskRevision: revision,
                          photo: image,
                          masks: masks(),
                          layer: layer,
                          tool: tool,
                          brushFraction: brush,
                          showOverlay: show,
                          editingEnabled: enabled,
                          onStroke: strokes.add,
                        ),
                      ),
                    ),
                  );
                  return scroll == null
                      ? content
                      : SingleChildScrollView(
                          controller: scroll,
                          child: SizedBox(height: 1400, child: content),
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> flush(WidgetTester tester, {bool overlay = true}) async {
  bool decoded() {
    final paints = find.descendant(
      of: find.byType(RoomMaskViewport),
      matching: find.byType(CustomPaint),
    );
    if (paints.evaluate().length != 1) return false;
    final dynamic painter = tester.widget<CustomPaint>(paints).painter;
    return painter.photo != null && (!overlay || painter.overlay != null);
  }

  for (var attempt = 0; attempt < 500 && !decoded(); attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(decoded(), isTrue, reason: 'Viewport images did not finish decoding');
  await tester.pump();
}

Future<List<int>> pixel(WidgetTester tester, Harness h, int x, int y) async =>
    (await tester.runAsync(() async {
      final render =
          h.boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await render.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final offset = (y * image.width + x) * 4;
      final result = data!.buffer.asUint8List().sublist(offset, offset + 4);
      image.dispose();
      return result;
    }))!;

void main() {
  testWidgets('manual precision cursor magnifier and smallest brush share one source sample', (tester) async {
    final h = Harness(service: PendingOverlay());
    final view = RoomMaskViewportController(); h.view = view; h.brush = .005;
    addTearDown(view.dispose); await h.mount(tester);
    view.selectRegion(1, 1); view.nudgeCursor(const Offset(1000, 1000)); await tester.pump();
    expect(view.sourceCursor, const Offset(15.5, 7.5));
    final magnifier = tester.widget<RoomMaskMagnifier>(find.byKey(const ValueKey('room-mask-magnifier')));
    expect(magnifier.sample.source, view.sourceCursor);
    expect(magnifier.sample.screenRadius, view.transform!.brushRadius(.005));
    view.paintCursor(MaskEditMode.add); await tester.pump();
    expect(h.strokes, hasLength(1)); expect(h.strokes.single.diameterFraction, .005);
    expect(h.strokes.single.segments.single.single.x, 15.5 / 16);
    expect(h.strokes.single.segments.single.single.y, 7.5 / 8);
  });

  testWidgets('manual precision two pointers cancellation and reorientation commit no partial stroke', (tester) async {
    final h = Harness(service: PendingOverlay()); final view = RoomMaskViewportController(); h.view = view;
    addTearDown(view.dispose); await h.mount(tester);
    final center = tester.getCenter(find.byType(RoomMaskViewport));
    final one = await tester.startGesture(center, pointer: 11);
    final two = await tester.startGesture(center + const Offset(20, 0), pointer: 12);
    await two.moveBy(const Offset(30, 0)); await two.up(); await one.cancel(); await tester.pump();
    expect(h.strokes, isEmpty); expect(view.zoom, greaterThan(1));
    view.reset(); await tester.pump();
    final painting = await tester.startGesture(center, pointer: 13);
    await painting.moveBy(const Offset(10, 0)); h.width = 280; h.height = 200; await h.mount(tester);
    await painting.up(); await tester.pump(); expect(h.strokes, isEmpty);
  });

  testWidgets(
    'raster completion waits for output slower than eighty milliseconds',
    (tester) async {
      final service = PendingOverlay();
      final h = Harness(service: service);
      await h.mount(tester);
      Timer? completion;
      addTearDown(() => completion?.cancel());
      final elapsed = Stopwatch()..start();
      await tester.runAsync(() async {
        completion = Timer(const Duration(milliseconds: 250), () {
          service.calls.single.complete(png(255, 0, 0));
        });
      });
      await flush(tester);
      expect((await pixel(tester, h, 80, 160))[0], greaterThan(100));
      expect(elapsed.elapsedMilliseconds, greaterThanOrEqualTo(250));
    },
  );

  testWidgets(
    'real overlay and unchanged photo share letterbox and resized rect',
    (tester) async {
      final h = Harness();
      final before = h.image.previewBytes.toList();
      await h.mount(tester);
      await flush(tester);
      final selected = await pixel(tester, h, 80, 160);
      expect(selected[2], greaterThan(selected[1]));
      expect(await pixel(tester, h, 280, 160), [100, 100, 100, 255]);
      expect(await pixel(tester, h, 80, 20), isNot([100, 100, 100, 255]));
      h.width = 240;
      h.height = 120;
      await h.mount(tester);
      expect(await pixel(tester, h, 60, 60), selected);
      expect(await pixel(tester, h, 210, 60), [100, 100, 100, 255]);
      h.layer = RoomLayer.floor;
      await h.mount(tester);
      await flush(tester);
      expect(await pixel(tester, h, 60, 60), [100, 100, 100, 255]);
      final floor = await pixel(tester, h, 195, 60);
      expect(floor[2], greaterThan(floor[1]));
      h.show = false;
      await h.mount(tester);
      expect(await pixel(tester, h, 60, 60), [100, 100, 100, 255]);
      expect(h.image.previewBytes, before);
    },
  );

  testWidgets('overlay boundary is antialiased without shifting its edge', (
    tester,
  ) async {
    final h = Harness();
    await h.mount(tester);
    await flush(tester);

    final interior = await pixel(tester, h, 150, 160);
    final edge = await pixel(tester, h, 159, 160);
    final exterior = await pixel(tester, h, 170, 160);
    expect(interior[2], greaterThan(interior[0]));
    expect(edge[2], greaterThan(edge[0]));
    expect(edge[2] - edge[0], lessThan(interior[2] - interior[0]));
    expect(exterior, [100, 100, 100, 255]);
  });

  testWidgets(
    'stroke buffers, previews aligned vectors, commits once with gaps',
    (tester) async {
      final h = Harness(service: PendingOverlay());
      await h.mount(tester);
      await flush(tester, overlay: false);
      final gesture = await tester.startGesture(const Offset(80, 160));
      await tester.pump();
      expect(h.strokes, isEmpty);
      expect(await pixel(tester, h, 80, 160), isNot([100, 100, 100, 255]));
      await gesture.moveTo(const Offset(120, 160));
      await gesture.moveTo(const Offset(120, 40));
      await gesture.moveTo(const Offset(240, 160));
      await gesture.up();
      await tester.pump();
      expect(h.strokes, hasLength(1));
      final stroke = h.strokes.single;
      expect(stroke.layer, RoomLayer.wall);
      expect(stroke.mode, MaskEditMode.add);
      expect(stroke.segments, hasLength(2));
      expect(stroke.segments.first.first.x, .25);
      expect(stroke.segments.first.first.y, .5);
      expect(stroke.segments.last.first.x, .75);
      expect(await pixel(tester, h, 80, 160), [100, 100, 100, 255]);
    },
  );

  testWidgets('second pointer and pointer cancel discard the whole preview', (
    tester,
  ) async {
    final h = Harness(service: PendingOverlay());
    await h.mount(tester);
    final first = await tester.startGesture(const Offset(80, 160), pointer: 1);
    final second = await tester.startGesture(
      const Offset(240, 160),
      pointer: 2,
    );
    await second.up();
    await first.moveTo(const Offset(100, 160));
    await first.up();
    final cancelled = await tester.startGesture(const Offset(80, 160));
    await cancelled.cancel();
    expect(h.strokes, isEmpty);
    final accepted = await tester.startGesture(const Offset(80, 160));
    await accepted.up();
    expect(h.strokes, hasLength(1));
  });

  for (final tool in [RoomMaskTool.add, RoomMaskTool.erase]) {
    testWidgets('pinch in ${tool.name} zooms without committing a stroke', (
      tester,
    ) async {
      final h = Harness(service: PendingOverlay())..tool = tool;
      await h.mount(tester);
      final first = await tester.startGesture(
        const Offset(120, 160),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(200, 160),
        pointer: 2,
      );
      await first.moveTo(const Offset(80, 160));
      await second.moveTo(const Offset(240, 160));
      await second.up();
      await first.moveTo(const Offset(100, 160));
      await first.up();
      expect(h.strokes, isEmpty);
      await tester.tapAt(const Offset(80, 160));
      expect(h.strokes, hasLength(1));
      expect(
        h.strokes.single.mode,
        tool == RoomMaskTool.add ? MaskEditMode.add : MaskEditMode.erase,
      );
      expect(h.strokes.single.segments.single.first.x, closeTo(.375, .001));
      expect(h.strokes.single.segments.single.first.y, .5);
    });
  }

  for (final change in [
    'tool',
    'layer',
    'photo',
    'revision',
    'disable',
    'hide',
    'brush',
  ]) {
    testWidgets('$change cancels an in-progress brush', (tester) async {
      final h = Harness(service: PendingOverlay());
      await h.mount(tester);
      final gesture = await tester.startGesture(const Offset(80, 160));
      switch (change) {
        case 'tool':
          h.tool = RoomMaskTool.erase;
        case 'layer':
          h.layer = RoomLayer.floor;
        case 'photo':
          h.id = 'b';
        case 'revision':
          h.revision++;
        case 'disable':
          h.enabled = false;
        case 'hide':
          h.show = false;
        case 'brush':
          h.brush = .1;
      }
      await h.mount(tester);
      await gesture.moveTo(const Offset(240, 160));
      await gesture.up();
      expect(h.strokes, isEmpty);
    });
  }

  testWidgets(
    'viewport claims brush and Move drags inside a scrolling editor',
    (tester) async {
      final controller = ScrollController();
      final h = Harness(service: PendingOverlay())..scroll = controller;
      await h.mount(tester);
      await tester.dragFrom(const Offset(80, 200), const Offset(0, -80));
      expect(controller.offset, 0);
      expect(h.strokes, hasLength(1));
      h.tool = RoomMaskTool.move;
      await h.mount(tester);
      await tester.dragFrom(const Offset(80, 200), const Offset(0, -80));
      expect(controller.offset, 0);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets(
    'Move zoom clamps at eight and one without encoding during pinch',
    (tester) async {
      final service = PendingOverlay();
      final h = Harness(service: service)..tool = RoomMaskTool.move;
      await h.mount(tester);
      final a = await tester.startGesture(const Offset(150, 160), pointer: 1);
      final b = await tester.startGesture(const Offset(170, 160), pointer: 2);
      await a.moveTo(const Offset(0, 160));
      await b.moveTo(const Offset(320, 160));
      await a.up();
      await b.up();
      h.tool = RoomMaskTool.add;
      await h.mount(tester);
      await tester.tapAt(const Offset(80, 160));
      expect(h.strokes.single.segments.single.first.x, .46875);
      h.tool = RoomMaskTool.move;
      await h.mount(tester);
      final c = await tester.startGesture(const Offset(20, 160), pointer: 3);
      final d = await tester.startGesture(const Offset(300, 160), pointer: 4);
      await c.moveTo(const Offset(159, 160));
      await d.moveTo(const Offset(161, 160));
      await c.up();
      await d.up();
      h.tool = RoomMaskTool.add;
      await h.mount(tester);
      await tester.tapAt(const Offset(80, 160));
      expect(h.strokes.last.segments.single.first.x, .25);
      expect(service.calls, hasLength(1));
    },
  );

  testWidgets(
    'photo replacement clears old photo and in-flight decoded overlay',
    (tester) async {
      final service = PendingOverlay();
      final h = Harness(service: service);
      await h.mount(tester);
      await flush(tester, overlay: false);
      service.calls[0].complete(png(255, 0, 0));
      // Let the old request begin decoding before replacing its photo.
      await tester.pump();
      h.id = 'replacement';
      h.image = photo(value: 50);
      await h.mount(tester);
      await flush(tester, overlay: false);
      expect(await pixel(tester, h, 80, 160), [50, 50, 50, 255]);
      h.layer = RoomLayer.floor;
      await h.mount(tester);
      service.calls[1].complete(png(255, 0, 0));
      service.calls[2].complete(png(0, 0, 255));
      await flush(tester);
      final current = await pixel(tester, h, 80, 160);
      expect(current[2], greaterThan(current[0]));
      expect(service.calls, hasLength(3));
    },
  );

  testWidgets(
    'Move zoom and pan map hits; clipped excursions disconnect strokes',
    (tester) async {
      final service = PendingOverlay();
      final h = Harness(service: service)..tool = RoomMaskTool.move;
      await h.mount(tester);
      final a = await tester.startGesture(const Offset(120, 160), pointer: 1);
      final b = await tester.startGesture(const Offset(200, 160), pointer: 2);
      await a.moveTo(const Offset(80, 160));
      await b.moveTo(const Offset(240, 160));
      await a.up();
      await b.up();
      h.tool = RoomMaskTool.add;
      h.revision++;
      h.dark = true;
      await h.mount(tester);
      final brush = await tester.startGesture(const Offset(80, 160));
      await brush.moveTo(const Offset(-40, 160));
      await brush.moveTo(const Offset(240, 160));
      await brush.up();
      expect(h.strokes.single.segments, hasLength(2));
      expect(h.strokes.single.segments.first.first.x, .375);
      expect(h.strokes.single.segments.last.first.x, .625);
      final count = service.calls.length;
      h.tool = RoomMaskTool.move;
      await h.mount(tester);
      await tester.dragFrom(const Offset(160, 160), const Offset(40, 0));
      await h.mount(tester);
      expect(service.calls, hasLength(count));
      h.tool = RoomMaskTool.erase;
      await h.mount(tester);
      await tester.tapAt(const Offset(80, 160));
      expect(h.strokes.last.mode, MaskEditMode.erase);
      expect(h.strokes.last.segments.first.first.x, closeTo(.3125, .001));
      h.id = 'new';
      await h.mount(tester);
      await tester.tapAt(const Offset(80, 160));
      expect(h.strokes.last.segments.first.first.x, .25);
    },
  );

  testWidgets(
    'key changes immediately clear stale output and ignore late PNGs',
    (tester) async {
      final service = PendingOverlay();
      final h = Harness(service: service);
      await h.mount(tester);
      service.calls[0].complete(png(255, 0, 0));
      await flush(tester);
      expect((await pixel(tester, h, 80, 160))[0], greaterThan(100));
      h.revision++;
      await h.mount(tester);
      expect(await pixel(tester, h, 80, 160), [100, 100, 100, 255]);
      h.id = 'b';
      await h.mount(tester);
      service.calls[2].complete(png(0, 255, 0));
      await flush(tester);
      service.calls[1].complete(png(255, 0, 0));
      await flush(tester);
      final current = await pixel(tester, h, 80, 160);
      expect(current[1], greaterThan(current[0]));
      await h.mount(tester);
      h.width = 300;
      await h.mount(tester);
      expect(service.calls, hasLength(3));
      h.revision++;
      await h.mount(tester);
      await tester.pumpWidget(const SizedBox());
      service.calls.last.complete(png(255, 0, 0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tint invalidates cache and original toggles reuse the same decoded PNG',
    (tester) async {
      final service = PendingOverlay();
      final h = Harness(service: service);
      await h.mount(tester);
      service.calls[0].complete(png(255, 0, 0));
      await flush(tester);
      h.show = false;
      await h.mount(tester);
      expect(await pixel(tester, h, 80, 160), [100, 100, 100, 255]);
      h.show = true;
      await h.mount(tester);
      expect((await pixel(tester, h, 80, 160))[0], greaterThan(100));
      expect(service.calls, hasLength(1));
      h.tint = Colors.green;
      await h.mount(tester);
      expect(service.calls, hasLength(2));
      expect(await pixel(tester, h, 80, 160), [100, 100, 100, 255]);
      service.calls.last.complete(png(0, 255, 0));
      await flush(tester);
      expect((await pixel(tester, h, 80, 160))[1], greaterThan(100));
    },
  );

  testWidgets(
    'original-only and disabled are nonpainting; narrow semantics describe mask',
    (tester) async {
      final h = Harness(service: PendingOverlay())..width = 360;
      final semantics = tester.ensureSemantics();
      for (final dark in [false, true]) {
        h.dark = dark;
        await h.mount(tester);
        expect(
          find.bySemanticsLabel(
            RegExp('.*mask preview.*', caseSensitive: false),
          ),
          findsOneWidget,
        );
        expect(
          tester.getSemantics(find.byType(RoomMaskViewport)),
          matchesSemantics(
            isImage: true,
            label: 'Room photo, Wall mask preview',
          ),
        );
        h.show = false;
        await h.mount(tester);
        await tester.tapAt(const Offset(80, 160));
        h.show = true;
        h.enabled = false;
        await h.mount(tester);
        await tester.tapAt(const Offset(80, 160));
        expect(h.strokes, isEmpty);
        expect(tester.takeException(), isNull);
        h.enabled = true;
      }
      semantics.dispose();
    },
  );
}
