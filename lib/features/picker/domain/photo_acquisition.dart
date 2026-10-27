import 'package:flutter/foundation.dart';

import 'prepared_photo.dart';

enum PhotoSource { gallery, camera }

enum AcquisitionDestination { capture, room }

@immutable
final class AcquisitionIntent {
  const AcquisitionIntent({
    required this.requestId,
    required this.source,
    required this.destination,
  });
  final String requestId;
  final PhotoSource source;
  final AcquisitionDestination destination;

  Map<String, Object> toMap() => {
    'schemaVersion': 1,
    'requestId': requestId,
    'source': source.name,
    'destination': destination.name,
  };

  static AcquisitionIntent? fromMap(Map<dynamic, dynamic> map) {
    final id = map['requestId'];
    if (map['schemaVersion'] != 1 || id is! String || id.trim().isEmpty) {
      return null;
    }
    final source = PhotoSource.values
        .where((value) => value.name == map['source'])
        .firstOrNull;
    final destination = AcquisitionDestination.values
        .where((value) => value.name == map['destination'])
        .firstOrNull;
    if (source == null || destination == null) return null;
    return AcquisitionIntent(
      requestId: id,
      source: source,
      destination: destination,
    );
  }
}

enum IntentRecordKind { absent, valid, untrusted }

@immutable
final class AcquisitionIntentRecord {
  const AcquisitionIntentRecord.absent()
    : kind = IntentRecordKind.absent,
      intent = null;
  const AcquisitionIntentRecord.valid(AcquisitionIntent value)
    : kind = IntentRecordKind.valid,
      intent = value;
  const AcquisitionIntentRecord.untrusted()
    : kind = IntentRecordKind.untrusted,
      intent = null;
  final IntentRecordKind kind;
  final AcquisitionIntent? intent;
}

@immutable
final class AcquisitionReceipt {
  const AcquisitionReceipt({
    required this.requestId,
    this.source,
    this.destination,
    required this.photo,
    required this.recovered,
  });
  final String requestId;
  final PhotoSource? source;
  final AcquisitionDestination? destination;
  final PreparedPhoto photo;
  final bool recovered;
}

enum AcquisitionFailureKind {
  permissionDenied,
  unavailable,
  cameraUnavailable,
  unsupported,
  invalidImage,
  tooLarge,
  processing,
  storage,
  recovery,
}

/// A consumed native recovery failure retains only its trusted request owner.
@immutable
final class AcquisitionRecoveryFailure {
  const AcquisitionRecoveryFailure({required this.intent, required this.kind});
  final AcquisitionIntent intent;
  final AcquisitionFailureKind kind;
}

/// One failed storage operation, retained through its retries. Even another
/// failure for the same receipt has a distinct identity. This is transient,
/// never part of the persisted intent schema.
@immutable
final class AcquisitionStorageFailure {
  // Public construction always allocates; canonical const values would merge
  // separate failed operations for the same request.
  factory AcquisitionStorageFailure({
    String? requestId,
    AcquisitionDestination? destination,
  }) => AcquisitionStorageFailure._(requestId, destination);
  const AcquisitionStorageFailure._(this.requestId, this.destination);
  final String? requestId;
  final AcquisitionDestination? destination;
}

@immutable
sealed class AcquisitionOutcome {
  const AcquisitionOutcome();
}

final class Acquired extends AcquisitionOutcome {
  const Acquired(this.receipt);
  final AcquisitionReceipt receipt;
}

final class AcquisitionCancelled extends AcquisitionOutcome {
  const AcquisitionCancelled();
}

final class AcquisitionBusy extends AcquisitionOutcome {
  const AcquisitionBusy();
}

final class AcquisitionFailed extends AcquisitionOutcome {
  const AcquisitionFailed(this.kind, {this.storageFailure});
  final AcquisitionFailureKind kind;
  final AcquisitionStorageFailure? storageFailure;
}

enum AcquisitionPhase {
  uninitialized,
  recovering,
  ready,
  picking,
  storageError,
}

@immutable
final class AcquisitionState {
  const AcquisitionState({
    required this.phase,
    this.pendingReceipt,
    this.failure,
    this.recoveryFailure,
    this.storageFailure,
    this.resolvedStorageFailure,
    this.hasUntrustedIntent = false,
  });
  const AcquisitionState.initial()
    : phase = AcquisitionPhase.uninitialized,
      pendingReceipt = null,
      failure = null,
      recoveryFailure = null,
      storageFailure = null,
      resolvedStorageFailure = null,
      hasUntrustedIntent = false;
  final AcquisitionPhase phase;
  final AcquisitionReceipt? pendingReceipt;
  final AcquisitionFailureKind? failure;
  final AcquisitionRecoveryFailure? recoveryFailure;
  final AcquisitionStorageFailure? storageFailure;
  final AcquisitionStorageFailure? resolvedStorageFailure;
  final bool hasUntrustedIntent;
}
