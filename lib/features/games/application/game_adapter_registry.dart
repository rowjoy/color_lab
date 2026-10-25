import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../color_test/domain/color_match_level_adapter.dart';
import '../domain/adapters/bubble_shooter_level_adapter.dart';
import '../domain/adapters/fruit_pop_level_adapter.dart';
import '../domain/adapters/rainbow_rings_level_adapter.dart';
import '../domain/adapters/water_sort_level_adapter.dart';
import '../domain/game_id.dart';
import '../domain/game_level_adapter.dart';
import '../domain/game_level_catalog.dart';
import '../domain/game_progression_engine.dart';

/// The complete production adapter set used by endless progression.
final class ProductionGameAdapterRegistry implements GameLevelAdapterRegistry {
  ProductionGameAdapterRegistry({Iterable<GameLevelAdapter>? adapters})
    : _adapters = _validate(
        adapters ??
            <GameLevelAdapter>[
              BubbleShooterLevelAdapter(),
              FruitPopLevelAdapter(),
              WaterSortLevelAdapter(),
              RainbowRingsLevelAdapter(),
              ColorMatchLevelAdapter(),
            ],
      );

  final Map<GameId, GameLevelAdapter> _adapters;

  @override
  GameLevelAdapter adapterFor(GameId gameId) {
    final adapter = _adapters[gameId];
    if (adapter == null) {
      throw StateError('No adapter registered for ${gameId.storageId}');
    }
    return adapter;
  }

  static Map<GameId, GameLevelAdapter> _validate(
    Iterable<GameLevelAdapter> adapters,
  ) {
    final byId = <GameId, GameLevelAdapter>{};
    for (final adapter in adapters) {
      if (byId.containsKey(adapter.gameId)) {
        throw ArgumentError.value(
          adapter.gameId,
          'adapters',
          'Duplicate game adapter',
        );
      }
      byId[adapter.gameId] = adapter;
    }
    final missing = GameId.values.where((gameId) => !byId.containsKey(gameId));
    if (missing.isNotEmpty || byId.length != GameId.values.length) {
      throw ArgumentError.value(
        adapters,
        'adapters',
        'Exactly one adapter is required for every game',
      );
    }
    return Map<GameId, GameLevelAdapter>.unmodifiable(byId);
  }
}

final gameAdapterRegistryProvider = Provider<GameLevelAdapterRegistry>(
  (ref) => ProductionGameAdapterRegistry(),
);

final gameProgressionEngineProvider = Provider<GameProgressionEngine>(
  (ref) => GameProgressionEngine(
    catalog: GameLevelCatalog(registry: ref.watch(gameAdapterRegistryProvider)),
  ),
);
