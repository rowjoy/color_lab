import '../../../core/color/color_engine.dart';

/// One immutable ingredient in an in-memory color mix.
final class MixerIngredient {
  MixerIngredient({required this.id, required this.color, this.weight = 50}) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be blank');
    }
    if (!weight.isFinite || weight < 0 || weight > 100) {
      throw ArgumentError.value(
        weight,
        'weight',
        'Must be finite and in [0, 100]',
      );
    }
  }

  final String id;
  final RgbColor color;
  final double weight;

  MixerIngredient copyWith({String? id, RgbColor? color, double? weight}) =>
      MixerIngredient(
        id: id ?? this.id,
        color: color ?? this.color,
        weight: weight ?? this.weight,
      );

  @override
  bool operator ==(Object other) =>
      other is MixerIngredient &&
      id == other.id &&
      color == other.color &&
      weight == other.weight;

  @override
  int get hashCode => Object.hash(id, color, weight);
}

/// An immutable snapshot of the session's mixer draft and derived results.
final class MixerState {
  MixerState({
    required Iterable<MixerIngredient> ingredients,
    this.space = MixingSpace.lab,
  }) : ingredients = List<MixerIngredient>.unmodifiable(ingredients) {
    if (this.ingredients.length < 2) {
      throw ArgumentError.value(
        ingredients,
        'ingredients',
        'Must contain at least two colors',
      );
    }
    if (this.ingredients.map((item) => item.id).toSet().length !=
        this.ingredients.length) {
      throw ArgumentError.value(
        ingredients,
        'ingredients',
        'IDs must be unique',
      );
    }
  }

  factory MixerState.initial() => MixerState(
    ingredients: [
      MixerIngredient(id: 'color-0', color: RgbColor.fromHex('#B2A4D4')),
      MixerIngredient(id: 'color-1', color: RgbColor.fromHex('#E8DAA9')),
    ],
  );

  factory MixerState.restored({
    required Iterable<MixerIngredient> ingredients,
    required MixingSpace space,
  }) => MixerState(ingredients: ingredients, space: space);

  final List<MixerIngredient> ingredients;
  final MixingSpace space;

  late final bool hasActiveColors = ingredients.any((item) => item.weight > 0);

  late final List<double> fractions = hasActiveColors
      ? normalizedMixWeights(ingredients.map((item) => item.weight))
      : List<double>.unmodifiable(List<double>.filled(ingredients.length, 0));

  Iterable<WeightedColor> get _weightedColors => ingredients.map(
    (item) => WeightedColor(color: item.color, weight: item.weight),
  );

  late final RgbColor? labResult = hasActiveColors
      ? mixColors(_weightedColors, space: MixingSpace.lab)
      : null;

  late final RgbColor? rgbResult = hasActiveColors
      ? mixColors(_weightedColors, space: MixingSpace.rgb)
      : null;

  RgbColor? get selectedResult => switch (space) {
    MixingSpace.lab => labResult,
    MixingSpace.rgb => rgbResult,
  };

  MixerState copyWith({
    Iterable<MixerIngredient>? ingredients,
    MixingSpace? space,
  }) => MixerState(
    ingredients: ingredients ?? this.ingredients,
    space: space ?? this.space,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MixerState ||
        space != other.space ||
        ingredients.length != other.ingredients.length) {
      return false;
    }
    for (var index = 0; index < ingredients.length; index++) {
      if (ingredients[index] != other.ingredients[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(space, Object.hashAll(ingredients));
}
