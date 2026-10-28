import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

import '../domain/drawing_definition.dart';

Future<ColoringMode?> showColoringModeSheet(
  BuildContext context, {
  required String drawingTitle,
}) => showModalBottomSheet<ColoringMode>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(drawingTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(context.l10n.coloringChooseMode),
          const SizedBox(height: 20),
          _ModeCard(
            key: const ValueKey('coloring-mode-guided'),
            icon: Icons.route_rounded,
            title: context.l10n.coloringGuidedMode,
            description: context.l10n.coloringGuidedDescription,
            onTap: () => Navigator.pop(context, ColoringMode.guided),
          ),
          const SizedBox(height: 12),
          _ModeCard(
            key: const ValueKey('coloring-mode-free'),
            icon: Icons.palette_outlined,
            title: context.l10n.coloringFreeMode,
            description: context.l10n.coloringFreeDescription,
            onTap: () => Navigator.pop(context, ColoringMode.free),
          ),
        ],
      ),
    ),
  ),
);

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(description),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}
