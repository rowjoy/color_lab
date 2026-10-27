import 'dart:async';
import 'dart:io';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/features/room_studio/application/room_export_metadata_verifier.dart';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/room_png_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  final calls = <MethodCall>[];
  const gallery = MethodChannel('gal');
  const share = MethodChannel('dev.fluttercommunity.plus/share');
  const origin = Rect.fromLTWH(12, 24, 80, 48);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('room-export-test-');
    await File('${root.path}/keep').writeAsString('unowned');
    calls.clear();
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(gallery, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(share, null);
    await root.delete(recursive: true);
  });
  PlatformRoomImageExportService service({
    Future<Directory> Function()? temp,
  }) => PlatformRoomImageExportService(
    gallery: GalRoomGalleryWriter(
      platform: TargetPlatform.android,
      isWeb: false,
      temporaryRoot: temp ?? () async => root,
    ),
    temporaryRoot: temp ?? () async => root,
  );
  void channels({
    Future<Object?> Function(MethodCall)? save,
    Future<Object?> Function(MethodCall)? sharing,
  }) {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      gallery,
      save ??
          (call) async {
            calls.add(call);
            return true;
          },
    );
    messenger.setMockMethodCallHandler(
      share,
      sharing ??
          (call) async {
            calls.add(call);
            return '';
          },
    );
  }

  test(
    'Save and Share hand off exact detached verified PNG with private filename and localized title',
    () async {
      final original = roomPng();
      final expected = Uint8List.fromList(original);
      Future<Object?> inspect(MethodCall call) async {
        calls.add(call);
        if (call.method == 'requestAccess') {
          expect(call.arguments, {'toAlbum': false});
          return true;
        }
        final args = call.arguments as Map;
        final path = call.method == 'putImage'
            ? args['path'] as String
            : (args['paths'] as List).single as String;
        expect(
          File(path).uri.pathSegments.last,
          'tintatlas-room-Room-north-1.png',
        );
        expect(await File(path).readAsBytes(), expected);
        expect(
          const RoomExportMetadataVerifier()
              .verify(await File(path).readAsBytes())
              .width,
          2,
        );
        if (call.method == 'share') {
          expect(args['mimeTypes'], ['image/png']);
          expect(args['title'], 'TintAtlas localized');
          expect(args['subject'], 'TintAtlas localized');
          expect(args['originX'], 12);
          expect(args['originWidth'], 80);
        } else {
          expect(args['album'], isNull);
        }
        return '';
      }

      channels(save: inspect, sharing: inspect);
      final s = service();
      await s.prepareSave(isCurrent: () => true);
      final saving = s.savePng(
        pngBytes: original,
        photoId: '../Room / north #1',
        isCurrent: () => true,
      );
      original.fillRange(0, original.length, 0);
      await saving;
      final result = await s.sharePng(
        pngBytes: expected,
        photoId: '../Room / north #1',
        origin: origin,
        title: 'TintAtlas localized',
        isCurrent: () => true,
      );
      expect(result, RoomShareResult.dismissed);
      expect(calls.map((e) => e.method), [
        'requestAccess',
        'putImage',
        'share',
      ]);
      expect(await root.list().length, 1);
    },
  );
  test('denied permission prevents write and maps access safely', () async {
    channels(
      save: (call) async {
        calls.add(call);
        return false;
      },
    );
    await expectLater(
      service().prepareSave(isCurrent: () => true),
      throwsA(
        isA<RoomGalleryWriteException>().having(
          (e) => e.failure,
          'failure',
          RoomGalleryFailure.accessDenied,
        ),
      ),
    );
    expect(calls.map((e) => e.method), ['requestAccess']);
  });
  for (final operation in ['save', 'share']) {
    test(
      '$operation rejects stale ownership after temp preparation at real channel seam',
      () async {
        channels();
        final gate = Completer<Directory>();
        var current = true;
        final s = service(temp: () => gate.future);
        final operationFuture = operation == 'save'
            ? s.savePng(
                pngBytes: roomPng(),
                photoId: 'photo',
                isCurrent: () => current,
              )
            : s.sharePng(
                pngBytes: roomPng(),
                photoId: 'photo',
                origin: origin,
                title: 'TintAtlas',
                isCurrent: () => current,
              );
        final expected = expectLater(
          operationFuture,
          throwsA(isA<RoomExportInterrupted>()),
        );
        current = false;
        gate.complete(root);
        await expected;
        expect(calls, isEmpty);
        expect(await root.list().length, 1);
      },
    );
    test(
      '$operation rejects metadata and signature-only bytes before native work',
      () async {
        channels();
        final c = pngChunks(roomPng());
        final s = service();
        for (final bytes in [
          Uint8List.fromList(pngSignature),
          pngFromChunks([
            c.first,
            ('tEXt', [1, 2]),
            ...c.skip(1),
          ]),
        ]) {
          await expectLater(
            operation == 'save'
                ? s.savePng(
                    pngBytes: bytes,
                    photoId: 'photo',
                    isCurrent: () => true,
                  )
                : s.sharePng(
                    pngBytes: bytes,
                    photoId: 'photo',
                    origin: origin,
                    title: 'TintAtlas',
                    isCurrent: () => true,
                  ),
            throwsA(isA<RoomExportVerificationException>()),
          );
        }
        expect(calls, isEmpty);
      },
    );
  }
  test(
    'permission completion is checked before any capture or native write',
    () async {
      var current = true;
      final gate = Completer<bool>();
      channels(
        save: (call) async {
          calls.add(call);
          return gate.future;
        },
      );
      final pending = service().prepareSave(isCurrent: () => current);
      final assertion = expectLater(
        pending,
        throwsA(isA<RoomExportInterrupted>()),
      );
      current = false;
      gate.complete(true);
      await assertion;
      expect(calls.map((e) => e.method), ['requestAccess']);
    },
  );
  test(
    'unavailable share is indeterminate, exceptions are typed failures',
    () async {
      channels(
        sharing: (call) async => 'dev.fluttercommunity.plus/share/unavailable',
      );
      expect(
        await service().sharePng(
          pngBytes: roomPng(),
          photoId: '___',
          origin: origin,
          title: 'TintAtlas',
          isCurrent: () => true,
        ),
        RoomShareResult.unavailable,
      );
      channels(
        sharing: (call) async => throw PlatformException(
          code: 'secret',
          message: '/private/photo.jpg',
        ),
      );
      await expectLater(
        service().sharePng(
          pngBytes: roomPng(),
          photoId: 'photo',
          origin: origin,
          title: 'TintAtlas',
          isCurrent: () => true,
        ),
        throwsA(
          isA<RoomShareException>().having(
            (e) => e.toString(),
            'safe',
            isNot(contains('/private')),
          ),
        ),
      );
      expect(await root.list().length, 1);
    },
  );
  test(
    'private filenames never use source separators and share cleanup failure stays neutral',
    () async {
      final names = <String>[];
      channels(
        sharing: (call) async {
          names.add(
            File(
              (call.arguments['paths'] as List).single as String,
            ).uri.pathSegments.last,
          );
          return '';
        },
      );
      final exporter = PlatformRoomImageExportService(
        temporaryRoot: () async => root,
        cleanupOwnedDirectory: (_) async =>
            throw const FileSystemException('cleanup'),
      );
      for (final id in ['___', '../', '__safe__', 'a/b.jpg']) {
        expect(
          await exporter.sharePng(
            pngBytes: roomPng(),
            photoId: id,
            origin: origin,
            title: 'TintAtlas',
            isCurrent: () => true,
          ),
          RoomShareResult.dismissed,
        );
      }
      expect(names, [
        'tintatlas-room-photo.png',
        'tintatlas-room-photo.png',
        'tintatlas-room-safe.png',
        'tintatlas-room-a-b-jpg.png',
      ]);
      expect(await File('${root.path}/keep').readAsString(), 'unowned');
    },
  );

  test('rejects empty anchor and bounds private filename', () async {
    channels(
      sharing: (call) async {
        calls.add(call);
        final path = (call.arguments['paths'] as List).single as String;
        expect(File(path).uri.pathSegments.last.length, 99);
        return '';
      },
    );
    await service().sharePng(
      pngBytes: roomPng(),
      photoId: List.filled(120, 'a').join(),
      origin: origin,
      title: 'TintAtlas',
      isCurrent: () => true,
    );
    await expectLater(
      service().sharePng(
        pngBytes: roomPng(),
        photoId: 'photo',
        origin: Rect.zero,
        title: 'TintAtlas',
        isCurrent: () => true,
      ),
      throwsA(isA<RoomShareException>()),
    );
    expect(calls, hasLength(1));
  });
}
