import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/core/vector_regions/application/vector_region_transform.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_region_artwork.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;

import '../../../support/legacy_illustrated_room_color_mapper.dart';

const _bedroomTableTopContours = <List<Offset>>[
  [
    Offset(183, 490),
    Offset(286, 484),
    Offset(312, 499),
    Offset(208, 506),
    Offset(183, 490),
  ],
  [
    Offset(886, 490),
    Offset(978, 484),
    Offset(1001, 499),
    Offset(910, 506),
    Offset(886, 490),
  ],
];

bool _isBedroomTableTopBoundary(int x, int y) {
  final point = Offset(x + .5, y + .5);
  for (final contour in _bedroomTableTopContours) {
    for (var index = 0; index < contour.length - 1; index++) {
      final start = contour[index];
      final delta = contour[index + 1] - start;
      final t =
          ((point - start).dx * delta.dx + (point - start).dy * delta.dy) /
          delta.distanceSquared;
      final closest = start + delta * t.clamp(0.0, 1.0);
      if ((point - closest).distance <= .5) return true;
    }
  }
  return false;
}

void main() {
  const size = Size(1200, 800);

  IllustratedRoomDraft colored(IllustratedRoomTemplate template) {
    var draft = IllustratedRoomDraft.grayscale(template);
    for (final entry in <IllustratedRoomSurface, String>{
      IllustratedRoomSurface.wall: '#B82D42',
      IllustratedRoomSurface.ceiling: '#D7E4F2',
      IllustratedRoomSurface.floor: '#73573D',
      IllustratedRoomSurface.furniture: '#315E73',
    }.entries) {
      draft = draft.setSurfaceColor(entry.key, RgbColor.fromHex(entry.value));
    }
    return draft;
  }

  String fixture(IllustratedRoomTemplate template) => template.id == 'study'
      ? 'test/fixtures/study_room_pre_region_pilot.svg'
      : 'test/fixtures/illustrated_rooms/${template.id}_room_pre_regions.svg';

  Future<Uint8List> migrated(IllustratedRoomDraft draft) async {
    final artwork = await StudyRoomRegionArtwork.loadFor(draft.template);
    final recorder = ui.PictureRecorder();
    artwork.draw(
      Canvas(recorder),
      draft,
      VectorRegionTransform.fit(
        intrinsicSize: artwork.definition.intrinsicSize,
        viewport: size,
        fit: BoxFit.fill,
      ),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(1200, 800);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(data!.buffer.asUint8List());
    } finally {
      image.dispose();
      picture.dispose();
    }
  }

  Future<Uint8List> legacy(IllustratedRoomDraft draft) async {
    final info = await vg.vg.loadPicture(
      SvgStringLoader(
        File(fixture(draft.template)).readAsStringSync(),
        colorMapper: LegacyIllustratedRoomColorMapper(draft),
      ),
      null,
    );
    final image = await info.picture.toImage(1200, 800);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(data!.buffer.asUint8List());
    } finally {
      image.dispose();
      info.picture.dispose();
    }
  }

  for (final template in IllustratedRoomCatalog.all) {
    testWidgets('${template.id} migration preserves grayscale and color raster', (
      tester,
    ) async {
      for (final draft in [
        IllustratedRoomDraft.grayscale(template),
        colored(template),
      ]) {
        final images = await tester.runAsync(
          () async => (await migrated(draft), await legacy(draft)),
        );
        final actual = images!.$1;
        final expected = images.$2;
        expect(actual, hasLength(expected.length));
        var changed = 0;
        var toleratedBedroomTableTopChannels = 0;
        final examples = <String>[];
        for (var offset = 0; offset < expected.length; offset++) {
          final delta = (actual[offset] - expected[offset]).abs();
          if (delta <= 1) continue;
          final pixel = offset ~/ 4;
          final x = pixel % 1200;
          final y = pixel ~/ 1200;
          final isBoundedBedroomRegrouping =
              template.id == 'bedroom' &&
              draft.displayMode == IllustratedRoomVisualMode.colored &&
              delta <= 2 &&
              _isBedroomTableTopBoundary(x, y);
          if (isBoundedBedroomRegrouping) {
            toleratedBedroomTableTopChannels++;
            continue;
          }
          changed++;
          if (examples.length < 8) {
            examples.add(
              '($x,$y) channel ${offset % 4}: '
              '${actual[offset]} != ${expected[offset]}',
            );
          }
        }
        expect(
          toleratedBedroomTableTopChannels,
          lessThanOrEqualTo(7),
          reason:
              'Only seven channels may use the Bedroom colored table-top regrouping allowance.',
        );
        expect(
          changed,
          0,
          reason: '${template.id} ${draft.displayMode}: $examples',
        );
      }
    });
  }
}
