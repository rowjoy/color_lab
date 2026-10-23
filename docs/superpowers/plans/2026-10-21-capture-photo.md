# Camera, Gallery and Photo Palette Implementation Plan

**Goal:** Deliver the next Phase 1 module: live camera sampling, zoomable gallery sampling with a loupe, dominant photo palettes, and completed color-detail actions.

**Authority:** The user's “next” continues step 4 of the supplied Color Lab build specification. Foundation and local history are complete; continue without another approval gate. Use the existing test-first, delegated implementation and independent review workflow.

## Design and limits

- Keep Capture's manual entry and studio landing, adding explicit Open camera and Pick a photo actions. Camera permission is requested only on opening the camera route.
- Camera runs full-screen with cover-fit preview, draggable colored reticle and floating glass values/save/gallery controls. Average a clipped 5×5 frame region, throttle to roughly 15 fps, and smooth a short moving window.
- Camera frame conversion supports Android YUV420 (including stride-aware chroma), NV21 if emitted, and iOS BGRA8888. Pure frame sampling and preview coordinate transforms are independently testable and isolate-safe. The plugin adapter uses only serializable frame DTOs for worker conversion, admits one in-flight sample, and suppresses stale callbacks.
- Lock camera capture to portrait while its route is active. Handle front-camera mirroring and raw frame rotation explicitly, based on the installed platform implementation. Stop/dispose on background and route removal; reinitialize on resume. Permission denied, permanent denial/restriction, no camera, unsupported format and initialization failures receive friendly recovery UI.
- Use the system photo picker to obtain a selected image rather than requesting broad library access. On Android, retrieve lost picker data after activity destruction. Cancellation is a normal outcome. Bound requested photo dimensions to 2048 and processing preview dimensions to 1600.
- Decode, bake EXIF orientation, composite alpha over white for consistent opaque sampling, resize and extract palettes in a worker isolate. Reject corrupt, unsupported, oversized or excessively large decoded images before expensive processing wherever codec metadata permits.
- Palette processing downsizes to max 200px, samples the image and invokes the existing seeded LAB k-means++ (k=8, merge delta-E<8). Show actual populations. Low-variety images may honestly return fewer than five colors after merging; do not invent extra colors.
- Photo view supports one-finger tap/drag sampling, a genuine magnifier loupe during drag, and pinch zoom / two-finger pan with correct coordinate transforms. Out-of-image taps do not sample padded background. Palette swatches and picked colors open the common details sheet with gallery source and can be saved/favorited.
- Complete details with a small harmony strip, system text sharing (including an iPad popover origin), and Use in Room routing to the explicitly illustrated room study. Real room-photo editing is still Phase 3. Onboarding and persisted theme settings remain the following module.
- Preserve offline operation, local history, source metadata, tokens, reduced motion, 48dp targets, and 360px / enlarged-text usability. No Git repository exists; work in the authorized folder.

## Shared interfaces and ownership

### 1. Photo processing — delegated

Own `lib/features/picker/domain/prepared_photo.dart`, `lib/core/image/photo_processing.dart`, `lib/features/picker/application/photo_processor.dart`, corresponding `test/core/image/` and `test/features/picker/photo_processing/`.

- `PreparedPhoto({required int width, required int height, required Uint8List rgbaBytes, required Uint8List previewBytes, required List<PaletteColor> palette})`: immutable snapshot; preview PNG and RGBA have identical oriented dimensions. Method `RgbColor sample(double x, double y)` samples normalized [0,1] coordinates with edge clipping; pixel mapping uses floor(x*width), floor(y*height), clipped at last pixel.
- `PreparedPhoto preparePhoto(Uint8List bytes)` is pure Dart and performs decode/normalization/palette work. Typed `PhotoProcessingException` and `PhotoProcessingFailure { invalidImage, tooLarge, unsupported }` expose safe error categories.
- `abstract interface class PhotoProcessor { Future<PreparedPhoto> prepare(Uint8List bytes); }`; `IsolatePhotoProcessor` uses compute with a top-level pure callback. `photoProcessorProvider` is an overridable Riverpod Provider.
- [x] Tests first: literal multicolor pixel fixtures, orientation, transparency compositing, actual percentage proportions, deterministic extraction, dimension limits and corrupt bytes. Observe failures, implement and run scoped verification.

### 2. Camera backend — delegated

Own `lib/features/picker/domain/camera_frame.dart`, `lib/core/utils/camera_sampling.dart`, `lib/features/picker/application/camera_session.dart`, and `test/core/camera/`, `test/features/picker/camera_backend/`.

- `abstract interface class CameraSession`: `Future<void> initialize()`, `Future<void> start({required ValueChanged<RgbColor> onColor, required ValueChanged<CameraFailure> onError})`, `Future<void> stop()`, `Future<void> dispose()`, `Future<bool> openSettings()`, `Widget buildPreview()`, `double get previewAspectRatio`, `void updateSamplePoint({required double x, required double y, required double viewportWidth, required double viewportHeight})`.
- `cameraSessionFactoryProvider` exposes `CameraSession Function()`; production `PluginCameraSession` handles permission_handler and camera plugin, preferring back lens with audio disabled.
- `CameraFailure` has `CameraFailureKind kind`; enum values `permissionDenied, permissionPermanentlyDenied, permissionRestricted, unavailable, unsupportedFormat, initialization, stream`. Do not expose raw platform strings to UI.
- Domain frame DTOs, stride/crop/rotation math, throttle and smoothing helper APIs are implementer's choice; report them. Root consumes only the session contract.
- Inspect installed native implementations to resolve buffer orientation rather than guessing. Handle lifecycle/dispose races and test through injectable backend boundaries or pure helpers where practical.
- [x] Tests first: padded Y/chroma rows and pixel strides, BGRA order, NV21 layout, 5×5 clipped boundaries, nonuniform fixtures, cover-crop mapping and all rotations/mirroring, throttle and smoothing. Implement and verify scoped tests/analysis.

### 3. Photo acquisition and view — delegated

Own `lib/features/picker/application/photo_picker_service.dart`, `lib/features/picker/presentation/photo_picker_screen.dart`, supporting `photo_*.dart` presentation files, optional `domain/photo_viewport.dart`, and `test/features/picker/photo_view/`.

- `abstract interface class PhotoPickerService { Future<PreparedPhoto?> pick(); Future<PreparedPhoto?> recoverLost(); Future<bool> openSettings(); }` with `photoPickerServiceProvider`.
- `PhotoPickFailure` has `PhotoPickFailureKind kind`; enum values `permissionDenied, unavailable, invalidImage, tooLarge, processing`. Map raw plugin/processing errors to safe categories. Limit native picker size and encoded bytes; root handles friendly errors around acquisition.
- Default recoverLost is Android-only and uses retrieveLostData; other platforms return null. Processor comes from task 1's provider.
- `PhotoPickerScreen({required PreparedPhoto photo})` is a routable full-screen widget with image sampling, zoom/pan, loupe, selected color values and tappable population swatches. UI imports existing `showColorDetails(..., source: ColorSource.gallery)` and reuses local SaveColorActions where appropriate.
- [x] Tests first: real sample pixels, letterboxed exclusion, sampling after zoom, loupe drag state, pinch behavior, palette/detail source, cancellation/error/lost-data service boundaries, 360px / 2x layout. Use genuine prepared fixtures and injectable acquisition/processing rather than pretending the platform picker itself was tested.

### 4. Camera UI and integration — root

Own `camera_picker_screen.dart`, `capture_screen.dart`, routes, platform setup, detail additions, share/room/harmony adapters, root tests/fakes, README and delivery.

- [x] Baseline existing suite and resolve only used dependencies: camera, image_picker, image, permission_handler, share_plus. Adapt Android tooling only if the selected plugin requires it; verify native package requirements.
- [x] Write camera-screen tests using an injected CameraSession: denied/settings/no-camera/retry, live color/save/source, reticle updates, background/resume, late initialize/dispose and small/large-text layout. Implement generation-safe startup and serialized teardown, with no automatic permission prompts on Capture landing.
- [x] Add root `/camera` and `/photo` routes outside the tab shell. `/photo` consumes PreparedPhoto route extra; invalid direct navigation returns a friendly recovery page. Wire pick/recovered photo routing with loading/cancel/error UI and no late navigation after disposal.
- [x] Add pure detail-harmony/share formatting tests, injectable share adapter and Room selected-color provider. Detail actions handle share failures and mounted state; avoid stacking unlimited harmony sheets.
- [x] Add Android CAMERA declaration and iOS rationale strings; configure only used iOS permission macros. System picker selection requires no broad media permission. No microphone/audio capture or gallery export capability is added.
- [x] Update prior tests/preview tools to override platform boundaries. Run scoped tests, full suite, analyzer, formatter, debug APK, and visual previews. Obtain independent code/algorithm review and fix required findings.
- [x] Document exact working features and physical-device verification limits, changed-file map, new package versions/platform changes/run commands, and create `dist/color-lab-capture-2026-10-21.zip` while preserving earlier archives.

## Review focus

- Pixel values and touch coordinates must agree after crop, rotation, mirroring and zoom.
- Slow sampling/initialization must never update disposed widgets or leak a camera.
- Photo cancellation and permission errors must leave prior state usable.
- EXIF, alpha and memory bounds must be consistent between preview and sampled bytes.
- Synthetic/unit tests and Android compilation do not establish physical camera color calibration or device-specific stream orientation; report that boundary honestly.
