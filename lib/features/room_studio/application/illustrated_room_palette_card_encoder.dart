import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/color/color_models.dart';
import '../domain/illustrated_room_draft.dart';
import 'illustrated_room_artwork_encoder.dart';
import 'illustrated_room_png.dart';

final class IllustratedRoomPaletteRow {
  const IllustratedRoomPaletteRow(this.name, this.groupName, this.color);
  final String name, groupName;
  final RgbColor color;
}

/// Fully captured labels and colors. No catalogue or widget references survive.
final class IllustratedRoomPaletteCard {
  IllustratedRoomPaletteCard({
    required Iterable<IllustratedRoomPaletteRow> rows,
    required this.limitation,
    this.textDirection = TextDirection.ltr,
    this.textScale = 1,
  }) : rows = List.unmodifiable(rows) {
    if (this.rows.isEmpty ||
        this.rows.length > 32 ||
        limitation.trim().isEmpty ||
        !textScale.isFinite ||
        textScale < 1 ||
        textScale > 2) {
      throw ArgumentError('Invalid palette card.');
    }
  }
  factory IllustratedRoomPaletteCard.fromDraft(
    IllustratedRoomDraft draft, {
    required String Function(String) labelFor,
    required String limitation,
    TextDirection textDirection = TextDirection.ltr,
    double textScale = 1,
  }) {
    final assignments = draft.displayAssignments;
    if (assignments == null) throw const IllustratedRoomRenderException();
    final authored = draft.template.regionAssetPath != null;
    return IllustratedRoomPaletteCard(
      rows: [
        for (final entry in draft.membership.groups.entries)
          for (final id in authored ? entry.value : [entry.key])
            IllustratedRoomPaletteRow(
              labelFor(id),
              labelFor(entry.key),
              authored
                  ? assignments.colorFor(id)
                  : assignments.groupColors[entry.key]!,
            ),
      ],
      limitation: limitation,
      textDirection: textDirection,
      textScale: textScale,
    );
  }
  final List<IllustratedRoomPaletteRow> rows;
  final String limitation;
  final TextDirection textDirection;
  final double textScale;
}

abstract interface class IllustratedRoomPaletteCardEncoder {
  Future<Uint8List> encodePng(IllustratedRoomPaletteCard card);
}

final illustratedRoomPaletteCardEncoderProvider =
    Provider<IllustratedRoomPaletteCardEncoder>(
      (ref) => CanvasIllustratedRoomPaletteCardEncoder(),
    );

final class CanvasIllustratedRoomPaletteCardEncoder
    implements IllustratedRoomPaletteCardEncoder {
  static const outputWidth = 1200;
  static const maxOutputHeight = 4096;

  /// The same measured layout is used for painting and bounds verification.
  static IllustratedRoomPaletteCardLayout layout(
    IllustratedRoomPaletteCard card,
  ) {
    final painters = <TextPainter>[];
    try {
      TextPainter paragraph(
        String text,
        double width, {
        double size = 28,
        bool bold = false,
        TextDirection? direction,
      }) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: const Color(0xFF151515),
              fontSize: size * card.textScale,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          textDirection: direction ?? card.textDirection,
        )..layout(maxWidth: width);
        painters.add(painter);
        return painter;
      }

      final title = paragraph('TintAtlas', 1080, size: 40, bold: true);
      final rows = [
        for (final row in card.rows)
          (
            row,
            paragraph(
              row.name == row.groupName
                  ? row.name
                  : '${row.name} · ${row.groupName}',
              952,
              bold: true,
            ),
            paragraph(
              row.color.hex.toUpperCase(),
              952,
              direction: TextDirection.ltr,
            ),
          ),
      ];
      final limitation = paragraph(card.limitation, 1080, size: 24);
      final height =
          (60 +
                  title.height +
                  36 +
                  rows.fold<double>(
                    0,
                    (height, row) =>
                        height + row.$2.height + row.$3.height + 40,
                  ) +
                  24 +
                  limitation.height +
                  60)
              .ceil();
      if (height > maxOutputHeight) {
        throw const IllustratedRoomRenderException();
      }
      final texts = <IllustratedRoomPaletteTextBounds>[];
      void text(String role, String value, TextPainter painter, Offset offset) {
        texts.add(
          IllustratedRoomPaletteTextBounds._(
            role,
            value,
            offset & painter.size,
            painter,
          ),
        );
      }

      text('title', 'TintAtlas', title, const Offset(60, 60));
      final swatches = <(Rect, Color)>[];
      var y = 60 + title.height + 36;
      final rtl = card.textDirection == TextDirection.rtl;
      for (final (index, row) in rows.indexed) {
        swatches.add((
          Rect.fromLTWH(rtl ? 1060 : 60, y, 80, 80),
          Color(0xFF000000 | row.$1.color.value),
        ));
        final x = rtl ? 60.0 : 188.0;
        text('label-$index', row.$2.text!.toPlainText(), row.$2, Offset(x, y));
        text(
          'hex-$index',
          row.$1.color.hex.toUpperCase(),
          row.$3,
          Offset(x, y + row.$2.height + 4),
        );
        y += row.$2.height + row.$3.height + 40;
      }
      text('limitation', card.limitation, limitation, Offset(60, y + 24));
      return IllustratedRoomPaletteCardLayout._(
        outputWidth,
        height,
        texts,
        swatches,
      );
    } catch (_) {
      for (final painter in painters) {
        painter.dispose();
      }
      rethrow;
    }
  }

  @override
  Future<Uint8List> encodePng(IllustratedRoomPaletteCard card) async {
    IllustratedRoomPaletteCardLayout? measured;
    ui.Picture? picture;
    ui.Image? image;
    ui.PictureRecorder? recorder;
    try {
      measured = layout(card);
      recorder = ui.PictureRecorder();
      measured.draw(Canvas(recorder));
      picture = recorder.endRecording();
      recorder = null;
      image = await picture.toImage(measured.width, measured.height);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const IllustratedRoomRenderException();
      return cleanIllustratedRoomPng(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      throw const IllustratedRoomRenderException();
    } finally {
      if (recorder?.isRecording ?? false) recorder!.endRecording().dispose();
      image?.dispose();
      picture?.dispose();
      measured?.dispose();
    }
  }
}

final class IllustratedRoomPaletteTextBounds {
  const IllustratedRoomPaletteTextBounds._(
    this.role,
    this.text,
    this.bounds,
    this._painter,
  );
  final String role, text;
  final Rect bounds;
  final TextPainter _painter;
}

/// Owned measured paragraphs. Dispose after inspection or drawing.
final class IllustratedRoomPaletteCardLayout {
  IllustratedRoomPaletteCardLayout._(
    this.width,
    this.height,
    Iterable<IllustratedRoomPaletteTextBounds> text,
    Iterable<(Rect, Color)> swatches,
  ) : text = List.unmodifiable(text),
      _swatches = List.unmodifiable(swatches);
  final int width, height;
  final List<IllustratedRoomPaletteTextBounds> text;
  final List<(Rect, Color)> _swatches;
  void draw(Canvas canvas) {
    canvas.drawColor(Colors.white, BlendMode.src);
    for (final (rect, color) in _swatches) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = color,
      );
    }
    for (final item in text) {
      item._painter.paint(canvas, item.bounds.topLeft);
    }
  }

  void dispose() {
    for (final item in text) {
      item._painter.dispose();
    }
  }
}
