import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/schema/corrupt_record.dart';
import '../domain/illustrated_room.dart';
import '../domain/illustrated_room_draft.dart';
import '../domain/recoverable_room_draft.dart';
import '../domain/room_design_repository.dart';
import 'room_designs_providers.dart';

enum IllustratedRoomDraftSaveStatus { saved, saving, failed }

/// Initial-load failure recovery repairs dependencies while leaving the editor
/// session and the persistence bridge's pending queue alive.
final illustratedRoomDraftLoadRetryProvider = Provider<Future<void> Function()>(
  (ref) {
    Future<void>? pending;
    Future<void> retryLoad() async {
      try {
        if (ref.read(roomDesignStorageDirectoryProvider).hasError) {
          ref.invalidate(roomDesignStorageDirectoryProvider);
        }
        final repository = ref.read(roomDesignRepositoryProvider);
        if (repository.hasError) {
          ref.invalidate(roomDesignRepositoryProvider);
        } else if (repository.asData?.value case final owner?) {
          try {
            await owner.retry();
          } catch (_) {
            if (ref.mounted) ref.invalidate(roomDesignRepositoryProvider);
          }
        }
        if (!ref.mounted) return;
        ref.invalidate(illustratedRoomDraftStoreProvider);
        await ref.read(illustratedRoomDraftStoreProvider.future);
      } finally {
        pending = null;
      }
    }

    return () => pending ??= retryLoad();
  },
);

/// Task 5 can listen to this owner and explicitly retain/resume editor drafts.
/// Loading never replaces a newer visible draft; history stays in that instance.
final illustratedRoomDraftStoreProvider =
    FutureProvider<IllustratedRoomDraftStore>((ref) async {
      final repository = await ref.watch(roomDesignRepositoryProvider.future);
      if (!ref.mounted) throw StateError('Draft store disposed.');
      final store = IllustratedRoomDraftStore(repository);
      ref.onDispose(store.dispose);
      await store.load();
      if (!ref.mounted) throw StateError('Draft store disposed.');
      return store;
    }, retry: (retryCount, error) => null);

final class IllustratedRoomDraftStore extends ChangeNotifier {
  IllustratedRoomDraftStore(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final RoomDesignRepository _repository;
  final DateTime Function() _clock;
  final Map<String, IllustratedRoomDraft> _visible = {};
  final Map<String, RecoverableRoomDraft> _acknowledged = {};
  final Map<String, IllustratedRoomDraftSaveStatus> _status = {};
  final Map<String, int> _versions = {};
  final Set<String> _unavailable = {};
  final Map<String, String?> _identityChanges = {};
  int _identityEpoch = 0;
  List<CorruptRecord> _corruptRecords = const [];
  List<CorruptRecord> get corruptRecords => _corruptRecords;
  Future<void> _pending = Future.value();
  bool _disposed = false;

  IllustratedRoomDraftSaveStatus? statusFor(String templateId) =>
      _status[templateId];
  RecoverableRoomDraft? acknowledgedFor(String templateId) =>
      _acknowledged[templateId];
  bool recoveryUnavailableFor(String templateId) =>
      _unavailable.contains(templateId);
  IllustratedRoomDraft? restoreAcknowledged(IllustratedRoomTemplate template) {
    if (_unavailable.contains(template.id)) return null;
    try {
      return _acknowledged[template.id]?.restore(template);
    } on ArgumentError {
      _unavailable.add(template.id);
      _notify();
      return null;
    } on FormatException {
      _unavailable.add(template.id);
      _notify();
      return null;
    }
  }

  IllustratedRoomDraft? draftFor(IllustratedRoomTemplate template) =>
      _visible[template.id] ?? restoreAcknowledged(template);

  RecoverableRoomDraft _reconcileRecord(RecoverableRoomDraft record) {
    final id = record.savedDesignId;
    if (id == null || !_identityChanges.containsKey(id)) return record;
    final name = _identityChanges[id];
    return name == null
        ? record.withoutSavedDesign()
        : record.withSavedName(name);
  }

  /// Called synchronously after the repository's atomic identity mutation.
  /// Pending visible edits retain their history/colors; only metadata changes.
  void reconcileSavedIdentity(String id, {String? name}) {
    if (_disposed) return;
    _identityChanges[id] = name;
    _identityEpoch++;
    for (final entry in _acknowledged.entries.toList()) {
      _acknowledged[entry.key] = _reconcileRecord(entry.value);
    }
    for (final entry in _visible.entries.toList()) {
      if (entry.value.savedDesignId != id) continue;
      _visible[entry.key] = name == null
          ? entry.value.asUnsavedAfterDelete()
          : entry.value.renameSavedDesign(id: id, name: name);
    }
    _notify();
  }

  Future<void> _serialize(Future<void> Function() action) {
    if (_disposed) return Future.error(StateError('Draft store disposed.'));
    final result = _pending.then((_) async {
      if (_disposed) return;
      await action();
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() => _serialize(() async {
    final snapshot = await _repository.loadDraftSnapshot();
    if (_disposed) return;
    _acknowledged
      ..clear()
      ..addEntries(
        snapshot.records.map((record) => MapEntry(record.templateId, record)),
      );
    _corruptRecords = List.unmodifiable(snapshot.corruptRecords);
    for (final record in snapshot.records) {
      final template = IllustratedRoomCatalog.maybeById(record.templateId);
      if (template != null) restoreAcknowledged(template);
      _status.putIfAbsent(
        record.templateId,
        () => IllustratedRoomDraftSaveStatus.saved,
      );
    }
    _notify();
  });

  Future<void> retain(IllustratedRoomDraft draft) {
    if (_disposed) return Future.error(StateError('Draft store disposed.'));
    final id = draft.template.id;
    if (_unavailable.contains(id)) {
      _visible[id] = draft;
      return Future.value();
    }
    final revision = (_versions[id] ?? 0) + 1;
    _versions[id] = revision;
    _visible[id] = draft;
    _status[id] = IllustratedRoomDraftSaveStatus.saving;
    _notify();
    return _persist(draft, revision, retry: false);
  }

  Future<void> retry(String templateId) {
    if (_unavailable.contains(templateId)) return Future.value();
    final draft = _visible[templateId];
    if (draft == null) {
      return Future.error(StateError('No failed draft to retry.'));
    }
    if (_disposed) return Future.error(StateError('Draft store disposed.'));
    final revision = (_versions[templateId] ?? 0) + 1;
    _versions[templateId] = revision;
    _status[templateId] = IllustratedRoomDraftSaveStatus.saving;
    _notify();
    return _persist(draft, revision, retry: true);
  }

  Future<void> _persist(
    IllustratedRoomDraft draft,
    int revision, {
    required bool retry,
  }) => _serialize(() async {
    final id = draft.template.id;
    try {
      if (retry) await _repository.retry();
      var record = _reconcileRecord(
        RecoverableRoomDraft.fromDraft(draft, updatedAt: _clock().toUtc()),
      );
      while (true) {
        final epoch = _identityEpoch;
        await _repository.saveDraft(record);
        if (_disposed) return;
        if (epoch == _identityEpoch) break;
        // An atomic library identity edit may have completed while this older
        // captured draft was queued in the shared repository. Repair its metadata
        // before acknowledgement, keeping the captured visible colors unchanged.
        record = _reconcileRecord(record);
      }
      if (_disposed) return;
      _acknowledged[id] = record;
      if (_versions[id] == revision) {
        _status[id] = IllustratedRoomDraftSaveStatus.saved;
      }
      _notify();
    } catch (_) {
      if (!_disposed && _versions[id] == revision) {
        _status[id] = IllustratedRoomDraftSaveStatus.failed;
        _notify();
      }
      rethrow;
    }
  });

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}
