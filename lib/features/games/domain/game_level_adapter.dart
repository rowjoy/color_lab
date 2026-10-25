import 'game_id.dart';
import 'game_level.dart';

abstract interface class GameLevelLayout {
  String get canonicalSignature;
}

abstract interface class GameLevelOutcome {}

abstract interface class GameLevelAdapter {
  GameId get gameId;
  int get currentGeneratorVersion;
  bool supportsVersion(int version);
  GameLevelLayout build(GameLevelDescriptor descriptor);
  int normalizeScore(GameLevelOutcome outcome);
}

abstract interface class GameLevelAdapterRegistry {
  GameLevelAdapter adapterFor(GameId gameId);
}
