import 'package:flutter/material.dart';

import '../domain/game_id.dart';

enum GameHubCategory {
  learnWithColor,
  colorLogic,
  playAndRelax;

  String get label => switch (this) {
    GameHubCategory.learnWithColor => 'Learn with Color',
    GameHubCategory.colorLogic => 'Color Logic',
    GameHubCategory.playAndRelax => 'Play & Relax',
  };

  String get description => switch (this) {
    GameHubCategory.learnWithColor =>
      'Train your eye and understand how colors move.',
    GameHubCategory.colorLogic =>
      'Solve calm puzzles with color, order, and strategy.',
    GameHubCategory.playAndRelax => 'Quick, colorful games for an easy break.',
  };

  IconData get icon => switch (this) {
    GameHubCategory.learnWithColor => Icons.school_rounded,
    GameHubCategory.colorLogic => Icons.psychology_alt_rounded,
    GameHubCategory.playAndRelax => Icons.sports_esports_rounded,
  };
}

/// Stable presentation copy shared by the Games hub, maps, and rankings.
final class GameUiMetadata {
  const GameUiMetadata({
    required this.gameId,
    required this.category,
    required this.label,
    required this.description,
    required this.icon,
  });

  final GameId gameId;
  final GameHubCategory category;
  final String label;
  final String description;
  final IconData icon;
}

const List<GameUiMetadata> gameUiMetadata = [
  GameUiMetadata(
    gameId: GameId.bubbleShooter,
    category: GameHubCategory.playAndRelax,
    label: 'Bubble Shooter',
    description: 'Aim, bounce, and match bubbles to clear the board.',
    icon: Icons.bubble_chart_rounded,
  ),
  GameUiMetadata(
    gameId: GameId.fruitPop,
    category: GameHubCategory.playAndRelax,
    label: 'Fruit & Veggie Pop',
    description: 'Swap colorful produce, clear the goal, and level up.',
    icon: Icons.eco_rounded,
  ),
  GameUiMetadata(
    gameId: GameId.waterSort,
    category: GameHubCategory.colorLogic,
    label: 'Water Sort',
    description: 'Pour matching colors together and clear every tube.',
    icon: Icons.water_drop_rounded,
  ),
  GameUiMetadata(
    gameId: GameId.rainbowRings,
    category: GameHubCategory.colorLogic,
    label: 'Rainbow Rings',
    description: 'Sort every colored ring onto its matching stack.',
    icon: Icons.donut_large_rounded,
  ),
  GameUiMetadata(
    gameId: GameId.colorMatch,
    category: GameHubCategory.learnWithColor,
    label: 'Color Match',
    description: 'Match your mix to the target shade and build your score.',
    icon: Icons.colorize_rounded,
  ),
];

GameUiMetadata metadataForGame(GameId gameId) =>
    gameUiMetadata.firstWhere((metadata) => metadata.gameId == gameId);
