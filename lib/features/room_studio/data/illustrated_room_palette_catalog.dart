import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/generated/app_localizations_en.dart';

/// Original starter records. Color order is wall, ceiling, floor, furniture.
/// Published v1 values are frozen; editing a room copies these values.
final class IllustratedRoomPaletteRecord {
  IllustratedRoomPaletteRecord._({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required Iterable<String> colors,
  }) : colors = List<String>.unmodifiable(colors);

  final int schemaVersion = 1;
  final int catalogueRevision = 1;
  final String id;
  final String nameKey;
  final String descriptionKey;
  final List<String> colors;

  String localizedName(AppLocalizations l10n) => switch (id) {
    'soft-linen' => l10n.illustratedPaletteSoftLinenName,
    'quiet-sage' => l10n.illustratedPaletteQuietSageName,
    'airy-slate' => l10n.illustratedPaletteAirySlateName,
    'clay-and-cream' => l10n.illustratedPaletteClayAndCreamName,
    'mist-and-ink' => l10n.illustratedPaletteMistAndInkName,
    'sunwashed-olive' => l10n.illustratedPaletteSunwashedOliveName,
    _ => throw StateError('Unknown starter palette $id'),
  };

  String localizedDescription(AppLocalizations l10n) => switch (id) {
    'soft-linen' => l10n.illustratedPaletteSoftLinenDescription,
    'quiet-sage' => l10n.illustratedPaletteQuietSageDescription,
    'airy-slate' => l10n.illustratedPaletteAirySlateDescription,
    'clay-and-cream' => l10n.illustratedPaletteClayAndCreamDescription,
    'mist-and-ink' => l10n.illustratedPaletteMistAndInkDescription,
    'sunwashed-olive' => l10n.illustratedPaletteSunwashedOliveDescription,
    _ => throw StateError('Unknown starter palette $id'),
  };
}

abstract final class IllustratedRoomPaletteCatalog {
  static final AppLocalizations fallbackLocalizations = AppLocalizationsEn();
  static const assetPath = 'assets/rooms/palettes/starter_palettes.v1.json';
  static const roles = ['wall', 'ceiling', 'floor', 'furniture'];
  static final List<IllustratedRoomPaletteRecord> all = List.unmodifiable([
    IllustratedRoomPaletteRecord._(
      id: 'soft-linen',
      nameKey: 'illustratedPaletteSoftLinenName',
      descriptionKey: 'illustratedPaletteSoftLinenDescription',
      colors: ['#F2E9DA', '#D8C7AC', '#A89073', '#5C554D'],
    ),
    IllustratedRoomPaletteRecord._(
      id: 'quiet-sage',
      nameKey: 'illustratedPaletteQuietSageName',
      descriptionKey: 'illustratedPaletteQuietSageDescription',
      colors: ['#ECE9DF', '#B7C2A3', '#78866B', '#4E5B4A'],
    ),
    IllustratedRoomPaletteRecord._(
      id: 'airy-slate',
      nameKey: 'illustratedPaletteAirySlateName',
      descriptionKey: 'illustratedPaletteAirySlateDescription',
      colors: ['#F2F4F3', '#C9D3D8', '#8396A5', '#3F5362'],
    ),
    IllustratedRoomPaletteRecord._(
      id: 'clay-and-cream',
      nameKey: 'illustratedPaletteClayAndCreamName',
      descriptionKey: 'illustratedPaletteClayAndCreamDescription',
      colors: ['#F5EBDD', '#D79A7A', '#9B6553', '#5E4A42'],
    ),
    IllustratedRoomPaletteRecord._(
      id: 'mist-and-ink',
      nameKey: 'illustratedPaletteMistAndInkName',
      descriptionKey: 'illustratedPaletteMistAndInkDescription',
      colors: ['#ECEFF1', '#B8C4CE', '#667989', '#263746'],
    ),
    IllustratedRoomPaletteRecord._(
      id: 'sunwashed-olive',
      nameKey: 'illustratedPaletteSunwashedOliveName',
      descriptionKey: 'illustratedPaletteSunwashedOliveDescription',
      colors: ['#F3E7C7', '#D8B96A', '#8B8F58', '#4F5A3F'],
    ),
  ]);
}
