import 'dart:typed_data';

import 'package:color_lab/features/coloring/application/coloring_export_service.dart';
import 'package:color_lab/features/coloring/application/coloring_project_providers.dart';
import 'package:color_lab/features/coloring/data/drawing_catalog_loader.dart';
import 'package:color_lab/features/coloring/domain/coloring_project.dart';
import 'package:color_lab/features/coloring/domain/drawing_definition.dart';
import 'package:color_lab/features/coloring/presentation/my_artwork_section.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/in_memory_coloring_project_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('My Artwork reports unavailable native sharing', (tester) async {
    final drawing = await AssetDrawingCatalogLoader().loadById(
      'fruit_red_apple',
    );
    final project = ColoringProject.create(
      drawingId: drawing.id,
      drawingRevision: drawing.revision,
      mode: ColoringMode.free,
    );
    final repository = InMemoryColoringProjectRepository([project]);
    final transport = _UnavailableShareTransport();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coloringProjectRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          drawingCatalogProvider.overrideWith((ref) async => [drawing]),
          coloringExportServiceProvider.overrideWithValue(const _StubEncoder()),
          roomImageExportServiceProvider.overrideWithValue(transport),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: MyArtworkSection()),
          ),
        ),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Share'));
    await tester.pumpAndSettle();

    expect(find.text('Sharing is unavailable on this device.'), findsOneWidget);
    expect(transport.shares, 1);
    expect(tester.takeException(), isNull);
  });
}

final class _StubEncoder implements ColoringExportService {
  const _StubEncoder();

  @override
  Future<Uint8List> encodePng(
    DrawingDefinition definition,
    ColoringProject project, {
    double scale = 2,
  }) async => Uint8List.fromList(const [1, 2, 3]);
}

final class _UnavailableShareTransport implements RoomImageExportService {
  int shares = 0;

  @override
  Future<void> prepareSave({required bool Function() isCurrent}) async {}

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String photoId,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {}

  @override
  Future<RoomShareResult> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
    required String title,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    shares++;
    return RoomShareResult.unavailable;
  }
}
