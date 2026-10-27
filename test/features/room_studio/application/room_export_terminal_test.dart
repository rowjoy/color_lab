import 'dart:async';
import 'dart:io';
import 'package:color_lab/features/room_studio/application/room_export_controller.dart';
import 'package:color_lab/features/room_studio/application/room_image_export_service.dart';
import 'package:color_lab/features/room_studio/application/room_gallery_writer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../support/room_export_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const gallery = MethodChannel('gal'),
      share = MethodChannel('dev.fluttercommunity.plus/share');
  const origin = Rect.fromLTWH(0, 0, 48, 48);
  for (final stage in ['save permission', 'save temp', 'share temp']) {
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
      'released',
    ]) {
      test(
        '$stage prevents real terminal channel call after $change changes',
        () async {
          final root = await Directory.systemTemp.createTemp('room-terminal-');
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          addTearDown(() async {
            messenger.setMockMethodCallHandler(gallery, null);
            messenger.setMockMethodCallHandler(share, null);
            await root.delete(recursive: true);
          });
          final entered = Completer<void>(),
              permission = Completer<bool>(),
              temp = Completer<Directory>();
          var writes = 0;
          messenger.setMockMethodCallHandler(gallery, (call) async {
            if (call.method == 'requestAccess') {
              if (stage == 'save permission') {
                entered.complete();
                return permission.future;
              }
              return true;
            }
            writes++;
            return null;
          });
          messenger.setMockMethodCallHandler(share, (call) async {
            writes++;
            return '';
          });
          Future<Directory> temporary() {
            if (!entered.isCompleted) entered.complete();
            return temp.future;
          }

          final service = PlatformRoomImageExportService(
            gallery: GalRoomGalleryWriter(
              platform: TargetPlatform.android,
              isWeb: false,
              temporaryRoot: temporary,
            ),
            temporaryRoot: temporary,
          );
          final lifetime = Object(), owner = Object();
          var current = source(lifetime: lifetime, owner: owner);
          final controller = RoomExportController(
            service: service,
            readSource: () => current,
          );
          final pending = controller.export(
            stage.startsWith('save')
                ? RoomExportAction.save
                : RoomExportAction.share,
            origin: origin,
            title: 'TintAtlas',
          );
          await entered.future;
          final lease = current.frame!.lease();
          current.frame!.dispose();
          if (change == 'dispose') {
            controller.dispose();
          } else if (change == 'background') {
            controller.revoke();
          } else if (change == 'released') {
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
          permission.complete(true);
          temp.complete(root);
          await pending;
          expect(writes, 0);
          expect(await root.list().length, 0);
          if (change != 'dispose') controller.dispose();
          current.frame!.dispose();
          lease.dispose();
        },
      );
    }
  }
}
