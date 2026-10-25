import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/illustrated_room_draft.dart';
import '../rendering/illustrated_room_color_mapper.dart';

class IllustratedRoomSvg extends StatefulWidget {
  const IllustratedRoomSvg({
    super.key,
    required this.draft,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.onError,
    this.retryToken = 0,
  });

  final IllustratedRoomDraft draft;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final VoidCallback? onError;
  final int retryToken;

  @override
  State<IllustratedRoomSvg> createState() => _IllustratedRoomSvgState();
}

class _IllustratedRoomSvgState extends State<IllustratedRoomSvg> {
  bool _failed = false;
  bool _failureScheduled = false;

  @override
  void didUpdateWidget(IllustratedRoomSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.template.assetPath != widget.draft.template.assetPath ||
        oldWidget.retryToken != widget.retryToken) {
      _failed = false;
      _failureScheduled = false;
    }
  }

  void _scheduleFailure() {
    if (_failed || _failureScheduled) return;
    _failureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _failureScheduled = false;
      });
      widget.onError?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Semantics(
        container: true,
        image: true,
        label: '${widget.draft.template.title} preview unavailable.',
        excludeSemantics: true,
        child: const ColoredBox(
          color: Color(0xFFF5F5F4),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );
    }

    final mapper = IllustratedRoomColorMapper(widget.draft);
    final colors = mapper.effectiveColors;
    final labels = widget.draft.template.surfaceLabels;
    final label = widget.draft.mode == IllustratedRoomVisualMode.grayscale
        ? '${widget.draft.template.title}, black and white'
        : '${widget.draft.template.title}. ${widget.draft.visualStateLabel}. '
              '${labels.wall} ${colors.wall.hex}. '
              '${labels.ceiling} ${colors.ceiling.hex}. '
              '${labels.floor} ${colors.floor.hex}. '
              '${labels.furniture} ${colors.furniture.hex}.';

    return Semantics(
      container: true,
      image: true,
      label: label,
      excludeSemantics: true,
      child: SvgPicture.asset(
        widget.draft.template.assetPath,
        fit: widget.fit,
        alignment: widget.alignment,
        colorMapper: mapper,
        excludeFromSemantics: true,
        placeholderBuilder: (context) => const ColoredBox(
          color: Color(0xFFE7E5E4),
          child: Center(child: Icon(Icons.chair_outlined)),
        ),
        errorBuilder: (context, error, stackTrace) {
          _scheduleFailure();
          return const ColoredBox(
            color: Color(0xFFF5F5F4),
            child: Center(child: Icon(Icons.broken_image_outlined)),
          );
        },
      ),
    );
  }
}
