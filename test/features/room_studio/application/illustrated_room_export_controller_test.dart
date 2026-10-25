import 'dart:async';
import 'dart:typed_data';

import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 25, 4, 0, 0, 123);

  ProviderContainer containerFor({
    required IllustratedRoomArtworkEncoder encoder,
    required RoomGalleryWriter writer,
    DateTime Function()? clock,
  }) {
    final container = ProviderContainer(
      overrides: [
        illustratedRoomArtworkEncoderProvider.overrideWithValue(encoder),
        roomGalleryWriterProvider.overrideWithValue(writer),
        roomExportClockProvider.overrideWithValue(clock ?? () => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'coalesces calls and emits exact phases, filename and detached PNG',
    () async {
      final events = <String>[];
      final encoded = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 7]);
      final encodeGate = Completer<Uint8List>();
      final encoder = _FakeEncoder((draft) {
        events.add('encode');
        return encodeGate.future;
      });
      final writer = _GatedWriter(events);
      final container = containerFor(encoder: encoder, writer: writer);
      final phases = <IllustratedRoomExportPhase>[];
      container.listen(
        illustratedRoomExportProvider,
        (previous, next) => phases.add(next.phase),
        fireImmediately: true,
      );
      final controller = container.read(illustratedRoomExportProvider.notifier);

      final first = controller.saveToGallery(_coloredDraft());
      final second = controller.saveToGallery(_coloredDraft());

      expect(identical(first, second), isTrue);
      expect(encoder.calls, 1);
      expect(phases, [
        IllustratedRoomExportPhase.idle,
        IllustratedRoomExportPhase.rendering,
      ]);

      encodeGate.complete(encoded);
      await writer.entered.future;
      expect(events, ['encode', 'write']);
      expect(phases.last, IllustratedRoomExportPhase.saving);
      expect(writer.fileName, 'color-lab-study-20261025T040000123Z.png');
      expect(identical(writer.bytes, encoded), isFalse);
      encoded.fillRange(0, encoded.length, 0);
      expect(writer.bytes, [137, 80, 78, 71, 13, 10, 26, 10, 7]);

      writer.release.complete();
      final result = await first;
      expect(
        result,
        isA<IllustratedRoomExportSuccess>().having(
          (value) => value.fileName,
          'fileName',
          'color-lab-study-20261025T040000123Z.png',
        ),
      );
      expect(phases, [
        IllustratedRoomExportPhase.idle,
        IllustratedRoomExportPhase.rendering,
        IllustratedRoomExportPhase.saving,
        IllustratedRoomExportPhase.idle,
      ]);
      expect(container.read(illustratedRoomExportProvider).isBusy, isFalse);
    },
  );

  test('grayscale fails without encoder, writer or busy state', () async {
    var clockCalls = 0;
    final encoder = _FakeEncoder((draft) async => _png());
    final writer = _FakeWriter();
    final container = containerFor(
      encoder: encoder,
      writer: writer,
      clock: () {
        clockCalls++;
        return now;
      },
    );
    final phases = <IllustratedRoomExportPhase>[];
    container.listen(
      illustratedRoomExportProvider,
      (previous, next) => phases.add(next.phase),
      fireImmediately: true,
    );

    final result = await container
        .read(illustratedRoomExportProvider.notifier)
        .saveToGallery(
          IllustratedRoomDraft.grayscale(IllustratedRoomCatalog.study),
        );

    expect(_failure(result), IllustratedRoomExportFailure.notColored);
    expect(encoder.calls, 0);
    expect(writer.calls, 0);
    expect(clockCalls, 0);
    expect(phases, [IllustratedRoomExportPhase.idle]);
  });

  test('maps render failure without reaching Gallery', () async {
    final encoder = _FakeEncoder(
      (draft) async => throw const IllustratedRoomRenderException(),
    );
    final writer = _FakeWriter();
    final container = containerFor(encoder: encoder, writer: writer);

    final result = await container
        .read(illustratedRoomExportProvider.notifier)
        .saveToGallery(_coloredDraft());

    expect(_failure(result), IllustratedRoomExportFailure.renderFailed);
    expect(writer.calls, 0);
    expect(
      container.read(illustratedRoomExportProvider).phase,
      IllustratedRoomExportPhase.idle,
    );
  });

  test('maps a raw encoder failure safely without reaching Gallery', () async {
    final encoder = _FakeEncoder(
      (draft) async => throw StateError('private encoder detail'),
    );
    final writer = _FakeWriter();
    final container = containerFor(encoder: encoder, writer: writer);

    final result = await container
        .read(illustratedRoomExportProvider.notifier)
        .saveToGallery(_coloredDraft());

    expect(_failure(result), IllustratedRoomExportFailure.unexpected);
    expect(writer.calls, 0);
    expect(
      container.read(illustratedRoomExportProvider).phase,
      IllustratedRoomExportPhase.idle,
    );
  });

  test('maps every typed Gallery failure one-to-one', () async {
    const expected = {
      RoomGalleryFailure.accessDenied:
          IllustratedRoomExportFailure.accessDenied,
      RoomGalleryFailure.notEnoughSpace:
          IllustratedRoomExportFailure.notEnoughSpace,
      RoomGalleryFailure.unsupportedFormat:
          IllustratedRoomExportFailure.unsupportedFormat,
      RoomGalleryFailure.unsupportedPlatform:
          IllustratedRoomExportFailure.unsupportedPlatform,
      RoomGalleryFailure.unexpected: IllustratedRoomExportFailure.unexpected,
    };

    for (final entry in expected.entries) {
      final container = containerFor(
        encoder: _FakeEncoder((draft) async => _png()),
        writer: _FakeWriter(failure: RoomGalleryWriteException(entry.key)),
      );

      final result = await container
          .read(illustratedRoomExportProvider.notifier)
          .saveToGallery(_coloredDraft());

      expect(_failure(result), entry.value, reason: entry.key.name);
      expect(
        container.read(illustratedRoomExportProvider).phase,
        IllustratedRoomExportPhase.idle,
      );
    }
  });

  test('maps raw failure safely and permits a successful retry', () async {
    var attempt = 0;
    final writer = _FakeWriter(
      onSave: (bytes, fileName) async {
        attempt++;
        if (attempt == 1) throw StateError('private writer detail');
      },
    );
    final encoder = _FakeEncoder((draft) async => _png());
    final container = containerFor(encoder: encoder, writer: writer);
    final controller = container.read(illustratedRoomExportProvider.notifier);

    final failed = await controller.saveToGallery(_coloredDraft());
    final retried = await controller.saveToGallery(_coloredDraft());

    expect(_failure(failed), IllustratedRoomExportFailure.unexpected);
    expect(retried, isA<IllustratedRoomExportSuccess>());
    expect(encoder.calls, 2);
    expect(writer.calls, 2);
    expect(
      container.read(illustratedRoomExportProvider).phase,
      IllustratedRoomExportPhase.idle,
    );
  });
}

IllustratedRoomDraft _coloredDraft() => IllustratedRoomDraft.grayscale(
  IllustratedRoomCatalog.study,
).applyPalette('soft-botanical');

Uint8List _png() => Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);

IllustratedRoomExportFailure _failure(IllustratedRoomExportResult result) =>
    (result as IllustratedRoomExportFailed).failure;

final class _FakeEncoder implements IllustratedRoomArtworkEncoder {
  _FakeEncoder(this.onEncode);

  final Future<Uint8List> Function(IllustratedRoomDraft draft) onEncode;
  int calls = 0;

  @override
  Future<Uint8List> encodePng(IllustratedRoomDraft draft) {
    calls++;
    return onEncode(draft);
  }
}

final class _FakeWriter implements RoomGalleryWriter {
  _FakeWriter({this.failure, this.onSave});

  final Object? failure;
  final Future<void> Function(Uint8List bytes, String fileName)? onSave;
  int calls = 0;

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    calls++;
    if (failure case final error?) throw error;
    await onSave?.call(pngBytes, fileName);
  }
}

final class _GatedWriter implements RoomGalleryWriter {
  _GatedWriter(this.events);

  final List<String> events;
  final entered = Completer<void>();
  final release = Completer<void>();
  Uint8List? bytes;
  String? fileName;

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String fileName,
  }) async {
    events.add('write');
    bytes = pngBytes;
    this.fileName = fileName;
    entered.complete();
    await release.future;
  }
}
