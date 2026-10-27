import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_model_store.dart';
import 'room_model_download_providers.dart';

enum RoomModelAvailability {
  notInstalled,
  checking,
  downloading,
  verifying,
  ready,
  failed,
  storageFull,
  cancelled,
}

final class RoomModelSetupState {
  const RoomModelSetupState({
    this.availability = RoomModelAvailability.notInstalled,
    required this.progress,
    this.canEnter = false,
  });
  final RoomModelAvailability availability;
  final RoomModelDownloadProgress progress;
  final bool canEnter;
  bool get busy =>
      availability == RoomModelAvailability.checking ||
      availability == RoomModelAvailability.downloading ||
      availability == RoomModelAvailability.verifying;
}

final roomModelSetupProvider =
    NotifierProvider<RoomModelSetupController, RoomModelSetupState>(
      RoomModelSetupController.new,
    );

class RoomModelSetupController extends Notifier<RoomModelSetupState> {
  late RoomModelStore _store;
  int _epoch = 0;
  bool _disposed = false;
  StreamSubscription<RoomModelDownloadProgress>? _subscription;

  @override
  RoomModelSetupState build() {
    _store = ref.watch(roomModelStoreProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _epoch++;
      unawaited(_subscription?.cancel());
      _store.cancel();
    });
    return RoomModelSetupState(progress: _store.progress);
  }

  bool _current(int epoch) => !_disposed && epoch == _epoch;

  Future<void> check() async {
    if (state.busy) return;
    final epoch = ++_epoch;
    state = RoomModelSetupState(
      availability: RoomModelAvailability.checking,
      progress: _store.progress,
    );
    try {
      final ready = await _store.check();
      if (_current(epoch)) {
        state = RoomModelSetupState(
          availability: ready
              ? RoomModelAvailability.ready
              : RoomModelAvailability.notInstalled,
          progress: _store.progress,
        );
      }
    } on RoomModelDownloadException catch (error) {
      if (_current(epoch)) _failure(error);
    }
  }

  Future<void> download() async {
    if (state.busy) return;
    final epoch = ++_epoch;
    state = RoomModelSetupState(
      availability: RoomModelAvailability.downloading,
      progress: _store.progress,
    );
    if (_subscription != null) await _subscription!.cancel();
    if (!_current(epoch)) return;
    _subscription = _store.changes.listen((progress) {
      if (!_current(epoch)) return;
      final availability = switch (progress.stage) {
        RoomModelDownloadStage.checking => RoomModelAvailability.checking,
        RoomModelDownloadStage.downloading => RoomModelAvailability.downloading,
        RoomModelDownloadStage.verifying => RoomModelAvailability.verifying,
        RoomModelDownloadStage.ready => RoomModelAvailability.ready,
        RoomModelDownloadStage.failed => RoomModelAvailability.failed,
        RoomModelDownloadStage.storageFull => RoomModelAvailability.storageFull,
        RoomModelDownloadStage.cancelled => RoomModelAvailability.cancelled,
        RoomModelDownloadStage.idle => RoomModelAvailability.notInstalled,
      };
      state = RoomModelSetupState(
        availability: availability,
        progress: progress,
      );
    });
    try {
      await _store.prepare();
      if (_current(epoch)) {
        state = RoomModelSetupState(
          availability: RoomModelAvailability.ready,
          progress: _store.progress,
        );
      }
    } on RoomModelDownloadException catch (error) {
      if (_current(epoch)) _failure(error);
    }
  }

  void _failure(RoomModelDownloadException error) {
    state = RoomModelSetupState(
      availability: error.cancelled
          ? RoomModelAvailability.cancelled
          : error.storageFull
          ? RoomModelAvailability.storageFull
          : RoomModelAvailability.failed,
      progress: _store.progress,
    );
  }

  void cancel() {
    _epoch++;
    _store.cancel();
    if (!_disposed) {
      state = RoomModelSetupState(
        availability: RoomModelAvailability.cancelled,
        progress: _store.progress,
      );
    }
  }

  Future<void> retry() => download();

  /// This is the explicit permission to enter the photo editor. Reverification
  /// is cache-only, including when a download just finished.
  Future<bool> continueWithCachedModels() async {
    await check();
    if (_disposed || state.availability != RoomModelAvailability.ready) {
      return false;
    }
    state = RoomModelSetupState(
      availability: RoomModelAvailability.ready,
      progress: _store.progress,
      canEnter: true,
    );
    return true;
  }
}
