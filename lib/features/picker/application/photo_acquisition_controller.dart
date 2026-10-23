import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/photo_acquisition.dart';
import '../domain/prepared_photo.dart';
import 'acquisition_intent_providers.dart';
import 'photo_picker_service.dart';

final photoAcquisitionProvider =
    NotifierProvider<PhotoAcquisitionController, AcquisitionState>(
      PhotoAcquisitionController.new,
    );

class PhotoAcquisitionController extends Notifier<AcquisitionState> {
  Future<void>? _recovery;
  bool _busy = false;
  bool _nativeConsumed = false;
  bool _recovered = false;
  bool _cleanupNeeded = false;
  AcquisitionIntentRecord? _origin;
  PreparedPhoto? _lost;
  AcquisitionFailureKind? _recoveryFailure;
  static int _sequence = 0;

  @override
  AcquisitionState build() => const AcquisitionState.initial();

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  void _publish(
    AcquisitionPhase phase, {
    AcquisitionReceipt? receipt,
    AcquisitionFailureKind? failure,
    bool? untrusted,
  }) {
    if (!ref.mounted) return;
    state = AcquisitionState(
      phase: phase,
      pendingReceipt: receipt,
      failure: failure,
      hasUntrustedIntent: untrusted ?? state.hasUntrustedIntent,
    );
  }

  void _storageFailure() {
    if (!ref.mounted) return;
    _publish(
      AcquisitionPhase.storageError,
      receipt: state.pendingReceipt,
      failure: AcquisitionFailureKind.storage,
    );
  }

  // No providers are read in build: onboarding decides when to recover.
  Future<void> ensureRecovered() {
    if (!ref.mounted ||
        _recovered ||
        state.phase == AcquisitionPhase.storageError) {
      return Future<void>.value();
    }
    return _recovery ??= _recover();
  }

  Future<void> _recover() async {
    _busy = true;
    _publish(AcquisitionPhase.recovering);
    try {
      final store = await ref.read(acquisitionIntentStoreProvider.future);
      if (!ref.mounted) return;
      final record = await store.load();
      if (!ref.mounted) return;
      _origin ??= record;
      _publish(
        AcquisitionPhase.recovering,
        untrusted: _origin!.kind == IntentRecordKind.untrusted,
      );
      if (!_nativeConsumed) {
        // Mark before invocation, including native/processing errors: retrieval
        // can consume the platform result even when preparing it fails.
        _nativeConsumed = true;
        try {
          _lost = await ref.read(photoPickerServiceProvider).recoverLost();
        } catch (_) {
          _recoveryFailure = AcquisitionFailureKind.recovery;
        }
      }
      if (!ref.mounted) return;
      if (_lost != null) {
        final intent = _origin!.intent;
        _publish(
          AcquisitionPhase.ready,
          receipt: AcquisitionReceipt(
            requestId: intent?.requestId ?? _newId(),
            source: intent?.source,
            destination: intent?.destination,
            photo: _lost!,
            recovered: true,
          ),
        );
      } else {
        if (_origin!.kind == IntentRecordKind.valid) {
          await store.clear();
          if (!ref.mounted) return;
        }
        _publish(AcquisitionPhase.ready, failure: _recoveryFailure);
      }
      _recovered = true;
      // The pending receipt is now the sole owner of these pixels.
      _lost = null;
    } catch (_) {
      _storageFailure();
    } finally {
      _busy = false;
    }
  }

  Future<AcquisitionOutcome> request({
    required PhotoSource source,
    required AcquisitionDestination destination,
    bool Function()? isActive,
  }) async {
    bool ownerIsActive() {
      try {
        return isActive?.call() ?? true;
      } catch (_) {
        return false;
      }
    }

    if (!ref.mounted || !ownerIsActive()) return const AcquisitionCancelled();
    if (_busy) return const AcquisitionBusy();
    if (!_recovered) await ensureRecovered();
    if (!ref.mounted || !ownerIsActive()) return const AcquisitionCancelled();
    if (_busy ||
        state.phase != AcquisitionPhase.ready ||
        state.pendingReceipt != null ||
        state.hasUntrustedIntent) {
      return const AcquisitionBusy();
    }
    _busy = true;
    _publish(AcquisitionPhase.picking);
    try {
      final store = await ref.read(acquisitionIntentStoreProvider.future);
      if (!ref.mounted) return const AcquisitionCancelled();
      if (!ownerIsActive()) {
        _publish(AcquisitionPhase.ready);
        return const AcquisitionCancelled();
      }
      final intent = AcquisitionIntent(
        requestId: _newId(),
        source: source,
        destination: destination,
      );
      // A failed put/flush may already have updated Hive's memory. Retry must
      // resolve that intent, never automatically reopen a native picker.
      _cleanupNeeded = true;
      await store.save(intent);
      if (!ref.mounted) return const AcquisitionCancelled();
      if (!ownerIsActive()) {
        await store.clear();
        if (!ref.mounted) return const AcquisitionCancelled();
        _cleanupNeeded = false;
        _publish(AcquisitionPhase.ready);
        return const AcquisitionCancelled();
      }
      PreparedPhoto? photo;
      AcquisitionFailureKind? failure;
      try {
        photo = await ref.read(photoPickerServiceProvider).pick(source: source);
      } on PhotoPickFailure catch (error) {
        failure = switch (error.kind) {
          PhotoPickFailureKind.permissionDenied =>
            AcquisitionFailureKind.permissionDenied,
          PhotoPickFailureKind.unavailable =>
            AcquisitionFailureKind.unavailable,
          PhotoPickFailureKind.invalidImage =>
            AcquisitionFailureKind.invalidImage,
          PhotoPickFailureKind.tooLarge => AcquisitionFailureKind.tooLarge,
          PhotoPickFailureKind.processing => AcquisitionFailureKind.processing,
        };
      } catch (_) {
        failure = AcquisitionFailureKind.unavailable;
      }
      if (!ref.mounted) return const AcquisitionCancelled();
      if (photo != null) {
        _cleanupNeeded = false;
        final receipt = AcquisitionReceipt(
          requestId: intent.requestId,
          source: source,
          destination: destination,
          photo: photo,
          recovered: false,
        );
        _publish(AcquisitionPhase.ready, receipt: receipt);
        return Acquired(receipt);
      }
      await store.clear();
      if (!ref.mounted) return const AcquisitionCancelled();
      _cleanupNeeded = false;
      _publish(AcquisitionPhase.ready, failure: failure);
      return failure == null
          ? const AcquisitionCancelled()
          : AcquisitionFailed(failure);
    } catch (_) {
      _storageFailure();
      return const AcquisitionFailed(AcquisitionFailureKind.storage);
    } finally {
      _busy = false;
    }
  }

  Future<PreparedPhoto?> claim({
    required String requestId,
    required AcquisitionDestination destination,
    bool Function(PreparedPhoto photo)? accept,
  }) async {
    if (!ref.mounted) return null;
    final receipt = state.pendingReceipt;
    if (receipt == null ||
        receipt.requestId != requestId ||
        (receipt.destination != null && receipt.destination != destination)) {
      return null;
    }
    return await _disposeReceipt(requestId, accept: accept)
        ? receipt.photo
        : null;
  }

  Future<bool> dismiss(String requestId) => _disposeReceipt(requestId);

  Future<bool> _disposeReceipt(
    String requestId, {
    bool Function(PreparedPhoto photo)? accept,
  }) async {
    if (!ref.mounted ||
        _busy ||
        state.phase != AcquisitionPhase.ready ||
        state.pendingReceipt?.requestId != requestId) {
      return false;
    }
    _busy = true;
    try {
      final receipt = state.pendingReceipt!;
      final store = await ref.read(acquisitionIntentStoreProvider.future);
      if (!ref.mounted) return false;
      await store.clear(discardUntrusted: state.hasUntrustedIntent);
      if (!ref.mounted) return false;
      // Keep the gate and pixels until the original owner synchronously accepts
      // delivery. A route may have disappeared during the durable clear.
      var accepted = true;
      try {
        accepted = accept?.call(receipt.photo) ?? true;
      } catch (_) {
        accepted = false;
      }
      if (!ref.mounted) return false;
      if (!accepted) {
        _publish(AcquisitionPhase.ready, receipt: receipt, untrusted: false);
        return false;
      }
      _publish(AcquisitionPhase.ready, untrusted: false);
      return true;
    } catch (_) {
      _storageFailure();
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<bool> discardUntrustedIntent() async {
    if (!ref.mounted ||
        _busy ||
        state.phase != AcquisitionPhase.ready ||
        !state.hasUntrustedIntent ||
        state.pendingReceipt != null) {
      return false;
    }
    _busy = true;
    try {
      final store = await ref.read(acquisitionIntentStoreProvider.future);
      if (!ref.mounted) return false;
      await store.clear(discardUntrusted: true);
      if (!ref.mounted) return false;
      _publish(AcquisitionPhase.ready, untrusted: false);
      return true;
    } catch (_) {
      _storageFailure();
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<void> retryStorage() async {
    if (!ref.mounted || _busy || state.phase != AcquisitionPhase.storageError) {
      return;
    }
    _busy = true;
    try {
      if (ref.read(acquisitionStorageDirectoryProvider).hasError) {
        ref.invalidate(acquisitionStorageDirectoryProvider);
      }
      if (ref.read(acquisitionIntentStoreProvider).hasError) {
        ref.invalidate(acquisitionIntentStoreProvider);
      }
      final store = await ref.read(acquisitionIntentStoreProvider.future);
      if (!ref.mounted) return;
      await store.load(); // Reaches the store's failed-flush retry barrier.
      if (!ref.mounted) return;
      if (!_recovered) {
        _recovery = _recover();
        await _recovery;
        return;
      }
      if (_cleanupNeeded) {
        await store.clear();
        if (!ref.mounted) return;
        _cleanupNeeded = false;
      }
      // A receipt survives a failed clear. The caller must claim/dismiss again
      // so retry never silently delivers or discards prepared pixels.
      _publish(AcquisitionPhase.ready, receipt: state.pendingReceipt);
    } catch (_) {
      _storageFailure();
    } finally {
      _busy = false;
    }
  }
}
