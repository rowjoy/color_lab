import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/illustrated_room_draft.dart';
import 'illustrated_room_artwork_encoder.dart';
import 'room_gallery_writer.dart';

enum IllustratedRoomExportPhase { idle, rendering, saving }

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
    IllustratedRoomDraft draft,
  ) {
    final active = _inFlight;
    if (active != null) return active;

    final completer = Completer<IllustratedRoomExportResult>();
    final operation = completer.future;
    _inFlight = operation;
    unawaited(_runAndComplete(draft, operation, completer));
    return operation;
  }

  Future<void> _runAndComplete(
    IllustratedRoomDraft draft,
    Future<IllustratedRoomExportResult> operation,
    Completer<IllustratedRoomExportResult> completer,
  ) async {
    IllustratedRoomExportResult result;
    try {
      result = await _execute(draft);
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
  ) async {
    if (draft.mode != IllustratedRoomVisualMode.colored) {
      return const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.notColored,
      );
    }

    final encoder = ref.read(illustratedRoomArtworkEncoderProvider);
    final writer = ref.read(roomGalleryWriterProvider);
    final clock = ref.read(roomExportClockProvider);
    try {
      if (ref.mounted) {
        state = const IllustratedRoomExportState(
          IllustratedRoomExportPhase.rendering,
        );
      }
      final encoded = await encoder.encodePng(draft);
      final detached = Uint8List.fromList(encoded);
      if (ref.mounted) {
        state = const IllustratedRoomExportState(
          IllustratedRoomExportPhase.saving,
        );
      }
      final fileName = _fileName(draft.template.id, clock());
      await writer.savePng(pngBytes: detached, fileName: fileName);
      return IllustratedRoomExportSuccess(fileName);
    } on IllustratedRoomRenderException {
      return const IllustratedRoomExportFailed(
        IllustratedRoomExportFailure.renderFailed,
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

String _fileName(String templateId, DateTime value) {
  final utc = value.toUtc();
  String digits(int number, int width) => number.toString().padLeft(width, '0');
  return 'color-lab-$templateId-'
      '${digits(utc.year, 4)}${digits(utc.month, 2)}${digits(utc.day, 2)}T'
      '${digits(utc.hour, 2)}${digits(utc.minute, 2)}'
      '${digits(utc.second, 2)}${digits(utc.millisecond, 3)}Z.png';
}
