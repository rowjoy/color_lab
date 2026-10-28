import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/l10n.dart';
import '../application/illustrated_room_controller.dart';
import '../application/room_designs_providers.dart';
import '../domain/illustrated_room_assignments.dart';
import '../domain/illustrated_room_comparison.dart';
import '../domain/saved_room_design.dart';

/// Comparison buttons use copied values; selecting B never opens the design.
class IllustratedRoomCompareControls extends ConsumerWidget {
  const IllustratedRoomCompareControls({super.key, required this.templateId});
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(illustratedRoomProvider);
    final draft = session.draftFor(templateId);
    if (draft == null || session.activeTemplateId != templateId) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(illustratedRoomProvider.notifier);
    final l10n = context.l10n;
    Widget button(
      String key,
      String label,
      VoidCallback? action, {
      bool selected = false,
    }) => Semantics(
      selected: selected,
      child: OutlinedButton(
        key: ValueKey(key),
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: action,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(label),
        ),
      ),
    );
    final variants =
        ref.watch(savedRoomDesignsProvider).asData?.value ??
        const <SavedRoomDesign>[];
    IllustratedRoomAssignments? snapshot(SavedRoomDesign design) {
      if (design.templateId != templateId || design.templateRevision != 1) {
        return null;
      }
      try {
        return design.snapshot.materializeForTemplate(
          draft.template,
          templateRevision: design.templateRevision,
        );
      } catch (_) {
        return null;
      }
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape):
            controller.clearComparison,
      },
      child: Focus(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.roomCompare,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(l10n.roomCompareHint),
            button(
              'room-compare-pin',
              l10n.roomComparePin,
              draft.assignments == null ? null : controller.pinBaseline,
            ),
            button(
              'room-compare-a',
              l10n.roomCompareA,
              draft.pinnedBaseline == null
                  ? null
                  : controller.showPinnedBaseline,
              selected:
                  draft.comparison.view ==
                  IllustratedRoomComparisonView.baseline,
            ),
            button(
              'room-compare-original',
              l10n.roomCompareOriginal,
              controller.showTemporaryOriginal,
              selected:
                  draft.comparison.view ==
                  IllustratedRoomComparisonView.original,
            ),
            button(
              'room-compare-grayscale',
              l10n.roomCompareGrayscale,
              controller.showTemporaryGrayscale,
              selected: draft.temporaryGrayscale,
            ),
            for (final design in variants)
              if (snapshot(design) case final value?)
                button(
                  'room-compare-b-${design.id}',
                  l10n.roomCompareVariant(design.name),
                  () {
                    if (ref.read(illustratedRoomProvider).activeTemplateId ==
                        templateId) {
                      controller.setComparisonVariant(value);
                    }
                  },
                  selected:
                      draft.comparison.view ==
                          IllustratedRoomComparisonView.variant &&
                      draft.displayAssignments == value,
                ),
            button(
              'room-compare-close',
              l10n.roomCompareCurrent,
              controller.clearComparison,
              selected: !draft.comparison.isActive,
            ),
          ],
        ),
      ),
    );
  }
}
