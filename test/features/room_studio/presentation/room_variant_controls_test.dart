import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:color_lab/features/room_studio/application/room_mask_controller.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:color_lab/features/room_studio/application/room_projects_providers.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_service.dart';
import 'package:color_lab/features/room_studio/presentation/room_variant_controls.dart';
import 'package:color_lab/features/room_studio/recolor/room_photo_recolorer.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_room_project_repository.dart';
import '../../../support/room_project_fixtures.dart';

class _Renderer implements RoomRecolorService {
  @override
  Future<RoomRecolorFrame> render({
    required RoomRecolorKey key,
    required PreparedPhoto photo,
    required MaskBitmap masks,
    required RoomLayerColors colors,
  }) async =>
      recolorRoomPhoto(key: key, photo: photo, masks: masks, colors: colors);
}

Future<ProviderContainer> mount(
  WidgetTester tester, {
  Size size = const Size(840, 800),
  double scale = 1,
  bool original = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var n = 0;
  final repo = InMemoryRoomProjectRepository(
    initial: [roomProjectFixture(revision: 1)],
  );
  final c = ProviderContainer(
    overrides: [
      roomProjectRepositoryProvider.overrideWith((ref) async => repo),
      roomProjectIdFactoryProvider.overrideWithValue(() => 'new-${n++}'),
      roomRecolorServiceProvider.overrideWithValue(_Renderer()),
    ],
  );
  var opened = false;
  c
      .read(roomMaskProvider.notifier)
      .openProject('project-1')
      .then((value) => opened = value);
  for (var i = 0; i < 100 && !opened; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  expect(opened, isTrue);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const RoomVariantControls(),
                RoomComparisonPreview(showOriginal: original),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

Future<void> tap(WidgetTester tester, String key) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'repeated rename Apply while save waits creates only one intent',
    (tester) async {
      final c = await mount(tester);
      final repo =
          c.read(roomProjectRepositoryProvider).requireValue
              as InMemoryRoomProjectRepository;
      final gate = Completer<void>();
      repo.beforeSave = () => gate.future;
      await tap(tester, 'room-variant-rename-variant-a');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Renamed',
      );
      final apply = find.byKey(const ValueKey('room-variant-submit'));
      await tester.ensureVisible(apply);
      await tester.tap(apply);
      await tester.tap(apply);
      await tester.pump();
      expect(c.read(roomProjectSessionProvider)!.pendingSaveCount, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(c.read(roomProjectSessionProvider)!.durable!.revision, 2);
    },
  );
  testWidgets(
    'A/B buttons select colors and create rename delete pin clear persist',
    (tester) async {
      final c = await mount(tester);
      await tap(tester, 'room-variant-select-variant-b');
      expect(c.read(roomProjectSessionProvider)!.activeVariantId, 'variant-b');
      await tap(tester, 'room-variant-create');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Evening',
      );
      await tap(tester, 'room-variant-submit');
      expect(c.read(roomProjectSessionProvider)!.variants.last.name, 'Evening');
      await tap(tester, 'room-variant-rename-new-0');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Night',
      );
      await tap(tester, 'room-variant-submit');
      await tap(tester, 'room-variant-pin-variant-a');
      expect(
        c.read(roomProjectSessionProvider)!.comparisonBaselineVariantId,
        'variant-a',
      );
      await tap(tester, 'room-comparison-clear');
      expect(
        c.read(roomProjectSessionProvider)!.comparisonBaselineVariantId,
        isNull,
      );
      await tap(tester, 'room-variant-delete-new-0');
      expect(c.read(roomProjectSessionProvider)!.activeVariantId, 'variant-a');
      expect(
        c.read(roomProjectSessionProvider)!.durable!.variants,
        hasLength(2),
      );
      expect(c.read(roomProjectSessionProvider)!.durable!.revision, 7);
    },
  );
  testWidgets('name error is safe and keeps dialog editable', (tester) async {
    final c = await mount(tester);
    await tap(tester, 'room-variant-create');
    await tester.enterText(
      find.byKey(const ValueKey('room-variant-name')),
      ' a ',
    );
    await tap(tester, 'room-variant-submit');
    expect(
      find.text('Choose a different name. Each variant needs a unique name.'),
      findsOneWidget,
    );
    expect(c.read(roomProjectSessionProvider)!.durable!.revision, 1);
    await tester.enterText(
      find.byKey(const ValueKey('room-variant-name')),
      'Valid',
    );
    await tap(tester, 'room-variant-submit');
    expect(c.read(roomProjectSessionProvider)!.variants, hasLength(3));
  });
  testWidgets(
    'real split images and drag keyboard semantics never mutate project',
    (tester) async {
      final c = await mount(tester);
      final semantics = tester.ensureSemantics();
      final before = c.read(roomProjectSessionProvider)!;
      expect(
        find.byKey(const ValueKey('room-comparison-active-image')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('room-comparison-baseline-image')),
        findsOneWidget,
      );
      final slider = find.byKey(const ValueKey('room-comparison-divider'));
      await tester.ensureVisible(slider);
      await tester.pumpAndSettle();
      await tester.drag(slider, const Offset(100, 0));
      await tester.pump();
      final value = tester.widget<Slider>(slider).value;
      expect(value, isNot(.5));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(tester.widget<Slider>(slider).value, lessThan(value));
      final node = tester.getSemantics(slider);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.increase),
        isTrue,
      );
      node.owner!.performAction(node.id, SemanticsAction.increase);
      await tester.pump();
      expect(identical(c.read(roomProjectSessionProvider), before), isTrue);
      semantics.dispose();
    },
  );
  testWidgets(
    'temporary original comparison renders source without metadata changes',
    (tester) async {
      final c = await mount(tester, original: true);
      expect(
        find.byKey(const ValueKey('room-comparison-original-image')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('room-comparison-active-image')),
        findsNothing,
      );
      expect(c.read(roomProjectSessionProvider)!.durable!.revision, 1);
      expect(c.read(roomProjectSessionProvider)!.activeVariantId, 'variant-a');
      expect(
        c.read(roomProjectSessionProvider)!.comparisonBaselineVariantId,
        'variant-b',
      );
    },
  );
  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(840, 800),
    const Size(1200, 800),
  ]) {
    testWidgets('comparison actions reachable at $size and 200 percent text', (
      tester,
    ) async {
      final c = await mount(tester, size: size, scale: 2);
      expect(tester.takeException(), isNull);
      await tap(tester, 'room-variant-select-variant-b');
      await tap(tester, 'room-variant-pin-variant-a');
      await tester.ensureVisible(
        find.byKey(const ValueKey('room-comparison-divider')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, 'room-comparison-clear');
      expect(
        c.read(roomProjectSessionProvider)!.comparisonBaselineVariantId,
        isNull,
      );
      await tap(tester, 'room-variant-create');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Evening',
      );
      await tap(tester, 'room-variant-submit');
      await tap(tester, 'room-variant-rename-new-0');
      await tester.enterText(
        find.byKey(const ValueKey('room-variant-name')),
        'Night',
      );
      await tap(tester, 'room-variant-submit');
      await tap(tester, 'room-variant-delete-new-0');
      expect(c.read(roomProjectSessionProvider)!.variants, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }
}
