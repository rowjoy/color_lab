import '../../../core/color/color_engine.dart';
import 'saved_palette.dart';

/// Successful edits finish only once their complete snapshots are durable.
abstract interface class SavedPaletteRepository {
  Future<List<SavedPalette>> load();
  Future<SavedPalette> save({
    required String name,
    required RgbColor base,
    required HarmonyMode mode,
    required Iterable<RgbColor> colors,
  });
  Future<void> delete(String id);
  Future<void> close();
}

/// Never exposes a storage path or persisted contents to the caller.
final class PaletteStorageException implements Exception {
  const PaletteStorageException();

  @override
  String toString() => 'Unable to access saved palettes.';
}
