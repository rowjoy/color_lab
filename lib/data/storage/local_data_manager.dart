import 'dart:async';
import '../schema/schema_registry.dart';
export '../schema/schema_registry.dart' show LocalDataCategory;

extension LocalDataAvailability on LocalDataCategory {
  bool get available => !const {
    LocalDataCategory.coloringProjects,
    LocalDataCategory.learningProgress,
  }.contains(this);
}

final class LocalDataException implements Exception {
  const LocalDataException();
}

final class DataDeletionPreview {
  DataDeletionPreview({
    required Set<LocalDataCategory> categories,
    required this.recordCount,
    required this.estimatedBytes,
    this.revisionCount = 0,
  }) : categories = Set.unmodifiable(categories);
  final Set<LocalDataCategory> categories;
  final int recordCount;
  final int estimatedBytes;
  final int revisionCount;
}

/// Immutable identities and content fingerprints, including undecodable records.
final class LocalDataManifest {
  LocalDataManifest(
    Map<String, String> entries,
    this.estimatedBytes, {
    int? recordCount,
    this.revisionCount = 0,
  }) : entries = Map.unmodifiable(entries),
       recordCount = recordCount ?? entries.length;
  final Map<String, String> entries;
  final int estimatedBytes;
  final int recordCount;
  final int revisionCount;
  bool sameAs(LocalDataManifest other) =>
      entries.length == other.entries.length &&
      entries.entries.every((entry) => other.entries[entry.key] == entry.value);
}

/// The owner holds its normal operation queue for the entire callback. The
/// manager acquires owners in enum order, validates all, then removes selected
/// records. No raw box or directory handle leaves its owner.
abstract interface class LocalDataOwner {
  Future<T> withMaintenance<T>(Future<T> Function(LocalDataLease lease) action);
}

abstract interface class LocalDataLease {
  Future<LocalDataManifest> inventory();
  Future<void> erase(LocalDataManifest manifest);
}

abstract interface class LocalDataManager {
  Future<DataDeletionPreview> preview(Set<LocalDataCategory> categories);
  Future<void> delete(Set<LocalDataCategory> categories);
}

final class ExactLocalDataManager implements LocalDataManager {
  ExactLocalDataManager({
    required Map<LocalDataCategory, Future<LocalDataOwner> Function()> owners,
  }) : _owners = Map.unmodifiable(owners);
  final Map<LocalDataCategory, Future<LocalDataOwner> Function()> _owners;
  Map<LocalDataCategory, LocalDataManifest>? _authorized;
  Future<void> _pending = Future.value();

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _pending.then((_) async {
      try {
        return await operation();
      } catch (_) {
        throw const LocalDataException();
      }
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<T> _locked<T>(
    Set<LocalDataCategory> categories,
    Future<T> Function(Map<LocalDataCategory, LocalDataLease>) action,
  ) async {
    if (categories.isEmpty ||
        categories.any((c) => !c.available || !_owners.containsKey(c))) {
      throw const LocalDataException();
    }
    final ordered = categories.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final leases = <LocalDataCategory, LocalDataLease>{};
    Future<T> acquire(int index) async {
      if (index == ordered.length) return action(leases);
      final category = ordered[index];
      final owner = await _owners[category]!();
      return owner.withMaintenance((lease) {
        leases[category] = lease;
        return acquire(index + 1);
      });
    }

    return acquire(0);
  }

  @override
  Future<DataDeletionPreview> preview(Set<LocalDataCategory> categories) {
    final selection = Set<LocalDataCategory>.unmodifiable(categories);
    return _serialize(() async {
      _authorized = null;
      return _locked(selection, (leases) async {
        final manifest = <LocalDataCategory, LocalDataManifest>{};
        for (final entry in leases.entries) {
          manifest[entry.key] = await entry.value.inventory();
        }
        _authorized = Map.unmodifiable(manifest);
        return DataDeletionPreview(
          categories: selection,
          recordCount: manifest.values.fold(
            0,
            (sum, item) => sum + item.recordCount,
          ),
          estimatedBytes: manifest.values.fold(
            0,
            (sum, item) => sum + item.estimatedBytes,
          ),
          revisionCount: manifest.values.fold(
            0,
            (sum, item) => sum + item.revisionCount,
          ),
        );
      });
    });
  }

  @override
  Future<void> delete(Set<LocalDataCategory> categories) {
    final selection = Set<LocalDataCategory>.unmodifiable(categories);
    return _serialize(() async {
      final authorized = _authorized;
      _authorized =
          null; // Every attempt consumes authorization, even mismatch.
      if (authorized == null ||
          authorized.length != selection.length ||
          !selection.every(authorized.containsKey)) {
        throw const LocalDataException();
      }
      await _locked(selection, (leases) async {
        for (final entry in leases.entries) {
          if (!authorized[entry.key]!.sameAs(await entry.value.inventory())) {
            throw const LocalDataException();
          }
        }
        for (final entry in leases.entries) {
          await entry.value.erase(authorized[entry.key]!);
        }
      });
    });
  }
}
