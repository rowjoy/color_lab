import 'package:color_lab/core/image/photo_processing.dart';
import 'package:color_lab/features/picker/application/photo_picker_service.dart';
import 'package:color_lab/features/picker/application/photo_processor.dart';
import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

class Picker extends ImagePicker {
  XFile? file;
  PlatformException? error;
  LostDataResponse lost = LostDataResponse.empty();
  int recoveries = 0;
  ImageSource expectedSource = ImageSource.gallery;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    // Reject requests which could ask for broad metadata permission or send an
    // unbounded image to the worker. The output below remains real image data.
    if (source != expectedSource ||
        maxWidth != 2048 ||
        maxHeight != 2048 ||
        requestFullMetadata) {
      throw StateError('Unsafe picker options');
    }
    if (error != null) throw error!;
    return file;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    recoveries++;
    return lost;
  }
}

class InlineProcessor implements PhotoProcessor {
  @override
  Future<PreparedPhoto> prepare(Uint8List bytes) async => preparePhoto(bytes);
}

class LargeFile extends XFile {
  LargeFile() : super('unused');
  @override
  Future<int> length() async => 25 * 1024 * 1024;
  @override
  Future<Uint8List> readAsBytes() => throw StateError('Must check size first');
}

void main() {
  PluginPhotoPickerService service(
    Picker picker, [
    TargetPlatform platform = TargetPlatform.android,
  ]) => PluginPhotoPickerService(
    picker: picker,
    processor: InlineProcessor(),
    platform: platform,
  );

  test(
    'camera preserves bounded native options and processes selected image',
    () async {
      final picker = Picker()..expectedSource = ImageSource.camera;
      final image = img.Image(width: 1, height: 1)..setPixelRgb(0, 0, 3, 6, 9);
      picker.file = XFile.fromData(Uint8List.fromList(img.encodePng(image)));
      expect(
        (await service(
          picker,
        ).pick(source: PhotoSource.camera))?.sample(0, 0).hex,
        '#030609',
      );
    },
  );

  test(
    'cancellation returns null and selected bytes are truly processed',
    () async {
      final picker = Picker();
      expect(await service(picker).pick(), isNull);
      final image = img.Image(width: 2, height: 1)
        ..setPixelRgb(0, 0, 255, 0, 0)
        ..setPixelRgb(1, 0, 0, 0, 255);
      picker.file = XFile.fromData(Uint8List.fromList(img.encodePng(image)));
      final photo = (await service(picker).pick())!;
      expect(photo.sample(.1, .5).hex, '#FF0000');
      expect(photo.sample(.8, .5).hex, '#0000FF');
    },
  );

  test(
    'permission, corrupt image, and size errors expose safe categories',
    () async {
      final picker = Picker()
        ..error = PlatformException(
          code: 'photo_access_denied',
          message: 'sensitive platform text',
        );
      expect(
        service(picker).pick(),
        throwsA(
          isA<PhotoPickFailure>().having(
            (e) => e.kind,
            'kind',
            PhotoPickFailureKind.permissionDenied,
          ),
        ),
      );
      picker.error = null;
      picker.file = XFile.fromData(Uint8List.fromList([1, 2, 3]));
      await expectLater(
        service(picker).pick(),
        throwsA(
          isA<PhotoPickFailure>().having(
            (e) => e.kind,
            'kind',
            PhotoPickFailureKind.invalidImage,
          ),
        ),
      );
      picker.file = LargeFile();
      await expectLater(
        service(picker).pick(),
        throwsA(
          isA<PhotoPickFailure>().having(
            (e) => e.kind,
            'kind',
            PhotoPickFailureKind.tooLarge,
          ),
        ),
      );
    },
  );

  test(
    'Android recovers real lost image and other platforms never call plugin',
    () async {
      final image = img.Image(width: 1, height: 1)
        ..setPixelRgb(0, 0, 12, 34, 56);
      final picker = Picker()
        ..lost = LostDataResponse(
          files: [XFile.fromData(Uint8List.fromList(img.encodePng(image)))],
          type: RetrieveType.image,
        );
      expect(await service(picker, TargetPlatform.iOS).recoverLost(), isNull);
      expect(picker.recoveries, 0);
      expect(
        (await service(picker).recoverLost())!.sample(0, 0).hex,
        '#0C2238',
      );
      picker.lost = LostDataResponse(
        exception: PlatformException(code: 'photo_access_denied'),
      );
      await expectLater(
        service(picker).recoverLost(),
        throwsA(
          isA<PhotoPickFailure>().having(
            (e) => e.kind,
            'kind',
            PhotoPickFailureKind.permissionDenied,
          ),
        ),
      );
    },
  );

  test('Android accepts the single-file lost data response', () async {
    final image = img.Image(width: 1, height: 1)..setPixelRgb(0, 0, 10, 20, 30);
    final picker = Picker()
      ..lost = LostDataResponse(
        file: XFile.fromData(Uint8List.fromList(img.encodePng(image))),
        type: RetrieveType.image,
      );
    expect((await service(picker).recoverLost())?.sample(0, 0).hex, '#0A141E');
  });

  test(
    'settings failures are recoverable and acquisition errors stay private',
    () async {
      final picker = Picker()
        ..error = PlatformException(
          code: 'already_active',
          message: 'private path',
        );
      await expectLater(
        service(picker).pick(),
        throwsA(
          isA<PhotoPickFailure>()
              .having((e) => e.kind, 'kind', PhotoPickFailureKind.unavailable)
              .having(
                (e) => e.toString(),
                'safe description',
                isNot(contains('private path')),
              ),
        ),
      );
      final failedSettings = PluginPhotoPickerService(
        picker: picker,
        processor: InlineProcessor(),
        settings: () async => throw PlatformException(code: 'not_available'),
      );
      expect(await failedSettings.openSettings(), false);
    },
  );
}
