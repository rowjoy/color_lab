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

void validateIllustratedRoomSvg(
  String source,
  IllustratedRoomTemplate template,
) {
  expect(source.toLowerCase(), isNot(contains('watermark')));

  final svg = RegExp(
    r'<svg\b([^>]*)>',
    caseSensitive: false,
  ).firstMatch(source);
  expect(svg, isNotNull, reason: '${template.id}: missing <svg> root');
  final viewBox = _attribute(svg!.group(1)!, 'viewBox');
  expect(
    viewBox?.trim().split(RegExp(r'[\s,]+')),
    ['0', '0', '1200', '800'],
    reason: '${template.id}: canonical viewBox',
  );

  final forbiddenElements = <String>{
    'image',
    'filter',
    'script',
    'animate',
    'animatemotion',
    'animatetransform',
    'set',
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

  for (final match in tags.allMatches(source)) {
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
      forbiddenElements,
      isNot(contains(element)),
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
    '''\\b${RegExp.escape(name)}\\s*=\\s*(["'])(.*?)\\1''',
    caseSensitive: false,
  );
  return pattern.firstMatch(attributes)?.group(2);
}

final class _SvgFrame {
  const _SvgFrame({required this.surfaceOwner, required this.inDefs});

  final String? surfaceOwner;
  final bool inDefs;
}
