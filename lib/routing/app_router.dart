import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/lab/presentation/lab_screen.dart';
import '../features/learning/presentation/learn_screen.dart';
import '../features/learning/presentation/lesson_screen.dart';
import '../features/learning/presentation/experiment_notebook_screen.dart';
import '../features/learning/presentation/learning_experiment_route_screen.dart';
import '../features/learning/presentation/learning_experiment_host.dart';
import '../features/learning/data/color_foundations_catalog.dart';
import '../features/learning/domain/experiment_snapshot.dart';
import '../features/my_work/presentation/my_work_screen.dart';
import '../features/palette/presentation/palette_screen.dart';
import '../features/picker/presentation/capture_screen.dart';
import '../features/picker/domain/prepared_photo.dart';
import '../features/picker/presentation/camera_picker_screen.dart';
import '../features/picker/presentation/photo_picker_screen.dart';
import '../features/room_studio/presentation/room_screen.dart';
import '../features/room_studio/presentation/room_mask_screen.dart';
import '../features/room_studio/presentation/room_model_setup_panel.dart';
import '../features/room_studio/presentation/room_projects_screen.dart';
import '../features/room_studio/presentation/room_project_open_screen.dart';
import '../features/room_studio/presentation/illustrated_room_gallery_screen.dart';
import '../features/room_studio/presentation/illustrated_room_screen.dart';
import '../features/shell/presentation/app_shell.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/application/app_preferences_providers.dart';
import '../features/settings/presentation/preferences_startup_screen.dart';
import '../features/settings/presentation/privacy_screen.dart';
import '../features/settings/presentation/data_management_screen.dart';
import '../features/settings/presentation/model_storage_screen.dart';
import '../features/settings/presentation/settings_page.dart';
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
import '../features/coloring/presentation/coloring_catalog_screen.dart';
import '../features/coloring/presentation/coloring_workspace_screen.dart';
import '../features/coloring/presentation/coloring_completion_screen.dart';
import '../features/learning/domain/learning_palette_copy.dart';
import '../l10n/l10n.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  final homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'home');
  final roomsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rooms');
  final learnNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'learn');
  final gamesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'games');
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    restorationScopeId: 'tintatlas-router',
    initialLocation: '/home',
    redirect: (context, state) {
      final preferences = ref.read(appPreferencesProvider);
      final path = state.uri.path;
      if (!preferences.hasValue) return path == '/startup' ? null : '/startup';
      if (!preferences.requireValue.onboardingCompleted) {
        return path == '/onboarding' ? null : '/onboarding';
      }
      if (path == '/startup' || path == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/settings/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/settings/data',
        builder: (context, state) => const DataManagementScreen(),
      ),
      GoRoute(
        path: '/settings/models',
        builder: (context, state) => const ModelStorageScreen(),
      ),
      GoRoute(
        path: '/settings/licenses',
        builder: (context, state) => SettingsPage(
          title: context.l10n.settingsLicensesEntry,
          children: [
            Text(context.l10n.appName),
            TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: context.l10n.appName,
              ),
              child: Text(context.l10n.aboutAndLicenses(context.l10n.appName)),
            ),
          ],
        ),
      ),
      GoRoute(path: '/room', redirect: (context, state) => '/rooms'),
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
        path: '/rooms/projects',
        builder: (context, state) => const RoomProjectsScreen(),
      ),
      GoRoute(
        path: '/rooms/project/:projectId',
        redirect: (context, state) => Uri(
          path: '/room/masks',
          queryParameters: {
            'project': state.pathParameters['projectId']!,
            if (state.uri.queryParameters['compare'] == '1') 'compare': '1',
          },
        ).toString(),
      ),
      GoRoute(
        path: '/room/masks',
        builder: (context, state) {
          // A saved editor's analysis setup retains its owner through restart.
          // This guard takes precedence even if a project query is also given.
          final setupProjectId = state.uri.queryParameters['setupProject'];
          if (setupProjectId != null) {
            return RoomModelSetupGate(
              child: RoomProjectOpenScreen(
                projectId: setupProjectId,
                isSetupContinuation: true,
                compareRequested: state.uri.queryParameters['compare'] == '1',
              ),
            );
          }
          final projectId = state.uri.queryParameters['project'];
          return projectId == null
              ? const RoomModelSetupGate(child: RoomMaskScreen())
              : RoomProjectOpenScreen(
                  projectId: projectId,
                  compareRequested: state.uri.queryParameters['compare'] == '1',
                );
        },
      ),
      GoRoute(
        path: '/vision',
        builder: (context, state) => const VisionScreen(),
      ),
      GoRoute(
        path: '/lab',
        redirect: (context, state) => '/learn/experiment/lab',
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
        path: '/my-work',
        builder: (context, state) => const MyWorkScreen(),
      ),
      GoRoute(
        path: '/coloring',
        builder: (context, state) => ColoringCatalogScreen(
          paletteCopy: state.extra is LearningPaletteCopy
              ? state.extra as LearningPaletteCopy
              : null,
        ),
      ),
      GoRoute(
        path: '/coloring/project/:projectId',
        builder: (context, state) => ColoringWorkspaceScreen(
          projectId: state.pathParameters['projectId']!,
          paletteCopy: state.extra is LearningPaletteCopy
              ? state.extra as LearningPaletteCopy
              : null,
        ),
      ),
      GoRoute(
        path: '/coloring/complete/:projectId',
        builder: (context, state) => ColoringCompletionScreen(
          projectId: state.pathParameters['projectId']!,
          paletteCopy: state.extra is LearningPaletteCopy
              ? state.extra as LearningPaletteCopy
              : null,
        ),
      ),
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
              context.go('/home');
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
        restorationScopeId: 'tintatlas-shell',
        pageBuilder: (context, state, shell) => MaterialPage<void>(
          key: state.pageKey,
          restorationId: 'tintatlas-shell-page',
          child: AppShell(navigationShell: shell),
        ),
        branches: [
          _homeBranch(homeNavigatorKey),
          _roomsBranch(roomsNavigatorKey),
          _learnBranch(learnNavigatorKey),
          _gamesBranch(gamesNavigatorKey),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _RouteUnavailableScreen(),
  );
  // Refresh guards in place: theme writes must not replace indexed navigators.
  ref.listen(appPreferencesProvider, (previous, next) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

StatefulShellBranch _homeBranch(GlobalKey<NavigatorState> navigatorKey) =>
    StatefulShellBranch(
      navigatorKey: navigatorKey,
      restorationScopeId: 'home-branch',
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/capture',
          builder: (context, state) => const CaptureScreen(),
        ),
      ],
    );

StatefulShellBranch _roomsBranch(GlobalKey<NavigatorState> navigatorKey) =>
    StatefulShellBranch(
      navigatorKey: navigatorKey,
      restorationScopeId: 'rooms-branch',
      initialLocation: '/rooms',
      routes: [
        GoRoute(
          path: '/rooms',
          builder: (context, state) => const RoomScreen(),
        ),
      ],
    );

StatefulShellBranch _learnBranch(GlobalKey<NavigatorState> navigatorKey) =>
    StatefulShellBranch(
      navigatorKey: navigatorKey,
      restorationScopeId: 'learn-branch',
      initialLocation: '/learn',
      routes: [
        GoRoute(
          path: '/learn',
          builder: (context, state) => const LearnScreen(),
          routes: [
            GoRoute(path: 'lesson/:lessonId', builder: _buildLearningLesson),
            GoRoute(
              path: 'notebook',
              builder: (context, state) => const ExperimentNotebookScreen(),
            ),
            GoRoute(
              path: 'experiment/:experimentId',
              builder: _buildLearningExperiment,
            ),
          ],
        ),
        GoRoute(
          path: '/palette',
          builder: (context, state) => const PaletteScreen(),
        ),
      ],
    );

Widget _buildLearningLesson(BuildContext context, GoRouterState state) {
  final lessonId = state.pathParameters['lessonId']!;
  try {
    ColorFoundationsCatalog.byId(lessonId);
    return LessonScreen(lessonId: lessonId);
  } on FormatException {
    return const _RouteUnavailableScreen();
  }
}

Widget _buildLearningExperiment(BuildContext context, GoRouterState state) {
  final lessonId = _validLearningLessonId(state.uri.queryParameters['lesson']);
  return switch (state.pathParameters['experimentId']!) {
    'lab' => LearningExperimentHost(
      tool: ExperimentTool.lab,
      lessonId: lessonId,
      child: const LabScreen(),
    ),
    'mixer' => LearningExperimentHost(
      tool: ExperimentTool.mixer,
      lessonId: lessonId,
      child: const MixerScreen(),
    ),
    'harmonies' => LearningExperimentHost(
      tool: ExperimentTool.harmonies,
      lessonId: lessonId,
      child: const HarmoniesScreen(),
    ),
    'formula' => LearningExperimentHost(
      tool: ExperimentTool.formula,
      lessonId: lessonId,
      child: const FormulaScreen(),
    ),
    'matching' => LearningExperimentHost(
      tool: ExperimentTool.matching,
      lessonId: lessonId,
      child: const MatchingScreen(),
    ),
    final experimentId => LearningExperimentRouteScreen(
      experimentId: experimentId,
    ),
  };
}

String? _validLearningLessonId(String? lessonId) {
  if (lessonId == null) return null;
  try {
    ColorFoundationsCatalog.byId(lessonId);
    return lessonId;
  } on FormatException {
    return null;
  }
}

StatefulShellBranch _gamesBranch(GlobalKey<NavigatorState> navigatorKey) =>
    StatefulShellBranch(
      navigatorKey: navigatorKey,
      restorationScopeId: 'games-branch',
      initialLocation: '/games',
      routes: [
        GoRoute(
          path: '/games',
          builder: (context, state) => GamesScreen(
            onLaunchGame: (launch) => _pushGame(context, launch),
            onOpenMap: (gameId) => _pushMap(context, gameId),
            onOpenBadges: () => _push(context, '/games/badges'),
            onOpenLeaderboard: () => _push(context, '/games/leaderboard'),
            onOpenColoring: () => _push(context, '/coloring'),
          ),
        ),
      ],
    );

class _RouteUnavailableScreen extends StatelessWidget {
  const _RouteUnavailableScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('route-unavailable'),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.routeUnavailableTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.routeUnavailableBody,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const ValueKey('route-recovery-home'),
                onPressed: () => context.go('/home'),
                child: Text(context.l10n.returnHome),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

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
