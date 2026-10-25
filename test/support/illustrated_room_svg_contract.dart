import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const illustratedRoomRasterKey = ValueKey('illustrated-room-raster');
const illustratedRoomRasterSize = Size(1200, 800);

const illustratedRoomSurfaceTokens = <String, String>{
  '#FF00A1': 'surface-wall',
  '#00E5FF': 'surface-ceiling',
  '#B7FF00': 'surface-floor',
  '#7A00FF': 'surface-furniture',
};

typedef IllustratedRoomSvgMetrics = ({
  int utf8Bytes,
  int geometryCount,
  int gradientCount,
  int clipPathCount,
});

typedef IllustratedRoomToneSample = ({
  (int, int) highlight,
  (int, int) base,
  (int, int) shade,
});

final class IllustratedRoomPolishContract {
  const IllustratedRoomPolishContract({
    required this.requiredGroupIds,
    required this.editableObjectGroupIds,
    required this.toneSample,
    required this.contactShadowAnchor,
    required this.clearFloorAnchor,
    this.complexityJustification,
  });

  final List<String> requiredGroupIds;
  final List<String> editableObjectGroupIds;
  final IllustratedRoomToneSample toneSample;
  final (int, int) contactShadowAnchor;
  final (int, int) clearFloorAnchor;
  final String? complexityJustification;
}

const _simpleGeometry = <String>{
  'path',
  'rect',
  'circle',
  'ellipse',
  'polygon',
  'polyline',
  'line',
};

String _withoutXmlComments(String source) =>
    source.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

IllustratedRoomSvgMetrics illustratedRoomSvgMetrics(String source) {
  final elements = RegExp(r'<\s*([A-Za-z][\w:.-]*)\b')
      .allMatches(_withoutXmlComments(source))
      .map((match) => match.group(1)!.split(':').last.toLowerCase());
  return (
    utf8Bytes: utf8.encode(source).length,
    geometryCount: elements.where(_simpleGeometry.contains).length,
    gradientCount: elements
        .where((name) => name == 'lineargradient' || name == 'radialgradient')
        .length,
    clipPathCount: elements.where((name) => name == 'clippath').length,
  );
}

void validatePolishedIllustratedRoomSvg(
  String source,
  IllustratedRoomTemplate template,
  IllustratedRoomPolishContract contract,
) {
  validateIllustratedRoomSvg(source, template);
  final metrics = illustratedRoomSvgMetrics(source);
  if (metrics.utf8Bytes > 81920 || metrics.geometryCount > 400) {
    expect(
      contract.complexityJustification?.trim(),
      isNot(isIn([null, ''])),
      reason: '${template.id}: complexity exceedance needs measured evidence',
    );
  }

  final groups = <String, _PolishGroup>{
    for (final id in {
      ...contract.requiredGroupIds,
      ...contract.editableObjectGroupIds,
    })
      id: _PolishGroup(),
  };
  final frames = <({String? id, double opacity})>[];
  for (final tag in RegExp(
    r'<\s*(/?)\s*([A-Za-z][\w:.-]*)([^<>]*?)(/?)\s*>',
  ).allMatches(_withoutXmlComments(source))) {
    if (tag.group(1) == '/') {
      frames.removeLast();
      continue;
    }
    final element = tag.group(2)!.split(':').last.toLowerCase();
    final attributes = tag.group(3)!;
    final id = _attribute(attributes, 'id');
    final opacity =
        (frames.isEmpty ? 1.0 : frames.last.opacity) *
        (double.tryParse(_attribute(attributes, 'opacity') ?? '1') ?? 1);
    final group = groups[id];
    if (group != null) {
      expect(element, 'g', reason: '${template.id}: $id must be a group');
      group.count++;
      if (contract.editableObjectGroupIds.contains(id)) {
        expect(
          frames.any((frame) => frame.id == 'surface-furniture'),
          isTrue,
          reason: '${template.id}: $id must be below surface-furniture',
        );
      }
    }
    if (_simpleGeometry.contains(element)) {
      for (final frame in frames) {
        final owner = groups[frame.id];
        if (owner == null) continue;
        owner.geometry++;
        owner.hasFittedShadow |= element == 'path' || element == 'polygon';
        owner.hasEllipse |= element == 'ellipse';
        for (final paint in ['fill', 'stroke']) {
          final color = _attribute(attributes, paint)?.toUpperCase();
          owner.hasBase |= color == '#7A00FF';
          final alpha =
              opacity *
              (double.tryParse(
                    _attribute(attributes, '$paint-opacity') ?? '1',
                  ) ??
                  1);
          if (alpha > 0 && alpha < 1) {
            owner.hasWhite |=
                color == '#FFFFFF' || color == '#FFF' || color == 'WHITE';
            owner.hasBlack |=
                color == '#000000' || color == '#000' || color == 'BLACK';
          }
        }
      }
    }
    if (tag.group(4) != '/') frames.add((id: id, opacity: opacity));
  }
  for (final entry in groups.entries) {
    final group = entry.value;
    expect(
      group.count,
      1,
      reason: '${template.id}: exactly one ${entry.key} required',
    );
    expect(
      group.geometry,
      greaterThan(0),
      reason: '${template.id}: ${entry.key} must contain geometry',
    );
    if (contract.editableObjectGroupIds.contains(entry.key)) {
      expect(
        group.hasBase && group.hasWhite && group.hasBlack,
        isTrue,
        reason:
            '${template.id}: ${entry.key} needs token base, translucent white and black geometry',
      );
    }
    if (entry.key.endsWith('-contact-shadows')) {
      expect(
        group.hasFittedShadow && !group.hasEllipse,
        isTrue,
        reason:
            '${template.id}: ${entry.key} needs fitted path/polygon shadows, no ellipses',
      );
    }
  }
}

final class _PolishGroup {
  int count = 0;
  int geometry = 0;
  bool hasBase = false;
  bool hasWhite = false;
  bool hasBlack = false;
  bool hasFittedShadow = false;
  bool hasEllipse = false;
}

double illustratedRoomLuma(Uint8List pixels, (int, int) anchor) {
  final rgb = illustratedRoomRgb(pixels, anchor.$1, anchor.$2);
  return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
}

void expectIllustratedRoomToneTriple(
  Uint8List pixels,
  IllustratedRoomToneSample sample, {
  double minDelta = 8,
}) {
  final base = illustratedRoomLuma(pixels, sample.base);
  expect(
    illustratedRoomLuma(pixels, sample.highlight) - base,
    greaterThanOrEqualTo(minDelta),
    reason: '${sample.highlight} highlight above ${sample.base} base',
  );
  expect(
    base - illustratedRoomLuma(pixels, sample.shade),
    greaterThanOrEqualTo(minDelta),
    reason: '${sample.shade} shade below ${sample.base} base',
  );
}

void expectIllustratedRoomContactShadow(
  Uint8List pixels, {
  required (int, int) shadow,
  required (int, int) clearFloor,
  double minDelta = 6,
}) {
  expect(
    illustratedRoomLuma(pixels, clearFloor) -
        illustratedRoomLuma(pixels, shadow),
    greaterThanOrEqualTo(minDelta),
    reason: '$shadow contact shadow below $clearFloor clear floor',
  );
}

void expectIllustratedRoomHueReadable(
  Uint8List pixels,
  (int, int) anchor, {
  int dominantChannel = 0,
  int minChannelMargin = 20,
}) {
  final rgb = illustratedRoomRgb(pixels, anchor.$1, anchor.$2);
  for (var channel = 0; channel < 3; channel++) {
    if (channel == dominantChannel) continue;
    expect(
      rgb[dominantChannel] - rgb[channel],
      greaterThanOrEqualTo(minChannelMargin),
      reason:
          '$anchor channel $dominantChannel remains readable against $channel',
    );
  }
}

void validateIllustratedRoomSvg(
  String source,
  IllustratedRoomTemplate template,
) {
  expect(source.toLowerCase(), isNot(contains('watermark')));
  final content = _withoutXmlComments(source);

  final svg = RegExp(
    r'<svg\b([^>]*)>',
    caseSensitive: false,
  ).firstMatch(content);
  expect(svg, isNotNull, reason: '${template.id}: missing <svg> root');
  final viewBox = _attribute(svg!.group(1)!, 'viewBox');
  expect(
    viewBox?.trim().split(RegExp(r'[\s,]+')),
    ['0', '0', '1200', '800'],
    reason: '${template.id}: canonical viewBox',
  );

  const allowedElements = <String>{
    'svg',
    'defs',
    'g',
    'path',
    'rect',
    'circle',
    'ellipse',
    'polygon',
    'polyline',
    'line',
    'lineargradient',
    'radialgradient',
    'stop',
    'clippath',
  };
  final groupCounts = <String, int>{
    for (final id in illustratedRoomSurfaceTokens.values) id: 0,
  };
  final tokenGeometryCounts = <String, int>{
    for (final token in illustratedRoomSurfaceTokens.keys) token: 0,
  };
  final frames = <_SvgFrame>[];
  final tags = RegExp(r'<\s*(/?)\s*([A-Za-z][\w:.-]*)([^<>]*?)(/?)\s*>');
  final geometryElements = <String>{
    'path',
    'rect',
    'circle',
    'ellipse',
    'polygon',
    'polyline',
    'line',
  };

  for (final match in tags.allMatches(content)) {
    final closing = match.group(1) == '/';
    if (closing) {
      expect(frames, isNotEmpty, reason: '${template.id}: unbalanced SVG');
      frames.removeLast();
      continue;
    }

    final qualifiedName = match.group(2)!.toLowerCase();
    final element = qualifiedName.split(':').last;
    final attributes = match.group(3)!;
    expect(
      allowedElements,
      contains(element),
      reason: '${template.id}: <$element> is forbidden',
    );

    for (final href in _attributeValues(attributes, 'href')) {
      expect(
        href.trim().startsWith('#'),
        isTrue,
        reason: '${template.id}: external href is forbidden',
      );
    }
    for (final match in RegExp(
      r'url\(\s*([^\)]+)\s*\)',
      caseSensitive: false,
    ).allMatches(attributes)) {
      final value = match
          .group(1)!
          .trim()
          .replaceAll(RegExp(r'''^["']|["']$'''), '');
      expect(
        value.startsWith('#'),
        isTrue,
        reason: '${template.id}: external URL is forbidden',
      );
    }

    final parent = frames.isEmpty ? null : frames.last;
    final inDefs = parent?.inDefs == true || element == 'defs';
    final id = _attribute(attributes, 'id');
    String? owner = parent?.surfaceOwner;
    if (id != null && groupCounts.containsKey(id)) {
      expect(element, 'g', reason: '${template.id}: $id must be a group');
      groupCounts[id] = groupCounts[id]! + 1;
      owner = id;
    }

    final normalizedAttributes = attributes.toUpperCase();
    for (final entry in illustratedRoomSurfaceTokens.entries) {
      final occurrences = entry.key.allMatches(normalizedAttributes).length;
      if (occurrences == 0) continue;
      expect(inDefs, isFalse, reason: '${template.id}: ${entry.key} in defs');
      expect(
        owner,
        entry.value,
        reason: '${template.id}: ${entry.key} leaked outside ${entry.value}',
      );
      expect(
        geometryElements,
        contains(element),
        reason: '${template.id}: ${entry.key} must color geometry',
      );
      tokenGeometryCounts[entry.key] =
          tokenGeometryCounts[entry.key]! + occurrences;
    }

    if (match.group(4) != '/') {
      frames.add(_SvgFrame(surfaceOwner: owner, inDefs: inDefs));
    }
  }

  expect(frames, isEmpty, reason: '${template.id}: unbalanced SVG');
  for (final entry in groupCounts.entries) {
    expect(
      entry.value,
      1,
      reason: '${template.id}: exactly one ${entry.key} group required',
    );
  }
  for (final entry in tokenGeometryCounts.entries) {
    expect(
      entry.value,
      greaterThan(0),
      reason: '${template.id}: ${entry.key} needs non-empty geometry',
    );
  }
}

Future<void> pumpIllustratedRoomRaster(
  WidgetTester tester,
  IllustratedRoomDraft draft,
) async {
  tester.view.physicalSize = illustratedRoomRasterSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: Colors.white,
        child: RepaintBoundary(
          key: illustratedRoomRasterKey,
          child: SizedBox.fromSize(
            size: illustratedRoomRasterSize,
            child: IllustratedRoomSvg(draft: draft, fit: BoxFit.fill),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<Uint8List> illustratedRoomPixels(WidgetTester tester) async =>
    (await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(illustratedRoomRasterKey),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return Uint8List.fromList(data!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    }))!;

List<int> illustratedRoomRgb(Uint8List pixels, int x, int y) => pixels.sublist(
  (y * illustratedRoomRasterSize.width.toInt() + x) * 4,
  (y * illustratedRoomRasterSize.width.toInt() + x) * 4 + 3,
);

void expectIllustratedRoomRgb(
  Uint8List pixels,
  (int, int) anchor,
  String expectedHex,
) {
  final expected = RgbColor.fromHex(expectedHex);
  final actual = illustratedRoomRgb(pixels, anchor.$1, anchor.$2);
  for (var channel = 0; channel < 3; channel++) {
    expect(
      actual[channel],
      closeTo([expected.red, expected.green, expected.blue][channel], 1),
      reason: 'anchor $anchor should render $expectedHex',
    );
  }
}

Iterable<String> _attributeValues(String attributes, String localName) sync* {
  final pattern = RegExp(
    '''(?:\\b|:)${RegExp.escape(localName)}\\s*=\\s*(["'])(.*?)\\1''',
    caseSensitive: false,
  );
  for (final match in pattern.allMatches(attributes)) {
    yield match.group(2)!;
  }
}

String? _attribute(String attributes, String name) {
  final pattern = RegExp(
    '''(?:^|\\s)${RegExp.escape(name)}\\s*=\\s*(["'])(.*?)\\1''',
    caseSensitive: false,
  );
  return pattern.firstMatch(attributes)?.group(2);
}

final class _SvgFrame {
  const _SvgFrame({required this.surfaceOwner, required this.inDefs});

  final String? surfaceOwner;
  final bool inDefs;
}
