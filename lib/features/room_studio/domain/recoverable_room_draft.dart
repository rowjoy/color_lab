import 'illustrated_room.dart';
import 'illustrated_room_assignments.dart';
import 'illustrated_room_draft.dart';
import 'saved_room_design.dart';

/// One acknowledged local draft, independent of saved library rows.
final class RecoverableRoomDraft {
  RecoverableRoomDraft({
    required this.templateId,
    this.templateRevision = 1,
    required this.visible,
    required this.activeBaseline,
    required this.savedSnapshot,
    required this.savedDesignId,
    required this.savedName,
    required DateTime updatedAt,
  }) : updatedAt = updatedAt.toUtc() {
    roomStorageIdentity(templateId);
    if (templateRevision < 1 ||
        (savedDesignId == null) != (savedName == null) ||
        (savedDesignId == null) != (savedSnapshot == null)) {
      throw ArgumentError('Invalid recoverable identity.');
    }
    if (savedDesignId case final id?) {
      roomStorageIdentity(id);
      if (savedName!.trim() != savedName ||
          savedName!.isEmpty ||
          savedName!.runes.length > 60) {
        throw ArgumentError('Invalid recoverable name.');
      }
    }
  }
  factory RecoverableRoomDraft.fromDraft(
    IllustratedRoomDraft draft, {
    required DateTime updatedAt,
  }) => RecoverableRoomDraft(
    templateId: draft.template.id,
    visible: _snapshot(draft.assignments),
    activeBaseline: _snapshot(draft.pinnedBaseline),
    savedSnapshot: _snapshot(draft.savedAssignments),
    savedDesignId: draft.savedDesignId,
    savedName: draft.savedName,
    updatedAt: updatedAt,
  );
  final String templateId;
  final int templateRevision;
  final RoomDesignSnapshot? visible;
  final RoomDesignSnapshot? activeBaseline;
  final RoomDesignSnapshot? savedSnapshot;
  final String? savedDesignId;
  final String? savedName;
  final DateTime updatedAt;

  /// Metadata-only edits preserve snapshots/revisions unknown to this app.
  RecoverableRoomDraft withSavedName(String name) => RecoverableRoomDraft(
    templateId: templateId,
    templateRevision: templateRevision,
    visible: visible,
    activeBaseline: activeBaseline,
    savedSnapshot: savedSnapshot,
    savedDesignId: savedDesignId,
    savedName: name,
    updatedAt: updatedAt,
  );
  RecoverableRoomDraft withoutSavedDesign() => RecoverableRoomDraft(
    templateId: templateId,
    templateRevision: templateRevision,
    visible: visible,
    activeBaseline: activeBaseline,
    savedSnapshot: null,
    savedDesignId: null,
    savedName: null,
    updatedAt: updatedAt,
  );
  Map<String, Object?> toMap() => Map.unmodifiable({
    'version': 2,
    'templateId': templateId,
    'templateRevision': templateRevision,
    'visible': visible?.toMap(),
    'activeBaseline': activeBaseline?.toMap(),
    'savedSnapshot': savedSnapshot?.toMap(),
    'savedDesignId': savedDesignId,
    'savedName': savedName,
    'updatedAt': updatedAt.toIso8601String(),
  });
  factory RecoverableRoomDraft.fromMap(Map<dynamic, dynamic> map) {
    const keys = {
      'version',
      'templateId',
      'templateRevision',
      'visible',
      'activeBaseline',
      'savedSnapshot',
      'savedDesignId',
      'savedName',
      'updatedAt',
    };
    if (map.length != keys.length ||
        !map.keys.every(keys.contains) ||
        map['version'] is! int ||
        map['version'] != 2 ||
        map['templateRevision'] is! int ||
        map['templateId'] is! String ||
        map['updatedAt'] is! String ||
        [
          'savedDesignId',
          'savedName',
        ].any((k) => map[k] != null && map[k] is! String)) {
      throw const FormatException('Invalid recoverable draft schema.');
    }
    RoomDesignSnapshot? snapshot(String key) {
      final value = map[key];
      if (value == null) return null;
      if (value is! Map) {
        throw const FormatException('Invalid recoverable snapshot.');
      }
      return RoomDesignSnapshot.fromMap(value);
    }

    try {
      return RecoverableRoomDraft(
        templateId: map['templateId'] as String,
        templateRevision: map['templateRevision'] as int,
        visible: snapshot('visible'),
        activeBaseline: snapshot('activeBaseline'),
        savedSnapshot: snapshot('savedSnapshot'),
        savedDesignId: map['savedDesignId'] as String?,
        savedName: map['savedName'] as String?,
        updatedAt: roomCanonicalUtc(map['updatedAt'] as String),
      );
    } on ArgumentError {
      throw const FormatException('Invalid recoverable draft metadata.');
    }
  }
  IllustratedRoomDraft restore(IllustratedRoomTemplate template) {
    if (template.id != templateId || templateRevision != 1) {
      throw ArgumentError('Unsupported template revision.');
    }
    return IllustratedRoomDraft.recovered(
      template: template,
      assignments: visible?.materializeForTemplate(
        template,
        templateRevision: templateRevision,
      ),
      savedAssignments: savedSnapshot?.materializeForTemplate(
        template,
        templateRevision: templateRevision,
      ),
      pinnedBaseline: activeBaseline?.materializeForTemplate(
        template,
        templateRevision: templateRevision,
      ),
      savedDesignId: savedDesignId,
      savedName: savedName,
    );
  }
}

RoomDesignSnapshot? _snapshot(IllustratedRoomAssignments? assignments) =>
    assignments == null
    ? null
    : RoomDesignSnapshot.fromAssignments(assignments);
