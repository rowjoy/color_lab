import 'package:color_lab/core/color/color_models.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_assignments.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_edit.dart';
import 'package:color_lab/features/room_studio/domain/illustrated_room_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final base = IllustratedRoomAssignments.fromColors(
    IllustratedRoomCatalog.study.defaultPalette.colors,
    membership: IllustratedRoomRegionMembership.study,
  );

  // Mutations caught: lossy before/after snapshots; history omits grayscale transition.
  test(
    'undo redo restore exact maps and grayscale, without mutating snapshots',
    () {
      final one = base.setRegionColor('wall-side', RgbColor.fromHex('#123456'));
      final two = one.setRegionColor('desk', RgbColor.fromHex('#654321'));
      final history = IllustratedRoomHistory().record(one).record(two);
      expect(history.undoCommands.length, 2);
      expect(history.undoCommands.first.before, isNull);
      expect(history.undoCommands.first.after, one);
      expect(
        history.undoCommands.last,
        IllustratedRoomEdit(before: one, after: two),
      );
      expect(
        history.undoCommands.last.hashCode,
        IllustratedRoomEdit(
          before: one.copyWith(),
          after: two.copyWith(),
        ).hashCode,
      );
      final undone = history.undo();
      expect(undone.current!.groupColors, one.groupColors);
      expect(undone.current!.regionOverrides, {
        'wall-side': RgbColor.fromHex('#123456'),
      });
      final grayscale = undone.undo();
      expect(grayscale.current, isNull);
      expect(grayscale.canUndo, isFalse);
      expect(grayscale.undo(), same(grayscale));
      final restored = grayscale.redo().redo();
      expect(restored.current!.groupColors, two.groupColors);
      expect(restored.current!.regionOverrides, two.regionOverrides);
      expect(restored.canRedo, isFalse);
      expect(restored.redo(), same(restored));
      expect(history.current, two);
      expect(() => history.undoCommands.clear(), throwsUnsupportedError);
      expect(() => grayscale.redoCommands.clear(), throwsUnsupportedError);
    },
  );

  // Mutations caught: forgotten redo clearing; equal copies incorrectly consume commands.
  test(
    'new edit clears redo and exact no-op retains redo and command count',
    () {
      final first = base.setRegionColor('desk', RgbColor.fromHex('#123456'));
      final second = first.setGroupColor('walls', RgbColor.fromHex('#654321'));
      final undone = IllustratedRoomHistory(
        initial: base,
      ).record(first).record(second).undo();
      expect(undone.record(first.copyWith()), same(undone));
      expect(undone.canRedo, isTrue);
      final branch = undone.record(base);
      expect(branch.canRedo, isFalse);
      expect(branch.undoCommands.length, 2);
      expect(branch.undo().current, first);
      expect(branch.undo().undo().current, base);
    },
  );

  // Mutations caught: off-by-one cap, old snapshots discarded, map restoration synthesized.
  test(
    'overflow retains exactly latest 50 commands and their exact snapshots',
    () {
      var history = IllustratedRoomHistory();
      final snapshots = <IllustratedRoomAssignments?>[null];
      for (var i = 1; i <= 55; i++) {
        final next = (history.current ?? base).setRegionColor(
          i.isEven ? 'desk' : 'wall-side',
          RgbColor(i, i + 1, i + 2),
        );
        snapshots.add(next);
        history = history.record(next);
      }
      expect(history.undoCommands.length, 50);
      for (var i = 54; i >= 5; i--) {
        history = history.undo();
        expect(history.current!.groupColors, snapshots[i]!.groupColors);
        expect(history.current!.regionOverrides, snapshots[i]!.regionOverrides);
      }
      expect(history.canUndo, isFalse);
      expect(history.redoCommands.length, 50);
      for (var i = 6; i <= 55; i++) {
        history = history.redo();
        expect(history.current!.groupColors, snapshots[i]!.groupColors);
        expect(history.current!.regionOverrides, snapshots[i]!.regionOverrides);
      }
      expect(history.canRedo, isFalse);
      expect(history.undoCommands.length, 50);
    },
  );
}
