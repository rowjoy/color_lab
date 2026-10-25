import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Safe recovery UI for malformed game links and stale navigation data.
class InvalidGameLaunchScreen extends StatelessWidget {
  const InvalidGameLaunchScreen({
    super.key,
    this.message =
        'Start this game again from Games so the correct level can be loaded.',
  });

  final String message;

  void _returnToGames(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/games');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => _returnToGames(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      title: const Text('Game unavailable'),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            key: const ValueKey('invalid-game-launch'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports_outlined, size: 56),
              const SizedBox(height: 20),
              Text(
                'This game could not be opened safely.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const ValueKey('invalid-game-launch-back'),
                onPressed: () => _returnToGames(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Games'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
