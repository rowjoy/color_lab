import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme.dart';
import 'window_size_class.dart';

@immutable
final class AppDestinationSpec {
  const AppDestinationSpec({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
  }) : assert(id != ''),
       assert(label != '');

  final String id;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
}

final class AdaptiveAppShell extends StatelessWidget {
  const AdaptiveAppShell({
    super.key,
    required this.navigationShell,
    required this.destinations,
  }) : assert(destinations.length >= 2);

  final StatefulNavigationShell navigationShell;
  final List<AppDestinationSpec> destinations;

  @override
  Widget build(BuildContext context) {
    assert(
      destinations.map((destination) => destination.id).toSet().length ==
          destinations.length,
      'Destination IDs must be unique.',
    );
    assert(navigationShell.currentIndex < destinations.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = windowSizeClassFor(constraints.maxWidth);
        if (!sizeClass.usesNavigationRail) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: NavigationBar(
              key: const ValueKey('adaptive-shell-bottom-navigation'),
              selectedIndex: navigationShell.currentIndex,
              animationDuration: AppMotion.duration(context),
              maintainBottomViewPadding: true,
              onDestinationSelected: (index) => _select(index),
              destinations: [
                for (var index = 0; index < destinations.length; index++)
                  NavigationDestination(
                    key: ValueKey('nav-${destinations[index].id}'),
                    icon: Icon(destinations[index].icon),
                    selectedIcon: Icon(
                      destinations[index].selectedIcon ??
                          destinations[index].icon,
                    ),
                    label: destinations[index].label,
                  ),
              ],
            ),
          );
        }

        final extended = sizeClass == WindowSizeClass.large;
        final direction = Directionality.of(context);
        return Scaffold(
          body: Row(
            // Nested Navigators block semantics painted before their active
            // route. Paint the rail last while reversing only flex placement
            // so it remains leading in both LTR and RTL layouts.
            textDirection: direction == TextDirection.ltr
                ? TextDirection.rtl
                : TextDirection.ltr,
            children: [
              Expanded(child: navigationShell),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: context.appColors.outline,
              ),
              NavigationRail(
                key: const ValueKey('adaptive-shell-navigation-rail'),
                selectedIndex: navigationShell.currentIndex,
                extended: extended,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                minWidth: 72,
                minExtendedWidth: 216,
                groupAlignment: -0.7,
                scrollable: true,
                onDestinationSelected: (index) => _select(index),
                destinations: [
                  for (var index = 0; index < destinations.length; index++)
                    NavigationRailDestination(
                      icon: _RailIcon(icon: destinations[index].icon),
                      selectedIcon: _RailIcon(
                        icon:
                            destinations[index].selectedIcon ??
                            destinations[index].icon,
                      ),
                      label: Text(
                        destinations[index].label,
                        key: ValueKey('nav-${destinations[index].id}'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );
}

class _RailIcon extends StatelessWidget {
  const _RailIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: AppTouchTargets.minimum, child: Icon(icon));
}
