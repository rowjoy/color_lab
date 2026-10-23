import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as permission;

import '../../../core/color/color_models.dart';
import '../../../core/utils/camera_sampling.dart';
import '../domain/camera_frame.dart';

enum CameraFailureKind {
  permissionDenied,
  permissionPermanentlyDenied,
  permissionRestricted,
  unavailable,
  unsupportedFormat,
  initialization,
  stream,
}

final class CameraFailure implements Exception {
  const CameraFailure(this.kind);
  final CameraFailureKind kind;
  @override
  String toString() => 'CameraFailure(${kind.name})';
}

abstract interface class CameraSession {
  Future<void> initialize();
  Future<void> start({
    required ValueChanged<RgbColor> onColor,
    required ValueChanged<CameraFailure> onError,
  });
  Future<void> stop();
  Future<void> dispose();
  Future<bool> openSettings();
  Widget buildPreview();
  double get previewAspectRatio;
  void updateSamplePoint({
    required double x,
    required double y,
    required double viewportWidth,
    required double viewportHeight,
  });
}

final cameraSessionFactoryProvider = Provider<CameraSession Function()>(
  (ref) =>
      () => PluginCameraSession(),
);

enum CameraPermission { granted, denied, permanentlyDenied, restricted }

abstract interface class CameraPermissionAccess {
  Future<CameraPermission> request();
  Future<bool> openSettings();
}

/// Native resource boundary; serializing ownership stays in PluginCameraSession.
abstract interface class NativeCameraAccess {
  Future<List<CameraDescription>> available();
  NativeCameraDevice create(CameraDescription description);
}

abstract interface class NativeCameraDevice {
  Future<void> initialize();
  Future<void> lockPortrait();

  /// The snapshot is lazy: bytes are copied only when a sample is admitted.
  Future<void> start({
    required void Function(CameraFrame Function()) onFrame,
    required void Function(Object) onError,
  });
  Future<void> stop();
  Future<void> dispose();
  Widget buildPreview();
  double get previewAspectRatio;
  int get rotationDegrees;
  bool get mirrored;
}

typedef CameraFrameSampler =
    Future<RgbColor> Function(CameraSampleRequest request);

Future<RgbColor> _isolateSample(CameraSampleRequest request) =>
    compute(sampleCameraRequest, request, debugLabel: 'camera-color');

final class PluginCameraSession implements CameraSession {
  PluginCameraSession({
    NativeCameraAccess? platform,
    CameraPermissionAccess? permissions,
    CameraFrameSampler? sampler,
  }) : _platform = platform ?? _PluginCameraAccess(),
       _permissions = permissions ?? _PluginPermissions(),
       _sampler = sampler ?? _isolateSample;

  final NativeCameraAccess _platform;
  final CameraPermissionAccess _permissions;
  final CameraFrameSampler _sampler;
  final _clock = Stopwatch()..start();
  final _gate = CameraSamplingGate();
  final _smoother = CameraColorSmoother();
  Future<void> _operations = Future.value();
  Future<void>? _inFlight;
  Future<void>? _disposing;
  NativeCameraDevice? _device;
  bool _disposed = false;
  bool _active = false;
  bool _nativeStreaming = false;
  int _generation = 0;
  int _pointGeneration = 0;
  double _x = .5, _y = .5, _viewportWidth = 1, _viewportHeight = 1;
  ValueChanged<RgbColor>? _onColor;
  ValueChanged<CameraFailure>? _onError;

  Future<void> _enqueue(Future<void> Function() action) {
    final operation = _operations.then((_) => action());
    _operations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  @override
  Future<void> initialize() => _enqueue(() async {
    if (_disposed || _device != null) return;
    try {
      final status = await _permissions.request();
      if (status != CameraPermission.granted) {
        throw CameraFailure(switch (status) {
          CameraPermission.permanentlyDenied =>
            CameraFailureKind.permissionPermanentlyDenied,
          CameraPermission.restricted => CameraFailureKind.permissionRestricted,
          _ => CameraFailureKind.permissionDenied,
        });
      }
      if (_disposed) return;
      final cameras = await _platform.available();
      if (_disposed) return;
      if (cameras.isEmpty) {
        throw const CameraFailure(CameraFailureKind.unavailable);
      }
      final description = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final device = _platform.create(description);
      _device = device;
      await device.initialize();
      if (_disposed) return;
      await device.lockPortrait();
    } catch (error) {
      await _release();
      final failure = _failure(error, CameraFailureKind.initialization);
      // A system permission dialog can background the route while this request
      // is pending. Preserve its decision even when native allocation canceled.
      if (!_disposed ||
          [
            CameraFailureKind.permissionDenied,
            CameraFailureKind.permissionPermanentlyDenied,
            CameraFailureKind.permissionRestricted,
          ].contains(failure.kind)) {
        throw failure;
      }
    }
  });

  @override
  Future<void> start({
    required ValueChanged<RgbColor> onColor,
    required ValueChanged<CameraFailure> onError,
  }) {
    final generation = ++_generation;
    return _enqueue(() async {
      if (_disposed || generation != _generation) return;
      if (_device == null) {
        throw const CameraFailure(CameraFailureKind.initialization);
      }
      // A prior generation's conversion may finish after stop. Never overlap it.
      await _inFlight;
      if (_disposed || generation != _generation) return;
      if (_nativeStreaming) await _stopNative();
      _gate.reset();
      _smoother.reset();
      _onColor = onColor;
      _onError = onError;
      _active = true;
      final device = _device!;
      try {
        _nativeStreaming = true;
        await device.start(
          onFrame: (snapshot) => _frame(snapshot, generation, device),
          onError: (error) => _streamFailure(
            _failure(error, CameraFailureKind.stream),
            generation,
          ),
        );
      } catch (error) {
        if (_valid(generation)) _invalidate();
        await _stopNative();
        if (!_disposed && generation + 1 == _generation) {
          throw _failure(error, CameraFailureKind.stream);
        }
      }
    });
  }

  bool _valid(int generation) =>
      !_disposed && _active && generation == _generation;

  void _frame(
    CameraFrame Function() snapshot,
    int generation,
    NativeCameraDevice device,
  ) {
    if (!_valid(generation) || !_gate.tryBegin(_clock.elapsed)) return;
    final pointGeneration = _pointGeneration;
    final work = _sample(snapshot, generation, pointGeneration, device);
    _inFlight = work;
    unawaited(
      work.whenComplete(() {
        if (identical(_inFlight, work)) _inFlight = null;
      }),
    );
  }

  Future<void> _sample(
    CameraFrame Function() snapshot,
    int generation,
    int pointGeneration,
    NativeCameraDevice device,
  ) async {
    try {
      final frame = snapshot();
      final request = CameraSampleRequest(
        frame: frame,
        x: _x,
        y: _y,
        viewportWidth: _viewportWidth,
        viewportHeight: _viewportHeight,
        rotationDegrees: device.rotationDegrees,
        mirrored: device.mirrored,
      );
      final color = await _sampler(request);
      if (_valid(generation) && pointGeneration == _pointGeneration) {
        _onColor?.call(_smoother.add(color));
      }
    } catch (error) {
      _streamFailure(
        _failure(
          error,
          error is FormatException
              ? CameraFailureKind.unsupportedFormat
              : CameraFailureKind.stream,
        ),
        generation,
      );
    } finally {
      _gate.complete();
    }
  }

  void _streamFailure(CameraFailure failure, int generation) {
    if (!_valid(generation)) return;
    final callback = _onError;
    _invalidate();
    unawaited(_enqueue(_stopNative));
    callback?.call(failure);
  }

  void _invalidate() {
    _active = false;
    _generation++;
    _onColor = null;
    _onError = null;
    _smoother.reset();
  }

  @override
  Future<void> stop() {
    _invalidate();
    return _enqueue(_stopNative);
  }

  Future<void> _stopNative() async {
    if (!_nativeStreaming) return;
    _nativeStreaming = false;
    try {
      await _device?.stop();
    } catch (_) {
      /* Cleanup still proceeds. */
    }
  }

  Future<void> _release() async {
    await _stopNative();
    final device = _device;
    _device = null;
    try {
      await device?.dispose();
    } catch (_) {
      /* Resource release is best effort. */
    }
  }

  @override
  Future<void> dispose() {
    if (_disposing != null) return _disposing!;
    _disposed = true;
    _invalidate();
    return _disposing = _enqueue(_release);
  }

  @override
  Future<bool> openSettings() => _permissions.openSettings();
  @override
  Widget buildPreview() => _device?.buildPreview() ?? const SizedBox.shrink();
  @override
  double get previewAspectRatio => _device?.previewAspectRatio ?? 3 / 4;

  @override
  void updateSamplePoint({
    required double x,
    required double y,
    required double viewportWidth,
    required double viewportHeight,
  }) {
    if (_disposed ||
        ![x, y, viewportWidth, viewportHeight].every((v) => v.isFinite) ||
        viewportWidth <= 0 ||
        viewportHeight <= 0) {
      return;
    }
    final nextX = x.clamp(0.0, 1.0), nextY = y.clamp(0.0, 1.0);
    if (nextX != _x ||
        nextY != _y ||
        viewportWidth != _viewportWidth ||
        viewportHeight != _viewportHeight) {
      _pointGeneration++;
      _smoother.reset();
    }
    _x = nextX;
    _y = nextY;
    _viewportWidth = viewportWidth;
    _viewportHeight = viewportHeight;
  }
}

CameraFailure _failure(Object error, CameraFailureKind fallback) {
  if (error is CameraFailure) return error;
  if (error is CameraException) {
    return CameraFailure(switch (error.code) {
      'CameraAccessDenied' => CameraFailureKind.permissionDenied,
      'CameraAccessDeniedWithoutPrompt' =>
        CameraFailureKind.permissionPermanentlyDenied,
      'CameraAccessRestricted' => CameraFailureKind.permissionRestricted,
      _ => fallback,
    });
  }
  return CameraFailure(fallback);
}

final class _PluginPermissions implements CameraPermissionAccess {
  @override
  Future<CameraPermission> request() async {
    final status = await permission.Permission.camera.request();
    if (status.isGranted) return CameraPermission.granted;
    if (status.isPermanentlyDenied) return CameraPermission.permanentlyDenied;
    if (status.isRestricted) return CameraPermission.restricted;
    return CameraPermission.denied;
  }

  @override
  Future<bool> openSettings() => permission.openAppSettings();
}

final class _PluginCameraAccess implements NativeCameraAccess {
  @override
  Future<List<CameraDescription>> available() => availableCameras();
  @override
  NativeCameraDevice create(CameraDescription description) =>
      _PluginCameraDevice(description);
}

final class _PluginCameraDevice implements NativeCameraDevice {
  _PluginCameraDevice(this.description)
    : _controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
  final CameraDescription description;
  final CameraController _controller;
  VoidCallback? _listener;

  // CameraX emits unrotated ImageProxy planes. AVFoundation rotates and mirrors
  // captureVideoOutput's CVPixelBuffer before forwarding its bytes to Dart.
  @override
  int get rotationDegrees => defaultTargetPlatform == TargetPlatform.iOS
      ? 0
      : description.sensorOrientation;
  @override
  bool get mirrored =>
      defaultTargetPlatform != TargetPlatform.iOS &&
      description.lensDirection == CameraLensDirection.front;
  @override
  double get previewAspectRatio => 1 / _controller.value.aspectRatio;
  @override
  Widget buildPreview() => CameraPreview(_controller);
  @override
  Future<void> initialize() => _controller.initialize();
  @override
  Future<void> lockPortrait() =>
      _controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
  @override
  Future<void> start({
    required void Function(CameraFrame Function()) onFrame,
    required void Function(Object) onError,
  }) async {
    if (_listener != null) _controller.removeListener(_listener!);
    _listener = () {
      if (_controller.value.hasError) {
        onError(const CameraFailure(CameraFailureKind.stream));
      }
    };
    _controller.addListener(_listener!);
    await _controller.startImageStream(
      (image) => onFrame(() => _snapshot(image)),
    );
  }

  @override
  Future<void> stop() async {
    if (_listener != null) {
      _controller.removeListener(_listener!);
      _listener = null;
    }
    if (_controller.value.isStreamingImages) {
      await _controller.stopImageStream();
    }
  }

  @override
  Future<void> dispose() async {
    if (_listener != null) {
      _controller.removeListener(_listener!);
      _listener = null;
    }
    await _controller.dispose();
  }
}

CameraFrame _snapshot(CameraImage image) {
  final format = switch (image.format.group) {
    ImageFormatGroup.yuv420 => CameraFrameFormat.yuv420,
    ImageFormatGroup.nv21 => CameraFrameFormat.nv21,
    ImageFormatGroup.bgra8888 => CameraFrameFormat.bgra8888,
    _ => CameraFrameFormat.unsupported,
  };
  return CameraFrame(
    width: image.width,
    height: image.height,
    format: format,
    planes: image.planes
        .map(
          (plane) => CameraPlane(
            bytes: plane.bytes,
            bytesPerRow: plane.bytesPerRow,
            bytesPerPixel:
                plane.bytesPerPixel ??
                (format == CameraFrameFormat.bgra8888 ? 4 : 1),
          ),
        )
        .toList(),
  );
}
