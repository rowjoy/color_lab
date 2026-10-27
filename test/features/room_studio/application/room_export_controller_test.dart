import 'dart:async';
import 'dart:typed_data';
import 'package:color_lab/features/room_studio/application/room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/features/room_studio/application/room_project_session_controller.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/room_export_fixtures.dart';

class Exporter implements RoomImageExportService {
  Completer<void>? permission, preparation, handoff;
  int calls = 0, permissions = 0;
  Uint8List? bytes;
  Object? error;
  @override
  Future<void> prepareSave({required bool Function() isCurrent}) async {
    permissions++;
    await permission?.future;
    if (!isCurrent()) throw const RoomExportInterrupted();
  }

  Future<void> send(
    Uint8List png,
    bool Function() guard,
    void Function()? onHandoff,
  ) async {
    await preparation?.future;
    if (!guard()) throw const RoomExportInterrupted();
    onHandoff?.call();
    calls++;
    bytes = png;
    await handoff?.future;
    if (error != null) throw error!;
  }

  @override
  Future<void> savePng({
    required Uint8List pngBytes,
    required String photoId,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) => send(pngBytes, isCurrent, onHandoff);
  @override
  Future<RoomShareResult> sharePng({
    required Uint8List pngBytes,
    required String photoId,
    required Rect origin,
    required String title,
    required bool Function() isCurrent,
    void Function()? onHandoff,
  }) async {
    await send(pngBytes, isCurrent, onHandoff);
    return RoomShareResult.dismissed;
  }
}

void main() {
  const origin = Rect.fromLTWH(0, 0, 48, 48);
  for (final action in RoomExportAction.values) {
    for (final change in [
      'project',
      'photo',
      'mask',
      'color',
      'variant',
      'dimensions',
      'lifetime',
      'owner',
      'route',
      'loading',
      'dispose',
      'background',
    ]) {
      test('$action rejects stale $change after async preparation', () async {
        final lifetime = Object(), owner = Object();
        var current = source(lifetime: lifetime, owner: owner);
        final original = current.session;
        final service = Exporter()..preparation = Completer<void>();
        final controller = RoomExportController(
          service: service,
          readSource: () => current,
        );
        final pending = controller.export(
          action,
          origin: origin,
          title: 'TintAtlas',
        );
        await Future<void>.delayed(Duration.zero);
        expect(controller.busy, isTrue);
        expect(current.frame!.retainedByteCount, greaterThan(0));
        current.frame!.dispose(); // No export lease keeps RGBA alive.
        expect(current.frame!.retainedByteCount, 0);
        if (change == 'dispose') {
          controller.dispose();
        } else if (change == 'background') {
          controller.revoke();
        } else {
          current = source(
            lifetime: change == 'lifetime' ? Object() : lifetime,
            owner: change == 'owner' ? Object() : owner,
            project: change == 'project' ? 'other' : 'project',
            photoId: change == 'photo' ? 'other' : 'photo',
            mask: change == 'mask' ? 1 : 0,
            color: change == 'color' ? 1 : 0,
            variant: change == 'variant' ? 'b' : 'a',
            width: change == 'dimensions' ? 3 : 2,
            eligible: change != 'route',
            ready: change != 'loading',
          );
        }
        service.preparation!.complete();
        await pending;
        expect(service.calls, 0);
        expect(original.saveStatus, RoomProjectSaveStatus.failed);
        if (change != 'dispose') controller.dispose();
        current.frame!.dispose();
      });
    }
  }
  test(
    'native sheet lifecycle after handoff preserves its eventual neutral result',
    () async {
      final lifetime = Object(), owner = Object();
      var current = source(lifetime: lifetime, owner: owner);
      final exporter = Exporter()..handoff = Completer<void>();
      final controller = RoomExportController(
        service: exporter,
        readSource: () => current,
      );
      final pending = controller.export(
        RoomExportAction.share,
        origin: origin,
        title: 'TintAtlas',
      );
      await Future<void>.delayed(Duration.zero);
      expect(exporter.calls, 1);
      current = source(
        lifetime: lifetime,
        owner: owner,
        eligible: false,
        ready: false,
      );
      controller.revoke(beforeHandoffOnly: true);
      expect(controller.busy, isTrue);
      exporter.handoff!.complete();
      await pending;
      current = source(lifetime: lifetime, owner: owner);
      expect(controller.notice, RoomExportNotice.dismissed);
      expect(controller.failure, isNull);
      controller.dispose();
      current.frame!.dispose();
    },
  );
  test(
    'a widget lease cannot make an owner-released preview exportable',
    () async {
      final current = source(lifetime: Object(), owner: Object());
      final lease = current.frame!.lease();
      current.frame!.dispose();
      expect(current.frame!.isDisposed, isFalse);
      final exporter = Exporter();
      final controller = RoomExportController(
        service: exporter,
        readSource: () => current,
      );
      await controller.export(
        RoomExportAction.share,
        origin: origin,
        title: 'TintAtlas',
      );
      expect(exporter.calls, 0);
      controller.dispose();
      lease.dispose();
    },
  );
  test(
    'one synchronous guard covers repeated Save and Share, detached bytes survive release',
    () async {
      final current = source(lifetime: Object(), owner: Object());
      final exporter = Exporter()..preparation = Completer<void>();
      final controller = RoomExportController(
        service: exporter,
        readSource: () => current,
      );
      final first = controller.export(
        RoomExportAction.share,
        origin: origin,
        title: 'TintAtlas',
      );
      final duplicate = controller.export(
        RoomExportAction.save,
        origin: origin,
        title: 'TintAtlas',
      );
      expect(controller.busy, isTrue);
      await duplicate;
      exporter.preparation!.complete();
      await first;
      expect(exporter.calls, 1);
      expect(exporter.permissions, 0);
      expect(exporter.bytes, current.frame!.pngBytes);
      expect(() => exporter.bytes![0] = 0, throwsUnsupportedError);
      expect(current.session.hasUnsavedChanges, isTrue);
      controller.dispose();
      current.frame!.dispose();
    },
  );
  test(
    'stale error cannot clear a newer operation or publish on replacement',
    () async {
      var current = source(lifetime: Object(), owner: Object());
      final exporter = Exporter()..handoff = Completer<void>();
      final controller = RoomExportController(
        service: exporter,
        readSource: () => current,
      );
      final old = controller.export(
        RoomExportAction.share,
        origin: origin,
        title: 'TintAtlas',
      );
      await Future<void>.delayed(Duration.zero);
      current = source(lifetime: Object(), owner: Object(), project: 'other');
      controller.revoke();
      final gate = exporter.handoff!;
      exporter.handoff = Completer<void>();
      final newer = controller.export(
        RoomExportAction.share,
        origin: origin,
        title: 'TintAtlas',
      );
      await Future<void>.delayed(Duration.zero);
      exporter.error = StateError('/private/path');
      gate.complete();
      await old;
      expect(controller.busy, isTrue);
      expect(controller.failure, isNull);
      exporter.error = null;
      exporter.handoff!.complete();
      await newer;
      controller.dispose();
      current.frame!.dispose();
    },
  );
  test(
    'save permission invalidation settles without capturing released preview',
    () async {
      var current = source(lifetime: Object(), owner: Object());
      final exporter = Exporter()..permission = Completer<void>();
      final controller = RoomExportController(
        service: exporter,
        readSource: () => current,
      );
      final pending = controller.export(
        RoomExportAction.save,
        origin: origin,
        title: 'TintAtlas',
      );
      current.frame!.dispose();
      controller.revoke();
      exporter.permission!.complete();
      await pending;
      expect(exporter.calls, 0);
      expect(controller.busy, isFalse);
      controller.dispose();
    },
  );
}
