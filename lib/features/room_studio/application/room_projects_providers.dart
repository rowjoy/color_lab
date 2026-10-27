import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/files/file_room_project_repository.dart';
import '../../../data/schema/repository_snapshot.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/room_project.dart';
import '../domain/room_project_repository.dart';

/// 128 random bits, with no process-local counter or restart dependency.
/// Shared by project, photo and variant identities; injectable in tests.
final roomProjectIdFactoryProvider = Provider<String Function()>((ref) {
  final random = Random.secure();
  return () =>
      'room-${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
});

final roomProjectLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final device = PlatformDispatcher.instance.locale;
  final locale = AppLocalizations.supportedLocales.firstWhere(
    (supported) => supported.languageCode == device.languageCode,
    orElse: () => AppLocalizations.supportedLocales.first,
  );
  return lookupAppLocalizations(locale);
});

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
