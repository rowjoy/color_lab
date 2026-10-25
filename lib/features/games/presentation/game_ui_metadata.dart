import 'package:flutter/material.dart';

import '../domain/game_id.dart';

/// Stable presentation copy shared by the Games hub, maps, and rankings.
final class GameUiMetadata {
  const GameUiMetadata({
    required this.gameId,
    required this.label,
    required this.description,
    required this.icon,
  });

  final GameId gameId;
  final String label;
  final String description;
  final IconData icon;
}

const List<GameUiMetadata> gameUiMetadata = [
  GameUiMetadata(
    gameId: GameId.bubbleShooter,
    label: 'Bubble Shooter',
    description: 'Aim, bounce, and match bubbles to clear the board.',
    icon: Icons.bubble_chart_rounded,
  ),
  GameUiMetadata(
    gameId: GameId.fruitPop,
    label: 'Fruit & Veggie Pop',
    description: 'Swap colorful produce, clear the goal, and level up.',
    icon: Icons.eco_rounded,
  ),
  GameUiMetadata(
    gameId: GameId.waterSort,
    label: 'Water Sort',
    description: 'Pour matching colors together and clear every tube.',
    icon: Icons.water_drop_rounded,
  ),
  GameUiMetadata(
    gameId: GameId.rainbowRings,
    label: 'Rainbow Rings',
    description: 'Sort every colored ring onto its matching stack.',
    icon: Icons.donut_large_rounded,
  ),
  GameUiMetadata(
    gameId: GameId.colorMatch,
    label: 'Color Match',
    description: 'Match your mix to the target shade and build your score.',
    icon: Icons.colorize_rounded,
  ),
];

GameUiMetadata metadataForGame(GameId gameId) =>
    gameUiMetadata.firstWhere((metadata) => metadata.gameId == gameId);
