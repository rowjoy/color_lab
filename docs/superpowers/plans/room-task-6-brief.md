### Task 6: Brush erase and exact bounded undo

**Files:**

- Create: `lib/features/room_studio/domain/{mask_stroke,mask_undo}.dart`.
- Create: `lib/features/room_studio/refine/{mask_refinement,mask_refinement_service}.dart`.
- Test: `test/features/room_studio/refine/mask_refinement_test.dart`, `test/features/room_studio/domain/mask_undo_test.dart`.

**Interfaces:**

- Immutable `MaskPoint(double x, double y)` requires finite normalized 0–1 coordinates. `MaskEditMode { add, erase }`.
- `MaskStroke({required RoomLayer layer, required MaskEditMode mode, required List<List<MaskPoint>> segments, double diameterFraction = .05})` snapshots nonempty segments/points and validates diameter .01–.20. Separate segments prevent a line being painted across an out-of-image excursion.
- `MaskUndoCommand({required int width, required int height, required Uint32List indices, required Uint8List previousLabels})` copies sorted unique in-bounds changed indices and labels 0–4; `int get byteLength` counts its typed buffers. No unchanged-pixel entries or empty command.
- `MaskUndoHistory()` exposes immutable commands, nullable `last`, `byteLength`, `canUndo`, `push(MaskUndoCommand)` and `withoutLast()`. Caps are exactly 20 commands and 16×1024×1024 typed bytes; evict oldest first, sharing immutable command objects rather than copying their buffers on every push.
- `MaskEditResult` exposes new `MaskBitmap masks`, nullable `MaskUndoCommand undo`, and `int changedFromAiCount`.
- `MaskEditResult applyMaskStroke({required MaskBitmap current, required MaskBitmap ai, required MaskStroke stroke})`; `MaskEditResult undoMaskStroke({required MaskBitmap current, required MaskBitmap ai, required MaskUndoCommand command})`.
- `MaskRefinementService`: `Future<MaskEditResult> apply({required MaskBitmap current, required MaskBitmap ai, required MaskStroke stroke})` and `Future<MaskEditResult> undo({required MaskBitmap current, required MaskBitmap ai, required MaskUndoCommand command})`. `IsolateMaskRefinementService` calls the pure functions through `compute`; `maskRefinementServiceProvider` provides this adapter. It owns no interpreter or persistent project store.

- [ ] **Write exact-pixel tests.** A point stroke at normalized (.25,.25), diameter .01, on a 2×2 map `[1,2,0,4]` must produce `[3,2,0,4]` when adding Floor and undo to the original bytes. Erasing Wall over an owned Floor is a no-op. Pin interpolated segment coverage using pixel-center distance, disconnected segments, border clipping, invalid points, no-op command absence, exact restore, full-byte budget and oldest-first eviction. Dirty count remains positive when an earlier non-undoable edit survives history eviction.

```dart
final before = MaskBitmap(width: 2, height: 2,
  labels: Uint8List.fromList([1, 2, 0, 4]));
final stroke = MaskStroke(layer: RoomLayer.floor, mode: MaskEditMode.add,
  segments: [[MaskPoint(.25, .25)]], diameterFraction: .01);
final edit = applyMaskStroke(current: before, ai: before, stroke: stroke);
expect(edit.masks.labels, [3, 2, 0, 4]);
expect(undoMaskStroke(current: edit.masks, ai: before,
  command: edit.undo!).masks.labels, before.labels);
```

- [ ] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/refine/mask_refinement_test.dart test/features/room_studio/domain/mask_undo_test.dart --reporter expanded` after Task 5's AI gate; missing refinement APIs or incorrect pixels fail. Do not substitute manual-first work for a failed model gate.
- [ ] **Implement the pure operations.** Paint pixel centers whose distance to a segment/point is at most half the selected fraction of the shorter image side. Add transfers ownership; Erase touches selected ownership only. Collect previous labels once per changed index. Undo restores those bytes exactly; calculate differences from the original AI map in the worker, not by history length. No smoothing of ownership during strokes.
- [ ] **Verify GREEN.** Both test files, scoped analyzer/format and real `compute` adapter round trip pass. Count delta buffers precisely; the 1600×1600 image limit permits one full-frame 5-byte-per-pixel delta within 16 MiB. No UI-isolate pixel loops.
- [ ] **Record acceptance.** `room-task-6-report.md` with independent expected bytes and budget evidence. No controller, acquisition or screen changes.

