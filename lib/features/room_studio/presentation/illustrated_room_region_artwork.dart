import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vector_graphics/vector_graphics.dart' as vg;
import '../../../core/vector_regions/domain/vector_region_geometry.dart';
import '../../../core/vector_regions/data/vector_region_json_codec.dart';
import '../../../core/vector_regions/application/vector_region_transform.dart';
import '../../../core/vector_regions/application/vector_region_hit_tester.dart';
import '../../../l10n/l10n.dart';
import '../../../l10n/generated/app_localizations_en.dart';
import 'illustrated_room_surface_picker.dart';
import '../../../core/vector_regions/rendering/vector_region_renderer.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_assignments.dart';
import '../domain/illustrated_room_draft.dart';
import '../rendering/illustrated_room_rendering.dart';

/// App-lifetime cached paths and bounded, trusted decoration pictures.
/// Nothing here accepts caller-supplied SVG or parses arbitrary SVG structure.
final class StudyRoomRegionArtwork {
  StudyRoomRegionArtwork._(
    this.definition,
    this._colored,
    this._grayscale,
    this._recipes,
    this._wallUnion,
    this._firstWallSlot,
  );

  final VectorArtworkDefinition definition;
  final List<ui.Picture> _colored;
  final List<ui.Picture> _grayscale;
  final List<List<_RoomDecorationRecipe>> _recipes;
  final ui.Path _wallUnion;
  final int _firstWallSlot;

  static final Map<_ArtworkCacheKey, Future<StudyRoomRegionArtwork>> _pending =
      {};
  static final Map<_ArtworkCacheKey, StudyRoomRegionArtwork> _loaded = {};

  /// Compatibility entry point retained for the region-pilot consumers.
  static Future<StudyRoomRegionArtwork> load() =>
      loadFor(IllustratedRoomCatalog.study);

  static Object identityFor(IllustratedRoomTemplate template) =>
      _artworkCacheKey(template);

  static Future<StudyRoomRegionArtwork> loadFor(
    IllustratedRoomTemplate template,
  ) {
    final key = _artworkCacheKey(template);
    if (_loaded[key] case final artwork?) {
      return SynchronousFuture(artwork);
    }
    if (_pending[key] case final pending?) return pending;
    final pending = _load(template, key);
    _pending[key] = pending;
    pending.then(
      (artwork) {
        if (identical(_pending[key], pending)) {
          _pending.remove(key);
          _loaded[key] = artwork;
        }
      },
      onError: (Object _, StackTrace _) {
        if (identical(_pending[key], pending)) _pending.remove(key);
      },
    );
    return pending;
  }

  static Future<StudyRoomRegionArtwork> _load(
    IllustratedRoomTemplate template,
    _ArtworkCacheKey key,
  ) async {
    final colored = <ui.Picture>[];
    final grayscale = <ui.Picture>[];
    try {
      final regionPath = template.regionAssetPath;
      if (regionPath == null) {
        throw const FormatException('Room has no region definition');
      }
      final definition = VectorRegionJsonCodec().decode(
        await rootBundle.loadString(regionPath, cache: false),
      );
      final source = await rootBundle.loadString(
        template.assetPath,
        cache: false,
      );
      final header = '<!-- ${template.id}-decoration-slots -->';
      final divider = '<!-- ${template.id}-decoration-slot -->';
      final sections = source.split(header);
      final expectedSize = Size(
        template.artboardWidth.toDouble(),
        template.artboardHeight.toDouble(),
      );
      if (definition.id != key.id ||
          definition.revision != key.revision ||
          definition.intrinsicSize != expectedSize ||
          IllustratedRoomRegionMembership.fromRegions(definition.regions) !=
              IllustratedRoomRegionMembership.forTemplate(template) ||
          sections.length != 2 ||
          !sections.last.trimRight().endsWith('</svg>')) {
        throw const FormatException('Invalid room decoration envelope');
      }
      final body = sections.last.trimRight();
      final slots = body
          .substring(0, body.length - '</svg>'.length)
          .split(divider);
      if (slots.length != definition.paintEntries.length + 1 ||
          slots.length > 64 ||
          definition.paintEntries.indexed.any(
            (entry) => entry.$1 != entry.$2.slot,
          )) {
        throw const FormatException('Invalid room decoration slots');
      }
      final recipes = _validatedRecipes(template, definition, source, slots);
      final wallEntries = definition.paintEntries
          .where((entry) => entry.region.groupId == 'walls')
          .toList(growable: false);
      if (wallEntries.isEmpty) {
        throw const FormatException('Room has no wall geometry');
      }
      final wallUnion = wallEntries
          .map((entry) => entry.path)
          .reduce(
            (left, right) =>
                ui.Path.combine(ui.PathOperation.union, left, right),
          );
      for (final slot in slots) {
        final svg = '${sections.first}$slot</svg>';
        final colorInfo = await vg.vg.loadPicture(SvgStringLoader(svg), null);
        colored.add(colorInfo.picture);
        final grayInfo = await vg.vg.loadPicture(
          SvgStringLoader(svg, colorMapper: const _GrayscaleDecorationMapper()),
          null,
        );
        grayscale.add(grayInfo.picture);
      }
      return StudyRoomRegionArtwork._(
        definition,
        List.unmodifiable(colored),
        List.unmodifiable(grayscale),
        List.unmodifiable(
          recipes.map(List<_RoomDecorationRecipe>.unmodifiable),
        ),
        wallUnion,
        wallEntries.first.slot,
      );
    } catch (_) {
      for (final picture in [...colored, ...grayscale]) {
        picture.dispose();
      }
      rethrow;
    }
  }

  void draw(
    Canvas canvas,
    IllustratedRoomDraft draft,
    VectorRegionTransform transform,
  ) {
    if (draft.template.id != definition.id ||
        draft.membership !=
            IllustratedRoomRegionMembership.fromRegions(definition.regions)) {
      throw ArgumentError('Draft does not match the loaded room artwork.');
    }
    final colors = illustratedRoomEffectiveColors(draft);
    final decoration = draft.displayMode == IllustratedRoomVisualMode.grayscale
        ? _grayscale
        : _colored;
    int colorValueFor(VectorRegionDefinition region) =>
        (draft.displayAssignments?.colorFor(region.id) ??
                colors.colorFor(illustratedRoomSurfaceForGroup(region.groupId)))
            .value;
    final wallValues = {
      for (final region in definition.regions)
        if (region.groupId == 'walls') colorValueFor(region),
    };
    final uniformWallPaint = wallValues.length == 1
        ? (Paint()..color = Color(0xFF000000 | wallValues.single))
        : null;
    VectorRegionRenderer.draw(
      canvas,
      definition,
      transform,
      colorFor: (region) =>
          uniformWallPaint != null && region.groupId == 'walls'
          ? const Color(0x00000000)
          : Color(0xFF000000 | colorValueFor(region)),
      decoration: (canvas, slot) {
        for (final recipe in _recipes[slot]) {
          recipe.draw(canvas);
        }
        canvas.drawPicture(decoration[slot]);
        if (uniformWallPaint != null && slot == _firstWallSlot) {
          canvas.drawPath(_wallUnion, uniformWallPaint);
        }
      },
    );
  }
}

typedef _ArtworkCacheKey = ({
  String id,
  int revision,
  String svgPath,
  String regionPath,
  int width,
  int height,
});

_ArtworkCacheKey _artworkCacheKey(IllustratedRoomTemplate template) => (
  id: template.id,
  revision: 1,
  svgPath: template.assetPath,
  regionPath:
      template.regionAssetPath ??
      (throw ArgumentError('Template has no region definition.')),
  width: template.artboardWidth,
  height: template.artboardHeight,
);

sealed class _RoomDecorationRecipe {
  const _RoomDecorationRecipe();
  void draw(Canvas canvas);
}

final class _BlackContourRecipe extends _RoomDecorationRecipe {
  const _BlackContourRecipe(this.path, this.alpha);
  final Path path;
  final int alpha;
  @override
  void draw(Canvas canvas) =>
      canvas.drawPath(path, Paint()..color = Color.fromARGB(alpha, 0, 0, 0));
}

final class _FabricGradientRecipe extends _RoomDecorationRecipe {
  _FabricGradientRecipe(this.path, this.bounds);
  final Path path;
  final Rect bounds;
  late final Shader _shader = ui.Gradient.linear(
    Offset(bounds.left, bounds.top),
    Offset(bounds.right, bounds.top),
    const [
      Color(0x42FFFFFF),
      Color(0x14FFFFFF),
      Color(0x0A000000),
      Color(0x3D000000),
    ],
    const [0, .28, .7, 1],
  );
  @override
  void draw(Canvas canvas) => canvas.drawPath(path, Paint()..shader = _shader);
}

List<List<_RoomDecorationRecipe>> _validatedRecipes(
  IllustratedRoomTemplate template,
  VectorArtworkDefinition definition,
  String source,
  List<String> slots,
) {
  final recipes = List.generate(slots.length, (_) => <_RoomDecorationRecipe>[]);
  final markerPattern = RegExp(r'<!--\s*room-shared-[\s\S]*?-->');
  final markers = markerPattern
      .allMatches(source)
      .map((match) => match.group(0)!.trim())
      .toList(growable: false);
  if (template.id == 'dining') {
    const marker =
        '<!-- room-shared-black-overlay part-slot="6" contour-indices="0" opacity="0.28" -->';
    if (markers.length != 1 ||
        markers.single != marker ||
        slots[7].split(marker).length != 2) {
      throw const FormatException('Invalid Dining shared recipe marker');
    }
    final part = definition.paintEntries
        .singleWhere((entry) => entry.slot == 6)
        .part;
    recipes[7].add(
      _BlackContourRecipe(_selectedContours(part, const {0}), 0x47),
    );
    return recipes;
  }
  if (template.id != 'living') {
    if (markers.isNotEmpty) {
      throw const FormatException('Shared recipe is not allowed for this room');
    }
    return recipes;
  }

  const blackMarker =
      '<!-- room-shared-black-overlay part-slot="6" contour-indices="0,2" opacity="0.08" -->';
  const sofaMarker =
      '<!-- room-shared-gradient part-slot="10" gradient-id="living-fabric-roll" -->';
  const chairMarker =
      '<!-- room-shared-gradient part-slot="14" gradient-id="living-fabric-roll" -->';
  const expected = [blackMarker, sofaMarker, chairMarker];
  if (markers.length != expected.length ||
      !expected.every(
        (marker) => markers.where((it) => it == marker).length == 1,
      ) ||
      slots[7].split(blackMarker).length != 2 ||
      slots[11].split(sofaMarker).length != 2 ||
      slots[15].split(chairMarker).length != 2) {
    throw const FormatException('Invalid Living shared recipe markers');
  }

  final gradient = RegExp(
    r'<linearGradient id="living-fabric-roll"[\s\S]*?</linearGradient>',
  ).firstMatch(source)?.group(0)?.replaceAll(RegExp(r'\s+'), '');
  const expectedGradient =
      '<linearGradientid="living-fabric-roll"x1="0"y1="0"x2="1"y2="0">'
      '<stopoffset="0"stop-color="#FFFFFF"stop-opacity=".26"/>'
      '<stopoffset=".28"stop-color="#FFFFFF"stop-opacity=".08"/>'
      '<stopoffset=".7"stop-color="#000000"stop-opacity=".04"/>'
      '<stopoffset="1"stop-color="#000000"stop-opacity=".24"/>'
      '</linearGradient>';
  if (gradient != expectedGradient) {
    throw const FormatException('Invalid Living fabric gradient');
  }

  VectorRegionPart part(int slot) =>
      definition.paintEntries.singleWhere((entry) => entry.slot == slot).part;
  final console = part(6);
  recipes[7].add(
    _BlackContourRecipe(_selectedContours(console, const {0, 2}), 0x14),
  );
  for (final entry in [
    (slot: 11, part: part(10)),
    (slot: 15, part: part(14)),
  ]) {
    recipes[entry.slot].add(
      _FabricGradientRecipe(
        entry.part.toPath(),
        _compilerBounds(entry.part.commands),
      ),
    );
  }
  return recipes;
}

Path _selectedContours(VectorRegionPart part, Set<int> selected) {
  final commands = <List<Object>>[];
  var contour = -1;
  final found = <int>{};
  for (final command in part.commands) {
    if (command.first == 'M') contour++;
    if (selected.contains(contour)) {
      commands.add(command);
      found.add(contour);
    }
  }
  if (found.length != selected.length || commands.isEmpty) {
    throw const FormatException('Invalid shared contour recipe');
  }
  return VectorRegionPart(slot: part.slot, commands: commands).toPath();
}

Rect _compilerBounds(List<List<Object>> commands) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final command in commands) {
    for (var index = 1; index + 1 < command.length; index += 2) {
      final x = (command[index] as num).toDouble();
      final y = (command[index + 1] as num).toDouble();
      left = x < left ? x : left;
      top = y < top ? y : top;
      right = x > right ? x : right;
      bottom = y > bottom ? y : bottom;
    }
  }
  if (!left.isFinite || right <= left || bottom <= top) {
    throw const FormatException('Invalid shared gradient bounds');
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

class IllustratedRoomRegionArtwork extends StatelessWidget {
  const IllustratedRoomRegionArtwork({
    super.key,
    required this.artwork,
    required this.draft,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.selectedRegionId,
    this.onRegionSelected,
  });
  final StudyRoomRegionArtwork artwork;
  final IllustratedRoomDraft draft;
  final BoxFit fit;
  final Alignment alignment;
  final String? selectedRegionId;
  final ValueChanged<String>? onRegionSelected;
  VectorRegionTransform _transform(Size size) => VectorRegionTransform.fit(
    intrinsicSize: artwork.definition.intrinsicSize,
    viewport: size,
    fit: fit,
    alignment: alignment,
  );
  Map<String, Rect> regionBounds(Size size) => {
    for (final region in artwork.definition.regions.where((r) => r.fillable))
      region.id: _transform(size).screenBounds(region.geometry.bounds),
  };
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final painter = _RegionPainter(
        this,
        Localizations.of<AppLocalizations>(context, AppLocalizations) ??
            AppLocalizationsEn(),
        Directionality.of(context),
      );
      return GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTapUp: onRegionSelected == null
            ? null
            : (details) {
                final hit = hitTestVectorRegion(
                  artwork.definition,
                  details.localPosition,
                  _transform(size),
                );
                if (hit != null) onRegionSelected!(hit.id);
              },
        child: CustomPaint(painter: painter, size: Size.infinite),
      );
    },
  );
}

final class _RegionPainter extends CustomPainter {
  _RegionPainter(this.widget, this.l10n, this.direction);
  final IllustratedRoomRegionArtwork widget;
  final AppLocalizations l10n;
  final TextDirection direction;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    widget.artwork.draw(canvas, widget.draft, widget._transform(size));
    if (widget.selectedRegionId != null) {
      final transform = widget._transform(size);
      canvas.save();
      transform.apply(canvas);
      for (final region in widget.artwork.definition.regions.where(
        (r) => r.id == widget.selectedRegionId,
      )) {
        for (final part in region.geometry.parts) {
          canvas.drawPath(
            part.toPath(),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6 / transform.scaleX
              ..color = Colors.white,
          );
          canvas.drawPath(
            part.toPath(),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 / transform.scaleX
              ..color = Colors.black,
          );
        }
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (size) {
    final bounds = widget.regionBounds(size);
    return [
      for (final region in widget.artwork.definition.regions.where(
        (r) =>
            r.fillable && !bounds[r.id]!.intersect(Offset.zero & size).isEmpty,
      ))
        CustomPainterSemantics(
          rect: bounds[region.id]!.intersect(Offset.zero & size),
          properties: SemanticsProperties(
            label:
                '${roomRegionName(l10n, region.id)}, ${roomRegionName(l10n, region.groupId)}, '
                '${(widget.draft.displayAssignments?.colorFor(region.id) ?? illustratedRoomEffectiveColors(widget.draft).colorFor(illustratedRoomSurfaceForGroup(region.groupId))).hex}',
            selected: widget.selectedRegionId == region.id,
            button: widget.onRegionSelected != null,
            onTap: widget.onRegionSelected == null
                ? null
                : () => widget.onRegionSelected!(region.id),
            textDirection: direction,
          ),
        ),
    ];
  };
  @override
  bool shouldRepaint(_RegionPainter old) =>
      old.widget.draft != widget.draft ||
      old.widget.draft.displayAssignments != widget.draft.displayAssignments ||
      old.widget.artwork != widget.artwork ||
      old.widget.fit != widget.fit ||
      old.widget.alignment != widget.alignment ||
      old.widget.selectedRegionId != widget.selectedRegionId;

  @override
  bool shouldRebuildSemantics(_RegionPainter old) =>
      shouldRepaint(old) ||
      old.direction != direction ||
      old.widget.selectedRegionId != widget.selectedRegionId ||
      old.widget.onRegionSelected != widget.onRegionSelected;
}

final class _GrayscaleDecorationMapper extends ColorMapper {
  const _GrayscaleDecorationMapper();
  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) => illustratedRoomGrayscaleColor(color);
}
