import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:color_lab/core/vector_regions/data/vector_region_json_codec.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_assignments.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_region_artwork.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_surface_picker.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_svg.dart';
import 'package:color_lab/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const inventory = <String, (int regions, int parts, int slots)>{
    'living': (9, 19, 20),
    'bedroom': (9, 20, 21),
    'study': (8, 21, 22),
    'dining': (10, 21, 22),
    'kitchen': (10, 18, 19),
    'bathroom': (7, 11, 12),
  };

  test('six region catalogues freeze identities geometry and envelopes', () {
    for (final template in IllustratedRoomCatalog.all) {
      final expected = inventory[template.id]!;
      final path = template.regionAssetPath!;
      final definition = VectorRegionJsonCodec().decode(
        File(path).readAsStringSync(),
      );
      final source = File(template.assetPath).readAsStringSync();
      expect(definition.id, template.id);
      expect(definition.revision, 1);
      expect(definition.intrinsicSize.width, template.artboardWidth);
      expect(definition.intrinsicSize.height, template.artboardHeight);
      expect(definition.regions, hasLength(expected.$1));
      expect(definition.paintEntries, hasLength(expected.$2));
      expect(
        definition.paintEntries.map((entry) => entry.slot),
        orderedEquals(List.generate(expected.$2, (index) => index)),
      );
      expect(
        IllustratedRoomRegionMembership.fromRegions(definition.regions),
        IllustratedRoomRegionMembership.forTemplate(template),
      );
      expect(
        source.split('<!-- ${template.id}-decoration-slot -->'),
        hasLength(expected.$3),
      );
      expect(source, contains('<!-- ${template.id}-decoration-slots -->'));
      for (final token in ['#FF00A1', '#00E5FF', '#B7FF00', '#7A00FF']) {
        expect(
          source.toUpperCase(),
          isNot(contains(token)),
          reason: template.id,
        );
      }
      for (final group in IllustratedRoomRegionMembership.groupIds) {
        expect(
          IllustratedRoomRegionMembership.forTemplate(
            template,
          ).membersOf(group),
          isNotEmpty,
        );
      }
    }
  });

  test('shared-path recipes are exact and limited to Living and Dining', () {
    final recipes = <String, List<String>>{
      for (final template in IllustratedRoomCatalog.all)
        template.id: RegExp(r'<!--\s*room-shared-[\s\S]*?-->')
            .allMatches(File(template.assetPath).readAsStringSync())
            .map((match) => match.group(0)!.trim())
            .toList(),
    };
    expect(recipes['living'], [
      '<!-- room-shared-black-overlay part-slot="6" contour-indices="0,2" opacity="0.08" -->',
      '<!-- room-shared-gradient part-slot="10" gradient-id="living-fabric-roll" -->',
      '<!-- room-shared-gradient part-slot="14" gradient-id="living-fabric-roll" -->',
    ]);
    expect(recipes['dining'], [
      '<!-- room-shared-black-overlay part-slot="6" contour-indices="0" opacity="0.28" -->',
    ]);
    for (final id in ['bedroom', 'study', 'kitchen', 'bathroom']) {
      expect(recipes[id], isEmpty);
    }
  });

  test('every authored region and group has a localized public name', () {
    final l10n = AppLocalizationsEn();
    for (final template in IllustratedRoomCatalog.all) {
      final membership = IllustratedRoomRegionMembership.forTemplate(template);
      for (final id in {
        ...membership.groups.keys,
        ...membership.groups.values.expand((ids) => ids),
      }) {
        expect(roomRegionName(l10n, id).trim(), isNotEmpty, reason: id);
      }
    }
  });

  testWidgets('generic loader caches every room independently', (tester) async {
    final loaded = await tester.runAsync(
      () => Future.wait(
        IllustratedRoomCatalog.all.map(StudyRoomRegionArtwork.loadFor),
      ),
    );
    expect(loaded, isNotNull);
    for (var index = 0; index < IllustratedRoomCatalog.all.length; index++) {
      final template = IllustratedRoomCatalog.all[index];
      final artwork = loaded![index];
      expect(artwork.definition.id, template.id);
      expect(
        await tester.runAsync(() => StudyRoomRegionArtwork.loadFor(template)),
        same(artwork),
      );
    }
  });

  testWidgets('a failed cache key does not poison a valid room', (
    tester,
  ) async {
    final study = IllustratedRoomCatalog.study;
    final invalid = IllustratedRoomTemplate(
      id: 'invalid-study-copy',
      title: 'Invalid copy',
      summary: 'Test-only invalid identity.',
      assetPath: study.assetPath,
      regionAssetPath: study.regionAssetPath,
      defaultPaletteId: study.defaultPaletteId,
      palettes: study.palettes,
      surfaceLabels: study.surfaceLabels,
      focalPoint: study.focalPoint,
    );
    final first = StudyRoomRegionArtwork.loadFor(invalid);
    await tester.runAsync(
      () => expectLater(first, throwsA(isA<FormatException>())),
    );
    final second = StudyRoomRegionArtwork.loadFor(invalid);
    expect(second, isNot(same(first)));
    await tester.runAsync(
      () => expectLater(second, throwsA(isA<FormatException>())),
    );
    expect(
      (await tester.runAsync(StudyRoomRegionArtwork.load))!.definition.id,
      'study',
    );
  });

  testWidgets('late artwork from the previous room identity stays hidden', (
    tester,
  ) async {
    final source = IllustratedRoomCatalog.living;
    IllustratedRoomTemplate copy(String suffix) => IllustratedRoomTemplate(
      id: source.id,
      title: '${source.title} $suffix',
      summary: source.summary,
      assetPath: 'assets/test/$suffix-living.svg',
      regionAssetPath: 'assets/test/$suffix-living.json',
      defaultPaletteId: source.defaultPaletteId,
      palettes: source.palettes,
      surfaceLabels: source.surfaceLabels,
      focalPoint: source.focalPoint,
    );
    final slow = copy('slow');
    final fast = copy('fast');
    final slowGate = Completer<void>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (key == slow.regionAssetPath) await slowGate.future;
      if (key == slow.regionAssetPath || key == fast.regionAssetPath) {
        return ByteData.sublistView(
          Uint8List.fromList(File(source.regionAssetPath!).readAsBytesSync()),
        );
      }
      if (key == slow.assetPath || key == fast.assetPath) {
        return ByteData.sublistView(
          Uint8List.fromList(File(source.assetPath).readAsBytesSync()),
        );
      }
      return ByteData.sublistView(await File(key).readAsBytes());
    });
    addTearDown(() {
      if (!slowGate.isCompleted) slowGate.complete();
      messenger.setMockMessageHandler('flutter/assets', null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: IllustratedRoomSvg(draft: IllustratedRoomDraft.grayscale(slow)),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: IllustratedRoomSvg(draft: IllustratedRoomDraft.grayscale(fast)),
      ),
    );
    await tester.pumpAndSettle();
    final fastArtwork = await tester.runAsync(
      () => StudyRoomRegionArtwork.loadFor(fast),
    );
    expect(
      tester
          .widget<IllustratedRoomRegionArtwork>(
            find.byType(IllustratedRoomRegionArtwork),
          )
          .artwork,
      same(fastArtwork),
    );

    slowGate.complete();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IllustratedRoomRegionArtwork>(
            find.byType(IllustratedRoomRegionArtwork),
          )
          .artwork,
      same(fastArtwork),
    );
  });
}
