import 'dart:io';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_svg.dart';
import 'package:color_lab/features/room_studio/rendering/illustrated_room_color_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/illustrated_room_svg_contract.dart';

IllustratedRoomDraft _distinctDraft([
  IllustratedRoomTemplate? selectedTemplate,
]) {
  final template = selectedTemplate ?? IllustratedRoomCatalog.study;
  var draft = IllustratedRoomDraft.grayscale(template);
  for (final entry in <IllustratedRoomSurface, String>{
    IllustratedRoomSurface.wall: '#D11111',
    IllustratedRoomSurface.ceiling: '#11D111',
    IllustratedRoomSurface.floor: '#1111D1',
    IllustratedRoomSurface.furniture: '#D1A111',
  }.entries) {
    draft = draft.setSurfaceColor(entry.key, RgbColor.fromHex(entry.value));
  }
  return draft;
}

String _minimalSvg({String additions = ''}) =>
    '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1200 800">
  <g id="surface-wall"><rect width="20" height="20" fill="#FF00A1"/></g>
  <g id="surface-ceiling"><rect width="20" height="20" fill="#00E5FF"/></g>
  <g id="surface-floor"><rect width="20" height="20" fill="#B7FF00"/></g>
  <g id="surface-furniture"><rect width="20" height="20" fill="#7A00FF"/></g>
  $additions
</svg>
''';

String _semanticsLabel(IllustratedRoomDraft draft) {
  if (draft.mode == IllustratedRoomVisualMode.grayscale) {
    return '${draft.template.title}, black and white';
  }
  final colors = IllustratedRoomColorMapper(draft).effectiveColors;
  final labels = draft.template.surfaceLabels;
  return '${draft.template.title}. ${draft.visualStateLabel}. '
      '${labels.wall} ${colors.wall.hex}. '
      '${labels.ceiling} ${colors.ceiling.hex}. '
      '${labels.floor} ${colors.floor.hex}. '
      '${labels.furniture} ${colors.furniture.hex}.';
}

void main() {
  test('shared validator accepts the canonical safe token contract', () {
    validateIllustratedRoomSvg(_minimalSvg(), IllustratedRoomCatalog.study);
  });

  test('Study asset satisfies the shared structural contract', () {
    final source = File('assets/rooms/study_room.svg').readAsStringSync();
    validateIllustratedRoomSvg(source, IllustratedRoomCatalog.study);
  });

  for (final fixture in <(String, String)>[
    (
      'wrong viewBox',
      _minimalSvg().replaceFirst('0 0 1200 800', '0 0 100 100'),
    ),
    (
      'duplicate surface owner',
      _minimalSvg(additions: '<g id="surface-wall"></g>'),
    ),
    (
      'leaked token',
      _minimalSvg(additions: '<path fill="#FF00A1" d="M0 0H1V1Z"/>'),
    ),
    (
      'token in defs',
      _minimalSvg(
        additions: '<defs><path fill="#FF00A1" d="M0 0H1V1Z"/></defs>',
      ),
    ),
    (
      'embedded image',
      _minimalSvg(additions: '<image href="data:image/png;base64,AA=="/>'),
    ),
    ('filter', _minimalSvg(additions: '<filter id="blur"></filter>')),
    ('script', _minimalSvg(additions: '<script>alert(1)</script>')),
    ('animation', _minimalSvg(additions: '<animate attributeName="x"/>')),
    (
      'external href',
      _minimalSvg(additions: '<use href="https://example.com/shape.svg#x"/>'),
    ),
    (
      'remote URL',
      _minimalSvg(additions: '<rect fill="url(https://example.com/a.svg#x)"/>'),
    ),
    ('watermark text', _minimalSvg(additions: '<text>WaterMark</text>')),
  ]) {
    test('shared validator rejects ${fixture.$1}', () {
      expect(
        () => validateIllustratedRoomSvg(
          fixture.$2,
          IllustratedRoomCatalog.study,
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  }

  test('shared validator rejects a surface group with no token geometry', () {
    final source = _minimalSvg().replaceFirst(
      '<rect width="20" height="20" fill="#7A00FF"/>',
      '',
    );
    expect(
      () => validateIllustratedRoomSvg(source, IllustratedRoomCatalog.study),
      throwsA(isA<TestFailure>()),
    );
  });

  test('mapper makes the whole initial scene grayscale', () {
    final grayscale = IllustratedRoomColorMapper(
      IllustratedRoomDraft.grayscale(IllustratedRoomCatalog.study),
    );
    final unchanged = const Color(0xFF2468AC);

    Color substitute(Color color) =>
        grayscale.substitute(null, 'path', 'fill', color);

    expect(substitute(const Color(0xFFFF00A1)), const Color(0xFFC8C8C8));
    expect(substitute(const Color(0xFF00E5FF)), const Color(0xFFF2F2F2));
    expect(substitute(const Color(0xFFB7FF00)), const Color(0xFFA9A9A9));
    expect(substitute(const Color(0xFF7A00FF)), const Color(0xFF737373));
    expect(substitute(unchanged), const Color(0xFF5B5B5B));

    final colored = IllustratedRoomColorMapper(_distinctDraft());
    expect(
      colored.substitute(null, 'path', 'fill', unchanged),
      same(unchanged),
    );
    expect(
      colored.substitute(null, 'path', 'fill', const Color(0xFFFF00A1)),
      const Color(0xFFD11111),
    );
    expect(
      colored.substitute(null, 'path', 'fill', const Color(0xFF00E5FF)),
      const Color(0xFF11D111),
    );
    expect(
      colored.substitute(null, 'path', 'fill', const Color(0xFFB7FF00)),
      const Color(0xFF1111D1),
    );
    expect(
      colored.substitute(null, 'path', 'fill', const Color(0xFF7A00FF)),
      const Color(0xFFD1A111),
    );
  });

  testWidgets('real asset exposes one contextual complete-scene semantic', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpIllustratedRoomRaster(tester, _distinctDraft());

    final finder = find.bySemanticsLabel(
      RegExp(
        r'^Study room.*Wall #D11111.*Ceiling #11D111.*Floor #1111D1.*Desk & furniture #D1A111',
      ),
    );
    expect(finder, findsOneWidget);
    final node = tester.getSemantics(finder);
    expect(
      node,
      matchesSemantics(
        isImage: true,
        label: node.label,
        textDirection: TextDirection.ltr,
      ),
    );
    expect(node.childrenCountInTraversalOrder, 0);
    semantics.dispose();
  });

  testWidgets('missing asset announces an unavailable preview, not colors', (
    tester,
  ) async {
    final template = IllustratedRoomTemplate(
      id: 'missing-room',
      title: 'Missing room',
      summary: 'A missing test fixture.',
      assetPath: 'assets/rooms/missing-room.svg',
      defaultPaletteId: 'fallback',
      surfaceLabels: const IllustratedRoomSurfaceLabels(
        wall: 'Wall',
        ceiling: 'Ceiling',
        floor: 'Floor',
        furniture: 'Furniture',
      ),
      focalPoint: const IllustratedRoomFocalPoint(x: 0, y: 0),
      paletteReviewLabel: 'Test review',
      paletteSourceNote: 'Test display preview and physical swatch note.',
      palettes: [
        IllustratedRoomPalette(
          id: 'fallback',
          name: 'Fallback',
          guidance: 'Test-only missing asset.',
          colors: IllustratedRoomCatalog.study.defaultPalette.colors,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: IllustratedRoomSvg(
          draft: IllustratedRoomDraft.grayscale(template),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Missing room preview unavailable.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'Black & white')), findsNothing);
  });

  testWidgets('Study maps every grayscale surface and furniture anchor', (
    tester,
  ) async {
    await pumpIllustratedRoomRaster(
      tester,
      IllustratedRoomDraft.grayscale(IllustratedRoomCatalog.study),
    );
    final pixels = await illustratedRoomPixels(tester);

    expectIllustratedRoomRgb(pixels, (600, 220), '#C8C8C8');
    expectIllustratedRoomRgb(pixels, (600, 40), '#F2F2F2');
    expectIllustratedRoomRgb(pixels, (1100, 760), '#A9A9A9');
    for (final anchor in [
      (600, 590),
      (600, 538),
      (610, 665),
      (180, 650),
      (380, 670),
    ]) {
      expectIllustratedRoomRgb(pixels, anchor, '#737373');
    }

    final decor = illustratedRoomRgb(pixels, 180, 250);
    expect(decor[0], decor[1]);
    expect(decor[1], decor[2]);
  });

  testWidgets(
    'Study maps distinct surfaces but preserves authored decoration',
    (tester) async {
      await pumpIllustratedRoomRaster(tester, _distinctDraft());
      final pixels = await illustratedRoomPixels(tester);

      expectIllustratedRoomRgb(pixels, (600, 220), '#D11111');
      expectIllustratedRoomRgb(pixels, (600, 40), '#11D111');
      expectIllustratedRoomRgb(pixels, (1100, 760), '#1111D1');
      for (final anchor in [
        (600, 590),
        (600, 538),
        (610, 665),
        (180, 650),
        (380, 670),
      ]) {
        expectIllustratedRoomRgb(pixels, anchor, '#D1A111');
      }
      expectIllustratedRoomRgb(pixels, (180, 250), '#9FD7EA');
    },
  );

  for (final fixture
      in <
        ({IllustratedRoomTemplate template, List<(int, int)> furnitureAnchors})
      >[
        (
          template: IllustratedRoomCatalog.living,
          furnitureAnchors: [(600, 610), (190, 650), (590, 690)],
        ),
        (
          template: IllustratedRoomCatalog.bedroom,
          furnitureAnchors: [(600, 455), (600, 650), (1030, 420)],
        ),
        (
          template: IllustratedRoomCatalog.dining,
          furnitureAnchors: [(600, 610), (350, 620), (1000, 560)],
        ),
        (
          template: IllustratedRoomCatalog.kitchen,
          furnitureAnchors: [(600, 610), (250, 430), (950, 430)],
        ),
        (
          template: IllustratedRoomCatalog.bathroom,
          furnitureAnchors: [(400, 590), (980, 480)],
        ),
      ]) {
    test(
      '${fixture.template.title} satisfies the shared structural contract',
      () {
        final source = File(fixture.template.assetPath).readAsStringSync();
        validateIllustratedRoomSvg(source, fixture.template);
      },
    );

    testWidgets(
      '${fixture.template.title} exposes common and room-specific color anchors',
      (tester) async {
        await pumpIllustratedRoomRaster(
          tester,
          _distinctDraft(fixture.template),
        );
        final pixels = await illustratedRoomPixels(tester);

        expectIllustratedRoomRgb(pixels, (600, 220), '#D11111');
        expectIllustratedRoomRgb(pixels, (600, 40), '#11D111');
        expectIllustratedRoomRgb(pixels, (1100, 760), '#1111D1');
        expectIllustratedRoomRgb(pixels, (600, 590), '#D1A111');
        for (final anchor in fixture.furnitureAnchors) {
          expectIllustratedRoomRgb(pixels, anchor, '#D1A111');
        }
      },
    );
  }

  for (final template in IllustratedRoomCatalog.all) {
    testWidgets(
      '${template.title} satisfies the catalog-wide render contract',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final source = File(template.assetPath).readAsStringSync();
          validateIllustratedRoomSvg(source, template);

          final grayscale = IllustratedRoomDraft.grayscale(template);
          await pumpIllustratedRoomRaster(tester, grayscale);
          var pixels = await illustratedRoomPixels(tester);
          expectIllustratedRoomRgb(pixels, (600, 220), '#C8C8C8');
          expectIllustratedRoomRgb(pixels, (600, 40), '#F2F2F2');
          expectIllustratedRoomRgb(pixels, (1100, 760), '#A9A9A9');
          expectIllustratedRoomRgb(pixels, (600, 590), '#737373');
          expect(
            find.bySemanticsLabel(_semanticsLabel(grayscale)),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          final colored = _distinctDraft(template);
          await pumpIllustratedRoomRaster(tester, colored);
          pixels = await illustratedRoomPixels(tester);
          expectIllustratedRoomRgb(pixels, (600, 220), '#D11111');
          expectIllustratedRoomRgb(pixels, (600, 40), '#11D111');
          expectIllustratedRoomRgb(pixels, (1100, 760), '#1111D1');
          expectIllustratedRoomRgb(pixels, (600, 590), '#D1A111');
          expect(
            find.bySemanticsLabel(_semanticsLabel(colored)),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
