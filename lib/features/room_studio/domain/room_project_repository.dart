import '../../../data/schema/repository_snapshot.dart';
import 'room_project.dart';

abstract interface class RoomProjectRepository {
  Future<RepositorySnapshot<RoomProjectSummary>> listSnapshot();
  Future<RoomProjectReadResult?> read(String projectId);
  Future<RoomProjectSnapshot> save(
    RoomProjectSnapshot snapshot, {
    required int expectedRevision,
  });
  Future<void> delete(String projectId);
  Future<void> close();
}

enum RoomProjectStorageFailure { io, corrupt, closed, invalidId, limit }

/// Safe to retain in application state: no private paths or underlying errors.
final class RoomProjectStorageException implements Exception {
  const RoomProjectStorageException([
    this.failure = RoomProjectStorageFailure.io,
  ]);
  final RoomProjectStorageFailure failure;
}

final class RoomProjectConflict implements Exception {
  const RoomProjectConflict({
    required this.expectedRevision,
    required this.actualRevision,
  });
  final int expectedRevision;
  final int actualRevision;
}
