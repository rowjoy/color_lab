import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/hive_room_design_repository.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../domain/illustrated_room.dart';
import '../domain/room_design_repository.dart';
import '../domain/saved_room_design.dart';

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

class SavedRoomDesignsController extends AsyncNotifier<List<SavedRoomDesign>> {
  Future<void> _pending = Future<void>.value();

  @override
  Future<List<SavedRoomDesign>> build() async {
    final repository = await ref.watch(roomDesignRepositoryProvider.future);
    if (!ref.mounted) {
      throw StateError('Room designs are no longer available.');
    }
    return List.unmodifiable(await repository.load());
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
        final value = await operation(repository);
        if (!ref.mounted) {
          throw StateError('Room designs are no longer available.');
        }
        final designs = List<SavedRoomDesign>.unmodifiable(
          await repository.load(),
        );
        if (!ref.mounted) {
          throw StateError('Room designs are no longer available.');
        }
        state = AsyncData(designs);
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

  Future<SavedRoomDesign> renameDesign(String id, String name) =>
      _mutate((repository) async {
        final designs = await repository.load();
        SavedRoomDesign? target;
        for (final design in designs) {
          if (design.id == id) {
            target = design;
            break;
          }
        }
        if (target == null) throw const RoomDesignStorageException();
        return repository.save(
          existingId: target.id,
          name: name,
          templateId: target.templateId,
          colors: target.colors,
        );
      });

  Future<void> deleteDesign(String id) =>
      _mutate((repository) => repository.delete(id));

  void retry() {
    if (!ref.mounted) return;
    if (ref.read(roomDesignStorageDirectoryProvider).hasError) {
      ref.invalidate(roomDesignStorageDirectoryProvider);
    }
    if (ref.read(roomDesignRepositoryProvider).hasError) {
      ref.invalidate(roomDesignRepositoryProvider);
    }
    ref.invalidateSelf();
  }
}
