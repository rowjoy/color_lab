import 'dart:io';
import 'dart:typed_data';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/illustrated_room_svg_contract.dart';

typedef _IllustratedRoomPolishFixture = ({
  IllustratedRoomTemplate template,
  IllustratedRoomPolishContract contract,
  (int, int) decorationAnchor,
  String decorationHex,
});

const _sample = (highlight: (600, 525), base: (600, 538), shade: (600, 551));
const _canonicalContract = IllustratedRoomPolishContract(
  requiredGroupIds: ['form', 'fixture-contact-shadows'],
  editableObjectGroupIds: ['object'],
  toneSample: _sample,
  contactShadowAnchor: (1035, 575),
  clearFloorAnchor: (1100, 760),
);

const _canonical =
    '<svg viewBox="0 0 1200 800">'
    '<defs><linearGradient id="light"><stop offset="0" stop-color="#FFFFFF"/></linearGradient>'
    '<clipPath id="clip"><rect width="2" height="2"/></clipPath></defs>'
    '<g id="surface-wall"><path fill="#FF00A1" d="M0 0H1V1Z"/></g>'
    '<g id="surface-ceiling"><path fill="#00E5FF" d="M0 0H1V1Z"/></g>'
    '<g id="surface-floor"><path fill="#B7FF00" d="M0 0H1V1Z"/></g>'
    '<g id="surface-furniture"><g id="object">'
    '<path fill="#7A00FF" d="M0 0H1V1Z"/>'
    '<path fill="#FFFFFF" fill-opacity=".2" d="M0 0H1V1Z"/>'
    '<path fill="#000000" fill-opacity=".2" d="M0 0H1V1Z"/>'
    '</g></g><g id="form"><line x2="1"/></g>'
    '<g id="fixture-contact-shadows"><polygon points="0,0 1,0 1,1"/></g></svg>';

void _validate(String source, [IllustratedRoomPolishContract? contract]) =>
    validatePolishedIllustratedRoomSvg(
      source,
      IllustratedRoomCatalog.study,
      contract ?? _canonicalContract,
    );

Uint8List _pixels(List<List<int>> samples) {
  final pixels = Uint8List(1200 * 800 * 4);
  for (var x = 0; x < samples.length; x++) {
    pixels.setRange(x * 4, x * 4 + 3, samples[x]);
  }
  return pixels;
}

void main() {
  // Missing ownership, neutral form cues or unsafe elements must fail before
  // rendering; literal fixtures exercise the validator without renderer mocks.
  test(
    'polish validator accepts safe form cues and counts actual SVG geometry',
    () {
      _validate(_canonical);
      expect(illustratedRoomSvgMetrics(_canonical), (
        utf8Bytes: 667,
        geometryCount: 9,
        gradientCount: 1,
        clipPathCount: 1,
      ));
      expect(
        illustratedRoomSvgMetrics(
          'é<RECT/><path/><linearGradient/><radialGradient/><clipPath/>',
        ),
        (utf8Bytes: 61, geometryCount: 2, gradientCount: 2, clipPathCount: 1),
      );
    },
  );

  test('translucent stroke remains a cue when the fill is transparent', () {
    _validate(
      _canonical.replaceFirst(
        'fill="#FFFFFF" fill-opacity=".2"',
        'fill="#FFFFFF" fill-opacity="0" stroke="#FFFFFF" stroke-opacity=".2"',
      ),
    );
  });

  test(
    'complexity review targets allow exactly 81920 bytes or 400 geometry',
    () {
      _validate(
        _canonical.replaceFirst('</svg>', '<!--${'x' * 81246}--></svg>'),
      );
      _validate(
        _canonical.replaceFirst(
          '</svg>',
          '${'<rect width="1" height="1"/>' * 391}</svg>',
        ),
      );
    },
  );

  for (final mutation in <String, String>{
    'missing named group': _canonical.replaceFirst('id="form"', 'id="other"'),
    'duplicate named group': _canonical.replaceFirst(
      '</svg>',
      '<g id="form"><path d="M0 0H1"/></g></svg>',
    ),
    'empty named group': _canonical.replaceFirst('<line x2="1"/>', ''),
    'editable object outside furniture': _canonical
        .replaceFirst(
          '<g id="surface-furniture"><g id="object">',
          '<g id="surface-furniture"><path fill="#7A00FF" d="M0 0H1V1Z"/></g><g><g id="object">',
        )
        .replaceFirst(
          '<path fill="#7A00FF" d="M0 0H1V1Z"/><path fill="#FFFFFF"',
          '<path fill="#888888" d="M0 0H1V1Z"/><path fill="#FFFFFF"',
        ),
    'missing editable token base': _canonical
        .replaceFirst('<path fill="#7A00FF" d="M0 0H1V1Z"/>', '')
        .replaceFirst(
          '<g id="surface-furniture">',
          '<g id="surface-furniture"><path fill="#7A00FF" d="M0 0H1V1Z"/>',
        ),
    'missing white cue': _canonical.replaceFirst(
      'fill="#FFFFFF" fill-opacity=".2"',
      'fill="#999999" fill-opacity=".2"',
    ),
    'opaque white cue': _canonical.replaceFirst(
      'fill="#FFFFFF" fill-opacity=".2"',
      'fill="#FFFFFF" fill-opacity="1"',
    ),
    'missing black cue': _canonical.replaceFirst(
      'fill="#000000" fill-opacity=".2"',
      'fill="#999999" fill-opacity=".2"',
    ),
    'contact shadow ellipse': _canonical.replaceFirst(
      '<polygon points="0,0 1,0 1,1"/>',
      '<ellipse rx="1" ry="1"/>',
    ),
    'ellipse alongside fitted contact shadow': _canonical.replaceFirst(
      '<polygon points="0,0 1,0 1,1"/>',
      '<polygon points="0,0 1,0 1,1"/><ellipse rx="1" ry="1"/>',
    ),
  }.entries) {
    test('polish validator rejects ${mutation.key}', () {
      expect(() => _validate(mutation.value), throwsA(isA<TestFailure>()));
    });
  }

  for (final excessive in [
    _canonical.replaceFirst('</svg>', '<!--${'x' * 81920}--></svg>'),
    _canonical.replaceFirst(
      '</svg>',
      '${'<rect width="1" height="1"/>' * 392}</svg>',
    ),
  ]) {
    test(
      'complexity exceedance requires measured evidence justification ${excessive.length}',
      () {
        expect(() => _validate(excessive), throwsA(isA<TestFailure>()));
        expect(
          () => _validate(
            excessive,
            const IllustratedRoomPolishContract(
              requiredGroupIds: ['form', 'fixture-contact-shadows'],
              editableObjectGroupIds: ['object'],
              toneSample: _sample,
              contactShadowAnchor: (1035, 575),
              clearFloorAnchor: (1100, 760),
              complexityJustification:
                  'Measured preview 0.1 s and export 0.2 s; geometry retains readable joinery.',
            ),
          ),
          returnsNormally,
        );
        expect(
          () => _validate(
            excessive,
            const IllustratedRoomPolishContract(
              requiredGroupIds: ['form', 'fixture-contact-shadows'],
              editableObjectGroupIds: ['object'],
              toneSample: _sample,
              contactShadowAnchor: (1035, 575),
              clearFloorAnchor: (1100, 760),
              complexityJustification: '  ',
            ),
          ),
          throwsA(isA<TestFailure>()),
        );
      },
    );
  }

  test(
    'luma uses encoded RGB values and tone assertions reject flat forms',
    () {
      final pixels = _pixels([
        [100, 100, 100],
        [80, 80, 80],
        [60, 60, 60],
        [201, 58, 91],
      ]);
      expect(illustratedRoomLuma(pixels, (3, 0)), closeTo(90.7844, .0001));
      expectIllustratedRoomToneTriple(pixels, (
        highlight: (0, 0),
        base: (1, 0),
        shade: (2, 0),
      ));
      expect(
        () => expectIllustratedRoomToneTriple(pixels, (
          highlight: (1, 0),
          base: (1, 0),
          shade: (2, 0),
        )),
        throwsA(isA<TestFailure>()),
      );
      expectIllustratedRoomContactShadow(
        pixels,
        shadow: (2, 0),
        clearFloor: (0, 0),
      );
      expect(
        () => expectIllustratedRoomContactShadow(
          pixels,
          shadow: (0, 0),
          clearFloor: (2, 0),
        ),
        throwsA(isA<TestFailure>()),
      );
      expectIllustratedRoomHueReadable(pixels, (3, 0));
      expect(
        () => expectIllustratedRoomHueReadable(pixels, (0, 0)),
        throwsA(isA<TestFailure>()),
      );
    },
  );

  test(
    'hue readability compares requested dominant channel with both peers',
    () {
      final pixels = _pixels([
        [10, 100, 40],
        [10, 100, 95],
      ]);
      expectIllustratedRoomHueReadable(pixels, (0, 0), dominantChannel: 1);
      expect(
        () => expectIllustratedRoomHueReadable(pixels, (
          1,
          0,
        ), dominantChannel: 1),
        throwsA(isA<TestFailure>()),
      );
    },
  );

  for (final fixture in <_IllustratedRoomPolishFixture>[
    (
      template: IllustratedRoomCatalog.study,
      contract: const IllustratedRoomPolishContract(
        requiredGroupIds: [
          'study-architecture-depth',
          'study-daylight',
          'study-practical-light',
          'study-contact-shadows',
          'study-material-cues',
        ],
        editableObjectGroupIds: [
          'study-editable-desk',
          'study-editable-office-chair',
          'study-editable-reading-chair',
          'study-editable-shelving',
        ],
        toneSample: _sample,
        contactShadowAnchor: (1035, 575),
        clearFloorAnchor: (1100, 760),
      ),
      decorationAnchor: (180, 250),
      decorationHex: '#9FD7EA',
    ),
    (
      template: IllustratedRoomCatalog.living,
      contract: const IllustratedRoomPolishContract(
        requiredGroupIds: [
          'living-architecture-depth',
          'living-daylight',
          'living-practical-light',
          'living-contact-shadows',
          'living-upholstery-details',
        ],
        editableObjectGroupIds: [
          'living-editable-sofa',
          'living-editable-accent-chair',
          'living-editable-console',
          'living-editable-coffee-table',
        ],
        toneSample: (
          highlight: (600, 570),
          base: (600, 610),
          shade: (600, 685),
        ),
        contactShadowAnchor: (1020, 575),
        clearFloorAnchor: (1100, 760),
      ),
      decorationAnchor: (301, 226),
      decorationHex: '#F4D27B',
    ),
    (
      template: IllustratedRoomCatalog.bedroom,
      contract: const IllustratedRoomPolishContract(
        requiredGroupIds: [
          'bedroom-architecture-depth',
          'bedroom-daylight',
          'bedroom-practical-light',
          'bedroom-contact-shadows',
          'bedroom-textile-details',
          'bedroom-timber-details',
        ],
        editableObjectGroupIds: [
          'bedroom-editable-bed',
          'bedroom-editable-wardrobe',
          'bedroom-editable-side-tables',
        ],
        toneSample: (
          highlight: (600, 630),
          base: (600, 650),
          shade: (600, 710),
        ),
        contactShadowAnchor: (1030, 580),
        clearFloorAnchor: (1100, 760),
      ),
      decorationAnchor: (262, 225),
      decorationHex: '#F3D37D',
    ),
    (
      template: IllustratedRoomCatalog.dining,
      contract: const IllustratedRoomPolishContract(
        requiredGroupIds: [
          'dining-architecture-depth',
          'dining-daylight',
          'dining-pendant-light',
          'dining-contact-shadows',
          'dining-material-cues',
        ],
        editableObjectGroupIds: [
          'dining-editable-table',
          'dining-editable-chairs',
          'dining-editable-sideboard',
        ],
        toneSample: (
          highlight: (600, 540),
          base: (600, 610),
          shade: (600, 632),
        ),
        contactShadowAnchor: (1010, 615),
        clearFloorAnchor: (1100, 760),
      ),
      decorationAnchor: (274, 226),
      decorationHex: '#F3D27A',
    ),
    (
      template: IllustratedRoomCatalog.kitchen,
      contract: const IllustratedRoomPolishContract(
        requiredGroupIds: [
          'kitchen-architecture-depth',
          'kitchen-daylight',
          'kitchen-undercabinet-light',
          'kitchen-contact-shadows',
          'kitchen-counter-details',
        ],
        editableObjectGroupIds: [
          'kitchen-editable-left-cabinetry',
          'kitchen-editable-right-cabinetry',
          'kitchen-editable-island',
        ],
        toneSample: (
          highlight: (600, 560),
          base: (600, 610),
          shade: (600, 695),
        ),
        contactShadowAnchor: (950, 585),
        clearFloorAnchor: (1100, 760),
      ),
      decorationAnchor: (850, 532),
      decorationHex: '#C6CFD0',
    ),
  ]) {
    test(
      '${fixture.template.title} satisfies the polish structure contract',
      () {
        validatePolishedIllustratedRoomSvg(
          File(fixture.template.assetPath).readAsStringSync(),
          fixture.template,
          fixture.contract,
        );
      },
    );

    testWidgets(
      '${fixture.template.title} retains colored form and authored decoration',
      (tester) async {
        var draft = IllustratedRoomDraft.grayscale(fixture.template);
        for (final surface in IllustratedRoomSurface.values) {
          draft = draft.setSurfaceColor(
            surface,
            RgbColor.fromHex(
              surface == IllustratedRoomSurface.furniture
                  ? '#C93A5B'
                  : '#808080',
            ),
          );
        }
        await pumpIllustratedRoomRaster(tester, draft);
        final pixels = await illustratedRoomPixels(tester);
        expectIllustratedRoomToneTriple(pixels, fixture.contract.toneSample);
        expectIllustratedRoomHueReadable(
          pixels,
          fixture.contract.toneSample.highlight,
        );
        expectIllustratedRoomHueReadable(
          pixels,
          fixture.contract.toneSample.shade,
        );
        expectIllustratedRoomContactShadow(
          pixels,
          shadow: fixture.contract.contactShadowAnchor,
          clearFloor: fixture.contract.clearFloorAnchor,
        );
        expectIllustratedRoomRgb(
          pixels,
          fixture.decorationAnchor,
          fixture.decorationHex,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${fixture.template.title} retains grayscale form and decoration',
      (tester) async {
        await pumpIllustratedRoomRaster(
          tester,
          IllustratedRoomDraft.grayscale(fixture.template),
        );
        final pixels = await illustratedRoomPixels(tester);
        expectIllustratedRoomToneTriple(pixels, fixture.contract.toneSample);
        expectIllustratedRoomContactShadow(
          pixels,
          shadow: fixture.contract.contactShadowAnchor,
          clearFloor: fixture.contract.clearFloorAnchor,
        );
        final rgb = illustratedRoomRgb(
          pixels,
          fixture.decorationAnchor.$1,
          fixture.decorationAnchor.$2,
        );
        expect(rgb[0], rgb[1]);
        expect(rgb[1], rgb[2]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
