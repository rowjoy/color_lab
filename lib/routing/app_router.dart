import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/lab/presentation/lab_screen.dart';
import '../features/palette/presentation/palette_screen.dart';
import '../features/picker/presentation/capture_screen.dart';
import '../features/picker/domain/prepared_photo.dart';
import '../features/picker/presentation/camera_picker_screen.dart';
import '../features/picker/presentation/photo_picker_screen.dart';
import '../features/room_studio/presentation/room_screen.dart';
import '../features/room_studio/presentation/room_mask_screen.dart';
import '../features/room_studio/presentation/illustrated_room_gallery_screen.dart';
import '../features/room_studio/presentation/illustrated_room_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/application/app_preferences_providers.dart';
import '../features/settings/presentation/preferences_startup_screen.dart';
import '../features/mixer/presentation/mixer_screen.dart';
import '../features/formula/presentation/formula_screen.dart';
import '../features/harmonies/presentation/harmonies_screen.dart';
import '../features/palette/presentation/saved_palettes_screen.dart';
import '../features/color_test/presentation/matching_screen.dart';
import '../features/color_test/presentation/vision_screen.dart';
import '../features/games/domain/game_id.dart';
import '../features/games/domain/game_launch.dart';
import '../features/games/presentation/badges_screen.dart';
import '../features/games/presentation/bubble_shooter_screen.dart';
import '../features/games/presentation/fruit_pop_screen.dart';
import '../features/games/presentation/game_level_map_screen.dart';
import '../features/games/presentation/games_screen.dart';
import '../features/games/presentation/invalid_game_launch_screen.dart';
import '../features/games/presentation/leaderboard_screen.dart';
import '../features/games/presentation/rainbow_rings_screen.dart';
import '../features/games/presentation/water_sort_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/capture',
    redirect: (context, state) {
      final preferences = ref.read(appPreferencesProvider);
      final path = state.uri.path;
      if (!preferences.hasValue) return path == '/startup' ? null : '/startup';
      if (!preferences.requireValue.onboardingCompleted) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if (path == '/startup' || path == '/onboarding') return '/capture';
      return null;
    },
    routes: [
      GoRoute(
        path: '/room/study',
        redirect: (context, state) => '/room/illustrated/study',
      ),
      GoRoute(
        path: '/room/illustrated',
        builder: (context, state) => const IllustratedRoomGalleryScreen(),
      ),
      GoRoute(
        path: '/room/illustrated/:templateId',
        builder: (context, state) => IllustratedRoomScreen(
          templateId: state.pathParameters['templateId']!,
        ),
      ),
      GoRoute(
        path: '/room/masks',
        builder: (context, state) => const RoomMaskScreen(),
      ),
      GoRoute(
        path: '/vision',
        builder: (context, state) => const VisionScreen(),
      ),
      GoRoute(
        path: '/matching',
        builder: (context, state) => state.extra == null
            ? const MatchingScreen()
            : _buildGameScreen(context, state, GameId.colorMatch),
      ),
      GoRoute(
        path: '/bubble-shooter',
        builder: (context, state) =>
            _buildGameScreen(context, state, GameId.bubbleShooter),
      ),
      GoRoute(
        path: '/rainbow-rings',
        builder: (context, state) =>
            _buildGameScreen(context, state, GameId.rainbowRings),
      ),
      GoRoute(
        path: '/water-sort',
        builder: (context, state) =>
            _buildGameScreen(context, state, GameId.waterSort),
      ),
      GoRoute(
        path: '/fruit-pop',
        builder: (context, state) =>
            _buildGameScreen(context, state, GameId.fruitPop),
      ),
      GoRoute(
        path: '/games/badges',
        builder: (context, state) => const BadgesScreen(),
      ),
      GoRoute(
        path: '/games/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(path: '/games/:gameId/map', builder: _buildMapScreen),
      GoRoute(
        path: '/harmonies',
        builder: (context, state) => const HarmoniesScreen(),
      ),
      GoRoute(
        path: '/palettes',
        builder: (context, state) =>
            SavedPalettesScreen(returnToHarmony: state.extra == true),
      ),
      GoRoute(
        path: '/formula',
        builder: (context, state) => const FormulaScreen(),
      ),
      GoRoute(path: '/mixer', builder: (context, state) => const MixerScreen()),
      GoRoute(
        path: '/startup',
        builder: (context, state) => const PreferencesStartupScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) => OnboardingScreen(
            onFinish: () =>
                ref.read(appPreferencesProvider.notifier).completeOnboarding(),
          ),
        ),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => OnboardingScreen(
          isReplay: true,
          onFinish: () async {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/capture');
            }
          },
        ),
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => const CameraPickerScreen(),
      ),
      GoRoute(
        path: '/photo',
        builder: (context, state) {
          final photo = state.extra;
          return photo is PreparedPhoto
              ? PhotoPickerScreen(photo: photo)
              : Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Choose a photo to start exploring its colors.',
                            ),
                            TextButton(
                              onPressed: () => context.go('/capture'),
                              child: const Text('Return to Capture'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          _branch('/capture', const CaptureScreen()),
          _branch('/palette', const PaletteScreen()),
          _branch('/lab', const LabScreen()),
          _branch('/room', const RoomScreen()),
          _gamesBranch(),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => context.go('/capture'),
          child: const Text('Return to Color Lab'),
        ),
      ),
    ),
  );
  // Refresh guards in place: theme writes must not replace indexed navigators.
  ref.listen(appPreferencesProvider, (previous, next) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => screen)],
);

StatefulShellBranch _gamesBranch() => StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/games',
      builder: (context, state) => GamesScreen(
        onLaunchGame: (launch) => _pushGame(context, launch),
        onOpenMap: (gameId) => _pushMap(context, gameId),
        onOpenBadges: () => _push(context, '/games/badges'),
        onOpenLeaderboard: () => _push(context, '/games/leaderboard'),
      ),
    ),
  ],
);

Widget _buildGameScreen(
  BuildContext context,
  GoRouterState state,
  GameId expectedGameId,
) {
  final extra = state.extra;
  if (extra is! GameLaunch ||
      extra.gameId != expectedGameId ||
      extra.descriptor.gameId != expectedGameId) {
    return const InvalidGameLaunchScreen();
  }

  void openMap() => _pushMap(context, expectedGameId);
  return switch (expectedGameId) {
    GameId.bubbleShooter => BubbleShooterScreen(
      launch: extra,
      onOpenMap: openMap,
    ),
    GameId.fruitPop => FruitPopScreen(launch: extra, onOpenMap: openMap),
    GameId.waterSort => WaterSortScreen(launch: extra, onOpenMap: openMap),
    GameId.rainbowRings => RainbowRingsScreen(
      launch: extra,
      onOpenMap: openMap,
    ),
    GameId.colorMatch => MatchingScreen(launch: extra, onOpenMap: openMap),
  };
}

Widget _buildMapScreen(BuildContext context, GoRouterState state) {
  final rawGameId = state.pathParameters['gameId'];
  final GameId gameId;
  try {
    gameId = GameId.parse(rawGameId ?? '');
  } on FormatException {
    return const InvalidGameLaunchScreen(
      message: 'That level map is not available.',
    );
  }
  return GameLevelMapScreen(
    gameId: gameId,
    onLaunchGame: (launch) => _pushGame(context, launch),
  );
}

void _pushGame(BuildContext context, GameLaunch launch) =>
    _push(context, _playPath(launch.gameId), extra: launch);

void _pushMap(BuildContext context, GameId gameId) =>
    _push(context, '/games/${gameId.storageId}/map');

void _push(BuildContext context, String location, {Object? extra}) {
  unawaited(context.push<void>(location, extra: extra));
}

String _playPath(GameId gameId) => switch (gameId) {
  GameId.bubbleShooter => '/bubble-shooter',
  GameId.fruitPop => '/fruit-pop',
  GameId.waterSort => '/water-sort',
  GameId.rainbowRings => '/rainbow-rings',
  GameId.colorMatch => '/matching',
};
