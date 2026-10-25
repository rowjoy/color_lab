import '../../../core/color/color_models.dart';
import 'illustrated_room.dart';

enum IllustratedRoomVisualMode { grayscale, colored }

final class IllustratedRoomDraft {
  const IllustratedRoomDraft._({
    required this.template,
    required this.mode,
    required this.colors,
    required this.savedDesignId,
    required this.savedName,
    required _IllustratedRoomDraftBaseline baseline,
  }) : _baseline = baseline,
       assert(
         (mode == IllustratedRoomVisualMode.grayscale && colors == null) ||
             (mode == IllustratedRoomVisualMode.colored && colors != null),
       ),
       assert(
         (savedDesignId == null && savedName == null) ||
             (savedDesignId != null && savedName != null),
       );

  factory IllustratedRoomDraft.grayscale(IllustratedRoomTemplate template) {
    const mode = IllustratedRoomVisualMode.grayscale;
    const baseline = _IllustratedRoomDraftBaseline(
      mode: mode,
      colors: null,
      savedDesignId: null,
      savedName: null,
    );
    return IllustratedRoomDraft._(
      template: template,
      mode: mode,
      colors: null,
      savedDesignId: null,
      savedName: null,
      baseline: baseline,
    );
  }

  factory IllustratedRoomDraft.saved({
    required IllustratedRoomTemplate template,
    required IllustratedRoomColors colors,
    required String id,
    required String name,
  }) {
    final savedId = _requiredIdentity(id, 'id');
    final savedName = _requiredIdentity(name, 'name');
    final baseline = _IllustratedRoomDraftBaseline(
      mode: IllustratedRoomVisualMode.colored,
      colors: colors,
      savedDesignId: savedId,
      savedName: savedName,
    );
    return IllustratedRoomDraft._(
      template: template,
      mode: IllustratedRoomVisualMode.colored,
      colors: colors,
      savedDesignId: savedId,
      savedName: savedName,
      baseline: baseline,
    );
  }

  final IllustratedRoomTemplate template;
  final IllustratedRoomVisualMode mode;
  final IllustratedRoomColors? colors;
  final String? savedDesignId;
  final String? savedName;
  final _IllustratedRoomDraftBaseline _baseline;

  String? get sourcePaletteId =>
      colors == null ? null : template.matchingPalette(colors!)?.id;

  bool get isDirty =>
      mode != _baseline.mode ||
      colors != _baseline.colors ||
      savedDesignId != _baseline.savedDesignId ||
      savedName != _baseline.savedName;

  bool get canSave => mode == IllustratedRoomVisualMode.colored && isDirty;

  String get visualStateLabel {
    if (mode == IllustratedRoomVisualMode.grayscale) return 'Black & white';
    return template.matchingPalette(colors!)?.name ?? 'Custom combination';
  }

  IllustratedRoomDraft applyPalette(String id) {
    final selected = template.palette(id);
    return _with(
      mode: IllustratedRoomVisualMode.colored,
      colors: selected.colors,
    );
  }

  IllustratedRoomDraft setSurfaceColor(
    IllustratedRoomSurface surface,
    RgbColor color,
  ) {
    final base = colors ?? template.defaultPalette.colors;
    return _with(
      mode: IllustratedRoomVisualMode.colored,
      colors: base.withColor(surface, color),
    );
  }

  IllustratedRoomDraft applyWallHandoff(RgbColor color) =>
      IllustratedRoomDraft.grayscale(
        template,
      ).setSurfaceColor(IllustratedRoomSurface.wall, color);

  IllustratedRoomDraft resetToGrayscale() =>
      _with(mode: IllustratedRoomVisualMode.grayscale, colors: null);

  IllustratedRoomDraft discardChanges() => IllustratedRoomDraft._(
    template: template,
    mode: _baseline.mode,
    colors: _baseline.colors,
    savedDesignId: _baseline.savedDesignId,
    savedName: _baseline.savedName,
    baseline: _baseline,
  );

  IllustratedRoomDraft markSaved({required String id, required String name}) {
    if (colors == null) {
      throw StateError('A grayscale room cannot be marked as saved');
    }
    return IllustratedRoomDraft.saved(
      template: template,
      colors: colors!,
      id: id,
      name: name,
    );
  }

  IllustratedRoomDraft renameSavedDesign({
    required String id,
    required String name,
  }) {
    if (savedDesignId != id) return this;
    final renamed = _requiredIdentity(name, 'name');
    return IllustratedRoomDraft._(
      template: template,
      mode: mode,
      colors: colors,
      savedDesignId: savedDesignId,
      savedName: renamed,
      baseline: _baseline.copyWith(savedName: renamed),
    );
  }

  IllustratedRoomDraft asUnsavedAfterDelete() {
    final fresh = IllustratedRoomDraft.grayscale(template);
    if (mode == IllustratedRoomVisualMode.grayscale) return fresh;
    return fresh._with(mode: mode, colors: colors);
  }

  @Deprecated('Use asUnsavedAfterDelete')
  IllustratedRoomDraft asUnsavedCopy() => asUnsavedAfterDelete();

  IllustratedRoomDraft _with({
    required IllustratedRoomVisualMode mode,
    required IllustratedRoomColors? colors,
  }) => IllustratedRoomDraft._(
    template: template,
    mode: mode,
    colors: colors,
    savedDesignId: savedDesignId,
    savedName: savedName,
    baseline: _baseline,
  );

  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomDraft &&
      template.id == other.template.id &&
      mode == other.mode &&
      colors == other.colors &&
      savedDesignId == other.savedDesignId &&
      savedName == other.savedName &&
      _baseline == other._baseline;

  @override
  int get hashCode => Object.hash(
    template.id,
    mode,
    colors,
    savedDesignId,
    savedName,
    _baseline,
  );
}

final class _IllustratedRoomDraftBaseline {
  const _IllustratedRoomDraftBaseline({
    required this.mode,
    required this.colors,
    required this.savedDesignId,
    required this.savedName,
  });

  final IllustratedRoomVisualMode mode;
  final IllustratedRoomColors? colors;
  final String? savedDesignId;
  final String? savedName;

  _IllustratedRoomDraftBaseline copyWith({String? savedName}) =>
      _IllustratedRoomDraftBaseline(
        mode: mode,
        colors: colors,
        savedDesignId: savedDesignId,
        savedName: savedName ?? this.savedName,
      );

  @override
  bool operator ==(Object other) =>
      other is _IllustratedRoomDraftBaseline &&
      mode == other.mode &&
      colors == other.colors &&
      savedDesignId == other.savedDesignId &&
      savedName == other.savedName;

  @override
  int get hashCode => Object.hash(mode, colors, savedDesignId, savedName);
}

String _requiredIdentity(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty');
  }
  return trimmed;
}
