import 'dart:async';

import 'package:color_lab/data/schema/repository_snapshot.dart';
import 'package:color_lab/features/room_studio/domain/room_project.dart';
import 'package:color_lab/features/room_studio/domain/room_project_repository.dart';

/// Session/controller double. Disk integrity and recovery are tested with the
/// actual file repository; this preserves its queue, CAS and close contract.
class InMemoryRoomProjectRepository implements RoomProjectRepository {
  InMemoryRoomProjectRepository({
    Iterable<RoomProjectSnapshot> initial = const [],
  }) : _projects = {for (final project in initial) project.projectId: project};

  final Map<String, RoomProjectSnapshot> _projects;
  Future<void> _pending = Future.value();
  Future<void>? _closing;

  /// Failure/gate controls remain in test support, never in production models.
  Object? saveError;
  Future<void> Function()? beforeSave;

  Future<T> _serialize<T>(FutureOr<T> Function() action) {
    if (_closing != null) {
      return Future.error(
        const RoomProjectStorageException(RoomProjectStorageFailure.closed),
      );
    }
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _checkId(String id) {
    if (!RoomProjectLimits.validId(id)) {
      throw const RoomProjectStorageException(
        RoomProjectStorageFailure.invalidId,
      );
    }
  }

  @override
  Future<RoomProjectReadResult?> read(String projectId) => _serialize(() {
    _checkId(projectId);
    final project = _projects[projectId];
    return project == null
        ? null
        : RoomProjectReadResult(
            snapshot: project,
            acknowledgedRevision: project.revision,
          );
  });

  @override
  Future<RepositorySnapshot<RoomProjectSummary>> listSnapshot() =>
      _serialize(() {
        final records =
            _projects.values
                .map(
                  (p) => RoomProjectSummary.fromReadResult(
                    RoomProjectReadResult(
                      snapshot: p,
                      acknowledgedRevision: p.revision,
                    ),
                  ),
                )
                .toList()
              ..sort((a, b) {
                final date = b.updatedAt.compareTo(a.updatedAt);
                return date == 0 ? a.projectId.compareTo(b.projectId) : date;
              });
        return RepositorySnapshot(records: records, corruptRecords: []);
      });

  @override
  Future<RoomProjectSnapshot> save(
    RoomProjectSnapshot snapshot, {
    required int expectedRevision,
  }) => _serialize(() async {
    await beforeSave?.call();
    if (saveError != null) throw saveError!;
    final actual = _projects[snapshot.projectId]?.revision ?? 0;
    if (actual != expectedRevision) {
      throw RoomProjectConflict(
        expectedRevision: expectedRevision,
        actualRevision: actual,
      );
    }
    if (actual >= RoomProjectLimits.maxRevisions) {
      throw const RoomProjectStorageException(RoomProjectStorageFailure.limit);
    }
    final committed = snapshot.copyWith(revision: actual + 1);
    _projects[snapshot.projectId] = committed;
    return committed;
  });

  @override
  Future<void> delete(String projectId) => _serialize(() {
    _checkId(projectId);
    _projects.remove(projectId);
  });

  @override
  Future<void> close() => _closing ??= _pending;
}
