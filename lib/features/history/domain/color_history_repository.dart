import '../../../core/color/color_engine.dart';
import 'saved_color.dart';

/// Durable saved colors. Successful edits are persisted before their futures end.
abstract interface class ColorHistoryRepository {
  Future<List<SavedColor>> load();
  Future<SavedColor> save({
    required RgbColor color,
    required String name,
    required ColorSource source,
  });
  Future<void> setFavorite(String id, bool isFavorite);
  Future<void> delete(String id);
  Future<void> close();
}

/// A safe public error that never includes filesystem paths or stored contents.
final class HistoryStorageException implements Exception {
  const HistoryStorageException();
  @override
  String toString() => 'Unable to access saved colors.';
}
