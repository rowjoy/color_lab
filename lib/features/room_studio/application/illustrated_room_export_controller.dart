import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/illustrated_room_draft.dart';
import 'illustrated_room_artwork_encoder.dart';
import 'room_gallery_writer.dart';
import 'illustrated_room_palette_card_encoder.dart';
import 'room_image_export_service.dart';
import 'room_export_metadata_verifier.dart';

enum IllustratedRoomExportPhase { idle, rendering, saving, sharing }

final class IllustratedRoomExportState {
  const IllustratedRoomExportState(this.phase);

  final IllustratedRoomExportPhase phase;

  bool get isBusy => phase != IllustratedRoomExportPhase.idle;
}

enum IllustratedRoomExportFailure {
  notColored,
  renderFailed,
  accessDenied,
  notEnoughSpace,
  unsupportedFormat,
  unsupportedPlatform,
  unexpected,
  shareFailed,
  interrupted,
}

sealed class IllustratedRoomExportResult {
  const IllustratedRoomExportResult();
}

final class IllustratedRoomExportSuccess extends IllustratedRoomExportResult {
  const IllustratedRoomExportSuccess(this.fileName);

  final String fileName;
}

final class IllustratedRoomExportFailed extends IllustratedRoomExportResult {
  const IllustratedRoomExportFailed(this.failure);

  final IllustratedRoomExportFailure failure;
}

final class IllustratedRoomExportShared extends IllustratedRoomExportResult {
  const IllustratedRoomExportShared(this.result);
  final RoomShareResult result;
}

final roomExportClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final illustratedRoomExportProvider =
    NotifierProvider<
      IllustratedRoomExportController,
      IllustratedRoomExportState
    >(IllustratedRoomExportController.new);

final class IllustratedRoomExportController
    extends Notifier<IllustratedRoomExportState> {
  Future<IllustratedRoomExportResult>? _inFlight;

  @override
  IllustratedRoomExportState build() =>
      const IllustratedRoomExportState(IllustratedRoomExportPhase.idle);

  Future<IllustratedRoomExportResult> saveToGallery(
    IllustratedRoomDraft draft, {
    IllustratedRoomPaletteCard? paletteCard,
    bool Function()? isCurrent,
  }) => _start(draft, paletteCard: paletteCard, isCurrent: isCurrent);

  Future<IllustratedRoomExportResult> share(
    IllustratedRoomDraft draft, {
    required Rect origin,
    required String title,
    IllustratedRoomPaletteCard? paletteCard,
    bool Function()? isCurrent,
  }) => _start(
    draft,
    paletteCard: paletteCard,
    shareOrigin: origin,
    shareTitle: title,
    isCurrent: isCurrent,
  );

  Future<IllustratedRoomExportResult> _start(
    IllustratedRoomDraft draft, {
    IllustratedRoomPaletteCard? paletteCard,
    Rect? shareOrigin,
    String? shareTitle,
    bool Function()? isCurrent,
  }) {
    final active = _inFlight;
    if (active != null) return active;

    final completer = Completer<IllustratedRoomExportResult>();
    final operation = completer.future;
    _inFlight = operation;
    unawaited(
      _runAndComplete(
        draft,
        operation,
        completer,
        paletteCard,
        shareOrigin,
        shareTitle,
        () => ref.mounted && (isCurrent?.call() ?? true),
      ),
    );
    return operation;
  }

  Future<void> _runAndComplete(
    IllustratedRoomDraft draft,
    Future<IllustratedRoomExportResult> operation,
    Completer<IllustratedRoomExportResult> completer,
    IllustratedRoomPaletteCard? paletteCard,
    Rect? shareOrigin,
    String? shareTitle,
    bool Function() isCurrent,
  ) async {
    IllustratedRoomExportResult result;
    try {
      result = await _execute(
        draft,
        paletteCard,
        shareOrigin,
        shareTitle,
        isCurrent,
      );
    } catch (_) {
      result = const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.unexpected,
      );
    } finally {
      if (identical(_inFlight, operation)) {
        _inFlight = null;
        if (ref.mounted && state.isBusy) {
          state = const IllustratedRoomExportState(
            IllustratedRoomExportPhase.idle,
          );
        }
      }
    }
    completer.complete(result);
  }

  Future<IllustratedRoomExportResult> _execute(
    IllustratedRoomDraft draft,
    IllustratedRoomPaletteCard? paletteCard,
    Rect? shareOrigin,
    String? shareTitle,
    bool Function() isCurrent,
  ) async {
    if (paletteCard != null && draft.displayAssignments == null) {
      return const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.notColored,
      );
    }

    final encoder = ref.read(illustratedRoomArtworkEncoderProvider);
    final clock = ref.read(roomExportClockProvider);
    final cardEncoder = ref.read(illustratedRoomPaletteCardEncoderProvider);
    final service = ref.read(roomImageExportServiceProvider);
    try {
      if (!isCurrent()) throw const RoomExportInterrupted();
      if (ref.mounted) {
        state = const IllustratedRoomExportState(
          IllustratedRoomExportPhase.rendering,
        );
      }
      final encoded = paletteCard == null
          ? await encoder.encodePng(draft)
          : await cardEncoder.encodePng(paletteCard);
      if (!isCurrent()) throw const RoomExportInterrupted();
      final detached = Uint8List.fromList(encoded);
      const RoomExportMetadataVerifier().verify(detached);
      final fileName = _fileName(
        draft.template.id,
        clock(),
        paletteCard != null,
      );
      if (shareOrigin != null) {
        state = const IllustratedRoomExportState(
          IllustratedRoomExportPhase.sharing,
        );
        final result = await service.sharePng(
          pngBytes: detached,
          photoId: fileName.substring(
            'tintatlas-room-'.length,
            fileName.length - 4,
          ),
          origin: shareOrigin,
          title: shareTitle!,
          isCurrent: isCurrent,
        );
        return IllustratedRoomExportShared(result);
      }
      if (ref.mounted) {
        state = const IllustratedRoomExportState(
          IllustratedRoomExportPhase.saving,
        );
      }
      await service.prepareSave(isCurrent: isCurrent);
      if (!isCurrent()) throw const RoomExportInterrupted();
      await service.savePng(
        pngBytes: detached,
        photoId: fileName.substring(
          'tintatlas-room-'.length,
          fileName.length - 4,
        ),
        isCurrent: isCurrent,
      );
      return IllustratedRoomExportSuccess(fileName);
    } on IllustratedRoomRenderException {
      return const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.renderFailed,
      );
    } on RoomExportVerificationException {
      return const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.renderFailed,
      );
    } on RoomShareException {
      return const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.shareFailed,
      );
    } on RoomExportInterrupted {
      return const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.interrupted,
      );
    } on RoomGalleryWriteException catch (error) {
      return IllustratedRoomExportFailed(switch (error.failure) {
        RoomGalleryFailure.accessDenied =>
          IllustratedRoomExportFailure.accessDenied,
        RoomGalleryFailure.notEnoughSpace =>
          IllustratedRoomExportFailure.notEnoughSpace,
        RoomGalleryFailure.unsupportedFormat =>
          IllustratedRoomExportFailure.unsupportedFormat,
        RoomGalleryFailure.unsupportedPlatform =>
          IllustratedRoomExportFailure.unsupportedPlatform,
        RoomGalleryFailure.unexpected =>
          IllustratedRoomExportFailure.unexpected,
      });
    } catch (_) {
      return const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.unexpected,
      );
    }
  }
}

String _fileName(String templateId, DateTime value, bool paletteCard) {
  final utc = value.toUtc();
  String digits(int number, int width) => number.toString().padLeft(width, '0');
  final safeId = templateId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  return 'tintatlas-room-$safeId-${paletteCard ? 'palette' : 'artwork'}-'
      '${digits(utc.year, 4)}${digits(utc.month, 2)}${digits(utc.day, 2)}T'
      '${digits(utc.hour, 2)}${digits(utc.minute, 2)}'
      '${digits(utc.second, 2)}${digits(utc.millisecond, 3)}Z.png';
}
