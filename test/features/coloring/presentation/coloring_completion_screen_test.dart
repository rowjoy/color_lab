import 'dart:typed_data';

import 'package:color_lab/features/coloring/application/coloring_export_service.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/presentation/coloring_completion_screen.dart';
import 'package:color_lab/features/coloring/presentation/coloring_workspace_screen.dart';
import 'package:color_lab/features/room_studio/application/room_export_metadata_verifier.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

import '../../../support/coloring_flow_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List cleanPng;
  setUpAll(() async {
    final drawing = await AssetDrawingCatalogLoader().loadById(
      'fruit_red_apple',
    );
    final project = ColoringProject.create(
      drawingId: drawing.id,
      drawingRevision: drawing.revision,
      mode: ColoringMode.free,
    );
    cleanPng = await const VectorColoringExportService().encodePng(
      drawing,
      project,
      scale: 1,
    );
  });

  testWidgets('export is explicit and leaves a separate editable project', (
    tester,
  ) async {
    final encoder = ColoringEncoderBoundary(cleanPng);
    final transport = ColoringNativeTransportBoundary();
    final flow = await ColoringFlowHarness.launch(
      tester,
      encoder: encoder,
      transport: transport,
    );
    final before = (await flow.persisted(tester))!.toMap();
    final l10n = tester.element(find.byType(ColoringCompletionScreen)).l10n;
    expect(find.text(l10n.coloringCompleteBody), findsOneWidget);
    expect(encoder.projects, isEmpty);
    expect(transport.saved, isEmpty);
    expect(transport.shared, isEmpty);

    await tapColoringKey(tester, 'coloring-export');

    expect(find.text(l10n.coloringExportedComplete), findsOneWidget);
    expect(encoder.projects.single.toMap(), before);
    expect(transport.preparations, 1);
    expect(transport.photoIds.single, 'coloring-${flow.project.id}');
    expect(image.decodePng(transport.saved.single), isNotNull);
    const RoomExportMetadataVerifier().verify(transport.saved.single);
    expect((await flow.persisted(tester))!.toMap(), before);

    // The same saved project still opens in the editor, including undo history.
    flow.router.go('/coloring/project/${flow.project.id}');
    await pumpColoringUntil(tester, find.byType(ColoringWorkspaceScreen));
    expect(
      find.widgetWithText(OutlinedButton, l10n.coloringUndo),
      findsOneWidget,
    );
    expect((await flow.persisted(tester))!.undoStack, isNotEmpty);
    expect((await flow.persisted(tester))!.toMap(), before);
    expect(tester.takeException(), isNull);
  });

  for (final outcome in [
    RoomShareResult.dismissed,
    RoomShareResult.unavailable,
  ]) {
    testWidgets(
      'share ${outcome.name} keeps artwork and shows a friendly notice',
      (tester) async {
        final transport = ColoringNativeTransportBoundary(shareResult: outcome);
        final flow = await ColoringFlowHarness.launch(
          tester,
          encoder: ColoringEncoderBoundary(cleanPng),
          transport: transport,
        );
        final before = (await flow.persisted(tester))!.toMap();
        final l10n = tester.element(find.byType(ColoringCompletionScreen)).l10n;

        await tapColoringKey(tester, 'coloring-share');

        expect(
          find.text(
            outcome == RoomShareResult.dismissed
                ? l10n.coloringShareDismissed
                : l10n.coloringShareUnavailable,
          ),
          findsOneWidget,
        );
        expect(transport.shared, hasLength(1));
        expect(transport.saved, isEmpty);
        expect((await flow.persisted(tester))!.toMap(), before);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const ValueKey('coloring-share')),
              )
              .onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final encoderFails in [true, false]) {
    testWidgets(
      '${encoderFails ? 'encoder' : 'gallery save'} failure keeps the project and re-enables export',
      (tester) async {
        final encoder = ColoringEncoderBoundary(cleanPng, fail: encoderFails);
        final transport = ColoringNativeTransportBoundary(
          failSave: !encoderFails,
        );
        final flow = await ColoringFlowHarness.launch(
          tester,
          encoder: encoder,
          transport: transport,
        );
        final before = (await flow.persisted(tester))!.toMap();
        final l10n = tester.element(find.byType(ColoringCompletionScreen)).l10n;

        await tapColoringKey(tester, 'coloring-export');

        expect(find.text(l10n.coloringPngFailed), findsOneWidget);
        expect(transport.saved, isEmpty);
        expect(transport.preparations, encoderFails ? 0 : 1);
        expect((await flow.persisted(tester))!.toMap(), before);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('coloring-export')),
              )
              .onPressed,
          isNotNull,
        );
        if (!encoderFails) {
          transport.failSave = false;
          await tapColoringKey(tester, 'coloring-export');
          expect(transport.saved, hasLength(1));
          expect((await flow.persisted(tester))!.toMap(), before);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'invalid completion project has recovery copy and no export actions',
    (tester) async {
      final transport = ColoringNativeTransportBoundary();
      final flow = await ColoringFlowHarness.launch(
        tester,
        location: '/coloring/complete/missing-project',
        transport: transport,
      );
      final l10n = tester.element(find.byType(ColoringCompletionScreen)).l10n;
      expect(find.text(l10n.coloringCompletedUnavailable), findsOneWidget);
      expect(find.byKey(const ValueKey('coloring-export')), findsNothing);
      expect(find.byKey(const ValueKey('coloring-share')), findsNothing);
      expect(transport.saved, isEmpty);
      expect((await flow.persisted(tester))!.toMap(), flow.project.toMap());
      expect(tester.takeException(), isNull);
    },
  );
}
