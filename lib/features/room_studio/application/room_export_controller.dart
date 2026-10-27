import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../recolor/room_recolor_frame.dart';
import 'room_export_metadata_verifier.dart';
import 'room_gallery_writer.dart';
import 'room_image_export_service.dart';
import 'room_project_session_controller.dart';
import 'room_recolor_provider.dart';

enum RoomExportAction { save, share }

enum RoomExportFailure {
  accessDenied,
  capacity,
  save,
  share,
  invalidPreview,
  interrupted,
}

enum RoomExportNotice { saved, shared, dismissed, unavailable }

/// A single read from the current editor. Display/baseline frames never enter.
final class RoomExportSource {
  const RoomExportSource({
    required this.session,
    required this.owner,
    required this.eligible,
    required this.ready,
    required this.frame,
  });
  final RoomProjectSession session;
  final Object owner;
  final bool eligible, ready;
  final RoomRecolorFrame? frame;
  bool get canCapture =>
      eligible &&
      ready &&
      frame != null &&
      !frame!.isDisposed &&
      !frame!.isOwnerReleased &&
      frame!.key == roomActiveRecolorKey(session) &&
      frame!.width == session.visible.photo.width &&
      frame!.height == session.visible.photo.height;
}

final class _Identity {
  _Identity(RoomExportSource source)
    : lifetime = source.session.lifetime,
      key = roomActiveRecolorKey(source.session)!,
      owner = source.owner,
      width = source.session.visible.photo.width,
      height = source.session.visible.photo.height,
      variantName = source.session.variantSet.active.name,
      unsaved = source.session.hasUnsavedChanges;
  final Object lifetime, owner;
  final RoomRecolorKey key;
  final int width, height;
  final String variantName;
  final bool unsaved;
  bool matches(RoomExportSource? source) =>
      source != null &&
      identical(lifetime, source.session.lifetime) &&
      identical(owner, source.owner) &&
      key == roomActiveRecolorKey(source.session) &&
      width == source.session.visible.photo.width &&
      height == source.session.visible.photo.height;
}

final class _Operation {
  _Operation(this.identity);
  final _Identity identity;
  bool handedOff = false;
}

/// Sole Save/Share busy guard. Owns detached PNG only, never a preview frame.
final class RoomExportController extends ChangeNotifier {
  RoomExportController({
    required RoomImageExportService service,
    required RoomExportSource? Function() readSource,
  }) : _service = service,
       _readSource = readSource;
  final RoomImageExportService _service;
  final RoomExportSource? Function() _readSource;
  _Operation? _operation;
  _Identity? _messageIdentity;
  bool _alive = true;
  RoomExportFailure? _failure;
  RoomExportNotice? _notice;
  RoomExportAction? lastAction;
  bool get busy => _operation != null;
  bool get _messageCurrent =>
      _alive && _messageIdentity?.matches(_readSource()) == true;
  RoomExportFailure? get failure => _messageCurrent ? _failure : null;
  RoomExportNotice? get notice => _messageCurrent ? _notice : null;

  bool _current(_Operation op) {
    if (!_alive || !identical(_operation, op)) return false;
    final source = _readSource();
    return op.identity.matches(source) && source!.canCapture;
  }

  /// Session/key changes revoke synchronously, before any pending I/O settles.
  void reconcile() {
    final op = _operation;
    if (op != null && !op.identity.matches(_readSource())) revoke();
  }

  bool _ownsResult(_Operation op) {
    if (!_alive || !identical(_operation, op)) return false;
    final source = _readSource();
    return op.identity.matches(source) && (op.handedOff || source!.eligible);
  }

  void revoke({bool beforeHandoffOnly = false}) {
    final op = _operation;
    if (!_alive || op == null || (beforeHandoffOnly && op.handedOff)) return;
    _operation = null;
    if (op.identity.matches(_readSource())) {
      _messageIdentity = op.identity;
      _failure = RoomExportFailure.interrupted;
      _notice = null;
    }
    notifyListeners();
  }

  Future<void> export(
    RoomExportAction action, {
    required Rect origin,
    required String title,
  }) async {
    if (!_alive || busy) return;
    final initial = _readSource();
    if (initial == null || !initial.canCapture) return;
    final op = _operation = _Operation(_Identity(initial));
    lastAction = action;
    _failure = null;
    _notice = null;
    _messageIdentity = op.identity;
    notifyListeners();
    try {
      if (action == RoomExportAction.save) {
        await _service.prepareSave(isCurrent: () => _current(op));
      }
      if (!_current(op)) throw const RoomExportInterrupted();
      final source = _readSource()!;
      if (!source.canCapture) throw const RoomExportInterrupted();
      final frame = source.frame!;
      if (frame.pngBytes.length > RoomExportMetadataVerifier.maxEncodedBytes) {
        throw const RoomExportVerificationException();
      }
      // Synchronous detachment; no frame/lease is owned across an await.
      final bytes = Uint8List.fromList(frame.pngBytes).asUnmodifiableView();
      final dimensions = const RoomExportMetadataVerifier().verify(bytes);
      if (dimensions.width != op.identity.width ||
          dimensions.height != op.identity.height) {
        throw const RoomExportVerificationException();
      }
      bool guard() => _current(op);
      void handedOff() => op.handedOff = true;
      RoomExportNotice result;
      if (action == RoomExportAction.save) {
        await _service.savePng(
          pngBytes: bytes,
          photoId: op.identity.key.photoId,
          isCurrent: guard,
          onHandoff: handedOff,
        );
        result = RoomExportNotice.saved;
      } else {
        final shared = await _service.sharePng(
          pngBytes: bytes,
          photoId: op.identity.key.photoId,
          origin: origin,
          title: title,
          isCurrent: guard,
          onHandoff: handedOff,
        );
        result = switch (shared) {
          RoomShareResult.completed => RoomExportNotice.shared,
          RoomShareResult.dismissed => RoomExportNotice.dismissed,
          RoomShareResult.unavailable => RoomExportNotice.unavailable,
        };
      }
      if (_ownsResult(op)) _notice = result;
    } catch (error) {
      if (_ownsResult(op)) {
        _failure = switch (error) {
          RoomExportInterrupted() => RoomExportFailure.interrupted,
          RoomExportVerificationException() => RoomExportFailure.invalidPreview,
          RoomGalleryWriteException(failure: RoomGalleryFailure.accessDenied) =>
            RoomExportFailure.accessDenied,
          RoomGalleryWriteException(
            failure: RoomGalleryFailure.notEnoughSpace,
          ) =>
            RoomExportFailure.capacity,
          _ =>
            action == RoomExportAction.save
                ? RoomExportFailure.save
                : RoomExportFailure.share,
        };
      }
    } finally {
      if (_alive && identical(_operation, op)) {
        _operation = null;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _alive = false;
    _operation = null;
    super.dispose();
  }
}
