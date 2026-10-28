import '../../../data/schema/repository_snapshot.dart';
import 'illustrated_room.dart';
import 'saved_room_design.dart';
import 'recoverable_room_draft.dart';

abstract interface class RoomDesignRepository {
  Future<RepositorySnapshot<SavedRoomDesign>> loadSnapshot();
  Future<List<SavedRoomDesign>> load();

  Future<SavedRoomDesign> save({
    String? existingId,
    required String name,
    required String templateId,
    required IllustratedRoomColors colors,
  });

  Future<SavedRoomDesign> saveNew({
    required String name,
    required String templateId,
    int templateRevision = 1,
    required RoomDesignSnapshot snapshot,
    RoomDesignSnapshot? activeBaseline,
  });
  Future<SavedRoomDesign> update(
    String existingId, {
    required String name,
    required RoomDesignSnapshot snapshot,
    required RoomDesignSnapshot? activeBaseline,
  });
  Future<SavedRoomDesign> saveCopy(String existingId, {required String name});
  Future<SavedRoomDesign> rename(String id, String name);
  Future<RepositorySnapshot<RecoverableRoomDraft>> loadDraftSnapshot();
  Future<void> saveDraft(RecoverableRoomDraft draft);

  /// Clears a failed barrier after restoring the last acknowledged bytes.
  /// The caller then explicitly reapplies its visible failed edit.
  Future<void> retry();

  Future<void> delete(String id);

  Future<void> close();
}

/// Prevents storage paths and persisted data from leaking into user messages.
final class RoomDesignStorageException implements Exception {
  const RoomDesignStorageException();

  @override
  String toString() => 'Unable to access saved room designs.';
}
