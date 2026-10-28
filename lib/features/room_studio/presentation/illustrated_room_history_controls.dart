import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';

class IllustratedRoomHistoryControls extends StatelessWidget {
  const IllustratedRoomHistoryControls({
    super.key,
    required this.onUndo,
    required this.onRedo,
  });
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('room-undo'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onUndo,
        icon: const Icon(Icons.undo),
        label: Text(context.l10n.roomUndo),
      ),
      OutlinedButton.icon(
        key: const ValueKey('room-redo'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onRedo,
        icon: const Icon(Icons.redo),
        label: Text(context.l10n.roomRedo),
      ),
    ],
  );
}
