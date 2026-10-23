# Camera backend implementation report

## Delivered contract

`camera_session.dart` exposes exactly the plan's `CameraSession`, `cameraSessionFactoryProvider` (`Provider<CameraSession Function()>`), `PluginCameraSession`, `CameraFailure(const CameraFailureKind)` and seven requested failure kinds. `updateSamplePoint` accepts **normalized viewport coordinates**, plus the viewport's logical dimensions. `previewAspectRatio` is the displayed portrait source width / height (`1 / CameraController.value.aspectRatio`). Place `buildPreview()` inside a portrait-sized source box under centered `BoxFit.cover` and pass the covering viewport dimensions unchanged.

The adapter requests permission only from `initialize`, prefers the first rear camera, disables audio, uses medium resolution, and awaits `lockCaptureOrientation(DeviceOrientation.portraitUp)` before starting. Initialization/stream errors expose typed categories and do not expose raw platform messages. Native camera operations are serialized. Stop/dispose immediately invalidate callbacks; asynchronous initialization and stream-start cleanup run in sequence, and repeated disposal releases each device once. A restart waits for its previous worker before admitting new conversion work.

## Native orientation evidence

These decisions were checked against the exact resolved packages in `~/.pub-cache/hosted/pub.dev`, not inferred solely from frame dimensions:

- `camera_android_camerax-0.7.2/lib/src/android_camera_camerax.dart:1333` forwards raw `ImageProxy` plane bytes and dimensions, with no rotated output or rotation metadata applied to the buffer. Its `ImageAnalysisProxyApi.java:35` constructs `ImageAnalysis.Builder` without enabling output image rotation. `CameraInfoProxyApi.java:25` obtains `getSensorRotationDegrees()`. With capture and route locked to portraitUp, apply `CameraDescription.sensorOrientation` clockwise to the buffer. Android front previews mirror; raw analysis buffers do not, so reverse a horizontal display mirror before inverse rotation. The plugin's `image_reader_rotated_preview.dart:124` documents and implements its preview rotation and front mirroring.
- `camera_avfoundation-0.10.3+1/.../DefaultCamera.swift:158` sets `captureVideoOutput` connection `isVideoMirrored = true` for a front camera. `updateOrientation` at line 820 updates the video output connection to the locked `.portrait` video orientation, and lines 1392–1447 forward the resulting CVPixelBuffer dimensions and bytes. Therefore iOS BGRA stream pixels already carry portrait orientation and any front mirroring: use **rotation 0 and no additional mirror**. Applying Android's sensor rotation here would be wrong.
- `camera-0.12.0+2/lib/src/camera_preview.dart` derives the displayed portrait preview aspect by inverting the native preview aspect and obeys the locked capture orientation.

The route must keep portrait UI orientation while using these transforms. The root camera UI owns route orientation restoration.

## Pure helper APIs and processing

- `CameraFrameFormat { yuv420, nv21, bgra8888, unsupported }`, `CameraPlane`, `CameraFrame`, `CameraSampleRequest`: ordinary isolate-safe Dart values. Each plane copies bytes into owned storage.
- `sampleCameraFrame(frame, {required x, required y, radius = 2})`: normalized raw frame point; floor-to-pixel mapping and a clipped 5×5 arithmetic RGB mean. BGRA obeys row/pixel stride; YUV420 obeys separate luma/U/V row and pixel stride; NV21 reads Y followed by interleaved VU using its row stride. YUV uses BT.601 limited-range integer conversion and clips each converted channel. Unknown or truncated buffers produce `FormatException` mapped to `unsupportedFormat`.
- `viewportToCameraPoint(...)`: reverses centered cover cropping, then horizontal mirroring, then clockwise rotation (0/90/180/270). Returns normalized raw buffer coordinates.
- `sampleCameraRequest`: top-level compute entry. Production `compute` receives only `CameraSampleRequest`, never `CameraImage` or a controller closure.
- `CameraSamplingGate`: one in-flight task and a minimum 66,667µs interval (~15fps). The native callback provides a lazy snapshot, so dropped frames do not copy their planes. Conversion touches only the sampled region.
- `CameraColorSmoother`: rounded arithmetic mean of the latest three emitted samples. Reticle/viewport changes clear smoothing and discard any old point's pending result.

`CameraPermissionAccess`, `NativeCameraAccess`, and `NativeCameraDevice` isolate external permissions/device resources from session ownership; `CameraFrameSampler` selects worker execution. These are dependency boundaries used by real production adapters, with fakes confined to tests.

## Verification

Test files were created before implementation; initial red runs failed because the requested backend/helper APIs did not exist. Subsequent scoped verification passed **17 tests**. Coverage includes nonuniform edge means; padded YUV/BGRA rows and chroma pixel strides; NV21 VU order; malformed formats; cover crop/all quarter rotations/mirroring; throttle/smoothing; permission/rear selection; real `compute` color output; disposal during initialization; stop/dispose during pending native start; suppressed late worker/native events; point changes; restart with an old worker; partial-start cleanup; and safe native error mapping.

`flutter analyze lib/features/picker/domain/camera_frame.dart lib/core/utils/camera_sampling.dart lib/features/picker/application/camera_session.dart test/core/camera test/features/picker/camera_backend` passed with **No issues found**.

Formatting passed using the SDK binary with `dart --suppress-analytics format` (the global flag avoids sandbox-blocked telemetry writes). The first whole-project run at the then-current concurrent development state reported 151 passing and two failures outside the backend: photo-processing WebP EXIF expected 1×2 but returned 2×1; camera screen lifecycle tests incorrectly awaited a void framework callback. The camera test compilation issue was corrected in the follow-up review below; the photo implementation owner was notified. Root must obtain final whole-project verification after all delegates finish.

## Follow-up camera UI review

At root's request, also reviewed and updated `camera_picker_screen.dart` and `camera_screen_test.dart`. Fixed these observable issues:

- Lock and restore screen orientation along with capture orientation, so the portrait buffer mapping's premise holds.
- Replace the Choose photo exit action with direct injected photo acquisition; release native camera before invoking the system picker, suppress camera reopening during picker lifecycle/overlaid photo view, pass the actual PreparedPhoto route extra, and recreate live camera after cancellation/return.
- Guard detail-sheet opening after asynchronous stop against background/route changes. Invalidate late sample callbacks and await cleanup before resuming a replacement device.
- Fill the reticle with the sampled color and provide the `camera-selected-color` Hero source and target tag through `showColorDetails`.
- Constrain the live header chip for 360px with doubled text. Stop animating the startup spinner while the app is backgrounded. Correct non-const Semantics construction and void lifecycle test calls.

Combined camera backend and UI verification passed **28 tests** (`flutter test test/core/camera test/features/picker/camera_backend test/features/picker/camera_screen_test.dart`). UI regressions exercise real saved camera source, reticle coordinates/fill, active 360px/2× values, portrait restoration, delayed initialization/disposal, late samples, picker cancellation and successful routing, and background during pending detail stop. New reticle/portrait/photo regression failures were observed before their fixes.

### Permission-dialog interruption correction

Independent review identified that a system permission dialog can itself produce `inactive` / `resumed`. The previous UI invalidated the pending request and opened a fresh session on resume, and disposal suppressed that original permission decision. Targeted red tests reproduced both lost denial (Future incorrectly completed successfully) and immediate duplicate session creation. The adapter now preserves typed permission failures through cancellation, while a late grant still skips native allocation. UI keeps the pending request identity across interruption, disposes its resource owner, waits for its decision before reopening, retains denial until explicit Try again, and allows explicit Settings return recovery. Both denial-before-resume and denial-after-resume cases are covered, along with a grant after true hidden/paused background and native non-allocation after cancellation. Sampling math was unchanged.

Visual review also found the tall bottom glass chrome was clipped by the shared pill default. Camera now explicitly uses the shared `GlassBar(borderRadius: AppRadii.large)` option, with a rendered ClipRRect regression (previous radius 999, expected 28). Final combined scoped camera verification passed **33 tests** after these corrections.

## Physical-device boundary

Synthetic frames, native-source inspection, and Flutter tests verify the math and ownership contract. They do not validate a physical device's negotiated preview/analysis field of view, vendor-specific color conversion/range, camera white balance/calibration, hardware stream reliability, real permission/settings transitions, or front/rear reticle agreement. Device checks should use a high-contrast multicolor target with off-center reticle positions, background/resume, and denied/restricted permission recovery. A source-level orientation conclusion is stronger than guessing but does not replace these device checks.
