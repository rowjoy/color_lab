import '../../../data/schema/repository_snapshot.dart';
import 'illustrated_room.dart';
import 'saved_room_design.dart';

abstract interface class RoomDesignRepository {
  Future<RepositorySnapshot<SavedRoomDesign>> loadSnapshot();
  Future<List<SavedRoomDesign>> load();

  Future<SavedRoomDesign> save({
    String? existingId,
    required String name,
    required String templateId,
    required IllustratedRoomColors colors,
  });

  Future<void> delete(String id);

  Future<void> close();
}

/// Prevents storage paths and persisted data from leaking into user messages.
final class RoomDesignStorageException implements Exception {
  const RoomDesignStorageException();

  @override
  String toString() => 'Unable to access saved room designs.';
}
