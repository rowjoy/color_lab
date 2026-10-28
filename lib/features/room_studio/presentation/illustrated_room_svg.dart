import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../domain/illustrated_room_draft.dart';
import 'illustrated_room_region_artwork.dart';
import '../rendering/illustrated_room_rendering.dart';

class IllustratedRoomSvg extends StatefulWidget {
  const IllustratedRoomSvg({
    super.key,
    required this.draft,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.onError,
    this.retryToken = 0,
    this.selectedRegionId,
    this.onRegionSelected,
  });

  final IllustratedRoomDraft draft;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final VoidCallback? onError;
  final int retryToken;
  final String? selectedRegionId;
  final ValueChanged<String>? onRegionSelected;

  @override
  State<IllustratedRoomSvg> createState() => _IllustratedRoomSvgState();
}

class _IllustratedRoomSvgState extends State<IllustratedRoomSvg> {
  bool _failed = false;
  bool _failureScheduled = false;
  int _loadEpoch = 0;

  Object get _artworkIdentity => widget.draft.template.regionAssetPath == null
      ? widget.draft.template.assetPath
      : StudyRoomRegionArtwork.identityFor(widget.draft.template);

  @override
  void didUpdateWidget(IllustratedRoomSvg oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.template.id != widget.draft.template.id ||
        oldWidget.draft.template.assetPath != widget.draft.template.assetPath ||
        oldWidget.draft.template.regionAssetPath !=
            widget.draft.template.regionAssetPath ||
        oldWidget.draft.template.artboardWidth !=
            widget.draft.template.artboardWidth ||
        oldWidget.draft.template.artboardHeight !=
            widget.draft.template.artboardHeight ||
        oldWidget.retryToken != widget.retryToken) {
      _failed = false;
      _failureScheduled = false;
      _loadEpoch++;
    }
  }

  void _scheduleFailure(int epoch, Object identity) {
    if (_failed || _failureScheduled) return;
    _failureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || epoch != _loadEpoch || identity != _artworkIdentity) {
        _failureScheduled = false;
        return;
      }
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

    final isRegionArtwork = widget.draft.template.regionAssetPath != null;
    final colors = illustratedRoomEffectiveColors(widget.draft);
    final labels = widget.draft.template.surfaceLabels;
    final label =
        widget.draft.displayMode == IllustratedRoomVisualMode.grayscale
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
      excludeSemantics: !isRegionArtwork,
      child: isRegionArtwork
          ? FutureBuilder<StudyRoomRegionArtwork>(
              key: ValueKey(
                StudyRoomRegionArtwork.identityFor(widget.draft.template),
              ),
              future: StudyRoomRegionArtwork.loadFor(widget.draft.template),
              builder: (context, snapshot) {
                final identity = StudyRoomRegionArtwork.identityFor(
                  widget.draft.template,
                );
                final epoch = _loadEpoch;
                if (snapshot.hasError) {
                  _scheduleFailure(epoch, identity);
                }
                if (snapshot.data case final artwork?
                    when artwork.definition.id == widget.draft.template.id) {
                  return IllustratedRoomRegionArtwork(
                    artwork: artwork,
                    draft: widget.draft,
                    fit: widget.fit,
                    selectedRegionId: widget.selectedRegionId,
                    onRegionSelected: widget.onRegionSelected,
                    alignment: widget.alignment.resolve(
                      Directionality.of(context),
                    ),
                  );
                }
                return const ColoredBox(
                  color: Color(0xFFE7E5E4),
                  child: Center(child: Icon(Icons.chair_outlined)),
                );
              },
            )
          : SvgPicture.asset(
              widget.draft.template.assetPath,
              fit: widget.fit,
              alignment: widget.alignment,
              excludeFromSemantics: true,
              placeholderBuilder: (context) => const ColoredBox(
                color: Color(0xFFE7E5E4),
                child: Center(child: Icon(Icons.chair_outlined)),
              ),
              errorBuilder: (context, error, stackTrace) {
                _scheduleFailure(_loadEpoch, _artworkIdentity);
                return const ColoredBox(
                  color: Color(0xFFF5F5F4),
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                );
              },
            ),
    );
  }
}
