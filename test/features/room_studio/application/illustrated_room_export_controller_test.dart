import 'dart:async';
import 'dart:io';

import 'package:color_lab/features/room_studio/application/illustrated_room_artwork_encoder.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_palette_card_encoder.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:color_lab/features/room_studio/application/illustrated_room_export_request.dart';
import '../../../support/room_png_fixtures.dart';
import '../../../support/illustrated_room_test_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 10, 25, 4, 0, 0, 123);

  ProviderContainer containerFor({
    required IllustratedRoomArtworkEncoder encoder,
    required RoomGalleryWriter writer,
    DateTime Function()? clock,
  }) {
    final container = ProviderContainer(
      overrides: [
        illustratedRoomArtworkEncoderProvider.overrideWithValue(encoder),
        roomImageExportServiceProvider.overrideWithValue(
          IllustratedRoomTestExportService(writer),
        ),
        roomExportClockProvider.overrideWithValue(clock ?? () => now),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'revoked request cannot hand off after a gated encoder completes',
    () async {
      var current = true;
      final gate = Completer<Uint8List>();
      final writer = _FakeWriter();
      final container = containerFor(
        encoder: _FakeEncoder((_) => gate.future),
        writer: writer,
      );
      final pending = container
          .read(illustratedRoomExportProvider.notifier)
          .saveToGallery(_coloredDraft(), isCurrent: () => current);
      current = false;
      gate.complete(_png());
      expect(_failure(await pending), IllustratedRoomExportFailure.interrupted);
      expect(writer.calls, 0);
    },
  );

  for (final stage in ['permission', 'gallery-temp', 'share-temp']) {
    test(
      'lifecycle revocation during $stage prevents terminal native handoff',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'illustrated-export-guard-',
        );
        addTearDown(() => root.delete(recursive: true));
        final entered = Completer<void>();
        final release = Completer<void>();
        var nativeCalls = 0;
        Future<Directory> temp() async {
          if (stage != 'permission') {
            entered.complete();
            await release.future;
          }
          return root;
        }

        final gallery = GalRoomGalleryWriter(
          platform: TargetPlatform.android,
          isWeb: false,
          temporaryRoot: temp,
          requestAccess: () async {
            if (stage == 'permission') {
              entered.complete();
              await release.future;
            }
            return true;
          },
          putImage: (_, {album}) async {
            nativeCalls++;
          },
        );
        const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(shareChannel, (_) async {
          nativeCalls++;
          return 'completed';
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(shareChannel, null),
        );
        final container = ProviderContainer(
          overrides: [
            illustratedRoomArtworkEncoderProvider.overrideWithValue(
              _FakeEncoder((_) async => _png()),
            ),
            roomImageExportServiceProvider.overrideWithValue(
              PlatformRoomImageExportService(
                gallery: gallery,
                temporaryRoot: temp,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final request = IllustratedRoomExportRequest(ownsRequest: () => true);
        addTearDown(request.dispose);
        final controller = container.read(
          illustratedRoomExportProvider.notifier,
        );
        final pending = stage == 'share-temp'
            ? controller.share(
                _coloredDraft(),
                origin: const Rect.fromLTWH(0, 0, 48, 48),
                title: 'TintAtlas',
                isCurrent: () => request.isCurrent,
              )
            : controller.saveToGallery(
                _coloredDraft(),
                isCurrent: () => request.isCurrent,
              );
        await entered.future;
        request.didChangeAppLifecycleState(AppLifecycleState.paused);
        request.didChangeAppLifecycleState(AppLifecycleState.resumed);
        release.complete();
        expect(
          _failure(await pending),
          IllustratedRoomExportFailure.interrupted,
        );
        expect(nativeCalls, 0);
        expect(await root.list().toList(), isEmpty);
      },
    );
  }

  test(
    'native Share completion remains authoritative after handoff lifecycle change',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'illustrated-share-handed-off-',
      );
      addTearDown(() => root.delete(recursive: true));
      final entered = Completer<void>();
      final release = Completer<String>();
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) {
        entered.complete();
        return release.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final container = ProviderContainer(
        overrides: [
          illustratedRoomArtworkEncoderProvider.overrideWithValue(
            _FakeEncoder((_) async => _png()),
          ),
          roomImageExportServiceProvider.overrideWithValue(
            PlatformRoomImageExportService(temporaryRoot: () async => root),
          ),
        ],
      );
      addTearDown(container.dispose);
      final request = IllustratedRoomExportRequest(ownsRequest: () => true);
      addTearDown(request.dispose);
      final pending = container
          .read(illustratedRoomExportProvider.notifier)
          .share(
            _coloredDraft(),
            origin: const Rect.fromLTWH(0, 0, 48, 48),
            title: 'TintAtlas',
            isCurrent: () => request.isCurrent,
          );
      await entered.future;
      request.didChangeAppLifecycleState(AppLifecycleState.inactive);
      release.complete('completed');
      expect(
        await pending,
        isA<IllustratedRoomExportShared>().having(
          (r) => r.result,
          'native result',
          RoomShareResult.completed,
        ),
      );
    },
  );

  test(
    'coalesces calls and emits exact phases, filename and detached PNG',
    () async {
      final events = <String>[];
      final encoded = _png();
      final expectedBytes = Uint8List.fromList(encoded);
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
      expect(
        writer.fileName,
        'tintatlas-room-study-artwork-20261025T040000123Z.png',
      );
      expect(identical(writer.bytes, encoded), isFalse);
      encoded.fillRange(0, encoded.length, 0);
      expect(writer.bytes, expectedBytes);

      writer.release.complete();
      final result = await first;
      expect(
        result,
        isA<IllustratedRoomExportSuccess>().having(
          (value) => value.fileName,
          'fileName',
          'tintatlas-room-study-artwork-20261025T040000123Z.png',
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

  test('grayscale room exports the displayed view', () async {
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

    expect(result, isA<IllustratedRoomExportSuccess>());
    expect(encoder.calls, 1);
    expect(writer.calls, 1);
    expect(clockCalls, 1);
    expect(phases.last, IllustratedRoomExportPhase.idle);
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

  test('rejects unverified PNG before native Gallery handoff', () async {
    final writer = _FakeWriter();
    final container = containerFor(
      encoder: _FakeEncoder((_) async => Uint8List.fromList([1, 2, 3])),
      writer: writer,
    );
    final result = await container
        .read(illustratedRoomExportProvider.notifier)
        .saveToGallery(_coloredDraft());
    expect(_failure(result), IllustratedRoomExportFailure.renderFailed);
    expect(writer.calls, 0);
  });

  test(
    'palette artifact uses captured card encoder and a separate filename',
    () async {
      final draft = _coloredDraft();
      final card = IllustratedRoomPaletteCard.fromDraft(
        draft,
        labelFor: (id) => id,
        limitation: 'Preview only',
      );
      final encoder = _FakeEncoder(
        (_) async => throw StateError('Room encoder should not run'),
      );
      final writer = _FakeWriter();
      final cardEncoder = _FakeCardEncoder();
      final container = ProviderContainer(
        overrides: [
          illustratedRoomArtworkEncoderProvider.overrideWithValue(encoder),
          illustratedRoomPaletteCardEncoderProvider.overrideWithValue(
            cardEncoder,
          ),
          roomImageExportServiceProvider.overrideWithValue(
            IllustratedRoomTestExportService(writer),
          ),
          roomExportClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      final result = await container
          .read(illustratedRoomExportProvider.notifier)
          .saveToGallery(draft, paletteCard: card);
      expect(
        result,
        isA<IllustratedRoomExportSuccess>().having(
          (r) => r.fileName,
          'filename',
          'tintatlas-room-study-palette-20261025T040000123Z.png',
        ),
      );
      expect(identical(cardEncoder.card, card), isTrue);
      expect(encoder.calls, 0);
    },
  );

  for (final nativeResult in RoomShareResult.values) {
    test(
      'share maps $nativeResult and captures displayed grayscale without editing',
      () async {
        final draft = _coloredDraft().showTemporaryGrayscale();
        final service = _FakeShareService(nativeResult);
        final container = ProviderContainer(
          overrides: [
            illustratedRoomArtworkEncoderProvider.overrideWithValue(
              _FakeEncoder((captured) async {
                expect(captured.displayAssignments, isNull);
                expect(captured.assignments, draft.assignments);
                return _png();
              }),
            ),
            roomImageExportServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);
        final result = await container
            .read(illustratedRoomExportProvider.notifier)
            .share(
              draft,
              origin: const Rect.fromLTWH(10, 20, 48, 48),
              title: 'TintAtlas room preview',
            );
        expect(
          result,
          isA<IllustratedRoomExportShared>().having(
            (r) => r.result,
            'native result',
            nativeResult,
          ),
        );
        expect(service.origin, const Rect.fromLTWH(10, 20, 48, 48));
        expect(service.title, 'TintAtlas room preview');
        expect(service.photoId, startsWith('study-artwork-'));
      },
    );
  }
}

IllustratedRoomDraft _coloredDraft() => IllustratedRoomDraft.grayscale(
  IllustratedRoomCatalog.study,
).applyPalette('quiet-sage');

Uint8List _png() => roomPng();

final class _FakeCardEncoder implements IllustratedRoomPaletteCardEncoder {
  IllustratedRoomPaletteCard? card;
  @override
  Future<Uint8List> encodePng(IllustratedRoomPaletteCard card) async {
    this.card = card;
    return _png();
  }
}

final class _FakeShareService implements RoomImageExportService {
  _FakeShareService(this.result);
  final RoomShareResult result;
  Rect? origin;
  String? title, photoId;
  @override
  Future<void> prepareSave({required bool Function() isCurrent}) async {}
  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String photoId,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async => throw StateError('Unexpected save');
  @override
  Future<RoomShareResult> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
    required String title,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    this.origin = origin;
    this.title = title;
    this.photoId = photoId;
    expect(isCurrent(), isTrue);
    return result;
  }
}

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
