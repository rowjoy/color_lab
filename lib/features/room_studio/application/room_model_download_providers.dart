import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_model_store.dart';

final roomModelStoreProvider = Provider<RoomModelStore>((ref) {
  final store = RoomModelStore();
  ref.onDispose(() => unawaited(store.close()));
  return store;
});

// Compatibility entry for explicit preparation only. Bootstrap does not watch
// this provider; photo setup requests downloads through its controller.
final roomModelStartupProvider = FutureProvider<void>(
  (ref) => ref.watch(roomModelStoreProvider).prepare(),
  retry: (retryCount, error) => null,
);

final roomModelDownloadProgressProvider =
    StreamProvider<RoomModelDownloadProgress>((ref) {
      final store = ref.watch(roomModelStoreProvider);
      return Stream.multi((controller) {
        final subscription = store.changes.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        controller.add(store.progress);
        controller.onCancel = subscription.cancel;
      });
    });
