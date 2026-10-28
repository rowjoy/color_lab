import 'dart:ui' show Tristate;
import 'dart:ui' as ui;
import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_assignments.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_surface_picker.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_region_artwork.dart';
import 'package:color_lab/core/vector_regions/application/vector_region_transform.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _RoomHitFixture = ({
  IllustratedRoomTemplate template,
  List<({Offset point, String regionId, String kind})> targets,
});

Future<void> _expectRoomHitFixtures(
  WidgetTester tester,
  _RoomHitFixture fixture,
) async {
  final artwork = (await tester.runAsync(
    () => StudyRoomRegionArtwork.loadFor(fixture.template),
  ))!;
  String? selected;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            height: 400,
            child: IllustratedRoomRegionArtwork(
              artwork: artwork,
              draft: IllustratedRoomDraft.grayscale(fixture.template),
              onRegionSelected: (id) => selected = id,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final room = find.byType(IllustratedRoomRegionArtwork);
  final origin = tester.getTopLeft(room);
  for (final target in fixture.targets) {
    selected = null;
    await tester.tapAt(
      origin + Offset(target.point.dx / 2, target.point.dy / 2),
    );
    expect(
      selected,
      target.regionId,
      reason:
          '${fixture.template.id} ${target.kind} ${target.point} should select ${target.regionId}',
    );
  }
}

void main() {
  // Mutation: hit testing uses another fit/coordinate frame or rendering ignores
  // region overrides. The same authored region owns this interior pixel and tap.
  testWidgets(
    'authored region taps and rendered overrides share the fitted geometry',
    (tester) async {
      final artwork = (await tester.runAsync(StudyRoomRegionArtwork.load))!;
      String? selected;
      final draft = IllustratedRoomDraft.grayscale(
        IllustratedRoomCatalog.study,
      ).setRegionColor('wall-back', RgbColor.fromHex('#FF0000'));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 600,
              height: 400,
              child: IllustratedRoomRegionArtwork(
                artwork: artwork,
                draft: draft,
                selectedRegionId: 'wall-back',
                onRegionSelected: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final widget = find.byType(IllustratedRoomRegionArtwork);
      await tester.tapAt(tester.getTopLeft(widget) + const Offset(300, 100));
      expect(selected, 'wall-back');
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      artwork.draw(
        canvas,
        draft,
        VectorRegionTransform.fit(
          intrinsicSize: const Size(1200, 800),
          viewport: const Size(600, 400),
        ),
      );
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(600, 400));
      final bytes = await tester.runAsync(() => image!.toByteData());
      // Authored (600, 200) is the bare wall between the two framed pictures.
      final offset = (100 * 600 + 300) * 4;
      expect(bytes!.buffer.asUint8List().sublist(offset, offset + 3), [
        255,
        0,
        0,
      ]);
      image!.dispose();
      picture.dispose();
    },
  );

  // Mutation: folding the left/right tables into one authored identity or
  // swapping their geometry makes the interior and exact-boundary taps fail.
  testWidgets('Bedroom keeps separate left and right bedside-table hits', (
    tester,
  ) async {
    await _expectRoomHitFixtures(tester, (
      template: IllustratedRoomCatalog.bedroom,
      targets: const [
        (
          point: Offset(240, 550),
          regionId: 'bedside-table-left',
          kind: 'interior',
        ),
        (
          point: Offset(183, 490),
          regionId: 'bedside-table-left',
          kind: 'boundary',
        ),
        (
          point: Offset(930, 550),
          regionId: 'bedside-table-right',
          kind: 'wardrobe overlap',
        ),
        (
          point: Offset(886, 490),
          regionId: 'bedside-table-right',
          kind: 'boundary',
        ),
      ],
    ));
  });

  for (final fixture in <_RoomHitFixture>[
    (
      template: IllustratedRoomCatalog.living,
      targets: const [
        (point: Offset(600, 610), regionId: 'sofa', kind: 'interior'),
        (
          point: Offset(590, 690),
          regionId: 'coffee-table',
          kind: 'sofa overlap',
        ),
        (
          point: Offset(451, 656),
          regionId: 'coffee-table',
          kind: 'boundary over sofa',
        ),
      ],
    ),
    (
      template: IllustratedRoomCatalog.dining,
      targets: const [
        (point: Offset(1000, 560), regionId: 'sideboard', kind: 'interior'),
        (
          point: Offset(700, 470),
          regionId: 'dining-table',
          kind: 'back-chair overlap',
        ),
        (point: Offset(414, 508), regionId: 'dining-table', kind: 'boundary'),
      ],
    ),
    (
      template: IllustratedRoomCatalog.kitchen,
      targets: const [
        (
          point: Offset(250, 430),
          regionId: 'cabinet-lower-left',
          kind: 'interior',
        ),
        (
          point: Offset(800, 535),
          regionId: 'island',
          kind: 'lower-cabinet overlap',
        ),
        (
          point: Offset(315, 537),
          regionId: 'island',
          kind: 'boundary over lower cabinet',
        ),
      ],
    ),
    (
      template: IllustratedRoomCatalog.bathroom,
      targets: const [
        (point: Offset(980, 480), regionId: 'storage', kind: 'interior'),
        (point: Offset(400, 590), regionId: 'vanity', kind: 'interior'),
        (point: Offset(203, 519), regionId: 'vanity', kind: 'boundary'),
      ],
    ),
  ]) {
    // Mutation: authored geometry is assigned to the wrong region, or hit
    // order no longer matches paint order at a shared boundary/overlap.
    testWidgets(
      '${fixture.template.title} keeps authored interior boundary and overlap hits',
      (tester) => _expectRoomHitFixtures(tester, fixture),
    );
  }

  // Mutation: presenting group adapters as authored regions or omitting a region.
  testWidgets('every room lists its exact authored named regions', (
    tester,
  ) async {
    for (final template in IllustratedRoomCatalog.all) {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: IllustratedRoomSurfacePicker(
                draft: IllustratedRoomDraft.grayscale(template),
                selectedRegionId: null,
                onSelected: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final options = find.byType(OutlinedButton);
      final expected = IllustratedRoomRegionMembership.forTemplate(
        template,
      ).groups.values.fold(0, (count, ids) => count + ids.length);
      expect(options, findsNWidgets(expected));
      await tester.ensureVisible(options.last);
      await tester.tap(options.last);
      expect(selected, isNotNull);
      expect(find.textContaining('legacy-'), findsNothing);
    }
  });

  // Mutation: losing selected state, group/HEX labels, or keyboard button action.
  testWidgets(
    'region semantics name its region group value and selected state',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        final draft = IllustratedRoomDraft.grayscale(
          IllustratedRoomCatalog.study,
        ).setRegionColor('desk', RgbColor.fromHex('#123456'));
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: IllustratedRoomSurfacePicker(
                  draft: draft,
                  selectedRegionId: 'desk',
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final desk = find.byKey(const ValueKey('room-region-desk'));
        await tester.ensureVisible(desk);
        final data = tester.getSemantics(desk).getSemanticsData();
        expect(data.label, contains('Desk'));
        expect(data.label, contains('Furniture'));
        expect(data.label, contains('#123456'));
        expect(data.flagsCollection.isSelected, Tristate.isTrue);
        expect(data.flagsCollection.isButton, isTrue);
        expect(tester.getSize(desk).height, greaterThanOrEqualTo(48));
      } finally {
        handle.dispose();
      }
    },
  );
}
