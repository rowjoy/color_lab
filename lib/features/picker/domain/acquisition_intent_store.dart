import 'photo_acquisition.dart';

abstract interface class AcquisitionIntentStore {
  Future<AcquisitionIntentRecord> load();
  Future<void> save(AcquisitionIntent intent);
  Future<void> clear({bool discardUntrusted = false});
  Future<void> close();
}

final class AcquisitionStorageException implements Exception {
  const AcquisitionStorageException();
  @override
  String toString() => 'Photo acquisition storage is unavailable.';
}
