import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/hive_room_design_repository.dart';
import '../../../data/schema/corrupt_record.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../domain/illustrated_room.dart';
import '../domain/room_design_repository.dart';
import '../domain/saved_room_design.dart';
import 'illustrated_room_draft_store.dart';

final roomDesignStorageDirectoryProvider = appStorageDirectoryProvider;

final roomDesignRepositoryProvider = FutureProvider<RoomDesignRepository>((
  ref,
) async {
  final storage = await ref.watch(appStorageDirectoryProvider.future);
  if (!ref.mounted) {
    throw StateError('Room designs were disposed during initialization.');
  }
  final directory = resolveAppStorageDirectory(storage);
  final repository = await HiveRoomDesignRepository.open(
    directory: directory.path,
  );
  if (!ref.mounted) {
    await repository.close();
    throw StateError('Room designs were disposed during initialization.');
  }
  ref.onDispose(() {
    unawaited(
      repository.close().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Room designs could not be closed cleanly.');
      }),
    );
  });
  return repository;
}, retry: (retryCount, error) => null);

final savedRoomDesignsProvider =
    AsyncNotifierProvider<SavedRoomDesignsController, List<SavedRoomDesign>>(
      SavedRoomDesignsController.new,
      retry: (retryCount, error) => null,
    );

final roomDesignCorruptRecordsProvider = Provider<List<CorruptRecord>>((ref) {
  ref.watch(savedRoomDesignsProvider);
  return ref.watch(savedRoomDesignsProvider.notifier).corruptRecords;
});

class SavedRoomDesignsController extends AsyncNotifier<List<SavedRoomDesign>> {
  Future<void> _pending = Future<void>.value();
  List<CorruptRecord> _corruptRecords = const [];
  bool _retryRequested = false;
  int _generation = 0;

  List<CorruptRecord> get corruptRecords => _corruptRecords;

  @override
  Future<List<SavedRoomDesign>> build() async {
    final generation = ++_generation;
    final repository = await ref.watch(roomDesignRepositoryProvider.future);
    if (!ref.mounted) {
      throw StateError('Room designs are no longer available.');
    }
    if (_retryRequested) {
      await repository.retry();
      _retryRequested = false;
    }
    final snapshot = await repository.loadSnapshot();
    if (!ref.mounted || generation != _generation) {
      throw StateError('Stale room library load.');
    }
    _corruptRecords = List.unmodifiable(snapshot.corruptRecords);
    return List.unmodifiable(snapshot.records);
  }

  Future<T> _mutate<T>(Future<T> Function(RoomDesignRepository) operation) {
    if (!ref.mounted) {
      return Future.error(StateError('Room designs are no longer available.'));
    }
    final result = Completer<T>();
    _pending = _pending.then((_) async {
      try {
        if (!ref.mounted) {
          throw StateError('Room designs are no longer available.');
        }
        // An unreadable initial library must be retried before any edit.
        await future;
        if (!ref.mounted) {
          throw StateError('Room designs are no longer available.');
        }
        final repository = await ref.read(roomDesignRepositoryProvider.future);
        if (!ref.mounted) {
          throw StateError('Room designs are no longer available.');
        }
        final generation = _generation;
        final value = await operation(repository);
        if (!ref.mounted || generation != _generation) {
          throw StateError('Room designs are no longer available.');
        }
        final snapshot = await repository.loadSnapshot();
        if (!ref.mounted || generation != _generation) {
          throw StateError('Room designs are no longer available.');
        }
        _corruptRecords = List.unmodifiable(snapshot.corruptRecords);
        state = AsyncData(List<SavedRoomDesign>.unmodifiable(snapshot.records));
        result.complete(value);
      } catch (error, stackTrace) {
        // Keep the last committed list. The caller presents friendly feedback.
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<SavedRoomDesign> saveDesign({
    String? existingId,
    required String name,
    required String templateId,
    required IllustratedRoomColors colors,
  }) => _mutate(
    (repository) => repository.save(
      existingId: existingId,
      name: name,
      templateId: templateId,
      colors: colors,
    ),
  );

  Future<SavedRoomDesign> saveNew({
    required String name,
    required String templateId,
    int templateRevision = 1,
    required RoomDesignSnapshot snapshot,
    RoomDesignSnapshot? activeBaseline,
  }) => _mutate(
    (repository) => repository.saveNew(
      name: name,
      templateId: templateId,
      templateRevision: templateRevision,
      snapshot: snapshot,
      activeBaseline: activeBaseline,
    ),
  );

  // AsyncNotifier owns update(callback); use an unambiguous design action here.
  Future<SavedRoomDesign> updateDesign(
    String existingId, {
    required String name,
    required RoomDesignSnapshot snapshot,
    required RoomDesignSnapshot? activeBaseline,
  }) => _mutate((repository) async {
    final saved = await repository.update(
      existingId,
      name: name,
      snapshot: snapshot,
      activeBaseline: activeBaseline,
    );
    if (ref.mounted) {
      ref
          .read(illustratedRoomDraftStoreProvider)
          .asData
          ?.value
          .reconcileSavedIdentity(existingId, name: saved.name);
    }
    return saved;
  });
  Future<SavedRoomDesign> saveCopy(String existingId, {required String name}) =>
      _mutate((repository) => repository.saveCopy(existingId, name: name));
  Future<SavedRoomDesign> rename(String id, String name) =>
      _mutate((repository) async {
        final renamed = await repository.rename(id, name);
        if (ref.mounted) {
          ref
              .read(illustratedRoomDraftStoreProvider)
              .asData
              ?.value
              .reconcileSavedIdentity(id, name: renamed.name);
        }
        return renamed;
      });
  Future<void> delete(String id) => _mutate((repository) async {
    await repository.delete(id);
    if (ref.mounted) {
      ref
          .read(illustratedRoomDraftStoreProvider)
          .asData
          ?.value
          .reconcileSavedIdentity(id);
    }
  });
  Future<SavedRoomDesign> renameDesign(String id, String name) =>
      rename(id, name);
  Future<void> deleteDesign(String id) => delete(id);

  void retry() {
    if (!ref.mounted) return;
    if (ref.read(roomDesignStorageDirectoryProvider).hasError) {
      ref.invalidate(roomDesignStorageDirectoryProvider);
    }
    if (ref.read(roomDesignRepositoryProvider).hasError) {
      ref.invalidate(roomDesignRepositoryProvider);
    }
    _retryRequested = true;
    ref.invalidateSelf();
  }
}
