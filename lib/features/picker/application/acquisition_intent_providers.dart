import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../data/db/hive_acquisition_intent_store.dart';
import '../domain/acquisition_intent_store.dart';

/// Resolves the final app-private directory exactly once.
final acquisitionStorageDirectoryProvider = FutureProvider<Directory>((
  ref,
) async {
  final root = await getApplicationDocumentsDirectory();
  return Directory('${root.path}/color_lab');
}, retry: (retryCount, error) => null);

final acquisitionIntentStoreFactoryProvider =
    Provider<Future<AcquisitionIntentStore> Function(String)>(
      (ref) =>
          (directory) => HiveAcquisitionIntentStore.open(directory: directory),
    );

final acquisitionIntentStoreProvider = FutureProvider<AcquisitionIntentStore>((
  ref,
) async {
  final directory = await ref.watch(acquisitionStorageDirectoryProvider.future);
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
