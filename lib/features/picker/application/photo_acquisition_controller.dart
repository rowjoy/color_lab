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
  final _recoveryFailureOwners = <AcquisitionDestination>{};
  static int _sequence = 0;

  @override
  AcquisitionState build() => const AcquisitionState.initial();

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  void _publish(
    AcquisitionPhase phase, {
    AcquisitionReceipt? receipt,
    AcquisitionFailureKind? failure,
    AcquisitionRecoveryFailure? recoveryFailure,
    AcquisitionStorageFailure? storageFailure,
    AcquisitionStorageFailure? resolvedStorageFailure,
    bool? untrusted,
  }) {
    if (!ref.mounted) return;
    state = AcquisitionState(
      phase: phase,
      pendingReceipt: receipt,
      failure: failure,
      recoveryFailure: recoveryFailure,
      storageFailure: storageFailure,
      resolvedStorageFailure: resolvedStorageFailure,
      hasUntrustedIntent: untrusted ?? state.hasUntrustedIntent,
    );
  }

  AcquisitionStorageFailure _storageFailure({
    String? requestId,
    AcquisitionDestination? destination,
    AcquisitionStorageFailure? retrying,
  }) {
    final receipt = ref.mounted ? state.pendingReceipt : null;
    final failure =
        retrying ??
        AcquisitionStorageFailure(
          requestId: requestId ?? receipt?.requestId,
          destination: destination ?? receipt?.destination,
        );
    _publish(
      AcquisitionPhase.storageError,
      receipt: receipt,
      failure: AcquisitionFailureKind.storage,
      storageFailure: failure,
    );
    return failure;
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

  Future<void> _recover({AcquisitionStorageFailure? retrying}) async {
    _busy = true;
    _publish(AcquisitionPhase.recovering, storageFailure: retrying);
    try {
      final store = await ref.read(acquisitionIntentStoreProvider.future);
      if (!ref.mounted) return;
      final record = await store.load();
      if (!ref.mounted) return;
      _origin ??= record;
      _publish(
        AcquisitionPhase.recovering,
        storageFailure: retrying,
        untrusted: _origin!.kind == IntentRecordKind.untrusted,
      );
      if (!_nativeConsumed) {
        // Mark before invocation, including native/processing errors: retrieval
        // can consume the platform result even when preparing it fails.
        _nativeConsumed = true;
        try {
          _lost = await ref.read(photoPickerServiceProvider).recoverLost();
        } on PhotoPickFailure catch (error) {
          _recoveryFailure = _pickFailure(error.kind);
        } catch (_) {
          _recoveryFailure = AcquisitionFailureKind.recovery;
        }
      }
      if (!ref.mounted) return;
      if (_lost != null) {
        final intent = _origin!.intent;
        _publish(
          AcquisitionPhase.ready,
          resolvedStorageFailure: retrying,
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
        final intent = _origin!.intent;
        _publish(
          AcquisitionPhase.ready,
          resolvedStorageFailure: retrying,
          failure: _recoveryFailure,
          recoveryFailure: intent != null && _recoveryFailure != null
              ? AcquisitionRecoveryFailure(
                  intent: intent,
                  kind: _recoveryFailure!,
                )
              : null,
        );
      }
      _recovered = true;
      // The pending receipt is now the sole owner of these pixels.
      _lost = null;
    } catch (_) {
      _storageFailure(
        requestId: _origin?.intent?.requestId,
        destination: _origin?.intent?.destination,
        retrying: retrying,
      );
    } finally {
      _busy = false;
    }
  }

  /// Recovery runs once per controller. Its first observer for a destination
  /// retains the reservation even after leaving, so a late error cannot move
  /// into a newer editor. This reserves presentation only, never photo pixels.
  bool reserveRecoveryFailure(AcquisitionDestination destination) =>
      ref.mounted && _recoveryFailureOwners.add(destination);

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
    final intent = AcquisitionIntent(
      requestId: _newId(),
      source: source,
      destination: destination,
    );
    try {
      final store = await ref.read(acquisitionIntentStoreProvider.future);
      if (!ref.mounted) return const AcquisitionCancelled();
      if (!ownerIsActive()) {
        _publish(AcquisitionPhase.ready);
        return const AcquisitionCancelled();
      }
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
        failure = _pickFailure(error.kind);
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
      final failure = _storageFailure(
        requestId: intent.requestId,
        destination: intent.destination,
      );
      return AcquisitionFailed(
        AcquisitionFailureKind.storage,
        storageFailure: failure,
      );
    } finally {
      _busy = false;
    }
  }

  static AcquisitionFailureKind _pickFailure(PhotoPickFailureKind kind) =>
      switch (kind) {
        PhotoPickFailureKind.permissionDenied =>
          AcquisitionFailureKind.permissionDenied,
        PhotoPickFailureKind.cameraUnavailable =>
          AcquisitionFailureKind.cameraUnavailable,
        PhotoPickFailureKind.unsupported => AcquisitionFailureKind.unsupported,
        PhotoPickFailureKind.unavailable => AcquisitionFailureKind.unavailable,
        PhotoPickFailureKind.invalidImage =>
          AcquisitionFailureKind.invalidImage,
        PhotoPickFailureKind.tooLarge => AcquisitionFailureKind.tooLarge,
        PhotoPickFailureKind.processing => AcquisitionFailureKind.processing,
      };

  Future<PreparedPhoto?> claim({
    required String requestId,
    required AcquisitionDestination destination,
    bool Function(PreparedPhoto photo)? accept,
  }) async {
    final outcome = await claimReceipt(
      requestId: requestId,
      destination: destination,
      accept: accept,
    );
    return outcome is Acquired ? outcome.receipt.photo : null;
  }

  /// Keeps a failed mutation's identity in the result, so its caller never
  /// borrows a newer provider failure after awaiting the storage boundary.
  Future<AcquisitionOutcome> claimReceipt({
    required String requestId,
    required AcquisitionDestination destination,
    bool Function(PreparedPhoto photo)? accept,
  }) async {
    if (!ref.mounted) return const AcquisitionCancelled();
    final receipt = state.pendingReceipt;
    if (receipt == null ||
        receipt.requestId != requestId ||
        (receipt.destination != null && receipt.destination != destination)) {
      return const AcquisitionCancelled();
    }
    return _disposeReceipt(requestId, destination: destination, accept: accept);
  }

  Future<bool> dismiss(String requestId) async =>
      await _disposeReceipt(requestId) is Acquired;

  Future<AcquisitionOutcome> _disposeReceipt(
    String requestId, {
    AcquisitionDestination? destination,
    bool Function(PreparedPhoto photo)? accept,
  }) async {
    if (!ref.mounted ||
        _busy ||
        state.phase != AcquisitionPhase.ready ||
        state.pendingReceipt?.requestId != requestId) {
      return const AcquisitionCancelled();
    }
    _busy = true;
    try {
      final receipt = state.pendingReceipt!;
      final store = await ref.read(acquisitionIntentStoreProvider.future);
      if (!ref.mounted) return const AcquisitionCancelled();
      await store.clear(discardUntrusted: state.hasUntrustedIntent);
      if (!ref.mounted) return const AcquisitionCancelled();
      // Keep the gate and pixels until the original owner synchronously accepts
      // delivery. A route may have disappeared during the durable clear.
      var accepted = true;
      try {
        accepted = accept?.call(receipt.photo) ?? true;
      } catch (_) {
        accepted = false;
      }
      if (!ref.mounted) return const AcquisitionCancelled();
      if (!accepted) {
        _publish(AcquisitionPhase.ready, receipt: receipt, untrusted: false);
        return const AcquisitionCancelled();
      }
      _publish(AcquisitionPhase.ready, untrusted: false);
      return Acquired(receipt);
    } catch (_) {
      final failure = _storageFailure(
        requestId: requestId,
        destination: destination,
      );
      return AcquisitionFailed(
        AcquisitionFailureKind.storage,
        storageFailure: failure,
      );
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

  Future<void> retryStorage({
    AcquisitionStorageFailure? expectedFailure,
  }) async {
    if (!ref.mounted ||
        _busy ||
        state.phase != AcquisitionPhase.storageError ||
        state.storageFailure == null ||
        (expectedFailure != null &&
            !identical(expectedFailure, state.storageFailure))) {
      return;
    }
    final failure = state.storageFailure!;
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
        _recovery = _recover(retrying: failure);
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
      _publish(
        AcquisitionPhase.ready,
        receipt: state.pendingReceipt,
        resolvedStorageFailure: failure,
      );
    } catch (_) {
      _storageFailure(retrying: failure);
    } finally {
      _busy = false;
    }
  }
}
