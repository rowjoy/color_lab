import 'dart:typed_data';

import '../domain/room_project.dart';

final class RoomRecolorKey {
  RoomRecolorKey({
    required this.projectId,
    required this.photoId,
    required this.maskRevision,
    required this.colorRevision,
    required this.variantId,
  }) {
    if (!RoomProjectLimits.validId(projectId) ||
        !RoomProjectLimits.validId(photoId) ||
        !RoomProjectLimits.validId(variantId) ||
        !RoomProjectLimits.validRevision(maskRevision) ||
        !RoomProjectLimits.validRevision(colorRevision)) {
      throw ArgumentError('Safe complete render identity required');
    }
  }

  final String photoId;
  final String projectId;
  final String variantId;
  final int maskRevision;
  final int colorRevision;

  @override
  bool operator ==(Object other) =>
      other is RoomRecolorKey &&
      projectId == other.projectId &&
      variantId == other.variantId &&
      photoId == other.photoId &&
      maskRevision == other.maskRevision &&
      colorRevision == other.colorRevision;

  @override
  int get hashCode =>
      Object.hash(projectId, photoId, maskRevision, colorRevision, variantId);

  /// Previous frames are display-only, and never cross these ownership fields.
  bool sameView(RoomRecolorKey other) =>
      projectId == other.projectId &&
      photoId == other.photoId &&
      variantId == other.variantId;
}

final class RoomRecolorFrame {
  RoomRecolorFrame({
    required this.key,
    required this.width,
    required this.height,
    required Uint8List rgbaBytes,
    required Uint8List pngBytes,
  }) : _rgbaBytes = Uint8List.fromList(rgbaBytes).asUnmodifiableView(),
       _pngBytes = Uint8List.fromList(pngBytes).asUnmodifiableView() {
    if (width < 1 ||
        height < 1 ||
        rgbaBytes.length != width * height * 4 ||
        pngBytes.isEmpty) {
      throw ArgumentError('Aligned RGBA and encoded PNG bytes required');
    }
  }

  final RoomRecolorKey key;
  final int width;
  final int height;
  Uint8List? _rgbaBytes;
  Uint8List? _pngBytes;
  int _leases = 0;
  bool _ownerReleased = false;
  void Function()? _onReleased;
  Uint8List get rgbaBytes => _rgbaBytes ?? (throw StateError('Frame released'));
  Uint8List get pngBytes => _pngBytes ?? (throw StateError('Frame released'));
  bool get isDisposed => _rgbaBytes == null;
  int get retainedByteCount =>
      (_rgbaBytes?.length ?? 0) + (_pngBytes?.length ?? 0);

  /// Widgets borrow; the scheduler/coordinator transfers the initial owner.
  /// Arrays already handed to Flutter or Share are never modified on release.
  RoomRecolorLease lease({void Function()? onReleased}) {
    if (isDisposed) throw StateError('Frame released');
    _leases++;
    _onReleased ??= onReleased;
    return RoomRecolorLease._(this);
  }

  void dispose() {
    if (_ownerReleased) return;
    _ownerReleased = true;
    _release();
  }

  void _release() {
    if (!_ownerReleased || _leases != 0 || isDisposed) return;
    _rgbaBytes = null;
    _pngBytes = null;
    final onReleased = _onReleased;
    _onReleased = null;
    onReleased?.call();
  }
}

final class RoomRecolorLease {
  RoomRecolorLease._(this._frame);
  RoomRecolorFrame? _frame;
  void dispose() {
    final frame = _frame;
    if (frame == null) return;
    _frame = null;
    frame._leases--;
    frame._release();
  }
}
