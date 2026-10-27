import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../recolor/room_recolor_frame.dart';

class RoomRecolorViewport extends StatelessWidget {
  const RoomRecolorViewport({
    super.key,
    required this.sourcePngBytes,
    required this.width,
    required this.height,
    required this.currentKey,
    required this.frame,
    required this.showAfter,
    required this.updating,
  });

  final Uint8List sourcePngBytes;
  final int width;
  final int height;
  final RoomRecolorKey currentKey;
  final RoomRecolorFrame? frame;
  final bool showAfter;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final isCurrent =
        frame != null && !frame!.isDisposed && frame!.key == currentKey;
    final isPrevious =
        updating &&
        frame != null &&
        !frame!.isDisposed &&
        frame!.key.sameView(currentKey);
    final useResult = showAfter && (isCurrent || isPrevious);
    final bytes = useResult ? frame!.pngBytes : sourcePngBytes;
    final imageKey = useResult
        ? isCurrent
              ? 'room-recolor-after-image'
              : 'room-recolor-previous-image'
        : 'room-recolor-before-image';
    final label = useResult
        ? isCurrent
              ? 'Recolored room preview'
              : 'Previous recolored preview while updating'
        : 'Original room photo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: width / height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: useResult
                ? RoomRecolorImage(
                    frame: frame!,
                    imageKey: ValueKey(imageKey),
                    semanticLabel: label,
                  )
                : Image.memory(
                    bytes,
                    key: ValueKey(imageKey),
                    fit: BoxFit.contain,
                    gaplessPlayback: false,
                    semanticLabel: label,
                  ),
          ),
        ),
        if (updating) ...[
          const SizedBox(height: 8),
          Semantics(liveRegion: true, child: const Text('Updating preview...')),
        ],
      ],
    );
  }
}

/// Widgets borrow buffers; only the exact obsolete image-cache key is evicted.
class RoomRecolorImage extends StatefulWidget {
  const RoomRecolorImage({
    super.key,
    required this.frame,
    required this.imageKey,
    required this.semanticLabel,
  });
  final RoomRecolorFrame frame;
  final Key imageKey;
  final String semanticLabel;
  @override
  State<RoomRecolorImage> createState() => _RoomRecolorImageState();
}

class _RoomRecolorImageState extends State<RoomRecolorImage> {
  late MemoryImage _image;
  late RoomRecolorLease _lease;
  void _acquire() {
    final image = _image = MemoryImage(widget.frame.pngBytes);
    _lease = widget.frame.lease(
      onReleased: () {
        PaintingBinding.instance.imageCache.evict(image);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _acquire();
  }

  @override
  void didUpdateWidget(RoomRecolorImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.frame, widget.frame)) {
      _lease.dispose();
      _acquire();
    }
  }

  @override
  void dispose() {
    _lease.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Image(
    image: _image,
    key: widget.imageKey,
    fit: BoxFit.contain,
    gaplessPlayback: false,
    semanticLabel: widget.semanticLabel,
  );
}
