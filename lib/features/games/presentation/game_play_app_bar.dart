import 'package:flutter/material.dart';

/// Compact, consistent toolbar for active game screens.
class GamePlayAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GamePlayAppBar({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.buttonColor,
    required this.accentColor,
    this.onOpenMap,
    this.soundEnabled,
    this.onToggleSound,
    this.onRestart,
    this.locked = false,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color buttonColor;
  final Color accentColor;
  final VoidCallback? onOpenMap;
  final bool? soundEnabled;
  final VoidCallback? onToggleSound;
  final VoidCallback? onRestart;
  final bool locked;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 72,
    automaticallyImplyLeading: false,
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    leadingWidth: 54,
    leading: Padding(
      padding: const EdgeInsets.only(left: 12),
      child: IconButton.filledTonal(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: locked ? null : onBack,
        style: IconButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: foregroundColor,
          fixedSize: const Size(40, 40),
          padding: EdgeInsets.zero,
        ),
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
      ),
    ),
    titleSpacing: 8,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accentColor,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .9,
          ),
        ),
      ],
    ),
    actions: [
      if (onOpenMap != null)
        _MapHeaderAction(
          tooltip: 'Level map',
          onPressed: locked ? null : onOpenMap,
          foreground: foregroundColor,
          background: buttonColor,
        ),
      if (soundEnabled != null && onToggleSound != null)
        _HeaderAction(
          tooltip: soundEnabled! ? 'Mute game sounds' : 'Enable game sounds',
          icon: soundEnabled!
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          onPressed: onToggleSound,
          foreground: foregroundColor,
          background: buttonColor,
        ),
      if (onRestart != null)
        _HeaderAction(
          tooltip: 'Restart level',
          icon: Icons.refresh_rounded,
          onPressed: locked ? null : onRestart,
          foreground: foregroundColor,
          background: buttonColor,
        ),
      const SizedBox(width: 8),
    ],
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.foreground,
    required this.background,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        fixedSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: 19),
    ),
  );
}

class _MapHeaderAction extends StatelessWidget {
  const _MapHeaderAction({
    required this.tooltip,
    required this.onPressed,
    required this.foreground,
    required this.background,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.map_outlined, size: 17),
        label: const Text('Map'),
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: background,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
    ),
  );
}
