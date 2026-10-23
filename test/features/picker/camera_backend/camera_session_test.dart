import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/picker/application/camera_session.dart';
import 'package:color_lab/features/picker/domain/camera_frame.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const rear = CameraDescription(
  name: 'rear',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);
const front = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 270,
);

final class Permissions implements CameraPermissionAccess {
  CameraPermission permission = CameraPermission.granted;
  Completer<CameraPermission>? pending;
  @override
  Future<CameraPermission> request() async =>
      pending == null ? permission : pending!.future;
  @override
  Future<bool> openSettings() async => true;
}

final class Platform implements NativeCameraAccess {
  final device = Device();
  List<CameraDescription> cameras = [front, rear];
  CameraDescription? selected;
  @override
  Future<List<CameraDescription>> available() async => cameras;
  @override
  NativeCameraDevice create(CameraDescription description) {
    selected = description;
    return device;
  }
}

final class Device implements NativeCameraDevice {
  Completer<void>? initializing;
  Completer<void>? starting;
  Object? initializationError;
  Object? startError;
  void Function(CameraFrame Function())? frame;
  void Function(Object)? error;
  final events = <String>[];
  @override
  int get rotationDegrees => 90;
  @override
  bool get mirrored => false;
  @override
  double get previewAspectRatio => .75;
  @override
  Widget buildPreview() => const SizedBox();
  @override
  Future<void> initialize() async {
    events.add('initialize');
    await initializing?.future;
    if (initializationError != null) throw initializationError!;
  }

  @override
  Future<void> lockPortrait() async {
    events.add('portrait');
  }

  @override
  Future<void> start({
    required void Function(CameraFrame Function()) onFrame,
    required void Function(Object) onError,
  }) async {
    events.add('start');
    frame = onFrame;
    error = onError;
    await starting?.future;
    if (startError != null) throw startError!;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
  }

  void emit() => frame?.call(
    () => CameraFrame(
      width: 1,
      height: 1,
      format: CameraFrameFormat.bgra8888,
      planes: [
        CameraPlane(
          bytes: Uint8List.fromList([0, 0, 255, 255]),
          bytesPerRow: 4,
          bytesPerPixel: 4,
        ),
      ],
    ),
  );
}

void main() {
  test(
    'disposal during pending permission grant never allocates a background camera',
    () async {
      final permissions = Permissions()
        ..pending = Completer<CameraPermission>();
      final platform = Platform();
      final session = PluginCameraSession(
        platform: platform,
        permissions: permissions,
      );
      final initialize = session.initialize();
      await Future<void>.delayed(Duration.zero);
      final disposing = session.dispose();
      permissions.pending!.complete(CameraPermission.granted);
      await initialize;
      await disposing;
      expect(platform.selected, isNull);
      expect(platform.device.events, isEmpty);
    },
  );

  test(
    'disposal during pending permission preserves denial and allocates no native device',
    () async {
      final permissions = Permissions()
        ..pending = Completer<CameraPermission>();
      final platform = Platform();
      final session = PluginCameraSession(
        platform: platform,
        permissions: permissions,
      );
      final initialize = session.initialize();
      await Future<void>.delayed(Duration.zero);
      final disposing = session.dispose();
      final denied = expectLater(
        initialize,
        throwsA(
          isA<CameraFailure>().having(
            (e) => e.kind,
            'kind',
            CameraFailureKind.permissionDenied,
          ),
        ),
      );
      permissions.pending!.complete(CameraPermission.denied);
      await denied;
      await disposing;
      expect(platform.selected, isNull);
      expect(platform.device.events, isEmpty);
    },
  );

  test(
    'typed permission failures and unavailable camera do not create a device',
    () async {
      for (final (permission, kind) in [
        (CameraPermission.denied, CameraFailureKind.permissionDenied),
        (
          CameraPermission.permanentlyDenied,
          CameraFailureKind.permissionPermanentlyDenied,
        ),
        (CameraPermission.restricted, CameraFailureKind.permissionRestricted),
      ]) {
        final platform = Platform(),
            permissions = Permissions()..permission = permission;
        final session = PluginCameraSession(
          platform: platform,
          permissions: permissions,
        );
        await expectLater(
          session.initialize(),
          throwsA(isA<CameraFailure>().having((e) => e.kind, 'kind', kind)),
        );
        expect(platform.selected, isNull);
        await session.dispose();
      }
      final session = PluginCameraSession(
        platform: Platform()..cameras = [],
        permissions: Permissions(),
      );
      await expectLater(
        session.initialize(),
        throwsA(
          isA<CameraFailure>().having(
            (e) => e.kind,
            'kind',
            CameraFailureKind.unavailable,
          ),
        ),
      );
      await session.dispose();
    },
  );

  test(
    'rear selection initializes portrait before delivering actual worker color',
    () async {
      final platform = Platform();
      final session = PluginCameraSession(
        platform: platform,
        permissions: Permissions(),
      );
      final colors = <RgbColor>[], errors = <CameraFailure>[];
      final firstColor = Completer<RgbColor>();
      await session.initialize();
      await session.start(
        onColor: (color) {
          colors.add(color);
          if (!firstColor.isCompleted) firstColor.complete(color);
        },
        onError: errors.add,
      );
      platform.device.emit();
      await firstColor.future.timeout(const Duration(seconds: 5));
      expect(platform.selected, rear);
      expect(platform.device.events.take(3), [
        'initialize',
        'portrait',
        'start',
      ]);
      expect(colors, [RgbColor(255, 0, 0)]);
      expect(errors, isEmpty);
      await session.dispose();
    },
  );

  test(
    'dispose waits for initialization and releases device exactly once',
    () async {
      final platform = Platform();
      platform.device.initializing = Completer<void>();
      final session = PluginCameraSession(
        platform: platform,
        permissions: Permissions(),
      );
      final initialize = session.initialize();
      await Future<void>.delayed(Duration.zero);
      final dispose = session.dispose();
      platform.device.initializing!.complete();
      await initialize;
      await dispose;
      await session.dispose();
      expect(platform.device.events, ['initialize', 'dispose']);
      await session.initialize();
      expect(platform.device.events, ['initialize', 'dispose']);
    },
  );

  test(
    'stop immediately invalidates in-flight sample and suppresses native late errors',
    () async {
      final platform = Platform(), sample = Completer<RgbColor>();
      var calls = 0;
      final session = PluginCameraSession(
        platform: platform,
        permissions: Permissions(),
        sampler: (request) {
          calls++;
          return sample.future;
        },
      );
      final colors = <RgbColor>[], errors = <CameraFailure>[];
      await session.initialize();
      await session.start(onColor: colors.add, onError: errors.add);
      platform.device.emit();
      platform.device.emit();
      expect(calls, 1);
      await session.stop();
      sample.complete(RgbColor(255, 0, 0));
      platform.device.error!(StateError('late'));
      await Future<void>.delayed(Duration.zero);
      expect(colors, isEmpty);
      expect(errors, isEmpty);
      await session.dispose();
      expect(
        platform.device.events.where((event) => event == 'stop').length,
        1,
      );
    },
  );

  test(
    'serialized cleanup handles stop and dispose during a pending native start',
    () async {
      final platform = Platform();
      platform.device.starting = Completer<void>();
      final session = PluginCameraSession(
        platform: platform,
        permissions: Permissions(),
      );
      final colors = <RgbColor>[];
      await session.initialize();
      final starting = session.start(onColor: colors.add, onError: (_) {});
      await Future<void>.delayed(Duration.zero);
      final stopping = session.stop();
      final disposing = session.dispose();
      platform.device.starting!.complete();
      await starting;
      await stopping;
      await disposing;
      platform.device.emit();
      await Future<void>.delayed(Duration.zero);
      expect(colors, isEmpty);
      expect(platform.device.events, [
        'initialize',
        'portrait',
        'start',
        'stop',
        'dispose',
      ]);
    },
  );

  test(
    'unsupported frame maps to typed failure once and ends its stream',
    () async {
      final platform = Platform();
      final session = PluginCameraSession(
        platform: platform,
        permissions: Permissions(),
        sampler: (_) async =>
            throw const FormatException('private native detail'),
      );
      final errors = <CameraFailure>[];
      await session.initialize();
      await session.start(onColor: (_) {}, onError: errors.add);
      platform.device.emit();
      await Future<void>.delayed(Duration.zero);
      expect(errors.single.kind, CameraFailureKind.unsupportedFormat);
      platform.device.emit();
      await Future<void>.delayed(Duration.zero);
      expect(errors.length, 1);
      await session.dispose();
    },
  );

  test(
    'reticle movement discards old point results and resets smoothing',
    () async {
      final platform = Platform(), oldPoint = Completer<RgbColor>();
      var calls = 0;
      CameraSampleRequest? latest;
      final session = PluginCameraSession(
        platform: platform,
        permissions: Permissions(),
        sampler: (request) {
          latest = request;
          return calls++ == 0
              ? oldPoint.future
              : Future.value(RgbColor(0, 0, 255));
        },
      );
      final colors = <RgbColor>[];
      await session.initialize();
      await session.start(onColor: colors.add, onError: (_) {});
      platform.device.emit();
      session.updateSamplePoint(
        x: .25,
        y: .75,
        viewportWidth: 360,
        viewportHeight: 720,
      );
      oldPoint.complete(RgbColor(255, 0, 0));
      await Future<void>.delayed(const Duration(milliseconds: 70));
      platform.device.emit();
      await Future<void>.delayed(Duration.zero);
      expect(colors, [RgbColor(0, 0, 255)]);
      expect(
        (latest!.x, latest!.y, latest!.viewportWidth, latest!.viewportHeight),
        (.25, .75, 360, 720),
      );
      await session.dispose();
    },
  );

  test(
    'restart waits for previous conversion and preserves one worker globally',
    () async {
      final platform = Platform(), previous = Completer<RgbColor>();
      var calls = 0;
      final session = PluginCameraSession(
        platform: platform,
        permissions: Permissions(),
        sampler: (_) =>
            calls++ == 0 ? previous.future : Future.value(RgbColor(0, 255, 0)),
      );
      final colors = <RgbColor>[];
      await session.initialize();
      await session.start(onColor: colors.add, onError: (_) {});
      platform.device.emit();
      await session.stop();
      final restart = session.start(onColor: colors.add, onError: (_) {});
      await Future<void>.delayed(Duration.zero);
      platform.device.emit();
      expect(calls, 1);
      previous.complete(RgbColor(255, 0, 0));
      await restart;
      platform.device.emit();
      await Future<void>.delayed(Duration.zero);
      expect(colors, [RgbColor(0, 255, 0)]);
      await session.dispose();
    },
  );

  test(
    'native initialize failures release the resource and preserve safe type',
    () async {
      for (final (error, kind) in [
        (StateError('sensitive diagnostic'), CameraFailureKind.initialization),
        (
          CameraException('CameraAccessRestricted', 'platform detail'),
          CameraFailureKind.permissionRestricted,
        ),
      ]) {
        final platform = Platform();
        platform.device.initializationError = error;
        final session = PluginCameraSession(
          platform: platform,
          permissions: Permissions(),
        );
        await expectLater(
          session.initialize(),
          throwsA(isA<CameraFailure>().having((e) => e.kind, 'kind', kind)),
        );
        await session.dispose();
        expect(platform.device.events, ['initialize', 'dispose']);
      }
    },
  );

  test(
    'failed native start stops partial stream and maps a friendly failure',
    () async {
      final platform = Platform();
      platform.device.startError = StateError('private');
      final session = PluginCameraSession(
        platform: platform,
        permissions: Permissions(),
      );
      await session.initialize();
      await expectLater(
        session.start(onColor: (_) {}, onError: (_) {}),
        throwsA(
          isA<CameraFailure>().having(
            (e) => e.kind,
            'kind',
            CameraFailureKind.stream,
          ),
        ),
      );
      await session.dispose();
      expect(platform.device.events, [
        'initialize',
        'portrait',
        'start',
        'stop',
        'dispose',
      ]);
    },
  );
}
