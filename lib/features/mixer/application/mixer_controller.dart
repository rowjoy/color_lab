import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/color/color_engine.dart';
import '../domain/mixer_state.dart';

/// Keeps the draft alive for the lifetime of the application container.
final mixerProvider = NotifierProvider<MixerController, MixerState>(
  MixerController.new,
);

class MixerController extends Notifier<MixerState> {
  // Reset restores the initial entries, but never recycles an added color ID.
  int _nextColorId = 2;

  @override
  MixerState build() => MixerState.initial();

  void addColor(RgbColor color) {
    late String id;
    do {
      id = 'color-${_nextColorId++}';
    } while (state.ingredients.any((item) => item.id == id));
    state = state.copyWith(
      ingredients: [
        ...state.ingredients,
        MixerIngredient(id: id, color: color),
      ],
    );
  }

  void setColor(String id, RgbColor color) =>
      _editIngredient(id, (item) => item.copyWith(color: color));

  void setWeight(String id, double weight) =>
      _editIngredient(id, (item) => item.copyWith(weight: weight));

  void _editIngredient(
    String id,
    MixerIngredient Function(MixerIngredient) edit,
  ) {
    final index = state.ingredients.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final ingredients = state.ingredients.toList();
    ingredients[index] = edit(ingredients[index]);
    state = state.copyWith(ingredients: ingredients);
  }

  void removeColor(String id) {
    if (state.ingredients.length <= 2 ||
        !state.ingredients.any((item) => item.id == id)) {
      return;
    }
    state = state.copyWith(
      ingredients: state.ingredients.where((item) => item.id != id),
    );
  }

  void setSpace(MixingSpace space) => state = state.copyWith(space: space);

  void restore(MixerState draft) {
    state = draft;
    var next = 0;
    for (final ingredient in draft.ingredients) {
      final match = RegExp(r'^color-(\d+)$').firstMatch(ingredient.id);
      if (match != null) {
        final candidate = int.parse(match.group(1)!) + 1;
        if (candidate > next) next = candidate;
      }
    }
    _nextColorId = next;
  }

  void reset() => state = MixerState.initial();
}
