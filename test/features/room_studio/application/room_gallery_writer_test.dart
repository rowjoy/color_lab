import 'dart:async';
import 'dart:io';

import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'prepared Gallery terminal seam rechecks after file work and maps native capacity',
    () async {
      final root = await Directory.systemTemp.createTemp('terminal-gallery-');
      addTearDown(() => root.delete(recursive: true));
      const channel = MethodChannel('gal');
      var writes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            writes++;
            throw PlatformException(
              code: 'NOT_ENOUGH_SPACE',
              message: '/private/source',
            );
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final writer = GalRoomGalleryWriter(
        platform: TargetPlatform.android,
        isWeb: false,
        temporaryRoot: () async => root,
      );
      await expectLater(
        writer.savePreparedPng(
          pngBytes: _png(),
          fileName: 'tintatlas-room-photo.png',
          beforeHandoff: () => false,
        ),
        throwsA(isA<RoomExportInterrupted>()),
      );
      expect(writes, 0);
      await expectLater(
        writer.savePreparedPng(
          pngBytes: _png(),
          fileName: 'tintatlas-room-photo.png',
          beforeHandoff: () => true,
        ),
        _failsWith(RoomGalleryFailure.notEnoughSpace),
      );
      expect(writes, 1);
      expect(await root.list().length, 0);
    },
  );
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('room-gallery-writer-test-');
    await File(
      '${root.path}${Platform.pathSeparator}keep.txt',
    ).writeAsString('not owned by the writer');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'validates PNG signature and safe lowercase .png filename first',
    () async {
      var platformCalls = 0;
      var tempCalls = 0;
      final writer = GalRoomGalleryWriter(
        platform: TargetPlatform.android,
        isWeb: false,
        temporaryRoot: () async {
          tempCalls++;
          return root;
        },
        putImage: (path, {album}) async => platformCalls++,
      );

      for (final bytes in <Uint8List>[
        Uint8List(0),
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26]),
        Uint8List.fromList([0, 80, 78, 71, 13, 10, 26, 10]),
      ]) {
        await expectLater(
          writer.savePng(pngBytes: bytes, fileName: 'room.png'),
          _failsWith(RoomGalleryFailure.unsupportedFormat),
        );
      }
      for (final name in [
        '',
        '.png',
        '../room.png',
        'folder/room.png',
        r'folder\room.png',
        'room.jpg',
        'room.PNG',
        'room name.png',
        'room.png.tmp',
        'room.png\n',
        '${List.filled(241, 'a').join()}.png',
      ]) {
        await expectLater(
          writer.savePng(pngBytes: _png(), fileName: name),
          _failsWith(RoomGalleryFailure.unsupportedFormat),
        );
      }

      expect(platformCalls, 0);
      expect(tempCalls, 0);
      expect(await root.list().length, 1);
    },
  );

  test(
    'copies bytes and exposes exact owned filename only during callback',
    () async {
      final input = _png(extra: [1, 2, 3, 4]);
      final expected = Uint8List.fromList(input);
      final entered = Completer<void>();
      final release = Completer<void>();
      String? callbackPath;
      String? callbackAlbum;
      Uint8List? callbackBytes;
      Directory? ownedDirectory;
      final writer = GalRoomGalleryWriter(
        platform: TargetPlatform.iOS,
        isWeb: false,
        temporaryRoot: () async => root,
        putImage: (path, {album}) async {
          callbackPath = path;
          callbackAlbum = album;
          final file = File(path);
          ownedDirectory = file.parent;
          expect(await file.exists(), isTrue);
          callbackBytes = await file.readAsBytes();
          entered.complete();
          await release.future;
        },
      );

      final saving = writer.savePng(
        pngBytes: input,
        fileName: 'color-lab-study-20261025T040000Z.png',
      );
      input.fillRange(0, input.length, 0);
      await entered.future;

      expect(callbackAlbum, isNull, reason: 'No custom album may be requested');
      expect(
        File(callbackPath!).uri.pathSegments.last,
        'color-lab-study-20261025T040000Z.png',
      );
      expect(callbackBytes, expected);
      expect(ownedDirectory, isNotNull);
      expect(await ownedDirectory!.exists(), isTrue);

      release.complete();
      await saving;
      expect(await File(callbackPath!).exists(), isFalse);
      expect(await ownedDirectory!.exists(), isFalse);
      expect(
        await File(
          '${root.path}${Platform.pathSeparator}keep.txt',
        ).readAsString(),
        'not owned by the writer',
      );
    },
  );

  test('maps every GalException type and cleans its owned directory', () async {
    const expected = {
      GalExceptionType.accessDenied: RoomGalleryFailure.accessDenied,
      GalExceptionType.notEnoughSpace: RoomGalleryFailure.notEnoughSpace,
      GalExceptionType.notSupportedFormat: RoomGalleryFailure.unsupportedFormat,
      GalExceptionType.unexpected: RoomGalleryFailure.unexpected,
    };

    for (final entry in expected.entries) {
      Directory? ownedDirectory;
      final writer = GalRoomGalleryWriter(
        platform: TargetPlatform.android,
        isWeb: false,
        temporaryRoot: () async => root,
        putImage: (path, {album}) async {
          ownedDirectory = File(path).parent;
          throw GalException(
            type: entry.key,
            platformException: PlatformException(code: entry.key.code),
            stackTrace: StackTrace.current,
          );
        },
      );
      await expectLater(
        writer.savePng(
          pngBytes: _png(),
          fileName: 'mapped-${entry.key.name}.png',
        ),
        _failsWith(entry.value),
      );
      expect(ownedDirectory, isNotNull);
      expect(await ownedDirectory!.exists(), isFalse);
    }
  });

  test(
    'maps missing plugin and unexpected failures and always cleans up',
    () async {
      for (final error in <Object>[
        MissingPluginException('Gallery plugin is unavailable'),
        StateError('private platform detail'),
      ]) {
        Directory? ownedDirectory;
        final writer = GalRoomGalleryWriter(
          platform: TargetPlatform.android,
          isWeb: false,
          temporaryRoot: () async => root,
          putImage: (path, {album}) async {
            ownedDirectory = File(path).parent;
            throw error;
          },
        );
        await expectLater(
          writer.savePng(
            pngBytes: _png(),
            fileName: 'failure-${error.runtimeType}.png',
          ),
          _failsWith(
            error is MissingPluginException
                ? RoomGalleryFailure.unsupportedPlatform
                : RoomGalleryFailure.unexpected,
          ),
        );
        expect(ownedDirectory, isNotNull);
        expect(await ownedDirectory!.exists(), isFalse);
      }
    },
  );

  test(
    'successful Gallery write stays successful when temp cleanup fails',
    () async {
      var platformCalls = 0;
      var cleanupCalls = 0;
      Directory? ownedDirectory;
      final writer = GalRoomGalleryWriter(
        platform: TargetPlatform.android,
        isWeb: false,
        temporaryRoot: () async => root,
        cleanupOwnedDirectory: (directory) async {
          cleanupCalls++;
          ownedDirectory = directory;
          throw const FileSystemException('injected cleanup failure');
        },
        putImage: (path, {album}) async => platformCalls++,
      );

      await writer.savePng(pngBytes: _png(), fileName: 'saved-once.png');

      expect(platformCalls, 1);
      expect(cleanupCalls, 1);
      expect(ownedDirectory, isNotNull);
      expect(await ownedDirectory!.exists(), isTrue);
    },
  );

  test('rejects unsupported platforms before temp or plugin access', () async {
    var tempCalls = 0;
    var platformCalls = 0;
    final writer = GalRoomGalleryWriter(
      platform: TargetPlatform.linux,
      isWeb: false,
      temporaryRoot: () async {
        tempCalls++;
        return root;
      },
      putImage: (path, {album}) async => platformCalls++,
    );

    await expectLater(
      writer.savePng(pngBytes: _png(), fileName: 'room.png'),
      _failsWith(RoomGalleryFailure.unsupportedPlatform),
    );
    expect(tempCalls, 0);
    expect(platformCalls, 0);

    final webWriter = GalRoomGalleryWriter(
      platform: TargetPlatform.android,
      isWeb: true,
      temporaryRoot: () async => root,
      putImage: (path, {album}) async => platformCalls++,
    );
    await expectLater(
      webWriter.savePng(pngBytes: _png(), fileName: 'room.png'),
      _failsWith(RoomGalleryFailure.unsupportedPlatform),
    );
    expect(platformCalls, 0);
  });

  test('providers expose injectable writer and Settings callback', () async {
    var settingsCalls = 0;
    final container = ProviderContainer(
      overrides: [
        roomGallerySettingsProvider.overrideWithValue(() async {
          settingsCalls++;
          return true;
        }),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(roomGalleryWriterProvider), isA<RoomGalleryWriter>());
    expect(await container.read(roomGallerySettingsProvider)(), isTrue);
    expect(settingsCalls, 1);
  });
}

Matcher _failsWith(RoomGalleryFailure failure) => throwsA(
  isA<RoomGalleryWriteException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

Uint8List _png({List<int> extra = const []}) =>
    Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, ...extra]);
