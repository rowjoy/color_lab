import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:color_lab/core/vector_regions/application/vector_region_hit_tester.dart';
import 'package:color_lab/core/vector_regions/application/vector_region_transform.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_region_artwork.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:color_lab/core/vector_regions/data/vector_region_json_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;
import '../../../support/legacy_illustrated_room_color_mapper.dart';

// Mutation: Study keeps token/duplicate geometry or thumbnail/export/hit/semantics diverge.
void main() {
  // Mutation: memoizing a rejected asset/decode/envelope future prevents Retry
  // from attempting the asset load again. Exercise the real Flutter asset seam.
  testWidgets('Study retries a failed asset load on the next request', (
    tester,
  ) async {
    const regionsKey = 'assets/rooms/regions/study_room.v1.json';
    rootBundle.evict(regionsKey);
    rootBundle.evict('assets/rooms/study_room.svg');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var regionReads = 0;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (key == regionsKey && ++regionReads == 1) return null;
      return ByteData.sublistView(await File(key).readAsBytes());
    });
    addTearDown(() => messenger.setMockMessageHandler('flutter/assets', null));
    await tester.runAsync(() async {
      await expectLater(
        StudyRoomRegionArtwork.load(),
        throwsA(isA<FlutterError>()),
      );
      final recovered = await StudyRoomRegionArtwork.load();
      expect(recovered.definition.id, 'study');
      expect(regionReads, 2);
    });
  });

  // Mutation: reintroducing any JSON-owned fill boundary in SVG, even with
  // H/V versus L spelling or a neutral overlay, violates single-source geometry.
  test('Study decoration has no normalized JSON part boundaries', () {
    final definition = VectorRegionJsonCodec().decode(
      File('assets/rooms/regions/study_room.v1.json').readAsStringSync(),
    );
    final parts = {
      for (final region in definition.regions)
        for (final part in region.geometry.parts)
          _normalizeBoundary(part.commands): '${region.id} slot ${part.slot}',
    };
    final source = File('assets/rooms/study_room.svg').readAsStringSync();
    final duplicates = <String>[];
    for (final element in RegExp(r'<path\b[^>]*>').allMatches(source)) {
      final d = RegExp(r'\bd="([^"]+)"').firstMatch(element.group(0)!);
      if (d == null) continue;
      final owner = parts[_normalizeBoundary(_decorationCommands(d.group(1)!))];
      if (owner != null) duplicates.add(owner);
    }
    expect(
      duplicates,
      isEmpty,
      reason: 'SVG repeats normalized JSON-owned boundaries',
    );
  });

  testWidgets(
    'Study JSON owns eight regions and cached geometry across all consumers',
    (tester) async {
      final art = await tester.runAsync(StudyRoomRegionArtwork.load);
      expect(art!.definition.intrinsicSize, const Size(1200, 800));
      expect(art.definition.regions.map((r) => r.id).toSet(), {
        'wall-back',
        'wall-side',
        'wall-accent',
        'ceiling',
        'floor',
        'desk',
        'chair',
        'shelves',
      });
      expect(art.definition.regions.map((r) => r.groupId).toSet(), {
        'walls',
        'ceiling',
        'floor',
        'furniture',
      });
      final svg = File('assets/rooms/study_room.svg').readAsStringSync();
      for (final token in ['#FF00A1', '#00E5FF', '#B7FF00', '#7A00FF']) {
        expect(svg.toUpperCase(), isNot(contains(token)));
      }
      for (final region in art.definition.regions) {
        expect(svg, isNot(contains('id="${region.id}"')));
      }
      expect(await tester.runAsync(StudyRoomRegionArtwork.load), same(art));
      final draft = IllustratedRoomDraft.grayscale(
        IllustratedRoomCatalog.study,
      ).applyPalette('quiet-sage');
      final semantics = tester.ensureSemantics();

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = Directory('/tmp/tintatlas-task2-inspection')
        ..createSync(recursive: true);
      for (final size in [const Size(360, 300), const Size(1024, 768)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: const ValueKey('inspection'),
              child: IllustratedRoomSvg(draft: draft),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final artwork = tester.widget<IllustratedRoomRegionArtwork>(
          find.byType(IllustratedRoomRegionArtwork),
        );
        expect(artwork.artwork, same(art));
        final transform = VectorRegionTransform.fit(
          intrinsicSize: art.definition.intrinsicSize,
          viewport: size,
        );
        expect(
          hitTestVectorRegion(
            art.definition,
            transform.artworkToScreen(const Offset(600, 590)),
            transform,
          )?.id,
          'chair',
        );
        final bounds = artwork.regionBounds(size);
        expect(
          bounds['desk'],
          transform.screenBounds(
            art.definition.regions
                .singleWhere((r) => r.id == 'desk')
                .geometry
                .bounds,
          ),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('inspection')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          File(
            '${directory.path}/study-${size.width.toInt()}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
        });
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      final png = await tester.runAsync(
        () => SvgIllustratedRoomArtworkEncoder().encodePng(draft),
      );
      File('${directory.path}/study-export-2400.png').writeAsBytesSync(png!);
      final exported = img.decodePng(png)!;
      final baseline = await tester.runAsync(() async {
        final info = await vg.vg.loadPicture(
          SvgStringLoader(
            File(
              'test/fixtures/study_room_pre_region_pilot.svg',
            ).readAsStringSync(),
            colorMapper: LegacyIllustratedRoomColorMapper(draft),
          ),
          null,
        );
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder)
          ..scale(2)
          ..drawPicture(info.picture);
        final picture = recorder.endRecording();
        final image = await picture.toImage(2400, 1600);
        try {
          return img.decodePng(
            (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!.buffer.asUint8List(),
          )!;
        } finally {
          image.dispose();
          picture.dispose();
          info.picture.dispose();
        }
      });
      File(
        '${directory.path}/study-baseline-2400.png',
      ).writeAsBytesSync(img.encodePng(baseline!));
      var changed = 0;
      final examples = <Object>[];
      for (var y = 0; y < 1600; y++) {
        for (var x = 0; x < 2400; x++) {
          final a = exported.getPixel(x, y);
          final b = baseline.getPixel(x, y);
          if ((a.r - b.r).abs() > 1 ||
              (a.g - b.g).abs() > 1 ||
              (a.b - b.b).abs() > 1 ||
              (a.a - b.a).abs() > 1) {
            changed++;
            if (examples.length < 20) {
              examples.add((x, y, a.toString(), b.toString()));
            }
          }
        }
      }
      expect(
        changed,
        0,
        reason:
            'Migration must retain the frozen authored Study raster: $examples',
      );
      expect((exported.width, exported.height), (2400, 1600));
      final point = exported.getPixel(1200, 440);
      final expected = draft.colors!.wall;
      expect(
        [point.r, point.g, point.b],
        [expected.red, expected.green, expected.blue],
      );
      semantics.dispose();
    },
  );
}

// Test-only normalization of this bundled asset's absolute path vocabulary.
// Runtime code still accepts only restricted JSON; no SVG parser was added there.
List<List<Object>> _decorationCommands(String source) {
  final tokens = RegExp(
    r'[A-Za-z]|[-+]?(?:\d*\.)?\d+(?:[eE][-+]?\d+)?',
  ).allMatches(source).map((match) => match.group(0)!).toList();
  final commands = <List<Object>>[];
  var index = 0;
  while (index < tokens.length) {
    final op = tokens[index++];
    final count = const {
      'M': 2,
      'L': 2,
      'H': 1,
      'V': 1,
      'Q': 4,
      'C': 6,
      'S': 4,
      'Z': 0,
    }[op];
    if (count == null) {
      throw FormatException('Unexpected decoration command $op');
    }
    commands.add([
      op,
      for (var n = 0; n < count; n++) double.parse(tokens[index++]),
    ]);
  }
  return commands;
}

String _normalizeBoundary(List<List<Object>> commands) {
  final normalized = <List<Object>>[];
  var point = Offset.zero;
  var start = Offset.zero;
  Offset? previousControl;
  for (final command in commands) {
    double n(int index) => (command[index] as num).toDouble();
    final op = command.first;
    switch (op) {
      case 'M':
        point = start = Offset(n(1), n(2));
        normalized.add(['M', point.dx, point.dy]);
      case 'H':
        point = Offset(n(1), point.dy);
        normalized.add(['L', point.dx, point.dy]);
      case 'V':
        point = Offset(point.dx, n(1));
        normalized.add(['L', point.dx, point.dy]);
      case 'L':
        point = Offset(n(1), n(2));
        normalized.add(['L', point.dx, point.dy]);
      case 'Q':
        final control = Offset(n(1), n(2));
        final end = Offset(n(3), n(4));
        final first = point + (control - point) * (2 / 3);
        final second = end + (control - end) * (2 / 3);
        normalized.add([
          'C',
          first.dx,
          first.dy,
          second.dx,
          second.dy,
          end.dx,
          end.dy,
        ]);
        point = end;
      case 'C':
        normalized.add(command);
        previousControl = Offset(n(3), n(4));
        point = Offset(n(5), n(6));
      case 'S':
        final first = point * 2 - (previousControl ?? point);
        normalized.add(['C', first.dx, first.dy, n(1), n(2), n(3), n(4)]);
        previousControl = Offset(n(1), n(2));
        point = Offset(n(3), n(4));
      case 'Z':
        normalized.add(['Z']);
        point = start;
      default:
        throw FormatException('Unexpected boundary command $op');
    }
    if (op != 'C' && op != 'S') previousControl = null;
  }
  return normalized
      .map(
        (command) => command
            .map(
              (value) => value is num
                  ? Float32List.fromList([
                      value.toDouble(),
                    ]).single.toStringAsFixed(4)
                  : value,
            )
            .join(','),
      )
      .join(';');
}
