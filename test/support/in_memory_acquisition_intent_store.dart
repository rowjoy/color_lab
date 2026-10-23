import 'package:color_lab/features/picker/domain/acquisition_intent_store.dart';
import 'package:color_lab/features/picker/domain/photo_acquisition.dart';

class InMemoryAcquisitionIntentStore implements AcquisitionIntentStore {
  InMemoryAcquisitionIntentStore({AcquisitionIntentRecord? initial})
    : _record = initial ?? const AcquisitionIntentRecord.absent();
  AcquisitionIntentRecord _record;
  bool _closed = false;
  void _checkOpen() {
    if (_closed) throw const AcquisitionStorageException();
  }

  @override
  Future<AcquisitionIntentRecord> load() async {
    _checkOpen();
    return _record;
  }

  @override
  Future<void> save(AcquisitionIntent intent) async {
    _checkOpen();
    if (_record.kind == IntentRecordKind.untrusted ||
        AcquisitionIntent.fromMap(intent.toMap()) == null) {
      throw const AcquisitionStorageException();
    }
    _record = AcquisitionIntentRecord.valid(intent);
  }

  @override
  Future<void> clear({bool discardUntrusted = false}) async {
    _checkOpen();
    if (_record.kind == IntentRecordKind.untrusted && !discardUntrusted) {
      throw const AcquisitionStorageException();
    }
    _record = const AcquisitionIntentRecord.absent();
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}
