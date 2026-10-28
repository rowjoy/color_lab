import '../../../core/color/color_models.dart';
import 'illustrated_room.dart';
import 'illustrated_room_assignments.dart';
import 'illustrated_room_history.dart';
import 'illustrated_room_comparison.dart';

enum IllustratedRoomVisualMode { grayscale, colored }

final class IllustratedRoomDraft {
  const IllustratedRoomDraft._({
    required this.template,
    required this.membership,
    required this.history,
    required this.savedDesignId,
    required this.savedName,
    required _IllustratedRoomDraftBaseline baseline,
    this.pinnedBaseline,
    this.comparison = const IllustratedRoomComparison.current(),
  }) : _baseline = baseline;

  factory IllustratedRoomDraft.grayscale(
    IllustratedRoomTemplate template, {
    IllustratedRoomRegionMembership? membership,
  }) => IllustratedRoomDraft._(
    template: template,
    membership:
        membership ?? IllustratedRoomRegionMembership.forTemplate(template),
    history: IllustratedRoomHistory(),
    savedDesignId: null,
    savedName: null,
    baseline: const _IllustratedRoomDraftBaseline(
      assignments: null,
      savedDesignId: null,
      savedName: null,
    ),
  );

  factory IllustratedRoomDraft.saved({
    required IllustratedRoomTemplate template,
    required IllustratedRoomColors colors,
    required String id,
    required String name,
    IllustratedRoomRegionMembership? membership,
  }) {
    final savedId = _requiredIdentity(id, 'id');
    final savedName = _requiredIdentity(name, 'name');
    final contract =
        membership ?? IllustratedRoomRegionMembership.forTemplate(template);
    final assignments = IllustratedRoomAssignments.fromColors(
      colors,
      membership: contract,
    );
    return IllustratedRoomDraft._(
      template: template,
      membership: contract,
      history: IllustratedRoomHistory(initial: assignments),
      savedDesignId: savedId,
      savedName: savedName,
      baseline: _IllustratedRoomDraftBaseline(
        assignments: assignments,
        savedDesignId: savedId,
        savedName: savedName,
      ),
    );
  }

  /// Rebuilds durable state; undo history and temporary display are session-only.
  factory IllustratedRoomDraft.recovered({
    required IllustratedRoomTemplate template,
    required IllustratedRoomAssignments? assignments,
    required IllustratedRoomAssignments? savedAssignments,
    required IllustratedRoomAssignments? pinnedBaseline,
    required String? savedDesignId,
    required String? savedName,
  }) {
    final membership = IllustratedRoomRegionMembership.forTemplate(template);
    for (final snapshot in [assignments, savedAssignments, pinnedBaseline]) {
      if (snapshot != null && snapshot.membership != membership) {
        throw ArgumentError('Snapshot does not belong to this template.');
      }
    }
    return IllustratedRoomDraft._(
      template: template,
      membership: membership,
      history: IllustratedRoomHistory(initial: assignments),
      savedDesignId: savedDesignId,
      savedName: savedName,
      pinnedBaseline: pinnedBaseline,
      baseline: _IllustratedRoomDraftBaseline(
        assignments: savedAssignments,
        savedDesignId: savedDesignId,
        savedName: savedName,
      ),
    );
  }

  IllustratedRoomAssignments? get savedAssignments => _baseline.assignments;

  final IllustratedRoomTemplate template;
  final IllustratedRoomRegionMembership membership;
  final IllustratedRoomHistory history;
  final String? savedDesignId;
  final String? savedName;
  final _IllustratedRoomDraftBaseline _baseline;

  /// Comparison snapshots and temporary presentation never enter edit history.
  final IllustratedRoomAssignments? pinnedBaseline;
  final IllustratedRoomComparison comparison;
  bool get temporaryGrayscale =>
      comparison.view == IllustratedRoomComparisonView.grayscale;

  IllustratedRoomAssignments? get assignments => history.current;
  IllustratedRoomAssignments? get displayAssignments =>
      comparison.isActive ? comparison.snapshot : assignments;
  IllustratedRoomVisualMode get displayMode => displayAssignments == null
      ? IllustratedRoomVisualMode.grayscale
      : IllustratedRoomVisualMode.colored;
  IllustratedRoomVisualMode get mode => assignments == null
      ? IllustratedRoomVisualMode.grayscale
      : IllustratedRoomVisualMode.colored;

  /// Schema-v1 compatibility adapter until saved-design migration.
  IllustratedRoomColors? get colors => assignments?.toLegacyColors();

  String? get sourcePaletteId =>
      assignments == null || assignments!.regionOverrides.isNotEmpty
      ? null
      : template.matchingPalette(colors!)?.id;

  bool get isDirty =>
      assignments != _baseline.assignments ||
      savedDesignId != _baseline.savedDesignId ||
      savedName != _baseline.savedName;

  bool get canSave => mode == IllustratedRoomVisualMode.colored && isDirty;

  String get visualStateLabel {
    final displayed = displayAssignments;
    if (displayed == null) return 'Black & white';
    return displayed.regionOverrides.isNotEmpty
        ? 'Custom combination'
        : template.matchingPalette(displayed.toLegacyColors())?.name ??
              'Custom combination';
  }

  IllustratedRoomDraft applyCompleteLook(IllustratedRoomColors colors) =>
      restoreSnapshot(
        IllustratedRoomAssignments.fromColors(colors, membership: membership),
      );

  IllustratedRoomDraft applyPalette(String id) =>
      applyCompleteLook(template.palette(id).colors);

  IllustratedRoomDraft setRegionColor(String regionId, RgbColor color) =>
      restoreSnapshot(_seededAssignments.setRegionColor(regionId, color));

  IllustratedRoomDraft setGroupColor(String groupId, RgbColor color) =>
      restoreSnapshot(_seededAssignments.setGroupColor(groupId, color));

  IllustratedRoomAssignments get _seededAssignments =>
      assignments ??
      IllustratedRoomAssignments.fromColors(
        template.defaultPalette.colors,
        membership: membership,
      );

  IllustratedRoomDraft setSurfaceColor(
    IllustratedRoomSurface surface,
    RgbColor color,
  ) => setGroupColor(switch (surface) {
    IllustratedRoomSurface.wall => 'walls',
    IllustratedRoomSurface.ceiling => 'ceiling',
    IllustratedRoomSurface.floor => 'floor',
    IllustratedRoomSurface.furniture => 'furniture',
  }, color);

  IllustratedRoomDraft applyWallHandoff(RgbColor color) =>
      IllustratedRoomDraft.grayscale(
        template,
        membership: membership,
      ).setSurfaceColor(IllustratedRoomSurface.wall, color);

  IllustratedRoomDraft resetToGrayscale() => restoreSnapshot(null);

  IllustratedRoomDraft restoreSnapshot(IllustratedRoomAssignments? snapshot) {
    if (snapshot != null && snapshot.membership != membership) {
      throw ArgumentError.value(
        snapshot,
        'snapshot',
        'Region membership must match the draft',
      );
    }
    return _copy(
      history: history.record(snapshot),
      comparison: const IllustratedRoomComparison.current(),
    );
  }

  IllustratedRoomDraft undo() => _copy(
    history: history.undo(),
    comparison: const IllustratedRoomComparison.current(),
  );
  IllustratedRoomDraft redo() => _copy(
    history: history.redo(),
    comparison: const IllustratedRoomComparison.current(),
  );

  IllustratedRoomDraft pinBaseline() => assignments == null
      ? this
      : _copy(
          pinnedBaseline: assignments!.copyWith(),
          replacePinnedBaseline: true,
        );

  IllustratedRoomDraft showPinnedBaseline() => pinnedBaseline == null
      ? this
      : _copy(
          comparison: IllustratedRoomComparison.snapshot(
            IllustratedRoomComparisonView.baseline,
            pinnedBaseline,
          ),
        );

  IllustratedRoomDraft setComparisonVariant(
    IllustratedRoomAssignments snapshot,
  ) {
    if (snapshot.membership != membership) {
      throw ArgumentError('Comparison belongs to a different room.');
    }
    return _copy(
      comparison: IllustratedRoomComparison.snapshot(
        IllustratedRoomComparisonView.variant,
        snapshot,
      ),
    );
  }

  /// Original means the last saved edit baseline, or B&W for a new design.
  IllustratedRoomDraft showTemporaryOriginal() => _copy(
    comparison: IllustratedRoomComparison.snapshot(
      IllustratedRoomComparisonView.original,
      savedAssignments,
    ),
  );

  IllustratedRoomDraft showTemporaryGrayscale() => _copy(
    comparison: IllustratedRoomComparison.snapshot(
      IllustratedRoomComparisonView.grayscale,
      null,
    ),
  );
  IllustratedRoomDraft clearComparison() => comparison.isActive
      ? _copy(comparison: const IllustratedRoomComparison.current())
      : this;

  /// Used when asynchronous recovery reconciles durable content beneath a
  /// presentation-only choice made while storage was loading.
  IllustratedRoomDraft withComparison(IllustratedRoomComparison value) {
    if (value.snapshot != null && value.snapshot!.membership != membership) {
      throw ArgumentError('Comparison belongs to a different room.');
    }
    return _copy(comparison: value);
  }

  IllustratedRoomDraft discardChanges() => IllustratedRoomDraft._(
    template: template,
    membership: membership,
    history: IllustratedRoomHistory(initial: _baseline.assignments),
    savedDesignId: _baseline.savedDesignId,
    savedName: _baseline.savedName,
    baseline: _baseline,
    pinnedBaseline: pinnedBaseline,
  );

  IllustratedRoomDraft markSaved({required String id, required String name}) {
    if (assignments == null) {
      throw StateError('A grayscale room cannot be marked as saved');
    }
    final savedId = _requiredIdentity(id, 'id');
    final savedName = _requiredIdentity(name, 'name');
    return IllustratedRoomDraft._(
      template: template,
      membership: membership,
      history: history,
      savedDesignId: savedId,
      savedName: savedName,
      baseline: _IllustratedRoomDraftBaseline(
        assignments: assignments,
        savedDesignId: savedId,
        savedName: savedName,
      ),
      pinnedBaseline: pinnedBaseline,
      comparison: comparison,
    );
  }

  IllustratedRoomDraft renameSavedDesign({
    required String id,
    required String name,
  }) {
    if (savedDesignId != id) return this;
    final renamed = _requiredIdentity(name, 'name');
    return _copy(
      savedName: renamed,
      baseline: _baseline.copyWith(savedName: renamed),
    );
  }

  IllustratedRoomDraft asUnsavedAfterDelete() => IllustratedRoomDraft._(
    template: template,
    membership: membership,
    history: history,
    savedDesignId: null,
    savedName: null,
    baseline: const _IllustratedRoomDraftBaseline(
      assignments: null,
      savedDesignId: null,
      savedName: null,
    ),
    pinnedBaseline: pinnedBaseline,
    comparison: comparison,
  );

  @Deprecated('Use asUnsavedAfterDelete')
  IllustratedRoomDraft asUnsavedCopy() => asUnsavedAfterDelete();

  IllustratedRoomDraft _copy({
    IllustratedRoomHistory? history,
    String? savedName,
    _IllustratedRoomDraftBaseline? baseline,
    IllustratedRoomAssignments? pinnedBaseline,
    bool replacePinnedBaseline = false,
    IllustratedRoomComparison? comparison,
  }) => IllustratedRoomDraft._(
    template: template,
    membership: membership,
    history: history ?? this.history,
    savedDesignId: savedDesignId,
    savedName: savedName ?? this.savedName,
    baseline: baseline ?? _baseline,
    pinnedBaseline: replacePinnedBaseline
        ? pinnedBaseline
        : this.pinnedBaseline,
    comparison: comparison ?? this.comparison,
  );

  /// Content equality deliberately excludes navigation/history/comparison state.
  /// Returning to the same saved contents clears dirty state regardless of path.
  @override
  bool operator ==(Object other) =>
      other is IllustratedRoomDraft &&
      template.id == other.template.id &&
      membership == other.membership &&
      assignments == other.assignments &&
      savedDesignId == other.savedDesignId &&
      savedName == other.savedName &&
      _baseline == other._baseline;

  @override
  int get hashCode => Object.hash(
    template.id,
    membership,
    assignments,
    savedDesignId,
    savedName,
    _baseline,
  );
}

final class _IllustratedRoomDraftBaseline {
  const _IllustratedRoomDraftBaseline({
    required this.assignments,
    required this.savedDesignId,
    required this.savedName,
  });

  final IllustratedRoomAssignments? assignments;
  final String? savedDesignId;
  final String? savedName;

  _IllustratedRoomDraftBaseline copyWith({String? savedName}) =>
      _IllustratedRoomDraftBaseline(
        assignments: assignments,
        savedDesignId: savedDesignId,
        savedName: savedName ?? this.savedName,
      );

  @override
  bool operator ==(Object other) =>
      other is _IllustratedRoomDraftBaseline &&
      assignments == other.assignments &&
      savedDesignId == other.savedDesignId &&
      savedName == other.savedName;

  @override
  int get hashCode => Object.hash(assignments, savedDesignId, savedName);
}

String _requiredIdentity(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'Must not be empty');
  }
  return trimmed;
}
