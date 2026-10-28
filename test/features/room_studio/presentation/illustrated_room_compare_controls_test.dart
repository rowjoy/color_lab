import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'dart:async';
import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_export_controls.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_compare_controls.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_region_artwork.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_svg.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/in_memory_room_design_repository.dart';
import '../../../support/illustrated_room_test_export_service.dart';
import '../../../support/room_png_fixtures.dart';

void main() {
  testWidgets(
    'legacy-v2 saved variant compares through copied authored regions',
    (tester) async {
      final now = DateTime.utc(2026, 10, 28);
      final source = SavedRoomDesign(
        id: 'living-legacy-b',
        name: 'Legacy B',
        templateId: 'living',
        snapshot: RoomDesignSnapshot(
          groupColors: {
            'walls': '#101010',
            'ceiling': '#202020',
            'floor': '#303030',
            'furniture': '#404040',
          },
          regionOverrides: {'legacy-furniture': '#A0A003'},
        ),
        createdAt: now,
        updatedAt: now,
      );
      final repository = InMemoryRoomDesignRepository(designs: [source]);
      final container = ProviderContainer(
        overrides: [
          roomDesignRepositoryProvider.overrideWith((ref) async => repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(illustratedRoomProvider.notifier);
      controller.openTemplate(IllustratedRoomCatalog.living);
      controller.applyPalette('soft-linen');
      final before = container.read(illustratedRoomProvider).activeDraft!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: IllustratedRoomCompareControls(templateId: 'living'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final variant = find.byKey(
        const ValueKey('room-compare-b-living-legacy-b'),
      );
      expect(variant, findsOneWidget);
      await tester.tap(variant);
      await tester.pump();
      final compared = container.read(illustratedRoomProvider).activeDraft!;
      for (final id in compared.membership.membersOf('furniture')) {
        expect(compared.displayAssignments!.colorFor(id).hex, '#A0A003');
      }
      expect(compared.assignments, before.assignments);
      expect(identical(compared.history, before.history), isTrue);
      expect(source.snapshot.regionOverrides, {'legacy-furniture': '#A0A003'});
    },
  );

  for (final cancel in [
    'route-dispose',
    'background-resume',
    'ordinary-edit',
  ]) {
    testWidgets(
      'export request ownership after $cancel while encoder is gated',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final encoder = _GatedExportEncoder();
        final writer = _RecordingExportWriter();
        final container = ProviderContainer(
          overrides: [
            illustratedRoomArtworkEncoderProvider.overrideWithValue(encoder),
            roomImageExportServiceProvider.overrideWithValue(
              IllustratedRoomTestExportService(writer),
            ),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(illustratedRoomProvider.notifier);
        controller.applyPalette('quiet-sage');
        final captured = container.read(illustratedRoomProvider).activeDraft!;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: IllustratedRoomExportControls(templateId: 'study'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey('room-export-artwork-save')),
        );
        await tester.pump();
        final pending = container
            .read(illustratedRoomExportProvider.notifier)
            .saveToGallery(captured);
        expect(encoder.captured, same(captured));
        if (cancel == 'route-dispose') {
          await tester.pumpWidget(const SizedBox.shrink());
        } else if (cancel == 'background-resume') {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        } else {
          controller.setRegionColor('desk', RgbColor.fromHex('#123456'));
        }
        encoder.gate.complete(roomPng());
        final result = await pending;
        await tester.pump();
        if (cancel == 'ordinary-edit') {
          expect(result, isA<IllustratedRoomExportSuccess>());
          expect(writer.calls, 1);
          expect(encoder.captured!.assignments, captured.assignments);
        } else {
          expect(
            result,
            isA<IllustratedRoomExportFailed>().having(
              (r) => r.failure,
              'failure',
              IllustratedRoomExportFailure.interrupted,
            ),
          );
          expect(writer.calls, 0);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'comparison-only changes repaint the real artwork and restore pixels',
    (tester) async {
      await tester.runAsync(StudyRoomRegionArtwork.load);
      tester.view.physicalSize = const Size(600, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final current =
          IllustratedRoomDraft.grayscale(IllustratedRoomCatalog.study)
              .applyPalette('quiet-sage')
              .setRegionColor('wall-back', RgbColor.fromHex('#112233'));
      final variant = current
          .setRegionColor('wall-back', RgbColor.fromHex('#ABCDEF'))
          .assignments!;
      Future<int> pixel(IllustratedRoomDraft draft) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: RepaintBoundary(
              key: const ValueKey('pixels'),
              child: IllustratedRoomSvg(draft: draft),
            ),
          ),
        );
        await tester.pump();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('pixels')),
        );
        final captured = await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            return await image.toByteData();
          } finally {
            image.dispose();
          }
        });
        final offset = (110 * 600 + 300) * 4;
        return (captured!.getUint8(offset) << 16) |
            (captured.getUint8(offset + 1) << 8) |
            captured.getUint8(offset + 2);
      }

      expect(await pixel(current), 0x112233);
      expect(await pixel(current.setComparisonVariant(variant)), 0xABCDEF);
      expect(await pixel(current.showTemporaryGrayscale()), 0xC8C8C8);
      expect(
        await pixel(current.showTemporaryGrayscale().clearComparison()),
        0x112233,
      );
    },
  );
  for (final direction in TextDirection.values) {
    testWidgets(
      'comparison controls preserve history at 320px 200% $direction',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            roomDesignRepositoryProvider.overrideWith(
              (ref) async => InMemoryRoomDesignRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(illustratedRoomProvider.notifier);
        controller.applyPalette('quiet-sage');
        final before = container.read(illustratedRoomProvider).activeDraft!;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Directionality(
                  textDirection: direction,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      textScaler: TextScaler.linear(2),
                    ),
                    child: const SingleChildScrollView(
                      child: IllustratedRoomCompareControls(
                        templateId: 'study',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final gray = find.byKey(const ValueKey('room-compare-grayscale'));
        await tester.ensureVisible(gray);
        await tester.tap(gray);
        await tester.pump();
        expect(
          container
              .read(illustratedRoomProvider)
              .activeDraft!
              .displayAssignments,
          isNull,
        );
        final grayElement = tester.element(gray);
        Focus.of(grayElement).requestFocus();
        // Focus ownership is committed asynchronously; let the requested node
        // become primary before dispatching Escape through CallbackShortcuts.
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(
          container
              .read(illustratedRoomProvider)
              .activeDraft!
              .displayAssignments,
          before.assignments,
        );
        await tester.tap(gray);
        await tester.pump();
        final close = find.byKey(const ValueKey('room-compare-close'));
        await tester.ensureVisible(close);
        await tester.tap(close);
        await tester.pump();
        final after = container.read(illustratedRoomProvider).activeDraft!;
        expect(after.assignments, before.assignments);
        expect(identical(after.history, before.history), isTrue);
        expect(after.isDirty, before.isDirty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final class _GatedExportEncoder implements IllustratedRoomArtworkEncoder {
  final gate = Completer<Uint8List>();
  IllustratedRoomDraft? captured;
  @override
  Future<Uint8List> encodePng(IllustratedRoomDraft draft) {
    captured = draft;
    return gate.future;
  }
}

final class _RecordingExportWriter implements RoomGalleryWriter {
  int calls = 0;
  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    calls++;
  }
}
