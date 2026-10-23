### Task 2: Pure mask ownership and aligned processing

**Files:**

- Create: `lib/features/room_studio/domain/{room_layer,mask_bitmap}.dart`.
- Create: `lib/features/room_studio/segmentation/{room_input,room_mask_processing}.dart`.
- Test: `test/features/room_studio/domain/mask_bitmap_test.dart`, `test/features/room_studio/segmentation/room_mask_processing_test.dart`.

**Interfaces:**

- `RoomLayer { wall, ceiling, floor, furniture }`, `int get label` = 1,2,3,4; zero is unselected.
- `MaskBitmap({required int width, required int height, required Uint8List labels})`, immutable copied ownership bytes, positive dimensions and labels 0–4; `int count(RoomLayer)`, `int get pixelCount`. No Flutter imports, mutable public buffers or whole-image equality work during widget builds.
- Immutable `RoomInput { Uint8List tensorBytes; RoomInputTransform transform; }`. `RoomInputTransform` records source/input/content widths/heights and integer left/top padding; validates positive sizes and containment.
- `RoomInput prepareRoomInput(PreparedPhoto photo, RoomModelDescriptor descriptor)`; `MaskBitmap postprocessRoomOutput(RawSegmentation output, RoomInputTransform transform, RoomModelDescriptor descriptor)`; `Uint8List buildLayerAlpha(MaskBitmap masks, RoomLayer layer, {int featherRadius = 2})`.

- [ ] **Write literal pixel tests.** Copy/snapshot immutability; invalid labels/dimensions; independently hand-drawn non-square input/padding and output maps; ignore-zero versus wall; furniture union; protected door/window pixels; stable fill ties; orientation already applied once; radius 1/2 alpha bounds and unchanged ownership. Include extreme wide/tall images without zero-size content.

```dart
final masks = MaskBitmap(width: 2, height: 2,
  labels: Uint8List.fromList([0, 1, 3, 4]));
expect(masks.count(RoomLayer.wall), 1);
expect(masks.count(RoomLayer.floor), 1);
expect(masks.count(RoomLayer.ceiling), 0);
```

- [ ] **Observe RED.** Run `flutter test --no-pub test/features/room_studio/domain/mask_bitmap_test.dart test/features/room_studio/segmentation/room_mask_processing_test.dart --reporter expanded`; expected missing owned APIs before implementation. Use the Task 1 descriptor, never duplicate model class IDs as guesses.
- [ ] **Implement the pure pipeline.** Top-left aspect fit floors content dimensions to longest side512, clamped to at least one pixel. Bilinear interpolation aligns corners; one-pixel output dimensions sample source coordinate0. Clamp interpolated channels to0–255 and truncate; transfer raw RGB bytes without normalization/requantization and pad bottom/right RGB123/115/103. Preserve inverse transform. Process output at verified dimensions, map original ADE IDs1/6/4/8,11,16,20,24 to four layers, fill only unscored zero pixels with3×3 close, resolve ties in enum order, protect all other nonzero classes, remove padding and nearest-map to original working dimensions. The inverse is aligned-corner: source axis length1 samples content coordinate0; otherwise use `round(sourceCoordinate * (contentSize - 1) / (sourceSize - 1))`, add padding and clamp to content. Include a literal three-pixel source test; the comparison fixture's floor-selected sparse points remain diagnostic, not an inverse-geometry rule. Closing uses per-layer binary dilation then erosion with zero outside the model grid, and only original ignored0 may be filled. Use separable binomial feather kernels `[1,2,1]/4` or `[1,4,6,4,1]/16` for radius1/2, zero outside the image. Ownership/counts remain discrete; feathering produces only derived alpha.
- [ ] **Verify GREEN.** The two focused files, scoped analyzer and formatting must pass. Compare at least one reference tensor/output from Task 1 with independently fixed expected pixels, not expectations regenerated from the function under test.
- [ ] **Record acceptance.** Report files, RED/GREEN commands/exits and transform/mapping limits in `docs/superpowers/plans/room-task-2-report.md`; announce these exact APIs ready. No acquisition/UI/native changes.

