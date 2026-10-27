import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/files/file_room_project_repository.dart';
import '../../../data/schema/repository_snapshot.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../domain/room_project.dart';
import '../domain/room_project_repository.dart';

final roomProjectRepositoryProvider = FutureProvider<RoomProjectRepository>((
  ref,
) async {
  final storage = await ref.watch(appStorageDirectoryProvider.future);
  if (!ref.mounted) {
    throw const RoomProjectStorageException(RoomProjectStorageFailure.closed);
  }
  final repository = await FileRoomProjectRepository.open(
    directory: resolveAppStorageDirectory(storage).path,
  );
  if (!ref.mounted) {
    await repository.close();
    throw const RoomProjectStorageException(RoomProjectStorageFailure.closed);
  }
  ref.onDispose(() {
    unawaited(
      repository.close().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Room projects could not be closed cleanly.');
      }),
    );
  });
  return repository;
}, retry: (retryCount, error) => null);

/// Invalidating the library refreshes values while its owner retains the queue.
final roomProjectsProvider =
    FutureProvider<RepositorySnapshot<RoomProjectSummary>>((ref) async {
      final repository = await ref.watch(roomProjectRepositoryProvider.future);
      if (!ref.mounted) {
        throw const RoomProjectStorageException(
          RoomProjectStorageFailure.closed,
        );
      }
      return repository.listSnapshot();
    }, retry: (retryCount, error) => null);
