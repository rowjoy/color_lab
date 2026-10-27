import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/room_mask_controller.dart';
import '../application/room_project_session_controller.dart';
import '../application/room_projects_providers.dart';
import '../domain/room_mask_state.dart';
import '../domain/room_project.dart';
import '../domain/room_project_repository.dart';

enum RoomProjectActionFailure {
  busy,
  unsaved,
  conflict,
  unavailable,
  storage,
  invalidName,
  limit,
}

/// Only safe, localizable reasons cross the action/presentation boundary.
final class RoomProjectActionException implements Exception {
  const RoomProjectActionException(this.failure);
  final RoomProjectActionFailure failure;
}

final roomProjectActionClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

final roomProjectActionsProvider = NotifierProvider<RoomProjectActions, bool>(
  RoomProjectActions.new,
);

class RoomProjectActions extends Notifier<bool> {
  @override
  bool build() => false;

  Future<T> _run<T>(Future<T> Function() action) async {
    if (state) {
      throw const RoomProjectActionException(RoomProjectActionFailure.busy);
    }
    state = true;
    try {
      return await action();
    } catch (error) {
      throw switch (error) {
        RoomProjectActionException() => error,
        RoomProjectUnsavedChanges() => const RoomProjectActionException(
          RoomProjectActionFailure.unsaved,
        ),
        RoomProjectConflict() => const RoomProjectActionException(
          RoomProjectActionFailure.conflict,
        ),
        RoomProjectStorageException(:final failure) =>
          RoomProjectActionException(switch (failure) {
            RoomProjectStorageFailure.corrupt ||
            RoomProjectStorageFailure.invalidId ||
            RoomProjectStorageFailure.closed =>
              RoomProjectActionFailure.unavailable,
            RoomProjectStorageFailure.limit => RoomProjectActionFailure.limit,
            RoomProjectStorageFailure.io => RoomProjectActionFailure.storage,
          }),
        _ => const RoomProjectActionException(RoomProjectActionFailure.storage),
      };
    } finally {
      if (ref.mounted) state = false;
    }
  }

  void _live() {
    if (!ref.mounted) {
      throw const RoomProjectStorageException(RoomProjectStorageFailure.closed);
    }
  }

  void _requireSaved() {
    _live();
    if (ref.read(roomProjectSessionProvider)?.hasUnsavedChanges ?? false) {
      throw const RoomProjectUnsavedChanges();
    }
    final editor = ref.read(roomMaskProvider);
    if (editor.editBusy ||
        editor.candidate != null ||
        editor.stage == RoomMaskStage.acquiring ||
        editor.stage == RoomMaskStage.analyzing) {
      throw const RoomProjectActionException(RoomProjectActionFailure.busy);
    }
  }

  String _name(String name) {
    final normalized = name.trim();
    if (!RoomProjectLimits.validName(normalized)) {
      throw const RoomProjectActionException(
        RoomProjectActionFailure.invalidName,
      );
    }
    return normalized;
  }

  Future<RoomProjectReadResult> _source(RoomProjectSummary project) async {
    final repository = await ref.read(roomProjectRepositoryProvider.future);
    _requireSaved();
    final result = await repository.read(project.projectId);
    _requireSaved();
    if (result == null) {
      throw const RoomProjectActionException(
        RoomProjectActionFailure.unavailable,
      );
    }
    if (result.acknowledgedRevision != project.acknowledgedRevision) {
      throw const RoomProjectActionException(RoomProjectActionFailure.conflict);
    }
    final session = ref.read(roomProjectSessionProvider);
    if (session?.projectId == project.projectId &&
        session!.acknowledgedRevision != result.acknowledgedRevision) {
      throw const RoomProjectActionException(RoomProjectActionFailure.conflict);
    }
    return result;
  }

  Future<RoomProjectSnapshot> rename(
    RoomProjectSummary project,
    String name,
  ) => _run(() async {
    final normalized = _name(name);
    _requireSaved();
    final now = ref.read(roomProjectActionClockProvider)().toUtc();
    if (ref.read(roomProjectSessionProvider)?.projectId == project.projectId) {
      final saved = await ref
          .read(roomProjectSessionProvider.notifier)
          .renameProject(
            project.projectId,
            normalized,
            expectedRevision: project.acknowledgedRevision,
            updatedAt: now,
          );
      _live();
      ref.invalidate(roomProjectsProvider);
      return saved;
    }
    final source = await _source(project);
    final snapshot = source.snapshot;
    final repository = await ref.read(roomProjectRepositoryProvider.future);
    _requireSaved();
    final saved = await repository.save(
      snapshot.copyWith(
        name: normalized,
        updatedAt: now.isBefore(snapshot.updatedAt) ? snapshot.updatedAt : now,
      ),
      expectedRevision: source.acknowledgedRevision,
    );
    _live();
    ref.invalidate(roomProjectsProvider);
    return saved;
  });

  Future<RoomProjectSnapshot> duplicate(
    RoomProjectSummary project, {
    required String name,
  }) => _run(() async {
    final normalized = _name(name);
    _requireSaved();
    final source = (await _source(project)).snapshot;
    final repository = await ref.read(roomProjectRepositoryProvider.future);
    final inventory = await repository.listSnapshot();
    _requireSaved();
    final ids = {
      source.projectId,
      source.photoId,
      for (final item in inventory.records) ...[item.projectId, item.photoId],
    };
    final id = ref.read(roomProjectIdFactoryProvider);
    final now = ref.read(roomProjectActionClockProvider)().toUtc();
    for (var attempt = 0; attempt < 5; attempt++) {
      final projectId = id();
      final photoId = id();
      if (!RoomProjectLimits.validId(projectId) ||
          !RoomProjectLimits.validId(photoId) ||
          projectId == photoId ||
          ids.contains(projectId) ||
          ids.contains(photoId)) {
        continue;
      }
      _requireSaved();
      try {
        final saved = await repository.save(
          source.copyWith(
            projectId: projectId,
            photoId: photoId,
            name: normalized,
            revision: 0,
            createdAt: now,
            updatedAt: now,
          ),
          expectedRevision: 0,
        );
        _live();
        ref.invalidate(roomProjectsProvider);
        return saved;
      } on RoomProjectConflict {
        // Another creation won this ID. Never overwrite or adopt its token.
        ids.add(projectId);
      }
    }
    throw const RoomProjectActionException(RoomProjectActionFailure.limit);
  });

  Future<void> delete(String projectId, {required bool confirmed}) async {
    if (!confirmed) return;
    await _run(() async {
      final repository = await ref.read(roomProjectRepositoryProvider.future);
      _live();
      if (ref.read(roomProjectSessionProvider)?.projectId == projectId) {
        await ref.read(roomMaskProvider.notifier).closeProject();
      }
      _live();
      await repository.delete(projectId);
      if (ref.mounted) ref.invalidate(roomProjectsProvider);
    });
  }

  Future<bool> open(String projectId, {bool Function()? isCurrent}) =>
      _run(() async {
        if (!RoomProjectLimits.validId(projectId)) {
          throw const RoomProjectActionException(
            RoomProjectActionFailure.unavailable,
          );
        }
        if (!(isCurrent?.call() ?? true)) return false;
        final editor = ref.read(roomMaskProvider.notifier);
        if (editor.continueProject(projectId)) return true;
        _requireSaved();
        final opened = await editor.openProject(
          projectId,
          isCurrent: isCurrent,
          preserveCurrentOnFailure: true,
        );
        _live();
        if (!(isCurrent?.call() ?? true)) return false;
        if (!opened) {
          throw const RoomProjectActionException(
            RoomProjectActionFailure.unavailable,
          );
        }
        return true;
      });
}
