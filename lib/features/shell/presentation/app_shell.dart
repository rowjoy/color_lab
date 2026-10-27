import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../l10n/l10n.dart';
import '../../picker/presentation/acquisition_recovery_scope.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (id: 'Capture', icon: Icons.center_focus_strong_rounded),
    (id: 'Palette', icon: Icons.palette_outlined),
    (id: 'Lab', icon: Icons.science_outlined),
    (id: 'Room', icon: Icons.chair_outlined),
    (id: 'Games', icon: Icons.sports_esports_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.captureDestination,
      context.l10n.paletteDestination,
      context.l10n.labDestination,
      context.l10n.roomDestination,
      context.l10n.gamesDestination,
    ];
    return Scaffold(
      body: AcquisitionRecoveryScope(child: navigationShell),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: GlassBar(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(_destinations.length, (index) {
                final item = _destinations[index];
                final label = labels[index];
                final selected = index == navigationShell.currentIndex;
                return Expanded(
                  child: Semantics(
                    selected: selected,
                    button: true,
                    label: context.l10n.destinationTab(label),
                    child: InkWell(
                      key: ValueKey('nav-${item.id}'),
                      borderRadius: BorderRadius.circular(AppRadii.medium),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        navigationShell.goBranch(index);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                color: selected
                                    ? context.appColors.textPrimary
                                    : context.appColors.textSecondary,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                label,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: selected
                                          ? context.appColors.textPrimary
                                          : context.appColors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                width: AppSpacing.xs,
                                height: AppSpacing.xs,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: selected
                                      ? context.appColors.accentGradient
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
