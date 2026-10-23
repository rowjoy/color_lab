### Task 7: Retained revision safe Room controller

**Files:**

- Create: `lib/features/room_studio/domain/room_mask_state.dart`.
- Create: `lib/features/room_studio/application/room_mask_controller.dart`.
- Test: `test/features/room_studio/application/room_mask_controller_test.dart`.

**Interfaces:**

- `RoomMaskStage { empty, acquiring, analyzing, ready, error }`; `RoomMaskTool { move, add, erase }`; `RoomMaskFailureKind { permissionDenied, acquisitionUnavailable, invalidImage, tooLarge, storage, modelUnavailable, incompatibleModel, invalidOutput, processing }`.
- Immutable `RoomPhotoCandidate` has photoId/PreparedPhoto. Immutable `RoomMaskDraft` has photoId/photo, original `aiMasks`, current `masks`, `MaskUndoHistory history`, nonnegative `maskRevision` and `changedFromAiCount`; `hasEdits` means changedFromAiCount > 0, not nonempty history. Both maps must match the photo dimensions.
- `RoomMaskState.initial()` exposes stage, nullable committed draft/candidate/failure, selectedLayer=Wall, tool=Move, brushFraction=.05, showOverlay=true, editBusy=false; `canEdit` only for ready, nonbusy, visible-overlay state with a committed AI draft. Keep immutable snapshots; avoid byte-array comparison on normal rebuilds.
- Retained `roomMaskProvider: NotifierProvider<RoomMaskController,RoomMaskState>`; `roomPhotoIdFactoryProvider: Provider<String Function()>` supplies unique in-session IDs and deterministic test IDs.
- Controller methods: `Future<void> importPhoto(PhotoSource source, {required bool Function() isActive})`, `Future<void> continueImport(String requestId, {required bool Function() isActive})`, `Future<void> analyzeCandidate()`, `Future<void> retryAnalysis()`, `void cancelCandidate()`, `void setLayer(RoomLayer)`, `void setTool(RoomMaskTool)`, `void setBrushFraction(double)`, `void setShowOverlay(bool)`.
- Captured mutation methods: `Future<bool> applyStroke({required String photoId, required int maskRevision, required MaskStroke stroke})`, `Future<bool> undo({required String photoId, required int maskRevision})`, `bool restoreAiMasks({required String photoId, required int maskRevision})`. Return false with no side effects for stale/busy/invalid-phase actions. `restoreAiMasks` is called only after UI confirmation.

- [ ] **Write real-provider transition tests.** Inject delayed acquisition/segmentation/refinement services and actual immutable maps. Assert no editing in empty/analyzing/failure states; valid all-empty AI result does permit manual marking. Old A success/error cannot replace equal-sized B. Late receipt remains pending rather than claimed; last successful draft survives pick cancel, failed inference and logical cancellation. Captured old stroke/undo/reset cannot affect a replacement or new revision. Test budget eviction still leaves `hasEdits=true`, and selection/theme/navigation do not reset masks.

```dart
expect(container.read(roomMaskProvider).canEdit, isFalse); // inference pending
expect(await controller.undo(photoId: 'photo-A', maskRevision: 0), isFalse);
expect(container.read(roomMaskProvider).draft, same(committedB));
```

- [ ] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/application/room_mask_controller_test.dart --reporter expanded` before its implementation. Use actual Task 3/5/6 contracts, not duplicate pending types.
- [ ] **Implement state ownership.** Read injected services without dependency-driven draft resets. Import starts a candidate operation while keeping committed data. Pass a live/current-operation and screen-active guard to acquisition `request(isActive:)`. Check isActive before claiming a receipt; use `claim(accept:)` to atomically retain prepared pixels only for the still-current live operation. If hidden during claim, retain the prepared candidate for explicit `analyzeCandidate()` instead of starting unseen analysis; if disposed/superseded, reject acceptance so the receipt remains pending. A staged candidate remains acquiring with no busy animation and an explicit Continue action. Analyze success commits atomically and clears old history; failure preserves committed data. Logical cancel invalidates operation tokens. Serialize refinement; reject mismatched photo/revision/tool/layer and discard late worker completions. Hiding overlay switches to Move and disables painting; show original changes no mask. Dispose invalidates callbacks, not an active native call's memory.
- [ ] **Verify GREEN.** Focused tests, analyzer and format pass, including fresh ProviderContainers and independence from roomColorProvider, matching, HSL/mixer/formula/harmonies, history and saved palettes.
- [ ] **Record acceptance.** `room-task-7-report.md`, exact transition/race evidence and API-ready announcement. No disk persistence of photos/masks/edits and no UI edits.

