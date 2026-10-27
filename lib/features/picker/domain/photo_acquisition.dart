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
  const AcquisitionFailed(this.kind);
  final AcquisitionFailureKind kind;
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
    this.hasUntrustedIntent = false,
  });
  const AcquisitionState.initial()
    : phase = AcquisitionPhase.uninitialized,
      pendingReceipt = null,
      failure = null,
      recoveryFailure = null,
      hasUntrustedIntent = false;
  final AcquisitionPhase phase;
  final AcquisitionReceipt? pendingReceipt;
  final AcquisitionFailureKind? failure;
  final AcquisitionRecoveryFailure? recoveryFailure;
  final bool hasUntrustedIntent;
}
