import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/illustrated_room_draft.dart';
import 'illustrated_room_controller.dart';
import 'illustrated_room_draft_store.dart';

/// Starts with the editor, then follows the retained session for rename/delete
/// and handoffs even while another route is visible. The shared store owns IO.
final illustratedRoomEditorPersistenceProvider = Provider<void>((ref) {
  final initial = ref.read(illustratedRoomProvider);
  bool pristine(IllustratedRoomDraft draft) =>
      draft.assignments == null &&
      draft.savedDesignId == null &&
      !draft.history.canUndo &&
      !draft.history.canRedo;
  final candidates = <String, IllustratedRoomDraft>{
    for (final entry in initial.draftsByTemplateId.entries)
      if (pristine(entry.value)) entry.key: entry.value,
  };
  final pending = <IllustratedRoomDraft>[
    for (final draft in initial.draftsByTemplateId.values)
      if (!pristine(draft)) draft,
  ];
  IllustratedRoomDraftStore? store;
  bool recovering = false;
  void recover(IllustratedRoomDraftStore owner, IllustratedRoomDraft expected) {
    if (!ref.mounted ||
        !identical(
          ref.read(illustratedRoomProvider).draftFor(expected.template.id),
          expected,
        )) {
      return;
    }
    final restored = owner.restoreAcknowledged(expected.template);
    if (restored == null) return;
    recovering = true;
    try {
      ref
          .read(illustratedRoomProvider.notifier)
          .resumeDraft(
            restored.withComparison(expected.comparison),
            expected: expected,
          );
    } finally {
      recovering = false;
    }
  }

  void retain(IllustratedRoomDraft draft) {
    final owner = store;
    if (owner == null) {
      pending.add(draft);
    } else {
      // The owner publishes Failed and retains the exact visible draft for Retry.
      unawaited(owner.retain(draft).catchError((Object _) {}));
    }
  }

  ref.listen(illustratedRoomProvider, (previous, next) {
    if (recovering) return;
    for (final entry in next.draftsByTemplateId.entries) {
      final before = previous?.draftFor(entry.key);
      if (identical(before, entry.value)) continue;
      if (before == entry.value &&
          before?.pinnedBaseline == entry.value.pinnedBaseline) {
        if (identical(candidates[entry.key], before)) {
          candidates[entry.key] = entry.value;
        }
        continue;
      }
      if (before == null && pristine(entry.value)) {
        candidates[entry.key] = entry.value;
        final owner = store;
        if (owner != null) {
          scheduleMicrotask(() {
            recover(owner, entry.value);
          });
        }
      } else {
        candidates.remove(entry.key);
        retain(entry.value);
      }
    }
  });
  ref.listen(illustratedRoomDraftStoreProvider, (_, next) {
    if (next.isLoading || next.hasError) {
      store = null;
      return;
    }
    if (!next.hasValue) return;
    final owner = next.requireValue;
    scheduleMicrotask(() {
      if (!ref.mounted || identical(store, owner)) return;
      store = owner;
      for (final entry in candidates.entries) {
        recover(owner, entry.value);
      }
      for (final draft in pending) {
        retain(draft);
      }
      pending.clear();
    });
  }, fireImmediately: true);
});
