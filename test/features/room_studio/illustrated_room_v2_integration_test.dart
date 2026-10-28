import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/data/db/hive_room_design_repository.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_draft_store.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_editor_persistence.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_palette_card_encoder.dart';
import 'package:color_lab/features/room_studio/application/room_designs_providers.dart';
import 'package:color_lab/features/room_studio/application/room_export_metadata_verifier.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:color_lab/features/room_studio/domain/saved_room_design.dart';
import 'package:color_lab/features/room_studio/presentation/illustrated_room_region_artwork.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _StaticArtworkEncoder implements IllustratedRoomArtworkEncoder {
  const _StaticArtworkEncoder(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> encodePng(IllustratedRoomDraft draft) async =>
      Uint8List.fromList(bytes);
}

final class _NativeHandoff {
  const _NativeHandoff(this.photoId, this.bytes);

  final String photoId;
  final Uint8List bytes;
}

final class _RecordingExportService implements RoomImageExportService {
  final saved = <_NativeHandoff>[];
  final shared = <_NativeHandoff>[];
  Rect? shareOrigin;
  String? shareTitle;

  @override
  Future<void> prepareSave({required bool Function() isCurrent}) async {
    if (!isCurrent()) throw const RoomExportInterrupted();
  }

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String photoId,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    if (!isCurrent()) throw const RoomExportInterrupted();
    onHandoff?.call();
    saved.add(_NativeHandoff(photoId, Uint8List.fromList(pngBytes)));
  }

  @override
  Future<RoomShareResult> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
    required String title,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    if (!isCurrent()) throw const RoomExportInterrupted();
    onHandoff?.call();
    shareOrigin = origin;
    shareTitle = title;
    shared.add(_NativeHandoff(photoId, Uint8List.fromList(pngBytes)));
    return RoomShareResult.completed;
  }
}

IllustratedRoomDraft _active(ProviderContainer container) =>
    container.read(illustratedRoomProvider).activeDraft!;

Future<void> _waitForAcknowledged(
  IllustratedRoomDraftStore store,
  IllustratedRoomDraft expected,
) async {
  for (var attempt = 0; attempt < 300; attempt++) {
    final restored = store.restoreAcknowledged(expected.template);
    if (store.statusFor(expected.template.id) ==
            IllustratedRoomDraftSaveStatus.saved &&
        restored?.assignments == expected.assignments &&
        restored?.pinnedBaseline == expected.pinnedBaseline &&
        restored?.savedDesignId == expected.savedDesignId &&
        restored?.savedName == expected.savedName) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Autosave did not acknowledge ${expected.template.id}.');
}

Future<Map<String, Map<String, Object?>>> _legacyFixtures() async {
  final decoded =
      jsonDecode(
            await File(
              'test/fixtures/illustrated_rooms/v1.json',
            ).readAsString(),
          )
          as List<dynamic>;
  return {
    for (final value in decoded.cast<Map<dynamic, dynamic>>())
      value['templateId']! as String: Map<String, Object?>.from(value),
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, Map<String, Object?>> legacyByTemplate;
  setUpAll(() async {
    legacyByTemplate = await _legacyFixtures();
  });

  for (final template in IllustratedRoomCatalog.all) {
    test(
      '${template.id} completes the offline Illustrated Rooms v2 workflow',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'tintatlas-v2-${template.id}-',
        );
        final boxName = 'milestone_${template.id}';
        var repository = await HiveRoomDesignRepository.open(
          directory: directory.path,
          boxName: boxName,
        );
        final container = ProviderContainer(
          overrides: [
            roomDesignRepositoryProvider.overrideWith(
              (ref) async => repository,
            ),
          ],
        );
        var containerOpen = true;
        var repositoryOpen = true;

        try {
          await container.read(savedRoomDesignsProvider.future);
          container.read(illustratedRoomEditorPersistenceProvider);
          final store = await container.read(
            illustratedRoomDraftStoreProvider.future,
          );
          final controller = container.read(illustratedRoomProvider.notifier);

          controller.openTemplate(template);
          final artwork = await StudyRoomRegionArtwork.loadFor(template);
          expect(artwork.definition.id, template.id);
          expect(
            artwork.definition.intrinsicSize,
            Size(
              template.artboardWidth.toDouble(),
              template.artboardHeight.toDouble(),
            ),
          );

          // Complete Look is explicit, then one copied swatch changes only one
          // authored furniture region even if its source collection is replaced.
          controller.applyCompleteLook(template.defaultPalette.colors);
          final completeLook = _active(container).assignments!;
          final membership = _active(container).membership;
          final furniture = membership.membersOf('furniture');
          final copiedSource = <RgbColor>[RgbColor.fromHex('#13579B')];
          final copiedSwatch = copiedSource.single;
          controller.setRegionColor(furniture.first, copiedSwatch);
          copiedSource[0] = RgbColor.fromHex('#FFFFFF');
          final singleEdit = _active(container).assignments!;
          expect(singleEdit.colorFor(furniture.first), copiedSwatch);
          expect(
            singleEdit.colorFor(furniture[1]),
            completeLook.colorFor(furniture[1]),
          );

          // All Walls owns exactly its declared members and one Undo/Redo command.
          final beforeWalls = singleEdit;
          final wallColor = RgbColor.fromHex('#2468AC');
          controller.setGroupColor('walls', wallColor);
          final grouped = _active(container).assignments!;
          for (final regionId in membership.membersOf('walls')) {
            expect(grouped.colorFor(regionId), wallColor);
          }
          for (final regionId in [
            ...membership.membersOf('ceiling'),
            ...membership.membersOf('floor'),
            ...membership.membersOf('furniture'),
          ]) {
            expect(grouped.colorFor(regionId), beforeWalls.colorFor(regionId));
          }
          controller.undo();
          expect(_active(container).assignments, beforeWalls);
          controller.redo();
          expect(_active(container).assignments, grouped);

          controller.pinBaseline();
          final pinned = _active(container);
          await _waitForAcknowledged(store, pinned);

          // Save, Save a Copy, Rename, and Delete keep independent identities.
          final original = await controller.saveDesign(
            '${template.id} original',
          );
          controller.setRegionColor(
            furniture.last,
            RgbColor.fromHex('#DEADBE'),
          );
          final copy = await controller.saveDesign(
            '${template.id} copy',
            asCopy: true,
          );
          expect(copy.id, isNot(original.id));
          expect(copy.snapshot, isNot(original.snapshot));
          final renamed = await controller.renameDesign(
            copy.id,
            '${template.id} renamed',
          );

          // A copied saved variant survives source deletion. A/B, Original and
          // B&W alter only the display projection, never history or assignments.
          final variant = original.snapshot.materializeForTemplate(template);
          final durable = _active(container);
          final durableHistory = durable.history;
          controller.setComparisonVariant(variant);
          expect(_active(container).displayAssignments, variant);
          await controller.deleteDesign(original.id);
          expect(_active(container).displayAssignments, variant);
          expect(_active(container).assignments, durable.assignments);
          expect(identical(_active(container).history, durableHistory), isTrue);
          controller.showPinnedBaseline();
          expect(_active(container).displayAssignments, durable.pinnedBaseline);
          controller.showTemporaryOriginal();
          expect(
            _active(container).displayAssignments,
            durable.savedAssignments,
          );
          controller.showTemporaryGrayscale();
          expect(_active(container).displayAssignments, isNull);
          controller.clearComparison();
          expect(_active(container).displayAssignments, durable.assignments);

          controller.openDesign(renamed);
          final reopenedCopy = _active(container);
          expect(reopenedCopy.savedDesignId, copy.id);
          expect(reopenedCopy.savedName, '${template.id} renamed');
          expect(reopenedCopy.assignments, durable.assignments);
          expect(reopenedCopy.pinnedBaseline, durable.pinnedBaseline);
          await _waitForAcknowledged(store, reopenedCopy);

          // Screen/thumbnail/export share the bundled definition. Real encoded
          // output is metadata-clean; Gallery/Share use a fake native boundary.
          final roomPng = await SvgIllustratedRoomArtworkEncoder().encodePng(
            reopenedCopy,
          );
          final roomDimensions = const RoomExportMetadataVerifier().verify(
            roomPng,
          );
          expect(roomDimensions.width, 2400);
          expect(roomDimensions.height, 1600);

          final card = IllustratedRoomPaletteCard.fromDraft(
            reopenedCopy,
            labelFor: (id) => id,
            limitation:
                'Illustrated preview; verify paint on a physical sample.',
          );
          final native = _RecordingExportService();
          final exportContainer = ProviderContainer(
            overrides: [
              illustratedRoomArtworkEncoderProvider.overrideWithValue(
                _StaticArtworkEncoder(roomPng),
              ),
              roomImageExportServiceProvider.overrideWithValue(native),
              roomExportClockProvider.overrideWithValue(
                () => DateTime.utc(2026, 10, 28, 12),
              ),
            ],
          );
          try {
            final export = exportContainer.read(
              illustratedRoomExportProvider.notifier,
            );
            final artworkResult = await export.saveToGallery(
              reopenedCopy,
              isCurrent: () => true,
            );
            final cardResult = await export.saveToGallery(
              reopenedCopy,
              paletteCard: card,
              isCurrent: () => true,
            );
            final shareResult = await export.share(
              reopenedCopy,
              origin: const Rect.fromLTWH(8, 8, 48, 48),
              title: 'TintAtlas',
              isCurrent: () => true,
            );
            expect(artworkResult, isA<IllustratedRoomExportSuccess>());
            expect(cardResult, isA<IllustratedRoomExportSuccess>());
            expect(
              (artworkResult as IllustratedRoomExportSuccess).fileName,
              startsWith('tintatlas-room-${template.id}-artwork-'),
            );
            expect(
              (cardResult as IllustratedRoomExportSuccess).fileName,
              startsWith('tintatlas-room-${template.id}-palette-'),
            );
            expect(
              shareResult,
              isA<IllustratedRoomExportShared>().having(
                (result) => result.result,
                'native result',
                RoomShareResult.completed,
              ),
            );
            expect(native.saved, hasLength(2));
            expect(native.shared, hasLength(1));
            expect(
              native.saved.first.photoId,
              contains('${template.id}-artwork-'),
            );
            expect(
              native.saved.last.photoId,
              contains('${template.id}-palette-'),
            );
            expect(
              native.shared.single.photoId,
              contains('${template.id}-artwork-'),
            );
            expect(native.shareOrigin, const Rect.fromLTWH(8, 8, 48, 48));
            expect(native.shareTitle, 'TintAtlas');
            expect(native.saved.first.bytes, roomPng);
            expect(native.shared.single.bytes, roomPng);
            final cardDimensions = const RoomExportMetadataVerifier().verify(
              native.saved.last.bytes,
            );
            expect(
              cardDimensions.width,
              CanvasIllustratedRoomPaletteCardEncoder.outputWidth,
            );
            expect(
              cardDimensions.height,
              lessThanOrEqualTo(
                CanvasIllustratedRoomPaletteCardEncoder.maxOutputHeight,
              ),
            );
          } finally {
            exportContainer.dispose();
          }

          // Frozen schema-v1 data reopens with exact four group values expanded
          // through the final authored membership without inferring a palette.
          final legacyMap = legacyByTemplate[template.id]!;
          final legacy = SavedRoomDesign.fromMap(legacyMap);
          final legacyAssignments = legacy.snapshot.materializeForTemplate(
            template,
            templateRevision: legacy.templateRevision,
          );
          expect(legacyAssignments.regionOverrides, isEmpty);
          expect(
            legacyAssignments.groupColors['walls']!.hex,
            legacyMap['wall'],
          );
          expect(
            legacyAssignments.groupColors['ceiling']!.hex,
            legacyMap['ceiling'],
          );
          expect(
            legacyAssignments.groupColors['floor']!.hex,
            legacyMap['floor'],
          );
          expect(
            legacyAssignments.groupColors['furniture']!.hex,
            legacyMap['furniture'],
          );
          for (final group in membership.groups.entries) {
            for (final regionId in group.value) {
              expect(
                legacyAssignments.colorFor(regionId),
                legacyAssignments.groupColors[group.key],
              );
            }
          }

          controller.openDesign(legacy);
          final reopenedLegacy = _active(container);
          expect(reopenedLegacy.template.id, template.id);
          expect(reopenedLegacy.savedDesignId, legacy.id);
          expect(reopenedLegacy.savedName, legacy.name);
          expect(reopenedLegacy.assignments, legacyAssignments);
          expect(reopenedLegacy.isDirty, isFalse);

          // Return to the stored v2 copy so the acknowledged recovery row does
          // not retain the fixture-only legacy identity across restart.
          controller.openDesign(renamed);
          final reopenedAfterLegacy = _active(container);
          expect(reopenedAfterLegacy.assignments, reopenedCopy.assignments);
          expect(
            reopenedAfterLegacy.pinnedBaseline,
            reopenedCopy.pinnedBaseline,
          );
          await _waitForAcknowledged(store, reopenedAfterLegacy);

          // Dispose every in-memory owner, reopen the actual Hive files, and
          // recover the acknowledged copy with exact assignments and pin.
          container.dispose();
          containerOpen = false;
          await repository.close();
          repositoryOpen = false;
          repository = await HiveRoomDesignRepository.open(
            directory: directory.path,
            boxName: boxName,
          );
          repositoryOpen = true;
          final persistedDesigns = await repository.load();
          expect(persistedDesigns, hasLength(1));
          expect(persistedDesigns.single.id, copy.id);
          expect(persistedDesigns.single.name, '${template.id} renamed');
          expect(persistedDesigns.single.snapshot, copy.snapshot);
          final persistedDraft = (await repository.loadDraftSnapshot()).records
              .singleWhere((record) => record.templateId == template.id)
              .restore(template);
          expect(persistedDraft.assignments, reopenedAfterLegacy.assignments);
          expect(
            persistedDraft.pinnedBaseline,
            reopenedAfterLegacy.pinnedBaseline,
          );
          expect(persistedDraft.savedDesignId, copy.id);
          expect(persistedDraft.savedName, '${template.id} renamed');
        } finally {
          if (containerOpen) container.dispose();
          if (repositoryOpen) await repository.close();
          if (await directory.exists()) await directory.delete(recursive: true);
        }
      },
    );
  }
}
