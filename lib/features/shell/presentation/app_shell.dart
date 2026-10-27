import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/adaptive_app_shell.dart';
import '../../../l10n/l10n.dart';
import '../../picker/presentation/acquisition_recovery_scope.dart';

enum AppDestination {
  home(
    path: '/home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  rooms(
    path: '/rooms',
    icon: Icons.chair_outlined,
    selectedIcon: Icons.chair_rounded,
  ),
  learn(
    path: '/learn',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school_rounded,
  ),
  games(
    path: '/games',
    icon: Icons.sports_esports_outlined,
    selectedIcon: Icons.sports_esports_rounded,
  );

  const AppDestination({
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final labels = {
      AppDestination.home: context.l10n.homeDestination,
      AppDestination.rooms: context.l10n.roomsDestination,
      AppDestination.learn: context.l10n.learnDestination,
      AppDestination.games: context.l10n.gamesDestination,
    };
    return AcquisitionRecoveryScope(
      child: AdaptiveAppShell(
        navigationShell: navigationShell,
        destinations: [
          for (final destination in AppDestination.values)
            AppDestinationSpec(
              id: destination.name,
              label: labels[destination]!,
              icon: destination.icon,
              selectedIcon: destination.selectedIcon,
            ),
        ],
      ),
    );
  }
}
