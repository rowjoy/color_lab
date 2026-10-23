import 'dart:typed_data';

import 'package:color_lab/features/room_studio/domain/mask_undo.dart';
import 'package:flutter_test/flutter_test.dart';

MaskUndoCommand command(int marker) => MaskUndoCommand(
  width: 30,
  height: 1,
  indices: Uint32List.fromList([marker]),
  previousLabels: Uint8List.fromList([marker % 5]),
);

MaskUndoCommand largeCommand(int count) => MaskUndoCommand(
  width: 1600,
  height: 1600,
  indices: Uint32List.fromList(List.generate(count, (index) => index)),
  previousLabels: Uint8List(count),
);

void main() {
  test('command detaches typed input and exposes immutable buffer views', () {
    final indices = Uint32List.fromList([0, 2]);
    final labels = Uint8List.fromList([4, 1]);
    final delta = MaskUndoCommand(
      width: 3,
      height: 1,
      indices: indices,
      previousLabels: labels,
    );
    indices[0] = 1;
    labels[0] = 0;
    expect(delta.indices, [0, 2]);
    expect(delta.previousLabels, [4, 1]);
    expect(delta.byteLength, 10);
    expect(() => delta.indices[0] = 1, throwsUnsupportedError);
    expect(() => delta.previousLabels[0] = 0, throwsUnsupportedError);
    expect(
      () => delta.indices.buffer.asUint32List()[0] = 1,
      throwsUnsupportedError,
    );
    expect(
      () => delta.previousLabels.buffer.asUint8List()[0] = 0,
      throwsUnsupportedError,
    );
  });

  test(
    'rejects invalid dimensions, empty, mismatched, unsorted and invalid delta',
    () {
      for (final size in [(0, 1), (1, 0), (-1, 1)]) {
        expect(
          () => MaskUndoCommand(
            width: size.$1,
            height: size.$2,
            indices: Uint32List.fromList([0]),
            previousLabels: Uint8List.fromList([0]),
          ),
          throwsArgumentError,
        );
      }
      for (final data in <(List<int>, List<int>)>[
        ([], []),
        ([0], []),
        ([1, 0], [0, 0]),
        ([0, 0], [0, 0]),
        ([3], [0]),
        ([0], [5]),
      ]) {
        expect(
          () => MaskUndoCommand(
            width: 3,
            height: 1,
            indices: Uint32List.fromList(data.$1),
            previousLabels: Uint8List.fromList(data.$2),
          ),
          throwsArgumentError,
        );
      }
    },
  );

  test('empty history is immutable and safely stays empty when popped', () {
    final history = MaskUndoHistory();
    expect(history.commands, isEmpty);
    expect(history.last, isNull);
    expect(history.canUndo, isFalse);
    expect(history.byteLength, 0);
    expect(history.withoutLast().canUndo, isFalse);
    expect(() => history.commands.add(command(0)), throwsUnsupportedError);
  });

  test(
    'push and pop preserve snapshots and share immutable command objects',
    () {
      final first = command(0);
      final second = command(1);
      final empty = MaskUndoHistory();
      final one = empty.push(first);
      final two = one.push(second);
      final popped = two.withoutLast();
      expect(empty.commands, isEmpty);
      expect(one.commands.length, 1);
      expect(two.commands.length, 2);
      expect(two.commands.first, same(first));
      expect(two.last, same(second));
      expect(two.byteLength, 10);
      expect(popped.last, same(first));
      expect(popped.byteLength, 5);
      expect(() => two.commands.clear(), throwsUnsupportedError);
    },
  );

  test('twenty-first command evicts only the oldest', () {
    final commands = List.generate(21, command);
    var history = MaskUndoHistory();
    for (final delta in commands) {
      history = history.push(delta);
    }
    expect(history.commands.length, 20);
    expect(history.commands.first, same(commands[1]));
    expect(history.last, same(commands[20]));
    expect(history.byteLength, 100);
  });

  test(
    'full-frame bytes fit, retain the last five-byte slot, then evict oldest',
    () {
      // 2,560,000 pixels * (4-byte index + 1-byte old label) = 12,800,000.
      // An additional 795,443 pixels = 3,977,215, total 16,777,215 bytes.
      // One further pixel exceeds the 16,777,216-byte cap by four bytes.
      final fullFrame = largeCommand(2560000);
      final rest = largeCommand(795443);
      expect(fullFrame.byteLength, 12800000);
      final exactFit = MaskUndoHistory().push(fullFrame).push(rest);
      expect(exactFit.commands.length, 2);
      expect(exactFit.byteLength, 16777215);
      final over = exactFit.push(command(0));
      expect(over.commands.length, 2);
      expect(over.commands.first, same(rest));
      expect(over.byteLength, 3977220);
      expect(exactFit.commands.first, same(fullFrame));
    },
  );

  test('a single over-budget command cannot leave the history over budget', () {
    final oversized = MaskUndoCommand(
      width: 3355444,
      height: 1,
      indices: Uint32List.fromList(List.generate(3355444, (index) => index)),
      previousLabels: Uint8List(3355444),
    );
    final history = MaskUndoHistory().push(command(0)).push(oversized);
    expect(oversized.byteLength, 16777220);
    expect(history.commands, isEmpty);
    expect(history.byteLength, 0);
    expect(history.canUndo, isFalse);
  });
}
