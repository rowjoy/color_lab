### Task 9: Room entry editor and full application flows

**Files:**

- Create: `lib/features/room_studio/presentation/{room_mask_screen,room_mask_dialogs}.dart`.
- Modify: `lib/features/room_studio/presentation/room_screen.dart`, `lib/routing/app_router.dart`.
- Test: `test/features/room_studio/presentation/room_masks_integration_test.dart`.
- Consume the Task 3 test boundary `test/support/in_memory_acquisition_intent_store.dart`; do not create a duplicate store or take ownership of its production interface.

**Interfaces and exact UI:**

- Root guarded `/room/masks` route, `RoomMaskScreen`, title `Room masks`, scroll key `screen-RoomMasks`; Back pops or goes `/room` without reset.
- Room entry `Prepare room masks`, key `open-room-masks`, ahead of the retained explicitly labeled illustrated color study. Existing Use in Room color behavior remains intact and is not described as photo painting.
- Buttons `Choose room photo`/`Take room photo`, keys `room-mask-gallery`/`room-mask-camera`. Recovered receipts use `room-mask-continue-import`; unknown destination recovery offers explicit Capture/Room choice. If a claimed candidate is awaiting user acceptance, show `Analyze this photo`, key `room-mask-continue-analysis`.
- Analysis text `Finding room surfaces on this device…`; `Cancel analysis`, `Retry analysis`, `Choose another photo`. No fake percentages. A valid empty result says `No supported surfaces were found. You can mark them manually.` Runtime errors say `Room analysis could not finish. Try again or choose another photo.`
- Ready: actual viewport key `room-mask-viewport`, visible `Mask preview`, Wall/Ceiling/Floor/Furniture chips with coverage and `Not detected` for zero counts. Move/Add/Erase, brush size, `Show original`, Undo (`room-mask-undo`), `Restore AI masks` (`room-mask-restore`) and replace-photo actions.
- Confirm restore/replace in root shared-token dialogs, minimum 48 dp, reduced motion. Restore confirmation key `confirm-room-mask-restore`; replace confirmation `confirm-room-mask-replace`. Recheck captured photo/revision after dialog acceptance. Persistent copy: `Automatic masks may miss surfaces or include nearby objects. Check each layer and refine it before recoloring.`
- Dialog helpers: `Future<bool> confirmRestoreAiMasks(BuildContext context)` and `Future<bool> confirmReplaceRoomPhoto(BuildContext context)` in `room_mask_dialogs.dart`; cancellation/system Back return false. They do not mutate controller state themselves.

- [ ] **Write full-app behavior tests.** First real Room entry test must fail before the CTA exists. Use actual router/controller/refinement/viewport, in-memory repository boundaries and delayed segmentation output. Cover both acquisition sources; AI-before-manual; failed versus empty detection; edits/undo exact pixels; selected-layer ownership; original-only no edits; cancelled/stale root dialogs; replaced photo resets view/history only on success; pending/late receipts never steal routes; preserved old draft on error and unchanged common Use in Room/history/Lab state. Include direct-route onboarding guard.

```dart
await tester.tap(find.byKey(const ValueKey('nav-Room')));
await tester.pumpAndSettle();
expect(find.byKey(const ValueKey('open-room-masks')), findsOneWidget);
```

- [ ] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/presentation/room_masks_integration_test.dart --reporter expanded`; first behavioral failure must identify the missing Room action. Do not create fake production workers to compile tests.
- [ ] **Implement UI against ready APIs.** Watch retained state, dispatch source-aware imports, and provide an active-owner callback checking mounted/current route before claiming asynchronous photos. Rendering/typing/theme changes do not reset viewport; a committed new photo or restore resets it intentionally. Capture photo/revision/tool in action callbacks and clear gesture/local busy state only for accepted mutations. Show the preserved previous draft as an explicit Return option after failure; do not automatically enable manual editing on a failed candidate.
- [ ] **Verify GREEN.** Full-app tests, scoped analyzer/format, plus 360 dp/2× light and dark/reduced-motion dialogs and visible new-photo entry without `ensureVisible` hiding a viewport bug. Faked lifecycle output here is UI evidence only; actual AI execution remains Task 1/5's separate gate.
- [ ] **Record acceptance.** `room-task-9-report.md` with observed failures/fixes and no raw errors/clinical/paint claims. Run one cumulative full suite and report any unfinished sibling failure by exact name; do not count a cancelled suite as success.

