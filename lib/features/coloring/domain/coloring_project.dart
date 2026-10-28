import '../../../core/color/color_models.dart';
import 'coloring_edit.dart';
import 'drawing_definition.dart';

final class ColoringProject {
  ColoringProject({
    required this.id,
    required this.drawingId,
    required this.drawingRevision,
    required this.mode,
    required Map<String, RgbColor> assignments,
    required Set<String> guidedFilledRegionIds,
    required List<ColoringEdit> undoStack,
    required List<ColoringEdit> redoStack,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
  }) : assignments = Map.unmodifiable(assignments),
       guidedFilledRegionIds = Set.unmodifiable(guidedFilledRegionIds),
       undoStack = List.unmodifiable(_bounded(undoStack)),
       redoStack = List.unmodifiable(_bounded(redoStack)) {
    if (id.trim().isEmpty || drawingId.trim().isEmpty || drawingRevision < 1) {
      throw ArgumentError('Stable project and drawing identity required.');
    }
    if (!this.assignments.keys.toSet().containsAll(
      this.guidedFilledRegionIds,
    )) {
      throw ArgumentError('Guided completion must reference assigned regions.');
    }
    if (mode == ColoringMode.free && this.guidedFilledRegionIds.isNotEmpty) {
      throw ArgumentError('Free projects cannot contain guided progress.');
    }
    if (createdAt.isAfter(updatedAt)) {
      throw ArgumentError('Project timestamps are out of order.');
    }
  }

  factory ColoringProject.create({
    required String drawingId,
    required int drawingRevision,
    required ColoringMode mode,
    DateTime Function()? clock,
  }) {
    final now = (clock ?? DateTime.now)().toUtc();
    return ColoringProject(
      id: '$drawingId-${mode.name}-${now.microsecondsSinceEpoch}',
      drawingId: drawingId,
      drawingRevision: drawingRevision,
      mode: mode,
      assignments: const {},
      guidedFilledRegionIds: const {},
      undoStack: const [],
      redoStack: const [],
      completed: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory ColoringProject.fromMap(Object? value) {
    const keys = {
      'version',
      'id',
      'drawingId',
      'drawingRevision',
      'mode',
      'assignments',
      'guidedFilledRegionIds',
      'undoStack',
      'redoStack',
      'completed',
      'createdAt',
      'updatedAt',
    };
    if (value is! Map ||
        value.keys.toSet().difference(keys).isNotEmpty ||
        !keys.every(value.containsKey) ||
        value['version'] != 1 ||
        value['id'] is! String ||
        value['drawingId'] is! String ||
        value['drawingRevision'] is! int ||
        value['mode'] is! String ||
        value['assignments'] is! Map ||
        value['guidedFilledRegionIds'] is! List ||
        value['undoStack'] is! List ||
        value['redoStack'] is! List ||
        value['completed'] is! bool ||
        value['createdAt'] is! String ||
        value['updatedAt'] is! String) {
      throw const FormatException('Invalid coloring project.');
    }
    final mode = ColoringMode.values.where(
      (item) => item.name == value['mode'],
    );
    if (mode.length != 1) throw const FormatException('Unknown coloring mode.');
    try {
      return ColoringProject(
        id: value['id'] as String,
        drawingId: value['drawingId'] as String,
        drawingRevision: value['drawingRevision'] as int,
        mode: mode.single,
        assignments: _decodeAssignments(value['assignments'] as Map),
        guidedFilledRegionIds: (value['guidedFilledRegionIds'] as List).map((
          item,
        ) {
          if (item is! String) {
            throw const FormatException('Invalid guided region.');
          }
          return item;
        }).toSet(),
        undoStack: (value['undoStack'] as List)
            .map(ColoringEdit.fromMap)
            .toList(growable: false),
        redoStack: (value['redoStack'] as List)
            .map(ColoringEdit.fromMap)
            .toList(growable: false),
        completed: value['completed'] as bool,
        createdAt: DateTime.parse(value['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(value['updatedAt'] as String).toUtc(),
      );
    } on ArgumentError {
      throw const FormatException('Invalid coloring project invariant.');
    }
  }

  static List<ColoringEdit> _bounded(Iterable<ColoringEdit> edits) {
    final values = edits.toList(growable: false);
    return values.length <= 50 ? values : values.sublist(values.length - 50);
  }

  static Map<String, RgbColor> _decodeAssignments(Map<dynamic, dynamic> raw) {
    final assignments = <String, RgbColor>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! String) {
        throw const FormatException('Invalid coloring assignment.');
      }
      assignments[entry.key as String] = RgbColor.fromHex(
        entry.value as String,
      );
    }
    return assignments;
  }

  final String id;
  final String drawingId;
  final int drawingRevision;
  final ColoringMode mode;
  final Map<String, RgbColor> assignments;
  final Set<String> guidedFilledRegionIds;
  final List<ColoringEdit> undoStack;
  final List<ColoringEdit> redoStack;
  final bool completed;
  final DateTime createdAt;
  final DateTime updatedAt;

  ColoringProject fill(
    String regionId,
    RgbColor color, {
    bool guided = false,
    DateTime? now,
  }) {
    final before = assignments[regionId];
    if (before == color) return this;
    final edit = ColoringEdit(regionId: regionId, before: before, after: color);
    return copyWith(
      assignments: {...assignments, regionId: color},
      guidedFilledRegionIds: guided
          ? {...guidedFilledRegionIds, regionId}
          : guidedFilledRegionIds,
      undoStack: [...undoStack, edit],
      redoStack: const [],
      completed: false,
      updatedAt: (now ?? DateTime.now()).toUtc(),
    );
  }

  ColoringProject undo({DateTime? now}) {
    if (undoStack.isEmpty) return this;
    final edit = undoStack.last;
    final nextAssignments = Map<String, RgbColor>.of(assignments);
    if (edit.before == null) {
      nextAssignments.remove(edit.regionId);
    } else {
      nextAssignments[edit.regionId] = edit.before!;
    }
    return copyWith(
      assignments: nextAssignments,
      guidedFilledRegionIds: mode == ColoringMode.guided
          ? guidedFilledRegionIds.intersection(nextAssignments.keys.toSet())
          : const {},
      undoStack: undoStack.sublist(0, undoStack.length - 1),
      redoStack: [...redoStack, edit],
      completed: false,
      updatedAt: (now ?? DateTime.now()).toUtc(),
    );
  }

  ColoringProject redo({DateTime? now}) {
    if (redoStack.isEmpty) return this;
    final edit = redoStack.last;
    final nextAssignments = Map<String, RgbColor>.of(assignments);
    if (edit.after == null) {
      nextAssignments.remove(edit.regionId);
    } else {
      nextAssignments[edit.regionId] = edit.after!;
    }
    return copyWith(
      assignments: nextAssignments,
      guidedFilledRegionIds: mode == ColoringMode.guided
          ? {...guidedFilledRegionIds, edit.regionId}
          : const {},
      undoStack: [...undoStack, edit],
      redoStack: redoStack.sublist(0, redoStack.length - 1),
      completed: false,
      updatedAt: (now ?? DateTime.now()).toUtc(),
    );
  }

  ColoringProject copyWith({
    Map<String, RgbColor>? assignments,
    Set<String>? guidedFilledRegionIds,
    List<ColoringEdit>? undoStack,
    List<ColoringEdit>? redoStack,
    bool? completed,
    DateTime? updatedAt,
  }) => ColoringProject(
    id: id,
    drawingId: drawingId,
    drawingRevision: drawingRevision,
    mode: mode,
    assignments: assignments ?? this.assignments,
    guidedFilledRegionIds: guidedFilledRegionIds ?? this.guidedFilledRegionIds,
    undoStack: undoStack ?? this.undoStack,
    redoStack: redoStack ?? this.redoStack,
    completed: completed ?? this.completed,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    'version': 1,
    'id': id,
    'drawingId': drawingId,
    'drawingRevision': drawingRevision,
    'mode': mode.name,
    'assignments': {
      for (final entry in assignments.entries) entry.key: entry.value.hex,
    },
    'guidedFilledRegionIds': guidedFilledRegionIds.toList()..sort(),
    'undoStack': undoStack.map((edit) => edit.toMap()).toList(),
    'redoStack': redoStack.map((edit) => edit.toMap()).toList(),
    'completed': completed,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
