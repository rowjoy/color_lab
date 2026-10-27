import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/hive_acquisition_intent_store.dart';
import '../../../data/storage/app_storage_directory.dart';
import '../domain/acquisition_intent_store.dart';

final acquisitionStorageDirectoryProvider = appStorageDirectoryProvider;

final acquisitionIntentStoreFactoryProvider =
    Provider<Future<AcquisitionIntentStore> Function(String)>(
      (ref) =>
          (directory) => HiveAcquisitionIntentStore.open(directory: directory),
    );

final acquisitionIntentStoreProvider = FutureProvider<AcquisitionIntentStore>((
  ref,
) async {
  final directory = await ref.watch(appStorageDirectoryProvider.future);
  if (!ref.mounted) throw StateError('Acquisition storage was disposed.');
  final store = await ref.watch(acquisitionIntentStoreFactoryProvider)(
    directory.path,
  );
  if (!ref.mounted) {
    await store.close();
    throw StateError('Acquisition storage was disposed.');
  }
  ref.onDispose(() {
    unawaited(
      store.close().catchError((Object error, StackTrace stack) {
        debugPrint('Acquisition storage could not be closed cleanly.');
      }),
    );
  });
  return store;
}, retry: (retryCount, error) => null);
