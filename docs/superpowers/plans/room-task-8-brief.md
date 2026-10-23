### Task 8: Real overlay rendering and transform safe viewport

**Files:**

- Create: `lib/features/room_studio/presentation/room_mask_viewport.dart`.
- Create: `lib/features/room_studio/application/mask_overlay_service.dart`.
- Test: `test/features/room_studio/presentation/{mask_overlay_service_test,room_mask_viewport_test}.dart`.

**Interfaces:**

- `MaskOverlayService`: `Future<Uint8List> render({required MaskBitmap masks, required RoomLayer layer, required RgbColor tint, int featherRadius = 2})` returns PNG RGBA, using Task 2 alpha and worker encoding. `IsolateMaskOverlayService` implements it; `maskOverlayServiceProvider` supplies that adapter.
- `RoomMaskViewport({super.key, required String photoId, required int maskRevision, required PreparedPhoto photo, required MaskBitmap masks, required RoomLayer layer, required RoomMaskTool tool, required double brushFraction, required bool showOverlay, required bool editingEnabled, required ValueChanged<MaskStroke> onStroke})`.
- Reuse `PhotoViewport` for both display and hit testing; zoom 1–8, explicit Move versus Add/Erase. Diagram callbacks carry the gesture's captured layer/mode; screen captures photoId/maskRevision for Task 7.

- [ ] **Write raster and gesture tests.** Actual PNG alpha/tint at independently known points, unchanged photo bytes, selected-only overlay, resize/letterbox alignment, non-square input, zoom mapping, no old overlay on a new photo/revision, no recomputation while moving/rebuilding unchanged geometry, and async old PNG completion ignored. A one-finger brush commits once; a second pointer cancels without a command; leaving/re-entering the image creates disconnected segments. Image semantics describe a mask preview, never a painted room or invented accuracy.

For a 7×7 mask whose central 3×3 pixels are Wall, rendered at feather radius 1:

```dart
final decoded = img.decodePng(png)!;
expect(decoded.getPixel(3, 3).a, 255);
expect(decoded.getPixel(0, 0).a, 0);
```

- [ ] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/presentation/mask_overlay_service_test.dart test/features/room_studio/presentation/room_mask_viewport_test.dart --reporter expanded` before implementation. Rasterize actual painter/image output and dispose explicit semantics handles inline, not only in late teardown.
- [ ] **Implement viewport and cache.** Cache by photoId/maskRevision/layer/tint/feather. Never run model, pixel masks or PNG encoding in build/paint. Clear stale overlay immediately when its key changes, then publish decoded output only for that key. Render photo and overlay through the same rect. During drag draw lightweight vector preview; no mask commits until accepted pointer-up. Second-pointer/cancel/tool/photo changes roll back preview. Original-only mode is nonpainting; no saturation filter masquerading as recolor.
- [ ] **Verify GREEN.** Focused pixel/gesture/semantics tests, analyzer and format; both themes and 360 dp/2× text/reduced motion. Explicitly inspect mask alignment rather than asserting only widget existence.
- [ ] **Record acceptance.** `room-task-8-report.md`; expose exact APIs to Task 9. No model/controller/Capture/README edits.

