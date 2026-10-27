/// Metadata for one persisted record that could not be decoded safely.
///
/// The raw value deliberately is not exposed so logs and UI warnings cannot
/// leak private user content. Repositories also leave that raw value untouched.
final class CorruptRecord {
  const CorruptRecord({
    required this.collectionId,
    required this.storageKey,
    required this.reason,
  });

  final String collectionId;
  final Object storageKey;
  final String reason;
}
