import 'dart:async';
import 'dart:typed_data';

import 'package:color_lab/features/picker/domain/prepared_photo.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_scheduler.dart';
import 'package:color_lab/features/room_studio/application/room_recolor_service.dart';
import 'package:color_lab/features/room_studio/domain/mask_bitmap.dart';
import 'package:color_lab/features/room_studio/domain/room_layer_colors.dart';
import 'package:color_lab/features/room_studio/recolor/room_recolor_frame.dart';

// Async flushing only: no elapsed-time scheduler assertions.
Future<void> flushRecolor() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.value();
  }
}

RoomRecolorInput recolorInput(
  int revision, {
  String project = 'project',
  String variant = 'a',
  int width = 1,
}) => RoomRecolorInput(
  key: RoomRecolorKey(
    projectId: project,
    photoId: 'photo',
    variantId: variant,
    maskRevision: revision,
    colorRevision: revision,
  ),
  photo: PreparedPhoto(
    width: width,
    height: 1,
    rgbaBytes: Uint8List(width * 4),
    previewBytes: Uint8List(0),
    palette: const [],
  ),
  masks: MaskBitmap(width: width, height: 1, labels: Uint8List(width)),
  colors: const RoomLayerColors(),
);

RoomRecolorFrame recolorFrame(
  RoomRecolorInput input, {
  RoomRecolorKey? key,
  int? width,
}) => RoomRecolorFrame(
  key: key ?? input.key,
  width: width ?? input.photo.width,
  height: input.photo.height,
  rgbaBytes: Uint8List((width ?? input.photo.width) * input.photo.height * 4),
  pngBytes: Uint8List.fromList([1, 2, 3]),
);

class ControlledRender {
  ControlledRender(this.input);
  final RoomRecolorInput input;
  final result = Completer<RoomRecolorFrame>();
  RoomRecolorFrame succeed({RoomRecolorKey? key, int? width}) {
    final frame = recolorFrame(input, key: key, width: width);
    result.complete(frame);
    return frame;
  }

  void fail() => result.completeError(StateError('controlled failure'));
}

class ControlledWorker implements RoomRecolorWorker {
  ControlledWorker({bool ready = true, this.autoExit = true}) {
    if (ready) startup.complete();
  }
  final startup = Completer<void>();
  final exit = Completer<void>();
  final renders = <ControlledRender>[];
  bool autoExit;
  int terminations = 0;
  @override
  Future<void> get ready => startup.future;
  @override
  Future<void> get exited => exit.future;
  @override
  Future<RoomRecolorFrame> render(RoomRecolorInput input) {
    final request = ControlledRender(input);
    renders.add(request);
    return request.result.future;
  }

  @override
  Future<void> terminate() {
    terminations++;
    if (autoExit && !exit.isCompleted) exit.complete();
    return exit.future;
  }
}

class ControlledWorkers {
  final workers = <ControlledWorker>[];
  bool ready = true;
  bool autoExit = true;
  RoomRecolorWorker create() {
    final worker = ControlledWorker(ready: ready, autoExit: autoExit);
    workers.add(worker);
    return worker;
  }

  List<ControlledRender> get renders => [for (final w in workers) ...w.renders];
}

class ManualWatchdog implements RoomRecolorWatchdog {
  ManualWatchdog(this.fireCallback);
  final void Function() fireCallback;
  bool cancelled = false;
  void fire() {
    if (!cancelled) fireCallback();
  }

  @override
  void cancel() => cancelled = true;
}

class ManualWatchdogs {
  final timers = <ManualWatchdog>[];
  RoomRecolorWatchdog create(Duration duration, void Function() fire) {
    final timer = ManualWatchdog(fire);
    timers.add(timer);
    return timer;
  }

  void fire() => timers.lastWhere((t) => !t.cancelled).fire();
}

/// Adapter for widget fixtures that need a controlled or immediate pixel result.
/// Physical isolate cancellation is covered separately by service tests.
class CallbackRecolorWorker implements RoomRecolorWorker {
  CallbackRecolorWorker(this.renderInput);
  final Future<RoomRecolorFrame> Function(RoomRecolorInput) renderInput;
  final _exit = Completer<void>();
  @override
  Future<void> get ready => Future.value();
  @override
  Future<void> get exited => _exit.future;
  @override
  Future<RoomRecolorFrame> render(RoomRecolorInput input) => renderInput(input);
  @override
  Future<void> terminate() {
    if (!_exit.isCompleted) _exit.complete();
    return exited;
  }
}
